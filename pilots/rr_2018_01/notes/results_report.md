# Relatorio de Resultados do Piloto RR 2018

Este relatorio consolida os resultados do piloto `RR_2018_01`, baseado na intervencao federal em Roraima iniciada em `2018-12-10`.

## 1. Desenho do Piloto

Evento:

- `RR_2018_01`
- UF tratada: `RR`
- Governadora: Suely Campos
- Tipo de evento: intervencao federal
- Data do evento: `2018-12-10`
- Classe analitica: `extended`

Regra temporal:

- Primeiro mes tratado nas series mensais: `2019-01`
- Mes de transicao excluido: `2018-12`
- Janela pre-tratamento mensal: `2016-01` a `2018-11`
- Janela pos-tratamento mensal principal: `2019-01` a `2020-12`
- Janela pos-tratamento de robustez: `2019-01` a `2019-12`

Grupo doador principal:

- Todas as UFs exceto `RR`, `AM` e `TO`.

Racional:

- `RR` e a unidade tratada.
- `AM` tem evento proximo no pre-tratamento: `AM_2017_01`.
- `TO` tem eventos multiplos e proximo ao evento de RR, especialmente `TO_2018_01`.

## 2. Dados Montados

Scripts principais:

- `pilots/rr_2018_01/code/01_build_rr_pilot_panels.R`
- `pilots/rr_2018_01/code/02_run_monthly_scm.R`
- `pilots/rr_2018_01/code/03_run_monthly_scm_moving_average.R`
- `pilots/rr_2018_01/code/04_run_employment_alternative_specs.R`
- `pilots/rr_2018_01/code/05_compare_employment_specs.R`
- `pilots/rr_2018_01/code/06_run_employment_ridge_scm.R`
- `pilots/rr_2018_01/code/07_run_activity_ridge_scm.R`
- `pilots/rr_2018_01/code/08_run_augmented_scm.R`

Paineis analiticos:

- `pilots/rr_2018_01/data/rr_2018_01_monthly_panel.csv`
- `pilots/rr_2018_01/data/rr_2018_01_fiscal_bimonthly_panel.csv`

Validacao do painel mensal:

- 35 meses pre-tratamento.
- 24 meses pos-tratamento.
- 27 UFs em todos os meses.
- 24 UFs no grupo doador principal.
- Sem missing values nos outcomes e covariaveis mensais selecionadas:
  - `formal_hiring_balance`
  - `retail_volume_index`
  - `services_volume_index`
  - `unemployment_rate_pnadc`
  - `formalization_rate_pnadc`

Nota sobre PNADc:

- `2018Q4` foi marcado como trimestre de transicao.
- Os meses `2018-10` e `2018-11` permanecem no pre-tratamento mensal.
- Covariaveis PNADc de `2018Q4` foram marcadas com `pnadc_predictor_valid = FALSE` para nao entrarem como preditores.

## 3. SCM Classico Mensal

Metodo:

- SCM classico.
- Pesos nao negativos.
- Pesos somam 1.
- Unidade sintetica e combinacao convexa dos doadores.

Outcomes:

- `formal_hiring_balance`
- `retail_volume_index`
- `services_volume_index`

### 3.1 Pesos dos Doadores

`formal_hiring_balance`:

| UF | Peso |
| --- | ---: |
| MS | 0.583 |
| PA | 0.135 |
| AP | 0.104 |
| ES | 0.086 |
| MA | 0.086 |
| SC | 0.005 |

`retail_volume_index`:

| UF | Peso |
| --- | ---: |
| MS | 0.368 |
| PA | 0.298 |
| ES | 0.228 |
| AP | 0.106 |

`services_volume_index`:

| UF | Peso |
| --- | ---: |
| MG | 0.504 |
| SC | 0.329 |
| PA | 0.118 |
| SP | 0.049 |

### 3.2 Ajuste e Gaps

| Outcome | Pre RMSPE | Pos RMSPE | Pos/pre RMSPE | Gap medio pos |
| --- | ---: | ---: | ---: | ---: |
| `formal_hiring_balance` | 1,685.1 | 3,103.6 | 1.84 | -638.8 |
| `retail_volume_index` | 5.10 | 4.43 | 0.87 | -2.79 |
| `services_volume_index` | 6.20 | 7.62 | 1.23 | -6.14 |

Ranking placebo por post/pre RMSPE, contando RR mais placebos:

| Outcome | Ranking RR |
| --- | ---: |
| `formal_hiring_balance` | 5 de 25 |
| `retail_volume_index` | 24 de 25 |
| `services_volume_index` | 13 de 25 |

Leitura:

- Emprego e o sinal mais forte no SCM classico, mas o ajuste pre ainda e ruim.
- Varejo nao mostra sinal forte no SCM classico.
- Servicos mostram gap negativo, mas com ranking placebo intermediario.

## 4. Medias Moveis e Transformacoes do Emprego

A motivacao foi a alta variabilidade mensal, especialmente em `formal_hiring_balance`.

### 4.1 Medias Moveis

| Outcome | Versao | Pre RMSPE | Pos RMSPE | Pos/pre RMSPE |
| --- | --- | ---: | ---: | ---: |
| `formal_hiring_balance` | nivel | 1,685.1 | 3,103.6 | 1.84 |
| `formal_hiring_balance` | MM 3m | 979.4 | 2,415.0 | 2.47 |
| `formal_hiring_balance` | MM 6m | 573.4 | 1,866.2 | 3.25 |
| `retail_volume_index` | nivel | 5.10 | 4.43 | 0.87 |
| `retail_volume_index` | MM 3m | 4.32 | 3.88 | 0.90 |
| `retail_volume_index` | MM 6m | 3.39 | 3.45 | 1.02 |
| `services_volume_index` | nivel | 6.20 | 7.62 | 1.23 |
| `services_volume_index` | MM 3m | 4.51 | 6.46 | 1.43 |
| `services_volume_index` | MM 6m | 3.74 | 6.47 | 1.73 |

Leitura:

- Medias moveis melhoram o ajuste pre em todos os outcomes.
- A melhora e mais forte em emprego e servicos.
- A media movel de 6 meses melhora bastante o pre de emprego, mas muda a interpretacao para uma trajetoria suavizada.

### 4.2 Alternativas Para Emprego

Foram testadas tres alternativas:

1. outcome em nivel com preditores semestrais;
2. saldo acumulado movel em 6 meses;
3. saldo acumulado desde `2016-01`.

Comparacao normalizada, usando RMSPE pre dividido pelo desvio-padrao pre de RR:

| Especificacao | Pre RMSPE / SD pre de RR | Correlacao pre | Pos/pre RMSPE |
| --- | ---: | ---: | ---: |
| MM 6 meses | 5.91 | 0.00 | 3.25 |
| soma movel 6 meses | 6.00 | -0.01 | 3.28 |
| MM 3 meses | 6.31 | 0.34 | 2.47 |
| baseline mensal | 7.05 | 0.39 | 1.84 |
| acumulado desde 2016 | 8.43 | 0.10 | 2.74 |
| preditores semestrais | 10.29 | 0.37 | 1.50 |

Leitura:

- A suavizacao em 6 meses e a soma movel em 6 meses melhoram o ajuste relativo.
- Preditores semestrais pioram o ajuste.
- Acumulado desde `2016-01` nao parece uma boa especificacao principal.

## 5. Ridge Diagnostico

Foi estimada uma versao ridge como diagnostico.

Importante:

- Ridge permite coeficientes negativos.
- Os coeficientes nao precisam somar 1.
- Portanto, nao e SCM classico.
- A interpretacao e de contrafactual regularizado, nao de unidade sintetica convexa.

### 5.1 Emprego

| Outcome | Pre RMSPE | Pos RMSPE | Pos/pre RMSPE |
| --- | ---: | ---: | ---: |
| `formal_hiring_balance` | 102.7 | 352.3 | 3.43 |
| `formal_hiring_balance_ma6` | 15.5 | 267.3 | 17.21 |
| `formal_hiring_balance_6m_sum` | 56.0 | 1,363.6 | 24.33 |

Leitura:

- Ridge melhora drasticamente o ajuste pre de emprego.
- O custo e interpretativo, pois os coeficientes tem sinais mistos.

### 5.2 Varejo e Servicos

| Outcome | Pre RMSPE | Pos RMSPE | Pos/pre RMSPE | Gap medio pos |
| --- | ---: | ---: | ---: | ---: |
| `retail_volume_index` | 3.85 | 9.60 | 2.50 | 7.57 |
| `retail_volume_index_ma6` | 0.24 | 13.61 | 56.63 | 10.15 |
| `services_volume_index` | 1.55 | 5.98 | 3.85 | -3.59 |
| `services_volume_index_ma6` | 0.18 | 4.62 | 25.68 | -2.56 |

Leitura:

- Ridge melhora o ajuste pre em varejo e servicos.
- Em servicos, o sinal negativo permanece.
- Em varejo, ridge puro inverte o sinal em relacao ao SCM classico: passa a sugerir gap positivo.
- Essa inversao e um alerta de extrapolacao. Varejo ridge nao deve ser usado como evidencia substantiva sem cautela.

## 6. Augmented SCM

Foi implementada uma versao mais formal de Augmented SCM:

1. estima primeiro o SCM classico convexo;
2. calcula o desbalanceamento entre RR e RR sintetico nos preditores;
3. aplica uma correcao ridge ao contrafactual.

Esta abordagem e mais interpretavel que o ridge puro, porque preserva o SCM classico como ponto de partida.

Output principal:

- `pilots/rr_2018_01/output/augmented_scm_monthly/`

### 6.1 Ajuste Pre e Pos

| Outcome | SCM pre RMSPE | Augmented pre RMSPE | SCM pos RMSPE | Augmented pos RMSPE |
| --- | ---: | ---: | ---: | ---: |
| `formal_hiring_balance` | 828.5 | 273.6 | 1,540.1 | 542.5 |
| `formal_hiring_balance_ma6` | 361.5 | 33.4 | 1,044.0 | 388.6 |
| `retail_volume_index` | 5.06 | 2.62 | 4.46 | 6.55 |
| `retail_volume_index_ma6` | 3.36 | 0.37 | 3.30 | 3.39 |
| `services_volume_index` | 6.21 | 2.14 | 7.28 | 8.92 |
| `services_volume_index_ma6` | 3.78 | 0.31 | 6.26 | 5.02 |

Leitura:

- Augmented SCM melhora o ajuste pre para todos os outcomes.
- A melhora e grande para emprego, servicos e versoes suavizadas.
- Ao contrario do ridge puro, o resultado de varejo fica menos extremo.

### 6.2 Gaps Medios Pos-Tratamento Por Ano

| Outcome | Gap aumentado 2019 | Gap aumentado 2020 |
| --- | ---: | ---: |
| `formal_hiring_balance` | -152.1 | -84.4 |
| `formal_hiring_balance_ma6` | -332.1 | 188.3 |
| `retail_volume_index` | 0.47 | -5.63 |
| `retail_volume_index_ma6` | 2.08 | -2.64 |
| `services_volume_index` | -1.57 | -9.68 |
| `services_volume_index_ma6` | -2.23 | -6.34 |

Leitura substantiva:

- Emprego em nivel fica negativo em 2019 e 2020.
- Emprego com MM 6 meses fica negativo em 2019, mas positivo em 2020; portanto, a versao suavizada de emprego e sensivel ao periodo.
- Varejo fica praticamente neutro em 2019 e negativo em 2020.
- Servicos ficam negativos em 2019 e 2020, tanto em nivel quanto em MM 6 meses.

## 7. Interpretacao Substantiva Provisoria

Os resultados ainda sao de piloto e nao devem ser lidos como estimativas finais.

Padroes mais consistentes:

- Servicos parecem o outcome economico mais consistentemente negativo.
- Emprego em nivel tambem sugere efeito negativo no Augmented SCM.
- Varejo e instavel: SCM classico sugere gap negativo; ridge puro sugere positivo; Augmented SCM sugere neutro em 2019 e negativo em 2020.

Padroes menos confiaveis:

- Ridge puro em varejo parece extrapolar.
- Medias moveis com ridge produzem ajuste pre quase perfeito, mas isso aumenta mecanicamente os ratios pos/pre e reduz interpretabilidade.

## 8. Hierarquia Empirica Atual

A hierarquia atual do piloto passa a priorizar uma narrativa economica mais concentrada em mercado de trabalho formal.

Outcome economico principal:

- `formal_hiring_balance`.

Especificacao principal:

- Augmented SCM em nivel.

Robustez principal de suavizacao:

- Augmented SCM com media movel de 6 meses pos-tratamento limpa, reiniciando a janela em `2019-01`.

Baseline/diagnostico transparente:

- SCM classico.

Outcomes economicos secundarios:

- `retail_volume_index` e `services_volume_index` deixam de fazer parte da hierarquia principal.
- Podem permanecer como material exploratorio ou apendice, mas nao devem organizar a narrativa central do piloto.

Metodos abandonados como rotas ativas:

- Ridge diagnostics.
- Nonlinear SCM.

Esses metodos foram uteis para diagnostico, mas adicionam complexidade interpretativa. No caso do Nonlinear SCM, os resultados para emprego formal foram sensiveis a escala e nao fortaleceram a evidencia principal. No caso do ridge, a extrapolacao e os pesos com sinais mistos reduzem a interpretabilidade.

Extensoes PNADc ainda pendentes:

- renda real de todos os trabalhos;
- possivelmente taxa de desemprego;
- possivelmente taxa de formalizacao.

Esses outcomes trimestrais ainda precisam ser testados antes de qualquer decisao sobre inclusao no corpo principal do artigo.

## 9. Proximos Passos

Antes de transformar o piloto em resultado de artigo:

1. Inspecionar visualmente os graficos:
   - `*_treated_scm_augmented.png`
   - `*_gaps.png`
2. Rodar placebos adaptados para Augmented SCM.
3. Produzir tabelas compactas de gaps por ano para emprego formal.
4. Testar outcomes trimestrais PNADc, especialmente renda real de todos os trabalhos.
5. Repetir o desenho para outcomes fiscais bimestrais, se a narrativa fiscal permanecer no escopo.
6. Decidir se o caso `RR_2018_01` sera apresentado como piloto exploratorio ou como parte do conjunto principal/extendido de resultados.

## 10. Arquivos Principais de Saida

SCM classico:

- `pilots/rr_2018_01/output/scm_monthly/`

Medias moveis:

- `pilots/rr_2018_01/output/scm_monthly_moving_average/`

Alternativas de emprego:

- `pilots/rr_2018_01/output/employment_alternative_specs/`

Ridge diagnostico:

- `pilots/rr_2018_01/output/employment_ridge_scm/`
- `pilots/rr_2018_01/output/activity_ridge_scm/`

Nonlinear SCM:

- `pilots/rr_2018_01/output/nonlinear_scm_monthly/`
- `pilots/rr_2018_01/output/nonlinear_scm_monthly_employment_per_100k/`

These outputs are retained as exploratory diagnostics but are no longer active routes in the preferred hierarchy.

Augmented SCM:

- `pilots/rr_2018_01/output/augmented_scm_monthly/`
- `pilots/rr_2018_01/output/augmented_scm_monthly_post_clean/`
