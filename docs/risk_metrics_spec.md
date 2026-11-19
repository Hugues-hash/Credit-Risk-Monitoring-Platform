# Risk Metrics Specification

What we measure about the loan book, why each measure matters, and exactly how it is calculated.

## Why this layer exists

The warehouse holds 2.26 million loans, one row each. A risk manager does not want to read loans one at a time. They want answers to a few questions:

1. **How many loans go bad?** → default rates
2. **Who is falling behind right now?** → delinquency buckets and funnel
3. **Are newer loans better or worse than older ones?** → vintage cohorts and curves
4. **How much money is at risk, and how much have we lost?** → exposure and loss
5. **Are we too dependent on one state, purpose or risk grade?** → concentration risk
6. **Does the economy explain any of this?** → vintages next to macro data

Each answer is a SQL **view** in the `analytics` schema. A view is a saved query that recalculates from the warehouse every time it is read. Keeping the calculations in one place means Power BI, Python and anyone running SQL all get **the same numbers**, and a definition only ever has to be changed once.

```
warehouse (star schema)  ─┐
                          ├─>  analytics views  ─>  Power BI dashboard / Python model
warehouse.Macro_Monthly  ─┘
```

- **Source:** `warehouse.*` (the star schema) and `warehouse.Macro_Monthly` (US economic data from FRED)
- **Output:** `analytics.*` (eight views, plus one settings table for alert thresholds)
- **Before you start:** `sql/07_validate_warehouse.sql` must pass
- **Checks:** `sql/10_validate_analytics.sql`
- **Data date:** the data ends on **2019-03-01** (the latest payment date). "Today" in this document means that date.

---

## Run order

| Step | File | What it does |
|---|---|---|
| 1 | `python/stage_macro_data.py` | Loads `data/macro_fred_combined.csv` into `staging.stg_macro_fred` |
| 2 | `sql/08_load_macro.sql` | Builds `warehouse.Macro_Monthly` (156 months, 2007–2019) |
| 3 | `sql/09_analytics_schema.sql` | Creates the `analytics` schema and `analytics.risk_thresholds` |
| 4 | `sql/09a` to `09h` | Create the eight views (any order) |
| 5 | `sql/10_validate_analytics.sql` | Runs every check. All rows must say PASS |

Re-running the warehouse scripts (`04`–`07`) does not break the views. They pick up the new data on their own.

---

## Two words used everywhere: closed and open loans

| | Meaning | `is_default` | Used for |
|---|---|---|---|
| **Closed loan** | The loan is finished: paid off or defaulted | 0 or 1 | Default rates, because the outcome is known |
| **Open (active) loan** | The borrower is still paying, or is late | empty (NULL) | Money at risk today, delinquency |

Mixing the two is the most common mistake in credit reporting. An open loan has not defaulted *yet*, so counting it as "not defaulted" makes the book look safer than it is.

### A rule for every rate

Every percentage is a **ratio of totals**: add up the top, add up the bottom, then divide. Never take the average of percentages, because small groups would count as much as big ones. In SQL the views write `100e0 * top / bottom`. The `e0` forces decimal maths: without it, SQL Server divides whole numbers as whole numbers, and `SUM(is_default) / COUNT(is_default)` would give 0.

---

## 1. Default rate: `analytics.vw_default_rates`

**Why it matters.** This is the headline credit risk number: of the loans whose story is over, how many ended badly? It shows whether each grade, term or purpose is as risky as its pricing assumes.

**Definition.** Closed loans only. Two versions answer two different questions:

```
default_rate_count_pct  = defaulted loans ÷ closed loans × 100
                          "What share of borrowers failed?"

default_rate_dollar_pct = amount lent on defaulted loans ÷ amount lent on closed loans × 100
                          "What share of the money went to borrowers who failed?"

maturity_rate_pct       = closed loans ÷ all loans × 100
                          "How final is this rate?"
```

If big loans default more often than small ones, the dollar rate is higher than the count rate. The **maturity rate** is a warning label. When few loans in a group have closed, the ones that have are mostly early payoffs, so the default rate is not final yet and usually rises later.

**Grain.** One row per `(dimension, segment)`. The dimensions are `overall`, `grade`, `sub_grade`, `term_months`, `purpose` and `home_ownership`.

**Today:**

| | Count | Dollar | Maturity |
|---|---:|---:|---:|
| All loans | 19.98% | 21.56% | 59.63% |
| 36-month loans | 16.02% | 16.09% | 63.56% |
| 60-month loans | 32.45% | 32.22% | 49.91% |
| Grade A → Grade G | 6.04% → 49.67% | 5.98% → 49.61% | |

Risk rises steadily from grade A to grade G, which is what a working grading system should show.

---

## 2. Delinquency buckets: `analytics.vw_delinquency_buckets`

**Why it matters.** Defaults are *past* losses. Delinquency is the warning *before* the loss: a borrower who is late today is far more likely to default next. This view shows how much of the live book is already slipping.

**Definition.** Open loans only, grouped by how late they are. The balance is `out_prncp`, the principal still owed.

```
share_of_active_balance_pct = bucket balance ÷ total open balance × 100
```

**Grain.** One row per `loan_status`.

**Today:**

| Order | `loan_status` | Risk tier | Loans | Balance | Share of balance |
|---:|---|---|---:|---:|---:|
| 1 | Current | Performing | 878,317 | $9.13B | 95.96% |
| 2 | In Grace Period | Early warning (1–15 days late) | 8,436 | $92.0M | 0.97% |
| 3 | Late (16-30 days) | Moderate delinquency | 4,349 | $47.9M | 0.50% |
| 4 | Late (31-120 days) | Severe delinquency (close to default) | 21,467 | $244.2M | 2.57% |

---

## 3. Delinquency funnel: `analytics.vw_delinquency_funnel`

**Why it matters.** Banks normally track **roll rates**: the share of late loans that get even later the next month. Roll rates show how fast trouble is spreading. They need a monthly history of every loan, and our data has only one row per loan at a single date, so true roll rates are impossible. The funnel is the closest stand-in (a **proxy**): it summarises the whole delinquency picture in one row.

**Definition.** One row for the whole open book:

```
delinquency_rate_pct            = (grace + late 16-30 + late 31-120 balance) ÷ open balance × 100
                                  "How much of the live book is behind at all?"

dpd_31_plus_rate_pct            = late 31-120 balance ÷ open balance × 100
                                  "How much is more than 30 days late?" (the industry's standard stress figure)

severe_to_total_delinquency_pct = late 31-120 balance ÷ all late-and-grace balance × 100
                                  "Of the trouble, how much is serious?"

ratio_16_30_to_grace            = late 16-30 balance ÷ grace balance
ratio_31_120_to_16_30           = late 31-120 balance ÷ late 16-30 balance
```

**Today:** delinquency rate **4.04%**, 31+ DPD rate **2.57%**, severe-to-total **63.57%**.

**Careful:** the two stage ratios are **not** roll rates. The buckets cover different numbers of days (15, 15 and 90), so the 31–120 bucket is bigger partly because it covers six times as many days. Compare these ratios over time, not against each other.

---

## 4. Vintage cohorts: `analytics.vw_vintage_cohorts`

**Why it matters.** A **vintage** (or cohort) is a group of loans issued in the same period. Comparing vintages shows whether the lender's standards loosened or tightened over time. A worse vintage often means risky lending months or years before the losses appear.

**Definition.** Loans grouped by the quarter they were issued, split by grade:

```
originated_loans, funded_exposure  how much was lent
maturity_rate_pct                  closed loans ÷ all loans × 100
default_rate_count_pct             defaulted ÷ closed × 100
default_rate_dollar_pct            amount lent on defaulted ÷ amount lent on closed × 100
avg_fico_score, avg_int_rate       borrower quality and pricing at the time of lending
```

**Grain.** One row per `(issue_year, issue_quarter, grade)`. Counts and amounts can be added across grades. To combine the averages, weight them by `originated_loans`.

**Today:**

| Issue year | Loans | Maturity | Default rate (closed loans) |
|---|---:|---:|---:|
| 2012 | 53,367 | 100.0% | 16.20% |
| 2015 | 421,095 | 89.2% | 20.19% |
| 2017 | 443,579 | 38.2% | 23.13% |
| 2018 | 495,242 | 11.4% | 15.76% |

The 2018 rate looks good only because 89% of those loans are still open. The vintage curves (next) fix this.

---

## 5. Vintage curves: `analytics.vw_vintage_curves`

**Why it matters.** Comparing a 6-year-old cohort with a 1-year-old one is unfair, because the old one has had far more time to default. Vintage curves compare cohorts **at the same age**. This is the standard way to tell whether newer lending is really better or worse.

**Definition.** For each issue-year cohort and each **month on book** (months since issue, 0 to 72):

```
cumulative_default_rate_pct = loans in the cohort that defaulted by month m ÷ all loans in the cohort × 100
```

**Grain.** One row per `(issue_year, months_on_book)`.

**Today:** 24 months after issue, 11.55% of the 2012 loans had defaulted, against 13.65% of the 2016 loans. Later lending was riskier at the same age.

**How it works, and its limits:**
- The data has no default date, so the **last payment date** is used as the month of default (month 0 if the borrower never paid). The real write-off comes a few months later, so the curves are shifted slightly early. Every cohort is shifted the same way, so comparisons still hold.
- A point is shown only when **every** loan in the cohort is at least that old on the data date. This is why 2017 stops at month 15 and 2018 at month 3.
- Near the end of each curve, some loans that will default are still marked Late, so the last few points are slightly low.

---

## 6. Exposure and loss: `analytics.vw_exposure_loss`

**Why it matters.** Rates say *how often* loans fail. Exposure and loss say *how much money* is involved. Banks size their capital and provisions using three ideas: how likely a default is (PD), how much is owed when it happens (**EAD**), and how much of that is lost (**LGD**). This view gives the last two for defaulted loans, and the live money at risk for open loans.

**Definition.** Three kinds of exposure, always kept apart so historical volume is never confused with money at risk:

| Column | Meaning | Today |
|---|---|---:|
| `originated_exposure` | Everything ever lent (`funded_amnt`) | $34.00B |
| `active_exposure` | Still owed on open loans today (`out_prncp`) | $9.51B |
| `exposure_at_default` | Still owed when each defaulted loan defaulted (`funded_amnt − total_rec_prncp`) | $3.00B |

Loss on defaulted loans:

```
net_principal_loss          = exposure_at_default − recoveries
                              "Money actually lost after collections"

lgd_pct                     = net_principal_loss ÷ exposure_at_default × 100
                              "Loss given default: of what was still owed, how much was never recovered?"

loss_rate_on_originated_pct = net_principal_loss ÷ amount lent on defaulted loans × 100
                              "Loss as a share of the original loan amount"
```

LGD divides by what was **still owed**, not by the original loan, because borrowers repay part of the loan before they default. Dividing by the original amount would understate LGD (64% instead of 89%).

**Grain.** One row per `(issue_year, grade)`. Add rows up for any total.

**Today:** recoveries $325M, net principal loss **$2.68B**, LGD **89.18%**. Once a borrower defaults, the lender gets back only about 11 cents of each dollar still owed, which is typical for unsecured loans (there is no house or car to sell).

**Notes:**
- Recoveries in the data are **gross**: collection fees are not deducted, so the real LGD is slightly higher.
- On 996 defaulted loans, recoveries are larger than the exposure at default (recoveries can include interest and fees), so those loans show a small negative loss. This is left as it is in the source.
- The 40 loans with status `Default` are not written off yet. Their remaining balance ($383K) is counted as loss.

---

## 7. Concentration risk: `analytics.vw_concentration_risk`

**Why it matters.** Even good loans become dangerous if too many sit in one place. If a large share of the book is in California, a California recession hits the whole portfolio at once. Concentration limits keep the book spread out, and breaching one is a classic **early warning**.

**Definition.** The share of the book in each segment, for two exposure bases:

```
funded_share_pct = segment amount lent ÷ total amount lent × 100     (history)
active_share_pct = segment open balance ÷ total open balance × 100   (today's risk, used for flags)
is_breach        = 1 when active_share_pct > threshold_pct
```

**Grain.** One row per `(dimension, segment)`. The dimensions are `addr_state`, `grade`, `grade_group` (A-D or E-G), `purpose` and `home_ownership`. Shares add up to 100% within each dimension.

**Thresholds.** They live in the table `analytics.risk_thresholds`, so they can be changed without editing the view. The starting values sit about 1.5–2 points above today's level. A flag therefore means "concentration is growing", not "this is how the book always looks". A limit that is always breached is just noise.

| Rule | Flag when | Today | Breach |
|---|---|---:|---|
| `STATE_SINGLE` | Any one state is above 15% of the open balance | CA 13.28% | No |
| `PURPOSE_SINGLE` | Any one purpose is above 60% | debt_consolidation 58.42% | No |
| `GRADE_EFG` | Grades E + F + G together are above 8% | 6.47% | No |

The final levels are a risk decision for Phase 5 (early warnings).

---

## 8. Vintages and the economy: `analytics.vw_vintage_macro`

**Why it matters.** Borrowers default more when the economy is weak: jobs are lost, or rates and prices rise. Putting each cohort next to the economic conditions of its time shows how much of the risk comes from the borrowers and how much from the times they borrowed in. It also links the loan data to the macro data, as the project plan requires.

**Definition.** For each issue quarter (all grades together):

```
default_rate_count_pct, default_rate_dollar_pct, maturity_rate_pct   as in the vintage cohorts
unemployment_rate   average % unemployed in the issue quarter
fed_funds_rate      average US central bank rate in the issue quarter
inflation_rate      average yearly price growth (CPI) in the issue quarter
```

**Grain.** One row per issue quarter.

The maturity warning applies here too: the 2017–2018 default rates are not final.

---

## How we check the views

`sql/10_validate_analytics.sql` recalculates everything from `filtered.loans`, the cleaned table, which the views never read. Two separate routes giving the same answer is strong evidence that the logic is right. It prints PASS or FAIL for each check.

### A. Totals add up (conservation checks)

- The bucket balances add up to all open-loan `out_prncp`, and the bucket counts add up to all open loans.
- The concentration shares add up to 100% within each dimension, for both bases.
- The cohort loans add up to 2,260,668, and the amounts lent to $34,004,208,600.
- The exposure view's totals match the amount lent and the bucket balances.
- The overall closed loans equal the loans with an outcome (1,348,099), so no open loans leak into default rates.
- For the fully closed cohorts (2007–2012), the end of each vintage curve equals the cohort's total defaults.

### B. Hand check on one small slice: Grade G loans issued in 2015

| Item | Value |
|---|---:|
| Loans | 2,167 |
| Defaulted / paid off / still open | 1,027 / 869 / 271 |
| Default rate, count | 54.1667% |
| Default rate, dollar | 54.0137% |
| Amount lent | $44,267,125.00 |
| Recoveries on defaulted loans | $2,127,014.44 |
| Net principal loss | $15,521,707.87 |
| LGD | 87.9481% |
| Loss rate on originated | 74.6101% |

### Results (2026-11-19)

- `10_validate_analytics.sql`: **36 of 36 checks pass**. Amounts and counts match exactly, and percentages differ by at most 0.0002 points from rounding.
- The 2,167 slice rows were also exported to CSV and recalculated outside SQL, in pandas. Every figure in the table above matched exactly.
- Sabiha re-runs the slice check her own way (Excel or her own query) before Power BI is connected.

### Pass conditions

| Check | Pass condition |
|---|---|
| Dollar totals | Exact match ($0.00 difference) |
| Loan counts | Exact match (0 difference) |
| Percentages and rates | Within ±0.01 points (rounding only) |
| Open vs closed loans | No open loan in any default-rate calculation |

---

## Known limits

| Limit | Effect | How we handle it |
|---|---|---|
| One row per loan at a single date | No true roll rates, no exact default dates | Delinquency funnel instead of roll rates; last payment date stands in for the default date |
| 40% of loans still open | Default rates are not final for recent and 60-month loans | `maturity_rate_pct` shown next to every rate; vintage curves compare cohorts at the same age |
| Gross recoveries | LGD slightly understated | Noted; no collection-fee column is kept |
| Thresholds are a first guess | Flags may need tuning | Kept in `analytics.risk_thresholds`; to be agreed in Phase 5 |

See `docs/project_glossary.md` for every term used here.
