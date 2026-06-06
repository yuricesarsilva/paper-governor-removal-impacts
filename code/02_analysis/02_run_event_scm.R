# ── Event-study engine: run Augmented SCM (arg: event_id) ─────────────────────
# Reads the built panels + covariates + metadata for one event and fits the
# Augmented SCM for each qualifying outcome (monthly and, in Regime B, bimonthly),
# plus the leave-one-out donor placebo. Writes results under output/<id>/scm/.
#
# Usage: Rscript code/02_analysis/02_run_event_scm.R <EVENT_ID>

source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))
source(file.path("code", "02_analysis", "00_event_config.R"))
source(file.path("code", "02_analysis", "00b_engine_helpers.R"))

extra <- c("tidyr", "quadprog")
miss  <- extra[!vapply(extra, requireNamespace, logical(1), quietly = TRUE)]
if (length(miss)) stop("Missing packages: ", paste(miss, collapse = ", "))
invisible(lapply(extra, library, character.only = TRUE))

event_id <- resolve_event_id()
d <- event_dirs(event_id)
meta <- readr::read_csv(file.path(d$data, paste0(event_id, "_event_metadata.csv")), show_col_types = FALSE) |> dplyr::slice(1)
treated_state <- meta$state_abbrev[[1]]
regime        <- meta$regime[[1]]

split_csv <- function(x) { x <- as.character(x); if (is.na(x) || !nzchar(x)) character(0) else strsplit(x, ",")[[1]] }
qual_monthly <- split_csv(meta$qualifying_monthly_outcomes[[1]])
qual_bim     <- split_csv(meta$qualifying_bimonthly_outcomes[[1]])
cov_vars     <- split_csv(meta$covariate_set[[1]])

covariates_raw <- readr::read_csv(file.path(d$data, paste0(event_id, "_covariates.csv")), show_col_types = FALSE)
main_donor_states <- covariates_raw |> dplyr::filter(.data$donor_pool_main) |> dplyr::pull(.data$state_abbrev) |> sort()
covariate_data <- covariates_raw |> dplyr::select(dplyr::all_of(c("state_abbrev", cov_vars)))

monthly_panel <- readr::read_csv(file.path(d$data, paste0(event_id, "_monthly_panel.csv")), show_col_types = FALSE) |>
  dplyr::mutate(period_date = as.Date(.data$period_date))
bim_path <- file.path(d$data, paste0(event_id, "_bimonthly_panel.csv"))
bimonthly_panel <- if (file.exists(bim_path)) readr::read_csv(bim_path, show_col_types = FALSE) |>
  dplyr::mutate(period_date = as.Date(.data$period_date)) else NULL

jobs <- c(
  lapply(qual_monthly, function(k) list(panel = monthly_panel, key = k, family = "monthly",
                                         min_pre = spec$monthly$pre_floor)),
  if (!is.null(bimonthly_panel)) lapply(qual_bim, function(k) list(panel = bimonthly_panel, key = k,
                                         family = "bimonthly", min_pre = spec$bimonthly$pre_floor)) else list()
)

summary_tbl <- purrr::map_dfr(jobs, function(j) {
  out_dir <- file.path(d$scm, j$family, "sa")
  fit_augmented_scm(j$panel, j$key, treated_state, main_donor_states, covariate_data,
                    j$min_pre, j$family, "sa", out_dir)
})
readr::write_csv(summary_tbl, file.path(d$scm, paste0(event_id, "_scm_summary.csv")), na = "")

# Leave-one-out donor placebo (for estimated outcomes).
loo_dir <- file.path(d$scm, "placebo_loo")
dir.create(loo_dir, recursive = TRUE, showWarnings = FALSE)
purrr::walk(jobs, function(j) {
  loo <- run_loo_placebo(j$panel, j$key, treated_state, main_donor_states, covariate_data, j$min_pre)
  if (!is.null(loo) && nrow(loo) > 0)
    readr::write_csv(loo, file.path(loo_dir, paste0(make_slug(j$key), "_loo_placebo.csv")), na = "")
})

est <- summary_tbl |> dplyr::filter(.data$status == "estimated")
message("=== SCM ", event_id, " (", regime, ") ===")
message("  estimated: ", nrow(est), " / ", nrow(summary_tbl), " outcomes")
if (nrow(est)) for (i in seq_len(nrow(est)))
  message(sprintf("    %-22s post gap = %8.3f  (RMSPE pre %.3f -> post %.3f, donors %d)",
          est$outcome[i], est$augmented_mean_gap_post[i], est$augmented_rmspe_pre[i],
          est$augmented_rmspe_post[i], est$donor_count[i]))
