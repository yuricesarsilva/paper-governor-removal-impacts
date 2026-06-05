# AM 2017-01 V3 Run Summary

Run date: 2026-06-05

## What V3 changes vs V2

- Monthly outcomes (labor/consumption) use the X-13 TREND-CYCLE component instead of the seasonally-adjusted series, removing the high-frequency irregular noise that kept the SCM gap plots volatile.
- Cut the monthly AM-minus-synthetic gap volatility by ~35-78% (formal hiring -75%, retail -78%, services -36%).
- Quarterly covariates and bimonthly fiscal unchanged from V2 (seasonally adjusted).

## Inherited from V2 (accountability frame)

- X-13 (monthly/quarterly) and STL (bimonthly) for seasonal handling; calendar-time x-axis.
- Accountability frame: single treatment cut at the removal date; cassation-process months are pre-treatment (no crisis window).
- Pre-treatment window: 52 months / 14 bimesters (up to removal). Post-removal: 12 months / 9 bimesters.
- Single estimation spec per family; no raw/MA variants.

## Outputs

- `data/am_2017_01_v3_*_panel.csv`, `data/am_2017_01_v3_covariates.csv`
- `output/am_2017_01_v3_scm_summary.csv`
- `output/placebo_inspace/`, `output/placebo_loo/`
- `am_2017_01_v3_results_report.md`
