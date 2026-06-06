# AM 2017-01 V4 Run Summary

Run date: 2026-06-05

## What V4 changes vs V2

- All eight outcomes are now bimonthly. Monthly labor/consumption series are aggregated to bimonthly: labor balances SUMMED, volume indices AVERAGED.
- Single SA method for everything: STL (freq 6). One estimation family (`bimonthly`), one window.
- Target pre-window = 24 bimesters. Labor/consumption use the full 24 (data from 2007); fiscal uses the max available 14 (Siconfi starts 2015). At 24 bimesters the labor/consumption overfitting (near-zero RMSPE_pre) disappears.

## Inherited from V2 (accountability frame)

- Calendar-time x-axis; single treatment cut at the removal date; cassation-process months are pre-treatment.
- Pre-treatment up to 24 bimesters (labor/consumption); 14 for fiscal. Post-removal 9 bimesters.

## Outputs

- `data/am_2017_01_v4_*_panel.csv`, `data/am_2017_01_v4_covariates.csv`
- `output/am_2017_01_v4_scm_summary.csv`
- `output/placebo_inspace/`, `output/placebo_loo/`
- `am_2017_01_v4_results_report.md`
