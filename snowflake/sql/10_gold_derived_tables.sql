/***************************************************************************************************       
Project:      Volve Field Retrospective Economic & Production Review 
Task   :      GOLD DERIVED Dynamic Tables (Transformation Layer)
****************************************************************************************************/
USE ROLE VOLVE_DE;
ALTER SESSION SET QUERY_TAG = '{"project":"volve", "name":"nabila natasha", "layer":"gold", "task":"dynamic tables transformation", "day": "3"}';
USE WAREHOUSE TRANSFORM_WH;
USE DATABASE OG_ANALYTICS;

-- 1. Derived GOLD Dynamic Tables (Production)
--a) For Production Decline Curve Analysis
CREATE OR REPLACE DYNAMIC TABLE GOLD.WELL_DECLINE_TREND
    TARGET_LAG = '1 hour'
    WAREHOUSE = 'TRANSFORM_WH'
AS
SELECT
    DATE_TRUNC('MONTH', prod_date)  AS month_start,
    well_name,
    SUM(oil_vol_sm3)                AS monthly_oil_vol,
    SUM(gas_vol_sm3)                AS monthly_gas_vol,
    SUM(water_vol_sm3)              AS monthly_water_vol,
    COUNT_IF(is_shutin)             AS shutin_days_in_month  -- count num of prod rows in month where well was shut-in
FROM GOLD.FACT_PRODUCTION
GROUP BY DATE_TRUNC('MONTH', prod_date), well_name;

--b) For Water Cut Analysis
CREATE OR REPLACE DYNAMIC TABLE GOLD.WATER_CUT_TREND
    TARGET_LAG = '1 hour'
    WAREHOUSE = 'TRANSFORM_WH'
AS
SELECT 
    DATE_TRUNC('MONTH', prod_date)                                          AS month_start,
    well_name,
    SUM(water_vol_sm3) / NULLIF(SUM(oil_vol_sm3) + SUM(water_vol_sm3),0)    AS monthly_water_cut,
FROM GOLD.FACT_PRODUCTION
GROUP BY well_name, DATE_TRUNC('MONTH', prod_date);

--c) For Downtime Event (Gaps & Islands Query) Islands = consecutive/continuous groups, Gaps = breaks between those groups
-- DOWNTIME_EVENTS uses FULL refresh mode due to its window-function-based grouping logic (ROW_NUMBER over an unbounded ordered partition),
-- which prevents Snowflake from computing a safe incremental delta — FACT_PRODUCTION and the other GOLD tables use standard incremental refresh
SELECT MIN(prod_date) earliest_prod_date FROM SILVER.DAILY_PRODUCTION_CLEAN;  --2007-09-01 (use as reference only)

CREATE OR REPLACE DYNAMIC TABLE GOLD.DOWNTIME_EVENTS
    TARGET_LAG = '1 hour'
    WAREHOUSE = 'TRANSFORM_WH'
AS
WITH flagged AS (
    SELECT  
        well_name,
        prod_date,
        DATEDIFF('day', '2007-09-01', prod_date)       -- -- Confirmed earliest_prod_date = 2007-09-01 (checked separately, used as anchor)         
            - ROW_NUMBER() OVER (PARTITION BY well_name, is_shutin ORDER BY prod_date)    AS shutdown_grp
    FROM GOLD.FACT_PRODUCTION
    WHERE is_shutin = TRUE  -- shutdown
)
SELECT 
    well_name,
    MIN(prod_date)                                          AS event_start,  
    MAX(prod_date)                                          AS event_end,
    DATEDIFF('day', MIN(prod_date), MAX(prod_date)) + 1     AS duration_days -- + 1 to get the calendar day duration 
FROM flagged
GROUP BY well_name, shutdown_grp
ORDER BY well_name, event_start;

-- 2. Derived GOLD Dynamic Tables (Economic)
-- d) For Revenue Decomposition - Break down the change in notional benchmark revenue due to volume or price effect. (Field-level revenue)
-- NOTE: "revenue" here is notional/benchmark revenue (volume x Brent spot price),
-- not realized/net revenue. Does not account for quality/lovation differentials,
-- royalties, production tax or OPEX. 
CREATE OR REPLACE DYNAMIC TABLE GOLD.REVENUE_DECOMPOSITION
    TARGET_LAG = '1 hour'
    WAREHOUSE = 'TRANSFORM_WH'
AS
WITH monthly AS (
SELECT 
    DATE_TRUNC('MONTH', prod_date)                                                      AS month_start,
    SUM(oil_vol_sm3) * 6.2898                                                           AS total_oil_vol_bbl,  -- FIXED: converted for direct price multiplication
    -- Volume-weighted average Brent price for the month.
    -- Each day's Brent price is weighted by that day's oil production volume.
    SUM(oil_vol_sm3 * brent_usd_bbl_filled) / NULLIF(SUM(oil_vol_sm3), 0)               AS avg_brent_price_usd,  -- Brent price weighted according to how much oil was produced on each day for that month
    SUM(oil_vol_sm3 * brent_usd_bbl_filled * nok_per_usd) / NULLIF(SUM(oil_vol_sm3), 0) AS avg_brent_price_nok,  -- Volume-weighted Brent price converted into NOK
    SUM(est_revenue_usd)                                                                AS benchmark_revenue_usd, 
    SUM(est_revenue_nok)                                                                AS benchmark_revenue_nok 
FROM GOLD.FACT_PRODUCTION
GROUP BY DATE_TRUNC('MONTH', prod_date)
),
annual_baseline AS (   
    -- The first available month of each year is used as the annual baseline. This answers:
    -- "How has notional benchmark revenue changed since the beginning of the year?"
    SELECT 
        YEAR(month_start)       AS report_year,
        total_oil_vol_bbl       AS baseline_vol_bbl,
        avg_brent_price_usd     AS baseline_price_usd,
        avg_brent_price_nok     AS baseline_price_nok,
        benchmark_revenue_usd   AS baseline_revenue_usd,
        benchmark_revenue_nok   AS baseline_revenue_nok
    FROM monthly
    QUALIFY ROW_NUMBER() OVER (PARTITION BY YEAR(month_start) ORDER BY month_start) = 1
)
SELECT
    m.month_start,
    YEAR(month_start)       AS report_year,
    -- Current month
    m.total_oil_vol_bbl,
    m.avg_brent_price_usd,
    m.avg_brent_price_nok,
    m.benchmark_revenue_usd,
    m.benchmark_revenue_nok,
    -- Annual baseline
    b.baseline_vol_bbl,
    b.baseline_price_usd,
    b.baseline_price_nok,
    b.baseline_revenue_usd,
    b.baseline_revenue_nok,
    -- Change from annual baseline                                                          -- REVENUE CHANGE = VOLUME EFFECT + PRICE EFFECT + INTERACION
    m.benchmark_revenue_usd - b.baseline_revenue_usd                                            AS revenue_change_usd,
    m.benchmark_revenue_nok - b.baseline_revenue_nok                                            AS revenue_change_nok,
    -- Volume effect: How much did benchmark revenue change because production volume changed, while holding the price at the baseline price?
    (m.total_oil_vol_bbl - b.baseline_vol_bbl) * b.baseline_price_usd                           AS volume_effect_usd,
    (m.total_oil_vol_bbl - b.baseline_vol_bbl) * b.baseline_price_nok                           AS volume_effect_nok,
    -- Price effect: How much did benchmark revenue change because Brent price changed, while holding volume at the baseline volume?
    (m.avg_brent_price_usd - b.baseline_price_usd) * b.baseline_vol_bbl                         AS price_effect_usd,
    (m.avg_brent_price_nok - b.baseline_price_nok) * b.baseline_vol_bbl                         AS price_effect_nok,
    -- Volume x Price Interaction
    (m.total_oil_vol_bbl - b.baseline_vol_bbl) * (m.avg_brent_price_usd - b.baseline_price_usd) AS volume_price_interaction_usd,
    (m.total_oil_vol_bbl - b.baseline_vol_bbl) * (m.avg_brent_price_nok - b.baseline_price_nok) AS volume_price_interacion_nok  
FROM monthly m
INNER JOIN annual_baseline b
    ON YEAR(m.month_start) = b.report_year;  -- compare against first month of it's own year

-- Validation check to reconcile the revenue after convert the oil_vol_sm3 to oil_vol_bbl
SELECT 
    month_start,
    revenue_change_usd,
    volume_effect_usd + price_effect_usd + volume_price_interaction_usd                                     AS reconstructed_change_usd,
    ROUND(revenue_change_usd - (volume_effect_usd + price_effect_usd + volume_price_interaction_usd), 2)    AS should_be_zero
FROM GOLD.REVENUE_DECOMPOSITION;

--e) For Well Value Ranking table
CREATE OR REPLACE DYNAMIC TABLE GOLD.WELL_VALUE_RANKING
    TARGET_LAG = '1 hour'
    WAREHOUSE = TRANSFORM_WH
AS
-- Notional cumulative value per well (volume x Brent), see REVENUE_DECOMPOSITION note.
WITH well_totals AS (
    SELECT
        well_name,
        SUM(est_revenue_usd) AS cumulative_revenue_usd,
        SUM(est_revenue_nok) AS cumulative_revenue_nok
    FROM GOLD.FACT_PRODUCTION
    GROUP BY well_name
)
SELECT
    well_name,
    cumulative_revenue_usd,
    cumulative_revenue_nok,
    RANK() OVER (ORDER BY cumulative_revenue_usd DESC)  AS value_rank,
    SUM(cumulative_revenue_usd) OVER (
        ORDER BY cumulative_revenue_usd DESC ROWS UNBOUNDED PRECEDING
    ) / SUM(cumulative_revenue_usd) OVER ()             AS running_pct_of_total
FROM well_totals;

-- 3. Reconciliation Check (Daily vs Monthly source)
WITH reconciliation AS (
SELECT 
    d.well_name,
    d.year,
    d.month,
    d.daily_summed_oil,
    m.oil_sm3                       AS monthly_reported_oil,
    d.daily_summed_oil - m.oil_sm3  AS oil_variance,
    ROUND(100.0 * (d.daily_summed_oil - m.oil_sm3) / NULLIF(m.oil_sm3, 0), 2) AS oil_variance_pct,
    d.daily_summed_gas,
    m.gas_sm3                       AS monthly_reported_gas,
    d.daily_summed_gas - m.gas_sm3  AS gas_variance,
    ROUND(100.0 * (d.daily_summed_gas - m.gas_sm3) / NULLIF(m.gas_sm3, 0), 2) AS gas_variance_pct
FROM (
    SELECT  
        well_name,
        YEAR(prod_date)     AS year,
        MONTH(prod_date)    AS month,
        SUM(oil_vol_sm3)    AS daily_summed_oil,
        SUM(gas_vol_sm3)    AS daily_summed_gas
    FROM SILVER.DAILY_PRODUCTION_CLEAN
    GROUP BY well_name, YEAR(prod_date), MONTH(prod_date)
) d
JOIN SILVER.MONTHLY_PRODUCTION_CLEAN m
    ON d.well_name = m.well_name AND d.year = m.prod_year AND d.month = m.prod_month
)
-- SUMMARY: how many well-months exceed a 1% threshold?
-- Based on he result, count = 0 hence reconciliation confirmed with minor/ 0 variance.
SELECT
    COUNT(*)                                              AS total_well_months,  -- 526
    COUNT_IF(ABS(oil_variance_pct) > 1)                   AS oil_flags,          -- 0
    COUNT_IF(ABS(gas_variance_pct) > 1)                   AS gas_flags           -- 0
FROM reconciliation;

-- 4. Force Refresh everything + capture proof of incremental behavior
ALTER DYNAMIC TABLE GOLD.FACT_PRODUCTION REFRESH;
ALTER DYNAMIC TABLE GOLD.WELL_DECLINE_TREND REFRESH;
ALTER DYNAMIC TABLE GOLD.WATER_CUT_TREND REFRESH;
ALTER DYNAMIC TABLE GOLD.DOWNTIME_EVENTS REFRESH;
ALTER DYNAMIC TABLE GOLD.REVENUE_DECOMPOSITION REFRESH;
ALTER DYNAMIC TABLE GOLD.WELL_VALUE_RANKING REFRESH;
    
SELECT MAX(prod_date) FROM GOLD.FACT_PRODUCTION;             -- 2016-09-17
SELECT MAX(month_start) FROM GOLD.REVENUE_DECOMPOSITION;     -- 2016-09-01

-- README screenshot - proof of incremental refresh behavior
SELECT *
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(
    NAME => 'GOLD.FACT_PRODUCTION'
))
ORDER BY refresh_start_time DESC
LIMIT 10;
