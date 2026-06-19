# SC_2020_01 results report (nova estrategia v2, k=6)

Generated on 2026-06-19.

Treated state: `SC`. Removal: `2020-10-24`.


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
Ridge penalty by LOO-CV (cross-validation, not the donor placebo).
Significance: in-space donor placebo (Abadie-Diamond-Hainmueller). LOO donor-exclusion placebo is a robustness check, not the significance criterion.

## Preliminary plots

![preliminary_main_outcomes.png](report/figures/preliminary_main_outcomes.png)

## Covariate and pre-treatment balance

### Pre-treatment outcome fit

| Outcome | Treated | Synthetic | RMSPE pre | Pre periods |
| --- | --- | --- | --- | --- |
| Varejo MA6 (log) | 4.49 | 4.49 | 0.00 | 31 |
| Emprego formal 6m (per 1k) | 1.36 | 1.27 | 1.12 | 31 |
| ICMS CONFAZ 6m pc (log) | 7.35 | 7.35 | 0.01 | 31 |

### Covariate balance

| Covariate | Treated | Varejo MA6 (log) | Emprego formal 6m (per 1k) | ICMS CONFAZ 6m pc (log) |
| --- | --- | --- | --- | --- |
| Unemployment rate |     0.051 |     0.076 |     0.070 |     0.070 |
| Formalization rate |     0.731 |     0.643 |     0.668 |     0.670 |
| Labor income (real) | 3,573.200 | 3,490.250 | 3,573.993 | 3,579.382 |
| Transfer dependency ratio |     0.046 |     0.065 |     0.056 |     0.057 |
| Health expenditure pc |   111.891 |   116.169 |   109.499 |   120.663 |
| Education expenditure pc |   116.595 |   159.529 |   180.033 |   132.460 |
| Public security expenditure pc |    80.820 |   108.281 |    84.095 |    87.517 |

## Main results: Augmented SCM

| Channel | Outcome | Mean gap (w6m) | RMSPE pre | Donors |
| --- | --- | --- | --- | --- |
| Household consumption | Retail volume, MA6 trailing, log |  0.05 | 0.00 | 22 |
| Formal labor market | Net formal hiring, 6m sum, per 1,000 residents |  4.77 | 1.12 | 22 |
| State public finances | ICMS CONFAZ per capita, 6m sum, log BRL/resident | -0.02 | 0.01 | 22 |

![att_summary.png](report/figures/att_summary.png)

![paths_main_outcomes.png](report/figures/paths_main_outcomes.png)

![gaps_main_outcomes.png](report/figures/gaps_main_outcomes.png)

### ATT by window

| Outcome | w3m | w6m | w12m | w24m |
| --- | --- | --- | --- | --- |
| Varejo MA6 (log) | 0.05 | 0.05 | 0.02 | 0.01 |
| Emprego formal 6m (per 1k) | 4.12 | 4.77 | 3.11 | 2.41 |
| ICMS CONFAZ 6m pc (log) | -0.01 | -0.02 | -0.05 | -0.02 |

## Donor weights

![weights_main_outcomes.png](report/figures/weights_main_outcomes.png)

## Placebo in-space (criterio principal)

Cada doador refeito como se fosse o tratado; classic_p = ranking da razao RMSPE pos/pre do tratado real entre tratado+placebos. Com pool de doadores pequeno, o ranking e mais informativo que o p continuo (p minimo possivel ~= 1/N).

| Outcome | Rank | p (classico) |
| --- | --- | --- |
| Varejo MA6 (log) | 6 / 23 | 0.260869565217391 |
| Emprego formal 6m (per 1k) | 9 / 23 | 0.391304347826087 |
| ICMS CONFAZ 6m pc (log) | 6 / 23 | 0.260869565217391 |

## Robustez: placebo LOO por doador

Exclusao de um doador por vez, mantendo o tratado real fixo -- testa estabilidade ao doador, nao significancia (nao e usado para classificar tier).

| Outcome | Gap post | LOO rank | p (2-sided) |
| --- | --- | --- | --- |
| Varejo MA6 (log) | 0.014 | 1 / 23 | 0.043 |
| Emprego formal 6m (per 1k) | 2.41 | 1 / 23 | 0.043 |
| ICMS CONFAZ 6m pc (log) | -0.02 | 1 / 23 | 0.043 |

## Evidence classification

Tier: placebo in-space (criterio principal). Thresholds: log >= 0.05; formal_hiring_6m_per1k >= 0.5 (per 1k residents). Poor fit: pre corr < 0.70.

Considerable: **0** / 3.

| Outcome | Tier | Effect (w6m) | Inspace rank | Inspace p | Mag (pre-SD) | Persist | Pre-trend p | Pre corr | Pre R2 | afitw | LOO rank (rob.) | LOO p (rob.) | LOO sign (rob.) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Varejo MA6 (log) | weak | +5.0% | 6/23 | 0.261 | 0.28 | 0.68 | 0.34 | 1.00 | 0.99 |  | 1/23 | 0.043 | 1.00 |
| Emprego formal 6m (per 1k) | weak | +4.8 | 9/23 | 0.391 | 0.42 | 0.95 | 0.54 | 0.98 | 0.96 |  | 1/23 | 0.043 | 1.00 |
| ICMS CONFAZ 6m pc (log) | weak | -2.3% | 6/23 | 0.261 | 0.33 | 0.74 | 0.75 | 0.98 | 0.95 |  | 1/23 | 0.043 | 0.00 |

### Nova Estrategia (Alcance x Duracao)

- **Alcance**: Nulo
- **Duracao**: Transitorio

| Variable | Affected |
| --- | --- |
| Retail MA6 (log) | FALSE |
| ICMS CONFAZ 6m per capita (log) | FALSE |
| Formal hiring 6m per 1k residents | FALSE |
