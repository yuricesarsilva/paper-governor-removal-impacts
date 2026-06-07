# ── Event-study engine: cross-event summary ───────────────────────────────────
# Aggregates per-event results into a master table graded by the 5-criterion
# AugSCM evidence ruler (pre-fit, magnitude, persistence, placebo rank,
# robustness), and produces comparative figures + groupings (timing in mandate,
# main vs extended sample, channel). Writes under output/_summary/.
#
# Usage: Rscript code/02_analysis/04_make_cross_event_summary.R

source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))
source(file.path("code", "02_analysis", "00_event_config.R"))
source(file.path("code", "02_analysis", "00b_engine_helpers.R"))

extra <- c("ggplot2", "tidyr")
miss  <- extra[!vapply(extra, requireNamespace, logical(1), quietly = TRUE)]
if (length(miss)) stop("Missing packages: ", paste(miss, collapse = ", "))
invisible(lapply(extra, library, character.only = TRUE))

sdir <- summary_root(); fig_dir <- file.path(sdir, "figures")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

# Event characteristics for groupings.
inv <- readr::read_csv(file.path(root_dir, "data", "raw", "governor_removal_events.csv"), show_col_types = FALSE) |>
  dplyr::mutate(removal_date = as.Date(.data$removal_date), legal_term_end_date = as.Date(.data$legal_term_end_date),
                mo_to_end = as.numeric(.data$legal_term_end_date - .data$removal_date) / 30.44) |>
  dplyr::transmute(event_id = .data$event_id, removal_date = .data$removal_date,
                   main_sample = .data$include_main_sample,
                   timing = ifelse(.data$mo_to_end <= 12, "last-year", "earlier"))

# Build the graded evidence table for every event that has results.
master <- purrr::map_dfr(analysis_events, function(eid) {
  dd <- event_dirs(eid)
  if (!file.exists(file.path(dd$scm, paste0(eid, "_scm_summary.csv")))) return(NULL)
  meta <- readr::read_csv(file.path(dd$data, paste0(eid, "_event_metadata.csv")), show_col_types = FALSE) |> dplyr::slice(1)
  et <- build_evidence_table(eid)
  if (nrow(et) == 0) return(NULL)
  et |> dplyr::mutate(regime = meta$regime[[1]])
})
if (nrow(master) == 0) stop("No event results found. Run the per-event stages first.")
master <- master |> dplyr::left_join(inv, by = "event_id")
readr::write_csv(master, file.path(sdir, "cross_event_results.csv"), na = "")

event_levels   <- inv |> dplyr::arrange(.data$removal_date) |> dplyr::filter(.data$event_id %in% master$event_id) |> dplyr::pull(.data$event_id)
outcome_levels <- unique(vapply(names(outcome_catalog), function(k) outcome_catalog[[k]]$short, character(1)))
tier_levels    <- c("strong", "moderate", "suggestive", "weak", "non-interpretable")
master <- master |> dplyr::mutate(
  event_f = factor(.data$event_id, levels = event_levels),
  outcome_f = factor(.data$short, levels = outcome_levels),
  tier_f = factor(.data$tier, levels = tier_levels))

base_theme <- function() ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(legend.position = "bottom", panel.grid.minor = ggplot2::element_blank(), plot.title.position = "plot")

# (a) Evidence-tier heatmap (event x outcome), considerable effects annotated with signed % effect.
tier_cols <- c(strong = "#1a9850", moderate = "#91cf60", suggestive = "#fee08b",
               weak = "#f0f0f0", `non-interpretable` = "gray85")
hm <- ggplot2::ggplot(master, ggplot2::aes(.data$outcome_f, .data$event_f, fill = .data$tier_f)) +
  ggplot2::geom_tile(color = "white", linewidth = 0.5) +
  ggplot2::geom_text(ggplot2::aes(label = ifelse(.data$tier != "non-interpretable", .data$effect_label, "")), size = 3) +
  ggplot2::scale_fill_manual(values = tier_cols, drop = FALSE, name = "evidence tier") +
  ggplot2::labs(title = "Evidence strength by event and outcome (5-criterion AugSCM ruler)",
                subtitle = "Labels: signed post effect for all eligible cells (% of synthetic; labor flows per 100k). Blank = non-interpretable (poor pre-fit).",
                x = NULL, y = NULL) +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 30, hjust = 1), panel.grid = ggplot2::element_blank())
ggplot2::ggsave(file.path(fig_dir, "cross_event_evidence_tiers.png"), hm, width = 11, height = 7, dpi = 300, bg = "white")

# (b) Considerable effects: signed % effect, faceted by channel, colored by tier.
cons <- master |> dplyr::filter(.data$considerable, is.finite(.data$effect_for_plot))
if (nrow(cons) > 0) {
  gp <- ggplot2::ggplot(cons, ggplot2::aes(.data$effect_for_plot, .data$event_f, color = .data$tier_f)) +
    ggplot2::geom_vline(xintercept = 0, color = "gray70", linewidth = 0.4) +
    ggplot2::geom_point(size = 2.8) +
    ggplot2::facet_wrap(~ channel_labels[.data$channel], scales = "free", ncol = 2) +
    ggplot2::scale_color_manual(values = tier_cols, drop = FALSE, name = "tier") +
    ggplot2::labs(title = "Considerable effects: signed magnitude",
                  subtitle = "Post effect — % of synthetic (fiscal/consumption) or absolute gap per 100k (labor flows)", x = "Post effect", y = NULL) +
    base_theme()
  ggplot2::ggsave(file.path(fig_dir, "cross_event_considerable_effects.png"), gp, width = 12, height = 7, dpi = 300, bg = "white")
}

# ── Groupings (the thesis) ────────────────────────────────────────────────────
fmt <- function(x, dg = 3) ifelse(is.na(x), "", format(round(x, dg), nsmall = dg))
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
by_channel <- cons_all |> dplyr::mutate(ch = channel_labels[.data$channel]) |> grp_dir("ch")

# Master table (considerable + a compact line per event-outcome with tier).
master_tab <- master |> dplyr::arrange(.data$event_f, .data$outcome_f) |>
  dplyr::transmute(Event = .data$event_id, Outcome = .data$short, Tier = .data$tier,
                   Score = paste0(.data$robustness_score, "/5"), Effect = .data$effect_label,
                   `Pre-fit` = .data$prefit_class, `Rank` = ifelse(is.na(.data$rank), "", paste0(.data$rank, "/", .data$n_units)),
                   `p` = fmt(.data$classic_p, 2), Dir = .data$direction)

n_ev <- length(event_levels); n_cons <- nrow(cons_all)
n_neg <- sum(cons_all$direction == "negative")
lines <- c(
  "# Cross-event results summary", "",
  paste0("Generated on ", Sys.Date(), ". Events with results: ", n_ev, "."), "",
  "## Evidence ruler", "",
  "Each event-outcome is graded on five criteria (pre-treatment fit, substantive magnitude, persistence, placebo rank, leave-one-out robustness) into a 0-5 score; pre-fit is a hard gate. Tiers: **strong** (5/5), **moderate** (>=4 with placebo), **suggestive** (>=3 with magnitude or placebo), **weak**, **non-interpretable** (poor pre-fit). A *considerable* effect is strong/moderate/suggestive.", "",
  "### Tier distribution", "", mdtab(tier_counts), "",
  paste0("**Considerable effects: ", n_cons, " of ", nrow(master), "** event-outcomes; ", n_neg, " negative / ", n_cons - n_neg, " positive."), "",
  "![cross_event_evidence_tiers.png](figures/cross_event_evidence_tiers.png)", "",
  "![cross_event_considerable_effects.png](figures/cross_event_considerable_effects.png)", "",
  "## Groupings (considerable effects only)", "",
  "### By timing in mandate (removal in last year vs earlier)", "", mdtab(by_timing), "",
  "### By sample (main vs extended)", "", mdtab(by_main), "",
  "### By channel", "", mdtab(by_channel), "",
  "## Master table (all event-outcomes)", "", mdtab(master_tab), "",
  "## Methodological note", "",
  "Placebo-based inference in synthetic control is discrete and low-resolution when the donor pool is small (the finest attainable p is ~1/N). We therefore do not rely on a single p-value threshold; we combine the placebo rank with pre-treatment fit, substantive magnitude, persistence, and leave-one-out robustness. Effects with a placebo p slightly above conventional thresholds but a high rank, good pre-fit, substantive magnitude and persistence are interpreted as suggestive evidence rather than conventional statistical significance."
)
readr::write_lines(lines, file.path(sdir, "cross_event_summary.md"))
message("=== cross-event summary: ", n_ev, " events, ", nrow(master), " event-outcomes, ", n_cons, " considerable ===")
