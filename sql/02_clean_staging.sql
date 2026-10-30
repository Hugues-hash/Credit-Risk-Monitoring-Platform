USE credit_risk_db;
GO

IF SCHEMA_ID('filtered') IS NULL
    EXEC('CREATE SCHEMA filtered');
GO

DROP TABLE IF EXISTS filtered.loans;
GO

SELECT
    -- ID
    CAST(id AS BIGINT) AS loan_id,

    -- Dates: 'Jun-2013' becomes 2013-06-01
    TRY_CAST('01-' + issue_d          AS DATE)      AS issue_date,
    TRY_CAST('01-' + earliest_cr_line AS DATE)      AS earliest_cr_date,
    TRY_CAST('01-' + last_pymnt_d     AS DATE)      AS last_pymnt_date,
    TRY_CAST('01-' + next_pymnt_d     AS DATE)      AS next_pymnt_date,

    -- Text columns
    loan_status,
    CAST(LEFT(TRIM(term), 2) AS INT) AS term_months,   -- ' 36 months' -> 36
    grade,
    sub_grade,
    ISNULL(emp_length, 'Unknown') AS emp_length,
    CASE WHEN home_ownership IN ('ANY', 'NONE') THEN 'OTHER'
         ELSE home_ownership END AS home_ownership,
    verification_status,
    purpose,
    application_type,
    addr_state,
    zip_code,

    -- Loan amounts
    TRY_CAST(loan_amnt   AS DECIMAL(12, 2))         AS loan_amnt,
    TRY_CAST(funded_amnt AS DECIMAL(12, 2))         AS funded_amnt,
    TRY_CAST(int_rate    AS DECIMAL(5, 2))          AS int_rate,
    TRY_CAST(installment AS DECIMAL(10, 2))         AS installment,

    -- Borrower risk 
    CASE 
        WHEN TRY_CAST(annual_inc AS DECIMAL(14, 2)) < 5000 THEN NULL
        ELSE TRY_CAST(annual_inc AS DECIMAL(14, 2))
    END AS annual_inc,
    
    CASE 
        WHEN TRY_CAST(dti AS DECIMAL(7, 2)) IN (-1, 999) THEN NULL
        ELSE TRY_CAST(dti AS DECIMAL(7, 2))
    END AS dti,

    CASE 
        WHEN TRY_CAST(revol_util AS DECIMAL(6, 2)) > 150.00 THEN NULL
        ELSE TRY_CAST(revol_util AS DECIMAL(6, 2))
    END AS revol_util,

    TRY_CAST(revol_bal      AS DECIMAL(14, 2))      AS revol_bal,
    TRY_CAST(delinq_2yrs    AS FLOAT)               AS delinq_2yrs,
    TRY_CAST(inq_last_6mths AS FLOAT)               AS inq_last_6mths,
    TRY_CAST(open_acc       AS FLOAT)               AS open_acc,
    TRY_CAST(total_acc      AS FLOAT)               AS total_acc,
    TRY_CAST(pub_rec        AS FLOAT)               AS pub_rec,
    (TRY_CAST(fico_range_low AS FLOAT) + TRY_CAST(fico_range_high AS FLOAT)) / 2  AS fico_score,

    -- Repayment so far
    TRY_CAST(out_prncp          AS DECIMAL(12, 2))  AS out_prncp,
    TRY_CAST(total_pymnt        AS DECIMAL(12, 2))  AS total_pymnt,
    TRY_CAST(total_rec_prncp    AS DECIMAL(12, 2))  AS total_rec_prncp,
    TRY_CAST(total_rec_int      AS DECIMAL(12, 2))  AS total_rec_int,
    TRY_CAST(total_rec_late_fee AS DECIMAL(10, 2))  AS total_rec_late_fee,
    TRY_CAST(recoveries         AS DECIMAL(12, 2))  AS recoveries,
    TRY_CAST(last_pymnt_amnt    AS DECIMAL(12, 2))  AS last_pymnt_amnt,

    -- 1 = default, 0 = paid off, NULL = still active
    CASE
        WHEN loan_status IN ('Charged Off', 'Default',
                             'Does not meet the credit policy. Status:Charged Off') THEN 1
        WHEN loan_status IN ('Fully Paid',
                             'Does not meet the credit policy. Status:Fully Paid')  THEN 0
    END AS is_default

INTO filtered.loans
FROM staging.stg_accepted_loans
WHERE loan_status IS NOT NULL;   -- drops the 33 summary rows at the end of the CSV
GO