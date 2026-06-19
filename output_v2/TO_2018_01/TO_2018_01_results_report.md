# TO_2018_01 results report (nova estrategia v2, k=6)

Generated on 2026-06-19.

Treated state: `TO`. Removal: `2018-03-22`.


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

Donor pool excludes `AM`, `RR`, `TO` (24 eligible donors).
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
| Varejo MA6 (log) | 4.59 | 4.59 | 0.01 | 31 |
| Emprego formal 6m (per 1k) | -0.89 | -0.83 | 0.66 | 31 |
| ICMS CONFAZ 6m pc (log) | 6.64 | 6.64 | 0.02 | 31 |

### Covariate balance

| Covariate | Treated | Varejo MA6 (log) | Emprego formal 6m (per 1k) | ICMS CONFAZ 6m pc (log) |
| --- | --- | --- | --- | --- |
| ICMS secondary VA pc |  14.199 | 18.858 | 16.556 | 12.025 |
| ICMS tertiary VA pc |  37.046 | 53.695 | 46.744 | 52.528 |
| ICMS energy VA pc |   9.989 |  8.590 |  8.146 |  8.408 |
| ICMS fuels VA pc |  29.923 | 16.700 | 24.244 | 31.584 |
| FPE transfer pc | 149.357 | 72.885 | 94.047 | 51.190 |
| IOF-state pc |   0.000 |  0.002 |  0.006 |  0.002 |

## Main results: Augmented SCM

| Channel | Outcome | Mean gap (w6m) | RMSPE pre | Donors |
| --- | --- | --- | --- | --- |
| Household consumption | Retail volume, MA6 trailing, log |  0.03 | 0.01 | 24 |
| Formal labor market | Net formal hiring, 6m sum, per 1,000 residents | -0.01 | 0.66 | 24 |
| State public finances | ICMS CONFAZ per capita, 6m sum, log BRL/resident |  0.00 | 0.02 | 24 |

![att_summary.png](report/figures/att_summary.png)

![paths_main_outcomes.png](report/figures/paths_main_outcomes.png)

![gaps_main_outcomes.png](report/figures/gaps_main_outcomes.png)

### ATT by window

| Outcome | w3m | w6m | w12m | w24m |
| --- | --- | --- | --- | --- |
| Varejo MA6 (log) | 0.04 | 0.03 | 0.04 | 0.06 |
| Emprego formal 6m (per 1k) | 0.48 | -0.01 | -0.24 | -0.33 |
| ICMS CONFAZ 6m pc (log) | 0.01 | 0.00 | 0.01 | 0.02 |

## Donor weights

![weights_main_outcomes.png](report/figures/weights_main_outcomes.png)

## Placebo in-space (criterio principal)

Cada doador refeito como se fosse o tratado; classic_p = ranking da razao RMSPE pos/pre do tratado real entre tratado+placebos. Com pool de doadores pequeno, o ranking e mais informativo que o p continuo (p minimo possivel ~= 1/N).

| Outcome | Rank | p (classico) |
| --- | --- | --- |
| Varejo MA6 (log) | 5 / 25 | 0.2 |
| Emprego formal 6m (per 1k) | 24 / 25 | 0.96 |
| ICMS CONFAZ 6m pc (log) | 25 / 25 | 1 |

## Robustez: placebo LOO por doador

Exclusao de um doador por vez, mantendo o tratado real fixo -- testa estabilidade ao doador, nao significancia (nao e usado para classificar tier).

| Outcome | Gap post | LOO rank | p (2-sided) |
| --- | --- | --- | --- |
| Varejo MA6 (log) | 0.062 | 1 / 25 | 0.04 |
| Emprego formal 6m (per 1k) | -0.332 | 5 / 25 | 0.2 |
| ICMS CONFAZ 6m pc (log) | 0.017 | 22 / 25 | 0.16 |

## Evidence classification

Tier: placebo in-space (criterio principal). Thresholds: log >= 0.05; formal_hiring_6m_per1k >= 0.5 (per 1k residents). Poor fit: pre corr < 0.70.

Considerable: **0** / 3.

| Outcome | Tier | Effect (w6m) | Inspace rank | Inspace p | Mag (pre-SD) | Persist | Pre-trend p | Pre corr | Pre R2 | afitw | LOO rank (rob.) | LOO p (rob.) | LOO sign (rob.) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Varejo MA6 (log) | weak | +3.1% | 5/25 | 0.200 | 1.60 | 0.95 | 0.51 | 0.99 | 0.98 |  | 1/25 | 0.040 | 1.00 |
| Emprego formal 6m (per 1k) | weak | -0.0 | 24/25 | 0.960 | 0.24 | 0.84 | 0.18 | 0.88 | 0.77 |  | 5/25 | 0.200 | 1.00 |
| ICMS CONFAZ 6m pc (log) | weak | -0.2% | 25/25 | 1.000 | 0.22 | 0.84 | 0.70 | 0.97 | 0.93 |  | 22/25 | 0.160 | 0.92 |

### Nova Estrategia (Alcance x Duracao)

- **Alcance**: Nulo
- **Duracao**: Transitorio

| Variable | Affected |
| --- | --- |
| Retail MA6 (log) | FALSE |
| ICMS CONFAZ 6m per capita (log) | FALSE |
| Formal hiring 6m per 1k residents | FALSE |
