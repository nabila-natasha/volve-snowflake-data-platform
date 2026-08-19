# Power BI Dashboard

This directory contains the Power BI portfolio output for the Volve Oil & Gas Data Platform.

The dashboard consumes analytical datasets from the Snowflake Gold layer.

---

# Dashboard Objective

The dashboard provides a consolidated view of:

- Oil Production (bbl)
- Total Revenue (USD)
- Total Revenue (NOK)
- Uptime (%)
- Brent Price Scenario Revenue
- Production Decline by Well
- Revenue Performance vs Brent Price
- Well Performance: Choke vs Oil Rate
- Water Cut Trend
- Economic Value Ranking of Well
- Downtime Events

---

# Analytical Areas

## Production

The dashboard analyses:

- Oil production
- Well-level trends

---

## Production Decline

The dashboard provides time-series views of production decline at:

- Well level

---

## Water Cut

Water cut is calculated as = 

Water
----------------
Oil + Water


The dashboard allows comparison between wells and over time.

---

## Operational Analysis

The dashboard examines relationships between:

- Choke size
- Wellhead pressure
- Oil production

It also provides downtime and shut-in analysis.

---

## Economic Analysis

The dashboard uses:


Oil Production × Brent Price

to calculate indicative production value.

This is a benchmark-based analytical metric and does not represent realized company revenue.

---

# Scenario Analysis

Power BI What-If analysis allows alternative Brent price assumptions.

Example scenarios:

```text
$50/bbl
$70/bbl
$90/bbl
```

Users can adjust the assumed benchmark price and observe the effect on indicative production value.

---

# Snowflake Connection

The dashboard is designed to consume the Snowflake Gold layer.

The intended flow is:

```text
Snowflake Gold
      ↓
Power BI
      ↓
DAX Measures
      ↓
Dashboard
```

---

# Dashboard Screenshot

The dashboard screenshot is available at:

```text
powerbi/dashboard.png
```

---

# Important Disclaimer

The economic metrics shown in the dashboard represent **indicative / notional production value**.

They do not represent:

- Realized revenue
- Official company financial results
- Commercial asset valuation
- Realized crude sales prices

The calculations do not account for royalties, taxes, operating costs, transportation, quality differentials, contractual pricing, or other commercial adjustments.

---

# Portfolio Purpose

The Power BI dashboard demonstrates:

- Snowflake-to-Power BI connectivity
- Analytical modelling
- DAX
- Time-series analysis
- Oil & gas production analytics
- Interactive scenario analysis
- Business-focused visualization
