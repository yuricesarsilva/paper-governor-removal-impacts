# AM_2017_01 results report (confaz regime)

Generated on 2026-06-07.

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
| Retail volume | 83.22 | 83.48 | 2.29 | 36 |
| Services volume | 89.68 | 89.73 | 3.32 | 36 |
| Formal hiring | -51.64 | -50.60 | 24.87 | 36 |
| Construction | -8.26 | -9.15 | 10.71 | 36 |
| ICMS | 5.14 | 5.14 | 0.07 | 36 |
| Tax revenue | 5.25 | 5.25 | 0.07 | 36 |

### Covariate balance (treated vs synthetic by outcome)

| Covariate | Treated | Retail volume | Services volume | Formal hiring | Construction | ICMS | Tax revenue |
| --- | --- | --- | --- | --- | --- | --- | --- |
| ICMS secondary VA pc | 51.463 | 42.963 | 50.964 | 39.605 | 39.409 | 45.383 | 45.079 |
| ICMS tertiary VA pc | 83.627 | 76.315 | 68.413 | 76.662 | 77.666 | 79.709 | 78.965 |
| ICMS energy VA pc |  4.517 | 10.652 | 12.257 | 11.617 | 10.988 | 11.122 | 10.878 |
| ICMS fuels VA pc | 20.509 | 19.374 | 22.972 | 21.341 | 23.667 | 21.272 | 21.984 |
| FPE transfer pc | 37.524 | 65.757 | 37.788 | 54.979 | 57.842 | 56.824 | 58.336 |
| IOF-state pc |  0.001 |  0.004 |  0.002 |  0.001 |  0.000 |  0.003 |  0.003 |

## Main results: Augmented SCM (SA)

| Channel | Outcome | Mean gap post | RMSPE pre | RMSPE post | Donors | Freq |
| --- | --- | --- | --- | --- | --- | --- |
| Household consumption | Retail volume index (PMC, SA level) | -1.29 |  2.29 |  3.12 | 24 | monthly |
| Household consumption | Services volume index (PMS, SA level) |  0.87 |  3.32 |  3.70 | 24 | monthly |
| Formal labor market | Formal hiring balance per 100k pop |  9.93 | 24.87 | 23.45 | 24 | monthly |
| Formal labor market | Construction hiring balance per 100k pop |  0.54 | 10.71 |  4.94 | 24 | monthly |
| State public finances | ICMS value added, log real per capita (CONFAZ) |  0.05 |  0.07 |  0.07 | 24 | monthly |
| State public finances | Tax revenue value added, log real per capita (CONFAZ) |  0.02 |  0.07 |  0.05 | 24 | monthly |

![augmented_effect_summary.png](report/figures/augmented_effect_summary.png)

![augmented_paths_outcomes.png](report/figures/augmented_paths_outcomes.png)

![augmented_gaps_outcomes.png](report/figures/augmented_gaps_outcomes.png)

## Donor weights

![donor_weights_outcomes.png](report/figures/donor_weights_outcomes.png)

## In-space placebos

Each eligible donor is treated as pseudo-treated; p = share of placebos with a post/pre RMSPE ratio (or absolute post gap) at least as large as the treated unit's.

| Outcome | RMSPE ratio (post/pre) | p (ratio) | p (abs gap) | Placebos |
| --- | --- | --- | --- | --- |
| Retail volume | 1.36 | 0.792 | 0.917 | 24 |
| Services volume | 1.11 | 0.667 | 1.000 | 24 |
| Formal hiring | 0.94 | 0.500 | 1.000 | 24 |
| Construction | 0.46 | 0.958 | 1.000 | 24 |
| ICMS | 1.05 | 0.625 | 0.625 | 24 |
| Tax revenue | 0.62 | 0.917 | 1.000 | 24 |

![placebo_gaps_outcomes.png](report/figures/placebo_gaps_outcomes.png)

![placebo_rmspe_ratio_outcomes.png](report/figures/placebo_rmspe_ratio_outcomes.png)

## Leave-one-out donor placebo

| Outcome | Gap post | LOO rank | p (2-sided) |
| --- | --- | --- | --- |
| Retail volume | -1.29 | 23 / 25 | 0.12 |
| Services volume | 0.87 | 25 / 25 | 0.04 |
| Formal hiring | 9.93 | 25 / 25 | 0.04 |
| Construction | 0.54 | 20 / 25 | 0.24 |
| ICMS | 0.05 | 2 / 25 | 0.08 |
| Tax revenue | 0.02 | 2 / 25 | 0.08 |

## Evidence classification

Inference follows the standard placebo approach (Abadie, Diamond & Hainmueller 2010): the tier is the treated unit's position in the placebo distribution of the post/pre RMSPE ratio (discrete p = rank/N), which already self-normalises for pre-treatment fit. To rise above *weak* an effect must also be substantively large (|post gap| >= 1 pre-period SD) and free of a pre-trend. Tiers: **strong** (placebo p <= 0.05), **moderate** (<= 0.10), **suggestive** (<= 0.15), **weak** otherwise; a *considerable* effect is strong/moderate/suggestive. Persistence and leave-one-out sign-stability are reported as supporting robustness.

**Pre-treatment fit quality is reported, not used to discard results.** The SCM literature has no fixed fit threshold (fit is judged visually and relative to the effect), so we show the treated pre-RMSPE percentile class (A-D), the treated-vs-synthetic pre correlation and R^2, and flag poor-fit cases (⚠) for the reader rather than labelling them non-interpretable.

Considerable effects for this event: **0** of 6 outcomes.

| Outcome | Tier | Effect | Placebo p | Rank | Mag (pre-SD) | Persist | LOO sign | Pre-trend p | Pre-fit | Pre corr | Pre R2 | ⚠fit |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Retail volume | weak | -1.5% | 0.800 | 20/25 | 0.19 | 0.75 | 0.96 | 0.84 | C | 0.94 |  0.88 |  |
| Services volume | weak | +1.1% | 0.680 | 17/25 | 0.08 | 0.58 | 0.00 | 0.01 | C | 0.95 |  0.90 |  |
| Formal hiring | weak | +9.9 | 0.520 | 13/25 | 0.28 | 0.62 | 1.00 | 0.77 | B | 0.73 |  0.52 |  |
| Construction | weak | +0.5 | 0.960 | 24/25 | 0.07 | 0.58 | 0.92 | 0.75 | B | 0.13 | -1.13 | yes |
| ICMS | weak | +5.6% | 0.640 | 16/25 | 0.46 | 0.96 | 1.00 | 0.25 | B | 0.81 |  0.66 |  |
| Tax revenue | weak | +2.2% | 0.920 | 23/25 | 0.17 | 0.79 | 0.96 | 0.08 | B | 0.80 |  0.65 |  |

Note: placebo inference in synthetic control is discrete and low-resolution with few donors (finest p ~ 1/N). A p slightly above the conventional threshold with a high placebo rank, good fit and a substantive, persistent gap is read as *suggestive*, not as conventional significance.

