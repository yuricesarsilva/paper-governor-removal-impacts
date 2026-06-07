# ── Event-study engine: report figures (arg: event_id) ────────────────────────
# Single combined 2-column panel per figure type, faceted over all qualifying
# outcomes (monthly + bimonthly together, calendar x-axis). Writes PNGs under
# output/<id>/report/figures/.
#
# Usage: Rscript code/02_analysis/03b_make_event_report_figures.R <EVENT_ID>

source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))
source(file.path("code", "02_analysis", "00_event_config.R"))
source(file.path("code", "02_analysis", "00b_engine_helpers.R"))

extra <- c("ggplot2", "tidyr", "ggh4x", "scales")
miss  <- extra[!vapply(extra, requireNamespace, logical(1), quietly = TRUE)]
if (length(miss)) stop("Missing packages: ", paste(miss, collapse = ", "))
invisible(lapply(extra, library, character.only = TRUE))

event_id <- resolve_event_id()
d <- event_dirs(event_id)
meta <- readr::read_csv(file.path(d$data, paste0(event_id, "_event_metadata.csv")), show_col_types = FALSE) |> dplyr::slice(1)
treated_state <- meta$state_abbrev[[1]]
treated_label <- meta$state_name[[1]]
removal_date  <- as.Date(meta$removal_date[[1]])

split_csv <- function(x) { x <- as.character(x); if (is.na(x) || !nzchar(x)) character(0) else strsplit(x, ",")[[1]] }
qual_monthly <- split_csv(meta$qualifying_monthly_outcomes[[1]])
qual_bim     <- split_csv(meta$qualifying_bimonthly_outcomes[[1]])

monthly_panel <- readr::read_csv(file.path(d$data, paste0(event_id, "_monthly_panel.csv")), show_col_types = FALSE) |>
  dplyr::mutate(period_date = as.Date(.data$period_date))
bim_path <- file.path(d$data, paste0(event_id, "_bimonthly_panel.csv"))
bimonthly_panel <- if (file.exists(bim_path)) readr::read_csv(bim_path, show_col_types = FALSE) |>
  dplyr::mutate(period_date = as.Date(.data$period_date)) else NULL
covariates_raw <- readr::read_csv(file.path(d$data, paste0(event_id, "_covariates.csv")), show_col_types = FALSE)
main_donor_states <- covariates_raw |> dplyr::filter(.data$donor_pool_main) |> dplyr::pull(.data$state_abbrev) |> sort()
summary_tbl <- readr::read_csv(file.path(d$scm, paste0(event_id, "_scm_summary.csv")), show_col_types = FALSE)

# Outcome table (catalog order), with family + panel.
otab <- tibble::tibble(
  outcome = c(qual_monthly, qual_bim),
  family  = c(rep("monthly", length(qual_monthly)), rep("bimonthly", length(qual_bim)))
) |>
  dplyr::mutate(short = vapply(.data$outcome, function(k) outcome_catalog[[k]]$short, character(1)),
                channel = vapply(.data$outcome, function(k) outcome_catalog[[k]]$channel, character(1)),
                transform = vapply(.data$outcome, function(k) {
                  tr <- outcome_catalog[[k]]$transform; if (is.null(tr)) "level" else tr }, character(1)))
order_keys <- intersect(names(outcome_catalog), otab$outcome)
otab <- otab |> dplyr::arrange(match(.data$outcome, order_keys))
short_levels <- otab$short
as_facet <- function(x) factor(x, levels = short_levels)
panel_for <- function(fam) if (fam == "monthly") monthly_panel else bimonthly_panel
tr_of <- function(sh) otab$transform[match(sh, otab$short)]

# Display back-transforms: log outcomes are modelled in logs but shown in levels
# (paths/preliminary) and as % deviations (gaps); level outcomes shown as-is.
# NB: transform is a scalar per outcome; use if (not ifelse, which would collapse
# a vectorised value to length 1 and flatten the series).
disp_level <- function(value, transform) if (identical(transform[[1]], "log")) exp(value) else value
disp_gap   <- function(gap, transform)   if (identical(transform[[1]], "log")) 100 * (exp(gap) - 1) else gap

placebo_dir <- file.path(d$scm, "placebo_inspace")
has_placebo <- file.exists(file.path(placebo_dir, "placebo_paths.csv"))
if (has_placebo) {
  placebo_paths   <- readr::read_csv(file.path(placebo_dir, "placebo_paths.csv"), show_col_types = FALSE) |>
    dplyr::mutate(period_date = as.Date(.data$period_date))
  placebo_summary <- readr::read_csv(file.path(placebo_dir, "placebo_summary.csv"), show_col_types = FALSE)
  placebo_rank    <- readr::read_csv(file.path(d$tables, "placebo_rank_actual_rr.csv"), show_col_types = FALSE)
}

base_theme <- function() ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(legend.position = "bottom", plot.title.position = "plot",
                 panel.grid.minor = ggplot2::element_blank(), strip.text = ggplot2::element_text(size = 11))
save_plot <- function(p, f, w = 12, h = 8) ggplot2::ggsave(file.path(d$figures, f), p, width = w, height = h, dpi = 300, bg = "white")
vline <- function() ggplot2::geom_vline(xintercept = as.numeric(removal_date), linetype = "dashed", color = "gray10")

load_paths <- function() purrr::map_dfr(seq_len(nrow(otab)), function(i) {
  r <- otab[i, ]
  f <- file.path(d$scm, r$family, "sa", paste0(make_slug(r$outcome), "_path.csv"))
  if (!file.exists(f)) return(NULL)
  readr::read_csv(f, show_col_types = FALSE) |>
    dplyr::mutate(period_date = as.Date(.data$period_date), short = r$short,
                  disp_treated = disp_level(.data$treated_value, r$transform),
                  disp_synth   = disp_level(.data$augmented_synthetic_value, r$transform),
                  disp_gap     = disp_gap(.data$augmented_gap, r$transform))
})

# ── Preliminary ───────────────────────────────────────────────────────────────
prelim_data <- purrr::map_dfr(seq_len(nrow(otab)), function(i) {
  r <- otab[i, ]; pn <- panel_for(r$family)
  pn |> dplyr::filter(.data$state_abbrev %in% c(treated_state, main_donor_states)) |>
    dplyr::transmute(.data$period_date, .data$state_abbrev,
                     value = disp_level(.data[[r$outcome]], r$transform),
                     short = r$short, treated = .data$state_abbrev == treated_state)
}) |> dplyr::mutate(short = as_facet(.data$short))

donor_mean <- prelim_data |> dplyr::filter(!.data$treated) |>
  dplyr::group_by(.data$period_date, .data$short) |>
  dplyr::summarise(value = mean(.data$value, na.rm = TRUE), .groups = "drop")
main_series <- dplyr::bind_rows(
  prelim_data |> dplyr::filter(.data$treated) |> dplyr::select("short", "value"),
  donor_mean |> dplyr::select("short", "value")) |> dplyr::filter(is.finite(.data$value))
y_ranges <- main_series |> dplyr::group_by(.data$short) |>
  dplyr::summarise(.ymin = min(.data$value), .ymax = max(.data$value), .groups = "drop") |>
  dplyr::mutate(.pad = (.data$.ymax - .data$.ymin) * 0.05, .ymin = .data$.ymin - .data$.pad, .ymax = .data$.ymax + .data$.pad) |>
  dplyr::arrange(.data$short)
y_scales <- lapply(seq_len(nrow(y_ranges)), function(i)
  ggplot2::scale_y_continuous(limits = c(y_ranges$.ymin[i], y_ranges$.ymax[i]), oob = scales::oob_keep))

prelim <- ggplot2::ggplot() +
  ggplot2::geom_line(data = prelim_data |> dplyr::filter(!.data$treated),
    ggplot2::aes(.data$period_date, .data$value, group = .data$state_abbrev), color = "gray75", alpha = 0.25, linewidth = 0.5) +
  ggplot2::geom_line(data = donor_mean, ggplot2::aes(.data$period_date, .data$value, color = "Donor mean"), linewidth = 1) +
  ggplot2::geom_line(data = prelim_data |> dplyr::filter(.data$treated),
    ggplot2::aes(.data$period_date, .data$value, color = treated_label), linewidth = 1.2) +
  vline() +
  ggplot2::scale_color_manual(values = stats::setNames(c("#222222", "#1f6f8b"), c("Donor mean", treated_label))) +
  ggplot2::scale_x_date(date_labels = "%Y") +
  ggplot2::facet_wrap(~short, scales = "free_y", ncol = 2) + ggh4x::facetted_pos_scales(y = y_scales) +
  ggplot2::labs(title = paste0("Preliminary view (SA): ", event_id),
                subtitle = paste0("Y-axis bounded by ", treated_label, " and the donor mean; donors in light gray. Dashed = removal."),
                x = NULL, y = NULL, color = NULL) + base_theme()
save_plot(prelim, "preliminary_outcomes.png")

# ── Paths + gaps ──────────────────────────────────────────────────────────────
paths <- load_paths()
if (!is.null(paths) && nrow(paths) > 0) {
  paths <- paths |> dplyr::mutate(short = as_facet(.data$short))
  pl <- paths |> tidyr::pivot_longer(c("disp_treated", "disp_synth"),
          names_to = "series", values_to = "value") |>
    dplyr::mutate(series = dplyr::recode(.data$series, disp_treated = treated_label, disp_synth = "Synthetic"))
  save_plot(ggplot2::ggplot(pl, ggplot2::aes(.data$period_date, .data$value, color = .data$series)) +
    ggplot2::geom_line(linewidth = 1.1) + vline() +
    ggplot2::scale_color_manual(values = stats::setNames(c("#1f6f8b", "#6a3d9a"), c(treated_label, "Synthetic"))) +
    ggplot2::scale_x_date(date_labels = "%Y") + ggplot2::facet_wrap(~short, scales = "free_y", ncol = 2) +
    ggplot2::labs(title = paste0("Augmented SCM paths (SA): ", event_id),
                  subtitle = "Levels (fiscal R$ pc, employment rate %, index); dashed = effective removal",
                  x = NULL, y = NULL, color = NULL) + base_theme(), "augmented_paths_outcomes.png")

  save_plot(ggplot2::ggplot(paths, ggplot2::aes(.data$period_date, .data$disp_gap)) +
    ggplot2::geom_hline(yintercept = 0, color = "gray60", linewidth = 0.4) +
    ggplot2::geom_line(color = "#6a3d9a", linewidth = 1.1) + vline() +
    ggplot2::scale_x_date(date_labels = "%Y") + ggplot2::facet_wrap(~short, scales = "free_y", ncol = 2) +
    ggplot2::labs(title = paste0("Augmented SCM gaps (SA): ", event_id),
                  subtitle = paste0("Gap = ", treated_label, " minus synthetic (fiscal in %, others in level units); dashed = removal"), x = NULL, y = NULL) +
    base_theme(), "augmented_gaps_outcomes.png")
}

# ── Donor weights (per-facet ordering via ___suffix) ──────────────────────────
weights <- purrr::map_dfr(seq_len(nrow(otab)), function(i) {
  r <- otab[i, ]; f <- file.path(d$scm, r$family, "sa", paste0(make_slug(r$outcome), "_weights.csv"))
  if (!file.exists(f)) return(NULL)
  readr::read_csv(f, show_col_types = FALSE) |> dplyr::mutate(short = r$short)
})
if (!is.null(weights) && nrow(weights) > 0) {
  wd <- weights |> dplyr::filter(.data$scm_weight > 0.001) |>
    dplyr::mutate(short = as_facet(.data$short)) |>
    dplyr::group_by(.data$short) |> dplyr::slice_max(.data$scm_weight, n = 6, with_ties = FALSE) |> dplyr::ungroup() |>
    dplyr::mutate(row_id = stats::reorder(paste(.data$donor_state, .data$short, sep = "___"), .data$scm_weight))
  save_plot(ggplot2::ggplot(wd, ggplot2::aes(.data$scm_weight, .data$row_id)) +
    ggplot2::geom_col(fill = "#7a52aa", alpha = 0.9) +
    ggplot2::scale_y_discrete(labels = function(x) sub("___.*$", "", x)) +
    ggplot2::facet_wrap(~short, scales = "free_y", ncol = 2) +
    ggplot2::scale_x_continuous(labels = function(x) paste0(round(100 * x), "%")) +
    ggplot2::labs(title = paste0("Donor weights (SA): ", event_id), x = "Weight", y = NULL) + base_theme(),
    "donor_weights_outcomes.png")
}

# ── Effect summary ────────────────────────────────────────────────────────────
es <- summary_tbl |> dplyr::filter(.data$status == "estimated") |>
  dplyr::mutate(short = vapply(.data$outcome, function(k) outcome_catalog[[k]]$short, character(1)),
                short = factor(.data$short, levels = rev(short_levels)))
save_plot(ggplot2::ggplot(es, ggplot2::aes(.data$augmented_mean_gap_post, .data$short)) +
  ggplot2::geom_vline(xintercept = 0, color = "gray70", linewidth = 0.4) +
  ggplot2::geom_point(size = 3, color = "#6a3d9a") +
  ggplot2::labs(title = paste0("Post-removal average gaps: ", event_id), x = "Mean post-removal gap", y = NULL) + base_theme(),
  "augmented_effect_summary.png", w = 10, h = 6)

# ── Placebo ───────────────────────────────────────────────────────────────────
if (has_placebo && nrow(placebo_paths) > 0) {
  rmspe_pre <- summary_tbl |> dplyr::filter(.data$status == "estimated") |>
    dplyr::select("outcome", rmspe_pre = "augmented_rmspe_pre")
  rr_paths <- load_paths() |>
    dplyr::left_join(rmspe_pre, by = "outcome") |>
    dplyr::mutate(short = as_facet(.data$short), normalized_gap = .data$augmented_gap / .data$rmspe_pre)
  pdat <- placebo_paths |>
    dplyr::left_join(placebo_summary |> dplyr::select("outcome", "pseudo_treated_state", "pre_rmspe"),
                     by = c("outcome", "pseudo_treated_state")) |>
    dplyr::mutate(short = vapply(.data$outcome, function(k) outcome_catalog[[k]]$short, character(1)),
                  short = as_facet(.data$short), normalized_gap = .data$augmented_gap / .data$pre_rmspe)
  save_plot(ggplot2::ggplot() +
    ggplot2::geom_hline(yintercept = 0, color = "gray65", linewidth = 0.4) +
    ggplot2::geom_line(data = pdat, ggplot2::aes(.data$period_date, .data$normalized_gap, group = .data$pseudo_treated_state),
      color = "gray70", alpha = 0.45, linewidth = 0.6) +
    ggplot2::geom_line(data = rr_paths, ggplot2::aes(.data$period_date, .data$normalized_gap, color = treated_label), linewidth = 1.1) +
    vline() + ggplot2::scale_color_manual(values = stats::setNames("#1f6f8b", treated_label)) +
    ggplot2::scale_x_date(date_labels = "%Y") + ggplot2::facet_wrap(~short, scales = "free_y", ncol = 2) +
    ggplot2::labs(title = paste0("In-space placebo: normalized gaps — ", event_id),
                  subtitle = paste0("Gray = placebos; blue = ", treated_label, "; normalized by pre-RMSPE"), x = NULL, y = NULL, color = NULL) +
    base_theme(), "placebo_gaps_outcomes.png")

  prk <- placebo_rank |> dplyr::mutate(short = factor(.data$short_label, levels = rev(short_levels)))
  save_plot(ggplot2::ggplot(prk, ggplot2::aes(.data$post_pre_rmspe_ratio, .data$short)) +
    ggplot2::geom_col(fill = "#7a52aa", alpha = 0.9) +
    ggplot2::labs(title = paste0("In-space placebo: RMSPE ratio (post/pre) — ", event_id), x = "Ratio", y = NULL) + base_theme(),
    "placebo_rmspe_ratio_outcomes.png", w = 10, h = 5)
}
message("=== figures ", event_id, " done ===")
