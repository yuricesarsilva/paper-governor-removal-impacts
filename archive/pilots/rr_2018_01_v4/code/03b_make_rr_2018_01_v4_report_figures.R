source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

extra_packages <- c("ggplot2", "tidyr")
missing_extra <- extra_packages[!vapply(extra_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_extra) > 0) {
  stop("Missing required packages: ", paste(missing_extra, collapse = ", "))
}
invisible(lapply(extra_packages, library, character.only = TRUE))

pilot_id <- "rr_2018_01_v4"
treated_state <- "RR"

pilot_root <- file.path(root_dir, "pilots", pilot_id)
data_dir <- file.path(pilot_root, "data")
output_root <- file.path(pilot_root, "output")
figure_dir <- file.path(pilot_root, "report", "figures")
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

event <- readr::read_csv(
  file.path(data_dir, "rr_2018_01_v4_event_metadata.csv"),
  show_col_types = FALSE
) |>
  dplyr::slice(1) |>
  dplyr::mutate(
    instability_start_date = as.Date(.data$instability_start_date),
    removal_date = as.Date(.data$removal_date)
  )

covariates_raw <- readr::read_csv(
  file.path(data_dir, "rr_2018_01_v4_covariates.csv"),
  show_col_types = FALSE
)

main_donor_states <- covariates_raw |>
  dplyr::filter(.data$donor_pool_main) |>
  dplyr::pull(.data$state_abbrev) |>
  sort()

monthly_panel <- readr::read_csv(
  file.path(data_dir, "rr_2018_01_v4_monthly_panel.csv"),
  show_col_types = FALSE
) |>
  dplyr::mutate(period_date = as.Date(.data$period_date))

fiscal_panel <- readr::read_csv(
  file.path(data_dir, "rr_2018_01_v4_bimonthly_fiscal_panel.csv"),
  show_col_types = FALSE
) |>
  dplyr::mutate(period_date = as.Date(.data$period_date))

summary_tbl <- readr::read_csv(
  file.path(output_root, "rr_2018_01_v4_scm_summary.csv"),
  show_col_types = FALSE
)

make_slug <- function(x) {
  x |>
    stringr::str_replace_all("[^A-Za-z0-9]+", "_") |>
    stringr::str_replace_all("_+$", "") |>
    tolower()
}

base_theme <- function() {
  ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      legend.position = "bottom",
      plot.title.position = "plot",
      panel.grid.minor = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(size = 11)
    )
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

meta <- tibble::tribble(
  ~channel_slug, ~channel_label, ~family, ~panel_name, ~specification, ~outcome, ~plot_var, ~short_label,
  "labor_market", "Formal labor market", "monthly", "monthly", "raw", "formal_hiring_balance_per_100k_wap", "formal_hiring_balance_per_100k_wap", "Formal hiring",
  "labor_market", "Formal labor market", "monthly", "monthly", "raw", "formal_hiring_balance_construction_per_100k_wap", "formal_hiring_balance_construction_per_100k_wap", "Construction hiring",
  "labor_market", "Formal labor market", "monthly", "monthly", "ma6_v4", "formal_hiring_balance_per_100k_wap_ma6_v4", "formal_hiring_balance_per_100k_wap_ma6_v4", "Formal hiring, MA6",
  "labor_market", "Formal labor market", "monthly", "monthly", "ma6_v4", "formal_hiring_balance_construction_per_100k_wap_ma6_v4", "formal_hiring_balance_construction_per_100k_wap_ma6_v4", "Construction hiring, MA6",
  "consumption", "Household consumption", "monthly", "monthly", "raw", "retail_volume_index", "retail_volume_index", "Retail",
  "consumption", "Household consumption", "monthly", "monthly", "raw", "services_volume_index", "services_volume_index", "Services",
  "consumption", "Household consumption", "monthly", "monthly", "ma6_v4", "retail_volume_index_ma6_v4", "retail_volume_index_ma6_v4", "Retail, MA6",
  "consumption", "Household consumption", "monthly", "monthly", "ma6_v4", "services_volume_index_ma6_v4", "services_volume_index_ma6_v4", "Services, MA6",
  "public_sector", "State public finances", "bimonthly_fiscal", "fiscal", "raw", "state_tax_revenue_real_pc", "state_tax_revenue_real_pc", "Own tax revenue",
  "public_sector", "State public finances", "bimonthly_fiscal", "fiscal", "raw", "icms_revenue_real_pc", "icms_revenue_real_pc", "ICMS",
  "public_sector", "State public finances", "bimonthly_fiscal", "fiscal", "raw", "public_investment_liquidated_real_pc", "public_investment_liquidated_real_pc", "Public investment",
  "public_sector", "State public finances", "bimonthly_fiscal", "fiscal", "raw", "liquidated_expenditure_total_real_pc", "liquidated_expenditure_total_real_pc", "Total expenditure",
  "public_sector", "State public finances", "bimonthly_fiscal", "fiscal", "ma4_v4", "state_tax_revenue_real_pc_ma4_v4", "state_tax_revenue_real_pc_ma4_v4", "Own tax revenue, MA4",
  "public_sector", "State public finances", "bimonthly_fiscal", "fiscal", "ma4_v4", "icms_revenue_real_pc_ma4_v4", "icms_revenue_real_pc_ma4_v4", "ICMS, MA4",
  "public_sector", "State public finances", "bimonthly_fiscal", "fiscal", "ma4_v4", "public_investment_liquidated_real_pc_ma4_v4", "public_investment_liquidated_real_pc_ma4_v4", "Public investment, MA4",
  "public_sector", "State public finances", "bimonthly_fiscal", "fiscal", "ma4_v4", "liquidated_expenditure_total_real_pc_ma4_v4", "liquidated_expenditure_total_real_pc_ma4_v4", "Total expenditure, MA4"
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
          period_date = as.Date(.data$period_date),
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
        dplyr::mutate(short_label = row$short_label[[1]])
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
    ggplot2::annotate("rect", xmin = event$instability_start_date, xmax = event$removal_date, ymin = -Inf, ymax = Inf, fill = "gray85", alpha = 0.5) +
    ggplot2::geom_line(
      data = plot_data |> dplyr::filter(!.data$treated),
      ggplot2::aes(x = .data$period_date, y = .data$value, group = .data$state_abbrev),
      color = "gray70",
      alpha = 0.3,
      linewidth = 0.6
    ) +
    ggplot2::geom_line(data = donor_mean, ggplot2::aes(x = .data$period_date, y = .data$value, color = "Donor mean"), linewidth = 1) +
    ggplot2::geom_line(data = plot_data |> dplyr::filter(.data$treated), ggplot2::aes(x = .data$period_date, y = .data$value, color = "Roraima"), linewidth = 1.1) +
    ggplot2::geom_vline(xintercept = event$instability_start_date, linetype = "dotted", color = "gray25") +
    ggplot2::geom_vline(xintercept = event$removal_date, linetype = "dashed", color = "gray10") +
    ggplot2::scale_color_manual(values = c("Donor mean" = "#222222", "Roraima" = "#1f6f8b")) +
    ggplot2::facet_wrap(~short_label, scales = "free_y", ncol = 2) +
    ggplot2::labs(
      title = paste0("Preliminary view: ", unique(meta_rows$channel_label)),
      subtitle = if (specification_value == "raw") {
        "Gray lines are eligible donors; shaded area is the crisis window"
      } else {
        "V4 smoothing rule: full windows in pre-treatment, expanding windows after the break"
      },
      x = NULL, y = NULL, color = NULL
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
      series = dplyr::recode(.data$series, treated_value = "Roraima", augmented_synthetic_value = "Augmented synthetic")
    )

  ggplot2::ggplot(path_data, ggplot2::aes(x = .data$period_date, y = .data$value, color = .data$series)) +
    ggplot2::annotate("rect", xmin = event$instability_start_date, xmax = event$removal_date, ymin = -Inf, ymax = Inf, fill = "gray85", alpha = 0.5) +
    ggplot2::geom_line(linewidth = 1) +
    ggplot2::geom_vline(xintercept = event$instability_start_date, linetype = "dotted", color = "gray25") +
    ggplot2::geom_vline(xintercept = event$removal_date, linetype = "dashed", color = "gray10") +
    ggplot2::scale_color_manual(values = c("Roraima" = "#1f6f8b", "Augmented synthetic" = "#6a3d9a")) +
    ggplot2::facet_wrap(~short_label, scales = "free_y", ncol = 2) +
    ggplot2::labs(title = paste0("Augmented SCM paths: ", unique(meta_rows$channel_label)), x = NULL, y = NULL, color = NULL) +
    base_theme()
}

build_augmented_gaps_plot <- function(channel_slug_value, specification_value) {
  meta_rows <- meta |>
    dplyr::filter(.data$channel_slug == channel_slug_value, .data$specification == specification_value)

  gap_data <- load_paths(meta_rows)

  ggplot2::ggplot(gap_data, ggplot2::aes(x = .data$period_date, y = .data$augmented_gap)) +
    ggplot2::annotate("rect", xmin = event$instability_start_date, xmax = event$removal_date, ymin = -Inf, ymax = Inf, fill = "gray85", alpha = 0.5) +
    ggplot2::geom_hline(yintercept = 0, color = "gray60", linewidth = 0.4) +
    ggplot2::geom_line(color = "#6a3d9a", linewidth = 1) +
    ggplot2::geom_vline(xintercept = event$instability_start_date, linetype = "dotted", color = "gray25") +
    ggplot2::geom_vline(xintercept = event$removal_date, linetype = "dashed", color = "gray10") +
    ggplot2::facet_wrap(~short_label, scales = "free_y", ncol = 2) +
    ggplot2::labs(title = paste0("Augmented SCM gaps: ", unique(meta_rows$channel_label)), x = NULL, y = NULL) +
    base_theme()
}

build_weight_plot <- function(channel_slug_value, specification_value) {
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
    ggplot2::labs(title = paste0("Positive donor weights: ", unique(meta_rows$channel_label)), x = "Weight", y = NULL) +
    base_theme()
}

effect_plot_data <- summary_tbl |>
  dplyr::filter(.data$status == "estimated") |>
  dplyr::mutate(
    channel = dplyr::case_when(
      stringr::str_detect(.data$outcome, "formal_hiring|retail|services") & stringr::str_detect(.data$outcome, "ma") ~ dplyr::case_when(
        stringr::str_detect(.data$outcome, "formal_hiring") ~ "Formal labor market",
        TRUE ~ "Household consumption"
      ),
      stringr::str_detect(.data$outcome, "formal_hiring") ~ "Formal labor market",
      stringr::str_detect(.data$outcome, "retail|services") ~ "Household consumption",
      TRUE ~ "State public finances"
    )
  )

effect_summary_plot <- effect_plot_data |>
  dplyr::filter(stringr::str_detect(.data$specification, "ma")) |>
  dplyr::mutate(short_label = .data$outcome) |>
  ggplot2::ggplot(ggplot2::aes(x = .data$augmented_mean_gap_post, y = stats::reorder(.data$short_label, .data$augmented_mean_gap_post), color = .data$channel)) +
  ggplot2::geom_vline(xintercept = 0, color = "gray70", linewidth = 0.4) +
  ggplot2::geom_point(size = 3) +
  ggplot2::labs(title = "Post-treatment average gaps in preferred smoothed specifications", x = "Average post-treatment gap", y = NULL, color = NULL) +
  base_theme()

save_plot(build_preliminary_plot("labor_market", "raw"), "preliminary_labor_market_raw.png")
save_plot(build_preliminary_plot("labor_market", "ma6_v4"), "preliminary_labor_market_smooth.png")
save_plot(build_preliminary_plot("consumption", "raw"), "preliminary_consumption_raw.png")
save_plot(build_preliminary_plot("consumption", "ma6_v4"), "preliminary_consumption_smooth.png")
save_plot(build_preliminary_plot("public_sector", "raw"), "preliminary_public_sector_raw.png")
save_plot(build_preliminary_plot("public_sector", "ma4_v4"), "preliminary_public_sector_smooth.png")

save_plot(build_augmented_paths_plot("labor_market", "ma6_v4"), "augmented_paths_labor_market_smooth.png")
save_plot(build_augmented_paths_plot("consumption", "ma6_v4"), "augmented_paths_consumption_smooth.png")
save_plot(build_augmented_paths_plot("public_sector", "ma4_v4"), "augmented_paths_public_sector_smooth.png")

save_plot(build_augmented_gaps_plot("labor_market", "ma6_v4"), "augmented_gaps_labor_market_smooth.png")
save_plot(build_augmented_gaps_plot("consumption", "ma6_v4"), "augmented_gaps_consumption_smooth.png")
save_plot(build_augmented_gaps_plot("public_sector", "ma4_v4"), "augmented_gaps_public_sector_smooth.png")

save_plot(build_weight_plot("labor_market", "ma6_v4"), "donor_weights_labor_market_smooth.png")
save_plot(build_weight_plot("consumption", "ma6_v4"), "donor_weights_consumption_smooth.png")
save_plot(build_weight_plot("public_sector", "ma4_v4"), "donor_weights_public_sector_smooth.png")

save_plot(effect_summary_plot, "augmented_effect_summary.png", width = 10, height = 6)

message("RR 2018-01 V4 report figures regenerated.")
