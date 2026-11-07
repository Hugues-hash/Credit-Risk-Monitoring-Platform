# Credit Risk Monitoring Platform

A SQL Server data warehouse built on LendingClub loan data (2007–2018, 2.26M loans), for credit risk dashboards in Power BI and a probability of default model.

## Pipeline

```
CSV  →  staging.stg_accepted_loans  →  filtered.loans  →  warehouse (star schema)
        (raw text)                     (cleaned)          (1 fact + 5 dimensions)
```

| Step | File | What it does |
|---|---|---|
| 0 | `sql/00_init_database.sql` | Creates the database and `staging` schema |
| 1 | `python/stage_raw_data.py` | Loads the CSV into `staging.stg_accepted_loans` |
| 2 | `sql/01_data_profiling.sql` | Profiles the raw data |
| 3 | `sql/02_clean_staging.sql` | Cleans the data into `filtered.loans` |
| 4 | `sql/03_validate_clean.sql` | Checks the cleaned data |
| 5 | `sql/04_star_schema.sql` | Creates the warehouse tables |
| 6 | `sql/05_load_dimensions.sql` | Loads the dimension tables |
| 7 | `sql/06_load_fact.sql` | Loads the fact table |
| 8 | `sql/07_validate_warehouse.sql` | Checks the warehouse load |

Run the files in this order.

## Star Schema

| Table | Rows | Contents |
|---|---:|---|
| `Fact_Loan_Performance` | 2,260,668 | One row per loan: amounts, rates, risk values, credit history length, repayments, `is_default` |
| `Dim_Borrower` | 144 | Employment length, home ownership, income verification |
| `Dim_Loan` | 1,626 | Term, grade, sub-grade, purpose, application type |
| `Dim_Geography` | 3,423 | State and 3-digit zip code |
| `Dim_Status` | 9 | Loan status and status group (Active, Late, Paid, Defaulted) |
| `Dim_Date` | 4,748 | Calendar, one row per day from 2007 to 2019 |

## Docs

| File | Contents |
|---|---|
| `docs/data_profiling_findings.md` | What profiling found in the raw data |
| `docs/data_cleaning_steps.md` | Each cleaning rule and why |
| `docs/star_schema_design.md` | Table design and diagram |
| `docs/data_loading_process.md` | How the warehouse is loaded and checked |
| `docs/project_glossary.md` | Data and credit risk terms |
| `docs/LCDataDictionary.csv` | LendingClub's description of every column |

## Setup

- SQL Server Express (2022 or later, for `IS NOT DISTINCT FROM`) with ODBC Driver 17
- Python 3 with `pandas`, `sqlalchemy` and `pyodbc`
- The LendingClub file `accepted_2007_to_2018Q4.csv`, saved in `data/` (not included in the repo because of its size)

