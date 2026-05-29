# PNADc Quarterly Augmented SCM Check

This note records the first quarterly PNADc Augmented SCM check for the `RR_2018_01` pilot.

## Script

Script:

- `pilots/rr_2018_01/code/10_run_pnadc_quarterly_augmented_scm.R`

Output folder:

- `pilots/rr_2018_01/output/augmented_scm_pnadc_quarterly/`
- `pilots/rr_2018_01/output/augmented_scm_pnadc_quarterly_full_window/`

## Design

Quarterly window:

- Pre-treatment: `2016Q1` to `2018Q3`.
- Transition excluded: `2018Q4`.
- Post-treatment: `2019Q1` to `2020Q4`.

Donor pool:

- Excludes `RR`, `AM`, and `TO`, matching the monthly pilot rule.

Outcomes:

- `labor_income_real_pnadc`
- `labor_income_real_pnadc_ma2_post_clean`
- `labor_income_real_pnadc_ma4_post_clean`
- `unemployment_rate_pnadc`
- `formalization_rate_pnadc`

The predictor matrix uses pre-treatment outcome lags plus pre-treatment means of the other PNADc labor variables.

The full-window robustness keeps the same pre-treatment fit but evaluates smoothed post-treatment income only after the moving-average window is complete:

- `labor_income_real_pnadc_ma2_post_clean`: post period starts in `2019Q2`.
- `labor_income_real_pnadc_ma4_post_clean`: post period starts in `2019Q4`.

## Fit Summary

| Outcome | SCM pre RMSPE | Augmented pre RMSPE | SCM post RMSPE | Augmented post RMSPE | Augmented post mean gap |
| --- | ---: | ---: | ---: | ---: | ---: |
| `labor_income_real_pnadc` | 72.32 | 0.66 | 143.65 | 141.42 | 40.69 |
| `labor_income_real_pnadc_ma2_post_clean` | 55.30 | 2.61 | 129.60 | 132.30 | 25.89 |
| `labor_income_real_pnadc_ma4_post_clean` | 39.16 | 2.36 | 113.74 | 115.09 | -62.47 |
| `unemployment_rate_pnadc` | 0.0103 | 0.000006 | 0.0504 | 0.0489 | 0.0479 |
| `formalization_rate_pnadc` | 0.0063 | 0.000034 | 0.0370 | 0.0372 | -0.0327 |

## Post-Treatment Gap Pattern

Average augmented gaps by year:

| Outcome | 2019 | 2020 |
| --- | ---: | ---: |
| `labor_income_real_pnadc` | -23.6 | 105.0 |
| `labor_income_real_pnadc_ma2_post_clean` | -34.1 | 85.9 |
| `labor_income_real_pnadc_ma4_post_clean` | -130.4 | 6.5 |
| `unemployment_rate_pnadc` | 0.0476 | 0.0481 |
| `formalization_rate_pnadc` | -0.0229 | -0.0426 |

## Interpretation

The PNADc results are substantively interesting:

- RR unemployment is persistently above the Augmented SCM counterfactual by about 4.8 percentage points.
- RR formalization is persistently below the Augmented SCM counterfactual, with a larger negative gap in 2020.
- Real labor income in levels is negative in 2019 but positive in 2020.
- The post-clean 2-quarter moving average follows the same broad pattern, with a slightly more negative 2019 gap and a positive 2020 gap.
- The post-clean 4-quarter moving average of real labor income is more negative in 2019 and approximately neutral in 2020.

Under the full-window restriction, the smoothed income gaps are less negative:

| Outcome | First full post window | Augmented post mean gap |
| --- | --- | ---: |
| `labor_income_real_pnadc_ma2_post_clean` | `2019Q2` | 56.1 |
| `labor_income_real_pnadc_ma4_post_clean` | `2019Q4` | -11.2 |

This reinforces that early partial-window observations drive much of the initial negative smoothed-income result.

However, these should be treated as preliminary. The Augmented SCM correction fits the short quarterly pre-treatment path almost perfectly, especially for unemployment and formalization. With only 11 pre-treatment quarters, this may reflect overfitting rather than genuinely strong predictive performance.

For the active hierarchy, these PNADc outcomes are promising secondary labor-market extensions, but they should not replace the monthly formal-employment specification without additional diagnostics such as classic SCM comparison, placebo checks, and possibly a less aggressive augmented specification.
