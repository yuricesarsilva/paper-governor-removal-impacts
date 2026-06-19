# ── Nova Estrategia v2 engine: master runner ──────────────────────────────────
# Runs the full pipeline (build -> SCM -> report figures -> report) for each
# event, then the cross-event summary. Each stage runs in an isolated Rscript
# subprocess so events do not interfere (mirrors code/02_analysis/run_analysis.R).
# Writes only under output_v2/ -- output/, archive/pilots/, and code/02_analysis/
# are never touched.
#
# Usage:
#   Rscript code/03_nova_estrategia/04_run_all_events_v2.R                    # all 15 events
#   Rscript code/03_nova_estrategia/04_run_all_events_v2.R RR_2018_01 PB_2009_01  # a subset

source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))
source(file.path("code", "03_nova_estrategia", "00_nova_estrategia_config.R"))

args <- commandArgs(trailingOnly = TRUE)
ids <- if (length(args) == 0) nova_estrategia_events$event_id else args

rscript <- find_rscript()
stages <- c(
  "01_build_event_panel_v2.R",
  "02_run_event_scm_v2.R",
  "02b_run_event_placebo_inspace_v2.R",
  "03_make_event_report_v2.R",
  "03b_make_event_report_figures_v2.R"
)
stage_path <- function(s) file.path("code", "03_nova_estrategia", s)

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

message("\n===== per-event run summary (nova estrategia v2) =====")
for (i in seq_len(nrow(results)))
  message(sprintf("  %-12s %s", results$event_id[i], if (isTRUE(results$ok[i])) "OK" else "FAILED"))

if (any(results$ok)) {
  message("\n>>> cross-event summary (v2)")
  code <- system2(rscript, shQuote(stage_path("05_make_cross_event_summary_v2.R")), stdout = "", stderr = "")
  if (!identical(code, 0L)) message("!! cross-event summary v2 failed (exit ", code, ")")
}
message("\nDone.")
