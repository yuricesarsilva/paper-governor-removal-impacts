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

## Evidence classification (5-criterion AugSCM ruler)

We do not rely on placebo p-value thresholds alone. Each outcome is graded on five criteria — (C1) pre-treatment fit (treated pre-RMSPE vs the donor median, no pre-trend), (C2) substantive magnitude (post gap >= 1 pre-period SD), (C3) persistence (share of post periods keeping the gap's sign), (C4) placebo position (discrete rank/N p <= 0.15), (C5) robustness (>= 80% of leave-one-out variants keep the sign) — into a 0-5 score. Pre-fit is a hard gate: a poor pre-fit makes the effect *non-interpretable* regardless of the rest. Tiers: **strong** (5/5), **moderate** (>=4 with placebo), **suggestive** (>=3 with magnitude or placebo), **weak**, **non-interpretable**. A *considerable* effect is strong/moderate/suggestive.

Considerable effects for this event: **0** of 8 outcomes.

| Outcome | Tier | Score | Effect | Mag (pre-SD) | Persist | Pre-fit | Placebo rank | p (rank/N) | LOO sign |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Retail volume | weak | 3/5 | +2.8% | 0.72 | 0.83 | B | 9/23 | 0.391 | 1.00 |
| Services volume | non-interpretable | 2/5 | +1.4% | 0.26 | 0.71 | D | 23/23 | 1.000 | 1.00 |
| Formal hiring | weak | 3/5 | -15.4 | 0.16 | 0.62 | C | 9/23 | 0.391 | 1.00 |
| Construction | weak | 3/5 | -2.6 | 0.22 | 0.67 | C | 22/23 | 0.957 | 0.95 |
| ICMS | non-interpretable | 1/5 | +4.6% | 0.32 | 0.75 | D | 19/22 | 0.864 | 0.00 |
| Tax revenue | weak | 3/5 | -6.3% | 0.77 | 0.75 | C | 14/23 | 0.609 | 1.00 |
| Public investment | weak | 3/5 | -44.7% | 0.83 | 1.00 | C | 11/23 | 0.478 | 1.00 |
| Total expenditure | non-interpretable | 1/5 | -1.3% | 0.09 | 0.50 | D | 22/23 | 0.957 | 1.00 |

Note: placebo-based inference in synthetic control is discrete and low-resolution with few donors (here the finest p is ~1/N). Results with p slightly above conventional thresholds but a high placebo rank, good pre-fit, substantive magnitude and persistence are read as *suggestive* evidence, not as conventional statistical significance.

