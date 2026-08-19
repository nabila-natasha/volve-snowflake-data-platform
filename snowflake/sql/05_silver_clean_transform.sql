/***************************************************************************************************       
Project:      Volve Field Retrospective Economic & Production Review 
Task   :      Clean, Transform, Iceberg, Flatten JSON    
****************************************************************************************************/
USE ROLE VOLVE_DE;

ALTER SESSION SET QUERY_TAG = '{"project":"volve", "name":"nabila natasha", "layer":"silver", "task":"clean_transform_iceberg", "day": "2"}';

USE WAREHOUSE TRANSFORM_WH;
USE DATABASE OG_ANALYTICS;

-- 1. Clean Daily Production and land it as Iceberg table (batching)
CREATE OR REPLACE ICEBERG TABLE SILVER.DAILY_PRODUCTION_CLEAN
    CATALOG = 'SNOWFLAKE'
AS
SELECT
    TO_DATE(dateprd, 'YYYY-MM-DD')                  AS prod_date,
    TRIM(well_bore_code)                            AS well_code_no,
    TRIM(npd_well_bore_code)                        AS well_code,
    TRIM(npd_well_bore_name)                        AS well_name,
    TRIM(npd_field_code)                            AS field_code,
    TRIM(npd_field_name)                            AS field_name,
    TRIM(npd_facility_code)                         AS facility_code,
    TRIM(npd_facility_name)                         AS facility_name,
    TRY_TO_DECIMAL(on_stream_hrs, 10, 4)            AS on_stream_hrs,
    TRY_TO_DECIMAL(avg_downhole_pressure, 18, 5)    AS avg_downhole_pressure,
    TRY_TO_DECIMAL(avg_downhole_temperature, 18, 5) AS avg_downhole_temp,
    TRY_TO_DECIMAL(avg_dp_tubing, 18, 5)            AS avg_dp_tubing,
    TRY_TO_DECIMAL(avg_annulus_press, 18, 5)        AS avg_annulus_press,
    TRY_TO_DECIMAL(avg_choke_size_p, 18, 5)         AS avg_choke_size,
    TRIM(avg_choke_uom)                             AS choke_uom,
    TRY_TO_DECIMAL(avg_whp_p, 18, 5)                AS avg_whp,
    TRY_TO_DECIMAL(avg_wht_p, 18, 5)                AS avg_wht,
    TRY_TO_DECIMAL(dp_choke_size, 18, 5)            AS dp_choke_size,
    TRY_TO_DECIMAL(bore_oil_vol, 18, 5)             AS oil_vol_sm3,
    TRY_TO_DECIMAL(bore_gas_vol, 18, 5)             AS gas_vol_sm3,
    TRY_TO_DECIMAL(bore_wat_vol, 18, 5)             AS water_vol_sm3,
    TRY_TO_DECIMAL(bore_wi_vol, 18, 5)              AS wi_vol,        -- left NULL as NULL, no COALESCE
    TRIM(flow_kind)                                 AS flow_kind,
    TRIM(well_type)                                 AS well_type,
    -- shut-in flag: only meaningful for producing (OP) wells;
    -- injector (WI) wells legitimately have zero oil/gas/water by design,
    -- and their on_stream_hrs appears unreliable relative to injection volume
    -- (see data quality log) — both are reasons to exclude WI here
    CASE
        WHEN well_type = 'OP'
         AND COALESCE(TRY_TO_DECIMAL(on_stream_hrs, 10, 4), 0) = 0
         AND COALESCE(TRY_TO_DECIMAL(bore_oil_vol, 18, 5), 0) = 0
         AND COALESCE(TRY_TO_DECIMAL(bore_gas_vol, 18, 5), 0) = 0
         AND COALESCE(TRY_TO_DECIMAL(bore_wat_vol, 18, 5), 0) = 0
        THEN TRUE ELSE FALSE
    END                                              AS is_shutin
FROM BRONZE.DAILY_PRODUCTION_RAW
WHERE TO_DATE(dateprd, 'YYYY-MM-DD') IS NOT NULL -- excludes any row where the date genuinely couldn't parse
AND TO_DATE(dateprd, 'YYYY-MM-DD') < '2013-01-01'; -- BATCH 1 ONLY - the rest lands later 

-- 2. Validate Daily Production counts immediately
SELECT COUNT(*) AS batch1_rows FROM SILVER.DAILY_PRODUCTION_CLEAN;  -- 7322 and compare after batch 2 lands
SELECT COUNT(*) AS bronze_rows FROM BRONZE.DAILY_PRODUCTION_RAW;    -- 15634
-- these should be close; any gap = rows dropped by the WHERE clause, and you should know exactly why
SELECT COUNT(*) AS shutin_days FROM SILVER.DAILY_PRODUCTION_CLEAN WHERE is_shutin = TRUE;  -- 341

-- 3. Clean Monthly Production and land it as Iceberg Table 
-- (one-shot, no batching needed)
CREATE OR REPLACE ICEBERG TABLE SILVER.MONTHLY_PRODUCTION_CLEAN
    CATALOG = 'SNOWFLAKE'
AS
SELECT 
    TRIM(wellbore_name)                     AS well_name,
    TRIM(npd_code)                          AS npd_code,
    TRY_TO_DECIMAL(year, 10, 0)             AS prod_year,
    TRY_TO_DECIMAL(month, 10, 0)            AS prod_month,
    TRY_TO_DECIMAL(on_stream_hrs, 10, 4)    AS on_stream_hrs,
    TRY_TO_DECIMAL(oil_sm3, 18, 5)          AS oil_sm3,
    TRY_TO_DECIMAL(gas_sm3, 18, 5)          AS gas_sm3,
    TRY_TO_DECIMAL(water_sm3, 18, 5)        AS water_sm3,
    TRY_TO_DECIMAL(gi_sm3, 18, 5)           AS gi_sm3,
    TRY_TO_DECIMAL(wi_sm3, 18, 5)           AS wi_sm3
FROM BRONZE.MONTHLY_PRODUCTION_RAW
WHERE wellbore_name IS NOT NULL AND wellbore_name != ''; 

-- 4. Validate Monthly Production counts immediately
SELECT COUNT(*) AS silver_rows FROM SILVER.MONTHLY_PRODUCTION_CLEAN;  -- 526 (removed 1 row which store units)
SELECT COUNT(*) AS bronze_rows FROM BRONZE.MONTHLY_PRODUCTION_RAW;    -- 527

-- 5. Flattened Brent and land in Iceberg Table
CREATE OR REPLACE ICEBERG TABLE SILVER.BRENT_PRICES
    CATALOG = 'SNOWFLAKE'
AS
SELECT 
    f.value:period::DATE                    AS price_date,
    f.value:value::FLOAT                    AS brent_usd_bbl,
    f.value:"series-description"::STRING    AS series_desc,
    f.value:units::STRING                   AS units
FROM BRONZE.BRENT_RAW,
LATERAL FLATTEN(input => raw_payload:response:data) f;

-- 6. Sanity check: row count should roughly match response.total from JSON -- "total": 9948
SELECT COUNT(*) AS total_rows FROM SILVER.BRENT_PRICES;  -- 9948
SELECT * FROM SILVER.BRENT_PRICES;

