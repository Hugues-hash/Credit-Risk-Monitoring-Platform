USE credit_risk_db;
GO

-- Delinquency funnel: a stand-in for roll rates. One row for the whole open book.
--
-- True roll rates need monthly snapshots of each loan (which bucket it was in last month
-- and this month). This data is a single snapshot, so we can only compare bucket sizes.
-- The stage ratios below are NOT roll rates: the buckets have different widths
-- (grace = 15 days, 16-30 = 15 days, 31-120 = 90 days), so a later bucket can be larger
-- than an earlier one simply because it covers more days.
CREATE OR ALTER VIEW analytics.vw_delinquency_funnel AS
WITH b AS (
    SELECT
        SUM(f.out_prncp)                                                                AS active_balance,
        SUM(CASE WHEN s.loan_status = 'Current'            THEN f.out_prncp ELSE 0 END) AS current_balance,
        SUM(CASE WHEN s.loan_status = 'In Grace Period'    THEN f.out_prncp ELSE 0 END) AS grace_balance,
        SUM(CASE WHEN s.loan_status = 'Late (16-30 days)'  THEN f.out_prncp ELSE 0 END) AS late_16_30_balance,
        SUM(CASE WHEN s.loan_status = 'Late (31-120 days)' THEN f.out_prncp ELSE 0 END) AS late_31_120_balance
    FROM warehouse.Fact_Loan_Performance AS f
    JOIN warehouse.Dim_Status AS s ON s.status_key = f.status_key
    WHERE f.is_default IS NULL
)
SELECT
    active_balance,
    current_balance,
    grace_balance,
    late_16_30_balance,
    late_31_120_balance,
    grace_balance + late_16_30_balance + late_31_120_balance AS delinquent_balance,

    -- Share of the open book that is behind on payments at all
    CAST(100e0 * (grace_balance + late_16_30_balance + late_31_120_balance)
               / NULLIF(active_balance, 0) AS DECIMAL(9, 4)) AS delinquency_rate_pct,

    -- Share of the open book more than 30 days late (the bucket starts at day 31)
    CAST(100e0 * late_31_120_balance / NULLIF(active_balance, 0) AS DECIMAL(9, 4)) AS dpd_31_plus_rate_pct,

    -- Of everything behind on payments, how much is in the most severe bucket
    CAST(100e0 * late_31_120_balance
               / NULLIF(grace_balance + late_16_30_balance + late_31_120_balance, 0) AS DECIMAL(9, 4)) AS severe_to_total_delinquency_pct,

    -- Stage-to-stage balance ratios (see the note above: not roll rates)
    CAST(1e0 * late_16_30_balance  / NULLIF(grace_balance, 0)      AS DECIMAL(9, 4)) AS ratio_16_30_to_grace,
    CAST(1e0 * late_31_120_balance / NULLIF(late_16_30_balance, 0) AS DECIMAL(9, 4)) AS ratio_31_120_to_16_30
FROM b;
GO
