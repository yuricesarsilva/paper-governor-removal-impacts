# ── Event-study engine: master runner ─────────────────────────────────────────
# Runs the full pipeline (build -> SCM -> in-space placebo -> report figures ->
# report) for each event, then the cross-event summary. Each stage runs in an
# isolated Rscript subprocess so events do not interfere.
#
# Usage:
#   Rscript code/02_analysis/run_analysis.R              # all events in analysis_events
#   Rscript code/02_analysis/run_analysis.R PI_2001_01 RJ_2020_01   # a subset
#   Rscript code/02_analysis/run_analysis.R --no-summary <ids...>   # skip cross-event summary

source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))
source(file.path("code", "02_analysis", "00_event_config.R"))

args <- commandArgs(trailingOnly = TRUE)
do_summary <- !("--no-summary" %in% args)
ids <- setdiff(args, "--no-summary")
if (length(ids) == 0) ids <- analysis_events

rscript <- find_rscript()
stages <- c(
  "01_build_event_panel.R",
  "02_run_event_scm.R",
  "02b_run_event_placebo_inspace.R",
  "03b_make_event_report_figures.R",
  "03_make_event_report.R"
)
stage_path <- function(s) file.path("code", "02_analysis", s)

run_stage <- function(stage, event_id) {
  message(">>> ", event_id, " :: ", stage)
  code <- system2(rscript, c(shQuote(stage_path(stage)), event_id), stdout = "", stderr = "")
  if (!identical(code, 0L)) stop("Stage failed (", stage, ", ", event_id, "): exit ", code)
}

results <- tibble::tibble(event_id = ids, ok = NA, error = NA_character_)
for (i in seq_along(ids)) {
  eid <- ids[i]
  message("\n========================= ", eid, " =========================")
  res <- tryCatch({ for (s in stages) run_stage(s, eid); TRUE },
                  error = function(e) { message("!! ", conditionMessage(e)); FALSE })
  results$ok[i] <- res
  if (!res) results$error[i] <- "stage failure (see log)"
}

message("\n===== per-event run summary =====")
for (i in seq_len(nrow(results)))
  message(sprintf("  %-12s %s", results$event_id[i], if (isTRUE(results$ok[i])) "OK" else "FAILED"))

if (do_summary && any(results$ok)) {
  message("\n>>> cross-event summary")
  code <- system2(rscript, shQuote(stage_path("04_make_cross_event_summary.R")), stdout = "", stderr = "")
  if (!identical(code, 0L)) message("!! cross-event summary failed (exit ", code, ")")
}
message("\nDone.")
