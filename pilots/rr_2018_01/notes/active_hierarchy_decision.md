# Active Empirical Hierarchy Decision

This note records the current empirical hierarchy for the `RR_2018_01` pilot after reviewing classic SCM, moving-average specifications, ridge diagnostics, Augmented SCM, and Nonlinear SCM.

## Main Economic Outcome

The active economic outcome is:

- `formal_hiring_balance`.

The pilot will focus on formal employment rather than carrying retail and services as coequal economic outcomes.

## Preferred Monthly Specification

Treatment timing:

- December 2018 remains excluded as the transition month.
- The first treated month in the active monthly specification is January 2019.
- The December-2018-as-treated specification is retained only as a robustness check.

Main specification:

- Augmented SCM in levels for `formal_hiring_balance`.

Main robustness:

- Augmented SCM with post-treatment-clean 6-month moving average.

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

## PNADc Outcomes Still To Test

The next labor-market extension is quarterly PNADc:

- real labor income from all jobs;
- possibly unemployment rate;
- possibly formalization rate.

These outcomes have now been tested preliminarily with Augmented SCM. The first results are promising for unemployment and formalization, but the short quarterly pre-treatment path is fitted almost perfectly by the augmented correction. They should therefore remain pending secondary extensions until classic SCM diagnostics, placebo checks, and sensitivity to the augmented correction are reviewed.
