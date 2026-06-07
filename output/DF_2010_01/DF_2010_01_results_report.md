# DF_2010_01 results report (confaz regime)

Generated on 2026-06-07.

Treated state: `DF` (Distrito Federal). Treatment (single accountability cut): effective removal `2010-02-11`.
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
| Retail volume | 111.94 | 111.46 | 2.93 | 36 |
| Formal hiring | 68.50 | 70.30 | 83.41 | 36 |
| Construction | 10.82 | 10.15 | 11.06 | 36 |
| ICMS | 4.91 | 4.95 | 0.12 | 36 |
| Tax revenue | 5.05 | 5.08 | 0.11 | 36 |

### Covariate balance (treated vs synthetic by outcome)

| Covariate | Treated | Retail volume | Formal hiring | Construction | ICMS | Tax revenue |
| --- | --- | --- | --- | --- | --- | --- |
| ICMS secondary VA pc | 21.587 | 17.125 | 24.626 | 21.502 | 21.028 | 21.609 |
| ICMS tertiary VA pc | 58.378 | 28.212 | 47.129 | 46.399 | 48.407 | 48.634 |
| ICMS energy VA pc |  9.521 |  7.640 |  9.492 |  8.498 |  8.622 |  8.370 |
| ICMS fuels VA pc | 25.926 | 17.246 | 21.224 | 22.917 | 23.560 | 23.852 |
| FPE transfer pc |  7.273 | 12.537 | 11.695 | 10.224 | 10.591 | 12.525 |
| IOF-state pc |  0.000 |  0.000 |  0.000 |  0.001 |  0.000 |  0.000 |

## Main results: Augmented SCM (SA)

| Channel | Outcome | Mean gap post | RMSPE pre | RMSPE post | Donors | Freq |
| --- | --- | --- | --- | --- | --- | --- |
| Household consumption | Retail volume index (PMC, SA level) |  -4.55 |  2.93 |  6.56 | 23 | monthly |
| Formal labor market | Formal hiring balance per 100k pop | -15.35 | 83.41 | 51.94 | 23 | monthly |
| Formal labor market | Construction hiring balance per 100k pop |   7.10 | 11.06 | 34.94 | 23 | monthly |
| State public finances | ICMS value added, log real per capita (CONFAZ) |  -0.10 |  0.12 |  0.13 | 22 | monthly |
| State public finances | Tax revenue value added, log real per capita (CONFAZ) |  -0.04 |  0.11 |  0.09 | 23 | monthly |

![augmented_effect_summary.png](report/figures/augmented_effect_summary.png)

![augmented_paths_outcomes.png](report/figures/augmented_paths_outcomes.png)

![augmented_gaps_outcomes.png](report/figures/augmented_gaps_outcomes.png)

## Donor weights

![donor_weights_outcomes.png](report/figures/donor_weights_outcomes.png)

## In-space placebos

Each eligible donor is treated as pseudo-treated; p = share of placebos with a post/pre RMSPE ratio (or absolute post gap) at least as large as the treated unit's.

| Outcome | RMSPE ratio (post/pre) | p (ratio) | p (abs gap) | Placebos |
| --- | --- | --- | --- | --- |
| Retail volume | 2.24 | 0.478 | 0.304 | 23 |
| Formal hiring | 0.62 | 0.870 | 0.957 | 23 |
| Construction | 3.16 | 0.000 | 0.870 | 23 |
| ICMS | 1.15 | 0.870 | 0.217 | 23 |
| Tax revenue | 0.83 | 0.913 | 0.913 | 23 |

![placebo_gaps_outcomes.png](report/figures/placebo_gaps_outcomes.png)

![placebo_rmspe_ratio_outcomes.png](report/figures/placebo_rmspe_ratio_outcomes.png)

## Leave-one-out donor placebo

| Outcome | Gap post | LOO rank | p (2-sided) |
| --- | --- | --- | --- |
| Retail volume | -4.55 | 1 / 24 | 0.042 |
| Formal hiring | -15.35 | 2 / 24 | 0.083 |
| Construction | 7.1 | 22 / 24 | 0.125 |
| ICMS | -0.1 | 1 / 23 | 0.043 |
| Tax revenue | -0.04 | 23 / 24 | 0.083 |

## Evidence classification (5-criterion AugSCM ruler)

We do not rely on placebo p-value thresholds alone. Each outcome is graded on five criteria — (C1) pre-treatment fit (treated pre-RMSPE vs the donor median, no pre-trend), (C2) substantive magnitude (post gap >= 1 pre-period SD), (C3) persistence (share of post periods keeping the gap's sign), (C4) placebo position (discrete rank/N p <= 0.15), (C5) robustness (>= 80% of leave-one-out variants keep the sign) — into a 0-5 score. Pre-fit is a hard gate: a poor pre-fit makes the effect *non-interpretable* regardless of the rest. Tiers: **strong** (5/5), **moderate** (>=4 with placebo), **suggestive** (>=3 with magnitude or placebo), **weak**, **non-interpretable**. A *considerable* effect is strong/moderate/suggestive.

Considerable effects for this event: **1** of 5 outcomes.

| Outcome | Tier | Score | Effect | Mag (pre-SD) | Persist | Pre-fit | Placebo rank | p (rank/N) | LOO sign |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Retail volume | non-interpretable | 2/5 | -3.5% | 1.37 | 0.83 | D | 12/24 | 0.500 | 0.00 |
| Formal hiring | non-interpretable | 1/5 | -15.4 | 0.20 | 0.58 | D | 21/24 | 0.875 | 1.00 |
| Construction | suggestive | 3/5 | +7.1 | 0.45 | 0.58 | C | 1/24 | 0.042 | 1.00 |
| ICMS | non-interpretable | 3/5 | -9.8% | 1.99 | 0.88 | D | 21/24 | 0.875 | 1.00 |
| Tax revenue | weak | 3/5 | -3.8% | 0.38 | 0.71 | C | 22/24 | 0.917 | 1.00 |

Note: placebo-based inference in synthetic control is discrete and low-resolution with few donors (here the finest p is ~1/N). Results with p slightly above conventional thresholds but a high placebo rank, good pre-fit, substantive magnitude and persistence are read as *suggestive* evidence, not as conventional statistical significance.

