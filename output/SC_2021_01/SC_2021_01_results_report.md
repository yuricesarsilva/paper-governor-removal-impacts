# SC_2021_01 results report (siconfi regime)

Generated on 2026-06-07.

Treated state: `SC` (Santa Catarina). Treatment (single accountability cut): effective removal `2021-03-30`.
Data regime: **siconfi**. Fiscal outcomes (ICMS, tax revenue, public investment, total expenditure) are bimonthly from SICONFI/RREO (STL). Non-fiscal outcomes (retail, services, formal hiring, construction) are monthly (X-13).

## Window design

- Monthly outcomes: target 36-month pre (floor 20), 24-month post.
- Bimonthly (SICONFI) outcomes: target 24-bimester pre (floor 21), 12-bimester post.
- An outcome enters only if the treated unit meets its pre-window floor and a complete post-window.

Qualifying outcomes: Retail volume, Services volume, Formal hiring, Construction, ICMS, Tax revenue, Public investment, Total expenditure.

## Methodological strategy

Main donor pool excludes `AL`, `AM`, `RJ`, `RR`, `SC`, `TO` (any state treated anywhere in the SCM window). Preferred specification uses 21 eligible donors. Augmented SCM is the headline estimator; weights are estimated on the pre-treatment window. Predictors: the full pre-treatment outcome path plus the regime covariates: PNADc labor covariates (unemployment, formalization, labor income) plus SICONFI transfer dependency and health/education/public-security expenditure per capita.

## Preliminary plots

![preliminary_outcomes.png](report/figures/preliminary_outcomes.png)

## Covariate and pre-treatment balance

### Pre-treatment outcome fit

| Outcome | Treated | Synthetic | RMSPE pre | Pre periods |
| --- | --- | --- | --- | --- |
| Retail volume | 91.92 | 91.38 | 3.91 | 36 |
| Services volume | 85.08 | 85.43 | 3.03 | 36 |
| Formal hiring | 68.29 | 57.82 | 92.75 | 36 |
| Construction | 3.04 | 3.37 | 8.27 | 36 |
| ICMS | 6.12 | 6.15 | 0.08 | 24 |
| Tax revenue | 6.37 | 6.41 | 0.08 | 24 |
| Public investment | 3.56 | 3.59 | 0.49 | 24 |
| Total expenditure | 6.77 | 6.82 | 0.16 | 24 |

### Covariate balance (treated vs synthetic by outcome)

| Covariate | Treated | Retail volume | Services volume | Formal hiring | Construction | ICMS | Tax revenue | Public investment | Total expenditure |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Unemployment rate |     0.051 |     0.071 |     0.076 |     0.072 |     0.072 |     0.071 |     0.072 |     0.078 |     0.076 |
| Formalization rate |     0.731 |     0.663 |     0.649 |     0.653 |     0.651 |     0.649 |     0.655 |     0.655 |     0.658 |
| Labor income (real) | 3,585.959 | 3,516.405 | 3,464.513 | 3,498.443 | 3,477.345 | 3,410.969 | 3,456.212 | 3,594.509 | 3,491.119 |
| Transfer dependency ratio |     0.052 |     0.065 |     0.066 |     0.069 |     0.079 |     0.067 |     0.067 |     0.068 |     0.075 |
| Health expenditure pc |   113.240 |   112.460 |   109.912 |   107.179 |   117.784 |   102.286 |   112.088 |   112.310 |   116.981 |
| Education expenditure pc |   116.976 |   156.758 |   151.028 |   202.793 |   163.695 |   177.712 |   147.975 |   196.236 |   167.127 |
| Public security expenditure pc |    80.385 |    91.155 |   102.155 |   100.229 |    88.990 |    98.421 |    96.277 |    99.632 |    85.623 |

## Main results: Augmented SCM (SA)

| Channel | Outcome | Mean gap post | RMSPE pre | RMSPE post | Donors | Freq |
| --- | --- | --- | --- | --- | --- | --- |
| Household consumption | Retail volume index (PMC, SA level) |  0.95 |  3.91 |  3.03 | 21 | monthly |
| Household consumption | Services volume index (PMS, SA level) |  0.55 |  3.03 |  4.73 | 21 | monthly |
| Formal labor market | Formal hiring balance per 100k pop | -7.96 | 92.75 | 46.96 | 21 | monthly |
| Formal labor market | Construction hiring balance per 100k pop |  8.81 |  8.27 | 11.44 | 21 | monthly |
| State public finances | ICMS revenue, log real per capita (SICONFI) | -0.03 |  0.08 |  0.10 | 19 | bimonthly |
| State public finances | Own tax revenue, log real per capita (SICONFI) |  0.01 |  0.08 |  0.08 | 21 | bimonthly |
| State public finances | Public investment, log real per capita (SICONFI) |  0.09 |  0.49 |  0.60 | 20 | bimonthly |
| State public finances | Total liquidated expenditure, log real per capita (SICONFI) |  0.14 |  0.16 |  0.17 | 20 | bimonthly |

![augmented_effect_summary.png](report/figures/augmented_effect_summary.png)

![augmented_paths_outcomes.png](report/figures/augmented_paths_outcomes.png)

![augmented_gaps_outcomes.png](report/figures/augmented_gaps_outcomes.png)

## Donor weights

![donor_weights_outcomes.png](report/figures/donor_weights_outcomes.png)

## In-space placebos

Each eligible donor is treated as pseudo-treated; p = share of placebos with a post/pre RMSPE ratio (or absolute post gap) at least as large as the treated unit's.

| Outcome | RMSPE ratio (post/pre) | p (ratio) | p (abs gap) | Placebos |
| --- | --- | --- | --- | --- |
| Retail volume | 0.77 | 0.762 | 1.000 | 21 |
| Services volume | 1.56 | 0.238 | 1.000 | 21 |
| Formal hiring | 0.51 | 0.952 | 1.000 | 21 |
| Construction | 1.38 | 0.238 | 0.381 | 21 |
| ICMS | 1.25 | 0.500 | 1.000 | 20 |
| Tax revenue | 0.96 | 0.667 | 1.000 | 21 |
| Public investment | 1.23 | 0.667 | 1.000 | 21 |
| Total expenditure | 1.08 | 0.429 | 0.333 | 21 |

![placebo_gaps_outcomes.png](report/figures/placebo_gaps_outcomes.png)

![placebo_rmspe_ratio_outcomes.png](report/figures/placebo_rmspe_ratio_outcomes.png)

## Leave-one-out donor placebo

| Outcome | Gap post | LOO rank | p (2-sided) |
| --- | --- | --- | --- |
| Retail volume | 0.95 | 1 / 22 | 0.045 |
| Services volume | 0.55 | 21 / 22 | 0.091 |
| Formal hiring | -7.96 | 1 / 22 | 0.045 |
| Construction | 8.81 | 22 / 22 | 0.045 |
| ICMS | -0.03 | 2 / 20 | 0.1 |
| Tax revenue | 0.01 | 2 / 22 | 0.091 |
| Public investment | 0.09 | 2 / 21 | 0.095 |
| Total expenditure | 0.14 | 21 / 21 | 0.048 |

## Evidence classification

Inference follows the standard placebo approach (Abadie, Diamond & Hainmueller 2010): the tier is the treated unit's position in the placebo distribution of the post/pre RMSPE ratio (discrete p = rank/N), which already self-normalises for pre-treatment fit. To rise above *weak* an effect must also be substantively large (|post gap| >= 1 pre-period SD) and free of a pre-trend. Tiers: **strong** (placebo p <= 0.05), **moderate** (<= 0.10), **suggestive** (<= 0.15), **weak** otherwise; a *considerable* effect is strong/moderate/suggestive. Persistence and leave-one-out sign-stability are reported as supporting robustness.

**Pre-treatment fit quality is reported, not used to discard results.** The SCM literature has no fixed fit threshold (fit is judged visually and relative to the effect), so we show the treated pre-RMSPE percentile class (A-D), the treated-vs-synthetic pre correlation and R^2, and flag poor-fit cases (⚠) for the reader rather than labelling them non-interpretable.

Considerable effects for this event: **0** of 8 outcomes.

| Outcome | Tier | Effect | Placebo p | Rank | Mag (pre-SD) | Persist | LOO sign | Pre-trend p | Pre-fit | Pre corr | Pre R2 | ⚠fit |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Retail volume | weak | +1.0% | 0.773 | 17/22 | 0.16 | 0.71 | 1.00 | 0.07 | C | 0.76 |  0.55 |  |
| Services volume | weak | +0.6% | 0.273 | 6/22 | 0.13 | 0.58 | 0.14 | 0.37 | C | 0.79 |  0.51 |  |
| Formal hiring | weak | -8.0 | 0.955 | 21/22 | 0.04 | 0.62 | 0.05 | 0.67 | D | 0.94 |  0.81 | yes |
| Construction | weak | +8.8 | 0.273 | 6/22 | 0.67 | 0.83 | 1.00 | 0.60 | B | 0.77 |  0.61 |  |
| ICMS | weak | -3.4% | 0.524 | 11/21 | 0.40 | 0.75 | 0.89 | 0.25 | B | 0.49 |  0.08 | yes |
| Tax revenue | weak | +0.8% | 0.682 | 15/22 | 0.10 | 0.50 | 0.95 | 0.39 | B | 0.67 |  0.04 |  |
| Public investment | weak | +9.1% | 0.682 | 15/22 | 0.22 | 0.58 | 1.00 | 0.76 | C | 0.22 | -0.51 | yes |
| Total expenditure | weak | +14.7% | 0.455 | 10/22 | 1.09 | 0.83 | 1.00 | 0.74 | C | 0.10 | -0.60 | yes |

Note: placebo inference in synthetic control is discrete and low-resolution with few donors (finest p ~ 1/N). A p slightly above the conventional threshold with a high placebo rank, good fit and a substantive, persistent gap is read as *suggestive*, not as conventional significance.

