# ── Nova Estrategia v2 engine: in-space placebo (arg: event_id) ──────────────
# Classic Abadie-Diamond-Hainmueller (2010) in-space placebo test: refits the
# AugSCM treating each donor in main_donor_states as if it were the treated
# unit (donor pool = the other donors, real treated state excluded), then
# ranks the real treated unit's post/pre RMSPE ratio within that placebo
# distribution. This is the literature-standard significance test for SCM,
# complementing (not replacing) the LOO donor-exclusion robustness check
# already produced by 02_run_event_scm_v2.R.
#
# Usage: Rscript code/03_nova_estrategia/02b_run_event_placebo_inspace_v2.R <EVENT_ID>

source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))
source(file.path("code", "03_nova_estrategia", "00_nova_estrategia_config.R"))
source(file.path("code", "03_nova_estrategia", "00b_augscm_core.R"))

extra_packages <- c("tidyr", "quadprog")
missing_extra <- extra_packages[!vapply(extra_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_extra) > 0) stop("Missing packages: ", paste(missing_extra, collapse = ", "))
invisible(lapply(extra_packages, library, character.only = TRUE))

POST_START <- 5L  # Opcao B (k=6): first clean post-treatment reading

event_id      <- resolve_event_id()
event_spec    <- get_event_spec(event_id)
treated_state <- event_spec$treated_state[[1]]
include_formal_hiring <- event_spec$include_formal_hiring[[1]]

d <- ensure_event_dirs_v2(event_id)
placebo_dir <- file.path(d$output, "placebo_inspace")
dir.create(placebo_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(d$tables, recursive = TRUE, showWarnings = FALSE)

covariates <- readr::read_csv(file.path(d$data, paste0(event_id, "_covariates.csv")), show_col_types = FALSE)
monthly_panel <- readr::read_csv(file.path(d$data, paste0(event_id, "_monthly_panel.csv")), show_col_types = FALSE) |>
  dplyr::mutate(period_date = as.Date(.data$period_date))

main_donor_states <- covariates |>
  dplyr::filter(.data$donor_pool_main) |>
  dplyr::pull(.data$state_abbrev) |>
  sort()

admin_cols <- c("state_abbrev", "donor_pool_main", "excluded_from_main_donor_pool",
                "donor_pool_exclusion_reason")
covariate_vars <- setdiff(names(covariates), admin_cols)
covariate_data <- covariates |> dplyr::select(dplyr::all_of(c("state_abbrev", covariate_vars)))

outcome_cols <- get_outcome_list(include_formal_hiring)

rmspe_split <- function(path) {
  pre  <- path$augmented_gap[path$event_time <  0L]
  post <- path$augmented_gap[path$event_time >= POST_START]
  pre  <- pre[is.finite(pre)]; post <- post[is.finite(post)]
  rmspe_pre  <- if (length(pre)  > 0) sqrt(mean(pre^2))  else NA_real_
  rmspe_post <- if (length(post) > 0) sqrt(mean(post^2)) else NA_real_
  tibble::tibble(rmspe_pre = rmspe_pre, rmspe_post = rmspe_post,
                 post_pre_ratio = rmspe_post / rmspe_pre)
}

placebo_rank_rows <- purrr::map_dfr(outcome_cols, function(outcome) {
  message("  In-space placebo: ", outcome, " (", length(main_donor_states), " donors)")
  slug <- make_slug(outcome)

  # Real treated unit's own ratio, from the already-fitted main path.
  treated_path_f <- file.path(d$monthly, paste0(slug, "_path.csv"))
  if (!file.exists(treated_path_f)) {
    message("    Skipped: no main path for ", outcome, " (run 02_run_event_scm_v2.R first)")
    return(NULL)
  }
  treated_path <- readr::read_csv(treated_path_f, show_col_types = FALSE)
  treated_rmspe <- rmspe_split(treated_path)

  fits <- purrr::map(main_donor_states, function(ps) {
    donor_pool <- setdiff(main_donor_states, ps)
    res <- tryCatch(
      fit_augscm(monthly_panel, outcome, "event_time", monthly_blocks,
                 unit = ps, candidate_pool = donor_pool),
      error = function(e) NULL
    )
    if (is.null(res) || !identical(res$status, "estimated")) return(NULL)
    list(pseudo_treated_state = ps, path = res$path)
  })
  fits <- purrr::compact(fits)

  placebo_paths <- purrr::map_dfr(fits, function(f) {
    f$path |> dplyr::transmute(pseudo_treated_state = f$pseudo_treated_state,
                                .data$period_date, .data$event_time, .data$augmented_gap)
  })
  placebo_rows <- purrr::map_dfr(fits, function(f) {
    rm <- rmspe_split(f$path)
    if (!is.finite(rm$post_pre_ratio)) return(NULL)
    dplyr::bind_cols(tibble::tibble(pseudo_treated_state = f$pseudo_treated_state), rm)
  })

  readr::write_csv(placebo_paths, file.path(placebo_dir, paste0(slug, "_inspace_paths.csv")), na = "")
  readr::write_csv(placebo_rows,  file.path(placebo_dir, paste0(slug, "_inspace_summary.csv")), na = "")

  n_placebo <- nrow(placebo_rows)
  if (n_placebo == 0 || !is.finite(treated_rmspe$post_pre_ratio)) {
    return(tibble::tibble(outcome = outcome, treated_ratio = treated_rmspe$post_pre_ratio,
                           n_placebo = n_placebo, rank = NA_integer_, n_units = NA_integer_,
                           classic_p = NA_real_))
  }

  all_ratios <- c(treated_rmspe$post_pre_ratio, placebo_rows$post_pre_ratio)
  rank <- sum(all_ratios >= treated_rmspe$post_pre_ratio - 1e-12, na.rm = TRUE)
  n_units <- sum(is.finite(all_ratios))
  tibble::tibble(
    outcome = outcome, treated_ratio = treated_rmspe$post_pre_ratio,
    n_placebo = n_placebo, rank = rank, n_units = n_units,
    classic_p = rank / n_units
  )
})

readr::write_csv(placebo_rank_rows, file.path(d$tables, "placebo_rank_inspace.csv"), na = "")
message(event_id, ": in-space placebo complete. ")
print(placebo_rank_rows)
