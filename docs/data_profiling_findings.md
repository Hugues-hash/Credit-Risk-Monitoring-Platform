# Data Profiling Findings

Results of profiling the raw data in `staging.stg_accepted_loans`, using `sql/01_data_profiling.sql`.

## 1. Identifiers (`id`, `member_id`)
- **Rows loaded:** 2,260,701
- **`id`:** 100% unique, so it can identify each loan.
- **`member_id`:** 100% NULL (removed by LendingClub for privacy), so it is not used.

## 2. Loan Status (`loan_status`, `last_pymnt_d`, `next_pymnt_d`)
- **Finished loans:** 47.63% Fully Paid, 11.91% Charged Off or Default.
- **Open loans:** 38.85% Current, about 1.51% late (In Grace Period, Late 16-30, Late 31-120).
- **Default mapping:**
  - `is_default = 1`: 'Charged Off', 'Default', 'Does not meet the credit policy. Status:Charged Off' (269,360 loans)
  - `is_default = 0`: 'Fully Paid', 'Does not meet the credit policy. Status:Fully Paid' (1,078,739 loans)
- **`next_pymnt_d`:** empty for about 59.5% of loans, because closed loans have no next payment.
- **33 rows have no `loan_status`.** These are summary lines at the end of the CSV, not loans.

## 3. Loan Amounts and Terms (`loan_amnt`, `funded_amnt`, `int_rate`, `installment`, `term`)
- **Loan amount:** $500 to $40,000 (average about $15,047).
- **Interest rate:** 5.31% to 30.99%.
- **Term:** about 71.2% 36 months (1.61M loans), 28.8% 60 months (651K loans).
- **`term` has a leading space** (`' 36 months'`).

## 4. Borrower Risk (`annual_inc`, `dti`, `revol_util`, `delinq_2yrs`)
- **Annual income:** $0 to $110,000,000 (average about $77,992). 1,667 rows are $0 and 37 are empty.
- **DTI:** -1 to 999 (average about 18.82). The -1 and 999 values are not real.
- **Revolving utilization:** up to 892.3%, with 1,744 empty values.
- **Delinquencies in the last 2 years:** up to 58, with 62 empty values.

## 5. Grades and Borrower Categories (`grade`, `sub_grade`, `emp_length`, `home_ownership`)
- **Grades:** A to G, with 5 sub-grades each. Most loans are grade B or C (about 1.31M).
- **Employment length:** most common are `10+ years` (748K), `2 years` (203K) and `< 1 year` (189K). 146,940 are empty.
- **Home ownership:** `MORTGAGE`, `RENT`, `OWN`, plus a few rare values: `ANY` (996), `OTHER` (182) and `NONE` (54).

## 6. Dates (`issue_d`, `earliest_cr_line`)
- **Issue date:** June 2007 to December 2018, stored as text in `Mon-YYYY` format.
- **Earliest credit line:** 62 empty values.

## 7. Location (`addr_state`, `zip_code`)
- **States:** 51 distinct codes. The largest are CA (314K), NY (186K), TX (186K) and FL (162K).
- **Zip code:** only the first 3 digits are given, with 956 distinct values.

---

## What this means for cleaning and the star schema

1. **Loan id:** `id` is unique, so it becomes `loan_id` in the fact table. `member_id` is dropped.
2. **Target variable:** the 9 status values are mapped to `is_default` (1, 0, or NULL for open loans). The status text goes into `Dim_Status`.
3. **Cleaning needed:** trim `term`, convert text dates and numbers, and fix the bad values in `annual_inc`, `dti` and `revol_util`. See `data_cleaning_steps.md`.
4. **Dimensions:** borrower details, loan terms, location, dates and loan status each go into their own dimension table. See `star_schema_design.md`.
