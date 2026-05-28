# RR Pilot Decision Checklist

Use this checklist to define the first pilot specification for Roraima.

## 1. Event Choice

- [X] Use `RR_2018_01`: Suely Campos, federal intervention, treatment date `2018-12-10`.
- [ ] Use `RR_2026_01`: Edilson Damiao, electoral cassation, treatment date `2026-04-30`.
- [ ] Estimate both RR cases separately.

Preferred starting point:

- [X] Start with `RR_2018_01`, because it has enough post-treatment data.

## 2. Treatment Timing

### Monthly Series

- [ ] First treated month is `2018-12`.
- [X] First treated month is `2019-01`.
- [X] Exclude `2018-12` as a transition month.
- [ ] Keep `2018-12` in the post-treatment period but flag it as transition.

Recommended pilot option:

- [X] Use `2019-01` as the first treated month and exclude `2018-12` in the main specification.

### Bimonthly Siconfi/RREO Series

- [ ] First treated bimester is `2018B6`.
- [X] First treated bimester is `2019B1`.
- [ ] Exclude `2018B6` as a transition bimester.

### Quarterly PNADc Series

- [ ] First treated quarter is `2018Q4`.
- [X] First treated quarter is `2019Q1`.
- [X] Exclude `2018Q4` as a transition quarter.

## 3. Main Outcome Family

- [X] Employment: `formal_hiring_balance` from CAGED.
- [X] Retail activity: `retail_volume_index` from PMC.
- [X] Services activity: `services_volume_index` from PMS.
- [ ] Fiscal expenditure: Siconfi/RREO expenditure variables.
- [ ] Fiscal revenue: Siconfi/RREO revenue variables.
- [X] Estimate several outcome families in parallel.

Recommended first pilot:

- [ ] Main outcome: `formal_hiring_balance`.
- [ ] Secondary outcomes: `retail_volume_index` and `services_volume_index`.

## 4. Fiscal Outcomes To Include

- [ ] Do not include fiscal outcomes in the first pilot.
- [X] Include `liquidated_expenditure_total_real`.
- [ ] Include `liquidated_expenditure_health_real`.
- [ ] Include `liquidated_expenditure_education_real`.
- [ ] Include `liquidated_expenditure_public_security_real`.
- [X] Include (`liquidated_expenditure_health_real`+`liquidated_expenditure_education_real`+`liquidated_expenditure_public_security_real`)/`liquidated_expenditure_total_real`.
- [ ] Include `public_investment_liquidated_real`.
- [X] Include `total_revenue_real`.
- [ ] Include `state_tax_revenue_real`.
- [ ] Include `federal_transfers_real`.
- [ ] Include `transfer_dependency_ratio`.
- [X] Include `own_revenue_ratio`.

Fiscal caveats for RR:

- [ ] Account for missing Siconfi investment before 2018.
- [X] Treat `2018B6` as transition if using bimonthly fiscal data.
- [ ] Prefer fiscal variables with complete pre-treatment coverage.

## 5. Monthly Window

### Pre-Treatment Window

- [ ] 24 months before treatment.
- [ ] 36 months before treatment.
- [ ] 48 months before treatment.
- [ ] Use the longest balanced pre-treatment period available.

Recommended pilot option:

- [X] Use `2016-01` to `2018-11` as the main pre-treatment window.

### Post-Treatment Window

- [ ] 12 months after treatment.
- [ ] 24 months after treatment.
- [ ] End in `2019-12` to avoid the CAGED 2020 methodological break.
- [ ] Extend through `2020-12` and include CAGED break controls.
- [ ] Extend as far as data availability allows.

Recommended pilot options:

- [X] Main post-treatment window: `2019-01` to `2020-12`.
- [X] Robustness post-treatment window: `2019-01` to `2019-12`.

## 6. Bimonthly Fiscal Window

- [X] Main pre-treatment window: `2015B1` to `2018B5`.
- [X] Main post-treatment window: `2019B1` to `2020B6`.
- [X] Exclude `2018B6` as transition.
- [ ] Include `2018B6` as treated.
- [ ] Do not run fiscal outcomes in the pilot.

## 7. Donor Pool

Baseline exclusions:

- [X] Exclude `RR`.
- [ ] Exclude all UFs with treatment events before or during the RR window.
- [ ] Exclude only UFs with treatment events during the pre-treatment window.
- [ ] Exclude only UFs with treatment events during the post-treatment window.
- [ ] Keep all non-RR UFs and handle treated donor contamination in robustness checks.

Specific possible exclusions:

- [ ] Exclude `PB` because of `PB_2009_01`.
- [ ] Exclude `MA` because of `MA_2009_01`.
- [ ] Exclude `TO` because of `TO_2009_01`, `TO_2018_01`, and later events.
- [ ] Exclude `DF` because of `DF_2010_01`.
- [ ] Exclude `AM` because of `AM_2017_01`.
- [ ] Exclude `RJ` because of `RJ_2020_01`.
- [ ] Exclude `SC` because of `SC_2020_01` and `SC_2021_01`.

Recommended pilot option:

- [X] Exclude `RR`, `AM`, and `TO` in the main donor pool.
- [ ] Test a stricter donor pool excluding all event UFs.

## 8. Covariates

### Outcome Lags

- [ ] Use all monthly pre-treatment outcome lags.
- [ ] Use selected pre-treatment outcome lags.
- [ ] Use pre-treatment averages by year.
- [ ] Use pre-treatment averages by semester.

### Economic Covariates

- [X] `retail_volume_index`.
- [X] `services_volume_index`.
- [X] `formal_hiring_balance`.

### PNADc Covariates

- [ ] `pnadc_population`.
- [X] `unemployment_rate_pnadc`.
- [ ] `labor_income_real_pnadc`.
- [ ] `informality_rate_pnadc`.
- [X] `formalization_rate_pnadc`.

### Fiscal Covariates

- [X] `total_revenue_real`.
- [X] `state_tax_revenue_real`.
- [ ] `federal_transfers_real`.
- [ ] `transfer_dependency_ratio`.
- [X] `own_revenue_ratio`.
- [ ] `liquidated_expenditure_total_real`.
- [ ] `public_investment_liquidated_real`.

Recommended pilot option:

- [ ] Start with outcome lags plus `retail_volume_index`, `services_volume_index`, `unemployment_rate_pnadc`, `formalization_rate_pnadc`, `labor_income_real_pnadc`, and `pnadc_population`.

## 9. Method

- [X] Synthetic Control Method, classic SCM.
- [ ] Augmented Synthetic Control.
- [ ] Difference-in-differences/event-study as descriptive benchmark.
- [X] Placebo tests by donor UF.
- [X] Leave-one-out donor sensitivity.
- [X] Robustness by alternative treatment timing.
- [X] Robustness by alternative post-treatment window.

Recommended pilot option:

- [ ] Classic SCM with placebo tests by donor UF.
- [ ] Add robustness with post-treatment window ending in `2019-12`.

## 10. CAGED 2020 Break Handling

- [ ] Avoid the CAGED break by ending the post-treatment window in `2019-12`.
- [X] Include `post_2020_caged_dummy`.
- [ ] Include `caged_method_break_dummy`.
- [ ] Estimate a robustness specification using only pre-2020 post-treatment months.

Recommended pilot option:

- [ ] Main employment result ends in `2019-12`.
- [ ] Secondary employment result extends through `2020-12` with CAGED break controls.

## 11. Output To Produce

- [X] Event-specific analytical panel for `RR_2018_01`.
- [X] Pre/post summary table for RR and donor pool.
- [X] Outcome time-series plot.
- [X] Treated versus synthetic plot.
- [X] Gap plot.
- [X] Placebo plot.
- [X] Donor weights table.
- [X] Predictor balance table.
- [X] Short pilot memo documenting decisions and results.

## 12. Final Pilot Decision

Fill this after reviewing the checklist.

- [ ] Event:
- [ ] Main outcome:
- [ ] Treatment period:
- [ ] Pre-treatment window:
- [ ] Post-treatment window:
- [ ] Donor pool rule:
- [ ] Covariate set:
- [ ] Method:
- [ ] Main robustness checks:
