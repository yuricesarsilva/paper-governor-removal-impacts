# RR 2018-01 Pilot V2

This folder reruns the Roraima 2018 pilot under the current article specification.

## Case timing

- Event: `RR_2018_01`
- Treated state: `RR`
- Instability start: `2018-11-07`
- Effective removal/intervention: `2018-12-10`

The preferred design treats observations before the instability start as clean pre-treatment, the interval between instability and removal as a crisis window, and observations after the effective removal as post-treatment.

## Main window

- Monthly main window: `2015-11-01` to `2019-12-01`
- Bimonthly fiscal main window: `2015-01-01` to `2019-12-01`
- Quarterly covariate window: `2015-01-01` to `2019-12-31`

The project default remains a two-year post-treatment window whenever feasible. For `RR_2018_01`, the main specification stops in `2019` because extending the post period into `2020` would overlap the pandemic and the CAGED methodological break.

## Current specification

Main estimator:

- Augmented Synthetic Control.

Diagnostic comparison:

- Classic Synthetic Control, plotted and saved alongside augmented SCM.

Main outcomes:

- Formal labor-market block:
  - `formal_hiring_balance_per_100k_wap`
  - `formal_hiring_balance_construction_per_100k_wap`
- Household-consumption block:
  - `retail_volume_index`
  - `services_volume_index`
- State-public-finance block, revenues:
  - `state_tax_revenue_real_pc`
  - `icms_revenue_real_pc`
- State-public-finance block, expenditures:
  - `public_investment_liquidated_real_pc`
  - `liquidated_expenditure_total_real_pc`

Covariates:

- pre-treatment trajectory of the dependent variable;
- unemployment rate;
- formalization rate;
- transfer dependency;
- health expenditure per capita;
- education expenditure per capita;
- public-security expenditure per capita.

## Donor pool rule

Main donor pool rule:

- exclude the treated state; and
- exclude any donor state with a coded rupture in `data/raw/governor_removal_events.csv` whose `removal_date` falls inside the pilot main estimation window.

Applied to `RR_2018_01`, this rule excludes:

- `RR` because it is the treated unit;
- `AM` because `AM_2017_01` falls inside the main estimation window;
- `TO` because `TO_2018_01` falls inside the main estimation window.

Under the current main window, the resulting donor pool has 24 eligible UFs before outcome-specific missingness filters.

## Scripts

1. `code/01_build_rr_2018_01_v2_panels.R`
   - Builds monthly, bimonthly, quarterly, and covariate files for the pilot.
   - Uses the general `data/processed/state_year_panel_template.csv` for annual resident population.
   - Uses the general `data/processed/caged_construction_state_balance_monthly_panel_ready.csv` for the monthly CAGED construction-flow series.
   - Creates clean moving averages separately inside pre/crisis/post segments.

2. `code/02_run_rr_2018_01_v2_scm.R`
   - Runs Classic SCM and Augmented SCM.
   - Saves paths, gaps, weights, RMSPE summaries, and figures.

## Notes

Fiscal per-capita variables are now wired to use the populated `data/processed/state_year_panel_template.csv`, which carries resident population from the consolidated annual SIDRA population panel for the current case universe.

The current fiscal panel isolates ICMS revenue from the raw local Siconfi/RREO Annex 06 files and now keeps `state_tax_revenue_real_pc` as the broader own-revenue margin inside the state-public-finance revenue block.

Public investment and total liquidated expenditure remain theoretically central but must be audited because the Siconfi/RREO series can combine accumulated bimonthly reporting with outright gaps. The current project base now repairs total expenditure with the same rule already adopted for investment: recover bimonthly flow from the cumulative raw line when available, and interpolate only the residual gaps that remain empty in the source response.

The pilot now consumes the general project-wide monthly CAGED construction series in `data/processed/caged_construction_state_balance_monthly_panel_ready.csv`, so the same sectoral input can be reused across future cases.
