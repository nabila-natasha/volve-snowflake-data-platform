/***************************************************************************************************       
Project:      Volve Field Retrospective Economic & Production Review 
Task   :      GOLD DIMENSION Tables (Transformation Layer)
****************************************************************************************************/
USE ROLE VOLVE_DE;
ALTER SESSION SET QUERY_TAG = '{"project":"volve", "name":"nabila natasha", "layer":"gold", "task":"dimension tables", "day": "3"}';
USE WAREHOUSE TRANSFORM_WH;
USE DATABASE OG_ANALYTICS;

-- 1. GOLD Dimension tables (plain tables - dimensions don't need to be dynamic)
-- a) DIM_WELL - confirmed, well_type removed (fact_production already stires well_type at daily grain)
CREATE OR REPLACE TABLE GOLD.DIM_WELL
AS
SELECT
    well_name,
    MAX_BY(field_name, prod_date)     AS field_name,
    MAX_BY(facility_name, prod_date)  AS facility_name,
    MIN(prod_date)                    AS first_producing_date,
    MAX(prod_date)                    AS last_producing_date
FROM SILVER.DAILY_PRODUCTION_CLEAN
GROUP BY well_name;

------ NOT PIPELINE STEP, PURELY FOR INVESTIGAION (doesn't feed in any table for dashboard reads) ------
-- In oil field operations - wells genuinely do get converted between injector and producer
-- roles over their lifetime as reservoir management strategy changes.
SELECT DISTINCT well_name, well_type, field_name, facility_name
FROM SILVER.DAILY_PRODUCTION_CLEAN
WHERE well_name IN (
    SELECT well_name FROM (   -- well 15/9-F-1 C and 15/9-F-5 has 2 well type = OP, WI
        SELECT DISTINCT well_name, well_type FROM SILVER.DAILY_PRODUCTION_CLEAN
    ) GROUP BY well_name HAVING COUNT(*) > 1
)
ORDER BY well_name;



--- Investigation ---
-- DIM_WELL SCD Type 1 table - using the well's most recent know type
CREATE OR REPLACE TABLE GOLD.DIM_WELL_SCD1
AS
SELECT
    well_name,
    MAX_BY(well_type, prod_date)        AS well_type, -- well_type as of its most recent producing date
    MAX_BY(field_name, prod_date)       AS field_name,
    MAX_BY(facility_name, prod_date)    AS facility_name,
    MIN(prod_date)                      AS first_producing_date,
    MAX(prod_date)                      AS last_producing_date
FROM SILVER.DAILY_PRODUCTION_CLEAN
GROUP BY well_name;

--  Immediately after, in the same session: verify the total_rows vs distinct_calendar (ensure count is same)
SELECT  
    COUNT(*)                    AS total_rows,      -- 7
    COUNT(DISTINCT well_name)   AS dictinct_wells   -- 7
FROM GOLD.DIM_WELL;

-- # Diagnosed SCD1 dimension flaw causing historical production data misrepresentation.
-- If using DIM_WELL_SCD1, found that 15/9-F-5 well was OP previously and if using recent  well type, it is WI.
-- Worried that the previous production vol was ignore impacting the benchmark revenue. 
-- Hence, this diagnosis to check "How much revenue is actually at risk." if we overwrite the previous well type.
-- Per-well: OP-period production, alonside what DIM_WELL_SCD1 currently labels that well.
SELECT 
    p.well_name,
    d.well_type                                    AS dim_well_current_label,
    COUNT(*)                                        AS op_days,
    SUM(p.oil_vol_sm3)                              AS op_oil_vol,
    SUM(p.oil_vol_sm3 * b.brent_usd_bbl_filled)     AS op_revenue_usd
FROM SILVER.DAILY_PRODUCTION_CLEAN p
JOIN GOLD.DIM_WELL_SCD1 d ON p.well_name = d.well_name
LEFT JOIN SILVER.BRENT_PRICES_FILLED b ON p.prod_date = b.cal_date
WHERE p.well_type = 'OP'   -- days that genuinely produced oil, regardless of current label
GROUP BY p.well_name, d.well_type
ORDER BY p.well_name;

-- # Summary - what % of total OP revenue would be affected. 
-- Based on result 0.22% revenue at risk.
SELECT 
    SUM(CASE WHEN d.well_type != 'OP' THEN p.oil_vol_sm3 * b.brent_usd_bbl_filled ELSE 0 END) AS at_risk_revenue_usd,
    SUM(p.oil_vol_sm3 * b.brent_usd_bbl_filled)                                                AS total_op_revenue_usd,
    ROUND(100.0 * SUM(CASE WHEN d.well_type != 'OP' THEN p.oil_vol_sm3 * b.brent_usd_bbl_filled ELSE 0 END)
        / NULLIF(SUM(p.oil_vol_sm3 * b.brent_usd_bbl_filled), 0), 2)                           AS at_risk_pct  
FROM SILVER.DAILY_PRODUCTION_CLEAN p
JOIN GOLD.DIM_WELL_SCD1 d ON p.well_name = d.well_name
LEFT JOIN SILVER.BRENT_PRICES_FILLED b ON p.prod_date = b.cal_date
WHERE p.well_type = 'OP';
-----------------------------------------------------------------------------------------------------------------------

---------------------- DIM_WELL SCD Type 2 - purely a standalone demonstration artifact -------------------------------
CREATE OR REPLACE TABLE GOLD.DIM_WELL_SCD2
AS
WITH well_changes AS (
    SELECT
        well_name,
        well_type,
        field_name,
        facility_name,
        prod_date,
        CASE
            WHEN well_type != LAG(well_type) OVER (PARTITION BY well_name ORDER BY prod_date)   -- if different from prev, is_new_version = 1 
                 OR LAG(well_type) OVER (PARTITION BY well_name ORDER BY prod_date) IS NULL     -- well's first record automatically start with is_new_version = 1
            THEN 1 ELSE 0
        END AS is_new_version
    FROM SILVER.DAILY_PRODUCTION_CLEAN
),
versioned AS (
    SELECT
        well_name, well_type, field_name, facility_name, prod_date,
        SUM(is_new_version) OVER (PARTITION BY well_name ORDER BY prod_date) AS version_num  -- detects how many times the well_type version changed
    FROM well_changes
)
SELECT
    ROW_NUMBER() OVER (ORDER BY well_name, version_num)                         AS well_surrogate_key,  -- a made-up, guaranteed-unique ID per version-row
    well_name,
    well_type,
    field_name,
    facility_name,
    MIN(prod_date) AS effective_start_date,
    MAX(prod_date) AS effective_end_date,
    ROW_NUMBER() OVER (PARTITION BY well_name ORDER BY version_num DESC) = 1     AS is_current  -- is_current checks rank = 1 (always corresponds to the newest version regardless of what the real version_num number is.)
FROM versioned
GROUP BY well_name, well_type, field_name, facility_name, version_num
ORDER BY well_name, effective_start_date;

-----------------------------------------------------------------------------------------------------------------------
-- b) DIM_DATE table
CREATE OR REPLACE TABLE GOLD.DIM_DATE AS
WITH date_bounds AS (
    SELECT 
        MIN(prod_date)  AS min_date, 
        MAX(prod_date)  AS max_date
    FROM SILVER.DAILY_PRODUCTION_CLEAN
),
date_spine AS (
    SELECT DATEADD('day', SEQ4(), min_date) AS calendar_date   -- add specified amount of date starting at min_date, then add the number generated by SEQ4() days. SEQ4() - generates sequential integers.
    FROM date_bounds,
         TABLE(GENERATOR(ROWCOUNT => 100000))  -- GENERATOR() - generate 100,000 rows. generous upper bound, trimmed by the WHERE below
    WHERE DATEADD('day', SEQ4(), min_date) <= (SELECT max_date FROM date_bounds)
)
SELECT
    calendar_date,
    YEAR(calendar_date)                AS year,
    MONTH(calendar_date)               AS month,
    QUARTER(calendar_date)             AS quarter,
    DATE_TRUNC('MONTH', calendar_date) AS month_start
FROM date_spine
ORDER BY calendar_date;

-- Immediately after, in the same session: verify the total_rows vs distinc_date. if total_rows > distinct well_name (duplicate)
SELECT 
    COUNT(*)                        AS total_rows,   -- 3380  
    COUNT(DISTINCT calendar_date)   AS distinct_date -- 3380 
FROM GOLD.DIM_DATE;  



--- Investigation ---
-- Sanity check on the blank brent prices due to weeekends and public holidays
-- Gap pattern is following the EIA's own US publishing calendar (US-centric data availability gap, not European market closure)
SELECT 
    DAYNAME(p.PROD_DATE) AS day_of_week,
    COUNT(*) AS null_brent_rows
FROM SILVER.DAILY_PRODUCTION_CLEAN p
LEFT JOIN SILVER.BRENT_PRICES b
    ON p.PROD_DATE = b.PRICE_DATE
WHERE b.BRENT_USD_BBL IS NULL
  AND p.well_type = 'OP'
GROUP BY DAYNAME(p.prod_date)
ORDER BY null_brent_rows DESC; -- total = 2821 having blank brent prices

-- Sanity check on the brent prices during weekdays due to public holidays (exclude Sat & Sun)
SELECT DISTINCT 
    p.PROD_DATE,  -- 74 rows
    DAYNAME(p.PROD_DATE) AS day_of_week
FROM SILVER.DAILY_PRODUCTION_CLEAN p
LEFT JOIN SILVER.BRENT_PRICES b
    ON p.PROD_DATE = b.PRICE_DATE
WHERE b.BRENT_USD_BBL IS NULL
  AND p.well_type = 'OP'
  AND DAYNAME(p.PROD_DATE) NOT IN ('Sat', 'Sun')
ORDER BY p.PROD_DATE;  --11-26, 12-25, 01-01 (Thanksgiving, Christmas, New Year)

-- Create brent_prices_filled and land in Iceberg table
-- Forward and backward-filled Brent prices, one row per calendar date
CREATE OR REPLACE ICEBERG TABLE SILVER.BRENT_PRICES_FILLED 
    CATALOG = 'SNOWFLAKE'
AS
WITH date_spine AS (
    SELECT 
        DISTINCT prod_date AS cal_date 
    FROM SILVER.DAILY_PRODUCTION_CLEAN
),
joined AS (
    SELECT 
        d.cal_date, 
        b.brent_usd_bbl
    FROM date_spine d
    LEFT JOIN SILVER.BRENT_PRICES b ON d.cal_date = b.price_date
)
SELECT
    cal_date,
    COALESCE(
        LAST_VALUE(brent_usd_bbl IGNORE NULLS) OVER (
            ORDER BY cal_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW -- forward-filled
        ),   
        FIRST_VALUE(brent_usd_bbl IGNORE NULLS) OVER (
            ORDER BY cal_date ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING  -- backward-filled
        )
    ) AS brent_usd_bbl_filled
FROM joined ORDER BY cal_date;

-- Sanity check if there's any null value in the brent_usd_bbl_filled
SELECT 
    COUNT(*) AS null_brent
FROM SILVER.BRENT_PRICES_FILLED
WHERE brent_usd_bbl_filled IS NULL;  -- 0

-- Sanity check if there's any missing foreign-exchange rates
SELECT 
    DAYNAME(p.prod_date) AS day_of_week,
    COUNT(*) AS null_fx_rows
FROM SILVER.DAILY_PRODUCTION_CLEAN p
LEFT JOIN SILVER.FX_RATES f
    ON p.prod_date = f.rate_date
WHERE f.nok_per_usd IS NULL
AND p.well_type = 'OP'
GROUP BY DAYNAME(p.prod_date)
ORDER BY null_fx_rows DESC;  -- no result