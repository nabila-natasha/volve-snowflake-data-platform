# Data

This directory documents the datasets used by the Volve Oil & Gas Data Platform.

The project integrates three primary data sources:

1. Volve field production data
2. EIA Brent crude oil benchmark prices
3. USD/NOK foreign exchange rates

---

## Data Directory Purpose

The repository does not redistribute the original Volve source dataset or external API datasets.

Instead, this directory documents:

- What data was used
- Where the data came from
- How the data was ingested
- How the data was transformed
- How the datasets were used in Snowflake

The actual production dataset and raw API responses were maintained locally during development and are intentionally excluded from GitHub where appropriate.

---

# 1. Volve Production Data

The Volve dataset contains historical production and operational data associated with the Volve field in the North Sea.

The downloaded workbook contains daily and monthly worksheets.

The data was used to support:

- Well-level production analysis
- Oil production analysis
- Gas production analysis
- Water production analysis
- Production decline
- Water-cut analysis
- Choke analysis
- Wellhead pressure analysis
- Downtime analysis

---

# 2. Daily Production Data

The daily production data provides observations at a daily level.

This dataset forms the primary source for:

```text
FACT_PRODUCTION
```

Typical measures include:

- Oil production
- Gas production
- Water production
- Production days
- Shut-in indicators
- Operational measurements

Daily data is particularly useful for:

- Time-series analysis
- Production decline
- Water cut
- Downtime
- Well-level performance

---

# 3. Monthly Production Data

The monthly production worksheet provides aggregated production information.

It can be used for:

- Monthly field-level analysis
- Cross-checking daily production
- Monthly production trends
- Aggregation validation

The monthly dataset is not necessarily used as the primary analytical fact table when daily observations provide sufficient granularity.

---

# 4. Brent Price Data

Historical Brent benchmark prices are obtained through the EIA Open Data API.

The API returns nested JSON.

The raw response is stored in Snowflake as:

```text
VARIANT
```

The JSON structure is then flattened using:

```text
LATERAL FLATTEN
```

The resulting relational dataset contains fields such as:

- Price date
- Brent price
- Series
- Series description
- Units

The Brent price dataset is used to calculate indicative production value.

---

# 5. USD/NOK FX Data

Historical USD/NOK exchange-rate data is obtained through the Frankfurter API.

The FX data demonstrates integration of an additional external API source.

It can be used for:

- Currency analysis
- External market-data integration
- API ingestion demonstration

---

# 6. Data Flow

The datasets follow this general flow:

```text
Volve Excel
     |
     v
Python / Local Staging
     |
     v
Snowflake Bronze
     |
     v
Silver
     |
     v
Gold
```

External market data follows:

```text
EIA API
   |
   v
Python
   |
   v
Raw JSON
   |
   v
Snowflake VARIANT
   |
   v
LATERAL FLATTEN
   |
   v
Silver
```

---

# 7. Data Storage

Raw data is intentionally not committed directly to GitHub.

This prevents:

- Large repository size
- Unnecessary duplication
- Licensing issues
- Accidental exposure of source data
- Accidental exposure of API credentials

The GitHub repository contains the implementation and documentation required to understand the data pipeline.

---

# 8. Data Privacy and Security

The repository must not contain:

- API keys
- Passwords
- Access tokens
- Snowflake credentials
- Company data
- Confidential operational data

The EIA API key is provided through an environment variable during development.

---

# 9. Source Documentation

Detailed information about the data sources is available in:

```text
docs/data_sources.md
```

The transformation methodology is documented in:

```text
docs/methodology.md
```

Data-quality considerations are documented in:

```text
docs/data_quality.md
```

---

# 10. Data Availability

The project was developed using publicly available historical data.

Because the Snowflake environment was created using a temporary trial account, the GitHub repository is designed to preserve the implementation independently of the Snowflake environment.

A future user can recreate the Snowflake objects using the SQL scripts provided in:

```text
snowflake/sql/
```