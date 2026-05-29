# December 2018 Treated-Month Robustness

This note records a robustness check that includes December 2018 as a treated month instead of excluding it as a transition month.

This is not the active specification. The active hierarchy keeps December 2018 excluded and uses January 2019 as the first treated month.

## Script

Script:

- `pilots/rr_2018_01/code/11_run_augmented_scm_dec2018_treated.R`

Output folders:

- `pilots/rr_2018_01/output/augmented_scm_monthly_dec2018_treated/`
- `pilots/rr_2018_01/output/augmented_scm_monthly_dec2018_treated_post_clean/`

## Design

The main specification keeps:

- Pre-treatment: `2016-01` to `2018-11`.
- Transition month excluded: `2018-12`.
- Post-treatment: `2019-01` to `2020-12`.

This robustness changes only the transition rule:

- Pre-treatment: `2016-01` to `2018-11`.
- Post-treatment: `2018-12` to `2020-12`.

The dashed line in the robustness plots is therefore placed at `2018-12-01`.

## Results

| Specification | Outcome | Augmented pre RMSPE | Augmented post RMSPE | Augmented post mean gap |
| --- | --- | ---: | ---: | ---: |
| Main, Dec/2018 excluded | `formal_hiring_balance` | 273.6 | 542.5 | -118.2 |
| Dec/2018 treated | `formal_hiring_balance` | 273.6 | 531.7 | -116.5 |
| Main, Dec/2018 excluded, post-clean MA6 | `formal_hiring_balance_ma6` | 33.4 | 658.0 | -236.4 |
| Dec/2018 treated, post-clean MA6 | `formal_hiring_balance_ma6` | 33.4 | 388.2 | -10.7 |

## Interpretation

For the level employment outcome, including December 2018 as treated changes very little. The post-treatment mean gap remains negative and close to the main specification.

For the post-clean 6-month moving average, the result changes substantially because the smoothing window now starts in December 2018. December itself has a positive smoothed gap, and the first months of 2019 are less negative in the smoothed series. This confirms that the smoothed specification is sensitive to the transition-month rule.

The main specification should still exclude December 2018 because it is a partially treated transition month. This robustness is useful mainly to show that the level-employment result is not driven by dropping December 2018, while the moving-average robustness is more sensitive to that choice.
