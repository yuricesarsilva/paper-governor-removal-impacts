# Active Empirical Hierarchy Decision

This note records the current empirical hierarchy for the `RR_2018_01` pilot after reviewing classic SCM, moving-average specifications, ridge diagnostics, Augmented SCM, and Nonlinear SCM.

## Selected Economic Short-Run Outcomes

The active economic short-run package now has three outcomes:

- Main outcome: `formal_hiring_balance`.
- Secondary income outcome: `labor_income_real_pnadc`.
- Secondary labor-market composition outcome: `formalization_rate_pnadc`.

The pilot will focus on short-run economic disruption rather than persistent post-treatment effects over the entire 2019-2020 period. For monthly employment, the main short-run window is the first six months after treatment, January to June 2019, with the first post-treatment year retained as a complementary window. For quarterly PNADc outcomes, the main short-run window is 2019.

Formal employment remains the primary economic outcome because it is monthly and closest to the immediate labor-market adjustment. Real labor income and formalization rate are secondary PNADc extensions.

## Preferred Monthly Specification

Treatment timing:

- December 2018 remains excluded as the transition month.
- The first treated month in the active monthly specification is January 2019.
- The December-2018-as-treated specification is retained only as a robustness check.

Main specification:

- Augmented SCM in levels for `formal_hiring_balance`.

Main robustness:

- Augmented SCM with post-treatment-clean 6-month moving average.
- Augmented SCM with the post-treatment-clean 6-month moving average normalized per 1,000 inhabitants, used as a scale diagnostic.

Baseline/diagnostic:

- Classic SCM.

The classic SCM remains useful because it is transparent and convex, but it is not the preferred estimator when discussing the substantive employment result.

## Methods No Longer Active

The following methods are no longer active routes for the preferred hierarchy:

- Ridge diagnostics.
- Nonlinear SCM.

Ridge diagnostics improve pre-treatment fit but rely on coefficients with mixed signs and weaker synthetic-unit interpretation.

Nonlinear SCM is useful as an exploratory inferential check, but in this pilot it adds interpretive complexity and does not strengthen the formal-employment result enough to justify inclusion in the active hierarchy.

Existing outputs are retained for auditability, but new substantive tables and figures should not center these methods.

## Secondary Outcomes

Retail and services are no longer active main economic outcomes:

- `retail_volume_index`;
- `services_volume_index`.

They may remain in appendix/exploratory material if useful, but the main pilot story should not be organized around them.

## PNADc Outcomes

The PNADc extension is now narrowed to:

- real labor income from all jobs;
- formalization rate.

Real labor income is used with a post-treatment-clean 4-quarter moving average. Formalization rate is used in levels. Both remain secondary to formal employment because the quarterly pre-treatment path is shorter and the augmented correction can fit it very tightly.

Unemployment remains available as an exploratory PNADc outcome, but it is not part of the current three-variable economic short-run package.

The consolidated selected-output folder is:

- `pilots/rr_2018_01/output/economic_short_run_selected/`
