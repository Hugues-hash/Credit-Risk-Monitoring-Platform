USE credit_risk_db;
GO

DELETE FROM warehouse.Fact_Loan_Performance;
DELETE FROM warehouse.Dim_Borrower;
DELETE FROM warehouse.Dim_Loan;
DELETE FROM warehouse.Dim_Geography;
DELETE FROM warehouse.Dim_Status;
DELETE FROM warehouse.Dim_Date;
GO

-- Dim_Borrower: one row per distinct combination of borrower traits
INSERT INTO warehouse.Dim_Borrower (emp_length, home_ownership, verification_status)
SELECT DISTINCT emp_length, home_ownership, verification_status
FROM filtered.loans;
GO

-- Dim_Loan: one row per distinct combination of loan terms
INSERT INTO warehouse.Dim_Loan (term_months, grade, sub_grade, purpose, application_type)
SELECT DISTINCT term_months, grade, sub_grade, purpose, application_type
FROM filtered.loans;
GO

-- Dim_Geography: one row per distinct state + zip code
INSERT INTO warehouse.Dim_Geography (addr_state, zip_code)
SELECT DISTINCT addr_state, zip_code
FROM filtered.loans;
GO

-- Dim_Status: one row per loan status, with its group
INSERT INTO warehouse.Dim_Status (loan_status, status_group)
SELECT DISTINCT
    loan_status,
    CASE
        WHEN loan_status = 'Current'                                    THEN 'Active'
        WHEN loan_status LIKE 'Late%' OR loan_status = 'In Grace Period' THEN 'Late'
        WHEN loan_status LIKE '%Fully Paid'                             THEN 'Paid'
        ELSE 'Defaulted'                                                -- Charged Off, Default
    END
FROM filtered.loans;
GO

-- Dim_Date: one row per day from 2007 (first loan) to 2019 (latest payment date)
WITH days AS (
    SELECT CAST('2007-01-01' AS DATE) AS d        -- starting row
    UNION ALL
    SELECT DATEADD(DAY, 1, d) FROM days WHERE d < '2019-12-31'     -- next row = previous + 1 day
)
INSERT INTO warehouse.Dim_Date (date_key, full_date, month_num, year_num, quarter_num)
SELECT
    YEAR(d) * 10000 + MONTH(d) * 100 + DAY(d),    -- 2018-03-15 -> 20180315
    d,
    MONTH(d),
    YEAR(d),
    DATEPART(QUARTER, d)
FROM days
OPTION (MAXRECURSION 0);
GO
