-- SELECT 
--     COUNT(*) AS total_rows,
--     -- Example checks for key Lending Club numeric columns
--     COUNT(loan_amnt) AS non_null_loan_amt,
--     COUNT(*) - COUNT(loan_amnt) AS null_loan_amt,
--     MIN(loan_amnt) AS min_loan_amt,
--     MAX(loan_amnt) AS max_loan_amt,
    
--     MIN(annual_inc) AS min_annual_inc,
--     MAX(annual_inc) AS max_annual_inc
-- FROM [staging].[stg_accepted_loans];


-- SELECT 
--     COUNT(*) - COUNT(loan_id) AS null_loan_ids,
--     COUNT(*) - COUNT(loan_amount) AS null_loan_amounts,
--     COUNT(*) - COUNT(interest_rate) AS null_interest_rates,
--     COUNT(*) - COUNT(annual_income) AS null_annual_incomes
-- FROM [staging].[stg_accepted_loans];


-- Creates an empty summary table in your staging schema (only if it doesn't exist yet)
IF OBJECT_ID('[staging].[stg_loan_profile_summary]', 'U') IS NULL
BEGIN
    CREATE TABLE [staging].[stg_loan_profile_summary] (
        ColumnName VARCHAR(255),
        TotalRows INT,
        NullCount INT,
        NullPercentage DECIMAL(5,2)
    );
END;
GO

-- 1. Clear out old data first
TRUNCATE TABLE [staging].[stg_loan_profile_summary];

-- 2. Insert the profile stats for 'loan_amnt'
INSERT INTO [staging].[stg_loan_profile_summary] (ColumnName, TotalRows, NullCount, NullPercentage)
SELECT 
    'loan_amnt' AS ColumnName,
    COUNT(*) AS TotalRows,
    SUM(CASE WHEN loan_amnt IS NULL THEN 1 ELSE 0 END) AS NullCount,
    CAST(100.0 * SUM(CASE WHEN loan_amnt IS NULL THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0)AS DECIMAL(5,2)) AS NullPercentage
FROM [staging].[stg_accepted_loans];

SELECT * FROM [staging].[stg_loan_profile_summary];
