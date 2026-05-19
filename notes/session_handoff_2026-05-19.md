# Handoff da Sessao - 2026-05-19

Este arquivo registra o ponto de parada do bloco CAGED em 2026-05-19. O usuario precisou desligar a maquina durante o download do Novo CAGED ajustado.

## Prioridade ao retomar

Continuar o bloco CAGED a partir do Novo CAGED ajustado. O Old CAGED pre-2020 ja foi consolidado com uma regra operacional reproduzivel.

## O que foi concluido

### Old CAGED completo 2007-2019

Foi criada e executada a rotina:

- `code/01_download_data/02n_build_old_caged_complete_with_bd_patch.R`

Regra aplicada:

- usar `CAGEDEST_MMYYYY.7z` do FTP oficial quando o arquivo passa no teste de integridade;
- usar `basedosdados.br_me_caged.microdados_antigos` como patch somente para meses cujo `.7z` oficial continua corrompido.

Arquivos gerados:

- `data/raw/mte/old_caged_complete_state_balance_monthly.csv`
- `data/raw/mte/old_caged_complete_state_balance_monthly_final.csv`
- `data/raw/mte/old_caged_complete_state_balance_monthly_final_coverage.csv`

Cobertura validada:

- `2007-01` a `2019-12`
- `156` meses
- `27` UFs por mes
- `4212` linhas no total (`156 x 27`)

Composicao da base:

- `3267` linhas de arquivos oficiais FTP integros;
- `945` linhas do patch Base dos Dados (`35` meses x `27` UFs).

### Base dos Dados

Foi criada e executada a rotina:

- `code/01_download_data/02m_query_old_caged_basedosdados_state_balance.R`

Configuracao usada:

- billing project: `teste-ufrr`
- email autenticado: `yuricesar15silva@gmail.com`
- escopo: `failed_months`

Arquivos gerados:

- `data/raw/mte/old_caged_basedosdados_state_balance_monthly_failed_months.csv`
- `data/raw/mte/old_caged_basedosdados_state_balance_coverage_failed_months.csv`
- `data/raw/mte/old_caged_basedosdados_state_balance_query_failed_months.sql`

Resultado:

- `945` linhas retornadas;
- `35` meses;
- `27` UFs em cada mes.

## Novo CAGED ajustado: estado parcial

O download de:

- `code/01_download_data/02h_download_novo_caged_adjusted_archives.R`

foi iniciado para:

- `CAGED_START_MONTH=2020-01`
- `CAGED_END_MONTH=2026-03`

mas foi interrompido pelo usuario antes de terminar e antes de sobrescrever corretamente `data/raw/mte/novo_caged_adjusted_download_results.csv`.

Portanto, o CSV de log `novo_caged_adjusted_download_results.csv` ainda nao reflete o download parcial atual; ele continua mostrando apenas o teste antigo de `2026-03`.

Arquivos Novo CAGED efetivamente presentes apos a interrupcao:

- `2020-01`: apenas `CAGEDMOV`
- `2020-02` a `2020-03`: `CAGEDMOV` e `CAGEDFOR`
- `2020-04` a `2025-06`: `CAGEDMOV`, `CAGEDFOR` e `CAGEDEXC`
- `2026-03`: `CAGEDMOV`, `CAGEDFOR` e `CAGEDEXC` do teste anterior

O download aparentemente foi interrompido logo apos `CAGEDMOV202506.7z`.

## Como retomar o Novo CAGED

Recomendacao para evitar rebaixar tudo:

```powershell
$env:CAGED_START_MONTH='2025-07'
$env:CAGED_END_MONTH='2026-03'
& 'C:\Users\yuri.silva\AppData\Local\Programs\R\R-4.4.2\bin\Rscript.exe' -e "source('code/01_download_data/02h_download_novo_caged_adjusted_archives.R')"
```

Depois, rodar o parser:

```powershell
& 'C:\Users\yuri.silva\AppData\Local\Programs\R\R-4.4.2\bin\Rscript.exe' -e "source('code/01_download_data/02i_parse_novo_caged_adjusted.R')"
```

Observacao importante:

- `2020-01` nao deve ter `CAGEDEXC`;
- `2020-02` e `2020-03` podem nao ter `CAGEDEXC`;
- se o downloader marcar alguns componentes como `not_available`, isso pode ser correto historicamente, mas precisa ficar documentado no log final.

## Passos pendentes

1. Retomar download do Novo CAGED ajustado de `2025-07` a `2026-03`.
2. Rodar `02i_parse_novo_caged_adjusted.R`.
3. Validar a cobertura do Novo CAGED ajustado:
   - quantos meses;
   - quantas UFs por competencia;
   - quais meses dependem de movimentos fora do prazo e exclusoes declaradas depois.
4. Rodar:
   - `code/01_build_panel/05_process_caged_state_balance_final.R`
5. Validar a base final:
   - `data/processed/caged_state_balance_monthly_processed.csv`
   - `data/processed/caged_state_balance_monthly_panel_ready.csv`

## Arquivos modificados/criados nesta sessao

Scripts:

- `code/01_download_data/02m_query_old_caged_basedosdados_state_balance.R`
- `code/01_download_data/02n_build_old_caged_complete_with_bd_patch.R`
- `code/01_download_data/README.md`

Notas:

- `notes/caged_pre2020_source_diagnostic_2026-05-19.md`
- `notes/caged_final_base_roadmap.md`
- `notes/session_handoff_2026-05-19.md`

Dados pequenos gerados e candidatos a versionamento:

- `data/raw/mte/old_caged_basedosdados_state_balance_monthly_failed_months.csv`
- `data/raw/mte/old_caged_basedosdados_state_balance_coverage_failed_months.csv`
- `data/raw/mte/old_caged_basedosdados_state_balance_query_failed_months.sql`

Dados brutos grandes continuam ignorados pelo git:

- `data/raw/mte/CAGEDEST*.7z`
- `data/raw/mte/CAGEDMOV*.7z`
- `data/raw/mte/CAGEDFOR*.7z`
- `data/raw/mte/CAGEDEXC*.7z`

## Estado metodologico

Old CAGED esta operacionalmente completo para `2007-2019`, mas a regra final deve ser descrita no paper como:

- microdados oficiais do FTP para meses integros;
- Base dos Dados como patch para meses em que os arquivos oficiais disponiveis no FTP falham em descompressao;
- serie ainda sujeita a validacao contra agregados oficiais anuais/acumulados.

Novo CAGED ainda nao esta completo. A base CAGED final ainda nao deve ser usada no paper ate finalizar os passos pendentes acima.
