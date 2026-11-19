USE credit_risk_db;
GO

-- Concentration risk: how much of the book sits in each segment.
-- One row per (dimension, segment). dimension = addr_state, grade, grade_group, purpose, home_ownership.
-- grade_group has two segments, A-D and E-G, so the high-risk grades can be flagged together.
-- Shares add up to 100% within each dimension, for both exposure bases:
--   funded_share_pct = share of everything ever lent
--   active_share_pct = share of money still owed on open loans (used for the flags)
-- Flags come from analytics.risk_thresholds (09_analytics_schema.sql).
CREATE OR ALTER VIEW analytics.vw_concentration_risk AS
WITH loans AS (
    SELECT
        g.addr_state,
        l.grade,
        CASE WHEN l.grade IN ('E', 'F', 'G') THEN 'E-G' ELSE 'A-D' END AS grade_group,
        l.purpose,
        b.home_ownership,
        f.funded_amnt,
        CASE WHEN f.is_default IS NULL THEN 1           ELSE 0 END AS is_active,
        CASE WHEN f.is_default IS NULL THEN f.out_prncp ELSE 0 END AS active_amount
    FROM warehouse.Fact_Loan_Performance AS f
    JOIN warehouse.Dim_Loan      AS l ON l.loan_dim_key  = f.loan_dim_key
    JOIN warehouse.Dim_Borrower  AS b ON b.borrower_key  = f.borrower_key
    JOIN warehouse.Dim_Geography AS g ON g.geography_key = f.geography_key
),
seg AS (
    SELECT
        CASE
            WHEN GROUPING(addr_state)  = 0 THEN 'addr_state'
            WHEN GROUPING(grade)       = 0 THEN 'grade'
            WHEN GROUPING(grade_group) = 0 THEN 'grade_group'
            WHEN GROUPING(purpose)     = 0 THEN 'purpose'
            ELSE 'home_ownership'
        END AS dimension,
        COALESCE(addr_state, grade, grade_group, purpose, home_ownership) AS segment,
        COUNT(*)           AS loans,
        SUM(funded_amnt)   AS funded_exposure,
        SUM(is_active)     AS active_loans,
        SUM(active_amount) AS active_exposure
    FROM loans
    GROUP BY GROUPING SETS ((addr_state), (grade), (grade_group), (purpose), (home_ownership))
),
shares AS (
    SELECT
        *,
        CAST(100e0 * funded_exposure / SUM(funded_exposure) OVER (PARTITION BY dimension) AS DECIMAL(9, 4)) AS funded_share_pct,
        CAST(100e0 * active_exposure / SUM(active_exposure) OVER (PARTITION BY dimension) AS DECIMAL(9, 4)) AS active_share_pct
    FROM seg
)
SELECT
    s.dimension,
    s.segment,
    s.loans,
    s.funded_exposure,
    s.funded_share_pct,
    s.active_loans,
    s.active_exposure,
    s.active_share_pct,
    t.rule_code,
    t.threshold_pct,
    CASE WHEN t.rule_code IS NULL               THEN NULL
         WHEN s.active_share_pct > t.threshold_pct THEN 1
         ELSE 0
    END AS is_breach
FROM shares AS s
LEFT JOIN analytics.risk_thresholds AS t
    ON  t.dimension = s.dimension
    AND (t.segment IS NULL OR t.segment = s.segment);
GO
