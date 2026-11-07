# Data Loading Process

How the cleaned data in `filtered.loans` is loaded into the `warehouse` star schema.

| Order | Script | What it does |
|---|---|---|
| 1 | `sql/04_star_schema.sql` | Creates the empty warehouse tables |
| 2 | `sql/05_load_dimensions.sql` | Fills the five dimension tables |
| 3 | `sql/06_load_fact.sql` | Fills the fact table |
| 4 | `sql/07_validate_warehouse.sql` | Checks the load |

Dimensions are loaded before the fact table, because the fact table stores the dimension keys.

Scripts 05 and 06 empty their tables before loading, so they can be run again at any time.

## Step 1: Load the dimensions

Each dimension is filled with `SELECT DISTINCT` on its columns, which keeps one row per combination of values that appears in the data. SQL Server numbers the rows automatically (`IDENTITY`).

| Table | Columns | Rows |
|---|---|---:|
| `Dim_Borrower` | `emp_length`, `home_ownership`, `verification_status` | 144 |
| `Dim_Loan` | `term_months`, `grade`, `sub_grade`, `purpose`, `application_type` | 1,626 |
| `Dim_Geography` | `addr_state`, `zip_code` | 3,423 |
| `Dim_Status` | `loan_status`, `status_group` | 9 |
| `Dim_Date` | `date_key`, `full_date`, `month_num`, `year_num`, `quarter_num` | 4,748 |

Notes:

- `Dim_Borrower` has every possible combination: 12 employment lengths × 4 home ownership types × 3 verification statuses = 144.
- `Dim_Loan` could have up to 1,960 combinations (2 terms × 35 sub-grades × 14 purposes × 2 application types), but only 1,626 appear in the data. Grade does not add to the count because each sub-grade belongs to one grade.
- `Dim_Geography` has more rows than there are zip codes (956), because some 3-digit zip codes appear under more than one state.
- `Dim_Status` groups each status:

  | `status_group` | `loan_status` |
  |---|---|
  | Active | Current |
  | Late | In Grace Period, Late (16-30 days), Late (31-120 days) |
  | Paid | Fully Paid, Does not meet the credit policy. Status:Fully Paid |
  | Defaulted | Charged Off, Default, Does not meet the credit policy. Status:Charged Off |

- `Dim_Date` is not built from the loan data. It is a calendar with one row per day from 2007-01-01 to 2019-12-31, which covers the first loan (June 2007) and the latest `next_pymnt_d` (May 2019). `date_key` is the date written as a number, for example `2018-03-15` → `20180315`.

## Step 2: Load the fact table

Each loan in `filtered.loans` is joined to the dimensions on the same columns that built them, to get its keys:

| Key | Matched on |
|---|---|
| `borrower_key` | `emp_length`, `home_ownership`, `verification_status` |
| `loan_dim_key` | `term_months`, `grade`, `sub_grade`, `purpose`, `application_type` |
| `geography_key` | `addr_state`, `zip_code` |
| `status_key` | `loan_status` |

One loan has no zip code. The geography join uses `IS NOT DISTINCT FROM` instead of `=` so that this loan still matches its row in `Dim_Geography`.

The three date keys (`issue_date_key`, `last_pymnt_date_key`, `next_pymnt_date_key`) are calculated directly from the dates with the same `YYYYMMDD` formula as `Dim_Date`, so no join is needed. A missing date gives a `NULL` key, for example `next_pymnt_date_key` on a closed loan.

`earliest_cr_date` (when the borrower opened their first credit account) is not stored as a date key. It goes back to 1933, which would stretch the calendar far beyond the loan period. Instead it becomes `credit_history_months`, the number of months between the first credit account and the loan's issue date. This is also the form the model needs.

All the other numeric columns (loan amounts, borrower risk values, repayment amounts and `is_default`) are copied from `filtered.loans` unchanged.

## Step 3: Validate

`sql/07_validate_warehouse.sql` runs five checks. Results from the latest load:

| Check | Result |
|---|---|
| Fact rows | 2,260,668, same as `filtered.loans` |
| Total `funded_amnt` | $34,004,208,600 in both `filtered.loans` and the fact table |
| Defaults (`is_default = 1`) | 269,360 in both |
| Loans missing a borrower, loan, geography, status or issue date key | 0 |
| Empty optional date keys | `last_pymnt_date_key` 2,427, `next_pymnt_date_key` 1,345,310 |
| `credit_history_months` | Empty for 29 loans, range 6 to 999 months |

The empty values match the missing dates in `filtered.loans`.
