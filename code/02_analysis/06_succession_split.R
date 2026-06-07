# ── Pooled effect split by succession type ────────────────────────────────────
# The institutional-continuity thesis is testable: if removals matter only when
# they bring a CHANGE of governing side, the effect should concentrate in events
# where the opposition (the electoral runner-up) takes over, and be absent where
# the same coalition continues (the vice assumes, or the governor returns).
#
# Groups (from data/raw/governor_removal_events.csv succession_type / vice / return):
#   continuity  : vice assumed, or the removed governor returned within weeks
#   change      : second-placed / opposition assumed (electoral cassations)
#   newelection : indirect or supplementary election (winning side ambiguous)
#   intervention: federal intervention (interventor)
#
# Inference is events-as-units (per-event mean post gap pooled within group),
# plus a two-sample test of change vs continuity. Small group n (esp. change with
# labor data) -> read as suggestive. Writes output/_summary/succession_split_results.csv.
#
# Usage: Rscript code/02_analysis/06_succession_split.R

source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))
source(file.path("code", "02_analysis", "00_event_config.R"))
source(file.path("code", "02_analysis", "00b_engine_helpers.R"))
suppressMessages(library(dplyr))

succession_group <- c(
  RJ_2014_01 = "continuity", RJ_2020_01 = "continuity", TO_2021_01 = "continuity",
  SC_2020_01 = "continuity", SC_2021_01 = "continuity", AL_2022_01 = "continuity",
  DF_2010_01 = "continuity",
  PI_2001_01 = "change", RR_2004_01 = "change", PB_2009_01 = "change", MA_2009_01 = "change",
  TO_2009_01 = "newelection", TO_2018_01 = "newelection", AM_2017_01 = "newelection",
  RR_2018_01 = "intervention"
)

rows <- list()
for (eid in analysis_events) {
  sf <- file.path(event_dirs(eid)$scm, paste0(eid, "_scm_summary.csv"))
  if (!file.exists(sf)) next
  sm <- readr::read_csv(sf, show_col_types = FALSE) |> dplyr::filter(.data$status == "estimated")
  for (i in seq_len(nrow(sm))) {
    o <- sm$outcome[i]
    rows[[length(rows) + 1L]] <- tibble::tibble(
      event_id = eid, group = unname(succession_group[eid]),
      short = outcome_catalog[[o]]$short,
      is_log = identical(outcome_catalog[[o]]$transform, "log"),
      gap = sm$augmented_mean_gap_post[i])
  }
}
d <- dplyr::bind_rows(rows)
pct <- function(x, lg) if (lg) 100 * (exp(x) - 1) else x

by_group <- d |> dplyr::filter(.data$group %in% c("continuity", "change", "newelection")) |>
  dplyr::group_by(.data$short, .data$group) |>
  dplyr::summarise(
    n = dplyr::n(), is_log = .data$is_log[1],
    mean_gap = mean(.data$gap, na.rm = TRUE), n_neg = sum(.data$gap < 0),
    t_p = tryCatch(stats::t.test(.data$gap)$p.value, error = function(e) NA_real_), .groups = "drop") |>
  dplyr::mutate(avg_effect = ifelse(.data$is_log, sprintf("%+.1f%%", pct(.data$mean_gap, TRUE)),
                                    sprintf("%+.2f", .data$mean_gap)),
                t_p = round(.data$t_p, 3)) |>
  dplyr::select("short", "group", "n", "avg_effect", "n_neg", "t_p")

# change vs continuity two-sample test per outcome
contrast <- purrr::map_dfr(unique(d$short), function(s) {
  ds <- d |> dplyr::filter(.data$short == s, .data$group %in% c("continuity", "change"))
  if (dplyr::n_distinct(ds$group) < 2) return(NULL)
  p <- tryCatch(stats::t.test(gap ~ group, ds)$p.value, error = function(e) NA_real_)
  tibble::tibble(short = s, change_vs_continuity_p = round(p, 3))
})

readr::write_csv(by_group, file.path(summary_root(), "succession_split_results.csv"), na = "")
readr::write_csv(contrast, file.path(summary_root(), "succession_split_contrast.csv"), na = "")

cat("=== Mean post effect by succession group ===\n")
print(as.data.frame(by_group), row.names = FALSE)
cat("\n=== change vs continuity (two-sample t) ===\n")
print(as.data.frame(contrast), row.names = FALSE)
message("Saved succession split under output/_summary/.")
