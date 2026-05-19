# Diagnostico CAGED pre-2020 - 2026-05-19

Esta nota registra a retomada do bloco CAGED apos o handoff de 2026-05-18.

## Integridade dos microdados Old Caged completos

Foi repetido o teste de integridade com `7z.exe t` para os arquivos:

- `data/raw/mte/CAGEDEST_MMYYYY.7z`
- periodo esperado: `2007-01` a `2019-12`
- total local: `156` arquivos

Resultado salvo em:

- `data/raw/mte/old_caged_complete_integrity_7z.csv`

Resumo inicial:

- arquivos integros: `120`
- arquivos com falha: `36`

Falhas por ano:

- `2007`: `1`
- `2008`: `2`
- `2009`: `4`
- `2010`: `5`
- `2011`: `1`
- `2012`: `4`
- `2013`: `2`
- `2014`: `4`
- `2015`: `4`
- `2016`: `2`
- `2017`: `3`
- `2019`: `4`

A lista de falhas reproduz a lista documentada no handoff de 2026-05-18. Portanto, o problema dos microdados completos antigos permanece: a copia oficial local nao permite parse completo de todos os meses.

Script criado para reproduzir o inventario:

- `code/01_download_data/02j_check_old_caged_complete_integrity.R`

## Tentativa de re-download das bases corrompidas

Foi feita uma tentativa de re-download dos `36` arquivos que falhavam, em pasta separada:

- `data/raw/mte/redownload_attempts_2026-05-19/`

Resultado limpo da tentativa:

- `data/raw/mte/redownload_attempts_2026-05-19/redownload_all_failed_results_clean.csv`

Apenas um arquivo passou a abrir corretamente depois do re-download:

- `CAGEDEST_092007.7z`

O arquivo original foi preservado como:

- `data/raw/mte/CAGEDEST_092007_corrupt_legacy.7z`

A copia nova e integra foi colocada no nome esperado:

- `data/raw/mte/CAGEDEST_092007.7z`

Resultado do inventario apos a substituicao:

- arquivos integros: `121`
- arquivos com falha: `35`

Um segundo arquivo mudou de tamanho no re-download, mas continuou falhando:

- `CAGEDEST_102013.7z`: `16,908,288` bytes na copia antiga; `30,844,627` bytes no re-download; ainda com `Data Error`

## Tentativa de salvamento parcial dos TXT corrompidos

Foi criado um script para extrair e parsear parcialmente os arquivos que continuam com `Data Error`:

- `code/01_download_data/02l_salvage_old_caged_complete_corrupt_archives.R`

A logica do salvamento e:

1. tentar extrair o `.txt` com `7z.exe x` mesmo quando o arquivo retorna erro;
2. manter apenas linhas com o mesmo numero de campos do cabecalho;
3. validar campos essenciais: `Competencia Declarada`, `UF` e `Saldo Mov`;
4. agregar por `competencia x UF`;
5. gravar um relatorio de aproveitamento.

Como `Rscript` nao estava disponivel na sessao, a mesma logica foi executada via Python/7-Zip para gerar os CSVs imediatamente.

Saidas geradas:

- `data/raw/mte/old_caged_complete_salvage_report.csv`
- `data/raw/mte/old_caged_complete_salvage_coverage.csv`
- `data/raw/mte/old_caged_complete_salvaged_state_balance_monthly.csv`

Resultado geral:

- os `35` arquivos restantes geraram algum `.txt` parcial;
- todos os `35` foram parseados parcialmente;
- nenhum dos `35` recuperou cobertura estadual completa de `27` UFs;
- a cobertura por arquivo variou de `3` a `23` UFs;
- foram geradas `559` linhas agregadas `competencia x UF`, contra `945` esperadas se todos os `35` arquivos tivessem `27` UFs.

Conclusao:

- o salvamento parcial e util como diagnostico e possivelmente para recuperar alguns valores estaduais especificos;
- ele nao resolve sozinho a base mensal estadual completa, porque todos os arquivos recuperados continuam com cobertura parcial de UFs;
- antes de usar qualquer valor salvado em analise, e necessario validar contra totais oficiais anuais/acumulados e sinalizar explicitamente a origem `old_caged_complete_salvaged_partial`.

Observacao operacional atualizada:

- os CSVs finais foram salvos fora das pastas temporarias;
- as pastas temporarias com `.txt` extraidos foram removidas apos nova tentativa com permissao elevada.

## Planilha oficial agregada

Foi inspecionada a planilha:

- `data/raw/mte/saldomunicipioajustado_dez2019.xls`

Estrutura observada:

- aba `serie 2002 A 2019`: saldo anual municipal, com ajustes, de `2002` a `2018` e `2019` apenas como `janeiro a setembro`
- abas acumuladas mensais disponiveis para `2017`, `2018` e `2019` ate setembro
- abas anuais para `2010` a `2016`

Implicacao:

- a planilha e util para validar totais oficiais ajustados por UF
- ela permite derivar saldos mensais por diferenca de acumulados para `2017-01` a `2019-09`
- ela nao substitui integralmente os microdados mensais de `2007-01` a `2016-12`
- ela tambem nao fornece, nesta copia, meses acumulados para `2019-10` a `2019-12`

Script criado para extrair os agregados oficiais:

- `code/01_download_data/02k_parse_old_caged_official_aggregate_workbook.R`

Saidas esperadas do script:

- `data/raw/mte/old_caged_official_adjusted_state_balance_annual.csv`
- `data/raw/mte/old_caged_official_adjusted_state_balance_monthly_2017_2019.csv`

## Consequencia metodologica

O caminho "usar somente a planilha oficial agregada como plano B mensal pre-2020" nao resolve todo o periodo necessario para um painel mensal estadual desde 2007.

No estado atual, ha tres caminhos tecnicamente defensaveis:

1. localizar outra fonte dos microdados mensais completos do Old Caged com arquivos integros;
2. usar os microdados completos nos 120 meses integros e uma regra documentada de imputacao/substituicao para os 36 meses corrompidos, validada contra totais oficiais anuais/acumulados;
3. restringir o uso do CAGED como outcome principal, mantendo-o como analise secundaria ou restringindo janelas/casos em que a cobertura mensal seja defensavel.

## Proximo passo recomendado

Antes de baixar todo o Novo Caged ajustado, resolver a fonte pre-2020:

1. rodar o parser da planilha oficial agregada no R/RStudio;
2. comparar os meses `2017-01` a `2019-09` da planilha oficial contra os meses integros dos microdados completos;
3. decidir se a diferenca entre "CAGED completo sem ajustes" e "planilha oficial com ajustes" e aceitavel ou se os ajustes precisam entrar explicitamente;
4. buscar uma fonte alternativa para os 36 meses corrompidos, especialmente para `2007-2016`, onde a planilha atual nao oferece acumulados mensais.
