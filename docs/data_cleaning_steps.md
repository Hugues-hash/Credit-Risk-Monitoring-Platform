# Data Cleaning Steps

How the raw loan data is cleaned before the star schema is built.

- **Script:** `sql/02_clean_staging.sql`
- **Checks:** `sql/03_validate_clean.sql`
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

`annual_inc_joint`, `dti_joint` and `verification_status_joint` are not kept as separate columns. They are used inside `annual_inc`, `dti` and `verification_status` for joint applications (see Step 6).

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

## Step 6: Use joint income, DTI and verification for joint applications

A **joint application** is when two people (usually spouses or partners) apply for one loan together. Both are responsible for paying it back. 120,710 loans (about 5%) are joint.

For these loans, `annual_inc` and `dti` describe **only the first applicant**. The real household numbers, which LendingClub used to approve the loan, are in `annual_inc_joint` and `dti_joint`.

Example from the data:

| | First applicant only | Both applicants (joint) |
|---|---:|---:|
| Annual income | $10,000 | $135,000 |
| DTI | 221% | 18.3% |

Using only the first applicant made these loans look broken. They caused **all** 1,667 zero incomes and **all** DTI values above 100 (including every `999`). So:

- **Joint App** → `annual_inc` comes from `annual_inc_joint`, and `dti` comes from `dti_joint`
- **Individual** → the normal `annual_inc` and `dti` are used

After this, the highest DTI in the data is 69.49 and there are no zero incomes.

**Verification status.** `verification_status` says whether LendingClub checked the **first applicant's** income. For joint loans we now use the combined income, so we also use `verification_status_joint`, which says whether the **combined** income was checked. The two often differ:

| Joint loans | Count |
|---|---:|
| Same status for first applicant and household | 93,814 |
| Household status is lower (e.g. first applicant `Verified`, household `Not Verified`) | 21,916 |
| No `verification_status_joint` in the source | 4,980 |

- **Joint App** → `verification_status` comes from `verification_status_joint`. If that is empty, the first applicant's status is kept, so no new empty values are created
- **Individual** → the normal `verification_status` is used

## Step 7: Fix impossible values

These rules run after Step 6, so they only catch values that are still wrong.

| Column | Problem | Fix | Rows affected |
|---|---|---|---:|
| `annual_inc` | A few individual incomes too small to be real (as low as $1,896 a year) | Set anything `< 5000` to empty (NULL) | 53 |
| `dti` | Placeholder values `-1` and `999` | Set to empty (NULL) | 1 |
| `revol_util` | Extreme values above 150%, up to 892% | Set anything `> 150` to empty (NULL) | 28 |

`revol_util` values between 100% and 150% (7,315 loans) are kept. They are real: the borrower is over their credit card limit.

## Step 8: Add new columns

| New column | How it is made | Why |
|---|---|---|
| `fico_score` | Average of `fico_range_low` and `fico_range_high` | The credit score at application. The strongest single sign of risk |
| `is_default` | From `loan_status` (see below) | The outcome we want to predict |

**How `is_default` is set:**

Late loans stay `NULL` because they have not been written off yet. Some of them still get paid back, so counting them as defaults would give the model wrong labels.

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
| `annual_inc` | 57 | 4 blank in the source + 53 under $5,000 | Keep empty in SQL |
| `dti` | 5 | 4 joint loans with no `dti_joint` + 1 value of `-1` | Keep empty in SQL |
| `revol_util` | 1,830 | 1,802 blank in the source + 28 above 150% | Keep empty in SQL |
| `earliest_cr_date` | 29 | Blank in the source | Keep empty in SQL |

**Why we don't fill in guesses here:**

- Dashboards should show real data. Power BI averages skip empty values on their own.
- Guesses for the machine learning model are made later in Python, using only the training data. If we filled them in here, we would use information from the test data, and the model would look better than it really is.

---

## Results of the checks

Run `sql/03_validate_clean.sql` after cleaning. Expected results:

| Check | Expected |
|---|---|
| Number of rows | 2,260,668 |
| `is_default` | 1 = 269,360 · 0 = 1,078,739 · empty = 912,569 |
| `term_months` | 36 = 1,609,754 · 60 = 650,914 |
| `issue_date` range | 2007-06-01 to 2018-12-01 |
| `fico_score` range | 612 to 847.5 |
| `dti` range | 0 to 69.49 |
| `annual_inc` range | $5,000 to $110,000,000 |
| `revol_util` maximum | 148 |

## Things to look at later

- `annual_inc` goes up to $110M. These very high incomes are kept in SQL, and will be capped or log-transformed in Python before modelling.