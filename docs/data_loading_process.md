# Data Loading Process (Silver to Gold Layer)

This document explains the final step of our database pipeline: moving the cleaned data from `filtered.loans` (our Silver layer) into the `warehouse` Star Schema (our Gold layer).

The empty warehouse tables are created by `sql/04_star_schema.sql`. The load itself will be executed via `sql/05_populate_warehouse.sql`, which has not been written yet.

## The Strategy: Two-Step Pumping

You cannot load a Star Schema all at once. Because the central Fact table relies on ID numbers (Surrogate Keys) that come from the Dimension tables, we must load the data in a specific order:
1. **Load Dimensions First:** Extract all unique descriptive categories.
2. **Load Fact Table Second:** Grab the new IDs from the dimensions and store them alongside the heavy numerical metrics.

---

## Step 1: Populating Dimension Tables (The "Who, What, Where, When")

**Why these columns?** Dimension tables hold *categorical* and *descriptive* data. They are the text-based attributes you will use in Power BI to slice, filter, and group your dashboards (e.g., "Show me defaults *by State* or *by Loan Grade*"). 

We use `SELECT DISTINCT` to ensure we only insert unique combinations of these traits, which saves massive amounts of storage space. SQL Server automatically generates a unique integer ID (`IDENTITY`) for each new row. The exception is `Dim_Date`, whose `date_key` is built from the date itself (`YYYYMMDD`).

### 1. `Dim_Borrower`
Contains information about the person applying for the loan.
* **Columns Extracted:** `emp_length`, `home_ownership`, `verification_status`
* **Why?** These are borrower-specific traits that describe their financial stability and living situation. 

### 2. `Dim_Loan`
Contains the configuration and classification of the loan product.
* **Columns Extracted:** `term_months`, `grade`, `sub_grade`, `purpose`, `application_type`
* **Why?** These attributes define the loan itself. `grade` and `sub_grade` are Lending Club's proprietary risk bands, while `purpose` tells us *why* they wanted the money (e.g., debt consolidation, wedding).

### 3. `Dim_Geography`
Contains location data.
* **Columns Extracted:** `addr_state`, `zip_code`
* **Why?** Grouping by location allows for regional economic analysis (e.g., do certain states have higher default rates?).

### 4. `Dim_Date`
Contains calendar information.
* **Columns Extracted:** `issue_date`, `earliest_cr_date`, `last_pymnt_date`, `next_pymnt_date` (transformed into `date_key`, `full_date`, `month_num`, `year_num`, `quarter_num`)
* **Why?** Building a dedicated date table is a Power BI best practice. It allows for "Time Intelligence" calculations like month-over-month growth or cohort vintage tracking. The table must cover every date in all four columns, or the Fact table load will fail on the foreign keys.

### 5. `Dim_Status`
Contains the state of the loan.
* **Columns Extracted:** `loan_status` (mapped into `status_group`: Active, Late, Paid, Defaulted)
* **Why?** `is_default` is `NULL` for every loan that is still open, so it cannot separate a healthy loan from a late one. `status_group` makes that split available for monitoring dashboards.

---

## Step 2: Populating the Fact Table (The "How Much")

**Why these columns?** The Fact table (`Fact_Loan_Performance`) is the massive, central table. It is designed to hold *quantitative* data—the numbers you want to sum, average, or predict. 

Instead of storing repeating text (like the word "MORTGAGE" 1.2 million times), it stores the tiny integer IDs linking back to the dimensions, alongside all the heavy financial math.

### 1. The Surrogate Keys (The Links)
* **Columns:** `borrower_key`, `loan_dim_key`, `geography_key`, `status_key`, `issue_date_key`, `earliest_cr_date_key`, `last_pymnt_date_key`, `next_pymnt_date_key`
* **Why?** The script joins the 2.26 million rows in `filtered.loans` against the new Dimension tables to fetch these integer IDs. This links the numbers to their descriptive categories. A missing date stays `NULL`, so the date keys must be built without an `INNER JOIN` to `Dim_Date`, which would drop those loans.

### 2. Financial Exposure Metrics
* **Columns:** `loan_amnt`, `funded_amnt`, `int_rate`, `installment`
* **Why?** These define the core financial size and cost of the loan agreement.

### 3. Borrower Risk Features (For Machine Learning)
* **Columns:** `annual_inc`, `dti`, `revol_util`, `revol_bal`, `fico_score`, `delinq_2yrs`, `inq_last_6mths`, `open_acc`, `total_acc`, `pub_rec`
* **Why?** These are historical financial health indicators. These columns are the most critical features we will feed into our Python Probability of Default (PD) machine learning model in Phase 7.

### 4. Repayment Tracking
* **Columns:** `out_prncp`, `total_pymnt`, `total_rec_prncp`, `total_rec_int`, `total_rec_late_fee`, `recoveries`, `last_pymnt_amnt`
* **Why?** These track the money actually coming back to the lender. `recoveries`, for example, tracks money salvaged from debt collectors after a default.

### 5. Target Variable
* **Columns:** `is_default` (Binary 1, 0, or NULL)
* **Why?** `is_default` is our "North Star" target variable. Everything else in the database is ultimately being analyzed to predict or explain this exact column.