# RR 2018 Pilot Specification

This document consolidates the current choices for the Roraima pilot.

## Event

- Event ID: `RR_2018_01`
- State: `RR`
- Governor: Suely Campos
- Event type: federal intervention
- Treatment date: `2018-12-10`
- Analytical class: `extended`

## Treatment Timing

Monthly series:

- First treated month: `2019-01`
- Transition month excluded from the main specification: `2018-12`

Bimonthly Siconfi/RREO series:

- First treated bimester: `2019B1`
- Transition bimester excluded from the main specification: `2018B6`

Quarterly PNADc series:

- First treated quarter: `2019Q1`
- Transition quarter excluded from the main specification: `2018Q4`
- Monthly rows from `2018-10` and `2018-11` remain in the monthly pre-treatment window, but PNADc covariates from `2018Q4` are flagged with `pnadc_predictor_valid = FALSE` so they can be excluded from predictor construction.

## Current Outcome Hierarchy

The pilot will focus on formal employment as the main economic outcome.

Main monthly economic outcome:

- `formal_hiring_balance` from CAGED

Main specification:

- Augmented SCM in levels.

Main smoothing robustness:

- Augmented SCM with the post-treatment-clean 6-month moving average.

Baseline diagnostic:

- Classic SCM, kept as a transparent benchmark for the preferred Augmented SCM results.

Secondary outcomes not kept as active main economic outcomes:

- `retail_volume_index` from PMC
- `services_volume_index` from PMS

These activity outcomes may remain as appendix material or exploratory diagnostics, but they are no longer part of the main pilot hierarchy.

Quarterly labor outcomes to test next:

- PNADc real labor income from all jobs.
- Possibly PNADc unemployment rate.
- Possibly PNADc formalization rate.

These PNADc outcomes have not yet been tested under the preferred hierarchy and should be treated as pending extensions.

Bimonthly fiscal outcomes:

- `liquidated_expenditure_total_real`
- `(liquidated_expenditure_health_real + liquidated_expenditure_education_real + liquidated_expenditure_public_security_real) / liquidated_expenditure_total_real`
- `total_revenue_real`
- `own_revenue_ratio`

The social-expenditure share is not currently stored in the Siconfi panel and must be constructed in the pilot script.

## Windows

Monthly main window:

- Pre-treatment: `2016-01` to `2018-11`
- Transition excluded: `2018-12`
- Post-treatment: `2019-01` to `2020-12`

Monthly robustness window:

- Pre-treatment: `2016-01` to `2018-11`
- Transition excluded: `2018-12`
- Post-treatment: `2019-01` to `2019-12`

Bimonthly fiscal window:

- Pre-treatment: `2015B1` to `2018B5`
- Transition excluded: `2018B6`
- Post-treatment: `2019B1` to `2020B6`

## Donor Pool

Main donor-pool rule:

- Exclude `RR`, `AM`, and `TO`.

Rationale:

- `RR` is the treated unit.
- `AM` has `AM_2017_01`, close to the RR pre-treatment window.
- `TO` has multiple rupture events, including `TO_2018_01`, close to the RR event.

All other UFs are initially admissible in the main donor pool.

Possible later robustness:

- stricter donor pool excluding all UFs with rupture events in the inventory.

## Covariates

Economic covariates:

- `retail_volume_index`
- `services_volume_index`
- `formal_hiring_balance`

PNADc covariates:

- `unemployment_rate_pnadc`
- `formalization_rate_pnadc`

Fiscal covariates:

- `total_revenue_real`
- `state_tax_revenue_real`
- `own_revenue_ratio`

Open implementation choice:

- The checklist does not select a specific lag rule. The pilot script should begin with a conservative predictor set using pre-treatment averages and selected pre-treatment lags rather than all monthly lags.

## Method

Main method:

- Augmented Synthetic Control Method for the monthly formal-employment outcome in levels.

Diagnostics and robustness:

- Augmented SCM with post-treatment-clean 6-month moving average;
- Classic SCM as transparent baseline;
- placebo tests by donor UF;
- leave-one-out donor sensitivity;
- alternative treatment timing;
- alternative post-treatment window.

Methods no longer kept as active routes:

- Ridge diagnostics.
- Nonlinear SCM.

These were useful exploratory checks, but they are not part of the preferred empirical hierarchy because they add interpretive complexity and, in this pilot, do not strengthen the formal-employment result enough to justify inclusion.

## CAGED Break Handling

The main monthly post-treatment window extends through `2020-12`, so the CAGED series crosses the January 2020 Old CAGED/Novo CAGED methodological break.

Selected control:

- `post_2020_caged_dummy`

Implementation note:

- The checklist currently selects `post_2020_caged_dummy` but not `caged_method_break_dummy`. Since the two dummies are equivalent in the current processed CAGED panel, using only one avoids perfect duplication in model matrices. Documentation should still mention that it represents the January 2020 CAGED methodological break.

Robustness:

- Run a shorter employment specification ending in `2019-12`.

## Outputs

The pilot should produce:

- event-specific analytical panel for `RR_2018_01`;
- pre/post summary table for RR and donor pool;
- outcome time-series plot;
- treated versus synthetic plot;
- gap plot;
- placebo plot;
- donor weights table;
- predictor balance table;
- short pilot memo documenting decisions and results.

## Immediate Next Step

Build the pilot data assembly script for `RR_2018_01`, creating one monthly analytical panel and one bimonthly fiscal analytical panel under a pilot-specific output folder.
