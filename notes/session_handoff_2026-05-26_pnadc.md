# Handoff PNADc - 2026-05-26

Este arquivo registra o ponto de parada do bloco PNADc trimestral.

## Estado geral

O bloco CAGED foi fechado antes desta etapa. A proxima frente aberta e PNADc trimestral, usando microdados baixados via `PNADcIBGE`.

## Arquivos criados/atualizados para PNADc

Scripts:

- `code/01_download_data/04_download_pnadc_quarterly.R`

Notas:

- `notes/pnadc_quarterly_roadmap.md`
- `notes/pnadc_processing_note.md`

Referencia copiada para o projeto:

- `references/dicionario_PNADC_microdados_trimestral.xls`

O dicionario foi copiado de:

- `C:\Users\yuri.silva\OneDrive\Trabalho - SEPLAN RR\DIEAS\Informativo trimestral DESEMPREGO\dicionario_PNADC_microdados_trimestral.xls`

## Regra de renda real

Foi corrigida a regra de renda real conforme orientacao do usuario:

```r
dadosPNADc <- get_pnadc(year = 2026, quarter = 1, deflator = TRUE)
dadosPNADc <- update(dadosPNADc, VD4020_real = VD4020 * Efetivo)
```

No script, a variavel de projeto correspondente e:

- `labor_income_real_pnadc`

Tambem foi registrada no dicionario:

- `data/processed/data_dictionary.csv`

## Regra de formalizacao

A taxa de formalizacao segue a classificacao documentada em:

- `notes/pnadc_processing_note.md`

Resumo:

- usar objeto de desenho amostral do `PNADcIBGE`;
- calcular totais com `survey::svytotal()` por UF;
- formais e informais sao classificados entre `VD4002 == "Pessoas ocupadas"`;
- usar parenteses explicitos em `VD4002 == "Pessoas ocupadas" & (...)`;
- `formalization_rate_pnadc = formal_occupied / (formal_occupied + informal_occupied)`.

## Tentativas executadas

### Teste 2025T4

Foi iniciada uma tentativa para `2025T4`.

Resultado:

- os arquivos brutos foram baixados para `data/raw/ibge/pnadc/`;
- o processamento falhou porque o script usava incorretamente `survey::update`;
- o registry registrou:

```text
2025,4,2025Q4,failed,0,,'update' is not an exported object from 'namespace:survey'
```

Esse erro ja foi corrigido no script: agora usa `update(...)`.

### Teste 2026T1

Foi iniciada uma tentativa para `2026T1`, mas o usuario precisou desligar a maquina.

Antes do desligamento, foram observados no cache:

- `data/raw/ibge/pnadc/PNADC_012026.zip`
- `data/raw/ibge/pnadc/PNADC_012026.txt`
- `data/raw/ibge/pnadc/deflator_PNADC_2026_trimestral_010203.xls`
- arquivos de dicionario/input trimestral

Dois processos `Rscript` ainda estavam rodando. Eles foram encerrados com `Stop-Process -Force` para evitar escrita incompleta durante o desligamento.

Nao havia, no momento do handoff, arquivos processados PNADc em:

- `data/processed/pnadc_quarterly_state_covariates_processed.csv`
- `data/processed/pnadc_quarterly_state_covariates_panel_ready.csv`

## Como retomar

Retomar com um unico trimestre, preferencialmente `2026T1`, usando o cache ja baixado e `PNADC_RELOAD=false`:

```powershell
$env:PNADC_START_YEAR='2026'
$env:PNADC_START_QUARTER='1'
$env:PNADC_END_YEAR='2026'
$env:PNADC_END_QUARTER='1'
$env:PNADC_RELOAD='false'
& 'C:\Users\yuri.silva\AppData\Local\Programs\R\R-4.4.2\bin\Rscript.exe' -e "source('code/01_download_data/04_download_pnadc_quarterly.R')"
```

Depois de rodar, validar:

- se `data/raw/ibge/pnadc_quarterly_download_registry.csv` marca `2026Q1` como `processed`;
- se os arquivos processados PNADc foram criados em `data/processed/`;
- se existem `27` UFs no trimestre;
- se `labor_income_real_pnadc`, `unemployment_rate_pnadc` e `formalization_rate_pnadc` foram preenchidas;
- se `income_variable_used` ficou documentada para a tentativa de renda domiciliar per capita.

## Observacao importante

O script PNADc ainda esta em fase de smoke test. Nao rodar todos os trimestres historicos antes de validar `2026T1`.
