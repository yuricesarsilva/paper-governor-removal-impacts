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

## Evidence classification

Inference follows the standard placebo approach (Abadie, Diamond & Hainmueller 2010): the tier is the treated unit's position in the placebo distribution of the post/pre RMSPE ratio (discrete p = rank/N), which already self-normalises for pre-treatment fit. To rise above *weak* an effect must also be substantively large (|post gap| >= 1 pre-period SD) and free of a pre-trend. Tiers: **strong** (placebo p <= 0.05), **moderate** (<= 0.10), **suggestive** (<= 0.15), **weak** otherwise; a *considerable* effect is strong/moderate/suggestive. Persistence and leave-one-out sign-stability are reported as supporting robustness.

**Pre-treatment fit quality is reported, not used to discard results.** The SCM literature has no fixed fit threshold (fit is judged visually and relative to the effect), so we show the treated pre-RMSPE percentile class (A-D), the treated-vs-synthetic pre correlation and R^2, and flag poor-fit cases (⚠) for the reader rather than labelling them non-interpretable.

Considerable effects for this event: **0** of 5 outcomes.

| Outcome | Tier | Effect | Placebo p | Rank | Mag (pre-SD) | Persist | LOO sign | Pre-trend p | Pre-fit | Pre corr | Pre R2 | ⚠fit |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Retail volume | weak | -3.5% | 0.500 | 12/24 | 1.37 | 0.83 | 0.00 | 0.57 | D | 0.75 |  0.23 | yes |
| Formal hiring | weak | -15.4 | 0.875 | 21/24 | 0.20 | 0.58 | 1.00 | 0.44 | D | 0.27 | -0.17 | yes |
| Construction | weak | +7.1 | 0.042 | 1/24 | 0.45 | 0.58 | 1.00 | 0.96 | C | 0.70 |  0.51 |  |
| ICMS | weak | -9.8% | 0.875 | 21/24 | 1.99 | 0.88 | 1.00 | 0.31 | D | 0.29 | -4.02 | yes |
| Tax revenue | weak | -3.8% | 0.917 | 22/24 | 0.38 | 0.71 | 1.00 | 0.44 | C | 0.22 | -0.18 | yes |

Note: placebo inference in synthetic control is discrete and low-resolution with few donors (finest p ~ 1/N). A p slightly above the conventional threshold with a high placebo rank, good fit and a substantive, persistent gap is read as *suggestive*, not as conventional significance.

