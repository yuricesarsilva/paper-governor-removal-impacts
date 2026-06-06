# RJ_2014_01 results report (confaz regime)

Generated on 2026-06-06.

Treated state: `RJ` (Rio de Janeiro). Treatment (single accountability cut): effective removal `2014-04-03`.
Data regime: **confaz**. All outcomes are monthly (X-13); fiscal outcomes (ICMS, tax revenue) are from CONFAZ.

## Window design

- Monthly outcomes: target 36-month pre (floor 20), 24-month post.
- An outcome enters only if the treated unit meets its pre-window floor and a complete post-window.

Qualifying outcomes: Retail volume, Services volume, Formal hiring, Construction, ICMS, Tax revenue.

## Methodological strategy

Main donor pool excludes `RJ` (any state treated anywhere in the SCM window). Preferred specification uses 26 eligible donors. Augmented SCM is the headline estimator; weights are estimated on the pre-treatment window. Predictors: the full pre-treatment outcome path plus the regime covariates: CONFAZ ICMS sectors (secondary, tertiary, energy, fuels) plus FPE and IOF-state, real per capita.

## Preliminary plots

![preliminary_outcomes.png](report/figures/preliminary_outcomes.png)

## Covariate and pre-treatment balance

### Pre-treatment outcome fit

| Outcome | Treated | Synthetic | RMSPE pre | Pre periods |
| --- | --- | --- | --- | --- |
| Retail volume | 105.88 | 105.84 | 0.85 | 36 |
| Services volume | 107.40 | 107.39 | 1.21 | 36 |
| Formal hiring | 53.68 | 51.66 | 19.80 | 36 |
| Construction | 11.67 | 10.52 | 7.52 | 36 |
| ICMS | 162.67 | 162.61 | 6.82 | 36 |
| Tax revenue | 192.50 | 192.48 | 7.04 | 36 |

### Covariate balance (treated vs synthetic by outcome)

| Covariate | Treated | Retail volume | Services volume | Formal hiring | Construction | ICMS | Tax revenue |
| --- | --- | --- | --- | --- | --- | --- | --- |
| ICMS secondary VA pc | 30.496 | 24.467 | 32.991 | 36.398 | 25.038 | 31.103 | 31.660 |
| ICMS tertiary VA pc | 56.860 | 44.313 | 48.279 | 54.681 | 43.161 | 49.846 | 51.312 |
| ICMS energy VA pc | 17.193 | 10.612 | 13.398 | 12.761 | 10.527 | 13.244 | 13.156 |
| ICMS fuels VA pc | 16.401 | 19.117 | 23.923 | 24.044 | 20.112 | 21.544 | 21.150 |
| FPE transfer pc |  3.405 | 37.798 | 19.530 | 17.553 | 25.597 | 19.855 | 18.313 |
| IOF-state pc |  0.000 |  0.003 |  0.001 |  0.001 |  0.002 |  0.000 |  0.000 |

## Main results: Augmented SCM (SA)

| Channel | Outcome | Mean gap post | RMSPE pre | RMSPE post | Donors | Freq |
| --- | --- | --- | --- | --- | --- | --- |
| Household consumption | Retail volume index (PMC) |   4.90 |  0.85 |  5.25 | 26 | monthly |
| Household consumption | Services volume index (PMS) |   0.01 |  1.21 |  1.98 | 26 | monthly |
| Formal labor market | Formal hiring balance per 100k pop |  -0.20 | 19.80 | 27.95 | 26 | monthly |
| Formal labor market | Construction hiring balance per 100k pop |   1.07 |  7.52 | 12.17 | 26 | monthly |
| State public finances | ICMS value added, real per capita (CONFAZ) | -15.12 |  6.82 | 20.22 | 26 | monthly |
| State public finances | Tax revenue value added, real per capita (CONFAZ) | -15.21 |  7.04 | 23.99 | 26 | monthly |

![augmented_effect_summary.png](report/figures/augmented_effect_summary.png)

![augmented_paths_outcomes.png](report/figures/augmented_paths_outcomes.png)

![augmented_gaps_outcomes.png](report/figures/augmented_gaps_outcomes.png)

## Donor weights

![donor_weights_outcomes.png](report/figures/donor_weights_outcomes.png)

## In-space placebos

Each eligible donor is treated as pseudo-treated; p = share of placebos with a post/pre RMSPE ratio (or absolute post gap) at least as large as the treated unit's.

| Outcome | RMSPE ratio (post/pre) | p (ratio) | p (abs gap) | Placebos |
| --- | --- | --- | --- | --- |
| Retail volume | 6.20 | 0.154 | 0.423 | 26 |
| Services volume | 1.63 | 0.885 | 1.000 | 26 |
| Formal hiring | 1.41 | 0.769 | 1.000 | 26 |
| Construction | 1.62 | 0.654 | 1.000 | 26 |
| ICMS | 2.96 | 0.192 | 0.192 | 26 |
| Tax revenue | 3.41 | 0.077 | 0.385 | 26 |

![placebo_gaps_outcomes.png](report/figures/placebo_gaps_outcomes.png)

![placebo_rmspe_ratio_outcomes.png](report/figures/placebo_rmspe_ratio_outcomes.png)

## Leave-one-out donor placebo

| Outcome | Gap post | LOO rank | p (2-sided) |
| --- | --- | --- | --- |
| Retail volume | 4.9 | 27 / 27 | 0.037 |
| Services volume | 0.01 | 1 / 27 | 0.037 |
| Formal hiring | -0.2 | 27 / 27 | 0.037 |
| Construction | 1.07 | 3 / 27 | 0.111 |
| ICMS | -15.12 | 2 / 27 | 0.074 |
| Tax revenue | -15.21 | 1 / 27 | 0.037 |

## Evidence classification (5-criterion AugSCM ruler)

We do not rely on placebo p-value thresholds alone. Each outcome is graded on five criteria — (C1) pre-treatment fit (treated pre-RMSPE vs the donor median, no pre-trend), (C2) substantive magnitude (post gap >= 1 pre-period SD), (C3) persistence (share of post periods keeping the gap's sign), (C4) placebo position (discrete rank/N p <= 0.15), (C5) robustness (>= 80% of leave-one-out variants keep the sign) — into a 0-5 score. Pre-fit is a hard gate: a poor pre-fit makes the effect *non-interpretable* regardless of the rest. Tiers: **strong** (5/5), **moderate** (>=4 with placebo), **suggestive** (>=3 with magnitude or placebo), **weak**, **non-interpretable**. A *considerable* effect is strong/moderate/suggestive.

Considerable effects for this event: **2** of 6 outcomes.

| Outcome | Tier | Score | % effect | Mag (pre-SD) | Persist | Pre-fit | Placebo rank | p (rank/N) | LOO sign |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Retail volume | suggestive | 4/5 |  4.6 | 1.14 | 1.00 | A | 5/27 | 0.185 | 1.00 |
| Services volume | weak | 2/5 |  0.0 | 0.00 | 0.54 | B | 24/27 | 0.889 | 1.00 |
| Formal hiring | weak | 2/5 |  0.4 | 0.01 | 0.50 | B | 21/27 | 0.778 | 1.00 |
| Construction | weak | 2/5 | -9.3 | 0.09 | 0.54 | B | 18/27 | 0.667 | 0.96 |
| ICMS | non-interpretable | 3/5 | -9.0 | 1.54 | 0.92 | C | 6/27 | 0.222 | 1.00 |
| Tax revenue | strong | 5/5 | -7.6 | 1.50 | 0.83 | B | 3/27 | 0.111 | 1.00 |

Note: placebo-based inference in synthetic control is discrete and low-resolution with few donors (here the finest p is ~1/N). Results with p slightly above conventional thresholds but a high placebo rank, good pre-fit, substantive magnitude and persistence are read as *suggestive* evidence, not as conventional statistical significance.

