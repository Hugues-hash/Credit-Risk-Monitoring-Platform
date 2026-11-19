USE credit_risk_db;
GO

-- Monthly macro data from FRED, kept for the same years as Dim_Date (2007-2019).
-- Input: staging.stg_macro_fred (loaded by python/stage_macro_data.py)
-- No foreign key to Dim_Date, so 04_star_schema.sql can still drop and rebuild Dim_Date.
-- month_date_key uses the same yyyymmdd format, so it joins to Dim_Date.date_key.
DROP TABLE IF EXISTS warehouse.Macro_Monthly;
GO

CREATE TABLE warehouse.Macro_Monthly (
    month_date_key    INT PRIMARY KEY,      -- first day of the month, e.g. 20150301
    month_start       DATE NOT NULL,
    unemployment_rate DECIMAL(5, 2) NULL,   -- % of the labour force out of work
    fed_funds_rate    DECIMAL(5, 2) NULL,   -- US central bank policy rate, %
    cpi_index         DECIMAL(9, 3) NULL,   -- consumer price level
    cpi_yoy_inflation DECIMAL(6, 2) NULL    -- price growth vs the same month a year earlier, %
);
GO

INSERT INTO warehouse.Macro_Monthly
    (month_date_key, month_start, unemployment_rate, fed_funds_rate, cpi_index, cpi_yoy_inflation)
SELECT
    YEAR(d) * 10000 + MONTH(d) * 100 + 1,
    d,
    CAST(TRY_CAST(unemployment_rate AS FLOAT) AS DECIMAL(5, 2)),
    CAST(TRY_CAST(fed_funds_rate    AS FLOAT) AS DECIMAL(5, 2)),
    CAST(TRY_CAST(cpi_index         AS FLOAT) AS DECIMAL(9, 3)),
    CAST(TRY_CAST(cpi_yoy_inflation AS FLOAT) AS DECIMAL(6, 2))
FROM (
    SELECT TRY_CAST([date] AS DATE) AS d, *
    FROM staging.stg_macro_fred
) AS m
WHERE d BETWEEN '2007-01-01' AND '2019-12-01';
GO

-- Expected: 156 months (2007-01 to 2019-12), no empty values
SELECT
    COUNT(*)                     AS months,
    MIN(month_start)             AS first_month,
    MAX(month_start)             AS last_month,
    SUM(CASE WHEN unemployment_rate IS NULL OR fed_funds_rate IS NULL
               OR cpi_yoy_inflation IS NULL THEN 1 ELSE 0 END) AS months_with_gaps
FROM warehouse.Macro_Monthly;
GO
