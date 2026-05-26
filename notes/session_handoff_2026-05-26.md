# Handoff da Sessao - 2026-05-26

Este arquivo registra a retomada e conclusao operacional do bloco Novo CAGED ajustado em 2026-05-26.

## O que foi retomado

O handoff anterior indicava que o download do Novo CAGED ajustado havia sido interrompido durante o lote iniciado em 2025.

Ao retomar, foi verificado que:

- os arquivos estavam completos de `2020-01` a `2025-07`;
- `2025-08` tinha `CAGEDFOR` e `CAGEDEXC`, mas `CAGEDMOV202508.7z` estava truncado;
- `2025-09` a `2026-02` ainda nao estavam presentes;
- `2026-03` ja existia por teste anterior.

## Download concluido

Foi removido o arquivo parcial:

- `data/raw/mte/CAGEDMOV202508.7z`

Depois foi executado:

```powershell
$env:CAGED_START_MONTH='2025-08'
$env:CAGED_END_MONTH='2026-03'
& 'C:\Users\yuri.silva\AppData\Local\Programs\R\R-4.4.2\bin\Rscript.exe' -e "source('code/01_download_data/02h_download_novo_caged_adjusted_archives.R')"
```

Resultado:

- `CAGEDMOV202508.7z` foi rebaixado com tamanho consistente;
- `2025-09` a `2026-02` foram baixados para `CAGEDMOV`, `CAGEDFOR` e `CAGEDEXC`;
- `2026-03` foi mantido como `already_present`;
- o log foi salvo em `data/raw/mte/novo_caged_adjusted_download_results.csv`.

Resumo do log:

- `19` arquivos baixados;
- `5` arquivos ja presentes.

## Parser executado

Foi executado:

```powershell
& 'C:\Users\yuri.silva\AppData\Local\Programs\R\R-4.4.2\bin\Rscript.exe' -e "source('code/01_download_data/02i_parse_novo_caged_adjusted.R')"
```

Arquivos gerados:

- `data/raw/mte/novo_caged_adjusted_state_balance_monthly_components.csv`
- `data/raw/mte/novo_caged_adjusted_state_balance_monthly.csv`

Cobertura observada do Novo CAGED ajustado:

- `2020-01` a `2026-03`;
- `75` meses;
- `28` linhas por competencia no arquivo bruto ajustado, sendo `27` UFs identificadas mais a categoria nao identificada filtrada no painel.

## Base CAGED final gerada

Foi executado:

```powershell
& 'C:\Users\yuri.silva\AppData\Local\Programs\R\R-4.4.2\bin\Rscript.exe' -e "source('code/01_build_panel/05_process_caged_state_balance_final.R')"
```

Arquivos gerados:

- `data/processed/caged_state_balance_monthly_processed.csv`
- `data/processed/caged_state_balance_monthly_panel_ready.csv`

Validacao da base panel-ready:

- periodo: `2007-01` a `2026-03`;
- `231` meses;
- `27` UFs por mes;
- `6237` linhas no total (`231 x 27`).

Composicao do arquivo processado completo:

- `4212` linhas de `old_caged`;
- `2100` linhas de `novo_caged`.

## Estado metodologico atual

A base CAGED mensal estadual esta operacionalmente pronta para uso exploratorio e para montagem de especificacoes com controle explicito da quebra metodologica de 2020.

Campos de quebra incluidos na base final:

- `post_2020_caged_dummy`
- `caged_method_break_dummy`

Recomendacao metodologica permanece:

- distinguir resultados de emprego formal dos resultados de PMC/PMS;
- reportar a quebra Old CAGED/Novo CAGED explicitamente;
- em casos recentes, considerar uma especificacao de robustez usando apenas o periodo Novo CAGED quando a janela permitir.

## Fechamento formal do bloco CAGED

Ainda em 2026-05-26, foi criado e executado:

- `code/01_build_panel/06_validate_caged_final.R`

O script validou:

- cobertura mensal de `2007-01` a `2026-03`;
- `27` UFs identificadas por mes no arquivo panel-ready;
- ausencia de duplicatas em `competencia x state_abbrev`;
- separacao esperada entre `old_caged` e `novo_caged`;
- consistencia de `post_2020_caged_dummy` e `caged_method_break_dummy`.

Arquivos de validacao gerados:

- `output/validation/caged_final_validation_summary.csv`
- `output/validation/caged_final_monthly_coverage.csv`
- `output/validation/caged_final_uf_pre_post_2020_summary.csv`
- `output/validation/caged_final_source_composition.csv`

Nota de fechamento:

- `notes/caged_final_validation.md`

Resultado: o bloco CAGED esta fechado para a proxima etapa. O proximo bloco planejado e PNADc trimestral.
