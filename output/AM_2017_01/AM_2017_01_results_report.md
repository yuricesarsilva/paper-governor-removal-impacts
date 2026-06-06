# AM_2017_01 results report (confaz regime)

Generated on 2026-06-06.

Treated state: `AM` (Amazonas). Treatment (single accountability cut): effective removal `2017-05-04`.
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
| Retail volume | 85.90 | 85.90 | 1.57 | 36 |
| Services volume | 82.77 | 82.97 | 1.90 | 36 |
| Formal hiring | -51.64 | -51.64 | 12.33 | 36 |
| Construction | -8.26 | -7.62 | 8.39 | 36 |
| ICMS | 171.56 | 170.14 | 9.96 | 36 |
| Tax revenue | 193.08 | 192.62 | 13.41 | 36 |

### Covariate balance (treated vs synthetic by outcome)

| Covariate | Treated | Retail volume | Services volume | Formal hiring | Construction | ICMS | Tax revenue |
| --- | --- | --- | --- | --- | --- | --- | --- |
| ICMS secondary VA pc | 51.463 | 26.685 |  8.980 | 33.414 | 34.135 | 39.993 | 42.279 |
| ICMS tertiary VA pc | 83.627 | 58.929 | 34.655 | 70.401 | 60.337 | 76.528 | 74.735 |
| ICMS energy VA pc |  4.517 | 12.345 |  6.597 | 11.856 | 13.086 | 10.465 | 10.340 |
| ICMS fuels VA pc | 20.509 | 29.087 | 19.400 | 22.808 | 30.363 | 20.845 | 19.299 |
| FPE transfer pc | 37.524 | 42.864 | 72.128 | 50.609 | 34.019 | 61.828 | 64.749 |
| IOF-state pc |  0.001 |  0.001 |  0.010 |  0.003 |  0.001 |  0.003 |  0.002 |

## Main results: Augmented SCM (SA)

| Channel | Outcome | Mean gap post | RMSPE pre | RMSPE post | Donors | Freq |
| --- | --- | --- | --- | --- | --- | --- |
| Household consumption | Retail volume index (PMC) | 5.28 |  1.57 |  6.99 | 24 | monthly |
| Household consumption | Services volume index (PMS) | 0.24 |  1.90 |  3.17 | 24 | monthly |
| Formal labor market | Formal hiring balance per 100k pop | 4.07 | 12.33 | 23.14 | 24 | monthly |
| Formal labor market | Construction hiring balance per 100k pop | 0.85 |  8.39 |  6.36 | 24 | monthly |
| State public finances | ICMS value added, real per capita (CONFAZ) | 5.98 |  9.96 | 13.78 | 24 | monthly |
| State public finances | Tax revenue value added, real per capita (CONFAZ) | 2.06 | 13.41 | 10.03 | 24 | monthly |

![augmented_effect_summary.png](report/figures/augmented_effect_summary.png)

![augmented_paths_outcomes.png](report/figures/augmented_paths_outcomes.png)

![augmented_gaps_outcomes.png](report/figures/augmented_gaps_outcomes.png)

## Donor weights

![donor_weights_outcomes.png](report/figures/donor_weights_outcomes.png)

## In-space placebos

Each eligible donor is treated as pseudo-treated; p = share of placebos with a post/pre RMSPE ratio (or absolute post gap) at least as large as the treated unit's.

| Outcome | RMSPE ratio (post/pre) | p (ratio) | p (abs gap) | Placebos |
| --- | --- | --- | --- | --- |
| Retail volume | 4.47 | 0.500 | 0.375 | 24 |
| Services volume | 1.67 | 0.792 | 1.000 | 24 |
| Formal hiring | 1.88 | 0.250 | 1.000 | 24 |
| Construction | 0.76 | 0.875 | 1.000 | 24 |
| ICMS | 1.38 | 0.750 | 0.667 | 24 |
| Tax revenue | 0.75 | 1.000 | 1.000 | 24 |

![placebo_gaps_outcomes.png](report/figures/placebo_gaps_outcomes.png)

![placebo_rmspe_ratio_outcomes.png](report/figures/placebo_rmspe_ratio_outcomes.png)

## Leave-one-out donor placebo

| Outcome | Gap post | LOO rank | p (2-sided) |
| --- | --- | --- | --- |
| Retail volume | 5.28 | 1 / 25 | 0.04 |
| Services volume | 0.24 | 24 / 25 | 0.08 |
| Formal hiring | 4.07 | 24 / 25 | 0.08 |
| Construction | 0.85 | 20 / 25 | 0.24 |
| ICMS | 5.98 | 1 / 25 | 0.04 |
| Tax revenue | 2.06 | 2 / 25 | 0.08 |

## Evidence classification (5-criterion AugSCM ruler)

We do not rely on placebo p-value thresholds alone. Each outcome is graded on five criteria — (C1) pre-treatment fit (treated pre-RMSPE vs the donor median, no pre-trend), (C2) substantive magnitude (post gap >= 1 pre-period SD), (C3) persistence (share of post periods keeping the gap's sign), (C4) placebo position (discrete rank/N p <= 0.15), (C5) robustness (>= 80% of leave-one-out variants keep the sign) — into a 0-5 score. Pre-fit is a hard gate: a poor pre-fit makes the effect *non-interpretable* regardless of the rest. Tiers: **strong** (5/5), **moderate** (>=4 with placebo), **suggestive** (>=3 with magnitude or placebo), **weak**, **non-interpretable**. A *considerable* effect is strong/moderate/suggestive.

Considerable effects for this event: **0** of 6 outcomes.

| Outcome | Tier | Score | % effect | Mag (pre-SD) | Persist | Pre-fit | Placebo rank | p (rank/N) | LOO sign |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Retail volume | non-interpretable | 2/5 |   6.4 | 0.77 | 0.88 | C | 13/25 | 0.520 | 1.00 |
| Services volume | non-interpretable | 0/5 |   0.3 | 0.03 | 0.58 | C | 20/25 | 0.800 | 0.04 |
| Formal hiring | weak | 3/5 |  50.6 | 0.11 | 0.62 | A | 7/25 | 0.280 | 0.96 |
| Construction | non-interpretable | 1/5 | -43.7 | 0.12 | 0.54 | C | 22/25 | 0.880 | 0.96 |
| ICMS | non-interpretable | 2/5 |   3.5 | 0.29 | 0.75 | C | 19/25 | 0.760 | 1.00 |
| Tax revenue | non-interpretable | 2/5 |   1.0 | 0.08 | 0.75 | C | 25/25 | 1.000 | 1.00 |

Note: placebo-based inference in synthetic control is discrete and low-resolution with few donors (here the finest p is ~1/N). Results with p slightly above conventional thresholds but a high placebo rank, good pre-fit, substantive magnitude and persistence are read as *suggestive* evidence, not as conventional statistical significance.

