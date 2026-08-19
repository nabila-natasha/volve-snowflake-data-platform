# Snowflake

This directory contains the Snowflake implementation of the Volve Oil & Gas Data Platform.

The Snowflake environment is responsible for:

- Data storage
- Data transformation
- Semi-structured data processing
- Dynamic Tables
- Data modelling
- Governance
- Analytical datasets

---

# Architecture

The Snowflake implementation follows:

```text
BRONZE
   ↓
SILVER
   ↓
DYNAMIC TABLES
   ↓
GOLD
```

---

# Bronze

The Bronze layer contains relatively raw source data.

Examples include:

- Production data
- Raw Brent JSON
- Raw FX JSON

The EIA JSON payload is stored using:

```text
VARIANT
```

---

# Silver

The Silver layer contains cleaned and standardized data.

Typical transformations include:

- Data-type casting
- Date standardization
- Null handling
- Duplicate handling
- Business transformations

---

# Dynamic Tables

Dynamic Tables are used to maintain derived transformation datasets.

The purpose is to demonstrate:

- Declarative transformation
- Target lag
- Dependency chains
- Automatic refresh of derived data

---

# Gold

The Gold layer provides analytical datasets for Power BI.

Main objects:

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

# Governance

Snowflake RBAC is implemented using custom roles.

Conceptually:

```text
SYSADMIN
   ↓
VOLVE_DE
   ↓
VOLVE_ANALYST
   ↓
VOLVE_VIEWER

```

The role and privilege definitions are contained in:

```text
snowflake/sql/
```

---

# Python

The `snowflake/python/` directory contains an additional Snowflake Python / pandas profiling exercise.

This is primarily a learning component.

---

# Snowflake Trial Disclaimer

The project was developed using a temporary Snowflake trial account.

The trial environment may no longer be available.

The SQL scripts are preserved in this repository so the environment can be recreated in another Snowflake account.
