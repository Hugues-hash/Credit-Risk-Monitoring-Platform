USE credit_risk_db;
GO

DELETE FROM warehouse.Fact_Loan_Performance;
GO

INSERT INTO warehouse.Fact_Loan_Performance (
    loan_id,
    borrower_key, loan_dim_key, geography_key, status_key,
    issue_date_key, last_pymnt_date_key, next_pymnt_date_key,
    loan_amnt, funded_amnt, int_rate, installment,
    annual_inc, dti, revol_util, revol_bal, fico_score, credit_history_months,
    delinq_2yrs, inq_last_6mths, open_acc, total_acc, pub_rec,
    out_prncp, total_pymnt, total_rec_prncp, total_rec_int, total_rec_late_fee, recoveries, last_pymnt_amnt,
    is_default
)
SELECT
    f.loan_id,

    -- Keys looked up from the dimensions
    b.borrower_key,
    l.loan_dim_key,
    g.geography_key,
    s.status_key,

    -- Date keys: the date written as a number (2018-03-01 -> 20180301). A missing date gives NULL.
    YEAR(f.issue_date)       * 10000 + MONTH(f.issue_date)       * 100 + DAY(f.issue_date),
    YEAR(f.last_pymnt_date)  * 10000 + MONTH(f.last_pymnt_date)  * 100 + DAY(f.last_pymnt_date),
    YEAR(f.next_pymnt_date)  * 10000 + MONTH(f.next_pymnt_date)  * 100 + DAY(f.next_pymnt_date),

    -- Measures copied straight from filtered.loans
    f.loan_amnt, f.funded_amnt, f.int_rate, f.installment,
    f.annual_inc, f.dti, f.revol_util, f.revol_bal, f.fico_score,
    DATEDIFF(MONTH, f.earliest_cr_date, f.issue_date),   -- credit_history_months: first credit line to loan issue
    f.delinq_2yrs, f.inq_last_6mths, f.open_acc, f.total_acc, f.pub_rec,
    f.out_prncp, f.total_pymnt, f.total_rec_prncp, f.total_rec_int, f.total_rec_late_fee, f.recoveries, f.last_pymnt_amnt,
    f.is_default

FROM filtered.loans AS f
JOIN warehouse.Dim_Borrower AS b
    ON  b.emp_length          = f.emp_length
    AND b.home_ownership      = f.home_ownership
    AND b.verification_status = f.verification_status
JOIN warehouse.Dim_Loan AS l
    ON  l.term_months      = f.term_months
    AND l.grade            = f.grade
    AND l.sub_grade        = f.sub_grade
    AND l.purpose          = f.purpose
    AND l.application_type = f.application_type
JOIN warehouse.Dim_Geography AS g
    ON  g.addr_state = f.addr_state
    AND g.zip_code IS NOT DISTINCT FROM f.zip_code     -- also matches the 1 loan with no zip code
JOIN warehouse.Dim_Status AS s
    ON  s.loan_status = f.loan_status;
GO
