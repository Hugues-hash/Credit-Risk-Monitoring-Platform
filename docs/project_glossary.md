# Project Glossary

## Data Terms

### ETL (Extract, Transform, Load)
The process of moving data from a source into a database.
- **Extract:** `python/stage_raw_data.py` reads the CSV in chunks.
- **Transform:** `sql/02_clean_staging.sql` fixes types, text values and bad values.
- **Load:** the raw data goes into `staging`, the cleaned data into `filtered`, and the star schema into `warehouse`.

### Schema
A folder inside the database that groups tables. This project uses three: `staging` (raw data), `filtered` (cleaned data) and `warehouse` (star schema).

### Star Schema
A database design with one central fact table linked to several dimension tables.

### Dimension Table (`Dim_...`)
A table of descriptive values used to filter and group data, such as state, grade or loan status. This project has `Dim_Borrower`, `Dim_Loan`, `Dim_Geography`, `Dim_Date` and `Dim_Status`.

### Fact Table (`Fact_...`)
The central table that holds the numbers (amounts, rates, scores) and the keys that link to each dimension. This project has `Fact_Loan_Performance`, with one row per loan.

### Surrogate Key
A number created by the database to identify a row, such as `borrower_key`. The fact table stores these numbers instead of repeating the text values.

---

## Credit Risk Terms

### Loan Status (`loan_status`)
The current state of a loan, such as Current, Fully Paid or Charged Off. Stored in `Dim_Status`, together with `status_group` (Active, Late, Paid, Defaulted).

### Default
When a borrower stops making the required payments. In this project, `is_default = 1` for Charged Off and Default loans, `0` for Fully Paid loans, and `NULL` for loans that are still open.

### Charged Off
The lender has written the loan off as a loss because the borrower is far behind and collection has failed. This is the most common default status in the data.

### Grace Period
A short window (usually up to 15 days) after a payment is due, during which the borrower can pay without a late fee.

### Late (`Late (16-30 days)` / `Late (31-120 days)`)
The borrower has missed a payment beyond the grace period. Late loans are at high risk of default but are not counted as defaults.

### Joint Application
A loan that two people apply for together. For these loans the combined income (`annual_inc_joint`) and combined DTI (`dti_joint`) are used.

### DTI (Debt-to-Income Ratio)
A borrower's monthly debt payments divided by their monthly income, as a percentage. Higher DTI means more risk.

### FICO Score
The standard US credit score, from 300 to 850. Higher means lower risk. LendingClub gives a range (`fico_range_low`, `fico_range_high`), so `fico_score` is the average of the two. In this data it ranges from 612 to 847.5.

`last_fico_range_low` and `last_fico_range_high` are not used. They are measured after the loan was issued, so they already reflect whether the borrower defaulted and would leak the outcome into the model.

### Revolving Utilization (`revol_util`)
How much of their available credit card limit a borrower is using, as a percentage. Values above 100% mean the borrower is over their limit.
