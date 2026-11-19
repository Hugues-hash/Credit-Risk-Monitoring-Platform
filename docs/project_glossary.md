# Project Glossary

## Data Terms

### ETL (Extract, Transform, Load)
The process of moving data from a source into a database.
- **Extract:** `python/stage_raw_data.py` reads the CSV in chunks.
- **Transform:** `sql/02_clean_staging.sql` fixes types, text values and bad values.
- **Load:** the raw data goes into `staging`, the cleaned data into `filtered`, and the star schema into `warehouse`.

### Schema
A folder inside the database that groups tables. This project uses four: `staging` (raw data), `filtered` (cleaned data), `warehouse` (star schema) and `analytics` (risk metric views).

### Star Schema
A database design with one central fact table linked to several dimension tables.

### Dimension Table (`Dim_...`)
A table of descriptive values used to filter and group data, such as state, grade or loan status. This project has `Dim_Borrower`, `Dim_Loan`, `Dim_Geography`, `Dim_Date` and `Dim_Status`.

### Fact Table (`Fact_...`)
The central table that holds the numbers (amounts, rates, scores) and the keys that link to each dimension. This project has `Fact_Loan_Performance`, with one row per loan.

### Surrogate Key
A number created by the database to identify a row, such as `borrower_key`. The fact table stores these numbers instead of repeating the text values.

### View (`vw_...`)
A saved query that looks like a table but stores no data of its own. Every time you read it, it recalculates from the tables underneath, so it is always up to date. The risk metrics are views in the `analytics` schema, such as `analytics.vw_default_rates`.

### Analytics Layer (`analytics` schema)
The last layer of the database, made of views built on the warehouse. Power BI and Python read from here, so every report shows the same numbers. It also holds one settings table, `analytics.risk_thresholds`.

### Grain
What one row of a table or view stands for. `Fact_Loan_Performance` has a grain of one row per loan, and `vw_exposure_loss` one row per issue year and grade. Knowing the grain tells you what you can safely add up.

### Snapshot
A picture of the data at one moment. The LendingClub file is a single snapshot taken around **2019-03-01**: each loan appears once, with its status on that date. We cannot see how a loan's status changed month by month.

### Conservation Check
A test that nothing was lost or counted twice: the parts must add up to the whole. For example, the balances of the four delinquency buckets must add up to exactly the total balance of all open loans.

### Hand Check
Recalculating a small slice of the data by a completely separate route (Excel, pandas or a standalone query) and comparing it with the view. If both routes give the same answer, the view's logic is very likely right. We use Grade G loans issued in 2015.

### Integer Division
In SQL Server, dividing one whole number by another throws away the decimals: `1 / 4` gives `0`, not `0.25`. Because `is_default` is a whole number, `SUM(is_default) / COUNT(is_default)` would always give 0. Our views write `100e0 * ...` first, which turns the maths into decimal maths.

### FRED (Federal Reserve Economic Data)
A free online database of US economic figures run by the Federal Reserve Bank of St. Louis. We use it for the unemployment rate, the Fed funds rate and inflation, stored in `warehouse.Macro_Monthly`.

### Macro Data (Macroeconomic Data)
Figures about the whole economy rather than one borrower, such as unemployment and interest rates. They help explain why loans issued in some periods did worse than others.

### Percentage Point
The plain difference between two percentages. Going from 2% to 3% is a rise of **1 percentage point**, but a rise of **50 percent** (because 1 is half of 2). Thresholds in this project are written in points.

---

## Credit Risk Terms

### Loan Status (`loan_status`)
The current state of a loan, such as Current, Fully Paid or Charged Off. Stored in `Dim_Status`, together with `status_group` (Active, Late, Paid, Defaulted).

### Default
When a borrower stops making the required payments. In this project, `is_default = 1` for Charged Off and Default loans, `0` for Fully Paid loans, and `NULL` for loans that are still open.

### Charged Off
The lender has written the loan off as a loss because the borrower is far behind and collection has failed. This is the most common default status in the data.

### Grace Period
A short window (usually up to 15 days) after a payment is due, during which the borrower can pay without a late fee.

### Late (`Late (16-30 days)` / `Late (31-120 days)`)
The borrower has missed a payment beyond the grace period. Late loans are at high risk of default but are not counted as defaults.

### Joint Application
A loan that two people apply for together. For these loans the combined income (`annual_inc_joint`) and combined DTI (`dti_joint`) are used.

### DTI (Debt-to-Income Ratio)
A borrower's monthly debt payments divided by their monthly income, as a percentage. Higher DTI means more risk.

### FICO Score
The standard US credit score, from 300 to 850. Higher means lower risk. LendingClub gives a range (`fico_range_low`, `fico_range_high`), so `fico_score` is the average of the two. In this data it ranges from 612 to 847.5.

`last_fico_range_low` and `last_fico_range_high` are not used. They are measured after the loan was issued, so they already reflect whether the borrower defaulted and would leak the outcome into the model.

### Revolving Utilization (`revol_util`)
How much of their available credit card limit a borrower is using, as a percentage. Values above 100% mean the borrower is over their limit.

### Closed Loan / Open (Active) Loan
- **Closed:** the story is over. The loan was either paid off or defaulted (`is_default` is 0 or 1).
- **Open (active):** the borrower is still paying, or is late (`is_default` is empty). We don't know yet how it will end.

### Default Rate
The share of loans that went bad. We only count **closed** loans, because open loans have no outcome yet. There are two versions:
- **Count-based:** defaulted loans ÷ closed loans. *"What share of borrowers failed?"*
- **Dollar-weighted:** money lent on defaulted loans ÷ money lent on closed loans. *"What share of the money went to borrowers who failed?"* Big loans count more.

### Maturity Rate
The share of a group of loans that has closed (been paid off or defaulted). A low maturity rate warns that the group's default rate is not final yet. Most of its loans are still open, and the ones that have already closed are mostly people who paid off early, so the default rate looks better than it will end up.

### Exposure
How much money the lender stands to lose. We use three kinds:
- **Originated exposure:** all the money ever lent (`funded_amnt`).
- **Active exposure:** the money still owed on open loans today (`out_prncp`). This is the money really at risk now.
- **Exposure at default (EAD):** how much was still owed at the moment a loan defaulted: the amount lent minus the principal already repaid.

### Outstanding Principal (`out_prncp`)
The part of the original loan amount that the borrower still has to pay back, not counting future interest.

### Recoveries
Money collected from a borrower **after** the loan defaulted, for example through a collection agency or a debt sale.

### Net Principal Loss
The money actually lost on a defaulted loan: exposure at default minus recoveries.

### LGD (Loss Given Default)
When a loan defaults, the share of what was still owed that is never recovered. LGD = net principal loss ÷ exposure at default. Our LendingClub loans have an LGD of about **89%**: once a borrower defaults, the lender gets back only about 11 cents of each dollar still owed. That is typical for unsecured loans, which have no house or car to sell.

### PD (Probability of Default)
The chance that a borrower will default, from 0% to 100%. This is what the optional Phase 7 model will predict for each loan.

### Expected Loss
The standard formula banks use to estimate future losses: **Expected Loss = PD × LGD × EAD**. For example: a 10% chance of default × 89% lost if it happens × $10,000 owed = $890 expected loss.

### Write-off
When the lender officially records a loan as lost. "Charged Off" in the data means the loan has been written off.

### Delinquency
Being behind on payments. A delinquent loan is not a default yet, but it is the main warning sign that one is coming.

### DPD (Days Past Due)
How many days late the borrower's oldest missed payment is. "31+ DPD" means more than 30 days late.

### Delinquency Buckets
Open loans grouped by how late they are: Current → In Grace Period (1–15 days) → Late 16–30 days → Late 31–120 days. The further right, the closer to default.

### Delinquency Rate
The share of the open balance that is behind on payments at all (grace period or late). It was **4.04%** on the snapshot date.

### Roll Rate
The share of loans that move from one delinquency bucket to a worse one from one month to the next (for example, 30 days late in March to 60 days late in April). It needs monthly history of each loan, which our data does not have, so we use the **delinquency funnel** instead: it compares the size of each bucket on a single date.

### Proxy
A stand-in measure used when the real one cannot be calculated. The delinquency funnel is a proxy for roll rates, and the last payment date is a proxy for the default date.

### Cohort / Vintage
A group of loans issued in the same period, such as "2015-Q1". The name comes from wine: like a wine year, a loan vintage tells you when it was "made". Comparing vintages shows whether lending standards got looser or stricter over time.

### Underwriting
The lender's process of checking a borrower and deciding whether to lend, and at what interest rate. Weaker underwriting shows up later as worse vintages.

### Months on Book (MOB)
How many months have passed since a loan was issued, i.e. the loan's age.

### Vintage Curve
A line showing, for one cohort, the share of its loans that had defaulted by each month on book. Putting several cohorts' curves on one chart compares them **at the same age**, which is fair even when some cohorts are much newer than others.

### Concentration Risk
The danger of having too much of the loan book in one place: one state, one loan purpose or one risk grade. If that one area has trouble, for example a recession in California, a large part of the book suffers at once.

### Early Warning / Threshold / Breach
- **Early warning:** a signal that risk is building, raised before losses happen.
- **Threshold:** the agreed limit, for example "no single state above 15% of the open balance". Ours are stored in `analytics.risk_thresholds`.
- **Breach:** when a measure goes past its threshold. The view then sets `is_breach = 1`, which Power BI can show as a red alert.

---

## Economic Terms

### Unemployment Rate
The percentage of people who want a job but don't have one. When it rises, more borrowers lose their income and loan defaults usually rise too.

### Fed Funds Rate
The interest rate set by the US Federal Reserve, the US central bank. It drives most other interest rates. It was near 0% from 2009 to 2015, which made borrowing cheap.

### Inflation / CPI
- **CPI (Consumer Price Index):** the average price of a fixed basket of everyday goods and services.
- **Inflation:** how fast CPI is rising, usually measured against the same month a year earlier. High inflation makes household budgets tighter.
