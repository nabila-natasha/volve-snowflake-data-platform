import pandas as pd
from pathlib import Path

# Anchor to this script's own location, not the current working directory
script_dir = Path(__file__).resolve().parent
data_dir = (script_dir / "../data/raw").resolve()

input_file = data_dir / "Volve production data.xlsx"

# Confirm the exact sheet names before parsing — Excel sheet names are
# case-sensitive and easy to get slightly wrong (extra space, etc.)
xls = pd.ExcelFile(input_file)
print("Sheets found:", xls.sheet_names)

# Create output directory
output_dir = data_dir   # same folder as the JSON file
output_dir.mkdir(parents=True, exist_ok=True)

xls.parse("Daily Production Data").to_csv(output_dir / "daily_production.csv", index=False)
xls.parse("Monthly Production Data").to_csv(output_dir / "monthly_production.csv", index=False)

print(f"Read from: {input_file}")
print(f"Wrote CSVs to: {output_dir}")