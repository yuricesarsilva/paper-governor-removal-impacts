# RR_2004_01 results report (confaz regime)

Generated on 2026-06-06.

Treated state: `RR` (Roraima). Treatment (single accountability cut): effective removal `2004-11-10`.
Data regime: **confaz**. All outcomes are monthly (X-13); fiscal outcomes (ICMS, tax revenue) are from CONFAZ.

## Window design

- Monthly outcomes: target 36-month pre (floor 20), 24-month post.
- An outcome enters only if the treated unit meets its pre-window floor and a complete post-window.

Qualifying outcomes: Retail volume, ICMS, Tax revenue.

## Methodological strategy

Main donor pool excludes `PI`, `RR` (any state treated anywhere in the SCM window). Preferred specification uses 25 eligible donors. Augmented SCM is the headline estimator; weights are estimated on the pre-treatment window. Predictors: the full pre-treatment outcome path plus the regime covariates: CONFAZ ICMS sectors (secondary, tertiary, energy, fuels) plus FPE and IOF-state, real per capita.

## Preliminary plots

![preliminary_outcomes.png](report/figures/preliminary_outcomes.png)

## Covariate and pre-treatment balance

### Pre-treatment outcome fit

| Outcome | Treated | Synthetic | RMSPE pre | Pre periods |
| --- | --- | --- | --- | --- |
| Retail volume | 90.11 | 90.08 | 3.37 | 36 |
| ICMS | 35.15 | 34.99 | 3.49 | 36 |
| Tax revenue | 38.63 | 38.11 | 5.27 | 36 |

### Covariate balance (treated vs synthetic by outcome)

| Covariate | Treated | Retail volume | ICMS | Tax revenue |
| --- | --- | --- | --- | --- |
| ICMS secondary VA pc |   2.915 |  5.445 |  2.422 |  2.384 |
| ICMS tertiary VA pc |  17.299 | 37.681 | 24.173 | 24.385 |
| ICMS energy VA pc |   1.220 |  1.893 |  2.061 |  2.048 |
| ICMS fuels VA pc |   9.265 |  3.022 |  7.815 |  7.793 |
| FPE transfer pc | 120.770 | 33.229 | 73.779 | 74.011 |
| IOF-state pc |   0.004 |  0.000 |  0.007 |  0.007 |

## Main results: Augmented SCM (SA)

| Channel | Outcome | Mean gap post | RMSPE pre | RMSPE post | Donors | Freq |
| --- | --- | --- | --- | --- | --- | --- |
| Household consumption | Retail volume index (PMC) | -7.95 | 3.37 | 15.12 | 25 | monthly |
| State public finances | ICMS value added, real per capita (CONFAZ) |  0.88 | 3.49 |  2.48 | 25 | monthly |
| State public finances | Tax revenue value added, real per capita (CONFAZ) |  4.82 | 5.27 |  6.22 | 25 | monthly |

![augmented_effect_summary.png](report/figures/augmented_effect_summary.png)

![augmented_paths_outcomes.png](report/figures/augmented_paths_outcomes.png)

![augmented_gaps_outcomes.png](report/figures/augmented_gaps_outcomes.png)

## Donor weights

![donor_weights_outcomes.png](report/figures/donor_weights_outcomes.png)

## In-space placebos

Each eligible donor is treated as pseudo-treated; p = share of placebos with a post/pre RMSPE ratio (or absolute post gap) at least as large as the treated unit's.

| Outcome | RMSPE ratio (post/pre) | p (ratio) | p (abs gap) | Placebos |
| --- | --- | --- | --- | --- |
| Retail volume | 4.49 | 0.600 | 0.480 | 25 |
| ICMS | 0.71 | 0.960 | 1.000 | 25 |
| Tax revenue | 1.18 | 0.840 | 0.560 | 25 |

![placebo_gaps_outcomes.png](report/figures/placebo_gaps_outcomes.png)

![placebo_rmspe_ratio_outcomes.png](report/figures/placebo_rmspe_ratio_outcomes.png)

## Leave-one-out donor placebo

| Outcome | Gap post | LOO rank | p (2-sided) |
| --- | --- | --- | --- |
| Retail volume | -7.95 | 26 / 26 | 0.038 |
| ICMS | 0.88 | 26 / 26 | 0.038 |
| Tax revenue | 4.82 | 26 / 26 | 0.038 |

## Evidence classification (5-criterion AugSCM ruler)

We do not rely on placebo p-value thresholds alone. Each outcome is graded on five criteria — (C1) pre-treatment fit (treated pre-RMSPE vs the donor median, no pre-trend), (C2) substantive magnitude (post gap >= 1 pre-period SD), (C3) persistence (share of post periods keeping the gap's sign), (C4) placebo position (discrete rank/N p <= 0.15), (C5) robustness (>= 80% of leave-one-out variants keep the sign) — into a 0-5 score. Pre-fit is a hard gate: a poor pre-fit makes the effect *non-interpretable* regardless of the rest. Tiers: **strong** (5/5), **moderate** (>=4 with placebo), **suggestive** (>=3 with magnitude or placebo), **weak**, **non-interpretable**. A *considerable* effect is strong/moderate/suggestive.

Considerable effects for this event: **0** of 3 outcomes.

| Outcome | Tier | Score | % effect | Mag (pre-SD) | Persist | Pre-fit | Placebo rank | p (rank/N) | LOO sign |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Retail volume | non-interpretable | 2/5 | -7.6 | 0.81 | 0.67 | D | 16/26 | 0.615 | 1.00 |
| ICMS | non-interpretable | 1/5 |  2.3 | 0.34 | 0.71 | C | 25/26 | 0.962 | 0.00 |
| Tax revenue | non-interpretable | 2/5 | 11.8 | 0.83 | 0.92 | C | 22/26 | 0.846 | 1.00 |

Note: placebo-based inference in synthetic control is discrete and low-resolution with few donors (here the finest p is ~1/N). Results with p slightly above conventional thresholds but a high placebo rank, good pre-fit, substantive magnitude and persistence are read as *suggestive* evidence, not as conventional statistical significance.

