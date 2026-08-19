"""***************************************************************************************************
Project:      Volve Field Retrospective Economic & Production Review
Task   :      Pandas Profiling
****************************************************************************************************"""
from snowflake.snowpark.context import get_active_session
import pandas as pd

# 1. Get the session that's already acive in the Workspace
#    (no account/user/password needed - already authenticated
#    to Snowsight and the Worksapce inherits that session)
session = get_active_session()

# Optional: set database/schema/warehouse/rile for this session if not
# already set by the Workspace defaults.
session.use_role("VOLVE_DE")
session.use_warehouse("TRANSFORM_WH")
session.use_database("OG_ANALYTICS")
session.use_schema("BRONZE")

# 2. Add query tag to this session
session.sql(
    """ALTER SESSION SET QUERY_TAG = 
        '{"project":"volve", "name":"nabila natasha", "layer":"bronze", "task":"pandas profiling", "day":"1"}'"""
).collect()

# 3. Pull bronze table into a pandas DataFrame
print("---DAILY PRODUCTION RESULTS---")
daily_df = session.table("BRONZE.DAILY_PRODUCTION_RAW").to_pandas()

# Snowflake stores unquoted identifiers in UPPERCASE, so normalize column
# names to lowercase to match the names used in SQL/script
daily_df.columns = [c.lower() for c in daily_df.columns]

# 4. Basic Profile
print(daily_df.shape)           # (rows, columns)
print(daily_df.dtypes)          # confirms everything came in as object/string
print(daily_df.isnull().sum())  # null counts per column — cross-check vs SQL numbers
print(daily_df.nunique())       # distinct value counts per column

# 5. Date column check - ties back to SQL finding that datepdr is 'YYYY-MM_DD'
daily_df["dateprd_parsed"] = pd.to_datetime(daily_df["dateprd"], format="%Y-%m-%d", errors="coerce")
print(f"Unparseable dateprd rows: {daily_df['dateprd_parsed'].isna().sum()}")
print(f"Earliest data: {daily_df['dateprd_parsed'].min()}")
print(f"Latest data: {daily_df['dateprd_parsed'].max()}")

# 6. Numeric columns, cast for real stats
numeric_cols = [
    "avg_downhole_pressure", "avg_downhole_temperature", "avg_dp_tubing",
    "avg_choke_size_p", "avg_whp_p", "avg_wht_p", "dp_choke_size", 
    "bore_oil_vol", "bore_gas_vol", "bore_wat_vol", "bore_wi_vol"
]
for col in numeric_cols:
    daily_df[col + "_NUM"] = pd.to_numeric(daily_df[col], errors="coerce")  # equivalent to TRY_TO_DECIMAL - turns unparseable values into NaN instead of raising
print(daily_df[[c + "_NUM" for c in numeric_cols]].describe())

# 7. Duplicate check (should match SQL result of zero)
dupe_count = daily_df.duplicated(subset=["npd_well_bore_name", "dateprd"]).sum()
print(f"Duplicate well+date rows: {dupe_count}")

# 8. Rows where the numeric cast failed (i.e. bad/unexpected text)
bad_oil_rows = daily_df[daily_df["bore_oil_vol"].notna() & daily_df["bore_oil_vol_NUM"].isna()]
print(f"Rows with unparseable bore_oil_vol: {len(bad_oil_rows)}")

bad_gas_rows = daily_df[daily_df["bore_gas_vol"].notna() & daily_df["bore_gas_vol_NUM"].isna()]
print(f"Rows with unparseable bore_gas_vol: {len(bad_gas_rows)}")

bad_wat_rows = daily_df[daily_df["bore_wat_vol"].notna() & daily_df["bore_wat_vol_NUM"].isna()]
print(f"Rows with unparseable bore_wat_vol: {len(bad_wat_rows)}")

bad_wi_rows = daily_df[daily_df["bore_wi_vol"].notna() & daily_df["bore_wi_vol_NUM"].isna()]
print(f"Rows with unparseable bore_wi_vol: {len(bad_wi_rows)}")

# 3. Pull bronze table into a pandas DataFrame
print("\n---MONTHLY PRODUCTION RESULTS---")
monthly_df = session.table("BRONZE.MONTHLY_PRODUCTION_RAW").to_pandas()

# normalize column names to lowercase to match the names used in SQL/script
monthly_df.columns = [c.lower() for c in monthly_df.columns]

# 4. Basic Profile
print(monthly_df.shape)           # (rows, columns)
print(monthly_df.dtypes)          # confirms everything came in as object/string
print(monthly_df.isnull().sum())  # null counts per column — cross-check vs SQL numbers
print(monthly_df.nunique())       # distinct value counts per column

# 6. Numeric columns, cast for real stats
numeric_cols = [
    "on_stream_hrs", "oil_sm3", "gas_sm3",
    "water_sm3", "gi_sm3", "wi_sm3"
]
for col in numeric_cols:
    monthly_df[col + "_NUM"] = pd.to_numeric(monthly_df[col], errors="coerce")  # equivalent to TRY_TO_DECIMAL - turns unparseable values into NaN instead of raising
print(monthly_df[[c + "_NUM" for c in numeric_cols]].describe())

# 7. Duplicate check (should match SQL result of zero)
dupe_count = monthly_df.duplicated(subset=["wellbore_name", "month"]).sum()
print(f"Duplicate well+month rows: {dupe_count}")

# 8. Rows where the numeric cast failed (i.e. bad/unexpected text)
on_stream_rows = monthly_df[monthly_df["on_stream_hrs"].notna() & monthly_df["on_stream_hrs_NUM"].isna()]
print(f"Rows with unparseable on_stream: {len(on_stream_rows)}")

oil_rows = monthly_df[monthly_df["oil_sm3"].notna() & monthly_df["oil_sm3_NUM"].isna()]
print(f"Rows with unparseable oil: {len(oil_rows)}")

gas_rows = monthly_df[monthly_df["gas_sm3"].notna() & monthly_df["gas_sm3_NUM"].isna()]
print(f"Rows with unparseable gas: {len(gas_rows)}")

water_rows = monthly_df[monthly_df["water_sm3"].notna() & monthly_df["water_sm3_NUM"].isna()]
print(f"Rows with unparseable water: {len(water_rows)}")

gi_rows = monthly_df[monthly_df["gi_sm3"].notna() & monthly_df["gi_sm3_NUM"].isna()]
print(f"Rows with unparseable gi: {len(gi_rows)}")

wi_rows = monthly_df[monthly_df["wi_sm3"].notna() & monthly_df["wi_sm3_NUM"].isna()]
print(f"Rows with unparseable wi: {len(wi_rows)}")

    