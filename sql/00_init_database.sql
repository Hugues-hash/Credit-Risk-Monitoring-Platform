-- 1. Create the project database
CREATE DATABASE credit_risk_db;
GO

-- 2. Switch context to the new database
USE credit_risk_db;
GO

-- 3. Create the staging schema for raw tables
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'staging')
	EXEC(N'CREATE SCHEMA staging');
GO