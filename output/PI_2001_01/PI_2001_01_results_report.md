# PI_2001_01 results report (confaz regime)

Generated on 2026-06-07.

Treated state: `PI` (Piaui). Treatment (single accountability cut): effective removal `2001-11-06`.
Data regime: **confaz**. All outcomes are monthly (X-13); fiscal outcomes (ICMS, tax revenue) are from CONFAZ.

## Window design

- Monthly outcomes: target 36-month pre (floor 20), 24-month post.
- An outcome enters only if the treated unit meets its pre-window floor and a complete post-window.

Qualifying outcomes: Retail volume, ICMS, Tax revenue.

## Methodological strategy

Main donor pool excludes `PI` (any state treated anywhere in the SCM window). Preferred specification uses 26 eligible donors. Augmented SCM is the headline estimator; weights are estimated on the pre-treatment window. Predictors: the full pre-treatment outcome path plus the regime covariates: CONFAZ ICMS sectors (secondary, tertiary, energy, fuels) plus FPE and IOF-state, real per capita.

## Preliminary plots

![preliminary_outcomes.png](report/figures/preliminary_outcomes.png)

## Covariate and pre-treatment balance

### Pre-treatment outcome fit

| Outcome | Treated | Synthetic | RMSPE pre | Pre periods |
| --- | --- | --- | --- | --- |
| Retail volume | 41.56 | 41.47 | 0.96 | 22 |
| ICMS | 2.64 | 2.63 | 0.08 | 22 |
| Tax revenue | 2.69 | 2.68 | 0.08 | 22 |

### Covariate balance (treated vs synthetic by outcome)

| Covariate | Treated | Retail volume | ICMS | Tax revenue |
| --- | --- | --- | --- | --- |
| ICMS secondary VA pc |  1.366 |  1.814 |  1.623 |  1.563 |
| ICMS tertiary VA pc |  7.982 |  7.512 |  7.995 |  8.017 |
| ICMS energy VA pc |  1.164 |  1.182 |  1.110 |  1.081 |
| ICMS fuels VA pc |  2.172 |  2.189 |  2.149 |  2.158 |
| FPE transfer pc | 16.533 | 17.371 | 16.420 | 16.221 |
| IOF-state pc |  0.000 |  0.000 |  0.000 |  0.000 |

## Main results: Augmented SCM (SA)

| Channel | Outcome | Mean gap post | RMSPE pre | RMSPE post | Donors | Freq |
| --- | --- | --- | --- | --- | --- | --- |
| Household consumption | Retail volume index (PMC, SA level) |  6.29 | 0.96 | 6.66 | 26 | monthly |
| State public finances | ICMS value added, log real per capita (CONFAZ) | -0.07 | 0.08 | 0.10 | 26 | monthly |
| State public finances | Tax revenue value added, log real per capita (CONFAZ) | -0.07 | 0.08 | 0.09 | 26 | monthly |

![augmented_effect_summary.png](report/figures/augmented_effect_summary.png)

![augmented_paths_outcomes.png](report/figures/augmented_paths_outcomes.png)

![augmented_gaps_outcomes.png](report/figures/augmented_gaps_outcomes.png)

## Donor weights

![donor_weights_outcomes.png](report/figures/donor_weights_outcomes.png)

## In-space placebos

Each eligible donor is treated as pseudo-treated; p = share of placebos with a post/pre RMSPE ratio (or absolute post gap) at least as large as the treated unit's.

| Outcome | RMSPE ratio (post/pre) | p (ratio) | p (abs gap) | Placebos |
| --- | --- | --- | --- | --- |
| Retail volume | 6.91 | 0.000 | 0.038 | 26 |
| ICMS | 1.35 | 0.423 | 0.577 | 26 |
| Tax revenue | 1.15 | 0.692 | 0.692 | 26 |

![placebo_gaps_outcomes.png](report/figures/placebo_gaps_outcomes.png)

![placebo_rmspe_ratio_outcomes.png](report/figures/placebo_rmspe_ratio_outcomes.png)

## Leave-one-out donor placebo

| Outcome | Gap post | LOO rank | p (2-sided) |
| --- | --- | --- | --- |
| Retail volume | 6.29 | 1 / 27 | 0.037 |
| ICMS | -0.07 | 26 / 27 | 0.074 |
| Tax revenue | -0.07 | 27 / 27 | 0.037 |

## Evidence classification (5-criterion AugSCM ruler)

We do not rely on placebo p-value thresholds alone. Each outcome is graded on five criteria — (C1) pre-treatment fit (treated pre-RMSPE vs the donor median, no pre-trend), (C2) substantive magnitude (post gap >= 1 pre-period SD), (C3) persistence (share of post periods keeping the gap's sign), (C4) placebo position (discrete rank/N p <= 0.15), (C5) robustness (>= 80% of leave-one-out variants keep the sign) — into a 0-5 score. Pre-fit is a hard gate: a poor pre-fit makes the effect *non-interpretable* regardless of the rest. Tiers: **strong** (5/5), **moderate** (>=4 with placebo), **suggestive** (>=3 with magnitude or placebo), **weak**, **non-interpretable**. A *considerable* effect is strong/moderate/suggestive.

Considerable effects for this event: **1** of 3 outcomes.

| Outcome | Tier | Score | Effect | Mag (pre-SD) | Persist | Pre-fit | Placebo rank | p (rank/N) | LOO sign |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Retail volume | strong | 5/5 | +15.4% | 7.55 | 1.00 | A | 1/27 | 0.037 | 1.00 |
| ICMS | non-interpretable | 2/5 | -6.7% | 0.99 | 0.75 | C | 12/27 | 0.444 | 1.00 |
| Tax revenue | non-interpretable | 2/5 | -6.5% | 0.98 | 0.79 | C | 19/27 | 0.704 | 1.00 |

Note: placebo-based inference in synthetic control is discrete and low-resolution with few donors (here the finest p is ~1/N). Results with p slightly above conventional thresholds but a high placebo rank, good pre-fit, substantive magnitude and persistence are read as *suggestive* evidence, not as conventional statistical significance.

