# RR 2018 Selected Economic Short-Run Results

This folder consolidates the three economic outcomes selected for short-run visualization in the `RR_2018_01` pilot.

## Empirical Hierarchy

The economic short-run package uses:

- Formal employment balance as the main monthly outcome.
- Real labor income as the main income-side PNADc extension.
- Formalization rate as the labor-market composition PNADc extension.

The substantive estimand is the short-run disruption after the governor removal, not a persistent effect through the full post-treatment period. The main windows are therefore:

- Monthly outcomes: January 2019 to June 2019 as the first six months, with January 2019 to December 2019 as the first year.
- Quarterly PNADc outcomes: 2019 as the first post-treatment year.

December 2018 remains excluded as the transition period.

## Files

Formal employment:

- `formal_employment/formal_hiring_balance_*`
- `formal_employment/formal_hiring_balance_ma6_*`
- `formal_employment/formal_hiring_balance_per_1000_ma6_*`

Real labor income:

- `labor_income_real/labor_income_real_pnadc_ma4_post_clean_*`

Formalization rate:

- `formalization_rate/formalization_rate_pnadc_*`

Consolidated table:

- `economic_short_run_selected_summary.csv`

## Summary

| Outcome | Specification | Short-run window | Augmented gap | Classic gap | Interpretation |
| --- | --- | --- | ---: | ---: | --- |
| Formal employment balance | Monthly level | Jan-Jun 2019 | -465.4 jobs | -795.5 jobs | Negative initial employment shock. |
| Formal employment balance | Monthly MA6 post-clean | Jan-Jun 2019 | -1,090.1 jobs | -2,056.2 jobs | Stronger negative signal after smoothing. |
| Formal employment balance | Monthly MA6 post-clean per 1,000 inhabitants | Jan-Jun 2019 | -0.811 jobs per 1,000 | -1.098 jobs per 1,000 | Negative signal is not only a donor-size artifact. |
| Real labor income | Quarterly MA4 post-clean | 2019 | -130.4 BRL | -119.2 BRL | Income-side effect is negative in the first year. |
| Formalization rate | Quarterly level | 2019 | -0.0229 | -0.0290 | Formalization falls relative to the synthetic counterfactual. |

## Full Post-Treatment Averages

| Outcome | Specification | Augmented post mean | 2019 mean | 2020 mean |
| --- | --- | ---: | ---: | ---: |
| Formal employment balance | Monthly level | -118.2 jobs | -152.1 jobs | -84.4 jobs |
| Formal employment balance | Monthly MA6 post-clean | -236.4 jobs | -661.1 jobs | 188.3 jobs |
| Formal employment balance | Monthly MA6 post-clean per 1,000 inhabitants | 0.060 jobs per 1,000 | -0.296 jobs per 1,000 | 0.415 jobs per 1,000 |
| Real labor income | Quarterly MA4 post-clean | -62.0 BRL | -130.4 BRL | 6.5 BRL |
| Formalization rate | Quarterly level | -0.0327 | -0.0229 | -0.0426 |

## Interpretation

The selected outcomes support a short-run economic disruption interpretation.

Formal employment is the central outcome because it is monthly and closest to the immediate labor-market adjustment. The negative gap is concentrated in the first six months and weakens or reverses after 2019 under smoothed specifications, which is consistent with a transitory shock and subsequent adjustment by the new administration.

Real labor income provides a quarterly income-side validation. The MA4 post-clean specification is negative in 2019 and approximately neutral in 2020.

Formalization rate adds a composition margin. The gap remains negative in both 2019 and 2020, suggesting that the labor-market adjustment may have involved lower formalization even after the initial employment shock weakened.

The PNADc results should remain secondary to formal employment because the quarterly pre-treatment path is shorter and Augmented SCM can fit it very tightly.
