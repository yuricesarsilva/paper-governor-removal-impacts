# Employment Ridge Synthetic Control Check

This note records the first ridge-regularized synthetic control check for the `RR_2018_01` employment outcome.

## Script

Script:

- `pilots/rr_2018_01/code/06_run_employment_ridge_scm.R`

Output folder:

- `pilots/rr_2018_01/output/employment_ridge_scm/`

## Method

This is a ridge synthetic-control diagnostic, not classic SCM.

Classic SCM:

- non-negative donor weights;
- weights sum to 1;
- synthetic unit is a convex combination of donor states.

Ridge specification:

- estimates a regularized linear combination of donor states;
- allows negative coefficients;
- coefficients do not need to sum to 1;
- chooses the ridge penalty by leave-one-out cross-validation over the pre-treatment months.

The advantage is better pre-treatment fit. The cost is weaker interpretability as a literal synthetic state.

## Outcomes Tested

- `formal_hiring_balance`
- `formal_hiring_balance_ma6`
- `formal_hiring_balance_6m_sum`

## Results

| Outcome | Pre RMSPE | Post RMSPE | Post/pre RMSPE | Lambda |
| --- | ---: | ---: | ---: | ---: |
| `formal_hiring_balance` | 102.7 | 352.3 | 3.43 | 3.61 |
| `formal_hiring_balance_ma6` | 15.5 | 267.3 | 17.21 | 0.20 |
| `formal_hiring_balance_6m_sum` | 56.0 | 1,363.6 | 24.33 | 0.05 |

Compared with classic SCM, ridge sharply improves the pre-treatment fit:

- classic SCM level pre RMSPE: 1,685.1;
- ridge level pre RMSPE: 102.7;
- classic 6-month moving-average pre RMSPE: 573.4;
- ridge 6-month moving-average pre RMSPE: 15.5;
- classic 6-month accumulated-flow pre RMSPE: 3,382.2;
- ridge 6-month accumulated-flow pre RMSPE: 56.0.

## Coefficient Pattern

The ridge fits use both positive and negative coefficients.

Examples:

- Level outcome: large positive coefficients for `SC` and `PE`, negative coefficients for `MA` and `MS`.
- 6-month moving average: large positive coefficients for `PE`, `RN`, and `SC`, but a large negative coefficient for `MA`.
- 6-month accumulated flow: large positive coefficients for `SC`, `PE`, and `RN`, but negative coefficients for `MS`, `ES`, `RS`, and `CE`.

This pattern is expected in ridge regression, but it means the resulting unit should be described as a regularized prediction or augmented synthetic counterfactual rather than as a standard SCM donor-weight convex combination.

## Interpretation

The ridge results strongly support the concern that the poor classic SCM pre-fit was partly methodological rather than purely substantive.

However, the large post/pre RMSPE ratios in ridge specifications should be read cautiously because the pre-fit becomes very tight.

The ridge approach is promising for the pilot, but the next version should ideally:

- implement a more formal Augmented SCM workflow;
- compare ridge results with classic SCM and smoothed classic SCM;
- report coefficient patterns transparently;
- use placebo or cross-fitting diagnostics adapted to the ridge specification.

## Recommendation

Keep three employment specifications in the pilot comparison:

1. classic SCM in levels as the transparent baseline;
2. classic SCM with 6-month moving average or 6-month accumulated flow as the smoothed robustness check;
3. ridge/Augmented SCM as the model-improvement candidate.

The ridge result is currently the best pre-treatment fit, but should not replace the classic SCM without methodological explanation.
