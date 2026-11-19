USE credit_risk_db;
GO

-- Vintage (cohort) view: loans grouped by the quarter they were issued, split by grade.
-- One row per (issue_year, issue_quarter, grade). Counts and amounts can be added up across grades;
-- to combine the averages, weight them by originated_loans.
-- Newer cohorts (2017-2018) have low maturity rates, so their observed default rates are too low:
-- most of their loans are still open, and the ones that have closed early are mostly early payoffs.
CREATE OR ALTER VIEW analytics.vw_vintage_cohorts AS
WITH agg AS (
    SELECT
        d.year_num                                                        AS issue_year,
        d.quarter_num                                                     AS issue_quarter,
        l.grade,
        COUNT(*)                                                          AS originated_loans,
        SUM(f.funded_amnt)                                                AS funded_exposure,
        COUNT(f.is_default)                                               AS closed_loans,
        SUM(CASE WHEN f.is_default = 1 THEN 1 ELSE 0 END)                 AS defaulted_loans,
        SUM(CASE WHEN f.is_default IS NOT NULL THEN f.funded_amnt ELSE 0 END) AS funded_closed,
        SUM(CASE WHEN f.is_default = 1 THEN f.funded_amnt ELSE 0 END)     AS funded_defaulted,
        AVG(f.fico_score)                                                 AS avg_fico_score,
        AVG(f.int_rate)                                                   AS avg_int_rate
    FROM warehouse.Fact_Loan_Performance AS f
    JOIN warehouse.Dim_Date AS d ON d.date_key     = f.issue_date_key
    JOIN warehouse.Dim_Loan AS l ON l.loan_dim_key = f.loan_dim_key
    GROUP BY d.year_num, d.quarter_num, l.grade
)
SELECT
    issue_year,
    issue_quarter,
    CONCAT(issue_year, '-Q', issue_quarter) AS cohort,
    grade,
    originated_loans,
    funded_exposure,
    closed_loans,
    defaulted_loans,
    funded_closed,
    funded_defaulted,
    CAST(100e0 * closed_loans     / originated_loans         AS DECIMAL(9, 4)) AS maturity_rate_pct,
    CAST(100e0 * defaulted_loans  / NULLIF(closed_loans, 0)  AS DECIMAL(9, 4)) AS default_rate_count_pct,
    CAST(100e0 * funded_defaulted / NULLIF(funded_closed, 0) AS DECIMAL(9, 4)) AS default_rate_dollar_pct,
    CAST(avg_fico_score AS DECIMAL(6, 1)) AS avg_fico_score,
    CAST(avg_int_rate   AS DECIMAL(6, 2)) AS avg_int_rate
FROM agg;
GO
