source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

extra_packages <- c("ggplot2", "tidyr")
missing_extra <- extra_packages[!vapply(extra_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_extra) > 0) {
  stop("Missing required packages: ", paste(missing_extra, collapse = ", "))
}
invisible(lapply(extra_packages, library, character.only = TRUE))

pilot_id <- "rr_2018_01_v3"
treated_state <- "RR"
pilot_root <- file.path(root_dir, "pilots", pilot_id)
data_dir <- file.path(pilot_root, "data")
output_root <- file.path(pilot_root, "output")
table_dir <- file.path(pilot_root, "report", "tables")
figure_dir <- file.path(pilot_root, "report", "figures")
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

event <- readr::read_csv(file.path(data_dir, "rr_2018_01_v3_event_metadata.csv"), show_col_types = FALSE) |>
  dplyr::slice(1) |>
  dplyr::mutate(
    instability_start_date = as.Date(instability_start_date),
    removal_date = as.Date(removal_date)
  )

covariates_raw <- readr::read_csv(file.path(data_dir, "rr_2018_01_v3_covariates.csv"), show_col_types = FALSE)
main_donor_states <- covariates_raw |>
  dplyr::filter(.data$donor_pool_main) |>
  dplyr::pull(.data$state_abbrev) |>
  sort()

monthly_panel <- readr::read_csv(file.path(data_dir, "rr_2018_01_v3_monthly_panel.csv"), show_col_types = FALSE) |>
  dplyr::mutate(period_date = as.Date(period_date))

fiscal_panel <- readr::read_csv(file.path(data_dir, "rr_2018_01_v3_bimonthly_fiscal_panel.csv"), show_col_types = FALSE) |>
  dplyr::mutate(period_date = as.Date(period_date))

effects_tbl <- readr::read_csv(file.path(table_dir, "augmented_effects_by_outcome.csv"), show_col_types = FALSE)
placebo_summary <- readr::read_csv(file.path(table_dir, "placebo_summary_preferred_smooth_augmented.csv"), show_col_types = FALSE)
placebo_paths <- readr::read_csv(file.path(table_dir, "placebo_paths_preferred_smooth_augmented.csv"), show_col_types = FALSE) |>
  dplyr::mutate(period_date = as.Date(period_date))
placebo_rank <- readr::read_csv(file.path(table_dir, "placebo_rank_actual_rr.csv"), show_col_types = FALSE)

make_slug <- function(x) {
  x |>
    stringr::str_replace_all("[^A-Za-z0-9]+", "_") |>
    stringr::str_replace_all("_+$", "") |>
    tolower()
}

save_plot <- function(plot, filename, width = 12, height = 7) {
  ggplot2::ggsave(
    file.path(figure_dir, filename),
    plot = plot,
    width = width,
    height = height,
    dpi = 300,
    bg = "white"
  )
}

base_theme <- function() {
  ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      legend.position = "bottom",
      plot.title.position = "plot",
      panel.grid.minor = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(size = 12)
    )
}

meta <- tibble::tribble(
  ~channel_slug, ~channel_label, ~family, ~panel_name, ~specification, ~outcome, ~plot_var, ~short_label,
  "labor_market", "Mercado de trabalho formal", "monthly", "monthly", "raw", "formal_hiring_balance_per_100k_wap", "formal_hiring_balance_per_100k_wap", "Emprego formal",
  "labor_market", "Mercado de trabalho formal", "monthly", "monthly", "raw", "formal_hiring_balance_construction_per_100k_wap", "formal_hiring_balance_construction_per_100k_wap", "Construcao civil",
  "labor_market", "Mercado de trabalho formal", "monthly", "monthly", "ma6_clean", "formal_hiring_balance_per_100k_wap_ma6_clean", "formal_hiring_balance_per_100k_wap_ma6_visual", "Emprego formal, MM6",
  "labor_market", "Mercado de trabalho formal", "monthly", "monthly", "ma6_clean", "formal_hiring_balance_construction_per_100k_wap_ma6_clean", "formal_hiring_balance_construction_per_100k_wap_ma6_visual", "Construcao civil, MM6",
  "consumption", "Consumo das familias", "monthly", "monthly", "raw", "retail_volume_index", "retail_volume_index", "Comercio",
  "consumption", "Consumo das familias", "monthly", "monthly", "raw", "services_volume_index", "services_volume_index", "Servicos",
  "consumption", "Consumo das familias", "monthly", "monthly", "ma6_clean", "retail_volume_index_ma6_clean", "retail_volume_index_ma6_visual", "Comercio, MM6",
  "consumption", "Consumo das familias", "monthly", "monthly", "ma6_clean", "services_volume_index_ma6_clean", "services_volume_index_ma6_visual", "Servicos, MM6",
  "public_sector", "Financas publicas estaduais", "bimonthly_fiscal", "fiscal", "raw", "state_tax_revenue_real_pc", "state_tax_revenue_real_pc", "Arrecadacao propria",
  "public_sector", "Financas publicas estaduais", "bimonthly_fiscal", "fiscal", "raw", "icms_revenue_real_pc", "icms_revenue_real_pc", "ICMS",
  "public_sector", "Financas publicas estaduais", "bimonthly_fiscal", "fiscal", "raw", "public_investment_liquidated_real_pc", "public_investment_liquidated_real_pc", "Investimento publico",
  "public_sector", "Financas publicas estaduais", "bimonthly_fiscal", "fiscal", "raw", "liquidated_expenditure_total_real_pc", "liquidated_expenditure_total_real_pc", "Despesa total",
  "public_sector", "Financas publicas estaduais", "bimonthly_fiscal", "fiscal", "ma4_clean", "state_tax_revenue_real_pc_ma4_clean", "state_tax_revenue_real_pc_ma4_visual", "Arrecadacao propria, MM4",
  "public_sector", "Financas publicas estaduais", "bimonthly_fiscal", "fiscal", "ma4_clean", "icms_revenue_real_pc_ma4_clean", "icms_revenue_real_pc_ma4_visual", "ICMS, MM4",
  "public_sector", "Financas publicas estaduais", "bimonthly_fiscal", "fiscal", "ma4_clean", "public_investment_liquidated_real_pc_ma4_clean", "public_investment_liquidated_real_pc_ma4_visual", "Investimento publico, MM4",
  "public_sector", "Financas publicas estaduais", "bimonthly_fiscal", "fiscal", "ma4_clean", "liquidated_expenditure_total_real_pc_ma4_clean", "liquidated_expenditure_total_real_pc_ma4_visual", "Despesa total, MM4"
)

get_panel <- function(panel_name) {
  if (panel_name == "monthly") {
    return(monthly_panel)
  }
  fiscal_panel
}

load_paths <- function(meta_rows) {
  purrr::map_dfr(
    seq_len(nrow(meta_rows)),
    function(i) {
      row <- meta_rows[i, ]
      readr::read_csv(
        file.path(output_root, row$family[[1]], row$specification[[1]], paste0(make_slug(row$outcome[[1]]), "_path.csv")),
        show_col_types = FALSE
      ) |>
        dplyr::mutate(
          period_date = as.Date(period_date),
          outcome = row$outcome[[1]],
          short_label = row$short_label[[1]]
        )
    }
  )
}

load_weights <- function(meta_rows) {
  purrr::map_dfr(
    seq_len(nrow(meta_rows)),
    function(i) {
      row <- meta_rows[i, ]
      readr::read_csv(
        file.path(output_root, row$family[[1]], row$specification[[1]], paste0(make_slug(row$outcome[[1]]), "_weights.csv")),
        show_col_types = FALSE
      ) |>
        dplyr::mutate(
          outcome = row$outcome[[1]],
          short_label = row$short_label[[1]]
        )
    }
  )
}

build_preliminary_plot <- function(channel_slug_value, specification_value) {
  meta_rows <- meta |>
    dplyr::filter(.data$channel_slug == channel_slug_value, .data$specification == specification_value)

  plot_data <- purrr::map_dfr(
    seq_len(nrow(meta_rows)),
    function(i) {
      row <- meta_rows[i, ]
      panel <- get_panel(row$panel_name[[1]])
      panel |>
        dplyr::filter(.data$state_abbrev %in% c(treated_state, main_donor_states)) |>
        dplyr::transmute(
          period_date = .data$period_date,
          state_abbrev = .data$state_abbrev,
          value = .data[[row$plot_var[[1]]]],
          short_label = row$short_label[[1]],
          treated = .data$state_abbrev == treated_state
        )
    }
  )

  donor_mean <- plot_data |>
    dplyr::filter(!.data$treated) |>
    dplyr::group_by(.data$period_date, .data$short_label) |>
    dplyr::summarise(value = mean(.data$value, na.rm = TRUE), .groups = "drop")

  ggplot2::ggplot() +
    ggplot2::annotate(
      "rect",
      xmin = event$instability_start_date,
      xmax = event$removal_date,
      ymin = -Inf,
      ymax = Inf,
      fill = "gray85",
      alpha = 0.5
    ) +
    ggplot2::geom_line(
      data = plot_data |> dplyr::filter(!.data$treated),
      ggplot2::aes(x = .data$period_date, y = .data$value, group = .data$state_abbrev),
      color = "gray70",
      alpha = 0.35,
      linewidth = 0.7
    ) +
    ggplot2::geom_line(
      data = donor_mean,
      ggplot2::aes(x = .data$period_date, y = .data$value, color = "Media dos doadores"),
      linewidth = 1
    ) +
    ggplot2::geom_line(
      data = plot_data |> dplyr::filter(.data$treated),
      ggplot2::aes(x = .data$period_date, y = .data$value, color = "Roraima"),
      linewidth = 1.2
    ) +
    ggplot2::geom_vline(xintercept = event$instability_start_date, linetype = "dotted", color = "gray25") +
    ggplot2::geom_vline(xintercept = event$removal_date, linetype = "dashed", color = "gray10") +
    ggplot2::scale_color_manual(values = c("Media dos doadores" = "#222222", "Roraima" = "#1f6f8b")) +
    ggplot2::facet_wrap(~short_label, scales = "free_y", ncol = 2) +
    ggplot2::labs(
      title = paste0("Visualizacao preliminar: ", unique(meta_rows$channel_label)),
      subtitle = if (specification_value == "raw") {
        "Linhas cinza = doadores elegiveis; area cinza = janela de instabilidade politica"
      } else {
        "Linhas cinza = doadores elegiveis; no pre a media movel so aparece com janela completa, e no pos ela recomeca com janelas expansivas"
      },
      x = NULL,
      y = NULL,
      color = NULL
    ) +
    base_theme()
}

build_augmented_paths_plot <- function(channel_slug_value, specification_value) {
  meta_rows <- meta |>
    dplyr::filter(.data$channel_slug == channel_slug_value, .data$specification == specification_value)

  path_data <- load_paths(meta_rows) |>
    tidyr::pivot_longer(
      cols = c("treated_value", "augmented_synthetic_value"),
      names_to = "series",
      values_to = "value"
    ) |>
    dplyr::mutate(
      series = dplyr::recode(
        .data$series,
        treated_value = "Roraima",
        augmented_synthetic_value = "Roraima sintetico aumentado"
      )
    )

  ggplot2::ggplot(path_data, ggplot2::aes(x = .data$period_date, y = .data$value, color = .data$series)) +
    ggplot2::annotate(
      "rect",
      xmin = event$instability_start_date,
      xmax = event$removal_date,
      ymin = -Inf,
      ymax = Inf,
      fill = "gray85",
      alpha = 0.5
    ) +
    ggplot2::geom_line(linewidth = 1.1) +
    ggplot2::geom_vline(xintercept = event$instability_start_date, linetype = "dotted", color = "gray25") +
    ggplot2::geom_vline(xintercept = event$removal_date, linetype = "dashed", color = "gray10") +
    ggplot2::scale_color_manual(values = c("Roraima" = "#1f6f8b", "Roraima sintetico aumentado" = "#6a3d9a")) +
    ggplot2::facet_wrap(~short_label, scales = "free_y", ncol = 2) +
    ggplot2::labs(
      title = paste0("Augmented SCM: trajetorias - ", unique(meta_rows$channel_label)),
      subtitle = "Apenas Augmented SCM; Classic SCM fica fora deste relatorio preliminar",
      x = NULL,
      y = NULL,
      color = NULL
    ) +
    base_theme()
}

build_augmented_gaps_plot <- function(channel_slug_value, specification_value) {
  meta_rows <- meta |>
    dplyr::filter(.data$channel_slug == channel_slug_value, .data$specification == specification_value)

  gap_data <- load_paths(meta_rows)

  ggplot2::ggplot(gap_data, ggplot2::aes(x = .data$period_date, y = .data$augmented_gap)) +
    ggplot2::annotate(
      "rect",
      xmin = event$instability_start_date,
      xmax = event$removal_date,
      ymin = -Inf,
      ymax = Inf,
      fill = "gray85",
      alpha = 0.5
    ) +
    ggplot2::geom_hline(yintercept = 0, color = "gray60", linewidth = 0.4) +
    ggplot2::geom_line(color = "#6a3d9a", linewidth = 1.1) +
    ggplot2::geom_vline(xintercept = event$instability_start_date, linetype = "dotted", color = "gray25") +
    ggplot2::geom_vline(xintercept = event$removal_date, linetype = "dashed", color = "gray10") +
    ggplot2::facet_wrap(~short_label, scales = "free_y", ncol = 2) +
    ggplot2::labs(
      title = paste0("Augmented SCM: gaps - ", unique(meta_rows$channel_label)),
      subtitle = "Gap = Roraima menos sintetico aumentado",
      x = NULL,
      y = NULL
    ) +
    base_theme()
}

build_donor_weights_plot <- function(channel_slug_value, specification_value) {
  meta_rows <- meta |>
    dplyr::filter(.data$channel_slug == channel_slug_value, .data$specification == specification_value)

  weight_data <- load_weights(meta_rows) |>
    dplyr::filter(.data$scm_weight > 0.001) |>
    dplyr::group_by(.data$short_label) |>
    dplyr::slice_max(.data$scm_weight, n = 6, with_ties = FALSE) |>
    dplyr::ungroup() |>
    dplyr::mutate(donor_state = stats::reorder(.data$donor_state, .data$scm_weight))

  ggplot2::ggplot(weight_data, ggplot2::aes(x = .data$scm_weight, y = .data$donor_state)) +
    ggplot2::geom_col(fill = "#7a52aa", alpha = 0.9) +
    ggplot2::facet_wrap(~short_label, scales = "free_y", ncol = 2) +
    ggplot2::scale_x_continuous(labels = function(x) paste0(round(100 * x), "%")) +
    ggplot2::labs(
      title = paste0("Pesos positivos dos doadores - ", unique(meta_rows$channel_label)),
      subtitle = "Pesos do SCM classico usados como base para a correcao aumentada",
      x = "Peso",
      y = NULL
    ) +
    base_theme()
}

build_effect_summary_plot <- function() {
  plot_data <- effects_tbl |>
    dplyr::filter(.data$preferred_smooth) |>
    dplyr::mutate(
      channel = dplyr::recode(
        .data$channel,
        "Mercado de trabalho formal" = "Mercado de trabalho formal",
        "Consumo das familias" = "Consumo das familias",
        "Financas publicas estaduais" = "Financas publicas estaduais"
      ),
      short_label = factor(.data$short_label, levels = rev(unique(.data$short_label)))
    )

  ggplot2::ggplot(plot_data, ggplot2::aes(x = .data$mean_gap_post, y = .data$short_label, color = .data$channel)) +
    ggplot2::geom_vline(xintercept = 0, color = "gray70", linewidth = 0.4) +
    ggplot2::geom_point(size = 3) +
    ggplot2::scale_color_manual(values = c(
      "Mercado de trabalho formal" = "#1f6f8b",
      "Consumo das familias" = "#c65a2e",
      "Financas publicas estaduais" = "#6a3d9a"
    )) +
    ggplot2::labs(
      title = "Resumo grafico dos efeitos pos-tratamento",
      subtitle = "Gap medio pos-tratamento nas especificacoes suavizadas preferidas",
      x = "Gap medio pos-tratamento",
      y = NULL,
      color = NULL
    ) +
    base_theme()
}

build_placebo_gaps_plot <- function(channel_slug_value) {
  rr_outcomes <- effects_tbl |>
    dplyr::filter(.data$preferred_smooth) |>
    dplyr::mutate(
      channel_slug = dplyr::case_when(
        .data$channel == "Mercado de trabalho formal" ~ "labor_market",
        .data$channel == "Consumo das familias" ~ "consumption",
        .data$channel == "Financas publicas estaduais" ~ "public_sector",
        TRUE ~ NA_character_
      )
    ) |>
    dplyr::filter(.data$channel_slug == channel_slug_value) |>
    dplyr::select("outcome", "short_label", "family", "specification", "augmented_rmspe_pre")

  rr_paths <- purrr::map_dfr(
    seq_len(nrow(rr_outcomes)),
    function(i) {
      row <- rr_outcomes[i, ]
      readr::read_csv(
        file.path(output_root, row$family[[1]], row$specification[[1]], paste0(make_slug(row$outcome[[1]]), "_path.csv")),
        show_col_types = FALSE
      ) |>
        dplyr::mutate(
          period_date = as.Date(period_date),
          short_label = row$short_label[[1]],
          normalized_gap = .data$augmented_gap / row$augmented_rmspe_pre[[1]]
        ) |>
        dplyr::select("period_date", "short_label", "normalized_gap")
    }
  )

  placebo_data <- placebo_paths |>
    dplyr::filter(.data$channel_slug == channel_slug_value) |>
    dplyr::left_join(
      placebo_summary |>
        dplyr::select("outcome", "pseudo_treated_state", "pre_rmspe"),
      by = c("outcome", "pseudo_treated_state")
    ) |>
    dplyr::mutate(normalized_gap = .data$augmented_gap / .data$pre_rmspe)

  channel_label <- if (channel_slug_value == "labor_market") {
    "Mercado de trabalho formal"
  } else if (channel_slug_value == "consumption") {
    "Consumo das familias"
  } else {
    "Financas publicas estaduais"
  }

  ggplot2::ggplot() +
    ggplot2::annotate(
      "rect",
      xmin = event$instability_start_date,
      xmax = event$removal_date,
      ymin = -Inf,
      ymax = Inf,
      fill = "gray85",
      alpha = 0.5
    ) +
    ggplot2::geom_hline(yintercept = 0, color = "gray65", linewidth = 0.4) +
    ggplot2::geom_line(
      data = placebo_data,
      ggplot2::aes(x = .data$period_date, y = .data$normalized_gap, group = .data$pseudo_treated_state),
      color = "gray70",
      alpha = 0.45,
      linewidth = 0.6
    ) +
    ggplot2::geom_line(
      data = rr_paths,
      ggplot2::aes(x = .data$period_date, y = .data$normalized_gap, color = "Roraima"),
      linewidth = 1.1
    ) +
    ggplot2::geom_vline(xintercept = event$instability_start_date, linetype = "dotted", color = "gray25") +
    ggplot2::geom_vline(xintercept = event$removal_date, linetype = "dashed", color = "gray10") +
    ggplot2::scale_color_manual(values = c("Roraima" = "#1f6f8b")) +
    ggplot2::facet_wrap(~short_label, scales = "free_y", ncol = 2) +
    ggplot2::labs(
      title = paste0("Placebos in-space: gaps normalizados - ", channel_label),
      subtitle = "Linhas cinza = placebos; linha azul = Roraima",
      x = NULL,
      y = NULL,
      color = NULL
    ) +
    base_theme()
}

build_placebo_ratio_plot <- function(channel_slug_value) {
  plot_data <- placebo_rank |>
    dplyr::filter(.data$channel_slug == channel_slug_value) |>
    dplyr::mutate(short_label = factor(.data$short_label, levels = rev(unique(.data$short_label))))

  channel_label <- if (channel_slug_value == "labor_market") {
    "Mercado de trabalho formal"
  } else if (channel_slug_value == "consumption") {
    "Consumo das familias"
  } else {
    "Financas publicas estaduais"
  }

  ggplot2::ggplot(plot_data, ggplot2::aes(x = .data$post_pre_rmspe_ratio, y = .data$short_label)) +
    ggplot2::geom_col(fill = "#7a52aa", alpha = 0.9) +
    ggplot2::labs(
      title = paste0("Placebos in-space: razao RMSPE pos/pre - ", channel_label),
      subtitle = "Razao calculada para Roraima em cada desfecho suavizado preferido",
      x = "Razao RMSPE pos/pre",
      y = NULL
    ) +
    base_theme()
}

save_plot(build_preliminary_plot("labor_market", "raw"), "preliminary_labor_market_raw.png")
save_plot(build_preliminary_plot("labor_market", "ma6_clean"), "preliminary_labor_market_smooth.png")
save_plot(build_preliminary_plot("consumption", "raw"), "preliminary_consumption_raw.png")
save_plot(build_preliminary_plot("consumption", "ma6_clean"), "preliminary_consumption_smooth.png")
save_plot(build_preliminary_plot("public_sector", "raw"), "preliminary_public_sector_raw.png", width = 13, height = 8)
save_plot(build_preliminary_plot("public_sector", "ma4_clean"), "preliminary_public_sector_smooth.png", width = 13, height = 8)

save_plot(build_augmented_paths_plot("labor_market", "raw"), "augmented_paths_labor_market_raw.png")
save_plot(build_augmented_paths_plot("labor_market", "ma6_clean"), "augmented_paths_labor_market_smooth.png")
save_plot(build_augmented_paths_plot("consumption", "raw"), "augmented_paths_consumption_raw.png")
save_plot(build_augmented_paths_plot("consumption", "ma6_clean"), "augmented_paths_consumption_smooth.png")
save_plot(build_augmented_paths_plot("public_sector", "raw"), "augmented_paths_public_sector_raw.png", width = 13, height = 8)
save_plot(build_augmented_paths_plot("public_sector", "ma4_clean"), "augmented_paths_public_sector_smooth.png", width = 13, height = 8)

save_plot(build_augmented_gaps_plot("labor_market", "raw"), "augmented_gaps_labor_market_raw.png")
save_plot(build_augmented_gaps_plot("labor_market", "ma6_clean"), "augmented_gaps_labor_market_smooth.png")
save_plot(build_augmented_gaps_plot("consumption", "raw"), "augmented_gaps_consumption_raw.png")
save_plot(build_augmented_gaps_plot("consumption", "ma6_clean"), "augmented_gaps_consumption_smooth.png")
save_plot(build_augmented_gaps_plot("public_sector", "raw"), "augmented_gaps_public_sector_raw.png", width = 13, height = 8)
save_plot(build_augmented_gaps_plot("public_sector", "ma4_clean"), "augmented_gaps_public_sector_smooth.png", width = 13, height = 8)

save_plot(build_donor_weights_plot("labor_market", "raw"), "donor_weights_labor_market_raw.png")
save_plot(build_donor_weights_plot("labor_market", "ma6_clean"), "donor_weights_labor_market_smooth.png")
save_plot(build_donor_weights_plot("consumption", "raw"), "donor_weights_consumption_raw.png")
save_plot(build_donor_weights_plot("consumption", "ma6_clean"), "donor_weights_consumption_smooth.png")
save_plot(build_donor_weights_plot("public_sector", "raw"), "donor_weights_public_sector_raw.png", width = 13, height = 8)
save_plot(build_donor_weights_plot("public_sector", "ma4_clean"), "donor_weights_public_sector_smooth.png", width = 13, height = 8)

save_plot(build_effect_summary_plot(), "augmented_effect_summary.png", width = 10, height = 6)

save_plot(build_placebo_gaps_plot("labor_market"), "placebo_gaps_labor_market_smooth.png")
save_plot(build_placebo_gaps_plot("consumption"), "placebo_gaps_consumption_smooth.png")
save_plot(build_placebo_gaps_plot("public_sector"), "placebo_gaps_public_sector_smooth.png", width = 13, height = 8)

save_plot(build_placebo_ratio_plot("labor_market"), "placebo_rmspe_ratio_labor_market_smooth.png", width = 10, height = 4)
save_plot(build_placebo_ratio_plot("consumption"), "placebo_rmspe_ratio_consumption_smooth.png", width = 10, height = 4)
save_plot(build_placebo_ratio_plot("public_sector"), "placebo_rmspe_ratio_public_sector_smooth.png", width = 10, height = 5)

message("RR 2018-01 V3 report figures regenerated with stable ASCII labels.")

