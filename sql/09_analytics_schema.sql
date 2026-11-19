USE credit_risk_db;
GO

-- analytics: reporting views on top of the warehouse.
-- Power BI and Python read from here, so every report uses the same numbers.
IF SCHEMA_ID('analytics') IS NULL
    EXEC('CREATE SCHEMA analytics');
GO

-- Early-warning thresholds used by analytics.vw_concentration_risk.
-- Kept in a table so they can be changed without editing any view.
-- Starting values sit about 1.5-2 points above the level on the 2019-03 snapshot,
-- so a flag means "concentration is growing", not "this is how the book always looks".
-- To be confirmed in Phase 5 (early warnings).
DROP TABLE IF EXISTS analytics.risk_thresholds;
GO

CREATE TABLE analytics.risk_thresholds (
    rule_code       VARCHAR(30)   PRIMARY KEY,
    dimension       VARCHAR(30)   NOT NULL,   -- matches vw_concentration_risk.dimension
    segment         VARCHAR(50)   NULL,       -- NULL = applies to every segment of the dimension
    threshold_pct   DECIMAL(9, 4) NOT NULL,   -- flag when active_share_pct is above this
    description     VARCHAR(200)  NOT NULL
);
GO

INSERT INTO analytics.risk_thresholds (rule_code, dimension, segment, threshold_pct, description) VALUES
    ('STATE_SINGLE',   'addr_state',  NULL,  15.00, 'Any single state above 15% of active exposure (CA is 13.3% today)'),
    ('PURPOSE_SINGLE', 'purpose',     NULL,  60.00, 'Any single loan purpose above 60% of active exposure (debt_consolidation is 58.4% today)'),
    ('GRADE_EFG',      'grade_group', 'E-G',  8.00, 'Grades E, F and G together above 8% of active exposure (6.5% today)');
GO
