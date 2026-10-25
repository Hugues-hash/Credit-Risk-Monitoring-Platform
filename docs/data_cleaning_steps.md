# Data Cleaning Steps

This page explains how the raw loan data is cleaned before we build the star schema.

- **Script:** `sql/01_clean_staging.sql`
- **Checks:** `sql/01b_validate_clean.sql`
- **Input:** `staging.stg_accepted_loans` (raw copy of the CSV, every column stored as text)
- **Output:** `filtered.loans` (one row per loan, correct data types, problems fixed)

```
CSV file  →  staging.stg_accepted_loans  →  filtered.loans  →  dimension tables + fact table
             (raw, untouched)               (cleaned)
```

The staging table is never changed. If a cleaning rule changes, we just run the script again and it rebuilds `filtered.loans` from scratch.

---

## Step 0: Make a place for the clean table

We create a schema called `filtered`. A schema is like a folder inside the database. It keeps raw tables (`staging`) and cleaned tables (`filtered`) apart, so it is always clear which is which.

The script also deletes the old `filtered.loans` table before building a new one, so every run starts fresh.

## Step 1: Keep only the columns we need

The CSV has 151 columns. We keep about 45 of them. Any column not listed in the script is left out, including:

| Left out | Why |
|---|---|
| `member_id` | 100% empty (removed by LendingClub for privacy) |
| `url`, `desc`, `title`, `emp_title` | Free text, not useful for analysis |
| `hardship_*`, `settlement_*`, `sec_app_*` | Mostly empty, not needed for now |
| `*_inv` columns | Investor copies of columns we already keep |

## Step 2: Remove the 33 summary rows

The last 33 rows of the CSV are not loans. They are summary lines such as `Total amount funded in policy code 1: 6417608175`. These rows have no `loan_status`, so we remove every row where `loan_status` is empty.

**Result:** 2,260,701 rows → 2,260,668 rows.

## Step 3: Turn text dates into real dates

Dates arrive as text like `Jun-2013`. We add `01-` in front and convert, so `Jun-2013` becomes `2013-06-01`. Real dates can be sorted, compared and linked to the date dimension.

Columns: `issue_d`, `earliest_cr_line`, `last_pymnt_d`, `next_pymnt_d`.

## Step 4: Fix text columns

| Column | Problem | Fix |
|---|---|---|
| `term` | Has a leading space and the word "months" (`' 36 months'`) | Keep only the number: `36` or `60` (new column `term_months`) |
| `emp_length` | 146,907 empty values | Label them `Unknown` |
| `home_ownership` | Rare values `ANY` (996) and `NONE` (54) | Merge them into `OTHER` |

## Step 5: Turn text numbers into real numbers

All money amounts, rates and counts are converted from text to numbers so we can add, average and compare them. For example, the text `'35000.0'` becomes the number `35000.00`.

## Step 6: Fix impossible values

| Column | Problem | Fix |
|---|---|---|
| `annual_inc` | 1,667 loans show an income of `0` | Set to empty (NULL). A real borrower can't have zero income |
| `dti` | Some values are `-1` | Set to empty (NULL). A debt-to-income ratio can't be negative |

## Step 7: Add new columns

| New column | How it is made | Why |
|---|---|---|
| `fico_score` | Average of `fico_range_low` and `fico_range_high` | The credit score at application. The strongest single sign of risk |
| `is_default` | From `loan_status` (see below) | The outcome we want to predict |

**How `is_default` is set:**

| `loan_status` | `is_default` |
|---|---|
| Charged Off, Default, Does not meet the credit policy. Status:Charged Off | 1 (bad loan) |
| Fully Paid, Does not meet the credit policy. Status:Fully Paid | 0 (good loan) |
| Current, In Grace Period, Late (16-30 days), Late (31-120 days) | Empty (loan still open, outcome not known yet) |

---

## How missing values are handled

Not every empty value means the same thing, so they are treated differently.

| Column | Empty rows | Why it is empty | What we do |
|---|---:|---|---|
| `next_pymnt_date` | 1,345,310 | The loan is closed, so there is no next payment | Keep empty. This is the correct answer, not missing data |
| `emp_length` | 146,907 | Borrower did not give it | Label as `Unknown`. Being unknown may itself be a sign of risk |
| `annual_inc` | 1,671 | Blank or zero in the source | Keep empty in SQL |
| `dti` | 1,713 | Blank or `-1` in the source | Keep empty in SQL |
| `revol_util` | 1,802 | Blank in the source | Keep empty in SQL |
| `earliest_cr_date` | 29 | Blank in the source | Keep empty in SQL |

**Why we don't fill in guesses here:**

- Dashboards should show real data. Power BI averages skip empty values on their own, and fewer than 0.1% of rows are affected.
- Guesses for the machine learning model are made later in Python, using only the training data. If we filled them in here, we would use information from the test data, and the model would look better than it really is.

---

## Results of the checks

Run `sql/01b_validate_clean.sql` after cleaning. Expected results:

| Check | Expected |
|---|---|
| Number of rows | 2,260,668 |
| `is_default` | 1 = 269,360 · 0 = 1,078,739 · empty = 912,569 |
| `term_months` | 36 = 1,609,754 · 60 = 650,914 |
| `issue_date` range | 2007-06-01 to 2018-12-01 |
| `fico_score` range | 612 to 847.5 |

## Things to look at later

- `dti` has 2,561 values above 100, up to 999. These look like data errors but are kept for now.
- The smallest non-zero `annual_inc` is $0.36, which is not a real income. A few more junk incomes may need fixing.
