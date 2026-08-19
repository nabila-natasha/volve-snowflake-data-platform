/***************************************************************************************************       
Project:      Volve Field Retrospective Economic & Production Review 
Task   :      Initial Profiling    
****************************************************************************************************/
USE ROLE VOLVE_DE;

-- assign Query Tag to Session
ALTER SESSION SET QUERY_TAG = '{"project":"volve", "name":"nabila natasha", "layer":"bronze", "task":"initial profiling", "day": "1"}';

USE WAREHOUSE TRANSFORM_WH;
USE DATABASE OG_ANALYTICS;

-- 1. Null counts per column (column of interest)
SELECT 
    COUNT(*)                                    AS total_rows,   -- 15634
    COUNT(*) - COUNT(dateprd)                   AS null_prod_date,  -- 0
    COUNT(*) - COUNT(npd_well_bore_name)        AS null_well_bore,  -- 0
    COUNT(*) - COUNT(avg_downhole_pressure)     AS null_avg_downhole_pressure,  -- 6654
    COUNT(*) - COUNT(avg_downhole_temperature)  AS null_avg_downhole_temp,   -- 6654
    COUNT(*) - COUNT(avg_dp_tubing)             AS null_avg_dp_tubing,  -- 6654
    COUNT(*) - COUNT(avg_whp_p)                 AS null_avg_whp_p,   -- 6479
    COUNT(*) - COUNT(avg_wht_p)                 AS null_avg_wht_p,   -- 6488
    COUNT(*) - COUNT(dp_choke_size)             AS null_dp_choke_size  -- 294
FROM BRONZE.DAILY_PRODUCTION_RAW;

SELECT 
    COUNT(*)                                    AS total_rows,
    COUNT(*) - COUNT(wellbore_name)             AS null_wellbore,
    COUNT(*) - COUNT(year)                      AS null_year,
    COUNT(*) - COUNT(month)                     AS null_month,
    COUNT(*) - COUNT(on_stream_hrs)             AS null_on_stream,
    COUNT(*) - COUNT(oil_sm3)                   AS null_oil,
    COUNT(*) - COUNT(gas_sm3)                   AS null_gas,
    COUNT(*) - COUNT(water_sm3)                 AS null_water,
    COUNT(*) - COUNT(gi_sm3)                   AS null_gi
FROM BRONZE.MONTHLY_PRODUCTION_RAW
WHERE wellbore_name != '' AND npd_code != '';  -- exclude second row which store units

-- 2. Duplicate check: same well + same date appearing more than once
SELECT
    npd_well_bore_name  AS wellbore_name,
    dateprd             AS prod_date,
    COUNT(*)            AS n
FROM BRONZE.DAILY_PRODUCTION_RAW
GROUP BY npd_well_bore_name, dateprd
HAVING COUNT(*) > 1    -- NO DUPLICATE
ORDER BY n DESC;   


SELECT
    wellbore_name       AS wellbore_name,
    month               AS month,
    year                AS year,
    COUNT(*)            AS n
FROM BRONZE.MONTHLY_PRODUCTION_RAW
GROUP BY wellbore_name, month, year
HAVING COUNT(*) > 1    -- NO DUPLICATE
ORDER BY n DESC;   

-- 3. Distinct well name spellings (catches inconsistent formatting across tables)
SELECT DISTINCT npd_well_bore_name FROM BRONZE.DAILY_PRODUCTION_RAW ORDER BY 1;  -- 7
SELECT DISTINCT wellbore_name 
FROM BRONZE.MONTHLY_PRODUCTION_RAW 
WHERE wellbore_name != '' AND npd_code != '' -- exclude second row which store units
ORDER BY 1;  -- 7

-- 4. Wells in daily but NOT in monthly (or vice versa)
-- cathes naming mismatches, extra spaces, different casting before break silently during join
SELECT DISTINCT npd_well_bore_name AS well_name FROM BRONZE.DAILY_PRODUCTION_RAW
MINUS
SELECT DISTINCT wellbore_name FROM BRONZE.MONTHLY_PRODUCTION_RAW 
WHERE wellbore_name != '';   -- NO RESULT

SELECT DISTINCT wellbore_name AS well_name FROM BRONZE.MONTHLY_PRODUCTION_RAW 
WHERE wellbore_name != ''
MINUS
SELECT DISTINCT npd_well_bore_name FROM BRONZE.DAILY_PRODUCTION_RAW;  -- NO RESULT

-- 5. Date format sanity check - confirm every dateprd matches the DD/MM/YY pattern before commit to TO_DATE(dateprd, ''DD/MM/YY) in silver
SELECT dateprd
FROM BRONZE.DAILY_PRODUCTION_RAW
WHERE TRY_TO_DATE(dateprd, 'YYYY-MM-DD') IS NULL  -- returns NULL instead of erroring data on bad format
LIMIT 20; -- NO RESULT

-- 6. Numeric columns that don't actually cast cleanly - since everything's STRING in bronze
SELECT bore_oil_vol
FROM BRONZE.DAILY_PRODUCTION_RAW
WHERE bore_oil_vol IS NOT NULL AND bore_oil_vol != ''
    AND TRY_TO_DECIMAL(bore_oil_vol, 18, 4) IS NULL
LIMIT 20;  -- NO RESULT

SELECT bore_gas_vol
FROM BRONZE.DAILY_PRODUCTION_RAW
WHERE bore_gas_vol IS NOT NULL AND bore_gas_vol != ''
    AND TRY_TO_DECIMAL(bore_gas_vol, 18, 4) IS NULL
LIMIT 20;  -- NO RESULT

SELECT bore_wat_vol
FROM BRONZE.DAILY_PRODUCTION_RAW
WHERE bore_wat_vol IS NOT NULL AND bore_wat_vol != ''
    AND TRY_TO_DECIMAL(bore_wat_vol, 18, 4) IS NULL
LIMIT 20;  -- NO RESULT

-- 7. Negative or physically nonsensical values
SELECT 
    COUNT(*)    AS negative_oil_rows
FROM BRONZE.DAILY_PRODUCTION_RAW
WHERE TRY_TO_DECIMAL(bore_oil_vol, 18, 4) < 0;  -- 0

SELECT 
    COUNT(*)    AS negative_gas_rows
FROM BRONZE.DAILY_PRODUCTION_RAW
WHERE TRY_TO_DECIMAL(bore_gas_vol, 18, 4) < 0;  -- 0

SELECT 
    COUNT(*)    AS negative_downhole_pressure
FROM BRONZE.DAILY_PRODUCTION_RAW
WHERE TRY_TO_DECIMAL(avg_downhole_pressure, 18, 4) < 0;  -- 0

SELECT 
    COUNT(*)    AS negative_downhole_temp
FROM BRONZE.DAILY_PRODUCTION_RAW
WHERE TRY_TO_DECIMAL(avg_downhole_temperature, 18, 4) < 0;  -- 0

SELECT 
    COUNT(*)    AS negative_choke_size
FROM BRONZE.DAILY_PRODUCTION_RAW
WHERE TRY_TO_DECIMAL(avg_choke_size_p, 18, 4) < 0;  -- 0

SELECT 
    COUNT(*)    AS negative_on_stream
FROM BRONZE.MONTHLY_PRODUCTION_RAW
WHERE TRY_TO_DECIMAL(on_stream_hrs, 18, 4) < 0;  -- 0

SELECT 
    COUNT(*)    AS negative_oil_sm3
FROM BRONZE.MONTHLY_PRODUCTION_RAW
WHERE TRY_TO_DECIMAL(oil_sm3, 18, 4) < 0;  -- 0

SELECT 
    COUNT(*)    AS negative_gas_sm3
FROM BRONZE.MONTHLY_PRODUCTION_RAW
WHERE TRY_TO_DECIMAL(gas_sm3, 18, 4) < 0;  -- 0

SELECT 
    COUNT(*)    AS negative_water_sm3
FROM BRONZE.MONTHLY_PRODUCTION_RAW
WHERE TRY_TO_DECIMAL(water_sm3, 18, 4) < 0;  -- 0

-- 8. Categorical sanity - small distinct value checks catch typos/unexpected categorical cheaply
SELECT well_type, COUNT(*) FROM BRONZE.DAILY_PRODUCTION_RAW GROUP BY well_type;
SELECT flow_kind, COUNT(*) FROM BRONZE.DAILY_PRODUCTION_RAW GROUP BY flow_kind;

-- 9. Date range coverage
SELECT 
    MIN(TRY_TO_DATE(dateprd, 'YYYY-MM-DD'))   AS earliest_date, -- 2007-09-01
    MAX(TRY_TO_DATE(dateprd, 'YYYY-MM-DD'))   AS latest_date    -- 2016-12-01
FROM BRONZE.DAILY_PRODUCTION_RAW; -- null

-- 10. Check for mixed date format
SELECT 
    COALESCE(
        TRY_TO_DATE(dateprd, 'YYYY-MM-DD'),
        TRY_TO_DATE(dateprd, 'DD-MM-YY')
    ) AS parsed_date
FROM BRONZE.DAILY_PRODUCTION_RAW;

SELECT 
    COUNT(TRY_TO_DATE(dateprd, 'DD-MM-YY')) as date_format
FROM BRONZE.DAILY_PRODUCTION_RAW;  -- 0


SELECT 
    COUNT(TRY_TO_DATE(dateprd, 'YYYY-MM-DD')) as date_format
FROM BRONZE.DAILY_PRODUCTION_RAW;  -- 15634 (all rows having YYYY-MM-DD format)
