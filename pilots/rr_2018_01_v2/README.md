# RR 2018-01 Pilot V2

This folder reruns the Roraima 2018 pilot under the current article specification.

## Case timing

- Event: `RR_2018_01`
- Treated state: `RR`
- Instability start: `2018-11-07`
- Effective removal/intervention: `2018-12-10`

The preferred design treats observations before the instability start as clean pre-treatment, the interval between instability and removal as a crisis window, and observations after the effective removal as post-treatment.

## Current specification

Main estimator:

- Augmented Synthetic Control.

Diagnostic comparison:

- Classic Synthetic Control, plotted and saved alongside augmented SCM.

Main outcomes:

- Labor/investment channel: `formal_hiring_balance_per_100k_wap`, `state_tax_revenue_real_pc`.
- Consumption channel: `retail_volume_index`, `services_volume_index`.
- Public-sector channel: `public_investment_liquidated_real_pc`, `liquidated_expenditure_total_real_pc`.

Covariates:

- pre-treatment trajectory of the dependent variable;
- unemployment rate;
- formalization rate;
- transfer dependency;
- health expenditure per capita;
- education expenditure per capita;
- public-security expenditure per capita.

## Scripts

1. `code/01_build_rr_2018_01_v2_panels.R`
   - Builds monthly, bimonthly, quarterly, and covariate files for the pilot.
   - Creates clean moving averages separately inside pre/crisis/post segments.

2. `code/02_run_rr_2018_01_v2_scm.R`
   - Runs Classic SCM and Augmented SCM.
   - Saves paths, gaps, weights, RMSPE summaries, and figures.

## Notes

Fiscal per-capita variables currently use PNADc population as the denominator available in the processed quarterly panel. This should be replaced by resident population if the project later materializes a better state-time population denominator.

The current fiscal panel does not isolate ICMS revenue. `state_tax_revenue_real_pc` is used as the operational proxy for ICMS-linked taxable activity until an ICMS-specific series is built.

Public investment remains theoretically central but must be audited because the Siconfi/RREO investment series has known missingness and derived-flow issues.
