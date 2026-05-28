# RR 2018 Pilot Data Assembly Validation

This note records the first data assembly for the `RR_2018_01` pilot.

## Scripts

Data assembly script:

- `pilots/rr_2018_01/code/01_build_rr_pilot_panels.R`

## Generated Data

Pilot analytical panels:

- `pilots/rr_2018_01/data/rr_2018_01_monthly_panel.csv`
- `pilots/rr_2018_01/data/rr_2018_01_fiscal_bimonthly_panel.csv`

Validation outputs:

- `pilots/rr_2018_01/output/rr_2018_01_monthly_coverage.csv`
- `pilots/rr_2018_01/output/rr_2018_01_monthly_missing_summary.csv`
- `pilots/rr_2018_01/output/rr_2018_01_monthly_pre_post_summary.csv`
- `pilots/rr_2018_01/output/rr_2018_01_fiscal_coverage.csv`
- `pilots/rr_2018_01/output/rr_2018_01_fiscal_missing_summary.csv`
- `pilots/rr_2018_01/output/rr_2018_01_fiscal_pre_post_summary.csv`

## Monthly Panel Validation

Window:

- Pre-treatment: `2016-01` to `2018-11`.
- Transition excluded: `2018-12`.
- Post-treatment: `2019-01` to `2020-12`.

Coverage:

- 59 monthly periods.
- 35 pre-treatment months.
- 24 post-treatment months.
- 27 UFs in every month.
- 24 main donor-pool UFs in every month after excluding `RR`, `AM`, and `TO`.
- Treated unit `RR` is present in every month.

Missing values in selected monthly outcomes and covariates:

- `formal_hiring_balance`: 0.
- `retail_volume_index`: 0.
- `services_volume_index`: 0.
- `unemployment_rate_pnadc`: 0.
- `formalization_rate_pnadc`: 0.

PNADc timing note:

- The user selected `2018Q4` as a transition quarter.
- Monthly rows for `2018-10` and `2018-11` remain in the monthly pre-treatment window because the monthly treatment timing excludes only `2018-12`.
- PNADc covariates attached to `2018Q4` are flagged with `pnadc_predictor_valid = FALSE` so they can be excluded when constructing predictors.

## Fiscal Panel Validation

Window:

- Pre-treatment: `2015B1` to `2018B5`.
- Transition excluded: `2018B6`.
- Post-treatment: `2019B1` to `2020B6`.

Coverage:

- 35 bimonthly periods.
- 23 pre-treatment bimesters.
- 12 post-treatment bimesters.
- 27 UFs in every bimester.
- 24 main donor-pool UFs in every bimester after excluding `RR`, `AM`, and `TO`.
- Treated unit `RR` is present in every bimester.

Missing values in selected fiscal outcomes and covariates:

- `liquidated_expenditure_total_real`: 5.
- `social_expenditure_share_real`: 5.
- `total_revenue_real`: 0.
- `own_revenue_ratio`: 0.
- `state_tax_revenue_real`: 0.

Fiscal construction note:

- `social_expenditure_share_real` is constructed in the pilot script as:

```text
(liquidated_expenditure_health_real +
 liquidated_expenditure_education_real +
 liquidated_expenditure_public_security_real) /
 liquidated_expenditure_total_real
```

## Current Assessment

The assembled panels are ready for the first SCM implementation.

Important implementation choices for the next script:

- Use `donor_pool_main == TRUE` for the main donor pool.
- Use `treated_unit == TRUE` for RR.
- Use `analysis_period` to define pre and post windows.
- Use `pnadc_predictor_valid == TRUE` when aggregating PNADc predictors.
- For CAGED models extending through `2020-12`, use `caged_break_control` to represent the January 2020 methodological break.
- For the employment robustness window ending in `2019-12`, use `monthly_pre_2020_robustness_window == TRUE`.
