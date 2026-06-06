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

save_plot <- function(plot, filename, width = 12, height = 7) {
  ggplot2::ggsave(file.path(figure_dir, filename), plot = plot,
                  width = width, height = height, dpi = 300, bg = "white")
}

# Accountability frame: single treatment marker at the removal date.
vlines <- function() {
  list(ggplot2::geom_vline(xintercept = as.numeric(event$removal_date), linetype = "dashed", color = "gray10"))
}

# ── Outcome meta ──────────────────────────────────────────────────────────────
# V1: all outcomes monthly + X-13 (freq 12); one family; x-axis = calendar date.
# Two channels: state tax base (ICMS / tax-revenue value added) and consumption.
meta <- tibble::tribble(
  ~channel_slug, ~channel_label,                ~family,   ~specification, ~outcome,                                  ~short_label,
  "tax_base",    "State tax base (ICMS VA)",    "monthly", "sa", "va_icms_total_real_pc_sa",                "ICMS total VA",
  "tax_base",    "State tax base (ICMS VA)",    "monthly", "sa", "va_receita_tributaria_total_real_pc_sa",  "Tax revenue VA",
  "tax_base",    "State tax base (ICMS VA)",    "monthly", "sa", "va_icms_terciario_varejista_real_pc_sa",  "ICMS retail VA",
  "consumption", "Household consumption",       "monthly", "sa", "retail_volume_index_sa",                  "Retail volume"
)

channel_label_of <- function(slug) {
  dplyr::case_when(slug == "tax_base" ~ "State tax base (ICMS VA)",
                   slug == "consumption" ~ "Household consumption",
                   TRUE ~ slug)
}

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

# ── Preliminary plots ─────────────────────────────────────────────────────────
build_preliminary_plot <- function(channel_slug_value) {
  mr    <- meta |> dplyr::filter(.data$channel_slug == channel_slug_value)

  plot_data <- purrr::map_dfr(seq_len(nrow(mr)), function(i) {
    row <- mr[i,]
    monthly_panel |>
      dplyr::filter(.data$state_abbrev %in% c(treated_state, main_donor_states)) |>
      dplyr::transmute(
        period_date  = .data$period_date,
        state_abbrev = .data$state_abbrev,
        value        = .data[[row$outcome]],
        short_label  = row$short_label,
        treated      = .data$state_abbrev == treated_state
      )
  })

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

  x_lim <- plot_data |> dplyr::filter(is.finite(.data$value)) |>
    dplyr::pull(.data$period_date) |> range(na.rm = TRUE)

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
    ggplot2::coord_cartesian(xlim = x_lim) +
    ggplot2::facet_wrap(~short_label, scales = "free_y", ncol = 2) +
    ggh4x::facetted_pos_scales(y = y_scales) +
    ggplot2::labs(
      title    = paste0("Preliminary view (SA): ", unique(mr$channel_label)),
      subtitle = paste0("Y-axis bounded by ", treated_label, " and the donor mean (26 donor states in light gray); x-axis limited to the data window. Dashed line = removal."),
      x = NULL, y = NULL, color = NULL
    ) +
    base_theme()
}

# ── Augmented SCM paths ───────────────────────────────────────────────────────
build_augmented_paths_plot <- function(channel_slug_value) {
  mr        <- meta |> dplyr::filter(.data$channel_slug == channel_slug_value)
  path_data <- load_paths(mr)
  if (is.null(path_data) || nrow(path_data) == 0) return(NULL)

  path_long <- path_data |>
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
      title    = paste0("Augmented SCM paths (SA): ", unique(mr$channel_label)),
      subtitle = "Dashed line = effective removal (treatment)",
      x = NULL, y = NULL, color = NULL
    ) +
    base_theme()
}

# ── Augmented SCM gaps ────────────────────────────────────────────────────────
build_augmented_gaps_plot <- function(channel_slug_value) {
  mr       <- meta |> dplyr::filter(.data$channel_slug == channel_slug_value)
  gap_data <- load_paths(mr)
  if (is.null(gap_data) || nrow(gap_data) == 0) return(NULL)

  ggplot2::ggplot(gap_data, ggplot2::aes(x = .data$period_date, y = .data$augmented_gap)) +
    ggplot2::geom_hline(yintercept = 0, color = "gray60", linewidth = 0.4) +
    ggplot2::geom_line(color = "#6a3d9a", linewidth = 1.1) +
    vlines() +
    ggplot2::scale_x_date(date_labels = "%Y", date_breaks = "1 year") +
    ggplot2::facet_wrap(~short_label, scales = "free_y", ncol = 2) +
    ggplot2::labs(
      title    = paste0("Augmented SCM gaps (SA): ", unique(mr$channel_label)),
      subtitle = paste0("Gap = ", treated_label, " minus synthetic; dashed line = effective removal"),
      x = NULL, y = NULL
    ) +
    base_theme()
}

# ── Donor weights ─────────────────────────────────────────────────────────────
build_weight_plot <- function(channel_slug_value) {
  mr          <- meta |> dplyr::filter(.data$channel_slug == channel_slug_value)
  weight_data <- load_weights(mr)
  if (is.null(weight_data) || nrow(weight_data) == 0) return(NULL)

  weight_data <- weight_data |>
    dplyr::filter(.data$scm_weight > 0.001) |>
    dplyr::group_by(.data$short_label) |>
    dplyr::slice_max(.data$scm_weight, n = 6, with_ties = FALSE) |>
    dplyr::ungroup() |>
    dplyr::mutate(donor_state = stats::reorder(.data$donor_state, .data$scm_weight))

  ggplot2::ggplot(weight_data, ggplot2::aes(x = .data$scm_weight, y = .data$donor_state)) +
    ggplot2::geom_col(fill = "#7a52aa", alpha = 0.9) +
    ggplot2::facet_wrap(~short_label, scales = "free_y", ncol = 2) +
    ggplot2::scale_x_continuous(labels = function(x) paste0(round(100 * x), "%")) +
    ggplot2::labs(title = paste0("Donor weights (SA): ", unique(mr$channel_label)), x = "Weight", y = NULL) +
    base_theme()
}

# ── Effect summary ────────────────────────────────────────────────────────────
effect_summary_plot <- summary_tbl |>
  dplyr::filter(.data$status == "estimated") |>
  dplyr::left_join(meta |> dplyr::select("outcome", "short_label", "channel_slug", "channel_label"), by = "outcome") |>
  dplyr::filter(!is.na(.data$short_label)) |>
  dplyr::mutate(short_label = factor(.data$short_label, levels = rev(unique(.data$short_label)))) |>
  ggplot2::ggplot(ggplot2::aes(x = .data$augmented_mean_gap_post,
                                y = .data$short_label, color = .data$channel_label)) +
  ggplot2::geom_vline(xintercept = 0, color = "gray70", linewidth = 0.4) +
  ggplot2::geom_point(size = 3) +
  ggplot2::scale_color_manual(values = c(
    "State tax base (ICMS VA)" = "#6a3d9a",
    "Household consumption"    = "#c65a2e"
  )) +
  ggplot2::labs(title = "Post-removal average gaps (SA specification)", x = "Mean post-removal gap", y = NULL, color = NULL) +
  base_theme()

# ── Placebo plots ─────────────────────────────────────────────────────────────
build_placebo_gaps_plot <- function(channel_slug_value) {
  if (!has_placebo) return(NULL)

  preferred_lookup <- meta |>
    dplyr::filter(.data$channel_slug == channel_slug_value) |>
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
  })

  placebo_data <- placebo_paths |>
    dplyr::filter(.data$channel_slug == channel_slug_value) |>
    dplyr::left_join(placebo_summary |> dplyr::select("outcome", "pseudo_treated_state", "pre_rmspe"),
                     by = c("outcome", "pseudo_treated_state")) |>
    dplyr::mutate(normalized_gap = .data$augmented_gap / .data$pre_rmspe)

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
      title    = paste0("In-space placebo: normalized gaps — ", channel_label_of(channel_slug_value)),
      subtitle = paste0("Gray = placebos; blue = ", treated_label, "; gaps normalized by pre-treatment RMSPE"),
      x = NULL, y = NULL, color = NULL
    ) +
    base_theme()
}

build_placebo_ratio_plot <- function(channel_slug_value) {
  if (!has_placebo) return(NULL)
  plot_data <- placebo_rank |>
    dplyr::filter(.data$channel_slug == channel_slug_value) |>
    dplyr::mutate(short_label = factor(.data$short_label, levels = rev(unique(.data$short_label))))
  if (nrow(plot_data) == 0) return(NULL)

  ggplot2::ggplot(plot_data, ggplot2::aes(x = .data$post_pre_rmspe_ratio, y = .data$short_label)) +
    ggplot2::geom_col(fill = "#7a52aa", alpha = 0.9) +
    ggplot2::labs(title = paste0("RMSPE ratio (post/pre) — ", channel_label_of(channel_slug_value)), x = "Ratio", y = NULL) +
    base_theme()
}

# ── Save all figures ──────────────────────────────────────────────────────────
for (ch in c("tax_base", "consumption")) {
  save_plot(build_preliminary_plot(ch), paste0("preliminary_", ch, ".png"), width = 12, height = 7)
  p <- build_augmented_paths_plot(ch)
  if (!is.null(p)) save_plot(p, paste0("augmented_paths_", ch, ".png"), width = 12, height = 7)
  g <- build_augmented_gaps_plot(ch)
  if (!is.null(g)) save_plot(g, paste0("augmented_gaps_", ch, ".png"), width = 12, height = 7)
  w <- build_weight_plot(ch)
  if (!is.null(w)) save_plot(w, paste0("donor_weights_", ch, ".png"), width = 12, height = 7)
  if (has_placebo) {
    pg <- build_placebo_gaps_plot(ch)
    if (!is.null(pg)) save_plot(pg, paste0("placebo_gaps_", ch, ".png"), width = 12, height = 7)
    pr <- build_placebo_ratio_plot(ch)
    if (!is.null(pr)) save_plot(pr, paste0("placebo_rmspe_ratio_", ch, ".png"), width = 10, height = 4)
  }
}

save_plot(effect_summary_plot, "augmented_effect_summary.png", width = 10, height = 6)

message("PI 2001-01 V1 report figures generated.")
