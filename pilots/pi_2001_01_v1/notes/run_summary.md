# PI 2001-01 V1 Run Summary

Run date: 2026-06-05

## What V1 (PI 2001) does

- First pilot on CONFAZ ICMS value-added + Tesouro Transparente transfers (1990s coverage), enabling a pre-2007 accountability event.
- Monthly frequency throughout with X-13ARIMA-SEATS seasonal adjustment (freq 12).
- Pre-treatment target 36 months, floor 20; post 24 months. Single accountability cut at the removal date.
- Outcomes (real pc, SA): ICMS total VA, tax-revenue VA, ICMS retail VA, PMC retail volume. Covariates (real pc, SA): own lags + ICMS secondary/tertiary/energy/fuels VA, FPE, IOF-state.
- Donor pool excludes any state treated anywhere in the SCM window (pre or post).

## Outputs

- `data/pi_2001_01_v1_monthly_panel.csv`, `data/pi_2001_01_v1_covariates.csv`, `data/pi_2001_01_v1_event_metadata.csv`
- `output/pi_2001_01_v1_scm_summary.csv`
- `output/placebo_inspace/`, `output/placebo_loo/`
- `pi_2001_01_v1_results_report.md`
