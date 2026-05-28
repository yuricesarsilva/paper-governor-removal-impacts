# Employment Alternative Specifications

This note records three alternatives tested after the first level-outcome SCM showed weak pre-treatment fit for `formal_hiring_balance`.

## Scripts

Alternative specifications:

- `pilots/rr_2018_01/code/04_run_employment_alternative_specs.R`

Normalized comparison:

- `pilots/rr_2018_01/code/05_compare_employment_specs.R`

Output folder:

- `pilots/rr_2018_01/output/employment_alternative_specs/`

## Tested Alternatives

### 1. Level Outcome With Semester Predictors

Outcome:

- `formal_hiring_balance`

Change:

- Instead of using all monthly pre-treatment outcome lags as predictors, use semester-level pre-treatment means.

Rationale:

- Reduce overfitting to high-frequency monthly noise.

### 2. Six-Month Accumulated Flow

Outcome:

- `formal_hiring_balance_6m_sum`

Construction:

- Trailing 6-month sum of `formal_hiring_balance` within each UF.

Rationale:

- Employment balance is a flow. A 6-month accumulated flow has a natural interpretation: net formal job creation over the recent semester.

### 3. Cumulative Flow Since Start Of Window

Outcome:

- `formal_hiring_balance_cumulative`

Construction:

- Cumulative sum of `formal_hiring_balance` from the start of the pilot panel.

Rationale:

- Reduce month-to-month noise by focusing on the cumulative employment path.

## Raw RMSPE Comparison

| Specification | Pre RMSPE | Post RMSPE | Post/pre RMSPE |
| --- | ---: | ---: | ---: |
| baseline monthly lags | 1,685.1 | 3,103.6 | 1.84 |
| level with semester predictors | 2,460.6 | 3,690.2 | 1.50 |
| six-month accumulated flow | 3,382.2 | 11,098.1 | 3.28 |
| cumulative flow since 2016 | 5,714.5 | 15,669.5 | 2.74 |

Raw RMSPE is not directly comparable across transformed outcomes because the outcome scale changes.

## Normalized Pre-Fit Comparison

The comparison below divides pre-treatment RMSPE by the pre-treatment standard deviation of the treated RR series for the corresponding outcome.

| Specification | Pre RMSPE / RR pre SD | Pre correlation | Post/pre RMSPE |
| --- | ---: | ---: | ---: |
| 6-month moving average | 5.91 | 0.00 | 3.25 |
| six-month accumulated flow | 6.00 | -0.01 | 3.28 |
| 3-month moving average | 6.31 | 0.34 | 2.47 |
| baseline monthly lags | 7.05 | 0.39 | 1.84 |
| cumulative flow since 2016 | 8.43 | 0.10 | 2.74 |
| level with semester predictors | 10.29 | 0.37 | 1.50 |

## Interpretation

The 6-month moving average and the 6-month accumulated flow improve the normalized pre-treatment fit relative to the baseline level specification.

The level specification with semester predictors does not help in this pilot; it worsens the pre-treatment fit.

The cumulative flow since 2016 also does not improve pre-fit enough to justify using it as the next main employment specification.

The six-month accumulated flow is substantively attractive because it keeps a flow interpretation:

```text
net formal job creation over the previous six months
```

However, even the best alternatives still show imperfect pre-treatment fit. This suggests that the next methodological step should be to test an augmented SCM or ridge-regularized approach rather than continuing to tune only the outcome transformation.

## Recommendation

For the next employment iteration:

- Keep the level outcome as a transparent baseline.
- Keep the 6-month accumulated flow or 6-month moving average as the preferred smoothed robustness check.
- Do not use the semester-predictor specification as a main result.
- Test Augmented SCM/ridge next, because the remaining pre-fit problem likely reflects noisy outcomes and imperfect donor comparability.
