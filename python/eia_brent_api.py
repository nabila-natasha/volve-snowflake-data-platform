"""
Day 1 - Step 1: Extract EIA Brent Crude Spot Prices
"""

import os
import json 
import requests
from pathlib import Path

# Get API key from environment variable
api_key = os.getenv("EIA_API_KEY")
print("API key loaded:", api_key is not None)

if api_key is None:
    raise RuntimeError("EIA_API_KEY was not found.")

# EIA API endpoint
url = "https://api.eia.gov/v2/seriesid/PET.RBRTE.D/"

all_records = []
offset = 0
page_size = 5000
reported_total = None

while True:
    params = {
        "api_key": api_key,
        "offset": offset,
        "length": page_size
    }
    # Make API request
    response = requests.get(url, params=params)
    print(f"Fetching offset={offset} - Status code:", response.status_code)

    # Stop if API request failed
    response.raise_for_status()

    # Convert response into Python dictionary
    page = response.json()
    records = page["response"]["data"]
    reported_total = page["response"]["total"]

    all_records.extend(records)
    print(f"  got {len(records)} records - running total: {len(all_records) / reported_total}")

    if len(records) < page_size or len(all_records) >= int(reported_total):
        break

    offset += page_size

# Rebuild a single combined payload, same shape as the original response  
combined = {
    "response": {
        "total": reported_total,
        "dateFormat": page["response"].get("dateFormat"),
        "frequency": page["response"].get("frequency"),
        "data": all_records
    }
}

# Create output directory
output_dir = Path("../data/raw")
output_dir.mkdir(parents=True, exist_ok=True)

# Save raw JSON
output_file = output_dir / "eia_brent_crude.json"

with open(output_file, "w", encoding="utf-8") as f:
    json.dump(combined, f, indent=2)

print(f"Total records saved: {len(all_records)} (API reported total: {reported_total})")
print(f"Raw JSON saved to: {output_file}")