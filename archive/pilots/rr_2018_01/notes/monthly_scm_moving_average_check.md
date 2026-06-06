# Monthly SCM Moving-Average Check

This note records an exploratory check motivated by the high month-to-month variability in the monthly outcomes.

## Script

Script:

- `pilots/rr_2018_01/code/03_run_monthly_scm_moving_average.R`

Output folder:

- `pilots/rr_2018_01/output/scm_monthly_moving_average/`
- `pilots/rr_2018_01/output/scm_monthly_moving_average_post_clean/`

## Smoothing Rule

The script creates trailing moving averages by state for the three monthly outcomes:

- `formal_hiring_balance`
- `retail_volume_index`
- `services_volume_index`

Windows tested:

- 3-month trailing moving average.
- 6-month trailing moving average.

At the beginning of each state series, the script uses partial trailing windows so that early 2016 observations are not dropped.

The `scm_monthly_moving_average_post_clean` outputs use the same trailing-window rule in the pre-treatment period, but restart the trailing window at the beginning of the post-treatment period. This avoids carrying pre-treatment months into the first post-treatment moving averages:

- January 2019 uses only January 2019.
- February 2019 uses January-February 2019.
- March 2019 is the first full 3-month post-treatment moving average.
- June 2019 is the first full 6-month post-treatment moving average.

## RMSPE Comparison

| Outcome | Version | Pre RMSPE | Post RMSPE | Post/pre RMSPE |
| --- | ---: | ---: | ---: | ---: |
| `formal_hiring_balance` | level | 1,685.1 | 3,103.6 | 1.84 |
| `formal_hiring_balance` | 3-month MA | 979.4 | 2,415.0 | 2.47 |
| `formal_hiring_balance` | 6-month MA | 573.4 | 1,866.2 | 3.25 |
| `retail_volume_index` | level | 5.10 | 4.43 | 0.87 |
| `retail_volume_index` | 3-month MA | 4.32 | 3.88 | 0.90 |
| `retail_volume_index` | 6-month MA | 3.39 | 3.45 | 1.02 |
| `services_volume_index` | level | 6.20 | 7.62 | 1.23 |
| `services_volume_index` | 3-month MA | 4.51 | 6.46 | 1.43 |
| `services_volume_index` | 6-month MA | 3.74 | 6.47 | 1.73 |

## Interpretation

The moving-average versions improve pre-treatment fit for all three monthly outcomes.

The improvement is strongest for `formal_hiring_balance`, where pre RMSPE falls from 1,685.1 in levels to 573.4 with a 6-month moving average.

The stronger post/pre RMSPE ratios in the smoothed employment and services outcomes suggest that some of the poor initial pre-treatment fit was driven by high-frequency noise rather than only by poor donor-pool comparability.

## Methodological Caution

Moving averages change the estimand:

- Level specifications estimate effects on the monthly outcome.
- Moving-average specifications estimate effects on a smoothed short-run path.

For the paper, moving averages should therefore be presented as a robustness or complementary specification, not as an automatic replacement for the level outcome.

Recommended next step:

- Inspect the smoothed paths visually.
- If the smoothed employment specification looks substantively coherent, keep both level and 3- or 6-month moving-average specifications in the pilot memo.
