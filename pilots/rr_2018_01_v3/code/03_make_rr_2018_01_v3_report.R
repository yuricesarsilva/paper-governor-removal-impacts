source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

pilot_id <- "rr_2018_01_v3"
treated_state <- "RR"
pilot_root <- file.path(root_dir, "pilots", pilot_id)
data_dir <- file.path(pilot_root, "data")
output_root <- file.path(pilot_root, "output")
report_dir <- file.path(pilot_root, "report")
figure_dir <- file.path(report_dir, "figures")
table_dir <- file.path(report_dir, "tables")
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)

make_slug <- function(x) {
  x |>
    stringr::str_replace_all("[^A-Za-z0-9]+", "_") |>
    stringr::str_replace_all("_+$", "") |>
    tolower()
}

format_num <- function(x, digits = 2) {
  ifelse(is.na(x), "", format(round(x, digits), nsmall = digits, big.mark = ","))
}

make_markdown_table <- function(data) {
  if (nrow(data) == 0) {
    return(character(0))
  }
  header <- paste0("| ", paste(names(data), collapse = " | "), " |")
  separator <- paste0("| ", paste(rep("---", ncol(data)), collapse = " | "), " |")
  rows <- apply(data, 1, function(row) paste0("| ", paste(row, collapse = " | "), " |"))
  c(header, separator, rows)
}

figure_link <- function(filename) {
  paste0("![", filename, "](report/figures/", filename, ")")
}

event <- readr::read_csv(
  file.path(data_dir, "rr_2018_01_v3_event_metadata.csv"),
  show_col_types = FALSE
) |>
  dplyr::slice(1) |>
  dplyr::mutate(
    instability_start_date = as.Date(instability_start_date),
    removal_date = as.Date(removal_date)
  )

covariates_raw <- readr::read_csv(
  file.path(data_dir, "rr_2018_01_v3_covariates.csv"),
  show_col_types = FALSE
)

fiscal_panel <- readr::read_csv(
  file.path(data_dir, "rr_2018_01_v3_bimonthly_fiscal_panel.csv"),
  show_col_types = FALSE
) |>
  dplyr::mutate(period_date = as.Date(period_date))

summary_tbl <- readr::read_csv(
  file.path(output_root, "rr_2018_01_v3_scm_summary.csv"),
  show_col_types = FALSE
)

outcome_meta <- tibble::tribble(
  ~outcome, ~label, ~short_label, ~channel, ~subblock, ~family, ~specification, ~preferred_smooth, ~preliminary_outcome,
  "formal_hiring_balance_per_100k_wap", "Saldo de emprego formal por 100 mil pessoas em idade ativa", "Emprego formal", "Mercado de trabalho formal", NA_character_, "monthly", "raw", FALSE, "formal_hiring_balance_per_100k_wap",
  "formal_hiring_balance_construction_per_100k_wap", "Saldo de emprego formal da construcao civil por 100 mil pessoas em idade ativa", "Construcao civil", "Mercado de trabalho formal", NA_character_, "monthly", "raw", FALSE, "formal_hiring_balance_construction_per_100k_wap",
  "retail_volume_index", "Indice de volume do comercio varejista", "Comercio", "Consumo das familias", NA_character_, "monthly", "raw", FALSE, "retail_volume_index",
  "services_volume_index", "Indice de volume de servicos", "Servicos", "Consumo das familias", NA_character_, "monthly", "raw", FALSE, "services_volume_index",
  "state_tax_revenue_real_pc", "Receita tributaria estadual real per capita", "Arrecadacao propria", "Financas publicas estaduais", "receitas", "bimonthly_fiscal", "raw", FALSE, "state_tax_revenue_real_pc",
  "icms_revenue_real_pc", "Receita de ICMS real per capita", "ICMS", "Financas publicas estaduais", "receitas", "bimonthly_fiscal", "raw", FALSE, "icms_revenue_real_pc",
  "public_investment_liquidated_real_pc", "Investimento publico liquidado per capita", "Investimento publico", "Financas publicas estaduais", "despesas", "bimonthly_fiscal", "raw", FALSE, "public_investment_liquidated_real_pc",
  "liquidated_expenditure_total_real_pc", "Despesa total liquidada per capita", "Despesa total", "Financas publicas estaduais", "despesas", "bimonthly_fiscal", "raw", FALSE, "liquidated_expenditure_total_real_pc",
  "formal_hiring_balance_per_100k_wap_ma6_clean", "Saldo de emprego formal por 100 mil pessoas em idade ativa, media movel limpa de 6 meses", "Emprego formal, MM6", "Mercado de trabalho formal", NA_character_, "monthly", "ma6_clean", TRUE, "formal_hiring_balance_per_100k_wap_ma6_visual",
  "formal_hiring_balance_construction_per_100k_wap_ma6_clean", "Saldo de emprego formal da construcao civil por 100 mil pessoas em idade ativa, media movel limpa de 6 meses", "Construcao civil, MM6", "Mercado de trabalho formal", NA_character_, "monthly", "ma6_clean", TRUE, "formal_hiring_balance_construction_per_100k_wap_ma6_visual",
  "retail_volume_index_ma6_clean", "Indice de volume do comercio varejista, media movel limpa de 6 meses", "Comercio, MM6", "Consumo das familias", NA_character_, "monthly", "ma6_clean", TRUE, "retail_volume_index_ma6_visual",
  "services_volume_index_ma6_clean", "Indice de volume de servicos, media movel limpa de 6 meses", "Servicos, MM6", "Consumo das familias", NA_character_, "monthly", "ma6_clean", TRUE, "services_volume_index_ma6_visual",
  "state_tax_revenue_real_pc_ma4_clean", "Receita tributaria estadual real per capita, media movel limpa de 4 bimestres", "Arrecadacao propria, MM4", "Financas publicas estaduais", "receitas", "bimonthly_fiscal", "ma4_clean", TRUE, "state_tax_revenue_real_pc_ma4_visual",
  "icms_revenue_real_pc_ma4_clean", "Receita de ICMS real per capita, media movel limpa de 4 bimestres", "ICMS, MM4", "Financas publicas estaduais", "receitas", "bimonthly_fiscal", "ma4_clean", TRUE, "icms_revenue_real_pc_ma4_visual",
  "public_investment_liquidated_real_pc_ma4_clean", "Investimento publico liquidado per capita, media movel limpa de 4 bimestres", "Investimento publico, MM4", "Financas publicas estaduais", "despesas", "bimonthly_fiscal", "ma4_clean", TRUE, "public_investment_liquidated_real_pc_ma4_visual",
  "liquidated_expenditure_total_real_pc_ma4_clean", "Despesa total liquidada per capita, media movel limpa de 4 bimestres", "Despesa total, MM4", "Financas publicas estaduais", "despesas", "bimonthly_fiscal", "ma4_clean", TRUE, "liquidated_expenditure_total_real_pc_ma4_visual"
) |>
  dplyr::mutate(
    channel_slug = dplyr::case_when(
      channel == "Mercado de trabalho formal" ~ "labor_market",
      channel == "Consumo das familias" ~ "consumption",
      channel == "Financas publicas estaduais" ~ "public_sector"
    )
  )

rr_icms_2018_audit <- fiscal_panel |>
  dplyr::filter(state_abbrev == "RR", year == 2018) |>
  dplyr::arrange(bimester) |>
  dplyr::select(
    period,
    period_date,
    icms_revenue_cumulative_nominal,
    icms_revenue_nominal,
    icms_revenue_real,
    pnadc_population,
    icms_revenue_real_pc,
    icms_revenue_flow_is_derived,
    icms_revenue_negative_flow_flag,
    analysis_period
  )

readr::write_csv(
  rr_icms_2018_audit,
  file.path(table_dir, "rr_2018_icms_revenue_audit.csv"),
  na = ""
)

rr_liquidated_expenditure_total_audit <- fiscal_panel |>
  dplyr::filter(state_abbrev == "RR") |>
  dplyr::arrange(year, bimester) |>
  dplyr::select(
    period,
    period_date,
    year,
    bimester,
    liquidated_expenditure_total_nominal,
    liquidated_expenditure_total_real,
    pnadc_population,
    resident_population,
    fiscal_population_denominator,
    fiscal_population_source,
    liquidated_expenditure_total_real_pc,
    original_liquidated_expenditure_total_missing,
    liquidated_expenditure_total_recovered_from_raw,
    liquidated_expenditure_total_imputed_adjacent_mean,
    liquidated_expenditure_total_imputation_method,
    analysis_period
  )

readr::write_csv(
  rr_liquidated_expenditure_total_audit,
  file.path(table_dir, "rr_liquidated_expenditure_total_audit.csv"),
  na = ""
)

effects_tbl <- summary_tbl |>
  dplyr::left_join(
    outcome_meta |>
      dplyr::select(outcome, label, short_label, channel, subblock, family, specification, preferred_smooth),
    by = c("outcome", "family", "specification")
  ) |>
  dplyr::filter(status == "estimated") |>
  dplyr::transmute(
    outcome,
    label,
    short_label,
    channel,
    subblock,
    family,
    specification,
    preferred_smooth,
    mean_gap_crisis = augmented_mean_gap_crisis,
    mean_gap_post = augmented_mean_gap_post,
    mean_gap_pre = augmented_mean_gap_pre,
    augmented_rmspe_pre,
    augmented_rmspe_crisis,
    augmented_rmspe_post,
    donor_count
  )

readr::write_csv(
  effects_tbl,
  file.path(table_dir, "augmented_effects_by_outcome.csv"),
  na = ""
)

read_weights <- function(family, specification, outcome) {
  readr::read_csv(
    file.path(output_root, family, specification, paste0(make_slug(outcome), "_weights.csv")),
    show_col_types = FALSE
  ) |>
    dplyr::mutate(outcome = outcome)
}

top_weights_tbl <- outcome_meta |>
  dplyr::filter(preferred_smooth) |>
  dplyr::select(outcome, family, specification, short_label, channel) |>
  purrr::pmap_dfr(function(outcome, family, specification, short_label, channel) {
    read_weights(family, specification, outcome) |>
      dplyr::arrange(dplyr::desc(scm_weight)) |>
      dplyr::slice_head(n = 5) |>
      dplyr::mutate(short_label = short_label, channel = channel)
  })

readr::write_csv(
  top_weights_tbl,
  file.path(table_dir, "top_donor_weights_by_outcome.csv"),
  na = ""
)

placebo_rank_path <- file.path(table_dir, "placebo_rank_actual_rr.csv")
if (!file.exists(placebo_rank_path)) {
  stop("Missing cached placebo summary at: ", placebo_rank_path)
}

actual_placebo_rank <- readr::read_csv(placebo_rank_path, show_col_types = FALSE) |>
  dplyr::left_join(
    outcome_meta |>
      dplyr::select(outcome, short_label_current = short_label, channel_current = channel, channel_slug_current = channel_slug),
    by = "outcome"
  ) |>
  dplyr::mutate(
    short_label = dplyr::coalesce(short_label_current, short_label),
    channel = dplyr::coalesce(channel_current, channel),
    channel_slug = dplyr::coalesce(channel_slug_current, channel_slug)
  ) |>
  dplyr::select(-dplyr::any_of(c("short_label_current", "channel_current", "channel_slug_current")))

preferred_effects_md <- effects_tbl |>
  dplyr::filter(preferred_smooth) |>
  dplyr::transmute(
    Canal = channel,
    Variavel = short_label,
    `Gap medio crise` = format_num(mean_gap_crisis),
    `Gap medio pos` = format_num(mean_gap_post),
    `RMSPE pre` = format_num(augmented_rmspe_pre),
    `RMSPE pos` = format_num(augmented_rmspe_post),
    Doadores = as.character(donor_count)
  )

raw_effects_md <- effects_tbl |>
  dplyr::filter(!preferred_smooth) |>
  dplyr::transmute(
    Canal = channel,
    Variavel = short_label,
    `Gap medio crise` = format_num(mean_gap_crisis),
    `Gap medio pos` = format_num(mean_gap_post),
    `RMSPE pre` = format_num(augmented_rmspe_pre),
    `RMSPE pos` = format_num(augmented_rmspe_post),
    Doadores = as.character(donor_count)
  )

placebo_md <- actual_placebo_rank |>
  dplyr::transmute(
    Canal = channel,
    Variavel = short_label,
    `Razao RMSPE pos/pre` = format_num(post_pre_rmspe_ratio),
    `p RMSPE` = format_num(ratio_p_value, 3),
    `p gap absoluto` = format_num(abs_gap_p_value, 3),
    Placebos = as.character(donor_placebo_count)
  )

apply_report_text_fixes <- function(lines) {
  lines
}

report_lines <- c(
  "# RR 2018-01: Resultados preliminares do piloto V3",
  "",
  paste0("Documento gerado em ", format(Sys.Date(), "%Y-%m-%d"), "."),
  "",
  "Este documento consolida a primeira rodada de resultados para o caso de Roraima em 2018. O objetivo e organizar, em formato proximo ao de uma secao empirica de artigo, os resultados do Augmented Synthetic Control Method (Augmented SCM) para tres canais do desenho atual do projeto: mercado de trabalho formal, consumo das familias e financas publicas estaduais.",
  "",
  "## Desenho do evento",
  "",
  paste0("- Unidade tratada: `", treated_state, "`."),
  paste0("- Inicio da instabilidade politica: `", event$instability_start_date, "`."),
  paste0("- Queda/intervencao efetiva: `", event$removal_date, "`."),
  "",
  "As observacoes anteriores ao inicio da instabilidade sao tratadas como pre-tratamento limpo. A janela entre o inicio da instabilidade e a queda efetiva e mantida como periodo de crise politica. As observacoes posteriores a queda/intervencao sao tratadas como pos-tratamento.",
  "",
  "## Estrategia metodologica",
  "",
  "O pool principal de doadores exclui `RR`, `AM` e `TO`. Roraima e excluida por ser a unidade tratada. Amazonas e excluido por ter o evento `AM_2017_01` dentro da janela principal de estimacao do piloto. Tocantins e excluido pelo mesmo criterio, em especial por `TO_2018_01`. Assim, a especificacao principal utiliza 24 UFs elegiveis como doadores.",
  "",
  "A unidade tratada e Roraima. Para cada desfecho, o metodo construiu uma combinacao convexa de estados doadores capaz de aproximar a trajetoria pre-tratamento e as covariaveis pre-evento de Roraima. Seja \\(Y_{1t}\\) o resultado observado em Roraima no periodo \\(t\\), e seja \\(Y_{jt}\\) o resultado observado no estado doador \\(j = 2, \\ldots, J+1\\). O sintetico classico e definido por:",
  "",
  "\\[",
  "\\widehat{Y}^{SCM}_{1t} = \\sum_{j=2}^{J+1} w_j Y_{jt}, \\qquad w_j \\geq 0, \\qquad \\sum_{j=2}^{J+1} w_j = 1.",
  "\\]",
  "",
  "Os pesos \\(w_j\\) minimizam a distancia entre os preditores da unidade tratada, \\(X_1\\), e os preditores ponderados dos doadores, \\(X_0 W\\):",
  "",
  "\\[",
  "\\widehat{W} = \\arg\\min_W (X_1 - X_0 W)' V (X_1 - X_0 W),",
  "\\]",
  "",
  "sujeito as restricoes de nao negatividade e soma unitaria. Na implementacao atual, os preditores incluem a trajetoria pre-tratamento completa disponivel da propria variavel dependente e covariaveis estaduais pre-evento: taxa de desemprego, taxa de formalizacao, dependencia de transferencias, despesa em saude per capita, despesa em educacao per capita e despesa em seguranca publica per capita.",
  "",
  "O estimador principal neste relatorio e o Augmented SCM. Ele preserva a estrutura de pesos do SCM e adiciona uma correcao de vies estimada por regressao ridge nos doadores. De forma compacta:",
  "",
  "\\[",
  "\\widehat{Y}^{ASCM}_{1t} = \\widehat{Y}^{SCM}_{1t} + \\widehat{m}_t(X_1) - \\sum_{j=2}^{J+1} \\widehat{w}_j \\widehat{m}_t(X_j),",
  "\\]",
  "",
  "em que \\(\\widehat{m}_t(\\cdot)\\) e uma funcao ridge ajustada entre os estados doadores para cada periodo. O efeito estimado em Roraima e:",
  "",
  "\\[",
  "\\widehat{\\tau}_{1t} = Y_{1t} - \\widehat{Y}^{ASCM}_{1t}.",
  "\\]",
  "",
  "Valores positivos indicam que Roraima ficou acima do contrafactual sintetico; valores negativos indicam desempenho abaixo do contrafactual. Para as variaveis mensais, o relatorio mostra resultados brutos e medias moveis de 6 meses. Para as variaveis bimestrais, mostra resultados brutos e medias moveis de 4 bimestres. No periodo pre-tratamento, a media movel exige janela completa ate o ultimo periodo pre. No periodo pos-tratamento, a media movel recomeca no primeiro periodo pos e cresce de forma expansiva ate atingir a janela cheia.",
  "",
  "## Variaveis e canais",
  "",
  "- Mercado de trabalho formal: saldo de emprego formal por 100 mil pessoas em idade ativa e saldo de emprego formal da construcao civil por 100 mil pessoas em idade ativa.",
  "- Consumo das familias: indice de volume do comercio varejista e indice de volume de servicos.",
  "- Financas publicas estaduais, receitas: arrecadacao propria real per capita e receita de ICMS real per capita.",
  "- Financas publicas estaduais, despesas: investimento publico liquidado per capita e despesa total liquidada per capita.",
  "",
  "A normalizacao por populacao ou por escala de mercado e importante porque os estados brasileiros diferem muito em tamanho. Por isso, as variaveis fiscais sao per capita, os saldos formais sao expressos por 100 mil pessoas em idade ativa e as series de comercio/servicos entram como indices de volume reancorados em 100 na primeira observacao valida da janela do piloto para cada estado.",
  "",
  "## Visualizacao preliminar dos dados",
  "",
  "As figuras abaixo comparam Roraima com a media simples dos doadores elegiveis antes de aplicar o controle sintetico. Elas nao devem ser interpretadas como efeito causal; servem para expor escala, volatilidade, quebras e diferencas iniciais entre Roraima e o conjunto de comparacao.",
  "",
  "Para facilitar a inspecao, as linhas cinza mostram os estados doadores elegiveis em traco fino e transparente; Roraima e a media simples dos doadores aparecem em tons mais escuros. Nas figuras suavizadas do V3, o pre-tratamento so aparece quando a janela movel completa esta disponivel, enquanto o pos-tratamento recomeca no primeiro periodo pos e vai acumulando 1, 2, 3 observacoes ate atingir a janela definida.",
  "",
  "A receita de ICMS foi extraida do arquivo bruto local do Siconfi/RREO, Anexo 06, conta `RREO6ICMS`. Como a fonte reporta a receita realizada acumulada ate o bimestre, o fluxo bimestral usado no painel e derivado por diferenca dentro de cada ano. A tabela de auditoria para Roraima em 2018 esta em `report/tables/rr_2018_icms_revenue_audit.csv`.",
  "",
  "A despesa total liquidada agora segue o mesmo tratamento aplicado ao investimento publico: quando o Anexo 02 traz apenas o acumulado ate o bimestre, o fluxo bimestral e reconstruido por diferenca dentro do ano; quando a fonte permanece vazia, o reparo usa interpolacao linear entre bimestres adjacentes observados. A tabela de auditoria especifica para Roraima esta em `report/tables/rr_liquidated_expenditure_total_audit.csv`, com valores nominais, reais, per capita e flags de reparo ao longo da janela do piloto.",
  "",
  "### Mercado de trabalho formal",
  "",
  figure_link("preliminary_labor_market_raw.png"),
  "",
  figure_link("preliminary_labor_market_smooth.png"),
  "",
  "### Consumo das familias",
  "",
  figure_link("preliminary_consumption_raw.png"),
  "",
  figure_link("preliminary_consumption_smooth.png"),
  "",
  "### Financas publicas estaduais",
  "",
  figure_link("preliminary_public_sector_raw.png"),
  "",
  figure_link("preliminary_public_sector_smooth.png"),
  "",
  "## Resultados principais: Augmented SCM",
  "",
  "A tabela resume os resultados para as especificacoes suavizadas, que reduzem volatilidade mensal/bimestral e seguem a regra do V3: janela completa no pre e janela expansiva no pos.",
  "",
  "Nas especificacoes suavizadas, a coluna de crise politica pode ficar vazia porque a janela entre instabilidade e queda efetiva e curta demais para sustentar uma serie suavizada informativa. Nesses casos, a leitura da transicao imediata deve privilegiar os graficos brutos.",
  "",
  make_markdown_table(preferred_effects_md),
  "",
  "Como leitura preliminar, a interpretacao deve privilegiar tres elementos: a qualidade do ajuste pre-tratamento, medida pelo RMSPE pre; o sinal e tamanho do gap durante a crise politica; e a persistencia do gap no periodo posterior a queda/intervencao.",
  "",
  "### Mercado de trabalho formal",
  "",
  figure_link("augmented_paths_labor_market_raw.png"),
  "",
  figure_link("augmented_gaps_labor_market_raw.png"),
  "",
  figure_link("augmented_paths_labor_market_smooth.png"),
  "",
  figure_link("augmented_gaps_labor_market_smooth.png"),
  "",
  "No canal de mercado de trabalho formal, o saldo agregado e o saldo da construcao civil capturam duas margens complementares do emprego com carteira. O primeiro resume a dinamica formal do mercado de trabalho estadual. O segundo observa uma margem setorial mais ciclica e sensivel a mudancas de atividade e expectativas. A especificacao suavizada e especialmente relevante porque ambas as series podem ter alta volatilidade de curto prazo.",
  "",
  "### Consumo das familias",
  "",
  figure_link("augmented_paths_consumption_raw.png"),
  "",
  figure_link("augmented_gaps_consumption_raw.png"),
  "",
  figure_link("augmented_paths_consumption_smooth.png"),
  "",
  figure_link("augmented_gaps_consumption_smooth.png"),
  "",
  "O canal de consumo e observado por comercio varejista e servicos, ambos reancorados em 100 no inicio da janela do piloto. A leitura conjunta e importante porque familias podem ajustar consumo de bens e servicos de forma diferente em resposta a incerteza politica, perda de renda esperada ou mudancas no funcionamento do setor publico local.",
  "",
  "### Financas publicas estaduais",
  "",
  figure_link("augmented_paths_public_sector_raw.png"),
  "",
  figure_link("augmented_gaps_public_sector_raw.png"),
  "",
  figure_link("augmented_paths_public_sector_smooth.png"),
  "",
  figure_link("augmented_gaps_public_sector_smooth.png"),
  "",
  "No canal de financas publicas estaduais, o subbloco de receitas combina arrecadacao propria e ICMS para observar a margem tributaria do estado. O subbloco de despesas combina investimento publico liquidado e despesa total liquidada para observar escala de gasto e compressao de investimento. As duas series exigem cautela adicional porque passaram por reparo de lacunas no Siconfi/RREO; por isso devem ser lidas junto das auditorias de dados e dos resultados de robustez.",
  "",
  "### Resumo grafico dos efeitos",
  "",
  figure_link("augmented_effect_summary.png"),
  "",
  "## Pesos dos doadores",
  "",
  "As figuras de pesos ajudam a avaliar a plausibilidade do contrafactual. Pesos muito concentrados podem indicar que poucos estados sao responsaveis pela aproximacao de Roraima; pesos mais dispersos sugerem uma composicao mais diversificada, embora a qualidade substantiva dependa tambem do ajuste pre-tratamento.",
  "",
  figure_link("donor_weights_labor_market_smooth.png"),
  "",
  figure_link("donor_weights_consumption_smooth.png"),
  "",
  figure_link("donor_weights_public_sector_smooth.png"),
  "",
  "## Robustez",
  "",
  "A primeira checagem de robustez compara especificacoes brutas e suavizadas. As series brutas preservam choques de curtissimo prazo, mas podem exagerar ruido operacional, sazonalidade residual e irregularidades administrativas. As series suavizadas reduzem esse ruido e sao, por ora, a especificacao preferida para leitura substantiva.",
  "",
  "Resultados brutos:",
  "",
  make_markdown_table(raw_effects_md),
  "",
  "Resultados suavizados:",
  "",
  make_markdown_table(preferred_effects_md),
  "",
  "A segunda checagem e a separacao explicita entre janela de crise politica e periodo pos-queda. Isso evita tratar o evento como um unico ponto instantaneo e permite avaliar se efeitos aparecem durante a instabilidade, depois da remocao efetiva, ou em ambos os momentos. Essa distincao e substantivamente importante porque processos legislativos ou judiciais podem afetar expectativas antes da troca formal de comando.",
  "",
  "A terceira checagem e a leitura do ajuste pre-tratamento. Resultados com RMSPE pre muito alto devem receber menor peso interpretativo, pois o contrafactual e menos crivel. Nos proximos ciclos, tambem faz sentido acrescentar janelas alternativas de pre-tratamento e excluir doadores de alta influencia para checar sensibilidade dos pesos.",
  "",
  "## Placebos in-space",
  "",
  "Os placebos in-space reestimam o Augmented SCM tratando cada estado elegivel do pool principal como se tivesse recebido o tratamento, mantendo Roraima como a unidade efetivamente tratada. `AM` e `TO` nao entram como placebos porque tambem foram excluidos do pool principal. Para os estados placebo, Roraima permanece fora do conjunto de doadores. Os gaps sao normalizados pelo RMSPE pre-tratamento da propria unidade placebo:",
  "",
  "\\[",
  "g^{norm}_{it} = \\frac{Y_{it} - \\widehat{Y}^{ASCM}_{it}}{RMSPE^{pre}_i}.",
  "\\]",
  "",
  "Essa normalizacao torna comparaveis unidades com escalas diferentes. O teste nao e uma inferencia randomizada formal, mas fornece uma avaliacao visual e ordinal: se Roraima estiver entre os maiores desvios pos-tratamento em relacao aos placebos, o resultado e mais consistente com um efeito excepcional do evento.",
  "",
  make_markdown_table(placebo_md),
  "",
  "### Placebos por canal",
  "",
  figure_link("placebo_gaps_labor_market_smooth.png"),
  "",
  figure_link("placebo_rmspe_ratio_labor_market_smooth.png"),
  "",
  figure_link("placebo_gaps_consumption_smooth.png"),
  "",
  figure_link("placebo_rmspe_ratio_consumption_smooth.png"),
  "",
  figure_link("placebo_gaps_public_sector_smooth.png"),
  "",
  figure_link("placebo_rmspe_ratio_public_sector_smooth.png"),
  "",
  "## Limitacoes atuais",
  "",
  "- O ICMS do Anexo 06 e reportado como receita realizada acumulada; o fluxo bimestral usado no piloto e derivado por diferenca dentro de cada ano.",
  "- O investimento publico liquidado e a despesa total liquidada passaram por reparo de lacunas e devem ser acompanhados por suas tabelas de auditoria no apendice.",
  "- Os placebos foram gerados e salvos em tabelas separadas; este script reaproveita esses resultados para evitar recalculo desnecessario.",
  "- Este documento e uma consolidacao preliminar do piloto de Roraima, nao a versao final da secao de resultados do artigo.",
  "",
  "## Arquivos gerados",
  "",
  "- `report/tables/augmented_effects_by_outcome.csv`",
  "- `report/tables/top_donor_weights_by_outcome.csv`",
  "- `report/tables/placebo_rank_actual_rr.csv`",
  "- `report/tables/rr_2018_icms_revenue_audit.csv`",
  "- `report/tables/rr_liquidated_expenditure_total_audit.csv`",
  "- `report/figures/`"
)

readr::write_lines(
  apply_report_text_fixes(report_lines),
  file.path(pilot_root, "rr_2018_01_v3_results_report.md")
)

message("RR 2018-01 V3 report completed.")
message("Saved report to: ", file.path(pilot_root, "rr_2018_01_v3_results_report.md"))

