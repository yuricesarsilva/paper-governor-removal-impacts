# TO_2021_01 results report (siconfi regime)

Generated on 2026-06-07.

Treated state: `TO` (Tocantins). Treatment (single accountability cut): effective removal `2021-10-20`.
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
| Retail volume | 107.55 | 106.98 | 7.55 | 36 |
| Services volume | 79.56 | 79.26 | 4.58 | 36 |
| Formal hiring | 32.17 | 30.49 | 33.42 | 36 |
| Construction | 1.88 | 3.26 | 24.23 | 36 |
| ICMS | 5.69 | 5.69 | 0.12 | 24 |
| Tax revenue | 6.09 | 6.11 | 0.13 | 24 |
| Public investment | 3.39 | 3.40 | 0.36 | 24 |
| Total expenditure | 7.14 | 7.14 | 0.08 | 24 |

### Covariate balance (treated vs synthetic by outcome)

| Covariate | Treated | Retail volume | Services volume | Formal hiring | Construction | ICMS | Tax revenue | Public investment | Total expenditure |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Unemployment rate |     0.102 |     0.124 |     0.124 |     0.109 |     0.109 |     0.108 |     0.104 |     0.109 |     0.108 |
| Formalization rate |     0.556 |     0.529 |     0.527 |     0.537 |     0.507 |     0.520 |     0.529 |     0.538 |     0.540 |
| Labor income (real) | 2,659.377 | 3,023.385 | 2,993.827 | 2,844.088 | 2,524.134 | 2,811.240 | 2,803.029 | 2,840.459 | 2,856.134 |
| Transfer dependency ratio |     0.255 |     0.208 |     0.225 |     0.235 |     0.222 |     0.248 |     0.245 |     0.231 |     0.243 |
| Health expenditure pc |   251.799 |   182.145 |   182.573 |   214.859 |   132.340 |   196.241 |   208.020 |   197.502 |   216.441 |
| Education expenditure pc |   181.093 |   195.182 |   225.105 |   258.335 |   173.352 |   228.258 |   231.160 |   225.587 |   239.813 |
| Public security expenditure pc |   139.965 |   106.898 |   139.130 |   130.630 |    96.330 |   132.078 |   127.221 |   134.686 |   127.747 |

## Main results: Augmented SCM (SA)

| Channel | Outcome | Mean gap post | RMSPE pre | RMSPE post | Donors | Freq |
| --- | --- | --- | --- | --- | --- | --- |
| Household consumption | Retail volume index (PMC, SA level) |  4.16 |  7.55 |  6.38 | 22 | monthly |
| Household consumption | Services volume index (PMS, SA level) |  2.80 |  4.58 |  5.48 | 22 | monthly |
| Formal labor market | Formal hiring balance per 100k pop |  3.92 | 33.42 | 31.24 | 22 | monthly |
| Formal labor market | Construction hiring balance per 100k pop | -7.42 | 24.23 | 16.11 | 22 | monthly |
| State public finances | ICMS revenue, log real per capita (SICONFI) | -0.01 |  0.12 |  0.06 | 20 | bimonthly |
| State public finances | Own tax revenue, log real per capita (SICONFI) | -0.07 |  0.13 |  0.10 | 22 | bimonthly |
| State public finances | Public investment, log real per capita (SICONFI) |  0.04 |  0.36 |  0.37 | 21 | bimonthly |
| State public finances | Total liquidated expenditure, log real per capita (SICONFI) | -0.01 |  0.08 |  0.08 | 22 | bimonthly |

![augmented_effect_summary.png](report/figures/augmented_effect_summary.png)

![augmented_paths_outcomes.png](report/figures/augmented_paths_outcomes.png)

![augmented_gaps_outcomes.png](report/figures/augmented_gaps_outcomes.png)

## Donor weights

![donor_weights_outcomes.png](report/figures/donor_weights_outcomes.png)

## In-space placebos

Each eligible donor is treated as pseudo-treated; p = share of placebos with a post/pre RMSPE ratio (or absolute post gap) at least as large as the treated unit's.

| Outcome | RMSPE ratio (post/pre) | p (ratio) | p (abs gap) | Placebos |
| --- | --- | --- | --- | --- |
| Retail volume | 0.84 | 0.409 | 0.045 | 22 |
| Services volume | 1.20 | 0.500 | 0.500 | 22 |
| Formal hiring | 0.93 | 0.636 | 1.000 | 22 |
| Construction | 0.66 | 1.000 | 0.727 | 22 |
| ICMS | 0.45 | 1.000 | 1.000 | 21 |
| Tax revenue | 0.79 | 0.864 | 0.909 | 22 |
| Public investment | 1.02 | 0.818 | 1.000 | 22 |
| Total expenditure | 1.07 | 0.636 | 1.000 | 22 |

![placebo_gaps_outcomes.png](report/figures/placebo_gaps_outcomes.png)

![placebo_rmspe_ratio_outcomes.png](report/figures/placebo_rmspe_ratio_outcomes.png)

## Leave-one-out donor placebo

| Outcome | Gap post | LOO rank | p (2-sided) |
| --- | --- | --- | --- |
| Retail volume | 4.16 | 2 / 23 | 0.087 |
| Services volume | 2.8 | 2 / 23 | 0.087 |
| Formal hiring | 3.92 | 20 / 23 | 0.174 |
| Construction | -7.42 | 19 / 23 | 0.217 |
| ICMS | -0.01 | 4 / 21 | 0.19 |
| Tax revenue | -0.07 | 4 / 23 | 0.174 |
| Public investment | 0.04 | 2 / 22 | 0.091 |
| Total expenditure | -0.01 | 1 / 23 | 0.043 |

## Evidence classification

Inference follows the standard placebo approach (Abadie, Diamond & Hainmueller 2010): the tier is the treated unit's position in the placebo distribution of the post/pre RMSPE ratio (discrete p = rank/N), which already self-normalises for pre-treatment fit. To rise above *weak* an effect must also be substantively large (|post gap| >= 1 pre-period SD) and free of a pre-trend. Tiers: **strong** (placebo p <= 0.05), **moderate** (<= 0.10), **suggestive** (<= 0.15), **weak** otherwise; a *considerable* effect is strong/moderate/suggestive. Persistence and leave-one-out sign-stability are reported as supporting robustness.

**Pre-treatment fit quality is reported, not used to discard results.** The SCM literature has no fixed fit threshold (fit is judged visually and relative to the effect), so we show the treated pre-RMSPE percentile class (A-D), the treated-vs-synthetic pre correlation and R^2, and flag poor-fit cases (⚠) for the reader rather than labelling them non-interpretable.

Considerable effects for this event: **0** of 8 outcomes.

| Outcome | Tier | Effect | Placebo p | Rank | Mag (pre-SD) | Persist | LOO sign | Pre-trend p | Pre-fit | Pre corr | Pre R2 | ⚠fit |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Retail volume | weak | +4.1% | 0.435 | 10/23 | 0.60 | 0.75 | 1.00 | 0.92 | D | 0.51 | -0.20 | yes |
| Services volume | weak | +2.8% | 0.522 | 12/23 | 0.44 | 0.67 | 1.00 | 0.56 | D | 0.73 |  0.48 | yes |
| Formal hiring | weak | +3.9 | 0.652 | 15/23 | 0.06 | 0.54 | 1.00 | 0.27 | B | 0.85 |  0.71 |  |
| Construction | weak | -7.4 | 1.000 | 23/23 | 0.37 | 0.75 | 1.00 | 0.75 | D | 0.39 | -0.47 | yes |
| ICMS | weak | -0.9% | 1.000 | 22/22 | 0.10 | 0.58 | 0.85 | 0.82 | C | 0.43 | -0.52 | yes |
| Tax revenue | weak | -6.4% | 0.870 | 20/23 | 0.54 | 0.75 | 0.95 | 0.76 | C | 0.38 | -0.08 | yes |
| Public investment | weak | +3.9% | 0.826 | 19/23 | 0.06 | 0.58 | 1.00 | 0.76 | B | 0.83 |  0.69 |  |
| Total expenditure | weak | -0.8% | 0.652 | 15/23 | 0.12 | 0.75 | 0.00 | 0.96 | A | 0.16 | -0.23 | yes |

Note: placebo inference in synthetic control is discrete and low-resolution with few donors (finest p ~ 1/N). A p slightly above the conventional threshold with a high placebo rank, good fit and a substantive, persistent gap is read as *suggestive*, not as conventional significance.

