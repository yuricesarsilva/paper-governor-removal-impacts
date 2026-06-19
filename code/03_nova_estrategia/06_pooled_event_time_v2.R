# ── Nova Estrategia v2 engine: pooled event-time (meta) analysis ─────────────
# Event-by-event AugSCM with ~22 donors is structurally low-powered (same
# diagnosis as code/02_analysis/05_pooled_event_time.R for the old engine).
# To detect a modest AVERAGE effect across the 15 events, pool them:
#   (1) events-as-units: one-sample t-test / Wilcoxon on the 15 events' own
#       mean post-treatment gaps, per outcome. Needs no placebo data -- uses
#       only the already-fitted treated path for each event.
#   (2) pooled placebo: average each unit's pre-RMSPE-normalized post gap
#       across events, rank the treated unit's pooled normalized effect
#       against the donor distribution. Only computed for events that already
#       have in-space placebo data (currently the 3 flagship cases; extend
#       02b_run_event_placebo_inspace_v2.R to more events to broaden this).
#
# Usage: Rscript code/03_nova_estrategia/06_pooled_event_time_v2.R

source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))
source(file.path("code", "03_nova_estrategia", "00_nova_estrategia_config.R"))

extra_packages <- c("ggplot2", "tidyr")
missing_extra <- extra_packages[!vapply(extra_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_extra) > 0) stop("Missing packages: ", paste(missing_extra, collapse = ", "))
invisible(lapply(extra_packages, library, character.only = TRUE))

POST_START <- 5L

summary_dir <- summary_root_v2()
fig_dir <- file.path(summary_dir, "figures")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

treated_rows <- list(); per_event_rows <- list(); placebo_norm_rows <- list()

for (i in seq_len(nrow(nova_estrategia_events))) {
  eid        <- nova_estrategia_events$event_id[i]
  include_fh <- nova_estrategia_events$include_formal_hiring[i]
  d <- event_dirs_v2(eid)
  outcome_cols <- get_outcome_list(include_fh)

  for (outcome in outcome_cols) {
    slug <- make_slug(outcome)
    pf <- file.path(d$monthly, paste0(slug, "_path.csv"))
    if (!file.exists(pf)) next
    p  <- readr::read_csv(pf, show_col_types = FALSE)
    om <- outcome_catalog_v2[outcome_catalog_v2$outcome == outcome, ]
    sh <- om$short[[1]]; lg <- identical(om$transform[[1]], "log")

    treated_rows[[length(treated_rows) + 1L]] <- p |>
      dplyr::transmute(event_id = eid, short = sh, is_log = lg,
                        event_time = .data$event_time, gap = .data$augmented_gap)

    rmspe_pre <- p |> dplyr::filter(.data$event_time < 0, is.finite(.data$augmented_gap)) |>
      dplyr::summarise(r = sqrt(mean(.data$augmented_gap^2))) |> dplyr::pull(.data$r)
    mean_post_gap <- p |> dplyr::filter(.data$event_time >= POST_START, is.finite(.data$augmented_gap)) |>
      dplyr::summarise(m = mean(.data$augmented_gap)) |> dplyr::pull(.data$m)

    per_event_rows[[length(per_event_rows) + 1L]] <- tibble::tibble(
      event_id = eid, short = sh, is_log = lg,
      mean_post_gap = mean_post_gap, rmspe_pre = rmspe_pre
    )

    ipf <- file.path(d$output, "placebo_inspace", paste0(slug, "_inspace_paths.csv"))
    isf <- file.path(d$output, "placebo_inspace", paste0(slug, "_inspace_summary.csv"))
    if (file.exists(ipf) && file.exists(isf)) {
      ip   <- readr::read_csv(ipf, show_col_types = FALSE)
      isum <- readr::read_csv(isf, show_col_types = FALSE)
      dg <- ip |> dplyr::filter(.data$event_time >= POST_START, is.finite(.data$augmented_gap)) |>
        dplyr::group_by(.data$pseudo_treated_state) |>
        dplyr::summarise(mean_post_gap = mean(.data$augmented_gap, na.rm = TRUE), .groups = "drop") |>
        dplyr::left_join(isum |> dplyr::select("pseudo_treated_state", "rmspe_pre"), by = "pseudo_treated_state")
      if (nrow(dg) > 0) {
        placebo_norm_rows[[length(placebo_norm_rows) + 1L]] <- dg |>
          dplyr::transmute(event_id = eid, short = sh, unit = .data$pseudo_treated_state,
                            .data$mean_post_gap, .data$rmspe_pre)
      }
    }
  }
}

treated      <- dplyr::bind_rows(treated_rows)
per_event    <- dplyr::bind_rows(per_event_rows)
placebo_norm <- dplyr::bind_rows(placebo_norm_rows)

# ── Test 1: events-as-units (t-test / Wilcoxon on the 15 events' mean post gaps) ─
pooled_tab <- per_event |> dplyr::group_by(.data$short, .data$is_log) |>
  dplyr::summarise(
    n_events = dplyr::n(),
    mean_gap = mean(.data$mean_post_gap, na.rm = TRUE),
    t_p      = tryCatch(stats::t.test(.data$mean_post_gap)$p.value, error = function(e) NA_real_),
    wilcox_p = tryCatch(stats::wilcox.test(.data$mean_post_gap)$p.value, error = function(e) NA_real_),
    n_neg    = sum(.data$mean_post_gap < 0, na.rm = TRUE),
    .groups = "drop"
  ) |>
  # NB: don't call pct(x, TRUE) here -- ifelse()'s result length follows its
  # `test` argument, so a scalar TRUE silently collapses a vectorized call to
  # length 1. Compute the % transform for every row first, then pick per row.
  dplyr::mutate(
    pct_gap    = 100 * (exp(.data$mean_gap) - 1),
    avg_effect = ifelse(.data$is_log, sprintf("%+.1f%%", .data$pct_gap), sprintf("%+.2f", .data$mean_gap))
  )

# ── Test 2: pooled placebo (only for events with in-space placebo data so far) ──
pp_tab <- tibble::tibble()
if (nrow(placebo_norm) > 0) {
  events_with_placebo <- unique(placebo_norm$event_id)
  tn <- per_event |>
    dplyr::filter(.data$event_id %in% events_with_placebo, is.finite(.data$rmspe_pre), .data$rmspe_pre > 0) |>
    dplyr::mutate(norm = .data$mean_post_gap / .data$rmspe_pre) |>
    dplyr::group_by(.data$short) |>
    dplyr::summarise(treated_pooled = mean(.data$norm, na.rm = TRUE), n_ev_placebo = dplyr::n(), .groups = "drop")

  pn <- placebo_norm |> dplyr::filter(is.finite(.data$rmspe_pre), .data$rmspe_pre > 0) |>
    dplyr::mutate(norm = .data$mean_post_gap / .data$rmspe_pre) |>
    dplyr::group_by(.data$short, .data$unit) |>
    dplyr::summarise(pooled_norm = mean(.data$norm, na.rm = TRUE), .groups = "drop")

  placebo_p_for <- function(sh, treated_pooled) {
    pl <- pn$pooled_norm[pn$short == sh]
    if (length(pl) == 0 || !is.finite(treated_pooled)) return(NA_real_)
    mean(abs(pl) >= abs(treated_pooled), na.rm = TRUE)
  }
  pp_tab <- tn |> dplyr::mutate(placebo_p = purrr::map2_dbl(.data$short, .data$treated_pooled, placebo_p_for))
}

result <- pooled_tab |> dplyr::left_join(pp_tab, by = "short") |>
  dplyr::transmute(
    Outcome = .data$short, n = .data$n_events, `Avg effect` = .data$avg_effect,
    `t p` = round(.data$t_p, 3), `Wilcoxon p` = round(.data$wilcox_p, 3),
    `Pooled placebo p` = round(.data$placebo_p, 3),
    `n events w/ placebo` = ifelse(is.na(.data$n_ev_placebo), 0L, .data$n_ev_placebo),
    neg = .data$n_neg
  )
readr::write_csv(result, file.path(summary_dir, "pooled_event_time_results.csv"), na = "")

cat("=== NOVA ESTRATEGIA V2 -- POOLED EVENT-TIME: average effect across events, per outcome ===\n")
print(as.data.frame(result), row.names = FALSE)

# ── Event-time average gap figure ─────────────────────────────────────────────
order_sh <- outcome_catalog_v2$short
avg_path <- treated |> dplyr::group_by(.data$short, .data$event_time) |>
  dplyr::summarise(mean_gap = mean(.data$gap, na.rm = TRUE), n = dplyr::n(), .groups = "drop") |>
  dplyr::filter(.data$n >= 3) |> dplyr::mutate(short = factor(.data$short, levels = order_sh))
ind <- treated |> dplyr::mutate(short = factor(.data$short, levels = order_sh))

gp <- ggplot2::ggplot() +
  ggplot2::geom_hline(yintercept = 0, color = "gray60", linewidth = 0.4) +
  ggplot2::geom_vline(xintercept = 0, linetype = "dashed", color = "gray10") +
  ggplot2::geom_line(data = ind, ggplot2::aes(.data$event_time, .data$gap, group = .data$event_id),
                     color = "gray80", alpha = 0.5, linewidth = 0.4) +
  ggplot2::geom_line(data = avg_path, ggplot2::aes(.data$event_time, .data$mean_gap),
                     color = "#1f6f8b", linewidth = 1.2) +
  ggplot2::facet_wrap(~short, scales = "free_y", ncol = 2) +
  ggplot2::labs(
    title    = "Pooled event-time: gap tratado-sintetico, media entre os 15 eventos",
    subtitle = "Cinza = eventos individuais; azul = media entre eventos; tracejado = remocao (event_time = 0)",
    x = "Meses relativos a remocao", y = "Gap (tratado - sintetico)"
  ) +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(panel.grid.minor = ggplot2::element_blank())
ggplot2::ggsave(file.path(fig_dir, "pooled_event_time_gaps.png"), gp, width = 12, height = 8, dpi = 300, bg = "white")
message("Saved pooled results + figure under output_v2/_summary/.")
