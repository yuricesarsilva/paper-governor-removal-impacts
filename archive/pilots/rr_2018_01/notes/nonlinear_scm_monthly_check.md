# Nonlinear SCM Monthly Check

This note records a first Tian-style nonlinear synthetic-control robustness check for the `RR_2018_01` monthly outcomes.

## Script

Script:

- `pilots/rr_2018_01/code/09_run_nonlinear_scm.R`

Output folder:

- `pilots/rr_2018_01/output/nonlinear_scm_monthly/`
- `pilots/rr_2018_01/output/nonlinear_scm_monthly_employment_per_100k/`

## Method

This check estimates affine synthetic controls with elastic-net style regularization:

- donor weights sum to one;
- donor weights are allowed to be negative;
- L1 regularization penalizes donor weights by predictor distance from RR;
- L2 regularization shrinks the donor-weight vector;
- tuning parameters are selected by leave-one-control-out cross-validation;
- uncertainty bands use donor leave-one-out residual variation in the spirit of Doudchenko-Imbens inference.

The moving-average outcomes use the post-treatment-clean 6-month moving average, so the first post-treatment smoothed months do not carry pre-treatment information.

Because the Doudchenko-Imbens variance estimator is sensitive to scale differences across donor units, employment is also rerun as `formal_hiring_balance_per_100k`, using PNADc population as the denominator.

## Results

| Outcome | a* | b* | Pre RMSPE | Post RMSPE | ATT | 95% CI | p-value | Negative weight sum |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `formal_hiring_balance` | 0.0 | 0.2 | 296.4 | 608.0 | -87.5 | [-3029.8, 2854.8] | 0.954 | 0.36 |
| `formal_hiring_balance_ma6_post_clean` | 0.0 | 0.0 | 34.1 | 322.3 | 105.5 | [-2716.6, 2927.5] | 0.942 | 0.72 |
| `retail_volume_index` | 0.0 | 0.1 | 2.43 | 14.30 | -8.54 | [-11.09, -6.00] | <0.001 | 4.73 |
| `retail_volume_index_ma6_post_clean` | 0.0 | 0.1 | 0.35 | 19.80 | -10.80 | [-12.66, -8.95] | <0.001 | 8.73 |
| `services_volume_index` | 0.0 | 0.0 | 1.86 | 17.27 | -14.45 | [-17.11, -11.79] | <0.001 | 5.47 |
| `services_volume_index_ma6_post_clean` | 0.0 | 0.0 | 0.30 | 16.54 | -14.35 | [-17.60, -11.11] | <0.001 | 7.16 |

## Interpretation

The test is useful because it produces confidence intervals and strongly improves pre-treatment fit relative to classic SCM for some outcomes.

However, the activity outcomes rely on substantial extrapolation. The negative-weight sums are large for retail and services, especially in the smoothed versions. These estimates should therefore be treated as inferential robustness diagnostics, not as the main specification.

The employment results are less extrapolative, but the uncertainty intervals are very wide and include zero. Under this check, employment is not statistically distinguishable from zero.

Substantively, the nonlinear SCM check strengthens the negative activity result, especially services, but it also shows why the Augmented SCM hierarchy should remain the main interpretation framework.

## Plotting Note

The `*_gap_ci.png` figures include pointwise confidence bands. For employment, these bands are extremely wide, so the y-axis can visually flatten the actual monthly gap line. Use the companion `*_gap.png` figures, without the confidence ribbon, to inspect whether `RR - Nonlinear SCM` matches the treated-versus-synthetic path visually.

## Employment Per 100k Check

| Outcome | a* | b* | Pre RMSPE | Post RMSPE | ATT | 95% CI | p-value | Negative weight sum |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `formal_hiring_balance_per_100k` | 0.0 | 0.0 | 28.25 | 112.81 | 28.76 | [-13.64, 71.15] | 0.184 | 2.96 |
| `formal_hiring_balance_per_100k_ma6_post_clean` | 0.0 | 0.0 | 5.50 | 55.42 | 11.57 | [-21.23, 44.36] | 0.489 | 3.68 |

Normalizing employment by population makes the confidence intervals much more interpretable. The employment ATT remains statistically indistinguishable from zero under this NSC check, and the estimated sign becomes positive rather than negative. This reinforces the view that the NSC evidence for employment is weak and sensitive, while the stronger NSC evidence is concentrated in retail and services.
