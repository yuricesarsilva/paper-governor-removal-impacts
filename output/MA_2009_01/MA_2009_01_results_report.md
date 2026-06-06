# MA_2009_01 results report (confaz regime)

Generated on 2026-06-06.

Treated state: `MA` (Maranhao). Treatment (single accountability cut): effective removal `2009-04-17`.
Data regime: **confaz**. All outcomes are monthly (X-13); fiscal outcomes (ICMS, tax revenue) are from CONFAZ.

## Window design

- Monthly outcomes: target 36-month pre (floor 20), 24-month post.
- An outcome enters only if the treated unit meets its pre-window floor and a complete post-window.

Qualifying outcomes: Retail volume, Formal hiring, Construction, ICMS, Tax revenue.

## Methodological strategy

Main donor pool excludes `DF`, `MA`, `PB`, `TO` (any state treated anywhere in the SCM window). Preferred specification uses 23 eligible donors. Augmented SCM is the headline estimator; weights are estimated on the pre-treatment window. Predictors: the full pre-treatment outcome path plus the regime covariates: CONFAZ ICMS sectors (secondary, tertiary, energy, fuels) plus FPE and IOF-state, real per capita.

## Preliminary plots

![preliminary_outcomes.png](report/figures/preliminary_outcomes.png)

## Covariate and pre-treatment balance

### Pre-treatment outcome fit

| Outcome | Treated | Synthetic | RMSPE pre | Pre periods |
| --- | --- | --- | --- | --- |
| Retail volume | 121.61 | 121.59 | 1.67 | 36 |
| Formal hiring | 20.35 | 20.78 | 9.96 | 27 |
| Construction | 6.74 | 7.30 | 4.82 | 27 |
| ICMS | 30.39 | 30.39 | 1.12 | 36 |
| Tax revenue | 32.96 | 33.02 | 1.06 | 36 |

### Covariate balance (treated vs synthetic by outcome)

| Covariate | Treated | Retail volume | Formal hiring | Construction | ICMS | Tax revenue |
| --- | --- | --- | --- | --- | --- | --- |
| ICMS secondary VA pc |  3.244 |  8.484 |  8.057 |  4.995 |  3.463 |  3.463 |
| ICMS tertiary VA pc |  7.933 | 23.479 | 19.740 | 16.055 | 13.813 | 13.813 |
| ICMS energy VA pc |  1.724 |  3.652 |  3.187 |  3.083 |  2.738 |  2.738 |
| ICMS fuels VA pc |  5.212 |  5.140 |  7.469 |  5.718 |  6.184 |  6.184 |
| FPE transfer pc | 27.446 | 32.601 | 29.908 | 32.322 | 33.015 | 33.015 |
| IOF-state pc |  0.000 |  0.001 |  0.000 |  0.001 |  0.000 |  0.000 |

## Main results: Augmented SCM (SA)

| Channel | Outcome | Mean gap post | RMSPE pre | RMSPE post | Donors | Freq |
| --- | --- | --- | --- | --- | --- | --- |
| Household consumption | Retail volume index (PMC) |   2.50 | 1.67 |  7.35 | 23 | monthly |
| Formal labor market | Formal hiring balance per 100k pop | -14.98 | 9.96 | 35.31 | 23 | monthly |
| Formal labor market | Construction hiring balance per 100k pop |  -6.48 | 4.82 | 15.75 | 23 | monthly |
| State public finances | ICMS value added, real per capita (CONFAZ) |  -5.51 | 1.12 |  6.24 | 23 | monthly |
| State public finances | Tax revenue value added, real per capita (CONFAZ) |  -4.64 | 1.06 |  5.69 | 23 | monthly |

![augmented_effect_summary.png](report/figures/augmented_effect_summary.png)

![augmented_paths_outcomes.png](report/figures/augmented_paths_outcomes.png)

![augmented_gaps_outcomes.png](report/figures/augmented_gaps_outcomes.png)

## Donor weights

![donor_weights_outcomes.png](report/figures/donor_weights_outcomes.png)

## In-space placebos

Each eligible donor is treated as pseudo-treated; p = share of placebos with a post/pre RMSPE ratio (or absolute post gap) at least as large as the treated unit's.

| Outcome | RMSPE ratio (post/pre) | p (ratio) | p (abs gap) | Placebos |
| --- | --- | --- | --- | --- |
| Retail volume | 4.39 | 0.217 | 0.826 | 23 |
| Formal hiring | 3.55 | 0.043 | 0.957 | 23 |
| Construction | 3.26 | 0.435 | 0.870 | 23 |
| ICMS | 5.55 | 0.000 | 0.696 | 23 |
| Tax revenue | 5.39 | 0.087 | 0.826 | 23 |

![placebo_gaps_outcomes.png](report/figures/placebo_gaps_outcomes.png)

![placebo_rmspe_ratio_outcomes.png](report/figures/placebo_rmspe_ratio_outcomes.png)

## Leave-one-out donor placebo

| Outcome | Gap post | LOO rank | p (2-sided) |
| --- | --- | --- | --- |
| Retail volume | 2.5 | 4 / 24 | 0.167 |
| Formal hiring | -14.98 | 24 / 24 | 0.042 |
| Construction | -6.48 | 24 / 24 | 0.042 |
| ICMS | -5.51 | 24 / 24 | 0.042 |
| Tax revenue | -4.64 | 24 / 24 | 0.042 |

## Evidence classification (5-criterion AugSCM ruler)

We do not rely on placebo p-value thresholds alone. Each outcome is graded on five criteria — (C1) pre-treatment fit (treated pre-RMSPE vs the donor median, no pre-trend), (C2) substantive magnitude (post gap >= 1 pre-period SD), (C3) persistence (share of post periods keeping the gap's sign), (C4) placebo position (discrete rank/N p <= 0.15), (C5) robustness (>= 80% of leave-one-out variants keep the sign) — into a 0-5 score. Pre-fit is a hard gate: a poor pre-fit makes the effect *non-interpretable* regardless of the rest. Tiers: **strong** (5/5), **moderate** (>=4 with placebo), **suggestive** (>=3 with magnitude or placebo), **weak**, **non-interpretable**. A *considerable* effect is strong/moderate/suggestive.

Considerable effects for this event: **3** of 5 outcomes.

| Outcome | Tier | Score | % effect | Mag (pre-SD) | Persist | Pre-fit | Placebo rank | p (rank/N) | LOO sign |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Retail volume | weak | 2/5 |    1.7 | 0.23 | 0.54 | B | 6/24 | 0.250 | 1.00 |
| Formal hiring | moderate | 4/5 |  -48.8 | 0.75 | 0.75 | A | 2/24 | 0.083 | 1.00 |
| Construction | weak | 3/5 | -175.5 | 0.72 | 0.75 | B | 11/24 | 0.458 | 1.00 |
| ICMS | strong | 5/5 |  -13.8 | 2.58 | 1.00 | A | 1/24 | 0.042 | 1.00 |
| Tax revenue | strong | 5/5 |  -10.9 | 1.86 | 0.96 | A | 3/24 | 0.125 | 1.00 |

Note: placebo-based inference in synthetic control is discrete and low-resolution with few donors (here the finest p is ~1/N). Results with p slightly above conventional thresholds but a high placebo rank, good pre-fit, substantive magnitude and persistence are read as *suggestive* evidence, not as conventional statistical significance.

