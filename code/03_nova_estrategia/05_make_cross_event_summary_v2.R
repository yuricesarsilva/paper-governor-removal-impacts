# ── Nova Estrategia v2 engine: cross-event summary ────────────────────────────
# Aggregates per-event evidence_classification.csv / nova_estrategia_classification.csv
# tables into a master cross-event table + markdown summary + comparison
# figures, mirroring the structure of output/_summary/cross_event_results.csv
# and output/_summary/cross_event_summary.md (the old engine's cross-event
# summary). Graded by the in-space donor placebo rank test (classic_p), the
# same family of test as the old engine's own RMSPE-ratio placebo, just our
# own AugSCM (k=6, block+slope predictors). LOO donor-exclusion is reported as
# a robustness cross-check, not the significance criterion.
# Writes under output_v2/_summary/ only.

source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))
source(file.path("code", "03_nova_estrategia", "00_nova_estrategia_config.R"))

extra_packages <- c("ggplot2", "tidyr")
missing_extra <- extra_packages[!vapply(extra_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_extra) > 0) stop("Missing packages: ", paste(missing_extra, collapse = ", "))
invisible(lapply(extra_packages, library, character.only = TRUE))

summary_dir <- summary_root_v2()
fig_dir     <- file.path(summary_dir, "figures")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

# ── Event characteristics for groupings (timing in mandate, sample) ──────────
inv <- readr::read_csv(
  file.path(root_dir, "data", "raw", "governor_removal_events.csv"), show_col_types = FALSE
) |>
  dplyr::mutate(
    removal_date         = as.Date(.data$removal_date),
    legal_term_end_date  = as.Date(.data$legal_term_end_date),
    mo_to_end            = as.numeric(.data$legal_term_end_date - .data$removal_date) / 30.44
  ) |>
  dplyr::transmute(
    event_id    = .data$event_id,
    removal_date = .data$removal_date,
    main_sample = .data$include_main_sample,
    timing      = ifelse(.data$mo_to_end <= 12, "last-year", "earlier")
  )

# ── Master table: one row per event-outcome ───────────────────────────────────
# Direction/effect-for-plot are derived from att_mean_w6m (the same primary
# window used for `effect_label` in each event's evidence_classification.csv),
# NOT from gap_post (the full post-period mean used internally for the
# persistence/magnitude criteria). These two can disagree in sign when an
# effect fades or reverses over the post period -- using w6m keeps "Effect"
# and "Dir" in this table consistent with each other.
att_window_cols <- c("att_mean_w3m", "att_mean_w6m", "att_mean_w12m", "att_mean_w24m")

master <- purrr::map_dfr(nova_estrategia_events$event_id, function(eid) {
  d  <- event_dirs_v2(eid)
  ef <- file.path(d$tables, "evidence_classification.csv")
  sf <- file.path(d$output, paste0(eid, "_scm_summary.csv"))
  if (!file.exists(ef) || !file.exists(sf)) return(NULL)
  meta <- readr::read_csv(file.path(d$data, paste0(eid, "_event_metadata.csv")), show_col_types = FALSE) |>
    dplyr::slice(1)
  att_windows <- readr::read_csv(sf, show_col_types = FALSE) |>
    dplyr::select("outcome", dplyr::any_of(att_window_cols))
  readr::read_csv(ef, show_col_types = FALSE) |>
    dplyr::left_join(att_windows, by = "outcome") |>
    dplyr::mutate(
      event_id  = eid,
      regime    = meta$regime[[1]],
      direction = ifelse(.data$att_mean_w6m >= 0, "positive", "negative"),
      effect_for_plot = ifelse(.data$transform == "log",
                                100 * (exp(.data$att_mean_w6m) - 1), .data$att_mean_w6m)
    )
})
if (nrow(master) == 0) stop("No event results found under output_v2/. Run the per-event stages first.")

# Sign-stability across the 4 v6 windows (w3m -> w24m): TRUE if every
# available window agrees in sign. Flags effects that fade or reverse over
# the post period instead of holding up (e.g. SC_2021_01 ICMS: negative at
# w6m, positive by w24m).
sign_mat <- sign(as.matrix(master[, att_window_cols, drop = FALSE]))
master$sign_stable_across_windows <- apply(sign_mat, 1, function(r) {
  r <- r[is.finite(r) & r != 0]
  length(unique(r)) <= 1
})

master <- master |> dplyr::left_join(inv, by = "event_id")
readr::write_csv(master, file.path(summary_dir, "cross_event_results.csv"), na = "")

event_levels   <- inv |> dplyr::arrange(.data$removal_date) |>
  dplyr::filter(.data$event_id %in% master$event_id) |> dplyr::pull(.data$event_id)
outcome_levels <- outcome_catalog_v2$short
tier_levels    <- c("strong", "moderate", "suggestive", "weak")

master <- master |> dplyr::mutate(
  event_f   = factor(.data$event_id, levels = event_levels),
  outcome_f = factor(.data$short, levels = outcome_levels),
  tier_f    = factor(.data$tier, levels = tier_levels)
)

base_theme <- function() {
  ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(legend.position = "bottom", panel.grid.minor = ggplot2::element_blank(),
                   plot.title.position = "plot")
}

tier_cols <- c(strong = "#1a9850", moderate = "#91cf60", suggestive = "#fee08b", weak = "#f0f0f0")

# (a) Evidence-tier heatmap (event x outcome).
hm <- ggplot2::ggplot(master, ggplot2::aes(.data$outcome_f, .data$event_f, fill = .data$tier_f)) +
  ggplot2::geom_tile(color = "white", linewidth = 0.5) +
  ggplot2::geom_text(ggplot2::aes(label = paste0(.data$effect_label,
                                                  ifelse(.data$poor_fit & nzchar(.data$effect_label), "!", ""))), size = 3) +
  ggplot2::scale_fill_manual(values = tier_cols, drop = FALSE, na.value = "gray92", name = "evidence tier") +
  ggplot2::labs(title = "Nova estrategia v2 — evidence strength by event and outcome (in-space placebo tier)",
                subtitle = "Color = in-space placebo p band (LOO is robustness, not shown here). Labels: signed effect (% for log outcomes; per 1k residents for hiring); '!' = poor pre-fit; blank = outcome not in this event's set.",
                x = NULL, y = NULL) +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 20, hjust = 1), panel.grid = ggplot2::element_blank())
ggplot2::ggsave(file.path(fig_dir, "cross_event_evidence_tiers.png"), hm, width = 10, height = 7, dpi = 300, bg = "white")

# (b) Considerable effects: signed magnitude, faceted by channel.
cons <- master |> dplyr::filter(.data$considerable, is.finite(.data$effect_for_plot))
if (nrow(cons) > 0) {
  gp <- ggplot2::ggplot(cons, ggplot2::aes(.data$effect_for_plot, .data$event_f, color = .data$tier_f)) +
    ggplot2::geom_vline(xintercept = 0, color = "gray70", linewidth = 0.4) +
    ggplot2::geom_point(size = 2.8) +
    ggplot2::facet_wrap(~ channel_labels_v2[.data$channel], scales = "free", ncol = 2) +
    ggplot2::scale_color_manual(values = tier_cols, drop = FALSE, name = "tier") +
    ggplot2::labs(title = "Nova estrategia v2 — considerable effects: signed magnitude",
                  subtitle = "Post effect (w6m) — % of synthetic (retail/icms) or absolute gap per 1,000 residents (formal hiring)",
                  x = "Post effect", y = NULL) +
    base_theme()
  ggplot2::ggsave(file.path(fig_dir, "cross_event_considerable_effects.png"), gp, width = 11, height = 7, dpi = 300, bg = "white")
}

# (c) ATT trajectory across the 4 v6 post-treatment windows (w3m..w24m), for
# considerable event-outcomes only -- shows whether an effect holds up,
# fades, or reverses sign as the post-treatment horizon lengthens.
window_end_month <- c(w3m = 7, w6m = 10, w12m = 16, w24m = 28)
window_long <- master |>
  dplyr::select("event_id", "event_f", "outcome", "short", "channel", "transform",
                "tier", "tier_f", "considerable", dplyr::any_of(att_window_cols)) |>
  tidyr::pivot_longer(cols = dplyr::any_of(att_window_cols), names_to = "window", values_to = "att_mean") |>
  dplyr::mutate(
    window      = sub("att_mean_", "", .data$window),
    window_end  = window_end_month[.data$window],
    effect_disp = ifelse(.data$transform == "log", 100 * (exp(.data$att_mean) - 1), .data$att_mean)
  ) |>
  dplyr::filter(is.finite(.data$att_mean))

traj <- window_long |> dplyr::filter(.data$considerable)
if (nrow(traj) > 0) {
  gp2 <- ggplot2::ggplot(traj, ggplot2::aes(.data$window_end, .data$effect_disp,
                                             group = interaction(.data$event_id, .data$outcome),
                                             color = .data$tier_f)) +
    ggplot2::geom_hline(yintercept = 0, color = "gray70", linewidth = 0.4) +
    ggplot2::geom_line(linewidth = 0.7, alpha = 0.8) +
    ggplot2::geom_point(size = 1.8) +
    ggplot2::scale_x_continuous(breaks = window_end_month, labels = names(window_end_month)) +
    ggplot2::facet_wrap(~ channel_labels_v2[.data$channel], scales = "free_y", ncol = 2) +
    ggplot2::scale_color_manual(values = tier_cols, drop = FALSE, name = "tier (overall)") +
    ggplot2::labs(title = "Nova estrategia v2 — ATT trajectory across post-treatment windows",
                  subtitle = "Considerable event-outcomes only. x = post window (w3m..w24m); color = overall tier (graded at w6m).",
                  x = "Post window (months since event_time = +5)", y = "Effect (display scale)") +
    base_theme()
  ggplot2::ggsave(file.path(fig_dir, "cross_event_window_trajectories.png"), gp2, width = 11, height = 7, dpi = 300, bg = "white")
}

# ── Groupings (considerable effects only) ─────────────────────────────────────
fmt <- function(x, dg = 2) ifelse(is.na(x) | !is.finite(x), "", format(round(x, dg), nsmall = dg))
mdtab <- function(df) c(paste0("| ", paste(names(df), collapse = " | "), " |"),
  paste0("| ", paste(rep("---", ncol(df)), collapse = " | "), " |"),
  apply(df, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |")))

tier_counts <- as.data.frame(table(factor(master$tier, levels = tier_levels)))
names(tier_counts) <- c("Tier", "n")

cons_all <- master |> dplyr::filter(.data$considerable)
grp_dir <- function(df, by) {
  df |> dplyr::group_by(.data[[by]]) |>
    dplyr::summarise(considerable = dplyr::n(), negative = sum(.data$direction == "negative"),
                     positive = sum(.data$direction == "positive"), .groups = "drop") |>
    dplyr::rename(Group = 1)
}
by_timing  <- grp_dir(cons_all, "timing")
by_main    <- cons_all |> dplyr::mutate(samp = ifelse(.data$main_sample == 1, "main", "extended")) |> grp_dir("samp")
by_channel <- cons_all |> dplyr::mutate(ch = channel_labels_v2[.data$channel]) |> grp_dir("ch")

master_tab <- master |> dplyr::arrange(.data$event_f, .data$outcome_f) |>
  dplyr::transmute(
    Event = .data$event_id, Outcome = .data$short, Tier = .data$tier, Effect = .data$effect_label,
    `Inspace p` = fmt(.data$inspace_p, 3), `Inspace rank` = dplyr::coalesce(.data$inspace_rank, ""),
    Persist = fmt(.data$persistence, 2), `Pre corr` = fmt(.data$pre_fit_corr, 2),
    `Poor fit` = ifelse(.data$poor_fit, "yes", ""), Dir = .data$direction,
    `LOO p (rob.)` = fmt(.data$loo_p, 3), `LOO rank (rob.)` = dplyr::coalesce(.data$loo_rank, "")
  )

# ── ATT by post-treatment window (the 4 windows fixed in the rr_2018_01_v6
#    pilot: w3m [+5,+7], w6m [+5,+10], w12m [+5,+16], w24m [+5,+28]) ─────────
fmt_window_effect <- function(att, transform) {
  ifelse(!is.finite(att), "",
         ifelse(transform == "log",
                paste0(formatC(100 * (exp(att) - 1), format = "f", digits = 1, flag = "+"), "%"),
                formatC(att, format = "f", digits = 1, flag = "+")))
}

window_tab <- master |> dplyr::arrange(.data$event_f, .data$outcome_f) |>
  dplyr::transmute(
    Event = .data$event_id, Outcome = .data$short,
    w3m  = fmt_window_effect(.data$att_mean_w3m,  .data$transform),
    w6m  = fmt_window_effect(.data$att_mean_w6m,  .data$transform),
    w12m = fmt_window_effect(.data$att_mean_w12m, .data$transform),
    w24m = fmt_window_effect(.data$att_mean_w24m, .data$transform),
    `Sign stable` = ifelse(.data$sign_stable_across_windows, "yes", "no")
  )

n_ev   <- length(event_levels)
n_cons <- nrow(cons_all)
n_neg  <- sum(cons_all$direction == "negative")

n_unstable_cons <- sum(!cons_all$sign_stable_across_windows, na.rm = TRUE)
unstable_list <- cons_all |> dplyr::filter(!.data$sign_stable_across_windows) |>
  dplyr::transmute(lbl = paste0(.data$event_id, "/", .data$short)) |> dplyr::pull(.data$lbl)
unstable_note <- if (n_unstable_cons > 0) paste0(" (", paste(unstable_list, collapse = "; "), ")") else ""

# ── Compact per-event classification table (kept for quick reference) ────────
class_rows <- purrr::map_dfr(nova_estrategia_events$event_id, function(eid) {
  d <- event_dirs_v2(eid)
  f <- file.path(d$tables, "nova_estrategia_classification.csv")
  if (!file.exists(f)) return(NULL)
  readr::read_csv(f, show_col_types = FALSE,
                   col_types = readr::cols(Hiring = readr::col_character()))
})
readr::write_csv(class_rows, file.path(summary_dir, "nova_estrategia_cross_event_summary.csv"), na = "")

lines <- c(
  "# Nova estrategia v2 — cross-event results summary", "",
  paste0("Generated on ", Sys.Date(), ". Events with results: ", n_ev, " (of ", nrow(nova_estrategia_events), " in scope)."), "",
  "## Evidence ruler", "",
  "Tiers follow the in-space donor placebo test (Abadie, Diamond & Hainmueller 2010): each donor is refit as if it were the treated unit (donor pool = the other donors, real treated state excluded), and the real treated unit's post/pre RMSPE ratio is ranked within the resulting placebo distribution (classic_p = rank/N, two-sided). With a small donor pool (~22-27) the smallest achievable p is ~1/N, so the rank itself -- not the continuous p -- is the informative statistic; both are reported. To rise above *weak* the effect must also clear a substantive-magnitude threshold (log outcomes: |ATT| >= 5% in w6m or w12m; formal hiring: >= 0.5 per 1,000 residents) and have post-period sign-consistency >= 50%. **strong** (p<=0.05), **moderate** (<=0.10), **suggestive** (<=0.15), **weak** otherwise; *considerable* = strong/moderate/suggestive. The leave-one-out (LOO) donor-exclusion placebo is reported separately as a robustness check (stability to which donor is in the pool) -- it is **not** used to grade tiers. Pre-treatment fit (treated-synthetic correlation/R2) is reported and poor-fit cells flagged, **not** used to discard results.", "",
  "### Tier distribution", "", mdtab(tier_counts), "",
  paste0("**Considerable effects: ", n_cons, " of ", nrow(master), "** event-outcomes; ", n_neg, " negative / ", n_cons - n_neg, " positive."), "",
  "![cross_event_evidence_tiers.png](figures/cross_event_evidence_tiers.png)", "",
  "![cross_event_considerable_effects.png](figures/cross_event_considerable_effects.png)", "",
  "## Groupings (considerable effects only)", "",
  "### By timing in mandate (removal in last year vs earlier)", "", mdtab(by_timing), "",
  "### By sample (main vs extended)", "", mdtab(by_main), "",
  "### By channel", "", mdtab(by_channel), "",
  "## Master table (all event-outcomes)", "", mdtab(master_tab), "",
  "## ATT by post-treatment window (all event-outcomes)", "",
  "Windows fixed in the rr_2018_01_v6 pilot: w3m [+5,+7], w6m [+5,+10], w12m [+5,+16], w24m [+5,+28] (event_time in months since removal; post starts at +5, Option B for k=6).", "",
  mdtab(window_tab), "",
  paste0("**Sign stability**: of the ", n_cons, " considerable effects (graded at w6m), ",
         n_cons - n_unstable_cons, " keep the same sign across every available window; ",
         n_unstable_cons, " reverse sign somewhere between w3m and w24m", unstable_note, "."), "",
  "![cross_event_window_trajectories.png](figures/cross_event_window_trajectories.png)", "",
  "## Nova Estrategia classification (Alcance x Duracao)", "",
  "Alcance = count of outcomes affected (0=Nulo, 1=Restrito, 2=Ampliado, 3=Propagado), no hierarchy among variables. Ceiling is Ampliado for the 5 events without formal_hiring (CAGED coverage insufficient).", "",
  mdtab(class_rows), "",
  "## Methodological note", "",
  "In-space placebo inference is discrete and low-resolution when the donor pool is small (finest p ~ 1/N), so a p slightly above a conventional threshold but with a high placebo rank and a substantive, persistent gap is read as suggestive, not conventional significance -- this is why rank is reported alongside p throughout. Pre-treatment fit is reported and poor-fit cases flagged for the reader rather than discarded. LOO donor-exclusion robustness (does the conclusion hinge on one donor) is reported per event but does not feed the tier."
)

readr::write_lines(lines, file.path(summary_dir, "cross_event_summary.md"))

message("=== nova estrategia v2 cross-event summary: ", n_ev, " events, ", nrow(master),
        " event-outcomes, ", n_cons, " considerable ===")
