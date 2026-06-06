source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))
extra_packages <- c("ggplot2", "tidyr", "ggh4x", "scales")
missing_extra  <- extra_packages[!vapply(extra_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_extra) > 0) stop("Missing: ", paste(missing_extra, collapse = ", "))
invisible(lapply(extra_packages, library, character.only = TRUE))

pilot_id      <- "pi_2001_01_v1"
treated_state <- "PI"
treated_label <- "Piaui"
pilot_root    <- file.path(root_dir, "pilots", pilot_id)
data_dir      <- file.path(pilot_root, "data")
output_root   <- file.path(pilot_root, "output")
figure_dir    <- file.path(pilot_root, "report", "figures")
table_dir     <- file.path(pilot_root, "report", "tables")
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

event <- readr::read_csv(file.path(data_dir, "pi_2001_01_v1_event_metadata.csv"), show_col_types = FALSE) |>
  dplyr::slice(1) |>
  dplyr::mutate(instability_start_date = as.Date(.data$instability_start_date),
                removal_date           = as.Date(.data$removal_date))

covariates_raw    <- readr::read_csv(file.path(data_dir, "pi_2001_01_v1_covariates.csv"),       show_col_types = FALSE)
monthly_panel     <- readr::read_csv(file.path(data_dir, "pi_2001_01_v1_monthly_panel.csv"),    show_col_types = FALSE) |> dplyr::mutate(period_date = as.Date(.data$period_date))
summary_tbl       <- readr::read_csv(file.path(output_root, "pi_2001_01_v1_scm_summary.csv"),    show_col_types = FALSE)
main_donor_states <- covariates_raw |> dplyr::filter(.data$donor_pool_main) |> dplyr::pull(.data$state_abbrev) |> sort()

placebo_dir <- file.path(output_root, "placebo_inspace")
has_placebo <- file.exists(file.path(placebo_dir, "placebo_paths_preferred_smooth.csv"))

if (has_placebo) {
  placebo_paths   <- readr::read_csv(file.path(placebo_dir, "placebo_paths_preferred_smooth.csv"),   show_col_types = FALSE) |> dplyr::mutate(period_date = as.Date(.data$period_date))
  placebo_summary <- readr::read_csv(file.path(placebo_dir, "placebo_summary_preferred_smooth.csv"), show_col_types = FALSE)
  placebo_rank    <- readr::read_csv(file.path(table_dir,   "placebo_rank_actual_rr.csv"),           show_col_types = FALSE)
}

make_slug <- function(x) { x |> stringr::str_replace_all("[^A-Za-z0-9]+","_") |> stringr::str_replace_all("_+$","") |> tolower() }

base_theme <- function() {
  ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(legend.position = "bottom", plot.title.position = "plot",
                   panel.grid.minor = ggplot2::element_blank(),
                   strip.text = ggplot2::element_text(size = 11))
}

save_plot <- function(plot, filename, width = 12, height = 8) {
  ggplot2::ggsave(file.path(figure_dir, filename), plot = plot,
                  width = width, height = height, dpi = 300, bg = "white")
}

# Accountability frame: single treatment marker at the removal date.
vlines <- function() {
  list(ggplot2::geom_vline(xintercept = as.numeric(event$removal_date), linetype = "dashed", color = "gray10"))
}

# ── Outcome meta ──────────────────────────────────────────────────────────────
# V1: all 4 outcomes are monthly + X-13 (freq 12) and shown together in ONE
# 2x2 panel (no channel split). Facet order is fixed below.
meta <- tibble::tribble(
  ~family,   ~specification, ~outcome,                                  ~short_label,
  "monthly", "sa", "va_icms_total_real_pc_sa",                "ICMS total VA",
  "monthly", "sa", "va_receita_tributaria_total_real_pc_sa",  "Tax revenue VA",
  "monthly", "sa", "va_icms_terciario_varejista_real_pc_sa",  "ICMS retail VA",
  "monthly", "sa", "retail_volume_index_sa",                  "Retail volume"
)
outcome_order <- meta$short_label  # ICMS total, Tax revenue, ICMS retail, Retail
as_facet <- function(x) factor(x, levels = outcome_order)

load_paths <- function(meta_rows) {
  purrr::map_dfr(seq_len(nrow(meta_rows)), function(i) {
    row <- meta_rows[i,]
    f   <- file.path(output_root, row$family, row$specification, paste0(make_slug(row$outcome), "_path.csv"))
    if (!file.exists(f)) return(NULL)
    readr::read_csv(f, show_col_types = FALSE) |>
      dplyr::mutate(period_date = as.Date(.data$period_date), short_label = row$short_label)
  })
}

load_weights <- function(meta_rows) {
  purrr::map_dfr(seq_len(nrow(meta_rows)), function(i) {
    row <- meta_rows[i,]
    f   <- file.path(output_root, row$family, row$specification, paste0(make_slug(row$outcome), "_weights.csv"))
    if (!file.exists(f)) return(NULL)
    readr::read_csv(f, show_col_types = FALSE) |> dplyr::mutate(short_label = row$short_label)
  })
}

# ── Preliminary plot (all 4 outcomes) ─────────────────────────────────────────
build_preliminary_plot <- function() {
  plot_data <- purrr::map_dfr(seq_len(nrow(meta)), function(i) {
    row <- meta[i,]
    monthly_panel |>
      dplyr::filter(.data$state_abbrev %in% c(treated_state, main_donor_states)) |>
      dplyr::transmute(
        period_date  = .data$period_date,
        state_abbrev = .data$state_abbrev,
        value        = .data[[row$outcome]],
        short_label  = row$short_label,
        treated      = .data$state_abbrev == treated_state
      )
  }) |> dplyr::mutate(short_label = as_facet(.data$short_label))

  donor_mean <- plot_data |> dplyr::filter(!.data$treated) |>
    dplyr::group_by(.data$period_date, .data$short_label) |>
    dplyr::summarise(value = mean(.data$value, na.rm = TRUE), .groups = "drop")

  # Per-facet y-range from the TWO MAIN series only (treated + donor mean).
  main_series <- dplyr::bind_rows(
    plot_data |> dplyr::filter(.data$treated) |> dplyr::select("short_label", "value"),
    donor_mean |> dplyr::select("short_label", "value")
  ) |> dplyr::filter(is.finite(.data$value))

  y_ranges <- main_series |>
    dplyr::group_by(.data$short_label) |>
    dplyr::summarise(.ymin = min(.data$value), .ymax = max(.data$value), .groups = "drop") |>
    dplyr::mutate(.pad = (.data$.ymax - .data$.ymin) * 0.05,
                  .ymin = .data$.ymin - .data$.pad, .ymax = .data$.ymax + .data$.pad) |>
    dplyr::arrange(.data$short_label)

  y_scales <- lapply(seq_len(nrow(y_ranges)), function(i) {
    ggplot2::scale_y_continuous(limits = c(y_ranges$.ymin[i], y_ranges$.ymax[i]),
                                oob = scales::oob_keep)
  })

  ggplot2::ggplot() +
    ggplot2::geom_line(data = plot_data |> dplyr::filter(!.data$treated),
      ggplot2::aes(x = .data$period_date, y = .data$value, group = .data$state_abbrev),
      color = "gray75", alpha = 0.25, linewidth = 0.5) +
    ggplot2::geom_line(data = donor_mean,
      ggplot2::aes(x = .data$period_date, y = .data$value, color = "Donor mean"), linewidth = 1) +
    ggplot2::geom_line(data = plot_data |> dplyr::filter(.data$treated),
      ggplot2::aes(x = .data$period_date, y = .data$value, color = treated_label), linewidth = 1.2) +
    vlines() +
    ggplot2::scale_color_manual(values = stats::setNames(c("#222222", "#1f6f8b"), c("Donor mean", treated_label))) +
    ggplot2::scale_x_date(date_labels = "%Y", date_breaks = "1 year") +
    ggplot2::facet_wrap(~short_label, scales = "free_y", ncol = 2) +
    ggh4x::facetted_pos_scales(y = y_scales) +
    ggplot2::labs(
      title    = "Preliminary view (SA): PI 2001 outcomes",
      subtitle = paste0("Y-axis bounded by ", treated_label, " and the donor mean (26 donor states in light gray). Dashed line = removal."),
      x = NULL, y = NULL, color = NULL
    ) +
    base_theme()
}

# ── Augmented SCM paths (all 4 outcomes) ──────────────────────────────────────
build_augmented_paths_plot <- function() {
  path_data <- load_paths(meta)
  if (is.null(path_data) || nrow(path_data) == 0) return(NULL)

  path_long <- path_data |>
    dplyr::mutate(short_label = as_facet(.data$short_label)) |>
    tidyr::pivot_longer(c("treated_value", "augmented_synthetic_value"),
                        names_to = "series", values_to = "value") |>
    dplyr::mutate(series = dplyr::recode(.data$series,
      treated_value = treated_label, augmented_synthetic_value = "Synthetic"))

  ggplot2::ggplot(path_long, ggplot2::aes(x = .data$period_date, y = .data$value, color = .data$series)) +
    ggplot2::geom_line(linewidth = 1.1) +
    vlines() +
    ggplot2::scale_color_manual(values = stats::setNames(c("#1f6f8b", "#6a3d9a"), c(treated_label, "Synthetic"))) +
    ggplot2::scale_x_date(date_labels = "%Y", date_breaks = "1 year") +
    ggplot2::facet_wrap(~short_label, scales = "free_y", ncol = 2) +
    ggplot2::labs(
      title    = "Augmented SCM paths (SA): PI 2001 outcomes",
      subtitle = "Dashed line = effective removal (treatment)",
      x = NULL, y = NULL, color = NULL
    ) +
    base_theme()
}

# ── Augmented SCM gaps (all 4 outcomes) ───────────────────────────────────────
build_augmented_gaps_plot <- function() {
  gap_data <- load_paths(meta)
  if (is.null(gap_data) || nrow(gap_data) == 0) return(NULL)
  gap_data <- gap_data |> dplyr::mutate(short_label = as_facet(.data$short_label))

  ggplot2::ggplot(gap_data, ggplot2::aes(x = .data$period_date, y = .data$augmented_gap)) +
    ggplot2::geom_hline(yintercept = 0, color = "gray60", linewidth = 0.4) +
    ggplot2::geom_line(color = "#6a3d9a", linewidth = 1.1) +
    vlines() +
    ggplot2::scale_x_date(date_labels = "%Y", date_breaks = "1 year") +
    ggplot2::facet_wrap(~short_label, scales = "free_y", ncol = 2) +
    ggplot2::labs(
      title    = "Augmented SCM gaps (SA): PI 2001 outcomes",
      subtitle = paste0("Gap = ", treated_label, " minus synthetic; dashed line = effective removal"),
      x = NULL, y = NULL
    ) +
    base_theme()
}

# ── Donor weights (all 4 outcomes) ────────────────────────────────────────────
build_weight_plot <- function() {
  weight_data <- load_weights(meta)
  if (is.null(weight_data) || nrow(weight_data) == 0) return(NULL)

  weight_data <- weight_data |>
    dplyr::filter(.data$scm_weight > 0.001) |>
    dplyr::mutate(short_label = as_facet(.data$short_label)) |>
    dplyr::group_by(.data$short_label) |>
    dplyr::slice_max(.data$scm_weight, n = 6, with_ties = FALSE) |>
    dplyr::ungroup() |>
    dplyr::mutate(donor_state = tidytext_reorder(.data$donor_state, .data$scm_weight, .data$short_label))

  ggplot2::ggplot(weight_data, ggplot2::aes(x = .data$scm_weight, y = .data$donor_state)) +
    ggplot2::geom_col(fill = "#7a52aa", alpha = 0.9) +
    ggplot2::facet_wrap(~short_label, scales = "free_y", ncol = 2) +
    ggplot2::scale_x_continuous(labels = function(x) paste0(round(100 * x), "%")) +
    ggplot2::labs(title = "Donor weights (SA): PI 2001 outcomes", x = "Weight", y = NULL) +
    base_theme()
}

# Reorder donor_state within each facet (so bars sort by weight per panel).
tidytext_reorder <- function(x, by, within) {
  new_x <- paste(x, within, sep = "___")
  stats::reorder(new_x, by)
}
strip_reorder <- function(x) sub("___.*$", "", as.character(x))

# ── Effect summary (all 4 outcomes) ───────────────────────────────────────────
effect_summary_plot <- summary_tbl |>
  dplyr::filter(.data$status == "estimated") |>
  dplyr::left_join(meta |> dplyr::select("outcome", "short_label"), by = "outcome") |>
  dplyr::filter(!is.na(.data$short_label)) |>
  dplyr::mutate(short_label = factor(.data$short_label, levels = rev(outcome_order))) |>
  ggplot2::ggplot(ggplot2::aes(x = .data$augmented_mean_gap_post, y = .data$short_label)) +
  ggplot2::geom_vline(xintercept = 0, color = "gray70", linewidth = 0.4) +
  ggplot2::geom_point(size = 3, color = "#6a3d9a") +
  ggplot2::labs(title = "Post-removal average gaps (SA specification)", x = "Mean post-removal gap", y = NULL) +
  base_theme()

# ── In-space placebo gaps (all 4 outcomes) ────────────────────────────────────
build_placebo_gaps_plot <- function() {
  if (!has_placebo) return(NULL)

  preferred_lookup <- meta |>
    dplyr::select("outcome", "short_label") |>
    dplyr::inner_join(
      summary_tbl |> dplyr::filter(.data$status == "estimated") |>
        dplyr::select("outcome", rmspe_pre = "augmented_rmspe_pre"),
      by = "outcome"
    )
  if (nrow(preferred_lookup) == 0) return(NULL)

  rr_paths <- purrr::map_dfr(seq_len(nrow(preferred_lookup)), function(i) {
    row <- preferred_lookup[i,]
    f   <- file.path(output_root, "monthly", "sa", paste0(make_slug(row$outcome), "_path.csv"))
    if (!file.exists(f)) return(NULL)
    readr::read_csv(f, show_col_types = FALSE) |>
      dplyr::mutate(period_date = as.Date(.data$period_date),
                    short_label = row$short_label,
                    normalized_gap = .data$augmented_gap / row$rmspe_pre) |>
      dplyr::select("period_date", "short_label", "normalized_gap")
  }) |> dplyr::mutate(short_label = as_facet(.data$short_label))

  placebo_data <- placebo_paths |>
    dplyr::left_join(placebo_summary |> dplyr::select("outcome", "pseudo_treated_state", "pre_rmspe"),
                     by = c("outcome", "pseudo_treated_state")) |>
    dplyr::mutate(normalized_gap = .data$augmented_gap / .data$pre_rmspe,
                  short_label = as_facet(.data$short_label))

  ggplot2::ggplot() +
    ggplot2::geom_hline(yintercept = 0, color = "gray65", linewidth = 0.4) +
    ggplot2::geom_line(data = placebo_data,
      ggplot2::aes(x = .data$period_date, y = .data$normalized_gap, group = .data$pseudo_treated_state),
      color = "gray70", alpha = 0.45, linewidth = 0.6) +
    ggplot2::geom_line(data = rr_paths,
      ggplot2::aes(x = .data$period_date, y = .data$normalized_gap, color = treated_label), linewidth = 1.1) +
    vlines() +
    ggplot2::scale_color_manual(values = stats::setNames("#1f6f8b", treated_label)) +
    ggplot2::scale_x_date(date_labels = "%Y", date_breaks = "1 year") +
    ggplot2::facet_wrap(~short_label, scales = "free_y", ncol = 2) +
    ggplot2::labs(
      title    = "In-space placebo: normalized gaps — PI 2001 outcomes",
      subtitle = paste0("Gray = placebos; blue = ", treated_label, "; gaps normalized by pre-treatment RMSPE"),
      x = NULL, y = NULL, color = NULL
    ) +
    base_theme()
}

# ── In-space placebo RMSPE ratio (all 4 outcomes) ─────────────────────────────
build_placebo_ratio_plot <- function() {
  if (!has_placebo) return(NULL)
  plot_data <- placebo_rank |>
    dplyr::mutate(short_label = factor(.data$short_label, levels = rev(outcome_order)))
  if (nrow(plot_data) == 0) return(NULL)

  ggplot2::ggplot(plot_data, ggplot2::aes(x = .data$post_pre_rmspe_ratio, y = .data$short_label)) +
    ggplot2::geom_col(fill = "#7a52aa", alpha = 0.9) +
    ggplot2::labs(title = "In-space placebo: RMSPE ratio (post/pre) — PI 2001 outcomes",
                  x = "Ratio", y = NULL) +
    base_theme()
}

# ── Save all figures (single combined panel each) ─────────────────────────────
save_plot(build_preliminary_plot(),     "preliminary_outcomes.png",        width = 12, height = 8)
p <- build_augmented_paths_plot(); if (!is.null(p)) save_plot(p, "augmented_paths_outcomes.png", width = 12, height = 8)
g <- build_augmented_gaps_plot();  if (!is.null(g)) save_plot(g, "augmented_gaps_outcomes.png",  width = 12, height = 8)

# Donor-weights facet needs per-facet y relabeling (strip the ___facet suffix).
w <- build_weight_plot()
if (!is.null(w)) {
  w <- w + ggplot2::scale_y_discrete(labels = strip_reorder)
  save_plot(w, "donor_weights_outcomes.png", width = 12, height = 8)
}

save_plot(effect_summary_plot, "augmented_effect_summary.png", width = 10, height = 6)

if (has_placebo) {
  pg <- build_placebo_gaps_plot();  if (!is.null(pg)) save_plot(pg, "placebo_gaps_outcomes.png",       width = 12, height = 8)
  pr <- build_placebo_ratio_plot(); if (!is.null(pr)) save_plot(pr, "placebo_rmspe_ratio_outcomes.png", width = 10, height = 5)
}

# Remove superseded per-channel figures so the report has a single source.
old_figs <- c("preliminary_tax_base.png", "preliminary_consumption.png",
              "augmented_paths_tax_base.png", "augmented_paths_consumption.png",
              "augmented_gaps_tax_base.png", "augmented_gaps_consumption.png",
              "donor_weights_tax_base.png", "donor_weights_consumption.png",
              "placebo_gaps_tax_base.png", "placebo_gaps_consumption.png",
              "placebo_rmspe_ratio_tax_base.png", "placebo_rmspe_ratio_consumption.png")
invisible(file.remove(file.path(figure_dir, old_figs[file.exists(file.path(figure_dir, old_figs))])))

message("PI 2001-01 V1 report figures generated (single 4-outcome panels).")
