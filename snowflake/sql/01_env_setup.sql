/***************************************************************************************************       
Project:      Volve Field Retrospective Economic & Production Review 
Task   :      Setup          
****************************************************************************************************/
USE ROLE ACCOUNTADMIN;
-- change timezone for entire ACCOUNT
ALTER ACCOUNT SET TIMEZONE = 'Asia/Kuala_Lumpur';

-- assign Query Tag to Session
ALTER SESSION SET QUERY_TAG = '{"project":"volve", "name":"nabila natasha", "layer":"bronze", "task":"setup", "day": "1"}';

-- 1. Create the functional roles
CREATE ROLE IF NOT EXISTS VOLVE_DE;
CREATE ROLE IF NOT EXISTS VOLVE_ANALYST;
CREATE ROLE IF NOT EXISTS VOLVE_VIEWER;

-- 2. Slot them into the standard role hierarchy
GRANT ROLE VOLVE_DE TO ROLE SYSADMIN;       -- SYSADMIN inherits the privileges of VOLVE_DE
GRANT ROLE VOLVE_ANALYST TO ROLE SYSADMIN;  -- SYSADMIN inherits the privileges of VOLVE_ANALYST
GRANT ROLE VOLVE_VIEWER TO ROLE SYSADMIN;   -- SYSADMIN inherits the privileges of VOLVE_VIEWER

-- 3. Grant the role to one user to simulate multiple personas
GRANT ROLE VOLVE_DE TO USER NABILA26;
GRANT ROLE VOLVE_ANALYST TO USER NABILA26;
GRANT ROLE VOLVE_VIEWER TO USER NABILA26;

-- 4. Let VOLVE_DE create it's own database (so it OWNS what it builds)
GRANT CREATE DATABASE ON ACCOUNT TO ROLE VOLVE_DE;

-- 5. Create 3 warehouses
CREATE WAREHOUSE IF NOT EXISTS LOAD_WH
    WAREHOUSE_SIZE = 'XSMALL'
    WAREHOUSE_TYPE = 'STANDARD'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE;

CREATE WAREHOUSE IF NOT EXISTS TRANSFORM_WH
    WAREHOUSE_SIZE = 'XSMALL'
    WAREHOUSE_TYPE = 'STANDARD'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE;

CREATE WAREHOUSE IF NOT EXISTS BI_WH
    WAREHOUSE_SIZE = 'XSMALL'
    WAREHOUSE_TYPE = 'STANDARD'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE;

-- 6. Assign warehouses to roles (governance mapping)
GRANT USAGE ON WAREHOUSE LOAD_WH TO ROLE VOLVE_DE;
GRANT USAGE ON WAREHOUSE TRANSFORM_WH TO ROLE VOLVE_DE;
GRANT USAGE ON WAREHOUSE BI_WH TO ROLE VOLVE_ANALYST;
GRANT USAGE ON WAREHOUSE BI_WH TO ROLE VOLVE_VIEWER;

-- 7. Resource monitor - monitor compute usage and spend
CREATE RESOURCE MONITOR IF NOT EXISTS OG_PROJECT_MONITOR
    WITH CREDIT_QUOTA = 50
    FREQUENCY = NEVER -- Can also be DAILY, MONTHLY, WEEKLY, YEARLY, or NEVER (for a one-time quota)
    START_TIMESTAMP = IMMEDIATELY
    TRIGGERS ON 75 PERCENT DO NOTIFY
             ON 90 PERCENT DO SUSPEND
             ON 100 PERCENT DO SUSPEND_IMMEDIATE;

-- 8. Apply Resource Monitor to the warehouses
ALTER WAREHOUSE LOAD_WH 
    SET RESOURCE_MONITOR = OG_PROJECT_MONITOR;
ALTER WAREHOUSE TRANSFORM_WH
    SET RESOURCE_MONITOR = OG_PROJECT_MONITOR;
ALTER WAREHOUSE BI_WH 
    SET RESOURCE_MONITOR = OG_PROJECT_MONITOR;