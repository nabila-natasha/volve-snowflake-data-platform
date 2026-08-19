"""
Day 3 - Step 1: Extract NOK/USD historical exchange rates from Frankfurt API
"""

import json 
import requests
from pathlib import Path

# Set project directories
script_dir = Path(__file__).resolve().parent  # __file__ built-in cariable conaining path of current script
data_dir = (script_dir / "../data/raw").resolve()
data_dir.mkdir(parents=True, exist_ok=True)

# Frankfurt API endpoint
url = "https://api.frankfurter.dev/v2/rates"

params = {
    "base": "USD",
    "quotes": "NOK",
    "from": "2007-09-01",
    "to": "2016-12-31"
}

# Make API request
response = requests.get(url, params=params)

print("Request URL:", response.url)
print("Status code:", response.status_code)

# Print API error before stopping
if response.status_code != 200:
    print("API response:")
    print(response.text)

# Stop if API request failed
response.raise_for_status()

# Convert JSON response into Python object
payload = response.json()

# Inspect response structure
print("Response type:", type(payload).__name__)

if isinstance(payload, dict):
    print("Top-level keys:", list(payload.keys()))

elif isinstance(payload, list):
    print(f"Response contains, {len(payload)} records")

# Print first 15000 characters for inspection
print(json.dumps(payload, indent=2)[:1500])   # convert Python object → JSON string

# Save raw JSON
output_file = data_dir / "usd_nok_fx_rates.json"

with open(output_file, "w") as f:
    json.dump(payload, f, indent=2)

print(f"Total records saved: {len(payload)}")
print(f"\nWrote FX data to: {output_file}")