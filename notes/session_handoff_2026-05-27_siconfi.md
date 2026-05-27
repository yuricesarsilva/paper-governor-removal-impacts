# Handoff Siconfi/RREO - 2026-05-27

Este arquivo registra o ponto de parada do bloco Siconfi/RREO.

## Estado geral

O bloco PNAD/PNADc foi fechado e commitado anteriormente no commit:

```text
c792069 Close PNAD and PNADc covariate blocks
```

A frente aberta agora e Siconfi/RREO.

## Arquivos criados/alterados nesta frente

Criados/alterados, ainda nao commitados:

- `code/01_download_data/03_download_siconfi.R`
- `code/01_download_data/03a_combine_siconfi_chunks.R`
- `notes/siconfi_rreo_processing_note.md`
- `code/01_download_data/README.md`
- `data/raw/download_manifest.csv`

Tambem havia um item novo no working tree que o usuario pediu para incluir no push:

- `references/Papers - Literature/`

## Investigacao concluida

Fonte candidata:

```text
https://apidatalake.tesouro.gov.br/ords/siconfi/tt/rreo
```

Documentacao oficial registrada na nota:

- `https://www.tesourotransparente.gov.br/consultas/consultas-siconfi/siconfi-api-de-dados-abertos`
- `http://apidatalake.tesouro.gov.br/docs/siconfi/#/RREO/get_rreo`
- `https://www.tesourotransparente.gov.br/ckan/dataset/api-rreo-entes/resource/42631872-e20e-4c91-b010-9e9ca54a851b`

Anexos escolhidos para a primeira versao:

- `RREO-Anexo 01`: receitas, receita tributaria, transferencias da Uniao.
- `RREO-Anexo 02`: despesas liquidadas total, saude, educacao e seguranca publica.
- `RREO-Anexo 06`: investimentos.

Cobertura testada:

- API retorna dados para `2015` em diante.
- Testes para `2009-2014`, em RR/Anexo 01/B1, retornaram zero linhas.
- Portanto, Siconfi/RREO via esta API nao resolve covariaveis fiscais dinamicas para os casos `2009/2010`.

## Decisao sobre investimento

A conta:

```text
RREO-Anexo 06 / RREO6Investimentos / DESPESAS LIQUIDADAS
```

foi identificada como acumulada no ano, nao fluxo bimestral.

Regra definida:

```text
public_investment_liquidated_cumulative_nominal =
  valor original acumulado do Anexo 06

public_investment_liquidated_nominal =
  diferenca bimestre a bimestre dentro de UF x ano
```

Para o primeiro bimestre:

```text
public_investment_liquidated_nominal =
  public_investment_liquidated_cumulative_nominal
```

Testes usados para essa decisao:

- UFs: `RR`, `RJ`, `SC`, `TO`
- anos: `2018`, `2020`, `2024`

## Script implementado

Script criado:

```text
code/01_download_data/03_download_siconfi.R
```

Recursos implementados:

- consulta da API oficial Siconfi/RREO;
- anexos `01`, `02`, `06`;
- suporte a paginacao (`limit`/`offset`);
- registry por combinacao `ano x bimestre x UF x anexo`;
- parsing numerico corrigido para valores vindos como numero ou texto;
- deflacao por IPCA;
- derivacao de investimento bimestral por diferenca do acumulado;
- variaveis de ambiente para smoke tests/chunks:
  - `SICONFI_START_YEAR`
  - `SICONFI_END_YEAR`
  - `SICONFI_BIMESTERS`
  - `SICONFI_UF_CODES`
  - `SICONFI_OUTPUT_PREFIX`
  - `SICONFI_LIMIT`

Script combinador criado:

```text
code/01_download_data/03a_combine_siconfi_chunks.R
```

Ele combina arquivos anuais/chunked com prefixo padrao:

```text
siconfi_rreo_state_fiscal_bimonthly_????
```

e gera os arquivos finais:

```text
data/processed/siconfi_rreo_state_fiscal_bimonthly_processed.csv
data/processed/siconfi_rreo_state_fiscal_bimonthly_panel_ready.csv
data/raw/siconfi/siconfi_rreo_state_fiscal_bimonthly_download_registry.csv
data/raw/siconfi/siconfi_rreo_state_fiscal_bimonthly_annex01_raw.csv
data/raw/siconfi/siconfi_rreo_state_fiscal_bimonthly_annex02_raw.csv
data/raw/siconfi/siconfi_rreo_state_fiscal_bimonthly_annex06_raw.csv
```

## Smoke test concluido

Foi rodado um smoke test com:

```powershell
$env:SICONFI_START_YEAR='2024'
$env:SICONFI_END_YEAR='2024'
$env:SICONFI_BIMESTERS='1'
$env:SICONFI_UF_CODES='14'
$env:SICONFI_OUTPUT_PREFIX='siconfi_rreo_smoke_test'
& 'C:\Users\yuri.silva\AppData\Local\Programs\R\R-4.4.2\bin\Rscript.exe' code\01_download_data\03_download_siconfi.R
```

Resultado:

- passou;
- gerou uma linha `RR x 2024B1`;
- valores ficaram em escala correta apos correcao do parser;
- arquivos temporarios do smoke test foram removidos.

Exemplo validado:

```text
total_revenue_nominal = 1460293275.32
state_tax_revenue_nominal = 289092577.99
federal_transfers_nominal = 931625058.40
transfer_dependency_ratio = 0.6379712036
liquidated_expenditure_total_nominal = 947821069.05
public_investment_liquidated_nominal = 5220243.52
```

## Tentativa de coleta completa

Foi iniciada a coleta completa com:

```powershell
Remove-Item Env:\SICONFI_OUTPUT_PREFIX -ErrorAction SilentlyContinue
Remove-Item Env:\SICONFI_UF_CODES -ErrorAction SilentlyContinue
Remove-Item Env:\SICONFI_BIMESTERS -ErrorAction SilentlyContinue
$env:SICONFI_START_YEAR='2015'
$env:SICONFI_END_YEAR='2026'
& 'C:\Users\yuri.silva\AppData\Local\Programs\R\R-4.4.2\bin\Rscript.exe' code\01_download_data\03_download_siconfi.R
```

A execucao foi interrompida pelo usuario porque a maquina precisaria ser desligada.

Importante:

- O processo ficou rodando em segundo plano apos a interrupcao da ferramenta.
- Foram encontrados dois processos `Rscript` ainda ativos:
  - `1104`
  - `13424`
- Ambos foram encerrados com `Stop-Process`.
- Nao havia arquivos finais Siconfi em `data/raw/siconfi/` nem em `data/processed/` no momento do handoff.

## Ponto critico para retomar

O script atual acumula todos os downloads em memoria e so grava os arquivos raw/processados no final.

Como a coleta completa e longa, se ela for interrompida antes do final, o progresso se perde.

Recomendacao para a proxima sessao:

1. Rodar em chunks por ano usando `SICONFI_START_YEAR`, `SICONFI_END_YEAR` e `SICONFI_OUTPUT_PREFIX`.
2. Depois combinar os chunks com `03a_combine_siconfi_chunks.R`.
3. Depois da coleta combinada, validar:
   - 27 UFs por `year x bimester`, quando disponivel;
   - duplicatas em `year x bimester x state_abbrev`;
   - missing por variavel;
   - flags de fluxo negativo em investimento;
   - faixas plausiveis de `transfer_dependency_ratio` e `own_revenue_ratio`.

## Comandos uteis para retomar

Verificar se ha Rscript rodando:

```powershell
Get-Process | Where-Object { $_.ProcessName -like '*Rscript*' -or $_.ProcessName -eq 'R' } |
  Select-Object Id,ProcessName,CPU,StartTime
```

Smoke test opcional:

```powershell
$env:SICONFI_START_YEAR='2024'
$env:SICONFI_END_YEAR='2024'
$env:SICONFI_BIMESTERS='1'
$env:SICONFI_UF_CODES='14'
$env:SICONFI_OUTPUT_PREFIX='siconfi_rreo_smoke_test'
& 'C:\Users\yuri.silva\AppData\Local\Programs\R\R-4.4.2\bin\Rscript.exe' code\01_download_data\03_download_siconfi.R
```

Coleta chunked recomendada:

```powershell
Remove-Item Env:\SICONFI_UF_CODES -ErrorAction SilentlyContinue
Remove-Item Env:\SICONFI_BIMESTERS -ErrorAction SilentlyContinue

foreach ($year in 2015..2026) {
  $env:SICONFI_START_YEAR="$year"
  $env:SICONFI_END_YEAR="$year"
  $env:SICONFI_OUTPUT_PREFIX="siconfi_rreo_state_fiscal_bimonthly_$year"
  & 'C:\Users\yuri.silva\AppData\Local\Programs\R\R-4.4.2\bin\Rscript.exe' code\01_download_data\03_download_siconfi.R
}

Remove-Item Env:\SICONFI_OUTPUT_PREFIX -ErrorAction SilentlyContinue
& 'C:\Users\yuri.silva\AppData\Local\Programs\R\R-4.4.2\bin\Rscript.exe' code\01_download_data\03a_combine_siconfi_chunks.R
```

## Status final

Siconfi/RREO esta com investigacao, script inicial e combinador de chunks prontos.

Proximo passo recomendado: rodar a coleta chunked por ano e combinar os chunks.
