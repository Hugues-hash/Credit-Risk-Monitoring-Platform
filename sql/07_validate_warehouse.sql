USE credit_risk_db;
GO

-- 1. Row counts of every table
SELECT 'Dim_Borrower'          AS table_name, COUNT(*) AS row_count FROM warehouse.Dim_Borrower
UNION ALL SELECT 'Dim_Loan',              COUNT(*) FROM warehouse.Dim_Loan
UNION ALL SELECT 'Dim_Geography',         COUNT(*) FROM warehouse.Dim_Geography
UNION ALL SELECT 'Dim_Status',            COUNT(*) FROM warehouse.Dim_Status
UNION ALL SELECT 'Dim_Date',              COUNT(*) FROM warehouse.Dim_Date
UNION ALL SELECT 'Fact_Loan_Performance', COUNT(*) FROM warehouse.Fact_Loan_Performance;
-- Expected fact rows: 2,260,668 (same as filtered.loans)

-- 2. Totals must match filtered.loans exactly
SELECT 'filtered.loans' AS source, COUNT(*) AS loans, SUM(funded_amnt) AS total_funded, SUM(is_default) AS defaults
FROM filtered.loans
UNION ALL
SELECT 'warehouse fact', COUNT(*), SUM(funded_amnt), SUM(is_default)
FROM warehouse.Fact_Loan_Performance;

-- 3. Required keys must never be empty (all should be 0)
SELECT
    SUM(CASE WHEN borrower_key   IS NULL THEN 1 ELSE 0 END) AS missing_borrower,
    SUM(CASE WHEN loan_dim_key   IS NULL THEN 1 ELSE 0 END) AS missing_loan,
    SUM(CASE WHEN geography_key  IS NULL THEN 1 ELSE 0 END) AS missing_geography,
    SUM(CASE WHEN status_key     IS NULL THEN 1 ELSE 0 END) AS missing_status,
    SUM(CASE WHEN issue_date_key IS NULL THEN 1 ELSE 0 END) AS missing_issue_date
FROM warehouse.Fact_Loan_Performance;

-- 4. date keys: empty only where the date itself is missing
--    (next_pymnt_date_key is empty for closed loans)
SELECT
    SUM(CASE WHEN last_pymnt_date_key  IS NULL THEN 1 ELSE 0 END) AS no_last_pymnt_date,
    SUM(CASE WHEN next_pymnt_date_key  IS NULL THEN 1 ELSE 0 END) AS no_next_pymnt_date
FROM warehouse.Fact_Loan_Performance;

-- 5. Credit history: empty only for the 29 loans with no earliest_cr_line, never negative
SELECT
    SUM(CASE WHEN credit_history_months IS NULL THEN 1 ELSE 0 END) AS no_credit_history,
    MIN(credit_history_months) AS min_months,
    MAX(credit_history_months) AS max_months
FROM warehouse.Fact_Loan_Performance;
GO
