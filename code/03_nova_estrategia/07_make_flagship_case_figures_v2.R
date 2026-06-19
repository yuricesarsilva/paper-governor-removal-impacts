# ── Nova Estrategia v2 engine: flagship case-study figures ───────────────────
# 5 "paper-style" figures for each of the 3 flagship cases (main: PI_2001_01;
# extended: AL_2022_01; borderline: RR_2018_01), faceted by outcome:
#   1. paths   -- treated vs. augmented synthetic
#   2. gaps    -- treated-minus-synthetic over time
#   3. scm_vs_augscm -- treated, plain-SCM synthetic, AugSCM synthetic together
#   4. placebo_spaghetti -- in-space placebo gap paths (donors gray, treated highlighted)
#   5. placebo_rank -- sorted post/pre RMSPE ratio across treated+donors, treated
#      highlighted and labeled with its rank (literature recommends leading with
#      the rank, not the p-value, when the donor pool is small)
# Requires 02b_run_event_placebo_inspace_v2.R to have been run for these events.
#
# Usage: Rscript code/03_nova_estrategia/07_make_flagship_case_figures_v2.R

source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))
source(file.path("code", "03_nova_estrategia", "00_nova_estrategia_config.R"))

extra_packages <- c("ggplot2", "tidyr")
missing_extra <- extra_packages[!vapply(extra_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_extra) > 0) stop("Missing packages: ", paste(missing_extra, collapse = ", "))
invisible(lapply(extra_packages, library, character.only = TRUE))

flagship_events <- c("PI_2001_01", "AL_2022_01", "RR_2018_01")
summary_dir <- summary_root_v2()
fig_dir <- file.path(summary_dir, "figures")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

base_theme <- function() {
  ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(legend.position = "bottom", panel.grid.minor = ggplot2::element_blank(),
                   plot.title.position = "plot")
}

for (eid in flagship_events) {
  event_spec <- get_event_spec(eid)
  include_fh <- event_spec$include_formal_hiring[[1]]
  outcome_cols <- get_outcome_list(include_fh)
  d <- event_dirs_v2(eid)

  meta <- readr::read_csv(file.path(d$data, paste0(eid, "_event_metadata.csv")), show_col_types = FALSE) |>
    dplyr::slice(1)
  removal_dt    <- as.Date(meta$removal_date[[1]])
  treated_label <- meta$state_name[[1]]

  om <- outcome_catalog_v2 |> dplyr::filter(.data$outcome %in% outcome_cols) |>
    dplyr::arrange(match(.data$outcome, outcome_cols))

  # ── Load per-outcome data ───────────────────────────────────────────────
  paths <- purrr::map_dfr(om$outcome, function(o) {
    slug <- make_slug(o)
    f <- file.path(d$monthly, paste0(slug, "_path.csv"))
    if (!file.exists(f)) return(NULL)
    lbl <- om$short[om$outcome == o][[1]]
    readr::read_csv(f, show_col_types = FALSE) |>
      dplyr::mutate(period_date = as.Date(.data$period_date), short = lbl)
  })

  placebo_paths <- purrr::map_dfr(om$outcome, function(o) {
    slug <- make_slug(o)
    f <- file.path(d$output, "placebo_inspace", paste0(slug, "_inspace_paths.csv"))
    if (!file.exists(f)) return(NULL)
    lbl <- om$short[om$outcome == o][[1]]
    readr::read_csv(f, show_col_types = FALSE) |>
      dplyr::mutate(period_date = as.Date(.data$period_date), short = lbl)
  })

  rank_tab <- file.path(d$tables, "placebo_rank_inspace.csv")
  rank_tab <- if (file.exists(rank_tab)) readr::read_csv(rank_tab, show_col_types = FALSE) else NULL

  placebo_summary <- purrr::map_dfr(om$outcome, function(o) {
    slug <- make_slug(o)
    f <- file.path(d$output, "placebo_inspace", paste0(slug, "_inspace_summary.csv"))
    if (!file.exists(f)) return(NULL)
    lbl <- om$short[om$outcome == o][[1]]
    readr::read_csv(f, show_col_types = FALSE) |> dplyr::mutate(short = lbl)
  })

  if (nrow(paths) == 0) { message(eid, ": sem paths, pulando."); next }
  paths$short <- factor(paths$short, levels = om$short)

  # ── 1. Paths: treated vs. augmented synthetic ───────────────────────────
  p1 <- paths |>
    tidyr::pivot_longer(cols = c("treated_value", "augmented_synthetic_value"),
                         names_to = "series", values_to = "value") |>
    dplyr::mutate(series = dplyr::recode(.data$series,
      treated_value = treated_label, augmented_synthetic_value = "Sintetico (AugSCM)")) |>
    (\(dd) ggplot2::ggplot(dd, ggplot2::aes(.data$period_date, .data$value, color = .data$series)) +
      ggplot2::geom_line(linewidth = 1) +
      ggplot2::geom_vline(xintercept = removal_dt, linetype = "dashed", color = "gray20") +
      ggplot2::scale_color_manual(values = setNames(c("#1f6f8b", "#6a3d9a"), c(treated_label, "Sintetico (AugSCM)"))) +
      ggplot2::facet_wrap(~short, scales = "free_y", ncol = 1) +
      ggplot2::labs(title = paste0(eid, " (", treated_label, ") — trajetoria real vs. sintetico"),
                    subtitle = "Tracejado = data da remocao", x = NULL, y = NULL, color = NULL) +
      base_theme()
    )()
  ggplot2::ggsave(file.path(fig_dir, paste0("flagship_", eid, "_paths.png")), p1,
                  width = 9, height = 3 * nrow(om), dpi = 300, bg = "white", limitsize = FALSE)

  # ── 2. Gaps ──────────────────────────────────────────────────────────────
  p2 <- ggplot2::ggplot(paths |> dplyr::filter(is.finite(.data$augmented_gap)),
                        ggplot2::aes(.data$period_date, .data$augmented_gap)) +
    ggplot2::geom_hline(yintercept = 0, color = "gray60", linewidth = 0.4) +
    ggplot2::geom_line(color = "#6a3d9a", linewidth = 1) +
    ggplot2::geom_vline(xintercept = removal_dt, linetype = "dashed", color = "gray20") +
    ggplot2::facet_wrap(~short, scales = "free_y", ncol = 1) +
    ggplot2::labs(title = paste0(eid, " (", treated_label, ") — gap tratado-sintetico"),
                  subtitle = "Tracejado = data da remocao", x = NULL, y = "Gap") +
    base_theme()
  ggplot2::ggsave(file.path(fig_dir, paste0("flagship_", eid, "_gaps.png")), p2,
                  width = 9, height = 3 * nrow(om), dpi = 300, bg = "white", limitsize = FALSE)

  # ── 3. SCM puro vs. AugSCM ───────────────────────────────────────────────
  p3 <- paths |>
    tidyr::pivot_longer(cols = c("treated_value", "scm_synthetic_value", "augmented_synthetic_value"),
                         names_to = "series", values_to = "value") |>
    dplyr::mutate(series = dplyr::recode(.data$series,
      treated_value = treated_label,
      scm_synthetic_value = "Sintetico (SCM puro)",
      augmented_synthetic_value = "Sintetico (AugSCM)")) |>
    (\(dd) ggplot2::ggplot(dd, ggplot2::aes(.data$period_date, .data$value, color = .data$series)) +
      ggplot2::geom_line(linewidth = 1) +
      ggplot2::geom_vline(xintercept = removal_dt, linetype = "dashed", color = "gray20") +
      ggplot2::scale_color_manual(values = setNames(c("#1f6f8b", "#e08214", "#6a3d9a"),
                                                     c(treated_label, "Sintetico (SCM puro)", "Sintetico (AugSCM)"))) +
      ggplot2::facet_wrap(~short, scales = "free_y", ncol = 1) +
      ggplot2::labs(title = paste0(eid, " (", treated_label, ") — SCM puro vs. AugSCM"),
                    subtitle = "Tracejado = data da remocao", x = NULL, y = NULL, color = NULL) +
      base_theme()
    )()
  ggplot2::ggsave(file.path(fig_dir, paste0("flagship_", eid, "_scm_vs_augscm.png")), p3,
                  width = 9, height = 3 * nrow(om), dpi = 300, bg = "white", limitsize = FALSE)

  # ── 4. Placebo spaghetti (in-space) ──────────────────────────────────────
  if (nrow(placebo_paths) > 0) {
    placebo_paths$short <- factor(placebo_paths$short, levels = om$short)
    p4 <- ggplot2::ggplot() +
      ggplot2::geom_hline(yintercept = 0, color = "gray60", linewidth = 0.4) +
      ggplot2::geom_vline(xintercept = 0, linetype = "dashed", color = "gray20") +
      ggplot2::geom_line(data = placebo_paths |> dplyr::filter(is.finite(.data$augmented_gap)),
                         ggplot2::aes(.data$event_time, .data$augmented_gap, group = .data$pseudo_treated_state),
                         color = "gray70", alpha = 0.6, linewidth = 0.4) +
      ggplot2::geom_line(data = paths |> dplyr::filter(is.finite(.data$augmented_gap)),
                         ggplot2::aes(.data$event_time, .data$augmented_gap),
                         color = "#6a3d9a", linewidth = 1.2) +
      ggplot2::facet_wrap(~short, scales = "free_y", ncol = 1) +
      ggplot2::labs(title = paste0(eid, " (", treated_label, ") — placebo in-space"),
                    subtitle = "Cinza = doadores no lugar do tratado (pseudo-tratados); roxo = tratado real; tracejado = remocao (event_time=0)",
                    x = "Meses relativos a remocao", y = "Gap") +
      base_theme()
    ggplot2::ggsave(file.path(fig_dir, paste0("flagship_", eid, "_placebo_spaghetti.png")), p4,
                    width = 9, height = 3 * nrow(om), dpi = 300, bg = "white", limitsize = FALSE)
  } else {
    message(eid, ": sem dados de placebo in-space (rode 02b_run_event_placebo_inspace_v2.R).")
  }

  # ── 5. Placebo rank (sorted post/pre RMSPE ratio, treated highlighted) ──
  if (nrow(placebo_summary) > 0 && !is.null(rank_tab)) {
    rank_plot_data <- purrr::map_dfr(om$outcome, function(o) {
      lbl <- om$short[om$outcome == o][[1]]
      ps  <- placebo_summary |> dplyr::filter(.data$short == lbl) |>
        dplyr::transmute(unit = .data$pseudo_treated_state, ratio = .data$post_pre_ratio, is_treated = FALSE)
      rr  <- rank_tab |> dplyr::filter(.data$outcome == o)
      if (nrow(rr) == 0) return(ps |> dplyr::mutate(short = lbl))
      tr <- tibble::tibble(unit = treated_label, ratio = rr$treated_ratio[[1]], is_treated = TRUE)
      dplyr::bind_rows(ps, tr) |> dplyr::mutate(short = lbl)
    })
    rank_plot_data <- rank_plot_data |> dplyr::filter(is.finite(.data$ratio)) |>
      dplyr::group_by(.data$short) |>
      dplyr::mutate(unit_f = stats::reorder(.data$unit, .data$ratio)) |>
      dplyr::ungroup() |>
      dplyr::mutate(short = factor(.data$short, levels = om$short))

    rank_labels <- rank_tab |> dplyr::mutate(
      lbl_txt = paste0("rank ", .data$rank, "/", .data$n_units, " (p=", round(.data$classic_p, 3), ")"))

    p5 <- ggplot2::ggplot(rank_plot_data, ggplot2::aes(.data$ratio, .data$unit_f, fill = .data$is_treated)) +
      ggplot2::geom_col() +
      ggplot2::scale_fill_manual(values = c(`TRUE` = "#6a3d9a", `FALSE` = "gray75"), guide = "none") +
      ggplot2::facet_wrap(~short, scales = "free", ncol = 1) +
      ggplot2::labs(title = paste0(eid, " (", treated_label, ") — razao RMSPE pos/pre, todas as unidades"),
                    subtitle = "Roxo = tratado real; cinza = doadores (pseudo-tratados). Ranking, nao o p continuo, e a estatistica recomendada com pool pequeno.",
                    x = "Razao RMSPE pos/pre", y = NULL) +
      base_theme() + ggplot2::theme(axis.text.y = ggplot2::element_text(size = 7))
    ggplot2::ggsave(file.path(fig_dir, paste0("flagship_", eid, "_placebo_rank.png")), p5,
                    width = 8, height = 3.2 * nrow(om), dpi = 300, bg = "white", limitsize = FALSE)
  }

  message(eid, ": figuras bandeira salvas.")
}
