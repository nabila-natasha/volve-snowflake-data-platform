/***************************************************************************************************       
Project:      Volve Field Retrospective Economic & Production Review 
Task   :      Daily Production Batch 2 Load 
****************************************************************************************************/
USE ROLE VOLVE_DE;
ALTER SESSION SET QUERY_TAG = '{"project":"volve", "name":"nabila natasha", "layer":"silver", "task":"batch 2 load", "day": "3"}';
USE WAREHOUSE TRANSFORM_WH;
USE DATABASE OG_ANALYTICS;

-- 1. Batch 2 - Incremental arrival of remaining daily production data
-- Confirm current state BEFORE Batch 2 lands (should only cover < 2013-01-01)
SELECT COUNT(*) FROM SILVER.DAILY_PRODUCTION_CLEAN;  -- 7322
SELECT MAX(prod_date) AS latest_date_before_batch2 FROM SILVER.DAILY_PRODUCTION_CLEAN;   --2012-12-31

INSERT INTO SILVER.DAILY_PRODUCTION_CLEAN  -- 8312
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
    TRY_TO_DECIMAL(bore_wi_vol, 18, 5)              AS wi_vol,     
    TRIM(flow_kind)                                 AS flow_kind,
    TRIM(well_type)                                 AS well_type,
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
AND TO_DATE(dateprd, 'YYYY-MM-DD') >= '2013-01-01'; -- BATCH 2 2013-01-01 onwards

-- 2. Verify the total count same as in bronze
SELECT COUNT(*) AS bronze_rows FROM BRONZE.DAILY_PRODUCTION_RAW;  -- 15634
SELECT COUNT(*) AS silver_rows FROM SILVER.DAILY_PRODUCTION_CLEAN; -- 15634
SELECT MAX(prod_date) as latest_date_after_batch2 FROM SILVER.DAILY_PRODUCTION_CLEAN;  -- 2016-12-01