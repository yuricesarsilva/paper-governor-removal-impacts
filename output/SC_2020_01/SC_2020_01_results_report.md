# SC_2020_01 results report (siconfi regime)

Generated on 2026-06-06.

Treated state: `SC` (Santa Catarina). Treatment (single accountability cut): effective removal `2020-10-24`.
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
| Retail volume | 112.48 | 112.35 | 1.34 | 36 |
| Services volume | 101.88 | 101.76 | 1.66 | 36 |
| Formal hiring | 35.31 | 38.75 | 55.62 | 36 |
| Construction | 2.09 | 2.55 | 4.02 | 36 |
| ICMS | 447.55 | 446.28 | 17.53 | 24 |
| Tax revenue | 573.72 | 577.21 | 24.20 | 24 |
| Public investment | 50.71 | 50.57 | 14.02 | 24 |
| Total expenditure | 909.90 | 912.28 | 84.92 | 24 |

### Covariate balance (treated vs synthetic by outcome)

| Covariate | Treated | Retail volume | Services volume | Formal hiring | Construction | ICMS | Tax revenue | Public investment | Total expenditure |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Unemployment rate |     0.051 |     0.098 |     0.087 |     0.070 |     0.093 |     0.073 |     0.075 |     0.087 |     0.081 |
| Formalization rate |     0.731 |     0.490 |     0.666 |     0.661 |     0.648 |     0.634 |     0.631 |     0.620 |     0.630 |
| Labor income (real) | 3,573.200 | 2,675.035 | 3,768.548 | 3,539.297 | 3,588.465 | 3,308.608 | 3,290.345 | 3,445.794 | 3,309.300 |
| Transfer dependency ratio |     0.046 |     0.140 |     0.057 |     0.058 |     0.061 |     0.065 |     0.068 |     0.089 |     0.095 |
| Health expenditure pc |   111.891 |   121.239 |   121.636 |   103.415 |   114.103 |   108.763 |   115.416 |   133.681 |   119.629 |
| Education expenditure pc |   116.595 |   119.932 |   151.000 |   211.609 |   160.980 |   165.517 |   151.110 |   199.640 |   160.621 |
| Public security expenditure pc |    80.820 |    92.293 |    85.808 |    89.293 |   102.584 |   104.127 |   104.327 |   106.780 |    85.863 |

## Main results: Augmented SCM (SA)

| Channel | Outcome | Mean gap post | RMSPE pre | RMSPE post | Donors | Freq |
| --- | --- | --- | --- | --- | --- | --- |
| Household consumption | Retail volume index (PMC) |  -7.22 |  1.34 |   9.32 | 22 | monthly |
| Household consumption | Services volume index (PMS) |   3.02 |  1.66 |   5.14 | 22 | monthly |
| Formal labor market | Formal hiring balance per 100k pop |  16.17 | 55.62 |  51.29 | 22 | monthly |
| Formal labor market | Construction hiring balance per 100k pop |   3.13 |  4.02 |   8.03 | 22 | monthly |
| State public finances | ICMS revenue, real per capita (SICONFI) | -11.57 | 17.53 |  49.95 | 21 | bimonthly |
| State public finances | Own tax revenue, real per capita (SICONFI) |  -5.12 | 24.20 |  45.58 | 22 | bimonthly |
| State public finances | Public investment, real per capita (SICONFI) |   3.25 | 14.02 |  27.50 | 22 | bimonthly |
| State public finances | Total liquidated expenditure, real per capita (SICONFI) | 128.72 | 84.92 | 159.35 | 22 | bimonthly |

![augmented_effect_summary.png](report/figures/augmented_effect_summary.png)

![augmented_paths_outcomes.png](report/figures/augmented_paths_outcomes.png)

![augmented_gaps_outcomes.png](report/figures/augmented_gaps_outcomes.png)

## Donor weights

![donor_weights_outcomes.png](report/figures/donor_weights_outcomes.png)

## In-space placebos

Each eligible donor is treated as pseudo-treated; p = share of placebos with a post/pre RMSPE ratio (or absolute post gap) at least as large as the treated unit's.

| Outcome | RMSPE ratio (post/pre) | p (ratio) | p (abs gap) | Placebos |
| --- | --- | --- | --- | --- |
| Retail volume | 6.93 | 0.045 | 0.318 | 22 |
| Services volume | 3.09 | 0.727 | 0.818 | 22 |
| Formal hiring | 0.92 | 0.864 | 1.000 | 22 |
| Construction | 2.00 | 0.136 | 1.000 | 22 |
| ICMS | 2.85 | 0.381 | 0.857 | 21 |
| Tax revenue | 1.88 | 0.636 | 1.000 | 22 |
| Public investment | 1.96 | 1.000 | 1.000 | 22 |
| Total expenditure | 1.88 | 0.455 | 0.318 | 22 |

![placebo_gaps_outcomes.png](report/figures/placebo_gaps_outcomes.png)

![placebo_rmspe_ratio_outcomes.png](report/figures/placebo_rmspe_ratio_outcomes.png)

## Leave-one-out donor placebo

| Outcome | Gap post | LOO rank | p (2-sided) |
| --- | --- | --- | --- |
| Retail volume | -7.22 | 1 / 23 | 0.043 |
| Services volume | 3.02 | 1 / 23 | 0.043 |
| Formal hiring | 16.17 | 1 / 23 | 0.043 |
| Construction | 3.13 | 14 / 23 | 0.435 |
| ICMS | -11.57 | 3 / 22 | 0.136 |
| Tax revenue | -5.12 | 5 / 23 | 0.217 |
| Public investment | 3.25 | 22 / 23 | 0.087 |
| Total expenditure | 128.72 | 23 / 23 | 0.043 |

## Evidence classification (5-criterion AugSCM ruler)

We do not rely on placebo p-value thresholds alone. Each outcome is graded on five criteria — (C1) pre-treatment fit (treated pre-RMSPE vs the donor median, no pre-trend), (C2) substantive magnitude (post gap >= 1 pre-period SD), (C3) persistence (share of post periods keeping the gap's sign), (C4) placebo position (discrete rank/N p <= 0.15), (C5) robustness (>= 80% of leave-one-out variants keep the sign) — into a 0-5 score. Pre-fit is a hard gate: a poor pre-fit makes the effect *non-interpretable* regardless of the rest. Tiers: **strong** (5/5), **moderate** (>=4 with placebo), **suggestive** (>=3 with magnitude or placebo), **weak**, **non-interpretable**. A *considerable* effect is strong/moderate/suggestive.

Considerable effects for this event: **1** of 8 outcomes.

| Outcome | Tier | Score | % effect | Mag (pre-SD) | Persist | Pre-fit | Placebo rank | p (rank/N) | LOO sign |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Retail volume | moderate | 4/5 | -5.5 | 0.96 | 0.88 | B | 2/23 | 0.087 | 1.00 |
| Services volume | non-interpretable | 2/5 |  2.7 | 0.69 | 0.83 | C | 17/23 | 0.739 | 1.00 |
| Formal hiring | non-interpretable | 2/5 |  9.7 | 0.08 | 0.62 | D | 20/23 | 0.870 | 1.00 |
| Construction | weak | 3/5 | 26.5 | 0.21 | 0.71 | A | 4/23 | 0.174 | 1.00 |
| ICMS | weak | 1/5 | -2.1 | 0.33 | 0.58 | B | 9/22 | 0.409 | 0.24 |
| Tax revenue | weak | 1/5 | -0.7 | 0.12 | 0.42 | B | 15/23 | 0.652 | 0.77 |
| Public investment | non-interpretable | 0/5 |  4.6 | 0.14 | 0.58 | D | 23/23 | 1.000 | 0.05 |
| Total expenditure | non-interpretable | 2/5 | 16.2 | 0.71 | 0.92 | C | 11/23 | 0.478 | 0.95 |

Note: placebo-based inference in synthetic control is discrete and low-resolution with few donors (here the finest p is ~1/N). Results with p slightly above conventional thresholds but a high placebo rank, good pre-fit, substantive magnitude and persistence are read as *suggestive* evidence, not as conventional statistical significance.

