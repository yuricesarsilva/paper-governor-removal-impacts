# TO_2018_01 results report (confaz regime)

Generated on 2026-06-06.

Treated state: `TO` (Tocantins). Treatment (single accountability cut): effective removal `2018-03-22`.
Data regime: **confaz**. All outcomes are monthly (X-13); fiscal outcomes (ICMS, tax revenue) are from CONFAZ.

## Window design

- Monthly outcomes: target 36-month pre (floor 20), 24-month post.
- An outcome enters only if the treated unit meets its pre-window floor and a complete post-window.

Qualifying outcomes: Retail volume, Services volume, Formal hiring, Construction, ICMS, Tax revenue.

## Methodological strategy

Main donor pool excludes `AM`, `RR`, `TO` (any state treated anywhere in the SCM window). Preferred specification uses 24 eligible donors. Augmented SCM is the headline estimator; weights are estimated on the pre-treatment window. Predictors: the full pre-treatment outcome path plus the regime covariates: CONFAZ ICMS sectors (secondary, tertiary, energy, fuels) plus FPE and IOF-state, real per capita.

## Preliminary plots

![preliminary_outcomes.png](report/figures/preliminary_outcomes.png)

## Covariate and pre-treatment balance

### Pre-treatment outcome fit

| Outcome | Treated | Synthetic | RMSPE pre | Pre periods |
| --- | --- | --- | --- | --- |
| Retail volume | 92.57 | 92.60 | 1.87 | 36 |
| Services volume | 97.00 | 96.90 | 3.80 | 36 |
| Formal hiring | -15.54 | -16.18 | 11.80 | 36 |
| Construction | -5.59 | -6.82 | 10.52 | 36 |
| ICMS | 135.87 | 137.01 | 7.18 | 36 |
| Tax revenue | 152.87 | 153.26 | 7.14 | 36 |

### Covariate balance (treated vs synthetic by outcome)

| Covariate | Treated | Retail volume | Services volume | Formal hiring | Construction | ICMS | Tax revenue |
| --- | --- | --- | --- | --- | --- | --- | --- |
| ICMS secondary VA pc |  14.199 | 19.750 | 15.141 | 17.146 |  16.473 | 15.598 |  14.824 |
| ICMS tertiary VA pc |  37.046 | 56.222 | 62.418 | 47.553 |  72.897 | 49.391 |  48.268 |
| ICMS energy VA pc |   9.989 |  9.646 |  8.072 |  7.792 |   8.378 |  8.393 |   8.135 |
| ICMS fuels VA pc |  29.923 | 22.081 | 21.810 | 17.314 |  19.271 | 24.751 |  24.790 |
| FPE transfer pc | 149.357 | 59.455 | 59.948 | 74.870 | 131.449 | 98.034 | 100.653 |
| IOF-state pc |   0.000 |  0.005 |  0.007 |  0.002 |   0.008 |  0.005 |   0.005 |

## Main results: Augmented SCM (SA)

| Channel | Outcome | Mean gap post | RMSPE pre | RMSPE post | Donors | Freq |
| --- | --- | --- | --- | --- | --- | --- |
| Household consumption | Retail volume index (PMC) |  7.09 |  1.87 |  9.31 | 24 | monthly |
| Household consumption | Services volume index (PMS) |  0.97 |  3.80 |  5.74 | 24 | monthly |
| Formal labor market | Formal hiring balance per 100k pop | -7.56 | 11.80 | 19.66 | 24 | monthly |
| Formal labor market | Construction hiring balance per 100k pop | -6.17 | 10.52 | 20.51 | 24 | monthly |
| State public finances | ICMS value added, real per capita (CONFAZ) |  5.38 |  7.18 | 10.36 | 24 | monthly |
| State public finances | Tax revenue value added, real per capita (CONFAZ) |  1.13 |  7.14 | 12.74 | 24 | monthly |

![augmented_effect_summary.png](report/figures/augmented_effect_summary.png)

![augmented_paths_outcomes.png](report/figures/augmented_paths_outcomes.png)

![augmented_gaps_outcomes.png](report/figures/augmented_gaps_outcomes.png)

## Donor weights

![donor_weights_outcomes.png](report/figures/donor_weights_outcomes.png)

## In-space placebos

Each eligible donor is treated as pseudo-treated; p = share of placebos with a post/pre RMSPE ratio (or absolute post gap) at least as large as the treated unit's.

| Outcome | RMSPE ratio (post/pre) | p (ratio) | p (abs gap) | Placebos |
| --- | --- | --- | --- | --- |
| Retail volume | 4.98 | 0.292 | 0.167 | 24 |
| Services volume | 1.51 | 0.792 | 1.000 | 24 |
| Formal hiring | 1.67 | 0.417 | 1.000 | 24 |
| Construction | 1.95 | 0.000 | 0.500 | 24 |
| ICMS | 1.44 | 0.833 | 0.875 | 24 |
| Tax revenue | 1.79 | 0.500 | 1.000 | 24 |

![placebo_gaps_outcomes.png](report/figures/placebo_gaps_outcomes.png)

![placebo_rmspe_ratio_outcomes.png](report/figures/placebo_rmspe_ratio_outcomes.png)

## Leave-one-out donor placebo

| Outcome | Gap post | LOO rank | p (2-sided) |
| --- | --- | --- | --- |
| Retail volume | 7.09 | 24 / 25 | 0.08 |
| Services volume | 0.97 | 25 / 25 | 0.04 |
| Formal hiring | -7.56 | 1 / 25 | 0.04 |
| Construction | -6.17 | 23 / 25 | 0.12 |
| ICMS | 5.38 | 2 / 25 | 0.08 |
| Tax revenue | 1.13 | 2 / 25 | 0.08 |

## Evidence classification (5-criterion AugSCM ruler)

We do not rely on placebo p-value thresholds alone. Each outcome is graded on five criteria — (C1) pre-treatment fit (treated pre-RMSPE vs the donor median, no pre-trend), (C2) substantive magnitude (post gap >= 1 pre-period SD), (C3) persistence (share of post periods keeping the gap's sign), (C4) placebo position (discrete rank/N p <= 0.15), (C5) robustness (>= 80% of leave-one-out variants keep the sign) — into a 0-5 score. Pre-fit is a hard gate: a poor pre-fit makes the effect *non-interpretable* regardless of the rest. Tiers: **strong** (5/5), **moderate** (>=4 with placebo), **suggestive** (>=3 with magnitude or placebo), **weak**, **non-interpretable**. A *considerable* effect is strong/moderate/suggestive.

Considerable effects for this event: **0** of 6 outcomes.

| Outcome | Tier | Score | % effect | Mag (pre-SD) | Persist | Pre-fit | Placebo rank | p (rank/N) | LOO sign |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Retail volume | non-interpretable | 3/5 |    7.6 | 1.48 | 0.92 | D | 8/25 | 0.320 | 1.00 |
| Services volume | non-interpretable | 0/5 |    1.2 | 0.11 | 0.46 | D | 20/25 | 0.800 | 0.08 |
| Formal hiring | weak | 3/5 |  -49.4 | 0.34 | 0.67 | A | 11/25 | 0.440 | 1.00 |
| Construction | non-interpretable | 3/5 | -732.4 | 0.39 | 0.67 | D | 1/25 | 0.040 | 1.00 |
| ICMS | weak | 3/5 |    3.7 | 0.68 | 0.75 | B | 21/25 | 0.840 | 1.00 |
| Tax revenue | weak | 2/5 |    0.7 | 0.13 | 0.58 | B | 13/25 | 0.520 | 0.96 |

Note: placebo-based inference in synthetic control is discrete and low-resolution with few donors (here the finest p is ~1/N). Results with p slightly above conventional thresholds but a high placebo rank, good pre-fit, substantive magnitude and persistence are read as *suggestive* evidence, not as conventional statistical significance.

