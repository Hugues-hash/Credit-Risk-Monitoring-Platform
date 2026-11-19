USE credit_risk_db;
GO

-- Exposure and realised loss. One row per (issue_year, grade); add rows up for any total.
--
-- Three exposure views, never mixed up:
--   originated_exposure = everything ever lent (funded_amnt, all loans)
--   active_exposure     = money still owed on open loans (out_prncp where is_default IS NULL)
--   exposure_at_default = principal still owed when a loan defaulted (funded_amnt - total_rec_prncp)
--
-- Loss on defaulted loans (is_default = 1):
--   net_principal_loss          = exposure_at_default - recoveries
--   lgd_pct                     = net_principal_loss / exposure_at_default   (loss given default)
--   loss_rate_on_originated_pct = net_principal_loss / funded_defaulted      (loss vs the amount lent)
-- Recoveries in this data are gross (collection fees are not taken off), so LGD is slightly too low.
-- The 40 'Default' loans are not written off yet; their outstanding balance counts as a loss here.
CREATE OR ALTER VIEW analytics.vw_exposure_loss AS
WITH agg AS (
    SELECT
        d.year_num AS issue_year,
        l.grade,
        COUNT(*)                                                               AS total_loans,
        SUM(f.funded_amnt)                                                     AS originated_exposure,
        SUM(CASE WHEN f.is_default IS NULL THEN 1 ELSE 0 END)                  AS active_loans,
        SUM(CASE WHEN f.is_default IS NULL THEN f.out_prncp ELSE 0 END)        AS active_exposure,
        SUM(CASE WHEN f.is_default = 1 THEN 1 ELSE 0 END)                      AS defaulted_loans,
        SUM(CASE WHEN f.is_default = 1 THEN f.funded_amnt ELSE 0 END)          AS funded_defaulted,
        SUM(CASE WHEN f.is_default = 1 THEN f.total_rec_prncp ELSE 0 END)      AS principal_repaid_before_default,
        SUM(CASE WHEN f.is_default = 1 THEN f.funded_amnt - f.total_rec_prncp ELSE 0 END) AS exposure_at_default,
        SUM(CASE WHEN f.is_default = 1 THEN f.recoveries ELSE 0 END)           AS recoveries,
        SUM(CASE WHEN f.is_default = 1
                 THEN f.funded_amnt - f.total_rec_prncp - f.recoveries ELSE 0 END) AS net_principal_loss
    FROM warehouse.Fact_Loan_Performance AS f
    JOIN warehouse.Dim_Date AS d ON d.date_key     = f.issue_date_key
    JOIN warehouse.Dim_Loan AS l ON l.loan_dim_key = f.loan_dim_key
    GROUP BY d.year_num, l.grade
)
SELECT
    issue_year,
    grade,
    total_loans,
    originated_exposure,
    active_loans,
    active_exposure,
    defaulted_loans,
    funded_defaulted,
    principal_repaid_before_default,
    exposure_at_default,
    recoveries,
    net_principal_loss,
    CAST(100e0 * net_principal_loss / NULLIF(exposure_at_default, 0) AS DECIMAL(9, 4)) AS lgd_pct,
    CAST(100e0 * net_principal_loss / NULLIF(funded_defaulted, 0)    AS DECIMAL(9, 4)) AS loss_rate_on_originated_pct
FROM agg;
GO
