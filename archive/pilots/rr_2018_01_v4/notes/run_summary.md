# RR 2018-01 V4 Run Summary

Run date: 2026-06-04

## What V4 changes

- Rebuilt from scratch instead of copying an earlier pilot folder.
- Uses one explicit smoothing rule: complete pre-treatment windows and expanding post-break windows.
- Uses resident annual population from the general project base for fiscal per-capita outcomes.
- Uses the project-wide construction-sector CAGED series for the sectoral labor-market outcome.

## Main outputs

- `data/rr_2018_01_v4_monthly_panel.csv`
- `data/rr_2018_01_v4_bimonthly_fiscal_panel.csv`
- `data/rr_2018_01_v4_quarterly_pnadc_panel.csv`
- `data/rr_2018_01_v4_covariates.csv`
- `output/rr_2018_01_v4_scm_summary.csv`
- `rr_2018_01_v4_results_report.md`

## Remaining work for article use

- Add placebo inference and leave-one-out diagnostics to the clean V4 pipeline.
- Decide whether the crisis block should be retained in the headline tables or treated as descriptive only.
- Review writing, narrative emphasis, and effect interpretation after the preferred specification is frozen.
