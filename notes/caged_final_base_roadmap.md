# Caged Final Base Roadmap

Este documento organiza os achados sobre `Old Caged`, `CAGED_AJUSTES` e `Novo Caged`, e define os passos necessários para construir uma base final de emprego formal para o projeto.

## Diagnostico principal

A base Caged do projeto ainda nao deve ser considerada final.

Atualizacao de 2026-05-18:

- o downloader do Old Caged completo foi criado e o lote `2007-01` a `2019-12` foi baixado
- existem 156 arquivos `CAGEDEST_MMYYYY.7z`, isto e, a cobertura mensal esperada
- porem, a etapa de integridade revelou que varios arquivos oficiais falham ao descompactar
- portanto, o gargalo atual nao e mais localizar a pasta do Old Caged, mas obter uma serie pre-2020 confiavel apesar desses arquivos corrompidos

Atualizacao de 2026-05-19:

- o inventario de integridade foi reproduzido e salvo em `data/raw/mte/old_caged_complete_integrity_7z.csv`
- resultado inicial: `120` arquivos integros e `36` com falha
- depois de rebaixar os `36` arquivos com falha, apenas `CAGEDEST_092007.7z` passou a abrir corretamente; o inventario final ficou com `121` arquivos integros e `35` com falha
- foi tentado salvamento parcial dos `.txt` dos `35` arquivos restantes; todos geraram registros parciais, mas nenhum recuperou as `27` UFs completas, entao o salvamento nao resolve sozinho a serie mensal estadual
- foi identificada a tabela `basedosdados.br_me_caged.microdados_antigos` como alternativa para preencher os meses corrompidos via BigQuery, com consulta agregada por `ano x mes x sigla_uf`
- foi criado `code/01_download_data/02m_query_old_caged_basedosdados_state_balance.R`
- a consulta da Base dos Dados foi executada para os `35` meses corrompidos e retornou cobertura completa: `945` linhas, isto e, `35` meses x `27` UFs
- foi criada a nota `notes/caged_pre2020_source_diagnostic_2026-05-19.md`
- a planilha `saldomunicipioajustado_dez2019.xls` foi inspecionada: ela oferece agregados anuais e acumulados mensais para `2017-01` a `2019-09`, mas nao substitui integralmente os microdados mensais de `2007-01` a `2016-12`

O problema nao e uma diferenca de unidade do tipo `1 pessoa` versus `1000 pessoas`. Os campos observados em `Old Caged`, `CAGED_AJUSTES` e `Novo Caged` parecem estar em contagem de vinculos/movimentos, isto e, pessoas/vinculos. O problema e de escopo da fonte:

- os arquivos `CAGED_AJUSTES` nao parecem ser o Caged antigo completo
- a serie Novo Caged atualmente processada usa apenas `CAGEDMOV`
- o Novo Caged completo/ajustado tambem precisa considerar `CAGEDFOR` e `CAGEDEXC`

## Fontes oficiais identificadas

Pagina oficial do MTE para microdados:

- `https://www.gov.br/trabalho-e-emprego/pt-br/assuntos/estatisticas-trabalho/microdados-rais-e-caged`

FTP oficial:

- `ftp://ftp.mtps.gov.br/pdet/microdados/`

Diretorios relevantes:

- Old Caged completo:
  - `ftp://ftp.mtps.gov.br/pdet/microdados/CAGED/`
- Old Caged ajustes:
  - `ftp://ftp.mtps.gov.br/pdet/microdados/CAGED_AJUSTES/`
- Novo Caged:
  - `ftp://ftp.mtps.gov.br/pdet/microdados/NOVO%20CAGED/`

## Old Caged completo

O Old Caged completo esta em:

- `ftp://ftp.mtps.gov.br/pdet/microdados/CAGED/`

Estrutura observada:

- subpastas anuais de `2007/` a `2019/`
- arquivos mensais do tipo `CAGEDEST_MMYYYY.7z`

Exemplos:

- `ftp://ftp.mtps.gov.br/pdet/microdados/CAGED/2007/CAGEDEST_012007.7z`
- `ftp://ftp.mtps.gov.br/pdet/microdados/CAGED/2019/CAGEDEST_122019.7z`

Layout:

- `ftp://ftp.mtps.gov.br/pdet/microdados/CAGED/CAGEDEST_layout_Atualizado.xls`

Campos observados em amostra de `CAGEDEST_122019.7z`:

- `Competencia Declarada`
- `UF`
- `Saldo Mov`

Interpretação operacional:

- Esta e a fonte que deve ser usada para reconstruir o saldo mensal total do Caged antigo por `UF x competencia`.
- Para esses arquivos completos, a competencia mensal observada no layout e `Competencia Declarada`.

Alerta de integridade encontrado em 2026-05-18:

- alguns arquivos `CAGEDEST_MMYYYY.7z` baixam com tamanho positivo, e em alguns casos com tamanho igual ao listado no FTP, mas falham na descompressao
- o problema foi reproduzido com `archive` no R e tambem com `7z.exe t`
- dois arquivos aparecem claramente truncados: `CAGEDEST_092007.7z` e `CAGEDEST_102013.7z`
- varios outros acusam `Data Error`, incluindo `CAGEDEST_012013.7z`, que continuou falhando mesmo apos re-download
- ver lista completa em `notes/session_handoff_2026-05-18.md`

Consequencia:

- o parse completo do Old Caged microdados ainda nao pode ser concluido de forma confiavel
- a planilha oficial agregada `data/raw/mte/saldomunicipioajustado_dez2019.xls` foi baixada como fonte de validacao e possivel alternativa agregada

## CAGED_AJUSTES

Os arquivos ja baixados/processados nesta sessao estao em:

- `ftp://ftp.mtps.gov.br/pdet/microdados/CAGED_AJUSTES/`

Estrutura observada:

- `2002a2009/` com arquivos anuais
- `2010/` a `2019/` com arquivos mensais

Campos observados:

- `Competencia Movimentacao`
- `Saldo Mov`
- `UF`
- `Competencia Declarada`

Achado importante:

- Esses arquivos nao devem ser tratados como a serie completa do Old Caged.
- Eles parecem conter apenas movimentos de ajuste/extemporaneos, ou algum componente de ajuste, nao o saldo mensal total.

Evidencia de escala para RR:

- planilha consolidada `old_caged_adjusted_balance_legacy.xls`, `jan a set 2019`: `1604`
- microdados `CAGED_AJUSTES` agregados em 2019 disponivel: `428`

Conclusao:

- Os arquivos `CAGED_AJUSTES` podem ser uteis, mas a logica de incorporacao precisa ser entendida antes de mistura-los ao Old Caged completo.
- A base `old_caged_state_balance_monthly_*` gerada a partir de `CAGED_AJUSTES` deve ser tratada como diagnostica/intermediaria, nao como outcome final.

## Novo Caged

O Novo Caged esta em:

- `ftp://ftp.mtps.gov.br/pdet/microdados/NOVO%20CAGED/`

Estrutura observada:

- subpastas anuais a partir de `2020/`
- subpastas mensais, por exemplo:
  - `2026/202603/`

Arquivos observados em meses recentes:

- `CAGEDMOVAAAAMM.7z`
- `CAGEDFORAAAAMM.7z`
- `CAGEDEXCAAAAMM.7z`

Segundo o `Leia-me.txt` oficial do FTP:

- `CAGEDMOV` contem movimentacoes declaradas dentro do prazo
- `CAGEDFOR` contem movimentacoes declaradas fora do prazo
- `CAGEDEXC` contem movimentacoes excluidas

Regra de sinal para exclusoes:

- a exclusao tem efeito inverso ao evento original
- exclusao de admissao reduz o saldo
- exclusao de desligamento aumenta o saldo

Conclusao:

- A serie Novo Caged atualmente processada no projeto usa apenas `CAGEDMOV`.
- Portanto, ela tambem nao deve ser tratada como uma serie final ajustada.
- A serie final deve incorporar `CAGEDMOV`, `CAGEDFOR` e `CAGEDEXC`.

## Estado atual dos arquivos do projeto

Arquivos ja existentes e utilizaveis como intermediarios:

- `data/processed/novo_caged_state_balance_monthly_processed.csv`
- `data/processed/novo_caged_state_balance_monthly_panel_ready.csv`
- `data/raw/mte/old_caged_state_balance_monthly.csv`
- `data/processed/old_caged_state_balance_monthly_processed.csv`
- `data/processed/old_caged_state_balance_monthly_panel_ready.csv`

Mas:

- `novo_caged_state_balance_monthly_*` esta baseado apenas em `CAGEDMOV`
- `old_caged_state_balance_monthly_*` esta baseado em `CAGED_AJUSTES`

Ambos devem ser substituidos ou renomeados quando a base final for criada, para evitar uso acidental.

## Passos para construir a base Caged final

### 1. Baixar Old Caged completo

Criar um script novo, por exemplo:

- `code/01_download_data/02f_download_old_caged_complete_archives.R`

Tarefas:

- listar ou construir URLs de `2007-01` a `2019-12`
- baixar arquivos `CAGEDEST_MMYYYY.7z`
- salvar em `data/raw/mte/`
- registrar status em um CSV, por exemplo:
  - `data/raw/mte/old_caged_complete_download_results.csv`

Observacao:

- Os arquivos sao grandes, cerca de dezenas de MB por mes.
- O download total pode demorar.

### 2. Parsear Old Caged completo

Criar um script novo, por exemplo:

- `code/01_download_data/02g_parse_old_caged_complete.R`

Campos esperados:

- `Competencia Declarada`
- `UF`
- `Saldo Mov`

Agregacao inicial:

- agrupar por `competencia x uf`
- somar `Saldo Mov`
- gerar:
  - `data/raw/mte/old_caged_complete_state_balance_monthly.csv`

Checagens obrigatorias:

- 27 UFs por competencia
- ausencia de duplicidade em `competencia x uf`
- cobertura mensal esperada
- comparar somas estaduais/anuais com a planilha consolidada `old_caged_adjusted_balance_legacy.xls`

### 3. Decidir como incorporar CAGED_AJUSTES

Antes de somar qualquer coisa:

- entender oficialmente se `CAGED_AJUSTES` corrige meses anteriores, complementa `CAGED`, ou se ja esta refletido nas planilhas consolidadas
- comparar totais:
  - Old Caged completo
  - Old Caged completo + CAGED_AJUSTES
  - planilha consolidada `old_caged_adjusted_balance_legacy.xls`

Resultado esperado:

- definir uma regra documentada para a serie pre-2020:
  - usar apenas `CAGED` completo, ou
  - usar `CAGED` completo mais ajustes, com competencia de movimentacao, ou
  - usar a planilha consolidada quando for suficiente

### 4. Reprocessar Novo Caged ajustado

Criar ou alterar os scripts atuais para baixar e processar:

- `CAGEDMOV`
- `CAGEDFOR`
- `CAGEDEXC`

Scripts possiveis:

- atualizar `code/01_download_data/02c_download_novo_caged_archives.R`
- criar `code/01_download_data/02h_parse_novo_caged_adjusted.R`

Regra esperada:

- `CAGEDMOV`: somar saldo normalmente
- `CAGEDFOR`: somar saldo normalmente, respeitando a competencia correta do movimento ou declaracao conforme layout
- `CAGEDEXC`: aplicar efeito inverso ao evento excluido

Checagem crucial:

- confirmar no layout de cada arquivo qual campo representa:
  - competencia de declaracao
  - competencia de movimentacao
  - UF
  - saldo ou tipo de movimentacao

### 5. Criar base unificada final

Depois de validar Old e Novo separadamente, criar:

- `data/processed/caged_state_balance_monthly_processed.csv`
- `data/processed/caged_state_balance_monthly_panel_ready.csv`

Campos recomendados:

- `competencia`
- `period_date`
- `year`
- `month`
- `uf`
- `state_abbrev`
- `state_name`
- `macroregion`
- `formal_hiring_balance`
- `source_regime`
- `source_component`
- `post_2020_caged_dummy`
- `caged_method_break_dummy`
- `series_version`

Valores possiveis:

- `source_regime`:
  - `old_caged`
  - `novo_caged`
- `source_component`:
  - `complete`
  - `adjusted`
  - `mov`
  - `for`
  - `exc`
  - `combined`
- `series_version`:
  - nome curto da regra adotada, por exemplo `old_complete_novo_mov_for_exc_v1`

### 6. Validar quebra metodologica

Somente depois da base final:

- refazer graficos de RR e outros estados
- comparar meses ao redor de `2020-01`
- avaliar se a quebra visual permanece
- decidir se:
  - usa dummy `post_2020_caged_dummy`
  - restringe algumas especificacoes a Novo Caged
  - evita emprego formal em casos cujo desenho depende demais da comparabilidade pre/post-2020

## Decisao metodologica provisoria

Ate a base final ser criada:

- nao usar `formal_hiring_balance` misturando Old Caged e Novo Caged como outcome principal
- manter PMC e PMS como outcomes mensais mais prontos
- tratar Caged como bloco ainda em preparacao

## Proxima retomada recomendada

Quando houver tempo para continuar:

1. Ler `notes/session_handoff_2026-05-18.md`.
2. Resolver a fonte pre-2020:
   - encontrar espelho integro dos microdados, ou
   - usar planilhas oficiais agregadas, ou
   - usar fonte harmonizada externa confiavel e reproduzivel.
3. Validar a regra Old Caged contra a planilha consolidada.
4. Baixar e parsear Novo Caged completo, incorporando `CAGEDMOV`, `CAGEDFOR` e `CAGEDEXC`.
5. Rodar `code/01_build_panel/05_process_caged_state_balance_final.R` somente depois das validacoes acima.
