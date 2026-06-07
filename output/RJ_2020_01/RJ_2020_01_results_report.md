# RJ_2020_01 results report (siconfi regime)

Generated on 2026-06-07.

Treated state: `RJ` (Rio de Janeiro). Treatment (single accountability cut): effective removal `2020-08-28`.
Data regime: **siconfi**. Fiscal outcomes (ICMS, tax revenue, public investment, total expenditure) are bimonthly from SICONFI/RREO (STL). Non-fiscal outcomes (retail, services, formal hiring, construction) are monthly (X-13).

## Window design

- Monthly outcomes: target 36-month pre (floor 20), 24-month post.
- Bimonthly (SICONFI) outcomes: target 24-bimester pre (floor 21), 12-bimester post.
- An outcome enters only if the treated unit meets its pre-window floor and a complete post-window.

Qualifying outcomes: Retail volume, Services volume, Formal hiring, Construction, ICMS, Tax revenue, Public investment, Total expenditure.

## Methodological strategy

Main donor pool excludes `AM`, `RJ`, `RR`, `SC`, `TO` (any state treated anywhere in the SCM window). Preferred specification uses 22 eligible donors. Augmented SCM is the headline estimator; weights are estimated on the pre-treatment window. Predictors: the full pre-treatment outcome path plus the regime covariates: PNADc labor covariates (unemployment, formalization, labor income) plus SICONFI transfer dependency and health/education/public-security expenditure per capita.

## Preliminary plots

![preliminary_outcomes.png](report/figures/preliminary_outcomes.png)

## Covariate and pre-treatment balance

### Pre-treatment outcome fit

| Outcome | Treated | Synthetic | RMSPE pre | Pre periods |
| --- | --- | --- | --- | --- |
| Retail volume | 102.04 | 102.00 | 2.44 | 36 |
| Services volume | 95.66 | 95.69 | 4.27 | 36 |
| Formal hiring | -34.33 | -28.17 | 38.16 | 36 |
| Construction | -3.58 | -2.28 | 8.94 | 36 |
| ICMS | 5.84 | 5.85 | 0.16 | 24 |
| Tax revenue | 6.22 | 6.23 | 0.12 | 24 |
| Public investment | 2.17 | 2.30 | 0.56 | 24 |
| Total expenditure | 6.74 | 6.76 | 0.22 | 24 |

### Covariate balance (treated vs synthetic by outcome)

| Covariate | Treated | Retail volume | Services volume | Formal hiring | Construction | ICMS | Tax revenue | Public investment | Total expenditure |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Unemployment rate |     0.112 |     0.098 |     0.096 |     0.090 |     0.102 |     0.099 |     0.106 |     0.093 |     0.101 |
| Formalization rate |     0.646 |     0.598 |     0.605 |     0.630 |     0.585 |     0.592 |     0.611 |     0.620 |     0.606 |
| Labor income (real) | 3,655.680 | 3,092.991 | 3,188.468 | 3,459.518 | 3,110.795 | 2,890.250 | 2,978.968 | 3,046.114 | 2,945.568 |
| Transfer dependency ratio |     0.029 |     0.059 |     0.078 |     0.094 |     0.078 |     0.076 |     0.074 |     0.044 |     0.067 |
| Health expenditure pc |    84.448 |   118.556 |   118.585 |   142.961 |   113.612 |   105.734 |    92.694 |    94.242 |    95.773 |
| Education expenditure pc |    96.298 |   143.379 |   166.667 |   151.817 |   141.972 |   128.172 |   115.451 |   110.995 |   124.813 |
| Public security expenditure pc |   140.290 |   119.134 |   112.837 |   103.716 |    97.988 |   135.846 |   134.497 |   154.949 |   141.717 |

## Main results: Augmented SCM (SA)

| Channel | Outcome | Mean gap post | RMSPE pre | RMSPE post | Donors | Freq |
| --- | --- | --- | --- | --- | --- | --- |
| Household consumption | Retail volume index (PMC, SA level) |   2.82 |  2.44 |  3.97 | 22 | monthly |
| Household consumption | Services volume index (PMS, SA level) |   1.36 |  4.27 |  2.92 | 22 | monthly |
| Formal labor market | Formal hiring balance per 100k pop | -15.43 | 38.16 | 44.55 | 22 | monthly |
| Formal labor market | Construction hiring balance per 100k pop |  -2.63 |  8.94 |  6.54 | 22 | monthly |
| State public finances | ICMS revenue, log real per capita (SICONFI) |   0.05 |  0.16 |  0.09 | 20 | bimonthly |
| State public finances | Own tax revenue, log real per capita (SICONFI) |  -0.06 |  0.12 |  0.11 | 22 | bimonthly |
| State public finances | Public investment, log real per capita (SICONFI) |  -0.59 |  0.56 |  0.75 | 22 | bimonthly |
| State public finances | Total liquidated expenditure, log real per capita (SICONFI) |  -0.01 |  0.22 |  0.11 | 21 | bimonthly |

![augmented_effect_summary.png](report/figures/augmented_effect_summary.png)

![augmented_paths_outcomes.png](report/figures/augmented_paths_outcomes.png)

![augmented_gaps_outcomes.png](report/figures/augmented_gaps_outcomes.png)

## Donor weights

![donor_weights_outcomes.png](report/figures/donor_weights_outcomes.png)

## In-space placebos

Each eligible donor is treated as pseudo-treated; p = share of placebos with a post/pre RMSPE ratio (or absolute post gap) at least as large as the treated unit's.

| Outcome | RMSPE ratio (post/pre) | p (ratio) | p (abs gap) | Placebos |
| --- | --- | --- | --- | --- |
| Retail volume | 1.62 | 0.364 | 0.636 | 22 |
| Services volume | 0.68 | 1.000 | 1.000 | 22 |
| Formal hiring | 1.17 | 0.364 | 1.000 | 22 |
| Construction | 0.73 | 0.955 | 1.000 | 22 |
| ICMS | 0.54 | 0.857 | 0.952 | 21 |
| Tax revenue | 0.88 | 0.591 | 0.773 | 22 |
| Public investment | 1.34 | 0.455 | 0.409 | 22 |
| Total expenditure | 0.49 | 0.955 | 1.000 | 22 |

![placebo_gaps_outcomes.png](report/figures/placebo_gaps_outcomes.png)

![placebo_rmspe_ratio_outcomes.png](report/figures/placebo_rmspe_ratio_outcomes.png)

## Leave-one-out donor placebo

| Outcome | Gap post | LOO rank | p (2-sided) |
| --- | --- | --- | --- |
| Retail volume | 2.82 | 1 / 23 | 0.043 |
| Services volume | 1.36 | 2 / 23 | 0.087 |
| Formal hiring | -15.43 | 6 / 23 | 0.261 |
| Construction | -2.63 | 17 / 23 | 0.304 |
| ICMS | 0.05 | 21 / 21 | 0.048 |
| Tax revenue | -0.06 | 23 / 23 | 0.043 |
| Public investment | -0.59 | 23 / 23 | 0.043 |
| Total expenditure | -0.01 | 22 / 22 | 0.045 |

## Evidence classification

Inference follows the standard placebo approach (Abadie, Diamond & Hainmueller 2010): the tier is the treated unit's position in the placebo distribution of the post/pre RMSPE ratio (discrete p = rank/N), which already self-normalises for pre-treatment fit. To rise above *weak* an effect must also be substantively large (|post gap| >= 1 pre-period SD) and free of a pre-trend. Tiers: **strong** (placebo p <= 0.05), **moderate** (<= 0.10), **suggestive** (<= 0.15), **weak** otherwise; a *considerable* effect is strong/moderate/suggestive. Persistence and leave-one-out sign-stability are reported as supporting robustness.

**Pre-treatment fit quality is reported, not used to discard results.** The SCM literature has no fixed fit threshold (fit is judged visually and relative to the effect), so we show the treated pre-RMSPE percentile class (A-D), the treated-vs-synthetic pre correlation and R^2, and flag poor-fit cases (⚠) for the reader rather than labelling them non-interpretable.

Considerable effects for this event: **0** of 8 outcomes.

| Outcome | Tier | Effect | Placebo p | Rank | Mag (pre-SD) | Persist | LOO sign | Pre-trend p | Pre-fit | Pre corr | Pre R2 | ⚠fit |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Retail volume | weak | +2.8% | 0.391 | 9/23 | 0.72 | 0.83 | 1.00 | 0.97 | B |  0.78 |  0.61 |  |
| Services volume | weak | +1.4% | 1.000 | 23/23 | 0.26 | 0.71 | 1.00 | 0.53 | D |  0.66 |  0.33 | yes |
| Formal hiring | weak | -15.4 | 0.391 | 9/23 | 0.16 | 0.62 | 1.00 | 0.52 | C |  0.95 |  0.84 |  |
| Construction | weak | -2.6 | 0.957 | 22/23 | 0.22 | 0.67 | 0.95 | 0.52 | C |  0.74 |  0.44 |  |
| ICMS | weak | +4.6% | 0.864 | 19/22 | 0.32 | 0.75 | 0.00 | 0.84 | D |  0.49 | -0.33 | yes |
| Tax revenue | weak | -6.3% | 0.609 | 14/23 | 0.77 | 0.75 | 1.00 | 0.96 | C |  0.24 | -1.08 | yes |
| Public investment | weak | -44.7% | 0.478 | 11/23 | 0.83 | 1.00 | 1.00 | 0.93 | C |  0.62 |  0.38 |  |
| Total expenditure | weak | -1.3% | 0.957 | 22/23 | 0.09 | 0.50 | 1.00 | 0.64 | D | -0.38 | -1.30 | yes |

Note: placebo inference in synthetic control is discrete and low-resolution with few donors (finest p ~ 1/N). A p slightly above the conventional threshold with a high placebo rank, good fit and a substantive, persistent gap is read as *suggestive*, not as conventional significance.

