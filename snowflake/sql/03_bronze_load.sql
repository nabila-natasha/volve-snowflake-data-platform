/***************************************************************************************************       
Project:      Volve Field Retrospective Economic & Production Review 
Task   :      Load File into Bronze        
****************************************************************************************************/
USE ROLE VOLVE_DE;

-- assign Query Tag to Session
ALTER SESSION SET QUERY_TAG = '{"project":"volve", "name":"nabila natasha", "layer":"bronze", "task":"load file into bronze", "day": "1"}';

USE WAREHOUSE LOAD_WH;

-- Upload the files to the stage (raw file storage) via Snowsight
-- Sanity check what actually landed to the BRONZE.RAW_STAGE
LIST @OG_ANALYTICS.BRONZE.RAW_STAGE;

/*
-- Sanity check on the csv file column names
CREATE FILE FORMAT IF NOT EXISTS BRONZE.CSV_FORMAT_HEADER
    TYPE = 'CSV'
    PARSE_HEADER = TRUE -- this is so that we can see the column name
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('', 'NULL', 'NaN')
    EMPTY_FIELD_AS_NULL = TRUE;

SELECT * 
FROM TABLE(
INFER_SCHEMA(
    LOCATION => '@OG_ANALYTICS.BRONZE.RAW_STAGE/production/daily_production.csv',
    FILE_FORMAT => 'OG_ANALYTICS.BRONZE.CSV_FORMAT_HEADER'
    )
);

DROP FILE FORMAT IF EXISTS BRONZE.CSV_FORMAT_HEADER;
*/

-- Bronze table: Daily Production (raw, minimal typing
-- bronze should mirror the source as closely as possible)
CREATE OR REPLACE TABLE BRONZE.DAILY_PRODUCTION_RAW (
    dateprd                     STRING,  -- kept as STRING in bronze on purpose; cast in silver
    well_bore_code              STRING, 
    npd_well_bore_code          STRING,
    npd_well_bore_name          STRING,
    npd_field_code              STRING,
    npd_field_name              STRING,
    npd_facility_code           STRING,
    npd_facility_name           STRING,
    on_stream_hrs               STRING,
    avg_downhole_pressure       STRING,
    avg_downhole_temperature    STRING,
    avg_dp_tubing               STRING,
    avg_annulus_press           STRING,
    avg_choke_size_p            STRING,
    avg_choke_uom               STRING,
    avg_whp_p                   STRING,
    avg_wht_p                   STRING,
    dp_choke_size               STRING,
    bore_oil_vol                STRING,
    bore_gas_vol                STRING,
    bore_wat_vol                STRING,
    bore_wi_vol                 STRING,
    flow_kind                   STRING,
    well_type                   STRING
);

CREATE OR REPLACE TABLE BRONZE.MONTHLY_PRODUCTION_RAW (
    wellbore_name    STRING,
    npd_code         STRING,
    year             STRING,
    month            STRING,
    on_stream_hrs    STRING,
    oil_sm3          STRING,
    gas_sm3          STRING,
    water_sm3        STRING,
    gi_sm3           STRING,
    wi_sm3           STRING
);

-- Brent JSON: single variant column, exactly as it arrives — do NOT try
-- to type this at load time, that's what VARIANT + FLATTEN on Day 3 is for
CREATE OR REPLACE TABLE BRONZE.BRENT_RAW (
    raw_payload VARIANT
);

-- daily_production_raw table load
COPY INTO BRONZE.DAILY_PRODUCTION_RAW
FROM @OG_ANALYTICS.BRONZE.RAW_STAGE/production/daily_production.csv
    FILE_FORMAT = (FORMAT_NAME = 'BRONZE.CSV_FORMAT')
    ON_ERROR = 'CONTINUE';  -- CONTINUE so one bad row doesn't kill the whole load;
                            -- check COPY_HISTORY / rejected rows afterward

-- monthly_production_raw table load
COPY INTO BRONZE.MONTHLY_PRODUCTION_RAW
FROM @OG_ANALYTICS.BRONZE.RAW_STAGE/production/monthly_production.csv
    FILE_FORMAT = (FORMAT_NAME = 'BRONZE.CSV_FORMAT')
    ON_ERROR = 'CONTINUE';

-- Clear out the incomplete load first
-- TRUNCATE TABLE BRONZE.BRENT_RAW;

-- brent_raw table load
COPY INTO BRONZE.BRENT_RAW
FROM @OG_ANALYTICS.BRONZE.RAW_STAGE/brent/eia_brent_crude.json
    FILE_FORMAT = (FORMAT_NAME = 'BRONZE.JSON_FORMAT')
    ON_ERROR = 'CONTINUE';

-- Verify counts (compare to response.total in the JSON and what expected from csv)
SELECT COUNT(*) AS daily_rows   FROM BRONZE.DAILY_PRODUCTION_RAW;  -- 15634
SELECT COUNT(*) AS monthly_rows FROM BRONZE.MONTHLY_PRODUCTION_RAW;  -- 527
SELECT * FROM BRONZE.MONTHLY_PRODUCTION_RAW WHERE wellbore_name IS NULL OR wellbore_name = '';
SELECT raw_payload:response:total::INT AS reported_brent_rows FROM BRONZE.BRENT_RAW;  -- 9948

-- Check load history for errors (works even if COPY loaded 0 new rows)
SELECT *
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME => 'OG_ANALYTICS.BRONZE.DAILY_PRODUCTION_RAW',
    START_TIME => DATEADD(HOUR, -1, CURRENT_TIMESTAMP())   -- only show load events from the last hour
))
ORDER BY LAST_LOAD_TIME DESC
LIMIT 5;

SELECT *
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME => 'OG_ANALYTICS.BRONZE.MONTHLY_PRODUCTION_RAW',
    START_TIME => DATEADD(HOUR, -1, CURRENT_TIMESTAMP())   -- only show load events from the last hour
))
ORDER BY LAST_LOAD_TIME DESC
LIMIT 5;

SELECT *
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME => 'OG_ANALYTICS.BRONZE.BRENT_RAW',
    START_TIME => DATEADD(HOUR, -1, CURRENT_TIMESTAMP())   -- only show load events from the last hour
))
ORDER BY LAST_LOAD_TIME DESC
LIMIT 5;