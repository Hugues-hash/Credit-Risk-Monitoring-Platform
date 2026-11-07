USE credit_risk_db;
GO

IF SCHEMA_ID('warehouse') IS NULL
BEGIN
    EXEC('CREATE SCHEMA warehouse;');
END
GO

DROP TABLE IF EXISTS warehouse.Fact_Loan_Performance;
DROP TABLE IF EXISTS warehouse.Dim_Borrower;
DROP TABLE IF EXISTS warehouse.Dim_Loan;
DROP TABLE IF EXISTS warehouse.Dim_Geography;
DROP TABLE IF EXISTS warehouse.Dim_Date;
DROP TABLE IF EXISTS warehouse.Dim_Status;
GO

-- Borrower details
CREATE TABLE warehouse.Dim_Borrower (
    borrower_key INT IDENTITY(1,1) PRIMARY KEY,
    emp_length VARCHAR(20) NULL,
    home_ownership VARCHAR(20) NULL,
    verification_status VARCHAR(50) NULL
);
GO

-- Loan terms and grade
CREATE TABLE warehouse.Dim_Loan (
    loan_dim_key INT IDENTITY(1,1) PRIMARY KEY,
    term_months INT NULL,
    grade CHAR(1) NULL,
    sub_grade VARCHAR(5) NULL,
    purpose VARCHAR(50) NULL,
    application_type VARCHAR(50) NULL
);
GO

-- Borrower location
CREATE TABLE warehouse.Dim_Geography (
    geography_key INT IDENTITY(1,1) PRIMARY KEY,
    addr_state CHAR(2) NULL,
    zip_code VARCHAR(10) NULL
);
GO

-- Calendar, one row per day
CREATE TABLE warehouse.Dim_Date (
    date_key INT PRIMARY KEY, 
    full_date DATE NULL,
    month_num INT NULL,
    year_num INT NULL,
    quarter_num INT NULL
);
GO

-- Loan status and its group
CREATE TABLE warehouse.Dim_Status (
    status_key INT IDENTITY(1,1) PRIMARY KEY,
    loan_status VARCHAR(100) NULL,
    status_group VARCHAR(20) NULL -- Active, Late, Paid, Defaulted
);
GO

CREATE TABLE warehouse.Fact_Loan_Performance (
    loan_fact_key INT IDENTITY(1,1) PRIMARY KEY,
    loan_id BIGINT NOT NULL, 
    
    -- Keys to the dimensions
    borrower_key INT NULL,
    loan_dim_key INT NULL,
    geography_key INT NULL,
    status_key INT NULL,
    issue_date_key INT NULL,
    last_pymnt_date_key INT NULL,
    next_pymnt_date_key INT NULL,

    -- Loan amounts
    loan_amnt DECIMAL(12, 2) NULL,
    funded_amnt DECIMAL(12, 2) NULL,
    int_rate DECIMAL(5, 2) NULL,
    installment DECIMAL(10, 2) NULL,

    -- Borrower risk
    annual_inc DECIMAL(14, 2) NULL,
    dti DECIMAL(7, 2) NULL,
    revol_util DECIMAL(6, 2) NULL,
    revol_bal DECIMAL(14, 2) NULL,
    fico_score FLOAT NULL,
    credit_history_months INT NULL,
    delinq_2yrs FLOAT NULL,
    inq_last_6mths FLOAT NULL,
    open_acc FLOAT NULL,
    total_acc FLOAT NULL,
    pub_rec FLOAT NULL,

    -- Repayment so far
    out_prncp DECIMAL(12, 2) NULL,
    total_pymnt DECIMAL(12, 2) NULL,
    total_rec_prncp DECIMAL(12, 2) NULL,
    total_rec_int DECIMAL(12, 2) NULL,
    total_rec_late_fee DECIMAL(10, 2) NULL,
    recoveries DECIMAL(12, 2) NULL,
    last_pymnt_amnt DECIMAL(12, 2) NULL,

    -- 1 = default, 0 = paid off, NULL = still open
    is_default INT NULL,

    -- Each loan can appear only once
    CONSTRAINT UQ_Fact_Loan_Id UNIQUE (loan_id),

    -- Foreign keys
    CONSTRAINT FK_Fact_Borrower FOREIGN KEY (borrower_key) REFERENCES warehouse.Dim_Borrower(borrower_key),
    CONSTRAINT FK_Fact_Loan FOREIGN KEY (loan_dim_key) REFERENCES warehouse.Dim_Loan(loan_dim_key),
    CONSTRAINT FK_Fact_Geography FOREIGN KEY (geography_key) REFERENCES warehouse.Dim_Geography(geography_key),
    CONSTRAINT FK_Fact_Status FOREIGN KEY (status_key) REFERENCES warehouse.Dim_Status(status_key),
    CONSTRAINT FK_Fact_Issue_Date FOREIGN KEY (issue_date_key) REFERENCES warehouse.Dim_Date(date_key),
    CONSTRAINT FK_Fact_Last_Pymnt_Date FOREIGN KEY (last_pymnt_date_key) REFERENCES warehouse.Dim_Date(date_key),
    CONSTRAINT FK_Fact_Next_Pymnt_Date FOREIGN KEY (next_pymnt_date_key) REFERENCES warehouse.Dim_Date(date_key)
);
GO