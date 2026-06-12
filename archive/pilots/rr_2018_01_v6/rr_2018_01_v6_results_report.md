# rr_2018_01_v6 results report (nova estrategia, k=6)

Generated on 2026-06-12.

Treated state: `RR` (Roraima). Removal: `2018-12-10`.

## Window design

- Accumulation window: **k = 6** for all outcomes.
  - Retail: trailing 6-month mean, log (`retail_ma6_log`)
  - Formal hiring: CAGED net balance, 6m sum, per 1,000 residents (`formal_hiring_6m_per1k`)
  - ICMS: CONFAZ monthly per capita (BRL/resident), 6m sum, log (`icms_conf6m_pc_log`)
- Opcao B (k=6): first clean post-treatment reading at event_time = +5.
- Pre-treatment blocks: 5 non-overlapping semi-annual blocks [-30,-25], [-24,-19], [-18,-13], [-12,-7], [-6,-1].
  Valid pre-treatment window: event_time -31 to -1 (31 months; first 5 observations are NA due to k=6 initialization).
- ATT windows: w3m [+5,+7], w6m [+5,+10], w12m [+5,+16], w24m [+5,+28].

## Methodological strategy

Donor pool excludes `AM`, `RJ`, `RR`, `SC`, `TO` (22 eligible donors).
AugSCM with 5 non-overlapping semi-annual block-level AND block-slope predictors + 7 structural covariates (17 predictor rows total).
Slope rows force the SCM to match the within-block trend direction, not just the block-mean level.
Ridge penalty by LOO-CV. LOO donor placebo is the primary robustness test.
LOO donor placebo is the primary robustness test.

## Preliminary plots

![preliminary_main_outcomes.png](report/figures/preliminary_main_outcomes.png)

## Covariate and pre-treatment balance

### Pre-treatment outcome fit

| Outcome | Treated | Synthetic | RMSPE pre | Pre periods |
| --- | --- | --- | --- | --- |
| Varejo MA6 (log) | 4.35 | 4.35 | 0.01 | 31 |
| Emprego formal 6m (per 1k) | 0.36 | 0.26 | 0.68 | 31 |
| ICMS CONFAZ 6m pc (log) | 6.59 | 6.59 | 0.02 | 31 |

### Covariate balance

| Covariate | Treated | Varejo MA6 (log) | Emprego formal 6m (per 1k) | ICMS CONFAZ 6m pc (log) |
| --- | --- | --- | --- | --- |
| Unemployment rate |     0.089 |     0.103 |     0.112 |     0.118 |
| Formalization rate |     0.562 |     0.513 |     0.534 |     0.559 |
| Labor income (real) | 3,281.611 | 2,845.431 | 2,995.606 | 3,362.831 |
| Transfer dependency ratio |     0.128 |     0.091 |     0.099 |     0.087 |
| Health expenditure pc |   283.644 |   222.837 |   209.822 |   200.498 |
| Education expenditure pc |   314.191 |   295.961 |   276.327 |   285.582 |
| Public security expenditure pc |   175.100 |   134.126 |   140.371 |   136.297 |

## Main results: Augmented SCM

| Channel | Outcome | Mean gap (w6m) | RMSPE pre | Donors |
| --- | --- | --- | --- | --- |
| Household consumption | Retail volume, MA6 trailing, log | -0.01 | 0.01 | 22 |
| Formal labor market | Net formal hiring, 6m sum, per 1,000 residents |  1.39 | 0.68 | 22 |
| State public finances | ICMS CONFAZ per capita, 6m sum, log BRL/resident |  0.17 | 0.02 | 22 |

![att_summary.png](report/figures/att_summary.png)

![paths_main_outcomes.png](report/figures/paths_main_outcomes.png)

![gaps_main_outcomes.png](report/figures/gaps_main_outcomes.png)

### ATT by window

| Outcome | w3m | w6m | w12m | w24m |
| --- | --- | --- | --- | --- |
| Varejo MA6 (log) | 0.01 | -0.01 | -0.07 | -0.06 |
| Emprego formal 6m (per 1k) | 0.38 | 1.39 | 2.14 | 2.38 |
| ICMS CONFAZ 6m pc (log) | 0.15 | 0.17 | 0.10 | 0.11 |

## Donor weights

![weights_main_outcomes.png](report/figures/weights_main_outcomes.png)

## In-space placebos

Not available in this pilot.

## Leave-one-out donor placebo

| Outcome | Gap post | LOO rank | p (2-sided) |
| --- | --- | --- | --- |
| Varejo MA6 (log) | -0.057 | 23 / 23 | 0.043 |
| ICMS CONFAZ 6m pc (log) | 0.108 | 2 / 23 | 0.087 |
| Emprego formal 6m (per 1k) | 2.378 | 23 / 23 | 0.043 |

## Evidence classification

Tier: LOO rank test. Thresholds: log >= 0.05; formal_hiring_6m_per1k >= 0.5 (per 1k residents). Poor fit: pre corr < 0.70.

Considerable: **3** / 3.

| Outcome | Tier | Effect (w6m) | LOO p | LOO rank | Mag (pre-SD) | Persist | LOO sign | Pre-trend p | Pre corr | Pre R2 | afitw |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Varejo MA6 (log) | strong | -0.8% | 0.043 | 23/23 | 2.01 | 0.79 | 1.00 | 0.47 | 0.90 | 0.74 |  |
| Emprego formal 6m (per 1k) | strong | +1.4 | 0.043 | 23/23 | 2.11 | 1.00 | 1.00 | 0.49 | 0.80 | 0.64 |  |
| ICMS CONFAZ 6m pc (log) | moderate | +18.9% | 0.087 | 2/23 | 2.42 | 0.84 | 1.00 | 0.10 | 0.89 | 0.78 |  |

### Nova Estrategia (Alcance x Duracao)

- **Alcance**: Propagado
- **Duracao**: Persistente

| Variable | Affected |
| --- | --- |
| Retail MA6 (log) | TRUE |
| ICMS CONFAZ 6m per capita (log) | TRUE |
| Formal hiring 6m per 1k residents | TRUE |
