# AM 2017-01 V2 Run Summary

Run date: 2026-06-05

## What V2 changes vs V1

- Replaces moving-average smoothing with X-13ARIMA-SEATS (monthly/quarterly) and STL (bimonthly) seasonal adjustment.
- Calendar-time x-axis (not event-centered) in all plots.
- Accountability frame: single treatment cut at the removal date; cassation-process months are pre-treatment (no crisis window).
- Pre-treatment window: 52 months / 14 bimesters (up to removal). Post-removal: 12 months / 9 bimesters.
- Single estimation spec per family (SA); no raw/MA variants.

## Outputs

- `data/am_2017_01_v2_*_panel.csv`, `data/am_2017_01_v2_covariates.csv`
- `output/am_2017_01_v2_scm_summary.csv`
- `output/placebo_inspace/`, `output/placebo_loo/`
- `am_2017_01_v2_results_report.md`
