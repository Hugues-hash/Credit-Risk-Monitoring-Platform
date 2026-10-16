USE credit_risk_db;
GO

-- ============================================================================
-- 1. IDENTIFIERS
-- Target: Verify uniqueness, primary key viability, and check for duplicates
-- ============================================================================
SELECT 
    COUNT(*) AS total_rows,
    COUNT(DISTINCT id) AS unique_ids,
    COUNT(*) - COUNT(DISTINCT id) AS duplicate_ids,
    COUNT(member_id) AS non_null_member_ids,
    COUNT(DISTINCT member_id) AS unique_member_ids
FROM staging.stg_accepted_loans;

-- Check sample duplicate IDs if any exist
SELECT id, COUNT(*) AS occurrences
FROM staging.stg_accepted_loans
GROUP BY id
HAVING COUNT(*) > 1;


-- ============================================================================
-- 2. LOAN STATUS & PERFORMANCE
-- Target: Map target variable categories, default definitions, date completeness
-- ============================================================================
-- Distribution of loan status categories
SELECT 
    loan_status,
    COUNT(*) AS loan_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct_of_total
FROM staging.stg_accepted_loans
GROUP BY loan_status
ORDER BY loan_count DESC;

-- Missingness in payment dates
SELECT 
    SUM(CASE WHEN last_pymnt_d IS NULL THEN 1 ELSE 0 END) AS missing_last_pymnt_d,
    SUM(CASE WHEN next_pymnt_d IS NULL THEN 1 ELSE 0 END) AS missing_next_pymnt_d
FROM staging.stg_accepted_loans;


-- ============================================================================
-- 3. FINANCIAL EXPOSURE & TERMS
-- Target: Range verification, negative values, and term formatting
-- ============================================================================
SELECT 
    MIN(TRY_CAST(loan_amnt AS FLOAT)) AS min_loan_amnt,
    MAX(TRY_CAST(loan_amnt AS FLOAT)) AS max_loan_amnt,
    AVG(TRY_CAST(loan_amnt AS FLOAT)) AS avg_loan_amnt,
    MIN(TRY_CAST(funded_amnt AS FLOAT)) AS min_funded_amnt,
    MAX(TRY_CAST(funded_amnt AS FLOAT)) AS max_funded_amnt,
    MIN(TRY_CAST(int_rate AS FLOAT)) AS min_int_rate,
    MAX(TRY_CAST(int_rate AS FLOAT)) AS max_int_rate,
    MIN(TRY_CAST(installment AS FLOAT)) AS min_installment,
    MAX(TRY_CAST(installment AS FLOAT)) AS max_installment
FROM staging.stg_accepted_loans;

-- Distinct term formatting (checks for whitespace, e.g., ' 36 months' vs '36 months')
SELECT 
    term, 
    COUNT(*) AS loan_count
FROM staging.stg_accepted_loans
GROUP BY term;


-- ============================================================================
-- 4. BORROWER RISK PROFILE
-- Target: Outliers, negative values, null rates in critical modeling drivers
-- ============================================================================
SELECT 
    -- Income checks
    MIN(TRY_CAST(annual_inc AS FLOAT)) AS min_annual_inc,
    MAX(TRY_CAST(annual_inc AS FLOAT)) AS max_annual_inc,
    AVG(TRY_CAST(annual_inc AS FLOAT)) AS avg_annual_inc,
    SUM(CASE WHEN annual_inc IS NULL THEN 1 ELSE 0 END) AS null_annual_inc,
    SUM(CASE WHEN TRY_CAST(annual_inc AS FLOAT) = 0 THEN 1 ELSE 0 END) AS zero_annual_inc,

    -- DTI checks
    MIN(TRY_CAST(dti AS FLOAT)) AS min_dti,
    MAX(TRY_CAST(dti AS FLOAT)) AS max_dti,
    AVG(TRY_CAST(dti AS FLOAT)) AS avg_dti,
    SUM(CASE WHEN dti IS NULL THEN 1 ELSE 0 END) AS null_dti,

    -- Revolving utilization & Delinquency checks
    MIN(TRY_CAST(revol_util AS FLOAT)) AS min_revol_util,
    MAX(TRY_CAST(revol_util AS FLOAT)) AS max_revol_util,
    SUM(CASE WHEN revol_util IS NULL THEN 1 ELSE 0 END) AS null_revol_util,
    MAX(TRY_CAST(delinq_2yrs AS FLOAT)) AS max_delinq_2yrs,
    SUM(CASE WHEN delinq_2yrs IS NULL THEN 1 ELSE 0 END) AS null_delinq_2yrs
FROM staging.stg_accepted_loans;


-- ============================================================================
-- 5. RISK SEGMENTATION & CLASSIFICATION
-- Target: Categorical integrity and inconsistent strings
-- ============================================================================
-- Check grade and subgrade consistency
SELECT 
    grade, 
    COUNT(DISTINCT sub_grade) AS distinct_subgrades,
    COUNT(*) AS volume
FROM staging.stg_accepted_loans
GROUP BY grade
ORDER BY grade ASC;

-- Check employment length strings
SELECT 
    emp_length, 
    COUNT(*) AS volume
FROM staging.stg_accepted_loans
GROUP BY emp_length
ORDER BY volume DESC;

-- Check home ownership categories (look for unexpected values like NONE, ANY)
SELECT 
    home_ownership, 
    COUNT(*) AS volume
FROM staging.stg_accepted_loans
GROUP BY home_ownership
ORDER BY volume DESC;


-- ============================================================================
-- 6. TEMPORAL / DATE FIELDS
-- Target: Date formats, unparseable strings, date boundaries (2007–2018)
-- ============================================================================
SELECT 
    MIN(issue_d) AS earliest_issue_string,
    MAX(issue_d) AS latest_issue_string,
    SUM(CASE WHEN issue_d IS NULL THEN 1 ELSE 0 END) AS null_issue_d,
    SUM(CASE WHEN earliest_cr_line IS NULL THEN 1 ELSE 0 END) AS null_earliest_cr_line
FROM staging.stg_accepted_loans;

-- Distinct year-month sample check (issue_d is typically formatted as 'Mon-YYYY')
SELECT TOP 10 
    issue_d, 
    COUNT(*) AS volume
FROM staging.stg_accepted_loans
GROUP BY issue_d
ORDER BY volume DESC;


-- ============================================================================
-- 7. GEOGRAPHIC CONTEXT
-- Target: Validate state code standards (50 US states + DC/territories) and zip formats
-- ============================================================================
SELECT 
    COUNT(DISTINCT addr_state) AS distinct_states,
    SUM(CASE WHEN addr_state IS NULL THEN 1 ELSE 0 END) AS null_states,
    COUNT(DISTINCT zip_code) AS distinct_zip_codes,
    SUM(CASE WHEN zip_code IS NULL THEN 1 ELSE 0 END) AS null_zip_codes
FROM staging.stg_accepted_loans;

-- List state codes to spot invalid 2-character strings
SELECT 
    addr_state, 
    COUNT(*) AS loan_count
FROM staging.stg_accepted_loans
GROUP BY addr_state
ORDER BY loan_count DESC;