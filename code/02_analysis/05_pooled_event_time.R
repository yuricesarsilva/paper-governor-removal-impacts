# ── Pooled event-time (meta) analysis ─────────────────────────────────────────
# Event-by-event SCM with ~22 donors is structurally low-powered (a "considerable"
# effect must be the 2nd-3rd most extreme of ~22 units). To detect a MODEST average
# effect, pool the events: align all events at the removal date, average the
# treated-minus-synthetic gap across events per outcome, and test the average two
# ways:
#   (1) events-as-units: one-sample t / Wilcoxon on the per-event mean post gaps;
#   (2) pooled placebo: average each donor's normalized gap across events and rank
#       the treated unit's pooled normalized effect against that distribution.
# Outcomes are pooled by display label (ICMS/Tax combine CONFAZ + SICONFI events,
# both log real pc -> comparable in %). Writes under output/_summary/.
#
# Usage: Rscript code/02_analysis/05_pooled_event_time.R

source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))
source(file.path("code", "02_analysis", "00_event_config.R"))
source(file.path("code", "02_analysis", "00b_engine_helpers.R"))
extra <- c("ggplot2", "tidyr"); invisible(lapply(extra, library, character.only = TRUE))

sdir <- summary_root(); fig_dir <- file.path(sdir, "figures")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

# Map each outcome key -> display short + whether it is a log outcome (effect in %).
short_of <- function(k) outcome_catalog[[k]]$short
islog_of <- function(k) identical(outcome_catalog[[k]]$transform, "log")

# Gather, per event, the treated gap path + per-event mean post gap + pre-RMSPE,
# and the donor (placebo) per-unit mean post gap + pre-RMSPE.
treated_rows <- list(); donor_rows <- list()
for (eid in analysis_events) {
  d <- event_dirs(eid)
  sf <- file.path(d$scm, paste0(eid, "_scm_summary.csv")); mf <- file.path(d$data, paste0(eid, "_event_metadata.csv"))
  if (!file.exists(sf) || !file.exists(mf)) next
  meta <- readr::read_csv(mf, show_col_types = FALSE) |> dplyr::slice(1)
  rem  <- as.Date(meta$removal_date[[1]])
  sm   <- readr::read_csv(sf, show_col_types = FALSE) |> dplyr::filter(.data$status == "estimated")
  ps_f <- file.path(d$scm, "placebo_inspace", "placebo_summary.csv")
  pp_f <- file.path(d$scm, "placebo_inspace", "placebo_paths.csv")
  ps   <- if (file.exists(ps_f)) readr::read_csv(ps_f, show_col_types = FALSE) else NULL
  pp   <- if (file.exists(pp_f)) readr::read_csv(pp_f, show_col_types = FALSE) else NULL

  for (i in seq_len(nrow(sm))) {
    o <- sm$outcome[i]; fam <- sm$family[i]; sh <- short_of(o); lg <- islog_of(o)
    pth <- file.path(d$scm, fam, "sa", paste0(make_slug(o), "_path.csv"))
    if (!file.exists(pth)) next
    p <- readr::read_csv(pth, show_col_types = FALSE) |> dplyr::mutate(period_date = as.Date(.data$period_date))
    plen <- if (fam == "bimonthly") 2 else 1
    p <- p |> dplyr::mutate(et = round(as.numeric(.data$period_date - rem) / 30.44 / plen))
    treated_rows[[length(treated_rows) + 1L]] <- p |>
      dplyr::transmute(event_id = eid, short = sh, is_log = lg, et = .data$et,
                       analysis_period = .data$analysis_period, gap = .data$augmented_gap)
    # per-unit summaries
    tre_pre <- sm$augmented_rmspe_pre[i]; tre_gap <- sm$augmented_mean_gap_post[i]
    donor_rows[[length(donor_rows) + 1L]] <- tibble::tibble(
      event_id = eid, short = sh, is_log = lg, unit = "TREATED",
      mean_post_gap = tre_gap, pre_rmspe = tre_pre)
    if (!is.null(pp) && !is.null(ps)) {
      dg <- pp |> dplyr::filter(.data$outcome == o, .data$analysis_period == "post") |>
        dplyr::group_by(.data$pseudo_treated_state) |>
        dplyr::summarise(mean_post_gap = mean(.data$augmented_gap, na.rm = TRUE), .groups = "drop") |>
        dplyr::left_join(ps |> dplyr::filter(.data$outcome == o) |>
                           dplyr::select("pseudo_treated_state", "pre_rmspe"), by = "pseudo_treated_state")
      if (nrow(dg)) donor_rows[[length(donor_rows) + 1L]] <- tibble::tibble(
        event_id = eid, short = sh, is_log = lg, unit = dg$pseudo_treated_state,
        mean_post_gap = dg$mean_post_gap, pre_rmspe = dg$pre_rmspe)
    }
  }
}
treated <- dplyr::bind_rows(treated_rows)
units   <- dplyr::bind_rows(donor_rows)

# ── (1) Events-as-units test on per-event treated mean post gaps ───────────────
pct <- function(x, lg) if (lg) 100 * (exp(x) - 1) else x
te <- units |> dplyr::filter(.data$unit == "TREATED")
pooled_tab <- te |> dplyr::group_by(.data$short, .data$is_log) |>
  dplyr::summarise(
    n_events = dplyr::n(),
    mean_gap = mean(.data$mean_post_gap, na.rm = TRUE),
    t_p   = tryCatch(stats::t.test(.data$mean_post_gap)$p.value, error = function(e) NA_real_),
    wilcox_p = tryCatch(stats::wilcox.test(.data$mean_post_gap)$p.value, error = function(e) NA_real_),
    n_neg = sum(.data$mean_post_gap < 0), .groups = "drop") |>
  dplyr::mutate(avg_effect = ifelse(.data$is_log, sprintf("%+.1f%%", pct(.data$mean_gap, TRUE)),
                                    sprintf("%+.2f", .data$mean_gap)))

# ── (2) Pooled placebo: average each unit's normalized gap across events ───────
pooled_placebo <- units |>
  dplyr::filter(is.finite(.data$pre_rmspe), .data$pre_rmspe > 0) |>
  dplyr::mutate(norm = .data$mean_post_gap / .data$pre_rmspe) |>
  dplyr::group_by(.data$short, .data$unit) |>
  dplyr::summarise(pooled_norm = mean(.data$norm, na.rm = TRUE), n_ev = dplyr::n(), .groups = "drop")
pp_tab <- pooled_placebo |> dplyr::group_by(.data$short) |>
  dplyr::summarise(
    treated_pooled = .data$pooled_norm[.data$unit == "TREATED"][1],
    placebo_p = {
      tr <- .data$pooled_norm[.data$unit == "TREATED"][1]
      pl <- .data$pooled_norm[.data$unit != "TREATED"]
      if (length(pl) && is.finite(tr)) mean(abs(pl) >= abs(tr), na.rm = TRUE) else NA_real_
    }, .groups = "drop")

result <- pooled_tab |> dplyr::left_join(pp_tab, by = "short") |>
  dplyr::transmute(Outcome = .data$short, n = .data$n_events, `Avg effect` = .data$avg_effect,
                   `t p` = round(.data$t_p, 3), `Wilcoxon p` = round(.data$wilcox_p, 3),
                   `Pooled placebo p` = round(.data$placebo_p, 3),
                   neg = .data$n_neg)
readr::write_csv(result, file.path(sdir, "pooled_event_time_results.csv"), na = "")

cat("=== POOLED EVENT-TIME: average effect across events, per outcome ===\n")
print(as.data.frame(result), row.names = FALSE)

# ── Event-time average gap figure ─────────────────────────────────────────────
order_sh <- unique(vapply(names(outcome_catalog), short_of, character(1)))
avg_path <- treated |> dplyr::group_by(.data$short, .data$et) |>
  dplyr::summarise(mean_gap = mean(.data$gap, na.rm = TRUE), n = dplyr::n(), .groups = "drop") |>
  dplyr::filter(.data$n >= 3) |> dplyr::mutate(short = factor(.data$short, levels = order_sh))
ind <- treated |> dplyr::mutate(short = factor(.data$short, levels = order_sh))
gp <- ggplot2::ggplot() +
  ggplot2::geom_hline(yintercept = 0, color = "gray60", linewidth = 0.4) +
  ggplot2::geom_vline(xintercept = 0, linetype = "dashed", color = "gray10") +
  ggplot2::geom_line(data = ind, ggplot2::aes(.data$et, .data$gap, group = .data$event_id),
                     color = "gray80", alpha = 0.5, linewidth = 0.4) +
  ggplot2::geom_line(data = avg_path, ggplot2::aes(.data$et, .data$mean_gap), color = "#1f6f8b", linewidth = 1.2) +
  ggplot2::facet_wrap(~short, scales = "free_y", ncol = 2) +
  ggplot2::labs(title = "Pooled event-time: treated-minus-synthetic gap, averaged across events",
                subtitle = "Gray = individual events; blue = cross-event average; dashed = removal (event time 0). Units: log/index/per-100k per outcome.",
                x = "Periods relative to removal", y = "Gap (treated - synthetic)") +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(panel.grid.minor = ggplot2::element_blank())
ggplot2::ggsave(file.path(fig_dir, "pooled_event_time_gaps.png"), gp, width = 12, height = 8, dpi = 300, bg = "white")
message("Saved pooled results + figure under output/_summary/.")
