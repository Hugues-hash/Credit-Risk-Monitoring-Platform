USE credit_risk_db;
GO

-- Each issue-quarter cohort next to the economy at the time it was issued (FRED data).
-- One row per issue quarter, all grades together.
-- Use it to ask: were loans issued in weaker or stronger economic times riskier?
-- Remember the maturity caveat: 2017-2018 cohorts have low observed default rates because
-- most of their loans are still open.
CREATE OR ALTER VIEW analytics.vw_vintage_macro AS
WITH cohorts AS (
    SELECT
        d.year_num    AS issue_year,
        d.quarter_num AS issue_quarter,
        COUNT(*)                                                              AS originated_loans,
        SUM(f.funded_amnt)                                                    AS funded_exposure,
        COUNT(f.is_default)                                                   AS closed_loans,
        SUM(CASE WHEN f.is_default = 1 THEN 1 ELSE 0 END)                     AS defaulted_loans,
        SUM(CASE WHEN f.is_default IS NOT NULL THEN f.funded_amnt ELSE 0 END) AS funded_closed,
        SUM(CASE WHEN f.is_default = 1 THEN f.funded_amnt ELSE 0 END)         AS funded_defaulted
    FROM warehouse.Fact_Loan_Performance AS f
    JOIN warehouse.Dim_Date AS d ON d.date_key = f.issue_date_key
    GROUP BY d.year_num, d.quarter_num
),
macro AS (   -- average of the 3 months in each quarter
    SELECT
        d.year_num    AS issue_year,
        d.quarter_num AS issue_quarter,
        AVG(m.unemployment_rate) AS unemployment_rate,
        AVG(m.fed_funds_rate)    AS fed_funds_rate,
        AVG(m.cpi_yoy_inflation) AS inflation_rate
    FROM warehouse.Macro_Monthly AS m
    JOIN warehouse.Dim_Date AS d ON d.date_key = m.month_date_key
    GROUP BY d.year_num, d.quarter_num
)
SELECT
    c.issue_year,
    c.issue_quarter,
    CONCAT(c.issue_year, '-Q', c.issue_quarter) AS cohort,
    c.originated_loans,
    c.funded_exposure,
    c.closed_loans,
    c.defaulted_loans,
    CAST(100e0 * c.closed_loans     / c.originated_loans          AS DECIMAL(9, 4)) AS maturity_rate_pct,
    CAST(100e0 * c.defaulted_loans  / NULLIF(c.closed_loans, 0)   AS DECIMAL(9, 4)) AS default_rate_count_pct,
    CAST(100e0 * c.funded_defaulted / NULLIF(c.funded_closed, 0)  AS DECIMAL(9, 4)) AS default_rate_dollar_pct,
    CAST(m.unemployment_rate AS DECIMAL(5, 2)) AS unemployment_rate,
    CAST(m.fed_funds_rate    AS DECIMAL(5, 2)) AS fed_funds_rate,
    CAST(m.inflation_rate    AS DECIMAL(5, 2)) AS inflation_rate
FROM cohorts AS c
LEFT JOIN macro AS m
    ON  m.issue_year    = c.issue_year
    AND m.issue_quarter = c.issue_quarter;
GO
