# ── Event-study engine: in-space placebo (arg: event_id) ──────────────────────
# Treats each eligible donor as pseudo-treated at the same dates and fits the
# ASCM, for every qualifying outcome (monthly + bimonthly). Produces the placebo
# gap paths, the placebo RMSPE-ratio distribution, and the treated unit's
# rank-based p-values. Writes under output/<id>/scm/placebo_inspace/ and the
# placebo rank table under report/tables/.
#
# Usage: Rscript code/02_analysis/02b_run_event_placebo_inspace.R <EVENT_ID>

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

split_csv <- function(x) { x <- as.character(x); if (is.na(x) || !nzchar(x)) character(0) else strsplit(x, ",")[[1]] }
qual_monthly <- split_csv(meta$qualifying_monthly_outcomes[[1]])
qual_bim     <- split_csv(meta$qualifying_bimonthly_outcomes[[1]])
cov_vars     <- split_csv(meta$covariate_set[[1]])

covariates_raw <- readr::read_csv(file.path(d$data, paste0(event_id, "_covariates.csv")), show_col_types = FALSE)
main_donor_states <- covariates_raw |> dplyr::filter(.data$donor_pool_main) |> dplyr::pull(.data$state_abbrev) |> sort()
covariate_data <- if (identical(scm_predictors, "lags_only")) {
  covariates_raw |> dplyr::select(dplyr::all_of("state_abbrev"))
} else {
  covariates_raw |> dplyr::select(dplyr::all_of(c("state_abbrev", cov_vars)))
}

monthly_panel <- readr::read_csv(file.path(d$data, paste0(event_id, "_monthly_panel.csv")), show_col_types = FALSE) |>
  dplyr::mutate(period_date = as.Date(.data$period_date))
bim_path <- file.path(d$data, paste0(event_id, "_bimonthly_panel.csv"))
bimonthly_panel <- if (file.exists(bim_path)) readr::read_csv(bim_path, show_col_types = FALSE) |>
  dplyr::mutate(period_date = as.Date(.data$period_date)) else NULL

scm_summary <- readr::read_csv(file.path(d$scm, paste0(event_id, "_scm_summary.csv")), show_col_types = FALSE)

specs <- c(
  lapply(qual_monthly, function(k) list(panel = monthly_panel, key = k, family = "monthly",
                                        min_pre = spec$monthly$pre_floor, channel = outcome_catalog[[k]]$channel)),
  if (!is.null(bimonthly_panel)) lapply(qual_bim, function(k) list(panel = bimonthly_panel, key = k,
                                        family = "bimonthly", min_pre = spec$bimonthly$pre_floor,
                                        channel = outcome_catalog[[k]]$channel)) else list()
)

placebo_dir <- file.path(d$scm, "placebo_inspace")
dir.create(placebo_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(d$tables, recursive = TRUE, showWarnings = FALSE)

message("=== in-space placebo ", event_id, ": ", length(main_donor_states), " donors x ", length(specs), " outcomes ===")
all_paths <- list(); all_rmspe <- list()
for (ps in main_donor_states) {
  for (sp in specs) {
    donor_pool <- setdiff(main_donor_states, ps)
    res <- tryCatch(fit_ascm_for_unit(sp$panel, sp$key, ps, donor_pool, covariate_data, sp$min_pre),
                    error = function(e) NULL)
    if (is.null(res)) next
    all_paths[[length(all_paths) + 1L]] <- res$path |>
      dplyr::transmute(pseudo_treated_state = ps, outcome = sp$key, channel_slug = sp$channel,
                       .data$period_date, .data$analysis_period, .data$augmented_gap)
    all_rmspe[[length(all_rmspe) + 1L]] <- res$rmspe |>
      dplyr::mutate(pseudo_treated_state = ps, outcome = sp$key, channel_slug = sp$channel)
  }
}
placebo_paths   <- dplyr::bind_rows(all_paths)
placebo_summary <- dplyr::bind_rows(all_rmspe)
readr::write_csv(placebo_paths,   file.path(placebo_dir, "placebo_paths.csv"),   na = "")
readr::write_csv(placebo_summary, file.path(placebo_dir, "placebo_summary.csv"), na = "")

# Treated unit's rank-based p-values vs the donor placebo distribution.
rr <- scm_summary |>
  dplyr::filter(.data$status == "estimated") |>
  dplyr::transmute(.data$outcome,
                   rr_ratio = .data$augmented_rmspe_post / .data$augmented_rmspe_pre,
                   rr_abs_gap = abs(.data$augmented_mean_gap_post))
placebo_rank <- purrr::map_dfr(seq_len(nrow(rr)), function(i) {
  row <- rr[i, ]
  p   <- placebo_summary |> dplyr::filter(.data$outcome == row$outcome)
  n   <- nrow(p)
  ch  <- outcome_catalog[[row$outcome]]$channel
  tibble::tibble(
    outcome = row$outcome, short_label = outcome_catalog[[row$outcome]]$short, channel_slug = ch,
    post_pre_rmspe_ratio = row$rr_ratio, donor_placebo_count = n,
    ratio_p_value   = if (n > 0) mean(p$post_pre_ratio    >= row$rr_ratio,   na.rm = TRUE) else NA_real_,
    abs_gap_p_value = if (n > 0) mean(p$mean_abs_gap_post  >= row$rr_abs_gap, na.rm = TRUE) else NA_real_
  )
})
readr::write_csv(placebo_rank, file.path(d$tables, "placebo_rank_actual_rr.csv"), na = "")
message("  placebo models: ", nrow(placebo_summary), "; outcomes ranked: ", nrow(placebo_rank))
