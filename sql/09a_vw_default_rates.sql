USE credit_risk_db;
GO

-- Default rates, count-based and dollar-weighted, on CLOSED loans only (is_default IS NOT NULL).
-- One row per (dimension, segment). dimension = overall, grade, sub_grade, term_months, purpose, home_ownership.
-- Rates use 100e0 * ... (a FLOAT). This avoids integer division on is_default, and stops SQL Server
-- cutting decimal places when it divides two large DECIMAL sums.
-- maturity_rate_pct shows how much of the segment is closed: a low value means the default rate
-- is based on a small, early part of the segment and will usually rise as more loans close.
CREATE OR ALTER VIEW analytics.vw_default_rates AS
WITH loans AS (
    SELECT
        l.grade,
        l.sub_grade,
        l.term_months,
        l.purpose,
        b.home_ownership,
        f.is_default,
        f.funded_amnt
    FROM warehouse.Fact_Loan_Performance AS f
    JOIN warehouse.Dim_Loan     AS l ON l.loan_dim_key = f.loan_dim_key
    JOIN warehouse.Dim_Borrower AS b ON b.borrower_key = f.borrower_key
),
agg AS (
    SELECT
        CASE
            WHEN GROUPING(grade)          = 0 THEN 'grade'
            WHEN GROUPING(sub_grade)      = 0 THEN 'sub_grade'
            WHEN GROUPING(term_months)    = 0 THEN 'term_months'
            WHEN GROUPING(purpose)        = 0 THEN 'purpose'
            WHEN GROUPING(home_ownership) = 0 THEN 'home_ownership'
            ELSE 'overall'
        END AS dimension,
        COALESCE(grade, sub_grade, CAST(term_months AS VARCHAR(10)), purpose, home_ownership, 'All loans') AS segment,
        COUNT(*)                                                     AS total_loans,
        COUNT(is_default)                                            AS closed_loans,
        SUM(CASE WHEN is_default = 1 THEN 1 ELSE 0 END)              AS defaulted_loans,
        SUM(CASE WHEN is_default IS NOT NULL THEN funded_amnt ELSE 0 END) AS funded_closed,
        SUM(CASE WHEN is_default = 1 THEN funded_amnt ELSE 0 END)    AS funded_defaulted
    FROM loans
    GROUP BY GROUPING SETS ((), (grade), (sub_grade), (term_months), (purpose), (home_ownership))
)
SELECT
    dimension,
    segment,
    total_loans,
    closed_loans,
    defaulted_loans,
    funded_closed,
    funded_defaulted,
    CAST(100e0 * closed_loans     / total_loans                AS DECIMAL(9, 4)) AS maturity_rate_pct,
    CAST(100e0 * defaulted_loans  / NULLIF(closed_loans, 0)    AS DECIMAL(9, 4)) AS default_rate_count_pct,
    CAST(100e0 * funded_defaulted / NULLIF(funded_closed, 0)   AS DECIMAL(9, 4)) AS default_rate_dollar_pct
FROM agg;
GO
