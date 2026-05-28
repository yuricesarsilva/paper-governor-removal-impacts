# Augmented SCM Monthly Check

This note records the first formal Augmented SCM check for the `RR_2018_01` monthly outcomes.

## Script

Script:

- `pilots/rr_2018_01/code/08_run_augmented_scm.R`

Output folder:

- `pilots/rr_2018_01/output/augmented_scm_monthly/`

## Method

This implementation keeps the classic SCM structure as the baseline:

- first estimate convex SCM weights;
- then add a ridge-based bias correction for predictor imbalance.

This is more interpretable than the pure ridge diagnostic because the counterfactual still starts from the classic SCM donor weights.

## Outcomes

Level outcomes:

- `formal_hiring_balance`
- `retail_volume_index`
- `services_volume_index`

6-month moving-average outcomes:

- `formal_hiring_balance_ma6`
- `retail_volume_index_ma6`
- `services_volume_index_ma6`

## Fit Summary

| Outcome | SCM pre RMSPE | Augmented pre RMSPE | SCM post RMSPE | Augmented post RMSPE |
| --- | ---: | ---: | ---: | ---: |
| `formal_hiring_balance` | 828.5 | 273.6 | 1,540.1 | 542.5 |
| `formal_hiring_balance_ma6` | 361.5 | 33.4 | 1,044.0 | 388.6 |
| `retail_volume_index` | 5.06 | 2.62 | 4.46 | 6.55 |
| `retail_volume_index_ma6` | 3.36 | 0.37 | 3.30 | 3.39 |
| `services_volume_index` | 6.21 | 2.14 | 7.28 | 8.92 |
| `services_volume_index_ma6` | 3.78 | 0.31 | 6.26 | 5.02 |

## Post-Treatment Gap Pattern

Average augmented gaps by year:

| Outcome | 2019 | 2020 |
| --- | ---: | ---: |
| `formal_hiring_balance` | -152.1 | -84.4 |
| `formal_hiring_balance_ma6` | -332.1 | 188.3 |
| `retail_volume_index` | 0.47 | -5.63 |
| `retail_volume_index_ma6` | 2.08 | -2.64 |
| `services_volume_index` | -1.57 | -9.68 |
| `services_volume_index_ma6` | -2.23 | -6.34 |

## Interpretation

The Augmented SCM version improves pre-treatment fit without fully abandoning the SCM structure.

Compared with the pure ridge diagnostic, the retail result is less suspicious:

- pure ridge suggested a strong positive retail gap in both 2019 and 2020;
- Augmented SCM shows a small positive retail gap in 2019 but a negative gap in 2020.

Services remains consistently negative across specifications.

Employment in levels remains negative in both 2019 and 2020 under Augmented SCM, while the 6-month moving-average employment outcome is negative in 2019 and positive in 2020. This suggests the employment result is sensitive to smoothing and should be inspected visually.

## Recommendation

For the pilot memo, treat Augmented SCM as the leading methodological candidate because it balances:

- better pre-treatment fit than classic SCM;
- more interpretability than pure ridge;
- clearer diagnostics across level and smoothed outcomes.

The next step should be visual inspection of:

- `*_treated_scm_augmented.png`;
- `*_gaps.png`;

followed by deciding which outcome transformation is credible enough for the first polished pilot result.
