USE credit_risk_db;
GO

-- Delinquency buckets: open loans only (is_default IS NULL), one row per loan_status.
-- active_balance = principal still owed (out_prncp). Shares add up to 100% across the 4 buckets.
CREATE OR ALTER VIEW analytics.vw_delinquency_buckets AS
WITH agg AS (
    SELECT
        s.loan_status,
        COUNT(*)         AS loan_count,
        SUM(f.out_prncp) AS active_balance
    FROM warehouse.Fact_Loan_Performance AS f
    JOIN warehouse.Dim_Status AS s ON s.status_key = f.status_key
    WHERE f.is_default IS NULL
    GROUP BY s.loan_status
)
SELECT
    CASE loan_status
        WHEN 'Current'            THEN 1
        WHEN 'In Grace Period'    THEN 2
        WHEN 'Late (16-30 days)'  THEN 3
        WHEN 'Late (31-120 days)' THEN 4
    END AS bucket_order,
    loan_status,
    CASE loan_status
        WHEN 'Current'            THEN 'Performing'
        WHEN 'In Grace Period'    THEN 'Early warning (1-15 days)'
        WHEN 'Late (16-30 days)'  THEN 'Moderate delinquency'
        WHEN 'Late (31-120 days)' THEN 'Severe delinquency (pre-default)'
    END AS risk_tier,
    loan_count,
    active_balance,
    CAST(100e0 * loan_count     / SUM(loan_count)     OVER () AS DECIMAL(9, 4)) AS share_of_active_loans_pct,
    CAST(100e0 * active_balance / SUM(active_balance) OVER () AS DECIMAL(9, 4)) AS share_of_active_balance_pct
FROM agg;
GO
