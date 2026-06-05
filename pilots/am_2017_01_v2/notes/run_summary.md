# AM 2017-01 V2 Run Summary

Run date: 2026-06-05

## What V2 changes vs V1

- Replaces moving-average smoothing with X-13ARIMA-SEATS seasonal adjustment for all sub-annual series.
- Calendar-time x-axis (not event-centered) in all plots.
- Pre-treatment window: 36 months / 24 bimesters target (bimonthly limited to 6 by Siconfi).
- Post-removal window: crisis interval + 12 months (monthly) or + 9 bimesters (bimonthly).
- Single estimation spec per family (SA); no raw/MA variants.

## Outputs

- `data/am_2017_01_v2_*_panel.csv`, `data/am_2017_01_v2_covariates.csv`
- `output/am_2017_01_v2_scm_summary.csv`
- `output/placebo_inspace/`, `output/placebo_loo/`
- `am_2017_01_v2_results_report.md`
