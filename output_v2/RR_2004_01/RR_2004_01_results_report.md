# RR_2004_01 results report (nova estrategia v2, k=6)

Generated on 2026-06-19.

Treated state: `RR`. Removal: `2004-11-10`.


**Nota**: emprego formal (CAGED) nao incluido neste evento -- a cobertura mensal do CAGED (a partir de 2007-01) nao alcanca a janela pre-tratamento exigida (5 blocos semestrais, ~35 meses). Teto de classificacao de Alcance = Ampliado.

## Window design

- Accumulation window: **k = 6** for all outcomes.
  - Retail: trailing 6-month mean, log (`retail_ma6_log`)
  - ICMS: CONFAZ monthly per capita (BRL/resident), 6m sum, log (`icms_conf6m_pc_log`)
- Opcao B (k=6): first clean post-treatment reading at event_time = +5.
- Pre-treatment blocks: 5 non-overlapping semi-annual blocks [-30,-25], [-24,-19], [-18,-13], [-12,-7], [-6,-1].
  Valid pre-treatment window: event_time -31 to -1 (31 months; first 5 observations are NA due to k=6 initialization).
- ATT windows: w3m [+5,+7], w6m [+5,+10], w12m [+5,+16], w24m [+5,+28].

## Methodological strategy

Donor pool excludes `PI`, `RR` (25 eligible donors).
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
| Varejo MA6 (log) | 3.25 | 3.26 | 0.02 | 31 |
| ICMS CONFAZ 6m pc (log) | 5.22 | 5.22 | 0.03 | 31 |

### Covariate balance

| Covariate | Treated | Varejo MA6 (log) | ICMS CONFAZ 6m pc (log) |
| --- | --- | --- | --- |
| ICMS secondary VA pc |   2.915 |  3.072 |  3.876 |
| ICMS tertiary VA pc |  17.299 | 19.862 | 29.908 |
| ICMS energy VA pc |   1.220 |  1.968 |  2.233 |
| ICMS fuels VA pc |   9.265 |  6.679 |  6.324 |
| FPE transfer pc | 120.770 | 65.380 | 61.294 |
| IOF-state pc |   0.004 |  0.007 |  0.007 |

## Main results: Augmented SCM

| Channel | Outcome | Mean gap (w6m) | RMSPE pre | Donors |
| --- | --- | --- | --- | --- |
| Household consumption | Retail volume, MA6 trailing, log | -0.29 | 0.02 | 25 |
| State public finances | ICMS CONFAZ per capita, 6m sum, log BRL/resident |  0.15 | 0.03 | 25 |

![att_summary.png](report/figures/att_summary.png)

![paths_main_outcomes.png](report/figures/paths_main_outcomes.png)

![gaps_main_outcomes.png](report/figures/gaps_main_outcomes.png)

### ATT by window

| Outcome | w3m | w6m | w12m | w24m |
| --- | --- | --- | --- | --- |
| Varejo MA6 (log) | -0.25 | -0.29 | -0.30 | -0.29 |
| ICMS CONFAZ 6m pc (log) | 0.15 | 0.15 | 0.12 | 0.14 |

## Donor weights

![weights_main_outcomes.png](report/figures/weights_main_outcomes.png)

## Placebo in-space (criterio principal)

Cada doador refeito como se fosse o tratado; classic_p = ranking da razao RMSPE pos/pre do tratado real entre tratado+placebos. Com pool de doadores pequeno, o ranking e mais informativo que o p continuo (p minimo possivel ~= 1/N).

| Outcome | Rank | p (classico) |
| --- | --- | --- |
| Varejo MA6 (log) | 16 / 26 | 0.615384615384615 |
| ICMS CONFAZ 6m pc (log) | 10 / 26 | 0.384615384615385 |

## Robustez: placebo LOO por doador

Exclusao de um doador por vez, mantendo o tratado real fixo -- testa estabilidade ao doador, nao significancia (nao e usado para classificar tier).

| Outcome | Gap post | LOO rank | p (2-sided) |
| --- | --- | --- | --- |
| Varejo MA6 (log) | -0.291 | 26 / 26 | 0.038 |
| ICMS CONFAZ 6m pc (log) | 0.14 | 26 / 26 | 0.038 |

## Evidence classification

Tier: placebo in-space (criterio principal). Thresholds: log >= 0.05; formal_hiring_6m_per1k >= 0.5 (per 1k residents). Poor fit: pre corr < 0.70.

Considerable: **0** / 2.

| Outcome | Tier | Effect (w6m) | Inspace rank | Inspace p | Mag (pre-SD) | Persist | Pre-trend p | Pre corr | Pre R2 | afitw | LOO rank (rob.) | LOO p (rob.) | LOO sign (rob.) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Varejo MA6 (log) | weak | -25.2% | 16/26 | 0.615 | 3.00 | 1.00 | 0.17 | 0.98 | 0.95 |  | 26/26 | 0.038 | 1.00 |
| ICMS CONFAZ 6m pc (log) | weak | +15.9% | 10/26 | 0.385 | 3.27 | 1.00 | 0.90 | 0.80 | 0.46 |  | 26/26 | 0.038 | 0.92 |

### Nova Estrategia (Alcance x Duracao)

- **Alcance**: Nulo
- **Duracao**: Transitorio

| Variable | Affected |
| --- | --- |
| Retail MA6 (log) | FALSE |
| ICMS CONFAZ 6m per capita (log) | FALSE |
| Formal hiring 6m per 1k residents | NA (CAGED indisponivel) |
