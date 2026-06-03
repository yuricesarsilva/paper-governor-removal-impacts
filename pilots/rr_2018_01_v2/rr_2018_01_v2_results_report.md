# RR 2018-01: Resultados preliminares do piloto V2

Documento gerado em 2026-06-03.

Este documento consolida a primeira rodada de resultados para o caso de Roraima em 2018. O objetivo é organizar, em formato próximo ao de uma seção empírica de artigo, os resultados do Augmented Synthetic Control Method (Augmented SCM) para os três canais discutidos no desenho do projeto: investimento privado/mercado de trabalho, consumo das famílias e setor público estadual.

## Desenho do evento

- Unidade tratada: `RR`.
- Início da instabilidade política: `2018-11-07`.
- Queda/intervenção efetiva: `2018-12-10`.

As observações anteriores ao início da instabilidade são tratadas como pré-tratamento limpo. A janela entre o início da instabilidade e a queda efetiva é mantida como período de crise política. As observações posteriores à queda/intervenção são tratadas como pós-tratamento.

## Estratégia metodológica

O pool principal de doadores exclui `RR`, `AM` e `TO`. Roraima é excluída por ser a unidade tratada. Amazonas é excluído por ter o evento `AM_2017_01` próximo ao período pré-tratamento de Roraima. Tocantins é excluído por ter eventos múltiplos e próximos ao caso de Roraima, em especial `TO_2018_01`. Assim, a especificação principal utiliza 24 UFs elegíveis como doadores.

A unidade tratada é Roraima. Para cada desfecho, o método construiu uma combinação convexa de estados doadores capaz de aproximar a trajetória pré-tratamento e as covariáveis pré-evento de Roraima. Seja \(Y_{1t}\) o resultado observado em Roraima no período \(t\), e seja \(Y_{jt}\) o resultado observado no estado doador \(j = 2, \ldots, J+1\). O sintético clássico é definido por:

\[
\widehat{Y}^{SCM}_{1t} = \sum_{j=2}^{J+1} w_j Y_{jt}, \qquad w_j \geq 0, \qquad \sum_{j=2}^{J+1} w_j = 1.
\]

Os pesos \(w_j\) minimizam a distância entre os preditores da unidade tratada, \(X_1\), e os preditores ponderados dos doadores, \(X_0 W\):

\[
\widehat{W} = \arg\min_W (X_1 - X_0 W)' V (X_1 - X_0 W),
\]

sujeito às restrições de não negatividade e soma unitária. Na implementação atual, os preditores incluem a trajetória pré-tratamento completa disponível da própria variável dependente e covariáveis estaduais pré-evento: taxa de desemprego, taxa de formalização, dependência de transferências, despesa em saúde per capita, despesa em educação per capita e despesa em segurança pública per capita.

O estimador principal neste relatório é o Augmented SCM. Ele preserva a estrutura de pesos do SCM e adiciona uma correção de viés estimada por regressão ridge nos doadores. De forma compacta:

\[
\widehat{Y}^{ASCM}_{1t} = \widehat{Y}^{SCM}_{1t} + \widehat{m}_t(X_1) - \sum_{j=2}^{J+1} \widehat{w}_j \widehat{m}_t(X_j),
\]

em que \(\widehat{m}_t(\cdot)\) é uma função ridge ajustada entre os estados doadores para cada período. O efeito estimado em Roraima é:

\[
\widehat{\tau}_{1t} = Y_{1t} - \widehat{Y}^{ASCM}_{1t}.
\]

Valores positivos indicam que Roraima ficou acima do contrafactual sintético; valores negativos indicam desempenho abaixo do contrafactual. Para as variáveis mensais, o relatório mostra resultados brutos e médias móveis limpas de 6 meses. Para as variáveis bimestrais, mostra resultados brutos e médias móveis limpas de 4 bimestres. As médias móveis limpas são calculadas separadamente dentro dos segmentos pré, crise e pós, evitando que observações pré-tratamento contaminem a janela posterior.

## Variáveis e canais

- Mercado de trabalho e investimento privado: saldo de emprego formal por 100 mil pessoas em idade ativa e receita de ICMS real per capita.
- Consumo das famílias: índice de volume do comércio varejista e índice de volume de serviços.
- Setor público estadual: investimento público liquidado como proporção da despesa total e despesa em saúde, educação e segurança pública como proporção da despesa total.

A normalização por população ou por escala de mercado é importante porque os estados brasileiros diferem muito em tamanho. Por isso, as variáveis fiscais são per capita, o saldo formal é expresso por 100 mil pessoas em idade ativa e as séries de comércio/serviços entram como índices de volume reancorados em 100 na primeira observação válida da janela do piloto para cada estado.

## Visualização preliminar dos dados

As figuras abaixo comparam Roraima com a média simples dos doadores elegíveis antes de aplicar o controle sintético. Elas não devem ser interpretadas como efeito causal; servem para expor escala, volatilidade, quebras e diferenças iniciais entre Roraima e o conjunto de comparação.

Para facilitar a inspeção, as linhas cinza mostram os estados doadores elegíveis em traço fino e transparente; Roraima e a média simples dos doadores aparecem em tons mais escuros. Nas figuras suavizadas, a visualização usa médias móveis com janela parcial no começo de cada segmento: o primeiro período pós-instabilidade ou pós-queda aparece com a primeira observação disponível, e os períodos seguintes incorporam progressivamente as observações novas até completar a janela definida. A estimativa principal do SCM continua usando as séries limpas, sem misturar períodos de tratamento.

A receita de ICMS foi extraída do arquivo bruto local do Siconfi/RREO, Anexo 06, conta `RREO6ICMS`. Como a fonte reporta a receita realizada acumulada até o bimestre, o fluxo bimestral usado no painel é derivado por diferença dentro de cada ano. A tabela de auditoria para Roraima em 2018 está em `report/tables/rr_2018_icms_revenue_audit.csv`.

### Mercado de trabalho e investimento privado

![preliminary_labor_investment_raw.png](report/figures/preliminary_labor_investment_raw.png)

![preliminary_labor_investment_smooth.png](report/figures/preliminary_labor_investment_smooth.png)

### Consumo das famílias

![preliminary_consumption_raw.png](report/figures/preliminary_consumption_raw.png)

![preliminary_consumption_smooth.png](report/figures/preliminary_consumption_smooth.png)

### Setor público estadual

![preliminary_public_sector_raw.png](report/figures/preliminary_public_sector_raw.png)

![preliminary_public_sector_smooth.png](report/figures/preliminary_public_sector_smooth.png)

## Resultados principais: Augmented SCM

A tabela resume os resultados para as especificações suavizadas, que são as mais informativas para leitura substantiva porque reduzem volatilidade mensal/bimestral sem misturar os segmentos de tratamento.

Nas especificações suavizadas, a coluna de crise política pode ficar vazia porque a janela entre instabilidade e queda efetiva é curta demais para formar uma média móvel limpa completa dentro do próprio segmento. Nesses casos, a inferência visual da transição imediata deve usar os gráficos brutos e as figuras de média móvel visual com janela parcial; a estimativa principal suavizada permanece concentrada no período pós-queda.

| Canal | Variável | Gap médio crise | Gap médio pós | RMSPE pré | RMSPE pós | Doadores |
| --- | --- | --- | --- | --- | --- | --- |
| Mercado de trabalho e investimento privado | Emprego formal, MM6 |  |  27.99 | 4.49 |  42.68 | 24 |
| Mercado de trabalho e investimento privado | ICMS, MM4 |  | 127.84 | 5.85 | 242.24 | 24 |
| Setor público estadual | Áreas prioritárias/despesa total, MM4 |  |   0.01 | 0.00 |   0.02 | 24 |
| Setor público estadual | Investimento/despesa total, MM4 |  |   0.00 | 0.00 |   0.00 | 24 |
| Consumo das famílias | Comércio, MM6 |  |   6.71 | 0.51 |   9.01 | 24 |
| Consumo das famílias | Serviços, MM6 |  |   2.89 | 0.38 |   3.30 | 24 |

Como leitura preliminar, a interpretação deve privilegiar três elementos: a qualidade do ajuste pré-tratamento, medida pelo RMSPE pré; o sinal e tamanho do gap durante a crise política; e a persistência do gap no período posterior à queda/intervenção.

### Mercado de trabalho e investimento privado

![augmented_paths_labor_investment_raw.png](report/figures/augmented_paths_labor_investment_raw.png)

![augmented_gaps_labor_investment_raw.png](report/figures/augmented_gaps_labor_investment_raw.png)

![augmented_paths_labor_investment_smooth.png](report/figures/augmented_paths_labor_investment_smooth.png)

![augmented_gaps_labor_investment_smooth.png](report/figures/augmented_gaps_labor_investment_smooth.png)

No canal de mercado de trabalho e investimento privado, o saldo formal e o ICMS real per capita capturam margens complementares. O emprego formal responde a decisões de contratação e desligamento das firmas. O ICMS é uma proxy fiscal de alta frequência para circulação tributável de bens e serviços, aproximando variações na base econômica estadual. A especificação suavizada é especialmente relevante porque ambas as séries podem ter alta volatilidade de curto prazo.

### Consumo das famílias

![augmented_paths_consumption_raw.png](report/figures/augmented_paths_consumption_raw.png)

![augmented_gaps_consumption_raw.png](report/figures/augmented_gaps_consumption_raw.png)

![augmented_paths_consumption_smooth.png](report/figures/augmented_paths_consumption_smooth.png)

![augmented_gaps_consumption_smooth.png](report/figures/augmented_gaps_consumption_smooth.png)

O canal de consumo é observado por comércio varejista e serviços, ambos reancorados em 100 no início da janela do piloto. A leitura conjunta é importante porque famílias podem ajustar consumo de bens e serviços de forma diferente em resposta a incerteza política, perda de renda esperada ou mudanças no funcionamento do setor público local.

### Setor público estadual

![augmented_paths_public_sector_raw.png](report/figures/augmented_paths_public_sector_raw.png)

![augmented_gaps_public_sector_raw.png](report/figures/augmented_gaps_public_sector_raw.png)

![augmented_paths_public_sector_smooth.png](report/figures/augmented_paths_public_sector_smooth.png)

![augmented_gaps_public_sector_smooth.png](report/figures/augmented_gaps_public_sector_smooth.png)

No canal do setor público, investimento liquidado como proporção da despesa total mede a margem de paralisação, reprogramação ou ajuste de projetos sem confundir o resultado com o tamanho absoluto do estado. A segunda variável é a proporção da despesa total direcionada a saúde, educação e segurança pública, capturando se a crise desloca ou preserva áreas centrais da prestação estatal. A série de investimento exige cautela adicional porque houve reparo de lacunas no Siconfi/RREO; por isso ela deve ser lida junto da auditoria de dados e dos resultados de robustez.

### Resumo gráfico dos efeitos

![augmented_effect_summary.png](report/figures/augmented_effect_summary.png)

## Pesos dos doadores

As figuras de pesos ajudam a avaliar a plausibilidade do contrafactual. Pesos muito concentrados podem indicar que poucos estados são responsáveis pela aproximação de Roraima; pesos mais dispersos sugerem uma composição mais diversificada, embora a qualidade substantiva dependa também do ajuste pré-tratamento.

![donor_weights_labor_investment_smooth.png](report/figures/donor_weights_labor_investment_smooth.png)

![donor_weights_consumption_smooth.png](report/figures/donor_weights_consumption_smooth.png)

![donor_weights_public_sector_smooth.png](report/figures/donor_weights_public_sector_smooth.png)

## Robustez

A primeira checagem de robustez compara especificações brutas e suavizadas. As séries brutas preservam choques de curtíssimo prazo, mas podem exagerar ruído operacional, sazonalidade residual e irregularidades administrativas. As séries suavizadas reduzem esse ruído e são, por ora, a especificação preferida para leitura substantiva.

Resultados brutos:

| Canal | Variável | Gap médio crise | Gap médio pós | RMSPE pré | RMSPE pós | Doadores |
| --- | --- | --- | --- | --- | --- | --- |
| Mercado de trabalho e investimento privado | Emprego formal |   30.25 | 26.31 | 39.79 |  90.66 | 24 |
| Mercado de trabalho e investimento privado | ICMS | -379.79 | 77.16 |  3.26 | 454.36 | 24 |
| Setor público estadual | Áreas prioritárias/despesa total |   -0.02 |  0.01 |  0.01 |   0.05 | 24 |
| Setor público estadual | Investimento/despesa total |    0.00 |  0.00 |  0.02 |   0.02 | 24 |
| Consumo das famílias | Comércio |    3.26 |  8.40 |  3.49 |  10.93 | 24 |
| Consumo das famílias | Serviços |   -0.37 |  2.95 |  3.26 |   5.19 | 24 |

Resultados suavizados:

| Canal | Variável | Gap médio crise | Gap médio pós | RMSPE pré | RMSPE pós | Doadores |
| --- | --- | --- | --- | --- | --- | --- |
| Mercado de trabalho e investimento privado | Emprego formal, MM6 |  |  27.99 | 4.49 |  42.68 | 24 |
| Mercado de trabalho e investimento privado | ICMS, MM4 |  | 127.84 | 5.85 | 242.24 | 24 |
| Setor público estadual | Áreas prioritárias/despesa total, MM4 |  |   0.01 | 0.00 |   0.02 | 24 |
| Setor público estadual | Investimento/despesa total, MM4 |  |   0.00 | 0.00 |   0.00 | 24 |
| Consumo das famílias | Comércio, MM6 |  |   6.71 | 0.51 |   9.01 | 24 |
| Consumo das famílias | Serviços, MM6 |  |   2.89 | 0.38 |   3.30 | 24 |

A segunda checagem é a separação explícita entre janela de crise política e período pós-queda. Isso evita tratar o evento como um único ponto instantâneo e permite avaliar se efeitos aparecem durante a instabilidade, depois da remoção efetiva, ou em ambos os momentos. Essa distinção é substantivamente importante porque processos legislativos ou judiciais podem afetar expectativas antes da troca formal de comando.

A terceira checagem é a leitura do ajuste pré-tratamento. Resultados com RMSPE pré muito alto devem receber menor peso interpretativo, pois o contrafactual é menos crível. Nos próximos ciclos, também faz sentido acrescentar janelas alternativas de pré-tratamento e excluir doadores de alta influência para checar sensibilidade dos pesos.

## Placebos in-space

Os placebos in-space reestimam o Augmented SCM tratando cada estado elegível do pool principal como se tivesse recebido o tratamento, mantendo Roraima como a unidade efetivamente tratada. `AM` e `TO` não entram como placebos porque também foram excluídos do pool principal. Para os estados placebo, Roraima permanece fora do conjunto de doadores. Os gaps são normalizados pelo RMSPE pré-tratamento da própria unidade placebo:

\[
g^{norm}_{it} = \frac{Y_{it} - \widehat{Y}^{ASCM}_{it}}{RMSPE^{pré}_i}.
\]

Essa normalização torna comparáveis unidades com escalas diferentes. O teste não é uma inferência randomizada formal, mas fornece uma avaliação visual e ordinal: se Roraima estiver entre os maiores desvios pós-tratamento em relação aos placebos, o resultado é mais consistente com um efeito excepcional do evento.

| Canal | Variável | Razão RMSPE pós/pré | p RMSPE | p gap absoluto | Placebos |
| --- | --- | --- | --- | --- | --- |
| Mercado de trabalho e investimento privado | Emprego formal, MM6 |  9.39 | 0.280 | 0.160 | 24 |
| Mercado de trabalho e investimento privado | ICMS, MM4 | 41.48 | 0.280 | 0.160 | 24 |
| Setor público estadual | Áreas prioritárias/despesa total, MM4 |  7.25 | 0.680 | 0.880 | 24 |
| Setor público estadual | Investimento/despesa total, MM4 |  1.31 | 0.920 | 0.960 | 24 |
| Consumo das famílias | Comércio, MM6 | 17.57 | 0.720 | 0.440 | 24 |
| Consumo das famílias | Serviços, MM6 |  8.80 | 0.640 | 0.440 | 24 |

### Placebos por canal

![placebo_gaps_labor_investment_smooth.png](report/figures/placebo_gaps_labor_investment_smooth.png)

![placebo_rmspe_ratio_labor_investment_smooth.png](report/figures/placebo_rmspe_ratio_labor_investment_smooth.png)

![placebo_gaps_consumption_smooth.png](report/figures/placebo_gaps_consumption_smooth.png)

![placebo_rmspe_ratio_consumption_smooth.png](report/figures/placebo_rmspe_ratio_consumption_smooth.png)

![placebo_gaps_public_sector_smooth.png](report/figures/placebo_gaps_public_sector_smooth.png)

![placebo_rmspe_ratio_public_sector_smooth.png](report/figures/placebo_rmspe_ratio_public_sector_smooth.png)

## Limitações atuais

- O ICMS do Anexo 06 é reportado como receita realizada acumulada; o fluxo bimestral usado no piloto é derivado por diferença dentro de cada ano.
- O investimento público liquidado passou por reparo de lacunas e deve ser acompanhado por uma tabela de auditoria no apêndice.
- Os placebos foram gerados para as especificações suavizadas preferidas; o mesmo procedimento pode ser estendido às séries brutas se a versão final do artigo exigir.
- Este documento é uma consolidação preliminar do piloto de Roraima, não a versão final da seção de resultados do artigo.

## Arquivos gerados

- `report/tables/augmented_effects_by_outcome.csv`
- `report/tables/top_donor_weights_by_outcome.csv`
- `report/tables/placebo_paths_preferred_smooth_augmented.csv`
- `report/tables/placebo_summary_preferred_smooth_augmented.csv`
- `report/tables/placebo_rank_actual_rr.csv`
- `report/tables/rr_2018_icms_revenue_audit.csv`
- `report/figures/`
