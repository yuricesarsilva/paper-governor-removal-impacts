# RR_2004_01 results report (confaz regime)

Generated on 2026-06-07.

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
| Retail volume | 26.07 | 26.05 | 2.57 | 36 |
| ICMS | 3.55 | 3.55 | 0.13 | 36 |
| Tax revenue | 3.64 | 3.63 | 0.15 | 36 |

### Covariate balance (treated vs synthetic by outcome)

| Covariate | Treated | Retail volume | ICMS | Tax revenue |
| --- | --- | --- | --- | --- |
| ICMS secondary VA pc |   2.915 |  2.356 |  2.386 |  2.381 |
| ICMS tertiary VA pc |  17.299 | 24.481 | 23.622 | 24.391 |
| ICMS energy VA pc |   1.220 |  2.131 |  2.082 |  2.057 |
| ICMS fuels VA pc |   9.265 |  7.883 |  7.862 |  7.803 |
| FPE transfer pc | 120.770 | 72.017 | 73.247 | 73.790 |
| IOF-state pc |   0.004 |  0.006 |  0.007 |  0.007 |

## Main results: Augmented SCM (SA)

| Channel | Outcome | Mean gap post | RMSPE pre | RMSPE post | Donors | Freq |
| --- | --- | --- | --- | --- | --- | --- |
| Household consumption | Retail volume index (PMC, SA level) | -8.61 | 2.57 | 9.42 | 25 | monthly |
| State public finances | ICMS value added, log real per capita (CONFAZ) |  0.04 | 0.13 | 0.07 | 25 | monthly |
| State public finances | Tax revenue value added, log real per capita (CONFAZ) |  0.15 | 0.15 | 0.17 | 25 | monthly |

![augmented_effect_summary.png](report/figures/augmented_effect_summary.png)

![augmented_paths_outcomes.png](report/figures/augmented_paths_outcomes.png)

![augmented_gaps_outcomes.png](report/figures/augmented_gaps_outcomes.png)

## Donor weights

![donor_weights_outcomes.png](report/figures/donor_weights_outcomes.png)

## In-space placebos

Each eligible donor is treated as pseudo-treated; p = share of placebos with a post/pre RMSPE ratio (or absolute post gap) at least as large as the treated unit's.

| Outcome | RMSPE ratio (post/pre) | p (ratio) | p (abs gap) | Placebos |
| --- | --- | --- | --- | --- |
| Retail volume | 3.66 | 0.320 | 0.080 | 25 |
| ICMS | 0.51 | 1.000 | 0.960 | 25 |
| Tax revenue | 1.08 | 0.720 | 0.160 | 25 |

![placebo_gaps_outcomes.png](report/figures/placebo_gaps_outcomes.png)

![placebo_rmspe_ratio_outcomes.png](report/figures/placebo_rmspe_ratio_outcomes.png)

## Leave-one-out donor placebo

| Outcome | Gap post | LOO rank | p (2-sided) |
| --- | --- | --- | --- |
| Retail volume | -8.61 | 26 / 26 | 0.038 |
| ICMS | 0.04 | 26 / 26 | 0.038 |
| Tax revenue | 0.15 | 26 / 26 | 0.038 |

## Evidence classification

Inference follows the standard placebo approach (Abadie, Diamond & Hainmueller 2010): the tier is the treated unit's position in the placebo distribution of the post/pre RMSPE ratio (discrete p = rank/N), which already self-normalises for pre-treatment fit. To rise above *weak* an effect must also be substantively large (|post gap| >= 1 pre-period SD) and free of a pre-trend. Tiers: **strong** (placebo p <= 0.05), **moderate** (<= 0.10), **suggestive** (<= 0.15), **weak** otherwise; a *considerable* effect is strong/moderate/suggestive. Persistence and leave-one-out sign-stability are reported as supporting robustness.

**Pre-treatment fit quality is reported, not used to discard results.** The SCM literature has no fixed fit threshold (fit is judged visually and relative to the effect), so we show the treated pre-RMSPE percentile class (A-D), the treated-vs-synthetic pre correlation and R^2, and flag poor-fit cases (⚠) for the reader rather than labelling them non-interpretable.

Considerable effects for this event: **0** of 3 outcomes.

| Outcome | Tier | Effect | Placebo p | Rank | Mag (pre-SD) | Persist | LOO sign | Pre-trend p | Pre-fit | Pre corr | Pre R2 | ⚠fit |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Retail volume | weak | -23.7% | 0.346 | 9/26 | 3.03 | 0.92 | 1.00 | 0.97 | D |  0.65 |  0.18 | yes |
| ICMS | weak | +4.1% | 1.000 | 26/26 | 0.52 | 0.79 | 0.92 | 0.04 | D | -0.10 | -2.04 | yes |
| Tax revenue | weak | +15.9% | 0.731 | 19/26 | 1.22 | 0.96 | 0.92 | 0.10 | D |  0.01 | -0.63 | yes |

Note: placebo inference in synthetic control is discrete and low-resolution with few donors (finest p ~ 1/N). A p slightly above the conventional threshold with a high placebo rank, good fit and a substantive, persistent gap is read as *suggestive*, not as conventional significance.

