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

## Evidence classification

Inference follows the standard placebo approach (Abadie, Diamond & Hainmueller 2010): the tier is the treated unit's position in the placebo distribution of the post/pre RMSPE ratio (discrete p = rank/N), which already self-normalises for pre-treatment fit. To rise above *weak* an effect must also be substantively large (|post gap| >= 1 pre-period SD) and free of a pre-trend. Tiers: **strong** (placebo p <= 0.05), **moderate** (<= 0.10), **suggestive** (<= 0.15), **weak** otherwise; a *considerable* effect is strong/moderate/suggestive. Persistence and leave-one-out sign-stability are reported as supporting robustness.

**Pre-treatment fit quality is reported, not used to discard results.** The SCM literature has no fixed fit threshold (fit is judged visually and relative to the effect), so we show the treated pre-RMSPE percentile class (A-D), the treated-vs-synthetic pre correlation and R^2, and flag poor-fit cases (⚠) for the reader rather than labelling them non-interpretable.

Considerable effects for this event: **1** of 5 outcomes.

| Outcome | Tier | Effect | Placebo p | Rank | Mag (pre-SD) | Persist | LOO sign | Pre-trend p | Pre-fit | Pre corr | Pre R2 | ⚠fit |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Retail volume | strong | +25.8% | 0.042 | 1/24 | 7.82 | 0.83 | 1.00 | 0.18 | B | 0.70 |  0.44 |  |
| Formal hiring | weak | -16.2 | 0.417 | 10/24 | 0.36 | 0.62 | 1.00 | 0.35 | B | 0.50 |  0.21 | yes |
| Construction | weak | -12.2 | 0.917 | 22/24 | 0.32 | 0.62 | 1.00 | 0.90 | D | 0.61 |  0.34 | yes |
| ICMS | weak | -3.3% | 0.750 | 18/24 | 0.54 | 0.75 | 1.00 | 0.79 | B | 0.53 | -0.10 |  |
| Tax revenue | weak | -5.0% | 0.792 | 19/24 | 0.74 | 0.88 | 1.00 | 0.36 | B | 0.62 |  0.18 |  |

Note: placebo inference in synthetic control is discrete and low-resolution with few donors (finest p ~ 1/N). A p slightly above the conventional threshold with a high placebo rank, good fit and a substantive, persistent gap is read as *suggestive*, not as conventional significance.

