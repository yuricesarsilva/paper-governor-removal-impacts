# RR_2018_01 results report (siconfi regime)

Generated on 2026-06-06.

Treated state: `RR` (Roraima). Treatment (single accountability cut): effective removal `2018-12-10`.
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
| Retail volume | 94.64 | 94.56 | 2.96 | 36 |
| Services volume | 90.58 | 90.25 | 3.02 | 36 |
| Formal hiring | 5.51 | 0.42 | 20.20 | 36 |
| Construction | 3.48 | 3.66 | 10.08 | 36 |
| ICMS | 299.71 | 296.54 | 28.57 | 23 |
| Tax revenue | 394.18 | 394.29 | 26.17 | 23 |
| Public investment | 63.35 | 65.05 | 23.85 | 23 |
| Total expenditure | 1,735.29 | 1,771.27 | 391.95 | 23 |

### Covariate balance (treated vs synthetic by outcome)

| Covariate | Treated | Retail volume | Services volume | Formal hiring | Construction | ICMS | Tax revenue | Public investment | Total expenditure |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Unemployment rate |     0.089 |     0.105 |     0.107 |     0.097 |     0.095 |     0.103 |     0.100 |     0.102 |     0.099 |
| Formalization rate |     0.562 |     0.576 |     0.574 |     0.534 |     0.565 |     0.501 |     0.494 |     0.559 |     0.529 |
| Labor income (real) | 3,281.611 | 3,589.636 | 3,556.657 | 2,852.995 | 3,217.323 | 2,791.278 | 2,692.594 | 3,227.628 | 3,030.765 |
| Transfer dependency ratio |     0.128 |     0.062 |     0.077 |     0.077 |     0.068 |     0.104 |     0.105 |     0.075 |     0.091 |
| Health expenditure pc |   283.644 |   222.560 |   232.435 |   183.792 |   206.091 |   235.052 |   238.636 |   211.274 |   250.478 |
| Education expenditure pc |   314.191 |   263.021 |   276.752 |   248.274 |   257.802 |   310.427 |   315.385 |   289.870 |   341.560 |
| Public security expenditure pc |   175.100 |   104.136 |   118.191 |   131.165 |   118.752 |   147.333 |   150.140 |   129.959 |   140.021 |

## Main results: Augmented SCM (SA)

| Channel | Outcome | Mean gap post | RMSPE pre | RMSPE post | Donors | Freq |
| --- | --- | --- | --- | --- | --- | --- |
| Household consumption | Retail volume index (PMC) |    8.42 |   2.96 |  10.06 | 22 | monthly |
| Household consumption | Services volume index (PMS) |    2.41 |   3.02 |   5.32 | 22 | monthly |
| Formal labor market | Formal hiring balance per 100k pop |   26.46 |  20.20 |  48.53 | 22 | monthly |
| Formal labor market | Construction hiring balance per 100k pop |    7.81 |  10.08 |  27.00 | 22 | monthly |
| State public finances | ICMS revenue, real per capita (SICONFI) |   68.25 |  28.57 | 308.83 | 21 | bimonthly |
| State public finances | Own tax revenue, real per capita (SICONFI) |  -22.60 |  26.17 |  85.14 | 22 | bimonthly |
| State public finances | Public investment, real per capita (SICONFI) |   -4.22 |  23.85 |  29.22 | 22 | bimonthly |
| State public finances | Total liquidated expenditure, real per capita (SICONFI) | -331.85 | 391.95 | 465.21 | 22 | bimonthly |

![augmented_effect_summary.png](report/figures/augmented_effect_summary.png)

![augmented_paths_outcomes.png](report/figures/augmented_paths_outcomes.png)

![augmented_gaps_outcomes.png](report/figures/augmented_gaps_outcomes.png)

## Donor weights

![donor_weights_outcomes.png](report/figures/donor_weights_outcomes.png)

## In-space placebos

Each eligible donor is treated as pseudo-treated; p = share of placebos with a post/pre RMSPE ratio (or absolute post gap) at least as large as the treated unit's.

| Outcome | RMSPE ratio (post/pre) | p (ratio) | p (abs gap) | Placebos |
| --- | --- | --- | --- | --- |
| Retail volume |  3.40 | 0.727 | 0.227 | 22 |
| Services volume |  1.76 | 0.727 | 0.727 | 22 |
| Formal hiring |  2.40 | 0.409 | 0.545 | 22 |
| Construction |  2.68 | 0.091 | 0.455 | 22 |
| ICMS | 10.81 | 0.000 | 0.238 | 21 |
| Tax revenue |  3.25 | 0.136 | 0.864 | 22 |
| Public investment |  1.23 | 0.773 | 1.000 | 22 |
| Total expenditure |  1.19 | 0.864 | 0.000 | 22 |

![placebo_gaps_outcomes.png](report/figures/placebo_gaps_outcomes.png)

![placebo_rmspe_ratio_outcomes.png](report/figures/placebo_rmspe_ratio_outcomes.png)

## Leave-one-out donor placebo

| Outcome | Gap post | LOO rank | p (2-sided) |
| --- | --- | --- | --- |
| Retail volume | 8.42 | 22 / 23 | 0.087 |
| Services volume | 2.41 | 3 / 23 | 0.13 |
| Formal hiring | 26.46 | 23 / 23 | 0.043 |
| Construction | 7.81 | 4 / 23 | 0.174 |
| ICMS | 68.25 | 21 / 22 | 0.091 |
| Tax revenue | -22.6 | 22 / 23 | 0.087 |
| Public investment | -4.22 | 23 / 23 | 0.043 |
| Total expenditure | -331.85 | 1 / 23 | 0.043 |

## Evidence classification (5-criterion AugSCM ruler)

We do not rely on placebo p-value thresholds alone. Each outcome is graded on five criteria — (C1) pre-treatment fit (treated pre-RMSPE vs the donor median, no pre-trend), (C2) substantive magnitude (post gap >= 1 pre-period SD), (C3) persistence (share of post periods keeping the gap's sign), (C4) placebo position (discrete rank/N p <= 0.15), (C5) robustness (>= 80% of leave-one-out variants keep the sign) — into a 0-5 score. Pre-fit is a hard gate: a poor pre-fit makes the effect *non-interpretable* regardless of the rest. Tiers: **strong** (5/5), **moderate** (>=4 with placebo), **suggestive** (>=3 with magnitude or placebo), **weak**, **non-interpretable**. A *considerable* effect is strong/moderate/suggestive.

Considerable effects for this event: **0** of 8 outcomes.

| Outcome | Tier | Score | % effect | Mag (pre-SD) | Persist | Pre-fit | Placebo rank | p (rank/N) | LOO sign |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Retail volume | non-interpretable | 3/5 |   9.1 | 1.85 | 0.96 | D | 17/23 | 0.739 | 1.00 |
| Services volume | non-interpretable | 2/5 |   3.0 | 0.36 | 0.67 | D | 17/23 | 0.739 | 1.00 |
| Formal hiring | non-interpretable | 2/5 | 506.8 | 0.98 | 0.75 | C | 10/23 | 0.435 | 1.00 |
| Construction | non-interpretable | 3/5 | 435.9 | 0.52 | 0.67 | D | 3/23 | 0.130 | 1.00 |
| ICMS | non-interpretable | 3/5 |  23.7 | 1.16 | 0.50 | D | 1/22 | 0.045 | 1.00 |
| Tax revenue | weak | 2/5 |  -5.5 | 0.37 | 0.58 | B | 4/23 | 0.174 | 1.00 |
| Public investment | non-interpretable | 1/5 | -10.8 | 0.18 | 0.58 | D | 18/23 | 0.783 | 1.00 |
| Total expenditure | non-interpretable | 2/5 | -20.5 | 0.67 | 0.83 | D | 20/23 | 0.870 | 1.00 |

Note: placebo-based inference in synthetic control is discrete and low-resolution with few donors (here the finest p is ~1/N). Results with p slightly above conventional thresholds but a high placebo rank, good pre-fit, substantive magnitude and persistence are read as *suggestive* evidence, not as conventional statistical significance.

