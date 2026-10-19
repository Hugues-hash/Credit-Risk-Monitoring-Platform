# Lending Club Credit Risk Platform: Project Glossary

## Architectural & Technical Terms

### 1. ETL (Extract, Transform, Load)
* **Definition**: The core data engineering pipeline process. 
* **In This Project**: 
  * **Extract**: Reading raw CSV files into Python/Pandas chunks.
  * **Transform**: Cleaning strings (trimming `term`), handling nulls, formatting dates, and filtering out trailing artifact rows.
  * **Load**: Writing the cleaned records into SQL Server staging tables and eventually into your Star Schema.

### 2. Dimension Table (`Dim_...`)
* **Definition**: A descriptive table in a Star Schema that contains categorical attributes about business entities (e.g., who, what, where).
* **In This Project**: Tables like `Dim_Borrower` (employment, home ownership), `Dim_Loan` (grades, terms), and `Dim_Geography` (states, zip codes) that provide context to your numerical metrics.

### 3. Fact Table (`Fact_...`)
* **Definition**: The central table in a Star Schema containing quantitative, numerical measurements (metrics) and foreign keys linking to dimension tables.
* **In This Project**: `Fact_Loan_Performance`, which holds loan amounts, interest rates, installment values, and default flags for every individual loan transaction.

---

## Financial & Credit Risk Terms

### 4. Loan Performance (`loan_status`)
* **Definition**: The current state or final outcome of a lending contract indicating whether money is being repaid or lost.
* **In This Project**: The overarching tracking category for every loan lifecycle stage, dictating whether a row represents a performing asset or a default.

### 5. Default
* **Definition**: When a borrower fails to make their required contractual loan payments for an extended period (typically 90 to 180+ days past due).
* **In This Project**: The primary target variable (`is_default = 1`) for your Phase 7 Probability of Default (PD) machine learning model.

### 6. Charged Off (`Charged Off`)
* **Definition**: An accounting status where a lender officially writes off a delinquent debt as a financial loss because the borrower is severely behind and collection efforts have failed.
* **In This Project**: The primary empirical indicator of a defaulted loan in the Lending Club dataset.

### 7. Grace Period
* **Definition**: A short window of time (usually 1 to 15 days) following a monthly payment due date during which a borrower can pay late without incurring a late fee or triggering delinquency status.
* **In This Project**: An active, non-default portfolio status indicating temporary distress.

### 8. Late (`Late (16-30 days)` / `Late (31-120 days)`)
* **Definition**: Status assigned when a borrower misses their monthly payment deadline beyond the grace period, categorized by how many days elapsed.
* **In This Project**: A critical leading indicator of credit risk that flags loans at high risk of moving into complete default.

### 9. DTI (Debt-to-Income Ratio)
* **Definition**: A personal finance measure that compares a borrower’s total monthly debt payments against their gross monthly income, expressed as a percentage.
* **In This Project**: A key risk driver; profiling revealed values ranging from -1 to 999, meaning extreme outliers and anomalies must be cleaned before modeling borrower risk capacity.