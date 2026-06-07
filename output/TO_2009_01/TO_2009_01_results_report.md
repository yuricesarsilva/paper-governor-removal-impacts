# TO_2009_01 results report (confaz regime)

Generated on 2026-06-07.

Treated state: `TO` (Tocantins). Treatment (single accountability cut): effective removal `2009-09-08`.
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
| Retail volume | 43.81 | 43.82 | 1.36 | 36 |
| Formal hiring | 18.87 | 19.85 | 40.19 | 32 |
| Construction | 3.68 | -0.61 | 31.30 | 32 |
| ICMS | 4.09 | 4.08 | 0.06 | 36 |
| Tax revenue | 4.18 | 4.18 | 0.06 | 36 |

### Covariate balance (treated vs synthetic by outcome)

| Covariate | Treated | Retail volume | Formal hiring | Construction | ICMS | Tax revenue |
| --- | --- | --- | --- | --- | --- | --- |
| ICMS secondary VA pc |  6.188 |  7.926 |  8.713 | 10.741 |  7.270 |  6.080 |
| ICMS tertiary VA pc | 18.615 | 24.852 | 23.943 | 29.879 | 21.282 | 21.800 |
| ICMS energy VA pc |  4.610 |  4.572 |  4.360 |  5.816 |  4.412 |  4.489 |
| ICMS fuels VA pc | 13.183 | 13.720 | 12.210 | 18.567 | 12.222 | 11.984 |
| FPE transfer pc | 81.070 | 92.753 | 78.737 | 56.416 | 77.921 | 77.252 |
| IOF-state pc |  0.000 |  0.003 |  0.003 |  0.006 |  0.002 |  0.002 |

## Main results: Augmented SCM (SA)

| Channel | Outcome | Mean gap post | RMSPE pre | RMSPE post | Donors | Freq |
| --- | --- | --- | --- | --- | --- | --- |
| Household consumption | Retail volume index (PMC, SA level) |  14.17 |  1.36 | 17.35 | 23 | monthly |
| Formal labor market | Formal hiring balance per 100k pop | -16.18 | 40.19 | 45.30 | 23 | monthly |
| Formal labor market | Construction hiring balance per 100k pop | -12.17 | 31.30 | 26.61 | 23 | monthly |
| State public finances | ICMS value added, log real per capita (CONFAZ) |  -0.03 |  0.06 |  0.07 | 22 | monthly |
| State public finances | Tax revenue value added, log real per capita (CONFAZ) |  -0.05 |  0.06 |  0.07 | 23 | monthly |

![augmented_effect_summary.png](report/figures/augmented_effect_summary.png)

![augmented_paths_outcomes.png](report/figures/augmented_paths_outcomes.png)

![augmented_gaps_outcomes.png](report/figures/augmented_gaps_outcomes.png)

## Donor weights

![donor_weights_outcomes.png](report/figures/donor_weights_outcomes.png)

## In-space placebos

Each eligible donor is treated as pseudo-treated; p = share of placebos with a post/pre RMSPE ratio (or absolute post gap) at least as large as the treated unit's.

| Outcome | RMSPE ratio (post/pre) | p (ratio) | p (abs gap) | Placebos |
| --- | --- | --- | --- | --- |
| Retail volume | 12.76 | 0.000 | 0.043 | 23 |
| Formal hiring |  1.13 | 0.391 | 0.957 | 23 |
| Construction |  0.85 | 0.913 | 0.348 | 23 |
| ICMS |  1.02 | 0.739 | 0.913 | 23 |
| Tax revenue |  1.14 | 0.783 | 0.739 | 23 |

![placebo_gaps_outcomes.png](report/figures/placebo_gaps_outcomes.png)

![placebo_rmspe_ratio_outcomes.png](report/figures/placebo_rmspe_ratio_outcomes.png)

## Leave-one-out donor placebo

| Outcome | Gap post | LOO rank | p (2-sided) |
| --- | --- | --- | --- |
| Retail volume | 14.17 | 24 / 24 | 0.042 |
| Formal hiring | -16.18 | 24 / 24 | 0.042 |
| Construction | -12.17 | 2 / 24 | 0.083 |
| ICMS | -0.03 | 23 / 23 | 0.043 |
| Tax revenue | -0.05 | 24 / 24 | 0.042 |

## Evidence classification (5-criterion AugSCM ruler)

We do not rely on placebo p-value thresholds alone. Each outcome is graded on five criteria — (C1) pre-treatment fit (treated pre-RMSPE vs the donor median, no pre-trend), (C2) substantive magnitude (post gap >= 1 pre-period SD), (C3) persistence (share of post periods keeping the gap's sign), (C4) placebo position (discrete rank/N p <= 0.15), (C5) robustness (>= 80% of leave-one-out variants keep the sign) — into a 0-5 score. Pre-fit is a hard gate: a poor pre-fit makes the effect *non-interpretable* regardless of the rest. Tiers: **strong** (5/5), **moderate** (>=4 with placebo), **suggestive** (>=3 with magnitude or placebo), **weak**, **non-interpretable**. A *considerable* effect is strong/moderate/suggestive.

Considerable effects for this event: **1** of 5 outcomes.

| Outcome | Tier | Score | Effect | Mag (pre-SD) | Persist | Pre-fit | Placebo rank | p (rank/N) | LOO sign |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Retail volume | strong | 5/5 | +25.8% | 7.82 | 0.83 | B | 1/24 | 0.042 | 1.00 |
| Formal hiring | weak | 3/5 | -16.2 | 0.36 | 0.62 | B | 10/24 | 0.417 | 1.00 |
| Construction | non-interpretable | 2/5 | -12.2 | 0.32 | 0.62 | D | 22/24 | 0.917 | 1.00 |
| ICMS | weak | 3/5 | -3.3% | 0.54 | 0.75 | B | 18/24 | 0.750 | 1.00 |
| Tax revenue | weak | 3/5 | -5.0% | 0.74 | 0.88 | B | 19/24 | 0.792 | 1.00 |

Note: placebo-based inference in synthetic control is discrete and low-resolution with few donors (here the finest p is ~1/N). Results with p slightly above conventional thresholds but a high placebo rank, good pre-fit, substantive magnitude and persistence are read as *suggestive* evidence, not as conventional statistical significance.

