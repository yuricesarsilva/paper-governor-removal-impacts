# RR 2018 Monthly SCM First Results

This note summarizes the first monthly SCM run for the `RR_2018_01` pilot.

## Script

Main SCM script:

- `pilots/rr_2018_01/code/02_run_monthly_scm.R`

Input:

- `pilots/rr_2018_01/data/rr_2018_01_monthly_panel.csv`

Output folder:

- `pilots/rr_2018_01/output/scm_monthly/`

## Specification

Method:

- Classic SCM implemented with constrained quadratic optimization through `quadprog`.
- Donor weights are non-negative and sum to 1.

Main donor pool:

- All UFs except `RR`, `AM`, and `TO`.

Timing:

- Pre-treatment: `2016-01` to `2018-11`.
- Transition excluded: `2018-12`.
- Post-treatment: `2019-01` to `2020-12`.

Predictors:

- Full pre-treatment path of the outcome.
- Mean pre-treatment economic covariates, excluding the outcome itself.
- Mean pre-treatment PNADc covariates: `unemployment_rate_pnadc` and `formalization_rate_pnadc`.
- PNADc observations from `2018Q4` are excluded from predictor construction through `pnadc_predictor_valid`.

Outcomes:

- `formal_hiring_balance`.
- `retail_volume_index`.
- `services_volume_index`.

## Main Results

### Formal Hiring Balance

Positive donor weights:

- `MS`: 0.583.
- `PA`: 0.135.
- `AP`: 0.104.
- `ES`: 0.086.
- `MA`: 0.086.
- `SC`: 0.005.

Fit and post-treatment gap:

- Pre RMSPE: 1,685.1.
- Post RMSPE: 3,103.6.
- Post/pre RMSPE ratio: 1.84.
- Mean pre-treatment gap: 319.6.
- Mean post-treatment gap: -638.8.
- Mean post-treatment RR value: 220.5.
- Mean post-treatment synthetic value: 859.3.

Placebo rank:

- RR ranks 5th out of 25 units by post/pre RMSPE ratio, counting RR plus placebo units.

Pre-2020 robustness:

- Post window restricted to `2019-01` through `2019-12`.
- Post/pre RMSPE ratio: 1.33.
- RR ranks 5th out of 25 units.

### Retail Volume Index

Positive donor weights:

- `MS`: 0.368.
- `PA`: 0.298.
- `ES`: 0.228.
- `AP`: 0.106.

Fit and post-treatment gap:

- Pre RMSPE: 5.10.
- Post RMSPE: 4.43.
- Post/pre RMSPE ratio: 0.87.
- Mean pre-treatment gap: -0.82.
- Mean post-treatment gap: -2.79.
- Mean post-treatment RR value: 83.69.
- Mean post-treatment synthetic value: 86.48.

Placebo rank:

- RR ranks 24th out of 25 units by post/pre RMSPE ratio.

Pre-2020 robustness:

- Post/pre RMSPE ratio: 0.85.
- RR ranks 23rd out of 25 units.

### Services Volume Index

Positive donor weights:

- `MG`: 0.504.
- `SC`: 0.329.
- `PA`: 0.118.
- `SP`: 0.049.

Fit and post-treatment gap:

- Pre RMSPE: 6.20.
- Post RMSPE: 7.62.
- Post/pre RMSPE ratio: 1.23.
- Mean pre-treatment gap: -2.66.
- Mean post-treatment gap: -6.14.
- Mean post-treatment RR value: 76.70.
- Mean post-treatment synthetic value: 82.84.

Placebo rank:

- RR ranks 13th out of 25 units by post/pre RMSPE ratio.

Pre-2020 robustness:

- Post/pre RMSPE ratio: 1.11.
- RR ranks 13th out of 25 units.

## Leave-One-Out Sensitivity

The script reruns each SCM after omitting each donor with weight greater than 0.001.

Formal hiring balance:

- Post/pre RMSPE ratios range from 1.74 to 2.08.
- The result is not driven by a single small-weight donor, but `MS` is substantively important because it has the largest weight.

Retail volume index:

- Post/pre RMSPE ratios range from 0.86 to 0.95.
- The retail result remains weak in the same direction under leave-one-out.

Services volume index:

- Post/pre RMSPE ratios range from 1.12 to 1.43.
- Omitting `MG` increases the ratio most, consistent with its large donor weight.

## Initial Interpretation

These are pilot results, not final paper estimates.

The first pass suggests:

- Employment has the strongest visual/statistical signal among the three monthly outcomes, with RR below its synthetic path after treatment and a relatively high placebo rank.
- Retail does not show a strong treatment signal in this specification.
- Services shows a negative gap, but the placebo ranking is not especially distinctive.

The next step is to inspect the figures and predictor balance tables before deciding whether to refine the predictor set or move to fiscal SCM.
