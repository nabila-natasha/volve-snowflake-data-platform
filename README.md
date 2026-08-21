# Volve Oil & Gas Data Platform

An end-to-end oil & gas data platform and analytics project built with **Snowflake (Iceberg Tables, Dynamic Tables), Python, REST APIs, JSON, SQL, and Power BI**.

This project demonstrates how publicly available oil & gas production data and external market data can be ingested, cleaned, governed, modelled, and served as an analytical data platform — including working through and documenting real data-quality issues along the way, rather than starting from a pre-cleaned dataset.

The project uses historical **Volve field production data**, **Brent crude oil benchmark prices from the U.S. Energy Information Administration (EIA) Open Data API**, and **USD/NOK foreign exchange rates from the Frankfurter API**.

---

## Project Overview

The central business question addressed by this project is:

> **How does well-level oil production performance change over time, and what is the indicative production value when external crude-oil market prices are applied — and how much of that value change is driven by production volume versus market price?**

The overall workflow is:

```text
Source Data
    ↓
Python / REST API Ingestion
    ↓
Snowflake Bronze
    ↓
Snowflake VARIANT / JSON Processing
    ↓
Silver Transformation (Iceberg Tables)
    ↓
Dynamic Tables
    ↓
Gold Analytical Model (Star Schema)
    ↓
Power BI
```

The project demonstrates both **data engineering** and **analytics engineering** concepts in an oil & gas context.

---

# Business Objectives

## Production & Reservoir Analysis

### 1. Production Decline

**Question:**

> How does oil, gas, and water production change over time at well level and field level?

The analysis examines oil, gas, and water production trends at both well and field level, providing a simplified production decline analysis using real historical production data.

---

### 2. Water Cut

**Question:**

> Which wells show increasing water cut over time?

Water cut is calculated as:

```text
Water Cut =
Water Production
-----------------------------
Oil Production + Water Production
```

Note: this is a **volume-weighted** ratio (sum of water ÷ sum of total liquid over the period), not a naive average of daily ratios — averaging pre-computed daily percentages directly would distort the result by giving equal weight to low-volume and high-volume days.

Increasing water cut can indicate reservoir maturity / water breakthrough. The analysis identifies wells where water contribution increases relative to total liquid production over time.

---

### 3. Choke and Wellhead Performance

**Question:**

> Is there an observable relationship between choke size, wellhead pressure, and oil production rate?

The project combines choke size (% opening), average wellhead pressure, and oil production rate to investigate operational choke-management behaviour alongside production outcomes.

---

### 4. Downtime and Shut-ins

**Question:**

> How much production was associated with downtime or shut-in periods, and were shut-ins concentrated in short, clustered events or long, scattered ones?

Consecutive shut-in days are grouped into discrete downtime **events** (not just a count of shut-in days) using a gaps-and-islands SQL pattern, giving each event a start date, end date, and duration. This distinguishes a few short maintenance-style events from a small number of long outages.

The project only uses classifications supported by the source data and does not infer planned/unplanned causes where that information isn't available.

---

# Economic Analysis

## 5. Indicative Production Value

**Question:**

> What is the estimated notional production value when historical Brent benchmark prices are applied to oil production, in both USD and NOK?

```text
Indicative Production Value (USD)
=
Oil Production Volume (bbl) × Brent Benchmark Price (USD/bbl)
```

Production volume is sourced in Sm³ and explicitly converted to barrels (× 6.2898 bbl/m³, the standard volume conversion factor) before being multiplied against the USD/bbl benchmark price — the two figures cannot be combined directly without this conversion. A NOK-denominated figure is also calculated by applying the historical USD/NOK exchange rate, since Volve is a Norwegian asset that would, in reality, have been managed in NOK.

This is **not realized company revenue**. The calculation excludes crude quality differentials, transportation costs, royalties, taxes, operating expenditure, marketing costs, contractual pricing, and realized sales prices. The dashboard labels this **"Total Revenue"** for readability, but it should be understood throughout as an **indicative / notional value**, not an audited financial figure.

---

## 6. Well Value Contribution

**Question:**

> Which wells contribute the greatest cumulative indicative production value?

Wells are ranked by cumulative indicative value with a running percentage-of-total, supporting Pareto / concentration analysis — i.e. whether value is concentrated in a small number of wells or spread evenly.

---

## 7. Price vs Volume

**Question:**

> How much of the change in indicative production value is associated with production volume versus benchmark price?

The project decomposes the change in indicative value into a **production volume effect**, a **price effect**, and a **volume-price interaction term** (since revenue is multiplicative, not additive — a simple two-way split alone does not fully reconcile when both drivers move at the same time). The reconciliation (`volume effect + price effect + interaction = actual change`) was validated directly in SQL.

**Finding:** across the field's producing life, declining production volume — not falling Brent price — appears to be the larger driver of the reduction in indicative value over time. This is a meaningful distinction: a naive read of the "revenue vs. Brent price" chart alone could wrongly suggest price was the main driver, when the decomposition shows the underlying decline curve was doing more of the work.

---

## 8. Brent Price Scenario Analysis

**Question:**

> How would indicative field value change under a different assumed Brent price?

A Power BI **What-If parameter** lets the user select a Brent price assumption and see recalculated total field value. This is explicitly a **historical sensitivity tool, not a forecast** — it answers "what would this field's value have looked like if Brent had averaged $X," using actual historical production, not a prediction of future prices or volumes.

---

# Data Sources

## Volve Production Data

Historical Volve field daily and monthly production/operational data (oil, gas, water volumes, choke size, wellhead pressure, well type). The original source workbook is not redistributed in this repository.

## EIA Brent Crude Oil Prices

Retrieved via the U.S. Energy Information Administration Open Data API (nested JSON). Note: the EIA API paginates results at 5,000 records per call — retrieving the full historical series required iterating through multiple pages rather than a single request.

```text
EIA REST API → JSON Response → Python → Snowflake Bronze → VARIANT → LATERAL FLATTEN → Typed Relational Columns
```

## USD/NOK Foreign Exchange Rates

Retrieved via the Frankfurter API, demonstrating a second, structurally different external API integrated into the same platform (a flat array of records, versus EIA's nested object-with-array response — handled with a different `LATERAL FLATTEN` pattern).

---

# Architecture

```text
SOURCE → INGESTION → BRONZE → SILVER (Iceberg) → DYNAMIC TABLES → GOLD (Star Schema) → POWER BI
```

Detailed architecture documentation is available in `architecture/README.md` and `docs/methodology.md`.

---

# Snowflake Data Architecture

## Bronze Layer

Preserves source data in raw form. Columns are deliberately kept as `STRING` (not typed) at this stage — typing too early means a single malformed value could fail an entire load. Semi-structured API payloads (Brent, FX) are stored whole in a `VARIANT` column, unflattened.

## Silver Layer

Standardizes and cleans Bronze data: type casting (`TRY_TO_DATE`, `TRY_TO_DECIMAL` — tolerant of bad values, converting them to NULL rather than failing the load), date-format resolution, an encoding fix (mangled UTF-8 characters in a facility name), exclusion of a hidden units-metadata row embedded in the monthly production file, and forward/backward-filling of Brent and FX prices onto non-trading days (weekends/holidays) using `LAST_VALUE`/`FIRST_VALUE` window functions.

Several Silver tables (`DAILY_PRODUCTION_CLEAN`, `MONTHLY_PRODUCTION_CLEAN`, `BRENT_PRICES`, `BRENT_PRICES_FILLED`) are built as **Snowflake-managed Iceberg Tables** — genuine Iceberg-format (Parquet + metadata) tables, using Snowflake's own managed catalog and storage rather than an external S3 volume, since this project was built without an AWS account. This means the format is open, but the storage location is not currently externally reachable by another engine (e.g. Databricks) — pairing this with an external volume on cloud storage would be the natural next step for true multi-engine access. The raw `VARIANT` Bronze tables are kept as standard (non-Iceberg) tables, since Iceberg's structured format is not a good fit for semi-structured `VARIANT` columns.

## Dynamic Tables

Used in the transformation layer for declarative, automatically-refreshed derived datasets — a `TARGET_LAG` is set once, and Snowflake manages the refresh schedule and (where possible) incremental computation.

Incremental behaviour was explicitly tested: an initial batch of production data was loaded, the full Dynamic Table chain built on top, and a second batch was inserted into Silver afterward — confirming the Gold layer picked up the new records automatically without any change to the transformation SQL.

One nuance worth noting: `DOWNTIME_EVENTS` uses a window function (`ROW_NUMBER()` over an unbounded, date-ordered partition) to group consecutive shut-in days into discrete events. This pattern cannot support Snowflake's incremental refresh — a single new row can shift the ranking of every later row in the same partition — so this table runs in `FULL` refresh mode, while the rest of the Gold layer refreshes incrementally. This is expected, not a defect.

## Gold Layer

Analytical datasets designed for Power BI consumption, following a **Star Schema**:

```text
FACT_PRODUCTION
DIM_WELL
DIM_DATE
WELL_DECLINE_TREND
WATER_CUT_TREND
DOWNTIME_EVENTS
REVENUE_DECOMPOSITION
WELL_VALUE_RANKING
```

---

# Dimensional Modelling

## FACT_PRODUCTION

Daily well-level production observations: oil/gas/water volume (Sm³ and converted bbl), choke size, wellhead pressure, shut-in flag, Brent price, FX rate, and indicative revenue in both USD and NOK.

## DIM_WELL

Descriptive well-level attributes (field, facility, first/last producing date).

**Slowly Changing Dimension (SCD) note:** some wells changed classification (producer ↔ injector) over their lifetime. `DIM_WELL` uses **SCD Type 1** — each well's most recent known attributes — after quantifying that the alternative (using the well's current label to filter historical fact rows) would have affected only ~0.22% of historical producing revenue, since `FACT_PRODUCTION` already retains the accurate `well_type` at daily grain independently of the dimension table. A working **SCD Type 2** implementation (change detection via `LAG()`, versioning via a running `SUM()`, surrogate key, effective date ranges) is included separately under `snowflake/sql/` to demonstrate the pattern for cases where the fact table doesn't already retain the accurate historical value.

## DIM_DATE

A complete calendar-date dimension (generated via a date spine, not just distinct production dates, so it has no gaps — required for Power BI's date-table time-intelligence functions) with year, quarter, month, and month-start attributes.

---

# Analytical Gold Tables

- **WELL_DECLINE_TREND** — monthly oil/gas/water volume and shut-in day count, per well.
- **WATER_CUT_TREND** — volume-weighted monthly water cut, per well.
- **DOWNTIME_EVENTS** — discrete shut-in events (start, end, duration) via gaps-and-islands grouping.
- **REVENUE_DECOMPOSITION** — monthly indicative value (USD & NOK) against an annual baseline, decomposed into volume effect, price effect, and interaction term. Uses a **volume-weighted average Brent price**, not a naive daily average, so low-volume days with an unusual price don't distort the figure.
- **WELL_VALUE_RANKING** — wells ranked by cumulative indicative value (USD & NOK) with running percentage of total, for Pareto/concentration analysis.

---

# Semi-Structured Data Processing

```sql
SELECT 
    f.value:period::DATE AS price_date,
    f.value:value::FLOAT AS brent_usd_bbl,
    f.value:"series-description"::STRING AS series_desc,
    f.value:units::STRING AS units
FROM BRONZE.BRENT_RAW,
LATERAL FLATTEN(
    input => raw_payload:response:data
) f;
```

This demonstrates `VARIANT`, JSON path expressions, `LATERAL FLATTEN`, and relational type casting of semi-structured data. The FX source (Frankfurter) uses a structurally different, flat JSON array — flattened with a different `LATERAL FLATTEN` pattern to demonstrate handling more than one semi-structured shape.

---

# Snowflake Governance

Role-based access control was designed around a simulated joint-venture (JV) scenario common in oil & gas — an operator and outside partners seeing different levels of detail on the same asset.

```text
SYSADMIN
    ↓
VOLVE_DE          -- pipeline/developer role: owns all objects, full read/write across Bronze/Silver/Gold
    ↓
VOLVE_ANALYST     -- internal analyst role: full read access to Gold
VOLVE_VIEWER      -- simulated JV partner role: restricted read access to Gold
```

Implemented and validated:

- **Row Access Policy** on `FACT_PRODUCTION` restricting `VOLVE_VIEWER` to a subset of wells (simulating non-operated interest visibility)
- **Dynamic Data Masking** nulling a sensitive operational column (wellhead pressure) for `VOLVE_VIEWER`
- **Object tagging** documenting which columns are governed and why
- Validated by running the identical query as each role and comparing the different results directly, rather than only describing the policy
- Warehouse-to-role mapping (separate load/transform vs. BI-read warehouses) and a resource monitor for cost governance

Governance SQL is available under `snowflake/sql/`.

---

# Python and API Ingestion

Python is used for the ingestion side of the pipeline, not for in-warehouse transformation:

- Converting the raw Excel production workbook to CSV (`pandas`/`openpyxl`)
- Calling the EIA and Frankfurter REST APIs (`requests`), handling pagination (EIA), inspecting the real response shape before writing any downstream SQL, and persisting the raw JSON
- A separate exercise profiling Bronze data with `pandas` (null counts, dtype checks, duplicate detection) via a Snowflake Python session — a learning exercise, kept separate from the core transformation pipeline, which is done in SQL

```text
Python → requests.get() → REST API → response.json() → Raw JSON File → Snowflake Stage
```

---

# Data Quality

Data quality was treated as an explicit, documented part of the pipeline, not an afterthought. Findings included:

- A **unit mismatch**: production volume (Sm³) was initially multiplied directly against a USD/bbl price with no conversion, overstating every revenue figure by roughly 6x — caught via a magnitude sanity-check and fixed with the standard bbl/m³ conversion factor, applied consistently through every downstream table.
- A **hidden units-metadata row** in the monthly production file, disguised as a data row directly beneath the header — identified during profiling and explicitly excluded with a documented `WHERE` clause rather than a silent drop.
- A **text-encoding issue** in a facility name, and a **date-format ambiguity** resolved by explicitly validating the source format before casting.
- A **reconciliation check** between the independently-reported daily and monthly production sources — summed daily volumes were compared against reported monthly totals, using a percentage-variance threshold (not exact-match) to account for expected rounding differences between independently-measured sources, flagging any well-month exceeding the threshold for review.
- **Weekend/holiday gaps** in the Brent price series (prices are only quoted on trading days, while wells produce every day) — resolved via forward-fill with a backward-fill fallback for the series' earliest dates.

The general approach: Profile → Validate → Transform → Validate Again → Gold. Detailed documentation is available in `docs/data_quality.md`.

---

# Power BI Dashboard

Power BI connects to the Snowflake Gold layer (via the `VOLVE_ANALYST` role). The dashboard is organized around the business questions above, not generic charts:

- **KPI strip** — Oil Production (bbl), Total Revenue (USD), Total Revenue (NOK), Uptime (%)
- **What-If Analysis** — Brent price scenario slicer, recalculating total field revenue; explicitly labelled as historical sensitivity, not a forecast
- **Production Decline by Well** — oil/gas/water volume trend per well over time
- **Revenue Performance vs. Brent Price** — total revenue against average Brent price over time; the accompanying decomposition shows declining production volume, not falling price, as the larger driver of the reduction in indicative value — a more precise read than the trend chart alone would suggest
- **Well Performance: Choke % vs. Oil Rate** — scatter chart, choke size (%) against oil rate, bubble size = average wellhead pressure
- **Water Cut Trend** — average water cut (%) per well over time, volume-weighted (see Water Cut section above)
- **Economic Value Ranking of Well** — Pareto-style cumulative value ranking by well
- **Downtime Events** — discrete shut-in events by well, start date and duration

All DAX measures use explicit aggregation logic (e.g. `DIVIDE(SUM(water), SUM(oil)+SUM(water))` for water cut, volume-weighted price averaging) rather than relying on default column aggregation, which would silently miscalculate ratio-based metrics.

---

# Repository Structure

```text
volve-snowflake-data-platform/
│
├── README.md
│
├── architecture/
│   ├── README.md
│   ├── data_pipeline.png
│   └── data_model.png
│
├── data/
│   └── README.md
│
├── docs/
│   ├── data_sources.md
│   ├── methodology.md
│   └── data_quality.md
│
├── powerbi/
│   ├── README.md
│   └── dashboard.png
│
├── python/
│   ├── README.md
│   ├── eia_api.py
│   ├── fx_api.py
│   ├── convert_xls_csv.py
│   └── requirements.txt
│
└── snowflake/
    ├── README.md
    │
    ├── sql/
    │   ├── 01_env_setup.sql
    │   ├── 02_pipeline.sql
    │   ├── 03_bronze_load.sql
    │   ├── 04_bronze_profile.sql
    │   ├── 05_silver_clean_transform.sql
    │   ├── 06_bronze_fx_ingest_silver_flatten.sql
    │   ├── 07_silver_production_batch_2.sql
    │   ├── 08_gold_dim_tables.sql
    │   ├── 09_gold_fact_table.sql
    │   ├── 10_gold_derived_tables.sql
    │   ├── 11_governance.sql
    │   └── 12_dim_well_scd2_demo.sql
    │
    └── python/
        └── 04_pandas_profile.py
```

---

# Technology Stack

**Data Platform:** Snowflake, Snowflake Dynamic Tables, Snowflake-Managed Iceberg Tables, Snowflake VARIANT, Snowflake RBAC (Row Access Policies, Dynamic Data Masking), Snowflake Python

**Programming:** Python, pandas, requests, SQL

**Data Integration:** REST APIs, JSON, Excel

**Data Modelling:** Star Schema, Fact/Dimension Tables, Slowly Changing Dimensions (Type 1 & Type 2)

**Analytics:** Power BI, DAX, What-If Parameters, Time-Series Analysis

---

# Key Skills Demonstrated

**Data Engineering:** end-to-end platform design, ingestion, transformation, Bronze/Silver/Gold architecture, external API integration (incl. pagination handling), semi-structured data processing, data-quality investigation and remediation

**Snowflake:** databases, schemas, warehouses, custom roles and role hierarchy, grants, RBAC, Row Access Policies, Dynamic Data Masking, object tagging, resource monitors, VARIANT, JSON, LATERAL FLATTEN, Dynamic Tables (incl. incremental vs. full refresh behaviour), Snowflake-Managed Iceberg Tables, Snowflake Python

**Python:** REST APIs, requests, pagination handling, JSON, environment variables, file handling, error handling, pandas

**SQL:** CTEs, joins, aggregations, window functions (LAG, ROW_NUMBER, running SUM, gaps-and-islands grouping), date functions, JSON path expressions, LATERAL FLATTEN, SCD Type 1 & Type 2 implementation, reconciliation logic

**Analytics:** production decline, water-cut analysis, choke/pressure analysis, downtime-event analysis, well ranking, commodity-price decomposition (volume/price/interaction), scenario analysis

**Power BI:** Snowflake connectivity, dimensional modelling, DAX (incl. weighted-average and time-intelligence measures), What-If parameters, interactive dashboard design

---

# Why Brent?

Volve is located in the North Sea. Brent is used as the external benchmark because it is the major international crude-oil benchmark associated with the North Sea and international crude pricing. The analysis should not be interpreted as the actual realized selling price of Volve crude — see Economic Disclaimer below.

---

# Project Limitations

This is an educational portfolio project based on publicly available historical data. It is not intended to reproduce a complete commercial oil & gas production platform, and results should not be interpreted as official reservoir-engineering conclusions, production accounting, financial reporting, commercial asset valuation, or investment advice.

---

# Economic Disclaimer

The economic calculations represent **indicative / notional production value**, labelled "Total Revenue" on the dashboard for readability. They do not represent realized revenue. The calculations exclude quality differentials, transportation, royalties, taxes, operating expenditure, marketing costs, contractual pricing, realized sales prices, hedging effects, and other commercial adjustments.

---

# Data and Security Disclaimer

This project uses publicly available data and external APIs for educational and portfolio purposes. The original Volve source dataset is not redistributed in this repository. API credentials, Snowflake passwords, and other secrets are never committed to GitHub — the EIA API key is supplied via an environment variable during development. No company-private or confidential data is included in this project.

---

# Snowflake Trial Account Disclaimer

This project was developed using a **Snowflake trial account**. The environment used during development is temporary and may no longer be available after the trial period ends. The GitHub repository preserves the project independently of the temporary Snowflake environment — architecture, SQL scripts, transformation and governance logic, Dynamic Table definitions, Python ingestion scripts, data-quality methodology, data-model documentation, and Power BI dashboard output. SQL scripts may require environment-specific configuration when recreated in another Snowflake account.

---

# Project Status

**Completed.** The core project has been completed using a temporary Snowflake trial environment and Power BI. The GitHub repository preserves the project architecture, source code, SQL transformations, data-model design, governance implementation, data-quality methodology, and Power BI output.

---

# Author

**Nabila Natasha**
Data Analyst | Data Engineering & Analytics

Personal portfolio project demonstrating practical experience with:
**Snowflake (Iceberg Tables, Dynamic Tables) • SQL • Python • REST APIs • JSON • Data Modelling (Star Schema, SCD) • Governance (RBAC/RLS/Masking) • Power BI • Oil & Gas Analytics**
