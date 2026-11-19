import pandas as pd
from sqlalchemy import create_engine
from sqlalchemy.types import Text

# Loads the FRED macro file (one row per month) into staging.stg_macro_fred.
# Columns: date, unemployment_rate, fed_funds_rate, cpi_index, cpi_yoy_inflation
engine = create_engine(
    "mssql+pyodbc://localhost\\SQLEXPRESS/credit_risk_db?driver=ODBC+Driver+17+for+SQL+Server&trusted_connection=yes"
)

csv_path = 'data/macro_fred_combined.csv'
table_name = 'stg_macro_fred'
schema_name = 'staging'

df = pd.read_csv(csv_path, dtype=str)
df.columns = [c.strip().lower().replace(" ", "_") for c in df.columns]

# Same approach as the loan data: everything lands as text, types are fixed in SQL (08_load_macro.sql)
df.to_sql(
    name=table_name,
    con=engine,
    schema=schema_name,
    if_exists='replace',
    index=False,
    dtype={col: Text() for col in df.columns}
)

print(f"Loaded {len(df):,} months into {schema_name}.{table_name}")
