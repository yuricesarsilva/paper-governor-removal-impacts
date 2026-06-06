# RR 2018 Pilot

This folder centralizes documents for the Roraima pilot based on `RR_2018_01`.

## Documents

- `decision_checklist.md`: user-selected decisions for the pilot specification.
- `pilot_specification.md`: consolidated working specification derived from the checklist.
- `data_assembly_validation.md`: validation note for the first pilot panels.
- `monthly_scm_first_results.md`: first monthly SCM results for employment, retail, and services.
- `monthly_scm_moving_average_check.md`: robustness check using smoothed monthly outcomes.
- `employment_alternative_specs.md`: comparison of employment transformations and aggregated-predictor alternatives.
- `employment_ridge_scm_check.md`: first ridge-regularized employment SCM diagnostic.
- `activity_ridge_scm_check.md`: ridge diagnostics for retail and services outcomes.
- `augmented_scm_monthly_check.md`: first formal Augmented SCM check for monthly outcomes.
- `nonlinear_scm_monthly_check.md`: exploratory Nonlinear SCM check, retained as diagnostic but no longer part of the active hierarchy.
- `pnadc_quarterly_augmented_scm_check.md`: first Augmented SCM check for quarterly PNADc labor outcomes.
- `dec2018_treated_robustness.md`: robustness check including December 2018 as a treated month.
- `active_hierarchy_decision.md`: current preferred empirical hierarchy after reviewing Augmented SCM, ridge, Nonlinear SCM, and outcome scope.
- `results_report.md`: consolidated report of all current pilot results.

## Current Status

The current preferred hierarchy focuses on formal employment. The main specification is Augmented SCM in levels, with post-treatment-clean 6-month moving-average Augmented SCM as the main smoothing robustness and classic SCM as baseline. Ridge diagnostics and Nonlinear SCM are retained only as exploratory diagnostics. Quarterly PNADc labor-income, unemployment, and formalization outcomes have now been tested preliminarily and require additional diagnostics before inclusion in the active hierarchy.
