# Activity Ridge Synthetic Control Check

This note records ridge-regularized synthetic control checks for the two non-employment monthly economic outcomes in the `RR_2018_01` pilot.

## Script

Script:

- `pilots/rr_2018_01/code/07_run_activity_ridge_scm.R`

Output folder:

- `pilots/rr_2018_01/output/activity_ridge_scm/`

## Outcomes Tested

- `retail_volume_index`
- `retail_volume_index_ma6`
- `services_volume_index`
- `services_volume_index_ma6`

The `_ma6` variables are trailing 6-month moving averages constructed within each UF.

## Results

| Outcome | Pre RMSPE | Post RMSPE | Post/pre RMSPE | Lambda |
| --- | ---: | ---: | ---: | ---: |
| `retail_volume_index` | 3.85 | 9.60 | 2.50 | 20.72 |
| `retail_volume_index_ma6` | 0.24 | 13.61 | 56.63 | 0.008 |
| `services_volume_index` | 1.55 | 5.98 | 3.85 | 0.63 |
| `services_volume_index_ma6` | 0.18 | 4.62 | 25.68 | 0.014 |

Compared with classic SCM:

- Retail level pre RMSPE falls from 5.10 to 3.85.
- Services level pre RMSPE falls from 6.20 to 1.55.
- Moving-average versions produce extremely tight pre-treatment fits.

## Coefficient Pattern

The ridge fits use both positive and negative coefficients.

Examples:

- Retail level: moderate coefficients, with positive weights for `DF`, `RJ`, and `GO`, and negative coefficients for `SC` and `AP`.
- Retail 6-month moving average: large positive and negative coefficients, including negative coefficients for `RS`, `PA`, and `BA`.
- Services level: large negative coefficient for `AL`, positive coefficients for `PB`, `GO`, `SP`, `SC`, and `DF`.
- Services 6-month moving average: mixed signs, including negative coefficients for `AL`, `PA`, and `AP`.

This is useful diagnostically, but less interpretable than classic SCM donor weights.

## Interpretation

Ridge improves pre-treatment fit for both retail and services, especially for services.

The moving-average ridge specifications fit the pre-treatment path very closely, but the very small pre RMSPE mechanically inflates the post/pre RMSPE ratio. These should be inspected visually and interpreted cautiously.

There is an important sign difference for retail:

- Classic SCM in levels gives a negative average post-treatment retail gap: RR is below synthetic RR.
- Ridge in levels gives a positive average post-treatment retail gap: RR is above ridge synthetic RR.

This sign reversal suggests that the retail ridge specification is extrapolating rather than simply improving the classic SCM fit. The ridge counterfactual for retail is substantially lower in the post-treatment period, especially in `2019` and `2020`. Because the ridge model uses negative and unconstrained coefficients, this should not be treated as a robust substantive result without additional checks.

Services is more stable across methods:

- Classic SCM gives a negative services gap.
- Ridge in levels also gives a negative services gap.
- Ridge with a 6-month moving average gives a negative services gap.

For the pilot comparison:

- keep classic SCM as the transparent baseline;
- keep ridge level specifications as model-improvement candidates;
- treat ridge moving-average specifications as high-fit diagnostics rather than immediate main specifications;
- treat the retail ridge sign reversal as a warning flag, not as evidence of a positive retail effect.

## Next Step

The next methodological step is to decide whether to formalize the ridge approach as an Augmented SCM family for all monthly outcomes, with a clear section explaining:

- why classic SCM fit is weak;
- how ridge improves pre-fit;
- why coefficients can be negative;
- how inference/placebo diagnostics should be adapted.
