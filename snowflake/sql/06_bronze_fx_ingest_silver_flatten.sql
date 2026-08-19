/***************************************************************************************************       
Project:      Volve Field Retrospective Economic & Production Review 
Task   :      USD-NOK FX Rate JSON Ingestion       
****************************************************************************************************/
USE ROLE VOLVE_DE;
ALTER SESSION SET QUERY_TAG = '{"project":"volve", "name":"nabila natasha", "layer":"bronze_silver", "task":"fx_raw_ingestion", "day": "3"}';
USE WAREHOUSE LOAD_WH;
USE DATABASE OG_ANALYTICS;

USE SCHEMA BRONZE;

LIST @OG_ANALYTICS.BRONZE.RAW_STAGE;

-- 1. Create FX JSON table, not flatten
CREATE OR REPLACE TABLE BRONZE.FX_RAW (
    raw_payload VARIANT
);

-- 2. FX raw table load - reuse the existing JSON FILE FORMAT
COPY INTO BRONZE.FX_RAW
FROM @OG_ANALYTICS.BRONZE.RAW_STAGE/fx/usd_nok_fx_rates.json
    FILE_FORMAT = (FORMAT_NAME = 'BRONZE.JSON_FORMAT')
    ON_ERROR = 'CONTINUE';

SELECT *
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME => 'OG_ANALYTICS.BRONZE.FX_RAW',
    START_TIME => DATEADD(HOUR, -1, CURRENT_TIMESTAMP())   -- only show load events from the last hour
))
ORDER BY LAST_LOAD_TIME DESC
LIMIT 5;

-- 3. Flattened FX and land in Iceberg Table
USE WAREHOUSE TRANSFORM_WH;
USE SCHEMA SILVER;

CREATE OR REPLACE ICEBERG TABLE SILVER.FX_RATES
    CATALOG = 'SNOWFLAKE'
AS 
SELECT
    f.value:date::DATE      AS rate_date,
    f.value:rate::FLOAT     AS nok_per_usd
FROM BRONZE.FX_RAW,
LATERAL FLATTEN(input => raw_payload) f; -- flattening the array itself, not a nested key 

-- 4. Sanity check: row count
SELECT COUNT(*) FROM SILVER.FX_RATES;  -- 3410 (same as payload length)
SELECT MIN(rate_date), MAX(rate_date) FROM SILVER.FX_RATES;
SELECT * FROM SILVER.FX_RATES;
