/***************************************************************************************************       
Project:      Volve Field Retrospective Economic & Production Review 
Task   :      Build the Pipeline Skeleton         
****************************************************************************************************/
USE ROLE VOLVE_DE;

-- assign Query Tag to Session
ALTER SESSION SET QUERY_TAG = '{"project":"volve", "name":"nabila natasha", "layer":"bronze", "task":"build pipeline", "day": "1"}';

USE WAREHOUSE LOAD_WH;

-- 1. Create Database
CREATE DATABASE IF NOT EXISTS OG_ANALYTICS;

-- 2. Create Schemas
CREATE SCHEMA IF NOT EXISTS OG_ANALYTICS.BRONZE;  -- raw, as-landed
CREATE SCHEMA IF NOT EXISTS OG_ANALYTICS.SILVER;  -- cleaned, typed
CREATE SCHEMA IF NOT EXISTS OG_ANALYTICS.GOLD;    -- star schema, analytics-ready

-- 3. Switch schema context before creating stage else the file will land in the wrong place
USE DATABASE OG_ANALYTICS;
USE SCHEMA BRONZE;

-- 3. Internal Stage holds both source files, in separate subfolders
-- Dont't need two stages - just PUT to different paths within this stage
CREATE STAGE IF NOT EXISTS RAW_STAGE
    DIRECTORY = (ENABLE = TRUE)   -- internal stage
    COMMENT = 'Landing Zone for raw Volve production files and EIA Brent JSON';

-- 4. File Formats
CREATE FILE FORMAT IF NOT EXISTS BRONZE.CSV_FORMAT
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('', 'NULL', 'NaN')
    EMPTY_FIELD_AS_NULL = TRUE;

CREATE FILE FORMAT IF NOT EXISTS BRONZE.JSON_FORMAT
    TYPE = 'JSON'
    STRIP_OUTER_ARRAY = FALSE;  -- EIA payload is one object with a nested "data" array, not bare array