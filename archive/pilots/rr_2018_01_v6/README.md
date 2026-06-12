# RR 2018-01 V6 — Nova Estratégia

Piloto da remoção de Suely Campos (Roraima, dezembro 2018) implementando
a **Nova Estratégia** definida em `Nova Estratégia - Artigo.txt`.

## Diferenças em relação ao V5

| Dimensão | V5 | V6 |
|---|---|---|
| Outcomes principais | 8 (varejo, serviços, CAGED, receitas, despesas) | 3 (retail_ma3_log, icms_2bim_log, formal_hiring_3m) |
| Transformação | MA6 segmentada (V5-rule) | MA3/soma 3m contínua (sem segmentação); ICMS: exp → soma 2-bim → log |
| Preditores SCM | Trajetória pré-tratamento completa + covariáveis | Médias em blocos de event-time + covariáveis |
| Leitura pós | Imediata (+1) | Opção B: +2 mensal, +1 bimestral |
| Classificação | Não implementada | Alcance × Duração |

## Fonte de dados

Todos os painéis são lidos de `output/RR_2018_01/data/` (engine principal).
Nenhum dado bruto é reprocessado neste piloto.

## Scripts — executar da raiz do projeto

```
Rscript archive/pilots/rr_2018_01_v6/code/01_build_rr_2018_01_v6_panels.R
Rscript archive/pilots/rr_2018_01_v6/code/02_run_rr_2018_01_v6_scm.R
Rscript archive/pilots/rr_2018_01_v6/code/03b_make_rr_2018_01_v6_report_figures.R
Rscript archive/pilots/rr_2018_01_v6/code/03_make_rr_2018_01_v6_report.R
```

## Outcomes

### Principais
| Variável | Transformação | Frequência | Threshold classificação |
|---|---|---|---|
| `retail_ma3_log` | MA3 backward → log | Mensal | 0.05 (log) |
| `icms_2bim_log` | exp → soma 2-bim → log | Bimestral | 0.05 (log) |
| `formal_hiring_3m` | Soma 3m (sem log) | Mensal | 15 por 100k WAP |

### Secundários (apêndice, sem transformação adicional)
- `services` — índice de volume de serviços
- `investment_siconfi` — investimento público (já em log)
- `totalexp_siconfi` — despesa total (já em log)

## Preditores (blocos de event-time)

**Mensais** (5 blocos): m36–m25, m24–m13, m12–m1, m6–m1, m3–m1  
**Bimestrais** (4 blocos): bim m23–m13, m12–m7, m6–m1, m3–m1  
Mais 7 covariáveis estruturais (desemprego, formalização, renda do trabalho,
dependência de transferências, gastos em saúde, educação, segurança pública).

## Leitura pós-tratamento (Opção B)

- Mensal: `event_time = +2` (primeiro MA3 cujos 3 meses são todos pós)
- Bimestral: `bim_event_time = +1` (primeira soma 2-bim sem bimestre pré)

## Janelas de ATT

| Frequência | Janelas |
|---|---|
| Mensal | w3m [+2,+4], w6m [+2,+7], w12m [+2,+13], w24m [+2,+25] |
| Bimestral | w4m [+1,+2], w12m [+1,+6], w24m [+1,+12] |

## Classificação Alcance × Duração

**Afetação**: |ATT médio em w6m ou w12m| ≥ threshold E sinal consistente (frac ≥ 0.5) E LOO frac ≥ 0.6

**Alcance**:
- Nulo — nenhuma variável afetada
- Restrito — só retail
- Ampliado — retail + ICMS
- Propagado — retail + ICMS + emprego formal

**Duração**:
- Transitório — efeito apenas em w3m ou w6m
- Persistente — efeito também em w12m ou w24m

## Outputs

```
data/
  rr_2018_01_v6_monthly_panel.csv
  rr_2018_01_v6_bim_panel.csv
  rr_2018_01_v6_covariates.csv
  rr_2018_01_v6_event_metadata.csv
output/
  rr_2018_01_v6_scm_summary.csv
  monthly/   <outcome>_path.csv, <outcome>_weights.csv
  bimonthly/ <outcome>_path.csv, <outcome>_weights.csv
  placebo_loo/ <outcome>_loo.csv
report/
  tables/    classification, att_by_window, loo_summary, covariate_balance, pretx_balance
  figures/   preliminary, paths, gaps, weights, att_summary
rr_2018_01_v6_results_report.md
```
