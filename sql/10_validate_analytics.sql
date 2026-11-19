USE credit_risk_db;
GO

-- Checks the analytics views against filtered.loans (the cleaned table, which the views never read).
-- Every row prints the view value, the expected value, the difference and PASS/FAIL.
-- Pass rules: amounts and counts must match exactly; percentages within 0.01 points.
SET NOCOUNT ON;

DROP TABLE IF EXISTS #checks;
CREATE TABLE #checks (
    check_group VARCHAR(40),
    check_name  VARCHAR(100),
    view_value  DECIMAL(20, 4),
    expected    DECIMAL(20, 4),
    tolerance   DECIMAL(20, 4)
);

------------------------------------------------------------------------------------------
-- A. Portfolio-wide conservation checks
------------------------------------------------------------------------------------------

-- A1. Delinquency buckets add up to all open-loan principal
INSERT INTO #checks
SELECT 'A. Conservation', 'Bucket balances = open-loan out_prncp',
       (SELECT SUM(active_balance) FROM analytics.vw_delinquency_buckets),
       (SELECT SUM(out_prncp) FROM filtered.loans WHERE is_default IS NULL), 0;

INSERT INTO #checks
SELECT 'A. Conservation', 'Bucket loan counts = open loans',
       (SELECT SUM(loan_count) FROM analytics.vw_delinquency_buckets),
       (SELECT COUNT(*) FROM filtered.loans WHERE is_default IS NULL), 0;

-- A2. Concentration shares add up to 100% within each dimension (both bases)
INSERT INTO #checks
SELECT 'A. Conservation', 'Funded shares sum to 100%: ' + dimension, SUM(funded_share_pct), 100, 0.01
FROM analytics.vw_concentration_risk GROUP BY dimension;

INSERT INTO #checks
SELECT 'A. Conservation', 'Active shares sum to 100%: ' + dimension, SUM(active_share_pct), 100, 0.01
FROM analytics.vw_concentration_risk GROUP BY dimension;

-- A3. Every loan lands in exactly one cohort
INSERT INTO #checks
SELECT 'A. Conservation', 'Cohort originated_loans = all loans',
       (SELECT SUM(originated_loans) FROM analytics.vw_vintage_cohorts),
       (SELECT COUNT(*) FROM filtered.loans), 0;

INSERT INTO #checks
SELECT 'A. Conservation', 'Cohort funded_exposure = all funded',
       (SELECT SUM(funded_exposure) FROM analytics.vw_vintage_cohorts),
       (SELECT SUM(funded_amnt) FROM filtered.loans), 0;

-- A4. Exposure view totals
INSERT INTO #checks
SELECT 'A. Conservation', 'Originated exposure = all funded',
       (SELECT SUM(originated_exposure) FROM analytics.vw_exposure_loss),
       (SELECT SUM(funded_amnt) FROM filtered.loans), 0;

INSERT INTO #checks
SELECT 'A. Conservation', 'Active exposure = bucket balances',
       (SELECT SUM(active_exposure) FROM analytics.vw_exposure_loss),
       (SELECT SUM(active_balance) FROM analytics.vw_delinquency_buckets), 0;

-- A5. Active vs closed separation: default-rate denominators hold closed loans only
INSERT INTO #checks
SELECT 'A. Conservation', 'Overall closed_loans = loans with an outcome',
       (SELECT closed_loans FROM analytics.vw_default_rates WHERE dimension = 'overall'),
       (SELECT COUNT(*) FROM filtered.loans WHERE is_default IS NOT NULL), 0;

INSERT INTO #checks
SELECT 'A. Conservation', 'Overall defaulted_loans = loans with is_default = 1',
       (SELECT defaulted_loans FROM analytics.vw_default_rates WHERE dimension = 'overall'),
       (SELECT COUNT(*) FROM filtered.loans WHERE is_default = 1), 0;

-- A6. Vintage curves end where the cohort ends: for fully closed cohorts (2007-2012),
--     the last curve point must equal the cohort's defaults / originated loans
INSERT INTO #checks
SELECT 'A. Conservation', 'Curve end = cohort default share: ' + CAST(c.issue_year AS VARCHAR(4)),
       c.cumulative_defaults, v.defaults, 0
FROM analytics.vw_vintage_curves AS c
JOIN (SELECT YEAR(issue_date) AS issue_year, COUNT(*) AS defaults
      FROM filtered.loans WHERE is_default = 1 GROUP BY YEAR(issue_date)) AS v
  ON v.issue_year = c.issue_year
WHERE c.issue_year <= 2012 AND c.months_on_book = 72;

------------------------------------------------------------------------------------------
-- B. Isolated slice hand check: Grade G loans issued in 2015, recalculated from filtered.loans
------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #slice;
SELECT
    COUNT(*)                                                         AS loans,
    SUM(CASE WHEN is_default = 1 THEN 1 ELSE 0 END)                  AS defaulted,
    SUM(CASE WHEN is_default = 0 THEN 1 ELSE 0 END)                  AS paid_off,
    SUM(CASE WHEN is_default IS NULL THEN 1 ELSE 0 END)              AS still_open,
    SUM(funded_amnt)                                                 AS funded,
    SUM(CASE WHEN is_default = 1 THEN funded_amnt     ELSE 0 END)    AS funded_defaulted,
    SUM(CASE WHEN is_default IS NOT NULL THEN funded_amnt ELSE 0 END) AS funded_closed,
    SUM(CASE WHEN is_default = 1 THEN total_rec_prncp ELSE 0 END)    AS repaid_defaulted,
    SUM(CASE WHEN is_default = 1 THEN recoveries      ELSE 0 END)    AS recoveries_defaulted
INTO #slice
FROM filtered.loans
WHERE grade = 'G' AND YEAR(issue_date) = 2015;

DROP TABLE IF EXISTS #vc;
SELECT SUM(originated_loans) AS loans, SUM(closed_loans) AS closed, SUM(defaulted_loans) AS defaulted,
       SUM(funded_exposure) AS funded, SUM(funded_closed) AS funded_closed, SUM(funded_defaulted) AS funded_defaulted
INTO #vc
FROM analytics.vw_vintage_cohorts WHERE issue_year = 2015 AND grade = 'G';

INSERT INTO #checks
SELECT 'B. Grade G 2015', 'Loans (vw_vintage_cohorts)',        v.loans,     s.loans, 0 FROM #vc v, #slice s
;
INSERT INTO #checks
SELECT 'B. Grade G 2015', 'Defaulted loans (vw_vintage_cohorts)', v.defaulted, s.defaulted, 0 FROM #vc v, #slice s
;
INSERT INTO #checks
SELECT 'B. Grade G 2015', 'Closed loans (vw_vintage_cohorts)', v.closed, s.defaulted + s.paid_off, 0 FROM #vc v, #slice s
;
INSERT INTO #checks
SELECT 'B. Grade G 2015', 'Default rate, count % (vw_vintage_cohorts)',
       100e0 * v.defaulted / v.closed, 100e0 * s.defaulted / (s.defaulted + s.paid_off), 0.01 FROM #vc v, #slice s
;
INSERT INTO #checks
SELECT 'B. Grade G 2015', 'Default rate, dollar % (vw_vintage_cohorts)',
       100e0 * v.funded_defaulted / v.funded_closed, 100e0 * s.funded_defaulted / s.funded_closed, 0.01 FROM #vc v, #slice s;

INSERT INTO #checks
SELECT 'B. Grade G 2015', 'Originated exposure (vw_exposure_loss)',
       e.originated_exposure, s.funded, 0
FROM analytics.vw_exposure_loss e, #slice s WHERE e.issue_year = 2015 AND e.grade = 'G'
;
INSERT INTO #checks
SELECT 'B. Grade G 2015', 'Funded, defaulted loans (vw_exposure_loss)', e.funded_defaulted, s.funded_defaulted, 0
FROM analytics.vw_exposure_loss e, #slice s WHERE e.issue_year = 2015 AND e.grade = 'G'
;
INSERT INTO #checks
SELECT 'B. Grade G 2015', 'Recoveries (vw_exposure_loss)', e.recoveries, s.recoveries_defaulted, 0
FROM analytics.vw_exposure_loss e, #slice s WHERE e.issue_year = 2015 AND e.grade = 'G'
;
INSERT INTO #checks
SELECT 'B. Grade G 2015', 'Net principal loss (vw_exposure_loss)', e.net_principal_loss,
       s.funded_defaulted - s.repaid_defaulted - s.recoveries_defaulted, 0
FROM analytics.vw_exposure_loss e, #slice s WHERE e.issue_year = 2015 AND e.grade = 'G'
;
INSERT INTO #checks
SELECT 'B. Grade G 2015', 'LGD % (vw_exposure_loss)', e.lgd_pct,
       100e0 * (s.funded_defaulted - s.repaid_defaulted - s.recoveries_defaulted) / (s.funded_defaulted - s.repaid_defaulted), 0.01
FROM analytics.vw_exposure_loss e, #slice s WHERE e.issue_year = 2015 AND e.grade = 'G';

-- vw_default_rates is not split by year, so check grade G across all years
INSERT INTO #checks
SELECT 'B. Grade G (all years)', 'Default rate, count % (vw_default_rates)', v.default_rate_count_pct,
       (SELECT 100e0 * SUM(is_default) / COUNT(is_default) FROM filtered.loans WHERE grade = 'G'), 0.01
FROM analytics.vw_default_rates v WHERE v.dimension = 'grade' AND v.segment = 'G'
;
INSERT INTO #checks
SELECT 'B. Grade G (all years)', 'Default rate, dollar % (vw_default_rates)', v.default_rate_dollar_pct,
       (SELECT 100e0 * SUM(CASE WHEN is_default = 1 THEN funded_amnt END)
                     / SUM(CASE WHEN is_default IS NOT NULL THEN funded_amnt END)
        FROM filtered.loans WHERE grade = 'G'), 0.01
FROM analytics.vw_default_rates v WHERE v.dimension = 'grade' AND v.segment = 'G';

------------------------------------------------------------------------------------------
-- Results
------------------------------------------------------------------------------------------
SELECT
    check_group,
    check_name,
    view_value,
    expected,
    view_value - expected AS difference,
    CASE WHEN ABS(view_value - expected) <= tolerance THEN 'PASS' ELSE 'FAIL' END AS result
FROM #checks
ORDER BY check_group, check_name;

SELECT
    COUNT(*) AS checks,
    SUM(CASE WHEN ABS(view_value - expected) <= tolerance THEN 1 ELSE 0 END) AS passed,
    SUM(CASE WHEN ABS(view_value - expected) >  tolerance THEN 1 ELSE 0 END) AS failed
FROM #checks;

-- The Grade G 2015 slice, for the record
SELECT * FROM #slice;
GO
