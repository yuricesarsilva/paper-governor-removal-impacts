# MA_2009_01 results report (confaz regime)

Generated on 2026-06-07.

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
| Retail volume | 52.22 | 52.20 | 1.45 | 36 |
| Formal hiring | 20.35 | 18.43 | 15.75 | 27 |
| Construction | 6.74 | 6.70 | 8.97 | 27 |
| ICMS | 3.41 | 3.41 | 0.05 | 36 |
| Tax revenue | 3.49 | 3.49 | 0.05 | 36 |

### Covariate balance (treated vs synthetic by outcome)

| Covariate | Treated | Retail volume | Formal hiring | Construction | ICMS | Tax revenue |
| --- | --- | --- | --- | --- | --- | --- |
| ICMS secondary VA pc |  3.244 |  6.056 |  5.288 |  3.982 |  3.463 |  3.463 |
| ICMS tertiary VA pc |  7.933 | 17.549 | 15.778 | 14.153 | 13.813 | 13.813 |
| ICMS energy VA pc |  1.724 |  3.247 |  2.996 |  2.780 |  2.738 |  2.738 |
| ICMS fuels VA pc |  5.212 |  6.643 |  5.931 |  5.626 |  6.184 |  6.184 |
| FPE transfer pc | 27.446 | 49.011 | 29.874 | 32.830 | 33.015 | 33.015 |
| IOF-state pc |  0.000 |  0.003 |  0.001 |  0.000 |  0.000 |  0.000 |

## Main results: Augmented SCM (SA)

| Channel | Outcome | Mean gap post | RMSPE pre | RMSPE post | Donors | Freq |
| --- | --- | --- | --- | --- | --- | --- |
| Household consumption | Retail volume index (PMC, SA level) |   0.25 |  1.45 |  2.34 | 23 | monthly |
| Formal labor market | Formal hiring balance per 100k pop | -20.39 | 15.75 | 32.73 | 23 | monthly |
| Formal labor market | Construction hiring balance per 100k pop |  -9.19 |  8.97 | 20.66 | 23 | monthly |
| State public finances | ICMS value added, log real per capita (CONFAZ) |  -0.13 |  0.05 |  0.14 | 22 | monthly |
| State public finances | Tax revenue value added, log real per capita (CONFAZ) |  -0.12 |  0.05 |  0.13 | 23 | monthly |

![augmented_effect_summary.png](report/figures/augmented_effect_summary.png)

![augmented_paths_outcomes.png](report/figures/augmented_paths_outcomes.png)

![augmented_gaps_outcomes.png](report/figures/augmented_gaps_outcomes.png)

## Donor weights

![donor_weights_outcomes.png](report/figures/donor_weights_outcomes.png)

## In-space placebos

Each eligible donor is treated as pseudo-treated; p = share of placebos with a post/pre RMSPE ratio (or absolute post gap) at least as large as the treated unit's.

| Outcome | RMSPE ratio (post/pre) | p (ratio) | p (abs gap) | Placebos |
| --- | --- | --- | --- | --- |
| Retail volume | 1.62 | 0.913 | 1.000 | 23 |
| Formal hiring | 2.08 | 0.087 | 0.913 | 23 |
| Construction | 2.30 | 0.174 | 0.696 | 23 |
| ICMS | 2.83 | 0.000 | 0.174 | 23 |
| Tax revenue | 2.49 | 0.217 | 0.435 | 23 |

![placebo_gaps_outcomes.png](report/figures/placebo_gaps_outcomes.png)

![placebo_rmspe_ratio_outcomes.png](report/figures/placebo_rmspe_ratio_outcomes.png)

## Leave-one-out donor placebo

| Outcome | Gap post | LOO rank | p (2-sided) |
| --- | --- | --- | --- |
| Retail volume | 0.25 | 24 / 24 | 0.042 |
| Formal hiring | -20.39 | 24 / 24 | 0.042 |
| Construction | -9.19 | 5 / 24 | 0.208 |
| ICMS | -0.13 | 23 / 23 | 0.043 |
| Tax revenue | -0.12 | 24 / 24 | 0.042 |

## Evidence classification (5-criterion AugSCM ruler)

We do not rely on placebo p-value thresholds alone. Each outcome is graded on five criteria — (C1) pre-treatment fit (treated pre-RMSPE vs the donor median, no pre-trend), (C2) substantive magnitude (post gap >= 1 pre-period SD), (C3) persistence (share of post periods keeping the gap's sign), (C4) placebo position (discrete rank/N p <= 0.15), (C5) robustness (>= 80% of leave-one-out variants keep the sign) — into a 0-5 score. Pre-fit is a hard gate: a poor pre-fit makes the effect *non-interpretable* regardless of the rest. Tiers: **strong** (5/5), **moderate** (>=4 with placebo), **suggestive** (>=3 with magnitude or placebo), **weak**, **non-interpretable**. A *considerable* effect is strong/moderate/suggestive.

Considerable effects for this event: **4** of 5 outcomes.

| Outcome | Tier | Score | Effect | Mag (pre-SD) | Persist | Pre-fit | Placebo rank | p (rank/N) | LOO sign |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Retail volume | weak | 1/5 | +0.4% | 0.05 | 0.54 | B | 22/24 | 0.917 | 0.00 |
| Formal hiring | strong | 5/5 | -20.4 | 1.02 | 0.79 | A | 3/24 | 0.125 | 1.00 |
| Construction | suggestive | 4/5 | -9.2 | 1.01 | 0.75 | B | 5/24 | 0.208 | 1.00 |
| ICMS | strong | 5/5 | -11.9% | 1.76 | 1.00 | A | 1/24 | 0.042 | 1.00 |
| Tax revenue | suggestive | 4/5 | -11.0% | 1.47 | 0.92 | A | 6/24 | 0.250 | 1.00 |

Note: placebo-based inference in synthetic control is discrete and low-resolution with few donors (here the finest p is ~1/N). Results with p slightly above conventional thresholds but a high placebo rank, good pre-fit, substantive magnitude and persistence are read as *suggestive* evidence, not as conventional statistical significance.

