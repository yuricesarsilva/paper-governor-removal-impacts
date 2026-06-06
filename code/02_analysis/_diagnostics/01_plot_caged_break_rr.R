source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

if (!requireNamespace("ggplot2", quietly = TRUE)) {
  stop("Missing required package: ggplot2")
}

caged_path <- file.path(path_data_processed, "caged_state_balance_monthly_panel_ready.csv")

if (!file.exists(caged_path)) {
  stop("Input file not found: ", caged_path)
}

output_dir <- path_output_figures
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

caged <- readr::read_csv(caged_path, show_col_types = FALSE)

target_states <- c("RR", "SC", "MA", "SP")

plot_caged_break_for_state <- function(state_code) {
  state_caged <- caged |>
    dplyr::filter(state_abbrev == state_code) |>
    dplyr::mutate(
      period_date = as.Date(period_date),
      source_label = dplyr::case_when(
        source_regime == "old_caged" ~ "Old Caged consolidado",
        source_regime == "novo_caged" ~ "Novo Caged ajustado",
        TRUE ~ source_regime
      )
    ) |>
    dplyr::arrange(period_date)

  if (nrow(state_caged) == 0) {
    stop("No CAGED rows found for state: ", state_code)
  }

  state_name <- dplyr::first(state_caged$state_name)
  state_slug <- tolower(state_code)

  state_caged <- state_caged |>
    dplyr::mutate(
      formal_hiring_balance_ma12 = stats::filter(
        formal_hiring_balance,
        rep(1 / 12, 12),
        sides = 1
      ) |>
        as.numeric()
    )

  break_summary <- state_caged |>
    dplyr::mutate(
      window = dplyr::case_when(
        period_date >= as.Date("2018-01-01") & period_date <= as.Date("2019-12-01") ~ "Old Caged consolidado: 2018-01 a 2019-12",
        period_date >= as.Date("2020-01-01") & period_date <= as.Date("2021-12-01") ~ "Novo Caged ajustado: 2020-01 a 2021-12",
        period_date >= as.Date("2022-01-01") & period_date <= as.Date("2023-12-01") ~ "Novo Caged ajustado: 2022-01 a 2023-12",
        TRUE ~ NA_character_
      )
    ) |>
    dplyr::filter(!is.na(window)) |>
    dplyr::group_by(window) |>
    dplyr::summarise(
      months = dplyr::n(),
      mean_balance = mean(formal_hiring_balance, na.rm = TRUE),
      median_balance = stats::median(formal_hiring_balance, na.rm = TRUE),
      sd_balance = stats::sd(formal_hiring_balance, na.rm = TRUE),
      min_balance = min(formal_hiring_balance, na.rm = TRUE),
      max_balance = max(formal_hiring_balance, na.rm = TRUE),
      .groups = "drop"
    )

  summary_path <- file.path(output_dir, paste0(state_slug, "_caged_old_novo_break_summary.csv"))
  readr::write_csv(break_summary, summary_path, na = "")

  plot_data <- state_caged |>
    dplyr::filter(period_date >= as.Date("2016-01-01"))

  caged_plot <- ggplot2::ggplot(
    plot_data,
    ggplot2::aes(x = period_date, y = formal_hiring_balance)
  ) +
    ggplot2::geom_hline(yintercept = 0, color = "gray70", linewidth = 0.3) +
    ggplot2::geom_col(
      ggplot2::aes(fill = source_label),
      width = 25,
      alpha = 0.72
    ) +
    ggplot2::geom_line(
      ggplot2::aes(y = formal_hiring_balance_ma12),
      color = "#2f4b7c",
      linewidth = 0.8,
      na.rm = TRUE
    ) +
    ggplot2::geom_vline(
      xintercept = as.Date("2020-01-01"),
      linetype = "dashed",
      color = "#b23a48",
      linewidth = 0.6
    ) +
    ggplot2::annotate(
      "text",
      x = as.Date("2020-02-01"),
      y = max(plot_data$formal_hiring_balance, na.rm = TRUE),
      label = "Jan/2020: Novo Caged",
      hjust = 0,
      vjust = 1,
      size = 3.4,
      color = "#7a1f2b"
    ) +
    ggplot2::scale_fill_manual(
      values = c("Old Caged consolidado" = "#4f8a8b", "Novo Caged ajustado" = "#c77d3a")
    ) +
    ggplot2::scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
    ggplot2::labs(
      title = paste0(state_name, ": Old Caged consolidado vs Novo Caged ajustado"),
      subtitle = "Saldo mensal de emprego formal; linha azul mostra media movel de 12 meses",
      x = NULL,
      y = "Saldo mensal",
      fill = NULL,
      caption = "Fonte: MTE, Old CAGED oficial com patch Base dos Dados para meses corrompidos; Novo CAGED com MOV, FOR e EXC."
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      legend.position = "bottom",
      panel.grid.minor = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = "bold"),
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1)
    )

  plot_path <- file.path(output_dir, paste0(state_slug, "_caged_old_novo_break.png"))
  ggplot2::ggsave(
    filename = plot_path,
    plot = caged_plot,
    width = 10,
    height = 5.8,
    dpi = 300,
    bg = "white"
  )

  message("Saved plot: ", plot_path)
  message("Saved summary: ", summary_path)
}

invisible(lapply(target_states, plot_caged_break_for_state))
