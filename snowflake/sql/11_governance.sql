/***************************************************************************************************       
Project:      Volve Field Retrospective Economic & Production Review 
Task   :      GOVERNANCE (RLS, Masking, Tagging, Audit)
****************************************************************************************************/
USE ROLE SYSADMIN;   -- Governance Role -> Control access and security
ALTER SESSION SET QUERY_TAG = '{"project":"volve", "name":"nabila natasha", "layer":"gold", "task":"governance", "day": "4"}';
USE WAREHOUSE TRANSFORM_WH;
USE DATABASE OG_ANALYTICS;

-- 1. Grant read access to GOLD for the downstream roles
GRANT USAGE ON DATABASE OG_ANALYTICS TO ROLE VOLVE_ANALYST;
GRANT USAGE ON DATABASE OG_ANALYTICS TO ROLE VOLVE_VIEWER;

GRANT USAGE ON SCHEMA OG_ANALYTICS.GOLD TO ROLE VOLVE_ANALYST;
GRANT USAGE ON SCHEMA OG_ANALYTICS.GOLD TO ROLE VOLVE_VIEWER;

GRANT SELECT ON ALL TABLES IN SCHEMA OG_ANALYTICS.GOLD TO ROLE VOLVE_ANALYST;
GRANT SELECT ON ALL TABLES IN SCHEMA OG_ANALYTICS.GOLD TO ROLE VOLVE_VIEWER;

GRANT SELECT ON FUTURE TABLES IN SCHEMA OG_ANALYTICS.GOLD TO ROLE VOLVE_ANALYST;
GRANT SELECT ON FUTURE TABLES IN SCHEMA OG_ANALYTICS.GOLD TO ROLE VOLVE_VIEWER;

-- 2. Row Access Policy; VOLVE_VIEWER (simulated JV partner) only sees a subset of wells
SELECT DISTINCT well_name FROM GOLD.FACT_PRODUCTION ORDER BY 1;

-- Replace these well names with the specific wells that should be visible to the VOLVE_VIEWER (simulated JV partner)
CREATE OR REPLACE ROW ACCESS POLICY GOLD.PARTNER_WELL_POLICY
AS (well_name STRING) RETURNS BOOLEAN ->
CURRENT_ROLE() IN ('VOLVE_DE', 'VOLVE_ANALYST')  -- return TRUE -> can see the row (can see all wells)
OR (
    CURRENT_ROLE() = 'VOLVE_VIEWER'
    AND well_name IN ('15/9-F-1 C', '15/9-F-15 D')  -- VOLVE_VIEWER can only see rows where well_name either 15/9-F-1 C or 15/9-F-15 D
);

ALTER TABLE GOLD.FACT_PRODUCTION ADD ROW ACCESS POLICY GOLD.PARTNER_WELL_POLICY ON (well_name);  -- only FACT_PRODUCTION is protected
ALTER TABLE GOLD.DIM_WELL ADD ROW ACCESS POLICY GOLD.PARTNER_WELL_POLICY ON (well_name);   -- DIM_WELL is protected

-- If want to amend the ROW ACCESS POLICY - Must detach policy before replacing it (policy cannot be dropped while attached)
-- ALTER TABLE GOLD.FACT_PRODUCTION DROP ROW ACCESS POLICY GOLD.PARTNER_WELL_POLICY;

--  Test THE ROW ACCESS POLICY as role VOLVE_VIEWER
-- USE ROLE VOLVE_VIEWER;
-- SELECT DISTINCT WELL_NAME FROM GOLD.DIM_WELL;

-- 3. Dynamic Data Masking: mask a commercially-sensitive operational column values for the partner-viewer role
CREATE OR REPLACE MASKING POLICY GOLD.MASK_WELLHEAD_PRESSURE
AS (val NUMBER) RETURNS NUMBER ->
    CASE
        WHEN CURRENT_ROLE() IN ('VOLVE_DE', 'VOLVE_ANALYST') THEN val
        ELSE null
    END;
        
CREATE OR REPLACE MASKING POLICY GOLD.MASK_PARTNER_FLOAT
AS (val FLOAT) RETURNS FLOAT ->
    CASE   
        WHEN CURRENT_ROLE() IN ('VOLVE_DE', 'VOLVE_ANALYST') THEN val
        ELSE null
    END;

ALTER TABLE GOLD.FACT_PRODUCTION MODIFY COLUMN avg_whp SET MASKING POLICY GOLD.MASK_WELLHEAD_PRESSURE;
ALTER TABLE GOLD.REVENUE_DECOMPOSITION MODIFY COLUMN benchmark_revenue_usd SET MASKING POLICY GOLD.MASK_PARTNER_FLOAT;
ALTER TABLE GOLD.REVENUE_DECOMPOSITION MODIFY COLUMN benchmark_revenue_nok SET MASKING POLICY GOLD.MASK_PARTNER_FLOAT;

-- 4. Tagging: document which columns are governed and why
CREATE OR REPLACE TAG GOLD.SENSITIVE_LEVEL;

ALTER TABLE GOLD.FACT_PRODUCTION MODIFY COLUMN well_name SET TAG GOLD.SENSITIVE_LEVEL = 'row_filtered';
ALTER TABLE GOLD.DIM_WELL MODIFY COLUMN well_name SET TAG GOLD.SENSITIVE_LEVEL = 'row_filtered';
ALTER TABLE GOLD.FACT_PRODUCTION MODIFY COLUMN avg_whp SET TAG GOLD.SENSITIVE_LEVEL = 'partner_restricted';
ALTER TABLE GOLD.REVENUE_DECOMPOSITION MODIFY COLUMN benchmark_revenue_usd SET TAG GOLD.SENSITIVE_LEVEL = 'partner_restricted';
ALTER TABLE GOLD.REVENUE_DECOMPOSITION MODIFY COLUMN benchmark_revenue_nok SET TAG GOLD.SENSITIVE_LEVEL = 'partner_restricted';

-- POLICY_REFERENCES - see which table has the Row Access Policy, Masking Policy
SHOW ROW ACCESS POLICIES IN SCHEMA GOLD;
SELECT POLICY_NAME, POLICY_SCHEMA, REF_ENTITY_NAME, REF_ENTITY_DOMAIN, REF_COLUMN_NAME
FROM TABLE(INFORMATION_SCHEMA.POLICY_REFERENCES(
    POLICY_NAME => 'GOLD.PARTNER_WELL_POLICY'
));

-- POLICY_REFERENCES - see which table has the Row Access Policy, Masking Policy
SHOW MASKING POLICIES IN SCHEMA GOLD;
SELECT *
FROM TABLE(INFORMATION_SCHEMA.POLICY_REFERENCES(
    POLICY_NAME => 'GOLD.MASK_PARTNER_FLOAT'
));
SELECT *
FROM TABLE(INFORMATION_SCHEMA.POLICY_REFERENCES(
    POLICY_NAME => 'GOLD.MASK_WELLHEAD_PRESSURE'
));

SHOW TAGS IN SCHEMA GOLD;
SELECT *
FROM SNOWFLAKE.ACCOUNT_USAGE.TAGS
WHERE TAG_DATABASE = 'OG_ANALYTICS';

-- 5. Verify if it works: same query, different role, different result.
USE ROLE VOLVE_DE;
SELECT 
    COUNT(DISTINCT well_name)   AS wells_visible,   -- 6
    COUNT(*)                    AS rows_visible     -- 9143
FROM GOLD.FACT_PRODUCTION;
SELECT well_name, avg_whp FROM GOLD.FACT_PRODUCTION LIMIT 10;   -- all visible
SELECT * FROM GOLD.REVENUE_DECOMPOSITION LIMIT 10;              -- all columns visible

USE ROLE VOLVE_VIEWER;
SELECT 
    COUNT(DISTINCT well_name)   AS wells_visible,   -- 2
    COUNT(*)                    AS rows_visible     -- 1722
FROM GOLD.FACT_PRODUCTION;
SELECT well_name, avg_whp FROM GOLD.FACT_PRODUCTION LIMIT 10;   -- avg_whp null
SELECT * FROM GOLD.REVENUE_DECOMPOSITION LIMIT 10;              -- benchmark_revenue_usd & benchmark_revenue_nok null

-- 6. Audit Capability
-- NOTE: ACCOUNT_USAGE views can lag up to ~45 mins 
SELECT query_text, user_name, role_name, start_time
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE query_tag LIKE '%volve%'
ORDER BY start_time DESC;
LIMIT 100;

-- USE ROLE VOLVE_DE;
-- SELECT COLUMN_NAME, data_type
-- FROM INFORMATION_SCHEMA.COLUMNS
-- WHERE TABLE_SCHEMA = 'GOLD'
--   AND TABLE_NAME = 'FACT_PRODUCTION';

-- SHOW TABLES IN SCHEMA OG_ANALYTICS.GOLD;

-- DESC TABLE GOLD.FACT_PRODUCTION;

