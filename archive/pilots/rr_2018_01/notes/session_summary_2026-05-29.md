# Session Summary 2026-05-29

This note consolidates the work completed in the RR 2018 pilot session.

## Active Hierarchy

The active empirical hierarchy now focuses on formal employment:

- Main outcome: `formal_hiring_balance`.
- Main specification: Augmented SCM in levels.
- Main smoothing robustness: Augmented SCM with post-treatment-clean 6-month moving average.
- Baseline/diagnostic: classic SCM.

The default monthly timing remains:

- Pre-treatment: `2016-01` to `2018-11`.
- Transition month excluded: `2018-12`.
- First treated month: `2019-01`.

Ridge diagnostics and Nonlinear SCM are no longer active routes. Their outputs are retained only for auditability and exploratory context.

## Moving-Average Corrections

The original trailing moving averages carried pre-treatment information into the first post-treatment months. New post-treatment-clean versions restart the moving-average window at the first post-treatment period.

Monthly employment:

- MA6 post-clean starts in `2019-01`, but full-window evaluation starts in `2019-06`.
- MA12 post-clean starts in `2019-01`, but full-window evaluation starts in `2019-12`.

Quarterly PNADc income:

- MA2 post-clean starts in `2019Q1`, but full-window evaluation starts in `2019Q2`.
- MA4 post-clean starts in `2019Q1`, but full-window evaluation starts in `2019Q4`.

The full-window tests show that much of the large negative smoothed gap is driven by the partial-window ramp-up months.

## December 2018 Robustness

A separate robustness includes December 2018 as a treated month. The active specification still excludes December 2018.

Key result:

- Employment in levels changes little when December 2018 is treated.
- MA6 is much more sensitive to including December 2018, confirming that smoothed specifications depend strongly on transition-month handling.

The December 2018 treated outputs are stored separately and should not replace the active hierarchy.

## PNADc Quarterly Tests

Quarterly PNADc outcomes were tested with Augmented SCM:

- `labor_income_real_pnadc`
- `labor_income_real_pnadc_ma2_post_clean`
- `labor_income_real_pnadc_ma4_post_clean`
- `unemployment_rate_pnadc`
- `formalization_rate_pnadc`

Preliminary pattern:

- Unemployment is persistently above the counterfactual after treatment.
- Formalization is persistently below the counterfactual.
- Real labor income is negative in 2019 and recovers in 2020 in levels and MA2; MA4 is more negative in 2019 and near neutral in 2020.

Caveat:

- The augmented correction fits the short quarterly pre-treatment path almost perfectly. These outcomes remain secondary extensions until additional classic SCM/placebo/sensitivity diagnostics are reviewed.

## Nonlinear SCM

Nonlinear SCM was implemented and tested, including employment per 100k normalization.

Decision:

- It is not part of the active hierarchy.
- Employment results are statistically indistinguishable from zero and sensitive to scaling.
- Activity outcomes show strong negative gaps but rely on substantial extrapolation.

## Main New Scripts

- `pilots/rr_2018_01/code/09_run_nonlinear_scm.R`
- `pilots/rr_2018_01/code/10_run_pnadc_quarterly_augmented_scm.R`
- `pilots/rr_2018_01/code/11_run_augmented_scm_dec2018_treated.R`

Main modified scripts:

- `pilots/rr_2018_01/code/08_run_augmented_scm.R`
- `pilots/rr_2018_01/code/03_run_monthly_scm_moving_average.R`
- `pilots/rr_2018_01/code/05_compare_employment_specs.R`

## Main Output Folders

- `pilots/rr_2018_01/output/augmented_scm_monthly_post_clean/`
- `pilots/rr_2018_01/output/augmented_scm_monthly_post_clean_ma12/`
- `pilots/rr_2018_01/output/augmented_scm_monthly_post_clean_full_window/`
- `pilots/rr_2018_01/output/augmented_scm_monthly_dec2018_treated/`
- `pilots/rr_2018_01/output/augmented_scm_monthly_dec2018_treated_post_clean/`
- `pilots/rr_2018_01/output/augmented_scm_pnadc_quarterly/`
- `pilots/rr_2018_01/output/augmented_scm_pnadc_quarterly_full_window/`
- `pilots/rr_2018_01/output/nonlinear_scm_monthly/`
- `pilots/rr_2018_01/output/nonlinear_scm_monthly_employment_per_100k/`

## Next Steps

1. Produce compact final tables for the active formal-employment hierarchy.
2. Add Augmented SCM placebos for the active formal-employment results.
3. Diagnose PNADc quarterly outcomes with classic SCM/placebos before deciding whether they enter the main paper.
4. Keep ridge and Nonlinear SCM out of the active empirical narrative unless needed in an appendix.
