# Architecture

This directory contains the architecture diagrams for the Volve Oil & Gas Data Platform.

---

# Data Pipeline Architecture

The end-to-end pipeline is:

```text
Volve Excel
     |
     v
Python Ingestion
     |
     v
Snowflake Bronze
     |
     v
Silver
     |
     v
Dynamic Tables
     |
     v
Gold
     |
     v
Power BI
```

External API data follows:

```text
EIA API
   ↓
Python
   ↓
JSON
   ↓
Snowflake VARIANT
   ↓
LATERAL FLATTEN
   ↓
Silver
   ↓
Gold
```

The complete diagram is:

```text
architecture/data_pipeline.png
```

---

# Data Model

The analytical model follows a Star Schema approach.

The central production fact table is:

```text
FACT_PRODUCTION
```

Supporting dimensions include:

```text
DIM_WELL
DIM_DATE
```

Additional analytical tables include:

```text
WELL_DECLINE_TREND
WATER_CUT_TREND
DOWNTIME_EVENTS
REVENUE_DECOMPOSITION
WELL_VALUE_RANKING
```

The data model diagram is:

```text
architecture/data_model.png
```

---

# Architecture Principles

The platform follows:

- Layered architecture
- Separation of raw and transformed data
- Dimensional modelling
- Role-based access control
- Semi-structured data processing
- Declarative transformation using Dynamic Tables
- BI-oriented Gold datasets

---

# Main Technologies

- Snowflake
- Python
- REST APIs
- JSON
- Dynamic Tables
- SQL
- Power BI