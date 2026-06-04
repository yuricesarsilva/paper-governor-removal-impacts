# AM 2017-01 Run Summary

Run date: 2026-06-04

## Pipeline

- Built from the V5 template (rr_2018_01_v5). All methodological improvements from V5 are included.
- Uses the validated final CAGED series (`caged_state_balance_monthly_panel_ready.csv`).
- RS 2018 ICMS B1-B5 imputed with 2017 seasonal shares.
- `pre_instability_clean` column marks periods before instability_start_date.
- Specification `ma6_v5_instability` uses pre-instability-only weight estimation.
- Leave-one-out and in-space placebo inference included.
- Covariate balance and pre-treatment outcome fit tables included.

## Main outputs

- `data/am_2017_01_v1_monthly_panel.csv`
- `data/am_2017_01_v1_bimonthly_fiscal_panel.csv`
- `data/am_2017_01_v1_quarterly_pnadc_panel.csv`
- `data/am_2017_01_v1_covariates.csv`
- `output/am_2017_01_v1_scm_summary.csv`
- `output/placebo_inspace/` (in-space placebo outputs)
- `output/placebo_loo/` (6 LOO placebo CSVs)
- `am_2017_01_v1_results_report.md`

## Notes

- Instability window: 465 days (2016-01-25 to 2017-05-04).
- Monthly pre-treatment periods: 35; post-treatment periods (until end of window): 31.
- Bimonthly pre-treatment bimesters: 13; post: 15.
- Excluded donor states: `AM`, `RR`, `TO`.
