/***************************************************************************************************       
Project:      Volve Field Retrospective Economic & Production Review 
Task   :      GOLD FACT Dynamic Tables (Transformation Layer)
****************************************************************************************************/
USE ROLE VOLVE_DE;
ALTER SESSION SET QUERY_TAG = '{"project":"volve", "name":"nabila natasha", "layer":"gold", "task":"dynamic tables transformation", "day": "3"}';
USE WAREHOUSE TRANSFORM_WH;
USE DATABASE OG_ANALYTICS;

-- 1. GOLD.FACT_DAILY_PRODUCTION (Dynamic Table)
-- Core fact table - everything else chains off this.
-- DAILY_PRODUCTION join BRENT_PRICE join FX_RATES
CREATE OR REPLACE DYNAMIC TABLE GOLD.FACT_PRODUCTION
    TARGET_LAG = '1 hour'
    WAREHOUSE = 'TRANSFORM_WH'
AS
SELECT
    p.prod_date,
    p.well_name,
    p.well_type,
    p.oil_vol_sm3,
    p.oil_vol_sm3 * 6.2898                                          AS oil_vol_bbl, -- NEW: converted volume
    p.gas_vol_sm3,
    p.water_vol_sm3,
    p.avg_choke_size,
    p.dp_choke_size,
    p.avg_whp,
    p.is_shutin,
    b.brent_usd_bbl_filled,
    f.nok_per_usd,
    p.water_vol_sm3 / NULLIF(p.oil_vol_sm3 + p.water_vol_sm3, 0)    AS water_cut,  -- NULLIF(x, 0) means if x is 0 return NULL, otherwise return x. This is o prevent a division-by-zero error.
    -- FIXED: convert m3 to bbl BEFORE multiplying by $/bbl
    (p.oil_vol_sm3 * 6.2898) * b.brent_usd_bbl_filled                          AS est_revenue_usd,
    (p.oil_vol_sm3 * 6.2898) * b.brent_usd_bbl_filled * f.nok_per_usd          AS est_revenue_nok
FROM SILVER.DAILY_PRODUCTION_CLEAN p
LEFT JOIN SILVER.BRENT_PRICES_FILLED b
    ON p.prod_date = b.cal_date
LEFT JOIN SILVER.FX_RATES f           
    ON p.prod_date = f.rate_date
WHERE p.well_type = 'OP';

-- Verify if the batch 2 data already landed
SELECT COUNT(*) FROM GOLD.FACT_PRODUCTION; -- 9143
SELECT MAX(prod_date) AS latest_date FROM GOLD.FACT_PRODUCTION;   -- 2016-09-17

--  Verify if there's any null values in brent_usd_bbl_filled and nok_per_usd
SELECT COUNT(*) FROM GOLD.FACT_PRODUCTION WHERE brent_usd_bbl_filled IS NULL;   -- 0
SELECT COUNT(*) FROM GOLD.FACT_PRODUCTION WHERE nok_per_usd IS NULL;            -- 0