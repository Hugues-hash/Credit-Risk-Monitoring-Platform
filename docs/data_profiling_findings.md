# Data Profiling Findings - Lending Club Staging Dataset

## 1. Identifiers (`id`, `member_id`)
* **Total Records Staged**: 2,260,701
* **`id` Integrity**: 100% unique (0 duplicate values). Verified natural key for loan-level grain.
* **`member_id` Integrity**: 100% NULL (0 non-null records). Column removed by data provider for PII privacy; exclude from Dim/Fact schema.

## 2. Loan Status & Performance (`loan_status`, `last_pymnt_d`, `next_pymnt_d`)
* **Terminal Loans**: 47.63% Fully Paid, 11.91% Total Charged Off / Default.
* **Active Portfolio**: 38.85% Current, ~1.51% actively delinquent (Grace Period, Late 16-30, Late 31-120).
* **Target Variable Mapping**:
  * Default (`is_default = 1`): 'Charged Off', 'Default', 'Does not meet the credit policy. Status:Charged Off' (~269,360 total records).
  * Non-Default (`is_default = 0`): 'Fully Paid', 'Does not meet the credit policy. Status:Fully Paid' (~1,078,739 total records).
* **Payment Date Handling**:
  * `next_pymnt_d` missingness (~59.5%) directly correlates to settled/closed loans; populate as NULL in Dim_Date linking.
  * 33 blank `loan_status` records identified for exclusion during Fact table ELT.

## 3. Financial Exposure & Terms (`loan_amnt`, `funded_amnt`, `int_rate`, `installment`, `term`)
* **Loan Amount Range**: $500 – $40,000 (Average: ~$15,047).
* **Interest Rate Range**: 5.31% – 30.99%.
* **Term Distribution**: ~71.2% 36-month terms (1.61M loans), ~28.8% 60-month terms (651K loans). 
* **Data Cleaning Note**: Leading whitespace exists in the `term` string values and requires trimming during the ELT phase. 33 null records correspond to the dataset trailer lines.

## 4. Borrower Risk Profile (`annual_inc`, `dti`, `revol_util`, `delinq_2yrs`)
* **Annual Income (`annual_inc`)**: Ranges from $0 to $110,000,000 (Avg: ~$77,992). Contains 1,667 zero-income rows and 37 nulls.
* **Debt-to-Income (`dti`)**: Ranges from -1 to 999 (Avg: ~18.82). Negative values (-1) and extreme outliers (999) represent data entry anomalies.
* **Revolving Utilization (`revol_util`)**: Max reaches 892.3% (over-limit credit), with 1,744 nulls.
* **Delinquency (`delinq_2yrs`)**: Max past-due incidents in a 2-year window is 58, with 62 nulls.

## 5. Risk Segmentation & Classification (`grade`, `sub_grade`, `emp_length`, `home_ownership`)
* **Grades & Sub-Grades**: 8 grades (A–G, plus 33 nulls) with 5 distinct sub-grades each. Heavily concentrated in Grades B and C (~1.31M loans).
* **Employment Length (`emp_length`)**: Dominated by `10+ years` (748K), followed by 2-year (203K) and `< 1 year` (189K). Contains 146,940 null records.
* **Home Ownership**: Clean categories (`MORTGAGE`, `RENT`, `OWN`, `OTHER`).

## 6. Temporal / Date Fields (`issue_d`, `earliest_cr_line`)
* **Issue Date (`issue_d`)**: Spans April 2008 to September 2018 (`Mon-YYYY` format). Average volume hovers around 43K–62K loans per month.
* **Earliest Credit Line**: 62 null records.

## 7. Geographic Context (`addr_state`, `zip_code`)
* **State Coverage (`addr_state`)**: Covers 51 distinct regions. Dominated by CA (314K), NY (186K), TX (186K), and FL (162K).
* **Zip Code (`zip_code`)**: Masked to 3 digits, containing 956 distinct regional codes.


# Key Findings Informing Phase 2 (Star Schema Design & ETL Transformation)

1. **Natural Key Selection (`Fact_Loan_Performance`)**
   * **Finding**: `id` is 100% unique and safe to use as the primary key for the loan grain. `member_id` is entirely `NULL` and must be dropped.
   * **Star Schema Action**: Exclude `member_id` from all dimension tables. Keep `id` as the natural key `loan_id` in `Fact_Loan_Performance`, with the surrogate `loan_fact_key` as the primary key.

2. **Target Variable Mapping for Credit Risk Modeling (`Fact_Loan_Performance`)**
   * **Finding**: Loan outcomes are split across 10 distinct text categories.
   * **Star Schema Action**: Create a derived boolean column or staging transformation `is_default` where `Charged Off`, `Default`, and policy exceptions map to `1`, while `Fully Paid` maps to `0`. Active loans (`Current`, `Grace Period`, `Late`) will have a `NULL` outcome and should be isolated during model training. The status text itself moves to `Dim_Status`.

3. **Data Cleansing & Normalization Rules (`ETL Pipeline`)**
   * **Finding**: `term` contains leading whitespace (` ' 36 months'`), `dti` contains negative values (`-1`) and extreme ceilings (`999`), and `annual_inc` contains zero-value entries.
   * **Star Schema Action**: Build explicit transformation logic into your SQL/Python views to trim strings (`LTRIM(RTRIM(term))`), sanitize negative financial ratios, and handle null or zero-income edge cases using `COALESCE` or default imputation flags.

4. **Dimension Table Splitting (`Dim_Borrower`, `Dim_Loan`, `Dim_Geography`, `Dim_Date`, `Dim_Status`)**
   * **Finding**: Categorical data is rich across borrower traits (`emp_length`, `home_ownership`, `verification_status`), loan terms (`term`, `grade`, `sub_grade`, `purpose`, `application_type`), geography (`addr_state`, `zip_code`), time (`issue_d`, `earliest_cr_line`, `last_pymnt_d`, `next_pymnt_d`), and loan state (`loan_status`).
   * **Star Schema Action**: Extract these into dedicated dimensions to prevent duplication in the central fact table, ensuring clean joins for Power BI reporting and machine learning feature stores.