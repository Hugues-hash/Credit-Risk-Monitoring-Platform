USE credit_risk_db;
GO

-- Vintage curves: for each issue-year cohort, the share of ALL its loans that had defaulted
-- by each month on book (0 to 72). Lets cohorts be compared at the same age.
--
-- How the default month is found: the data is a single snapshot, so there is no default date.
-- We use the months from issue to the LAST PAYMENT as the default month (0 if the borrower
-- never paid). The actual charge-off comes a few months later, so the curves are shifted
-- slightly earlier than reality, but every cohort is shifted the same way.
--
-- A point is only shown when EVERY loan in the cohort is at least that old on the snapshot
-- date (the latest last_pymnt_date, 2019-03-01). Otherwise late-issued loans would pull the
-- curve down. So newer cohorts have shorter curves.
CREATE OR ALTER VIEW analytics.vw_vintage_curves AS
WITH snapshot AS (
    SELECT MAX(d.full_date) AS snapshot_date
    FROM warehouse.Fact_Loan_Performance AS f
    JOIN warehouse.Dim_Date AS d ON d.date_key = f.last_pymnt_date_key
),
loans AS (
    SELECT
        iss.year_num  AS issue_year,
        iss.full_date AS issue_date,
        f.is_default,
        CASE WHEN f.is_default = 1
             THEN COALESCE(DATEDIFF(MONTH, iss.full_date, lp.full_date), 0)
        END AS months_to_default
    FROM warehouse.Fact_Loan_Performance AS f
    JOIN      warehouse.Dim_Date AS iss ON iss.date_key = f.issue_date_key
    LEFT JOIN warehouse.Dim_Date AS lp  ON lp.date_key  = f.last_pymnt_date_key
),
cohorts AS (
    SELECT
        issue_year,
        COUNT(*) AS originated_loans,
        DATEDIFF(MONTH, MAX(issue_date), (SELECT snapshot_date FROM snapshot)) AS months_fully_observed
    FROM loans
    GROUP BY issue_year
),
defaults_by_month AS (
    SELECT issue_year, months_to_default, COUNT(*) AS defaults
    FROM loans
    WHERE is_default = 1
    GROUP BY issue_year, months_to_default
),
months AS (   -- 0 to 72
    SELECT tens.n * 10 + ones.n AS months_on_book
    FROM       (VALUES (0),(1),(2),(3),(4),(5),(6),(7))         AS tens(n)
    CROSS JOIN (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS ones(n)
    WHERE tens.n * 10 + ones.n <= 72
)
SELECT
    c.issue_year,
    m.months_on_book,
    c.originated_loans,
    COALESCE(SUM(dm.defaults), 0) AS cumulative_defaults,
    CAST(100e0 * COALESCE(SUM(dm.defaults), 0) / c.originated_loans AS DECIMAL(9, 4)) AS cumulative_default_rate_pct
FROM cohorts AS c
CROSS JOIN months AS m
LEFT JOIN defaults_by_month AS dm
    ON  dm.issue_year        = c.issue_year
    AND dm.months_to_default <= m.months_on_book
WHERE m.months_on_book <= c.months_fully_observed
GROUP BY c.issue_year, m.months_on_book, c.originated_loans;
GO
