-- 01b_validate_clean.sql
-- Quick checks on filtered.loans. Run after 01_clean_staging.sql.

USE credit_risk_db;
GO

-- 1. Row count: should be 2,260,668 (staging minus the 33 summary rows)
SELECT COUNT(*) AS clean_rows FROM filtered.loans;

-- 2. Target split: 1 = 269,360   0 = 1,078,739   NULL = active loans
SELECT is_default, COUNT(*) AS loans FROM filtered.loans GROUP BY is_default;

-- 3. Term: only 36 and 60
SELECT term_months, COUNT(*) AS loans FROM filtered.loans GROUP BY term_months;

-- 4. Value ranges
SELECT
    MIN(issue_date) AS first_issue,  MAX(issue_date) AS last_issue,
    MIN(fico_score) AS min_fico,     MAX(fico_score) AS max_fico,
    MIN(dti)        AS min_dti,      MIN(annual_inc) AS min_income
FROM filtered.loans;
GO
