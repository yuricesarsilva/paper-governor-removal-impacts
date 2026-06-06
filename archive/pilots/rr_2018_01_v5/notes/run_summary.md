# RR 2018-01 V5 Run Summary

Run date: 2026-06-04

## What V5 changes (original rebuild)

- Rebuilt from scratch instead of copying an earlier pilot folder.
- Uses one explicit smoothing rule: complete pre-treatment windows, event coded as 0, and first post-treatment moving average at +1.
- Starts the quarterly covariate panel at the first quarter with observed formalization data instead of keeping empty leading quarters.
- Repairs isolated gaps in fiscal sector covariates with the average of adjacent bimesters, with explicit audit flags.
- Uses resident annual population from the general project base for fiscal per-capita outcomes.
- Uses the project-wide construction-sector CAGED series for the sectoral labor-market outcome.

## Post-critique additions

- CAGED BUG FIXED: formal hiring source corrected from `old_caged_state_balance_monthly_panel_ready.csv` (deprecated intermediate file) to `caged_state_balance_monthly_panel_ready.csv` (validated final file). This changed the formal hiring MA6 gap from −0.60 to +21.74.
- RS 2018 ICMS B1-B5 imputed with 2017 seasonal shares (API returns 0 rows for those bimesters). RS restored to ICMS donor pool (24 donors).
- Negative ICMS flows (MT 2015B2, RN 2018B3) replaced by adjacent bimester mean and flagged.
- `pre_instability_clean` column added to monthly and bimonthly panels.
- Specification `ma6_v5_instability` added: estimates SCM weights using only periods before instability_start_date.
- Leave-one-out placebo inference added for 6 outcomes. Results in `output/placebo_loo/`.

## Main outputs

- `data/rr_2018_01_v5_monthly_panel.csv`
- `data/rr_2018_01_v5_bimonthly_fiscal_panel.csv`
- `data/rr_2018_01_v5_quarterly_pnadc_panel.csv`
- `data/rr_2018_01_v5_covariates.csv`
- `output/rr_2018_01_v5_scm_summary.csv`
- `output/placebo_loo/` (6 LOO placebo CSVs)
- `rr_2018_01_v5_results_report.md`

## Remaining work for article use

- Decide whether RR_2018_01 stays in `extended` or moves to `borderline` before investing further.
- Investigate total expenditure RMSPE_pre = 98.5: consider alternative covariate sets or confirm it is a genuine Roraima data feature.
- Review writing, narrative emphasis, and effect interpretation after the preferred specification is frozen.
