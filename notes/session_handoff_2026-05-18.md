# Handoff da Sessao - 2026-05-18

Este arquivo registra o ponto de retomada do bloco CAGED. A prioridade definida pelo usuario foi: primeiro resolver CAGED; depois discutir `notes/ideias_para_aplicacao_yuri.md`; somente depois seguir para Siconfi/RREO.

## Objetivo imediato

Construir uma base CAGED estadual mensal final, documentada e validada, antes de usar emprego formal como outcome do paper.

## Scripts criados nesta sessao

- `code/01_download_data/02f_download_old_caged_complete_archives.R`
  - baixa o Old Caged completo (`CAGED/CAGEDEST_MMYYYY.7z`) de `2007-01` a `2019-12`
  - aceita `CAGED_START_MONTH` e `CAGED_END_MONTH`
  - grava `data/raw/mte/old_caged_complete_download_results.csv`
  - foi corrigido para tratar codigo de erro do `curl`
- `code/01_download_data/02g_parse_old_caged_complete.R`
  - parseia `CAGEDEST_MMYYYY.7z`
  - usa `Competencia Declarada`, `UF`, `Saldo Mov`
  - grava `data/raw/mte/old_caged_complete_state_balance_monthly.csv`
- `code/01_download_data/02h_download_novo_caged_adjusted_archives.R`
  - baixa `CAGEDMOV`, `CAGEDFOR` e `CAGEDEXC`
  - aceita `CAGED_START_MONTH` e `CAGED_END_MONTH`
  - grava `data/raw/mte/novo_caged_adjusted_download_results.csv`
- `code/01_download_data/02i_parse_novo_caged_adjusted.R`
  - parseia componentes do Novo Caged
  - soma `CAGEDMOV` e `CAGEDFOR`
  - multiplica `CAGEDEXC` por `-1`
  - grava arquivos bruto agregado e por componente
- `code/01_build_panel/05_process_caged_state_balance_final.R`
  - combina Old e Novo em uma base estadual mensal final
  - este script ainda depende de finalizar a decisao sobre Old Caged completo + ajustes

## Downloads feitos

Old Caged completo:

- o lote `2007-01` a `2019-12` foi baixado do FTP oficial
- existem 156 arquivos `CAGEDEST_MMYYYY.7z`, que corresponde ao numero esperado de meses
- o CSV de resultado foi sobrescrito no ultimo re-download pontual de `2013-01`; se precisar do log completo, reexecute o downloader ou gere novo inventario local

Novo Caged ajustado:

- foi feito apenas teste com `2026-03`
- os arquivos `CAGEDMOV202603.7z`, `CAGEDFOR202603.7z` e `CAGEDEXC202603.7z` foram baixados
- o parse funcionou, mas a serie completa ainda nao foi baixada

Planilha oficial agregada:

- foi baixada `data/raw/mte/saldomunicipioajustado_dez2019.xls`
- origem usada:
  - `https://www.gov.br/trabalho-e-emprego/pt-br/assuntos/estatisticas-trabalho/caged/6-saldomunicipioajustado.xls`
- ela deve ser usada como fonte de validacao e possivel plano B agregado para o Old Caged

## Achado critico sobre Old Caged

Varios arquivos oficiais `CAGEDEST_MMYYYY.7z` baixam com tamanho igual ao listado no FTP, mas falham no teste de integridade/decompressao.

O pacote `archive` consegue listar o arquivo interno, mas falha ao extrair em alguns meses. O `7z.exe` externo tambem acusa `Data Error`, entao nao parece ser apenas problema do pacote R.

Lista de arquivos que falharam no teste com `7z.exe t`:

- `CAGEDEST_012013.7z`
- `CAGEDEST_012015.7z`
- `CAGEDEST_012019.7z`
- `CAGEDEST_032011.7z`
- `CAGEDEST_032014.7z`
- `CAGEDEST_032015.7z`
- `CAGEDEST_032016.7z`
- `CAGEDEST_032019.7z`
- `CAGEDEST_042017.7z`
- `CAGEDEST_052008.7z`
- `CAGEDEST_052010.7z`
- `CAGEDEST_052012.7z`
- `CAGEDEST_052014.7z`
- `CAGEDEST_052016.7z`
- `CAGEDEST_062009.7z`
- `CAGEDEST_062010.7z`
- `CAGEDEST_062012.7z`
- `CAGEDEST_062017.7z`
- `CAGEDEST_072010.7z`
- `CAGEDEST_072015.7z`
- `CAGEDEST_082008.7z`
- `CAGEDEST_082009.7z`
- `CAGEDEST_082012.7z`
- `CAGEDEST_082019.7z`
- `CAGEDEST_092007.7z`
- `CAGEDEST_092014.7z`
- `CAGEDEST_092019.7z`
- `CAGEDEST_102009.7z`
- `CAGEDEST_102010.7z`
- `CAGEDEST_102012.7z`
- `CAGEDEST_102013.7z`
- `CAGEDEST_112009.7z`
- `CAGEDEST_112015.7z`
- `CAGEDEST_122010.7z`
- `CAGEDEST_122014.7z`
- `CAGEDEST_122017.7z`

Dois casos parecem truncados de forma explicita:

- `CAGEDEST_092007.7z`: `Unexpected end of archive`
- `CAGEDEST_102013.7z`: `Unexpected end of archive`

O teste de `CAGEDEST_012013.7z` foi repetido apos re-download e continuou falhando. O tamanho local (`32,909,712 bytes`) coincide com o tamanho listado pelo FTP, o que sugere que a copia oficial disponivel pode estar corrompida.

## Implicacao

Nao basta baixar os microdados completos do Old Caged e parsear com `archive`.

Antes de declarar Old Caged final, precisamos escolher um caminho:

1. localizar outra fonte espelho para os microdados completos antigos;
2. usar planilhas oficiais agregadas (`Saldo Municipio Ajustado`) para construir a serie estadual mensal/anuais quando os microdados falharem;
3. usar uma fonte harmonizada externa confiavel, se existir e for reproduzivel;
4. ou documentar explicitamente a impossibilidade de reconstruir microdados completos para todos os meses e abandonar CAGED como outcome principal.

## Validacoes ja feitas

- Amostra Old Caged `CAGEDEST_122019.7z`:
  - RR em `2019-12` = `-171`
  - 27 UFs na agregacao estadual
- Amostra Novo Caged `2026-03`:
  - `CAGEDMOV202603`, `CAGEDFOR202603`, `CAGEDEXC202603` baixaram e parsearam
  - RR em `2026-03` no componente `CAGEDMOV` = `751`
- A planilha `saldomunicipioajustado_dez2019.xls` tem abas desde `série 2002 A 2019` e abas mensais/acumuladas recentes, incluindo `jan a set 2019` e `jan a dez 2018`.

## Proxima retomada recomendada

1. Confirmar integridade dos arquivos Old Caged localmente:
   - comando usado:
     - `& 'C:\Program Files\AMD\CIM\Bin64\7z.exe' t data\raw\mte\CAGEDEST_012013.7z`
   - para todos os arquivos, repetir loop com `7z.exe t`
2. Investigar alternativas para Old Caged:
   - espelho oficial/arquivos historicos
   - planilhas `Saldo Municipio Ajustado`
   - Base dos Dados ou outra fonte harmonizada
3. Se usar planilhas agregadas:
   - extrair municipio-UF das abas
   - agregar para `UF x competencia`
   - comparar com microdados nos meses integros
4. Decidir a regra pre-2020:
   - Old completo puro
   - Old completo + `CAGED_AJUSTES`
   - planilha oficial agregada ajustada
5. So depois baixar/processar Novo Caged completo `2020-01` em diante com `CAGEDMOV + CAGEDFOR - CAGEDEXC`.

## Estado do git

Ha novos scripts e arquivos de documentacao ainda nao commitados. Os arquivos brutos grandes em `data/raw/mte/*.7z` devem permanecer fora do git.

