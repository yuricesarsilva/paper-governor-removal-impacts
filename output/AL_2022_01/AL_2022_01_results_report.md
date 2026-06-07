# AL_2022_01 results report (siconfi regime)

Generated on 2026-06-07.

Treated state: `AL` (Alagoas). Treatment (single accountability cut): effective removal `2022-10-11`.
Data regime: **siconfi**. Fiscal outcomes (ICMS, tax revenue, public investment, total expenditure) are bimonthly from SICONFI/RREO (STL). Non-fiscal outcomes (retail, services, formal hiring, construction) are monthly (X-13).

## Window design

- Monthly outcomes: target 36-month pre (floor 20), 24-month post.
- Bimonthly (SICONFI) outcomes: target 24-bimester pre (floor 21), 12-bimester post.
- An outcome enters only if the treated unit meets its pre-window floor and a complete post-window.

Qualifying outcomes: Retail volume, Services volume, Formal hiring, Construction, ICMS, Tax revenue, Public investment, Total expenditure.

## Methodological strategy

Main donor pool excludes `AL`, `RJ`, `RR`, `SC`, `TO` (any state treated anywhere in the SCM window). Preferred specification uses 22 eligible donors. Augmented SCM is the headline estimator; weights are estimated on the pre-treatment window. Predictors: the full pre-treatment outcome path plus the regime covariates: PNADc labor covariates (unemployment, formalization, labor income) plus SICONFI transfer dependency and health/education/public-security expenditure per capita.

## Preliminary plots

![preliminary_outcomes.png](report/figures/preliminary_outcomes.png)

## Covariate and pre-treatment balance

### Pre-treatment outcome fit

| Outcome | Treated | Synthetic | RMSPE pre | Pre periods |
| --- | --- | --- | --- | --- |
| Retail volume | 95.45 | 95.74 | 2.83 | 36 |
| Services volume | 84.19 | 84.35 | 3.20 | 36 |
| Formal hiring | 43.79 | 39.40 | 59.80 | 36 |
| Construction | 6.66 | 6.28 | 9.49 | 36 |
| ICMS | 5.38 | 5.39 | 0.05 | 24 |
| Tax revenue | 5.63 | 5.64 | 0.07 | 24 |
| Public investment | 4.03 | 4.01 | 0.41 | 24 |
| Total expenditure | 6.55 | 6.56 | 0.17 | 24 |

### Covariate balance (treated vs synthetic by outcome)

| Covariate | Treated | Retail volume | Services volume | Formal hiring | Construction | ICMS | Tax revenue | Public investment | Total expenditure |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Unemployment rate |     0.142 |     0.121 |     0.129 |     0.134 |     0.128 |     0.132 |     0.131 |     0.129 |     0.132 |
| Formalization rate |     0.535 |     0.525 |     0.501 |     0.477 |     0.498 |     0.500 |     0.483 |     0.489 |     0.493 |
| Labor income (real) | 2,135.720 | 2,515.089 | 2,553.921 | 2,296.003 | 2,398.743 | 2,351.856 | 2,282.095 | 2,399.108 | 2,277.004 |
| Transfer dependency ratio |     0.257 |     0.237 |     0.227 |     0.216 |     0.229 |     0.257 |     0.263 |     0.195 |     0.241 |
| Health expenditure pc |   102.459 |   116.845 |   144.563 |   126.959 |   114.095 |   112.333 |   110.338 |   134.185 |   104.832 |
| Education expenditure pc |    75.090 |   110.655 |   152.445 |   136.978 |   110.591 |   102.397 |   101.105 |    95.433 |   102.062 |
| Public security expenditure pc |    87.756 |    76.846 |    99.188 |    83.600 |    78.039 |    80.505 |    79.234 |    70.736 |    72.041 |

## Main results: Augmented SCM (SA)

| Channel | Outcome | Mean gap post | RMSPE pre | RMSPE post | Donors | Freq |
| --- | --- | --- | --- | --- | --- | --- |
| Household consumption | Retail volume index (PMC, SA level) |  2.22 |  2.83 |  2.92 | 22 | monthly |
| Household consumption | Services volume index (PMS, SA level) |  0.36 |  3.20 |  3.08 | 22 | monthly |
| Formal labor market | Formal hiring balance per 100k pop |  9.68 | 59.80 | 96.09 | 22 | monthly |
| Formal labor market | Construction hiring balance per 100k pop | -2.16 |  9.49 |  6.40 | 22 | monthly |
| State public finances | ICMS revenue, log real per capita (SICONFI) |  0.11 |  0.05 |  0.15 | 21 | bimonthly |
| State public finances | Own tax revenue, log real per capita (SICONFI) |  0.06 |  0.07 |  0.10 | 22 | bimonthly |
| State public finances | Public investment, log real per capita (SICONFI) | -0.41 |  0.41 |  0.59 | 21 | bimonthly |
| State public finances | Total liquidated expenditure, log real per capita (SICONFI) |  0.00 |  0.17 |  0.06 | 22 | bimonthly |

![augmented_effect_summary.png](report/figures/augmented_effect_summary.png)

![augmented_paths_outcomes.png](report/figures/augmented_paths_outcomes.png)

![augmented_gaps_outcomes.png](report/figures/augmented_gaps_outcomes.png)

## Donor weights

![donor_weights_outcomes.png](report/figures/donor_weights_outcomes.png)

## In-space placebos

Each eligible donor is treated as pseudo-treated; p = share of placebos with a post/pre RMSPE ratio (or absolute post gap) at least as large as the treated unit's.

| Outcome | RMSPE ratio (post/pre) | p (ratio) | p (abs gap) | Placebos |
| --- | --- | --- | --- | --- |
| Retail volume | 1.03 | 0.409 | 0.591 | 22 |
| Services volume | 0.96 | 0.864 | 1.000 | 22 |
| Formal hiring | 1.61 | 0.045 | 1.000 | 22 |
| Construction | 0.67 | 0.955 | 1.000 | 22 |
| ICMS | 3.12 | 0.000 | 0.409 | 22 |
| Tax revenue | 1.30 | 0.273 | 0.864 | 22 |
| Public investment | 1.42 | 0.318 | 0.636 | 22 |
| Total expenditure | 0.37 | 1.000 | 1.000 | 22 |

![placebo_gaps_outcomes.png](report/figures/placebo_gaps_outcomes.png)

![placebo_rmspe_ratio_outcomes.png](report/figures/placebo_rmspe_ratio_outcomes.png)

## Leave-one-out donor placebo

| Outcome | Gap post | LOO rank | p (2-sided) |
| --- | --- | --- | --- |
| Retail volume | 2.22 | 6 / 23 | 0.261 |
| Services volume | 0.36 | 22 / 23 | 0.087 |
| Formal hiring | 9.68 | 23 / 23 | 0.043 |
| Construction | -2.16 | 19 / 23 | 0.217 |
| ICMS | 0.11 | 21 / 22 | 0.091 |
| Tax revenue | 0.06 | 23 / 23 | 0.043 |
| Public investment | -0.41 | 1 / 22 | 0.045 |
| Total expenditure | 0 | 1 / 23 | 0.043 |

## Evidence classification

Inference follows the standard placebo approach (Abadie, Diamond & Hainmueller 2010): the tier is the treated unit's position in the placebo distribution of the post/pre RMSPE ratio (discrete p = rank/N), which already self-normalises for pre-treatment fit. To rise above *weak* an effect must also be substantively large (|post gap| >= 1 pre-period SD) and free of a pre-trend. Tiers: **strong** (placebo p <= 0.05), **moderate** (<= 0.10), **suggestive** (<= 0.15), **weak** otherwise; a *considerable* effect is strong/moderate/suggestive. Persistence and leave-one-out sign-stability are reported as supporting robustness.

**Pre-treatment fit quality is reported, not used to discard results.** The SCM literature has no fixed fit threshold (fit is judged visually and relative to the effect), so we show the treated pre-RMSPE percentile class (A-D), the treated-vs-synthetic pre correlation and R^2, and flag poor-fit cases (⚠) for the reader rather than labelling them non-interpretable.

Considerable effects for this event: **1** of 8 outcomes.

| Outcome | Tier | Effect | Placebo p | Rank | Mag (pre-SD) | Persist | LOO sign | Pre-trend p | Pre-fit | Pre corr | Pre R2 | ⚠fit |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Retail volume | weak | +2.2% | 0.435 | 10/23 | 0.37 | 0.88 | 0.95 | 0.95 | B | 0.88 | 0.78 |  |
| Services volume | weak | +0.4% | 0.870 | 20/23 | 0.03 | 0.62 | 0.05 | 0.78 | C | 0.97 | 0.94 |  |
| Formal hiring | weak | +9.7 | 0.087 | 2/23 | 0.15 | 0.67 | 0.95 | 0.73 | D | 0.57 | 0.14 | yes |
| Construction | weak | -2.2 | 0.957 | 22/23 | 0.21 | 0.67 | 0.91 | 0.50 | C | 0.60 | 0.11 |  |
| ICMS | strong | +11.1% | 0.043 | 1/23 | 1.01 | 0.83 | 1.00 | 0.28 | A | 0.90 | 0.79 |  |
| Tax revenue | weak | +6.4% | 0.304 | 7/23 | 0.64 | 0.75 | 0.82 | 0.97 | B | 0.81 | 0.41 |  |
| Public investment | weak | -33.9% | 0.348 | 8/23 | 0.66 | 0.83 | 1.00 | 0.98 | B | 0.75 | 0.57 |  |
| Total expenditure | weak | +0.2% | 1.000 | 23/23 | 0.01 | 0.58 | 1.00 | 0.75 | C | 0.47 | 0.06 | yes |

Note: placebo inference in synthetic control is discrete and low-resolution with few donors (finest p ~ 1/N). A p slightly above the conventional threshold with a high placebo rank, good fit and a substantive, persistent gap is read as *suggestive*, not as conventional significance.

