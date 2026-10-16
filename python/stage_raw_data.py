import pandas as pd
from sqlalchemy import create_engine
from sqlalchemy.types import Text
import time

# Connect to your local SQL Server Express instance
# Added '&UseFMTONLY=yes' to fix the fast_executemany truncation bug
engine = create_engine(
    "mssql+pyodbc://localhost\\SQLEXPRESS/credit_risk_db?driver=ODBC+Driver+17+for+SQL+Server&trusted_connection=yes&UseFMTONLY=yes",
    fast_executemany=True
)

csv_path = 'data/accepted_2007_to_2018q4.csv'
table_name = 'stg_accepted_loans'
schema_name = 'staging'

print(f"Starting staging load for {csv_path}...")
start_time = time.time()

chunk_size = 100_000
chunks_loaded = 0
rows_loaded = 0

# Clean up the partially loaded table from the previous failed run
with engine.begin() as conn:
    conn.exec_driver_sql(f"IF OBJECT_ID('{schema_name}.{table_name}', 'U') IS NOT NULL DROP TABLE {schema_name}.{table_name}")

# Read and insert in chunks
# Read everything as strings: per-chunk type inference is inconsistent (e.g. a column
# that is all-NaN in chunk 1 becomes FLOAT, then fails when text appears later).
# Staging stays raw text; type casting happens downstream in SQL.
for chunk in pd.read_csv(csv_path, chunksize=chunk_size, dtype=str):
    # Clean column names (lowercase, replace spaces with underscores)
    chunk.columns = [c.strip().lower().replace(" ", "_") for c in chunk.columns]

    # Every column is unlimited text so the table schema doesn't depend on chunk 1
    column_dtypes = {col: Text() for col in chunk.columns}
    
    # Write to SQL (always append since we dropped the table initially)
    chunk.to_sql(
        name=table_name, 
        con=engine, 
        schema=schema_name, 
        if_exists='append', 
        index=False, 
        dtype=column_dtypes
    )
    
    chunks_loaded += 1
    rows_loaded += len(chunk)
    print(f"Loaded chunk {chunks_loaded} ({rows_loaded:,} rows processed)")

print(f"Completed in {round((time.time() - start_time) / 60, 2)} minutes.")