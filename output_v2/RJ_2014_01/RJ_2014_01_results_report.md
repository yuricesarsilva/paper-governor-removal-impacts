# RJ_2014_01 results report (nova estrategia v2, k=6)

Generated on 2026-06-19.

Treated state: `RJ`. Removal: `2014-04-03`.


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

Donor pool excludes `RJ` (26 eligible donors).
AugSCM with 5 non-overlapping semi-annual block-level AND block-slope predictors + 6 structural covariates (16 predictor rows total).
Slope rows force the SCM to match the within-block trend direction, not just the block-mean level.
Ridge penalty by LOO-CV (cross-validation, not the donor placebo).
Significance: in-space donor placebo (Abadie-Diamond-Hainmueller). LOO donor-exclusion placebo is a robustness check, not the significance criterion.

## Preliminary plots

![preliminary_main_outcomes.png](report/figures/preliminary_main_outcomes.png)

## Covariate and pre-treatment balance

### Pre-treatment outcome fit

| Outcome | Treated | Synthetic | RMSPE pre | Pre periods |
| --- | --- | --- | --- | --- |
| Varejo MA6 (log) | 4.69 | 4.69 | 0.00 | 31 |
| Emprego formal 6m (per 1k) | 3.11 | 3.19 | 0.85 | 31 |
| ICMS CONFAZ 6m pc (log) | 6.79 | 6.78 | 0.01 | 31 |

### Covariate balance

| Covariate | Treated | Varejo MA6 (log) | Emprego formal 6m (per 1k) | ICMS CONFAZ 6m pc (log) |
| --- | --- | --- | --- | --- |
| ICMS secondary VA pc | 30.496 | 30.528 | 33.968 | 32.482 |
| ICMS tertiary VA pc | 56.860 | 57.400 | 54.586 | 49.670 |
| ICMS energy VA pc | 17.193 | 12.276 | 13.547 | 13.160 |
| ICMS fuels VA pc | 16.401 | 22.764 | 22.888 | 23.335 |
| FPE transfer pc |  3.405 | 24.597 | 15.086 | 18.110 |
| IOF-state pc |  0.000 |  0.000 |  0.000 |  0.000 |

## Main results: Augmented SCM

| Channel | Outcome | Mean gap (w6m) | RMSPE pre | Donors |
| --- | --- | --- | --- | --- |
| Household consumption | Retail volume, MA6 trailing, log |  0.04 | 0.00 | 26 |
| Formal labor market | Net formal hiring, 6m sum, per 1,000 residents | -0.20 | 0.85 | 26 |
| State public finances | ICMS CONFAZ per capita, 6m sum, log BRL/resident | -0.14 | 0.01 | 26 |

![att_summary.png](report/figures/att_summary.png)

![paths_main_outcomes.png](report/figures/paths_main_outcomes.png)

![gaps_main_outcomes.png](report/figures/gaps_main_outcomes.png)

### ATT by window

| Outcome | w3m | w6m | w12m | w24m |
| --- | --- | --- | --- | --- |
| Varejo MA6 (log) | 0.05 | 0.04 | 0.03 | 0.04 |
| Emprego formal 6m (per 1k) | -0.17 | -0.20 | -0.22 | 0.02 |
| ICMS CONFAZ 6m pc (log) | -0.10 | -0.14 | -0.15 | -0.14 |

## Donor weights

![weights_main_outcomes.png](report/figures/weights_main_outcomes.png)

## Placebo in-space (criterio principal)

Cada doador refeito como se fosse o tratado; classic_p = ranking da razao RMSPE pos/pre do tratado real entre tratado+placebos. Com pool de doadores pequeno, o ranking e mais informativo que o p continuo (p minimo possivel ~= 1/N).

| Outcome | Rank | p (classico) |
| --- | --- | --- |
| Varejo MA6 (log) | 5 / 27 | 0.185185185185185 |
| Emprego formal 6m (per 1k) | 24 / 27 | 0.888888888888889 |
| ICMS CONFAZ 6m pc (log) | 2 / 27 | 0.0740740740740741 |

## Robustez: placebo LOO por doador

Exclusao de um doador por vez, mantendo o tratado real fixo -- testa estabilidade ao doador, nao significancia (nao e usado para classificar tier).

| Outcome | Gap post | LOO rank | p (2-sided) |
| --- | --- | --- | --- |
| Varejo MA6 (log) | 0.038 | 1 / 27 | 0.037 |
| Emprego formal 6m (per 1k) | 0.02 | 26 / 27 | 0.074 |
| ICMS CONFAZ 6m pc (log) | -0.137 | 1 / 27 | 0.037 |

## Evidence classification

Tier: placebo in-space (criterio principal). Thresholds: log >= 0.05; formal_hiring_6m_per1k >= 0.5 (per 1k residents). Poor fit: pre corr < 0.70.

Considerable: **1** / 3.

| Outcome | Tier | Effect (w6m) | Inspace rank | Inspace p | Mag (pre-SD) | Persist | Pre-trend p | Pre corr | Pre R2 | afitw | LOO rank (rob.) | LOO p (rob.) | LOO sign (rob.) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Varejo MA6 (log) | weak | +4.5% | 5/27 | 0.185 | 1.06 | 1.00 | 0.46 | 1.00 | 1.00 |  | 1/27 | 0.037 | 1.00 |
| Emprego formal 6m (per 1k) | weak | -0.2 | 24/27 | 0.889 | 0.01 | 0.53 | 0.71 | 0.91 | 0.82 |  | 26/27 | 0.074 | 0.04 |
| ICMS CONFAZ 6m pc (log) | moderate | -13.3% | 2/27 | 0.074 | 1.59 | 1.00 | 0.96 | 0.99 | 0.98 |  | 1/27 | 0.037 | 1.00 |

### Nova Estrategia (Alcance x Duracao)

- **Alcance**: Restrito
- **Duracao**: Transitorio

| Variable | Affected |
| --- | --- |
| Retail MA6 (log) | FALSE |
| ICMS CONFAZ 6m per capita (log) | TRUE |
| Formal hiring 6m per 1k residents | FALSE |
