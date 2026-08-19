# Python Ingestion

This directory contains Python scripts used to retrieve external market data.

The scripts demonstrate REST API integration and raw JSON ingestion.

---

# Files

```text
python/
├── README.md
├── eia_api.py
├── fx_api.py
└── requirements.txt
```

---

# EIA Brent API

`eia_api.py` retrieves Brent crude oil benchmark data from the EIA Open Data API.

The workflow is:

```text
Python
   ↓
HTTP Request
   ↓
EIA API
   ↓
JSON Response
   ↓
Python Object
   ↓
Raw JSON File
```

The API key is supplied through an environment variable.

Example:

```text
EIA_API_KEY
```

The actual key must never be committed to GitHub.

---

# Frankfurter FX API

`fx_api.py` retrieves historical USD/NOK exchange rates.

The workflow is:

```text
Python
   ↓
HTTP Request
   ↓
Frankfurter API
   ↓
JSON Response
   ↓
Python Object
   ↓
Raw JSON File
```

---

# Python Packages

The scripts use packages such as:

```text
requests
```

and standard Python libraries such as:

```text
json
os
pathlib
```

---

# Error Handling

The scripts check:

- HTTP status codes
- API response status
- JSON response structure

A failed request is stopped using HTTP error handling.

---

# Security

API keys are not hard-coded.

Credentials should be supplied through environment variables.

Do not commit:

- API keys
- Passwords
- Tokens
- Snowflake credentials
- `.env` files containing secrets

---

# Purpose

The Python ingestion component demonstrates:

- REST API integration
- JSON handling
- API authentication
- Environment variables
- File handling
- Error handling
- External data ingestion