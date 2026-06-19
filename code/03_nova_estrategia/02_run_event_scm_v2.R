source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))
source(file.path("code", "03_nova_estrategia", "00_nova_estrategia_config.R"))
source(file.path("code", "03_nova_estrategia", "00b_augscm_core.R"))

extra_packages <- c("tidyr", "quadprog")
missing_extra <- extra_packages[!vapply(extra_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_extra) > 0) stop("Missing packages: ", paste(missing_extra, collapse = ", "))
invisible(lapply(extra_packages, library, character.only = TRUE))

event_id      <- resolve_event_id()
event_spec    <- get_event_spec(event_id)
treated_state <- event_spec$treated_state[[1]]
include_formal_hiring <- event_spec$include_formal_hiring[[1]]

d <- ensure_event_dirs_v2(event_id)

# ── Load panels (written by 01_build_event_panel_v2.R) ────────────────────────
event <- readr::read_csv(
  file.path(d$data, paste0(event_id, "_event_metadata.csv")), show_col_types = FALSE
) |> dplyr::slice(1)

covariates <- readr::read_csv(
  file.path(d$data, paste0(event_id, "_covariates.csv")), show_col_types = FALSE
)

monthly_panel <- readr::read_csv(
  file.path(d$data, paste0(event_id, "_monthly_panel.csv")), show_col_types = FALSE
) |> dplyr::mutate(period_date = as.Date(.data$period_date))

main_donor_states <- covariates |>
  dplyr::filter(.data$donor_pool_main) |>
  dplyr::pull(.data$state_abbrev) |>
  sort()

# Covariate columns are read dynamically: the old engine's "confaz" regime
# events (e.g. PB_2009_01) have 6 CONFAZ/FPE/IOF columns; "siconfi" regime
# events (e.g. RR_2018_01) have 7 PNADc/SICONFI columns. Whatever is present
# (minus the donor-pool admin columns) is used as-is.
admin_cols <- c("state_abbrev", "donor_pool_main", "excluded_from_main_donor_pool",
                "donor_pool_exclusion_reason")
covariate_vars <- setdiff(names(covariates), admin_cols)

covariate_data <- covariates |>
  dplyr::select(dplyr::all_of(c("state_abbrev", covariate_vars)))

# ── Core SCM functions: standardize_rows, standardize_cols_by_train,
# solve_scm_weights, fit_ridge, predict_ridge, loocv_lambda,
# build_block_predictor_matrix, fit_augscm -- see 00b_augscm_core.R ──────────

# ── Window ATT computation ────────────────────────────────────────────────────
compute_window_att <- function(path, etime_col, windows) {
  purrr::map_dfr(windows, function(w) {
    gaps <- path |>
      dplyr::filter(
        .data[[etime_col]] >= w$start,
        .data[[etime_col]] <= w$end,
        is.finite(.data$augmented_gap)
      ) |>
      dplyr::pull(.data$augmented_gap)

    if (length(gaps) == 0) {
      return(tibble::tibble(window = w$name, n_periods = 0L,
                            att_mean = NA_real_, sign_consistent = NA))
    }
    att_mean <- mean(gaps)
    frac_same_sign <- if (is.finite(att_mean) && att_mean != 0) {
      mean(sign(gaps) == sign(att_mean))
    } else NA_real_

    tibble::tibble(
      window          = w$name,
      n_periods       = length(gaps),
      att_mean        = att_mean,
      sign_consistent = frac_same_sign >= 0.5
    )
  })
}

# ── LOO placebo ───────────────────────────────────────────────────────────────
run_loo_placebo <- function(data, outcome, etime_col, donor_states, blocks) {
  if (length(donor_states) < 3) return(NULL)

  states_needed <- c(treated_state, donor_states)
  wide_full <- data |>
    dplyr::filter(.data$state_abbrev %in% states_needed) |>
    dplyr::select("period_date", "state_abbrev", dplyr::all_of(etime_col),
                  value = dplyr::all_of(outcome)) |>
    tidyr::pivot_wider(names_from = "state_abbrev", values_from = "value") |>
    dplyr::arrange(dplyr::all_of(etime_col)) |>
    dplyr::filter(stats::complete.cases(dplyr::across(dplyr::all_of(states_needed))))

  purrr::map_dfr(donor_states, function(dropped) {
    loo_donors <- setdiff(donor_states, dropped)
    if (length(loo_donors) < 2) return(NULL)

    pm <- tryCatch(
      build_block_predictor_matrix(data, outcome, etime_col, loo_donors, blocks),
      error = function(e) NULL
    )
    if (is.null(pm)) return(NULL)
    if (anyNA(pm)) pm[!is.finite(pm)] <- 0

    scaled <- standardize_rows(pm)
    x1 <- scaled$x[, treated_state, drop = FALSE]
    x0 <- scaled$x[, loo_donors,    drop = FALSE]
    w  <- solve_scm_weights(x1, x0)
    names(w) <- loo_donors

    loo_states <- c(treated_state, loo_donors)
    wide_loo <- wide_full |>
      dplyr::filter(stats::complete.cases(dplyr::across(dplyr::all_of(loo_states))))

    synthetic <- as.matrix(wide_loo[, loo_donors, drop = FALSE]) %*% w
    gap       <- wide_loo[[treated_state]] - as.numeric(synthetic)

    tibble::tibble(
      dropped_donor = dropped,
      period_date   = wide_loo$period_date,
      !!etime_col  := wide_loo[[etime_col]],
      loo_gap       = gap
    )
  })
}

compute_loo_window_frac <- function(loo, etime_col, windows, main_att_by_window) {
  if (is.null(loo) || nrow(loo) == 0) return(NULL)
  purrr::map_dfr(windows, function(w) {
    main_att <- main_att_by_window |>
      dplyr::filter(.data$window == w$name) |>
      dplyr::pull(.data$att_mean)
    if (length(main_att) == 0 || !is.finite(main_att)) {
      return(tibble::tibble(window = w$name, loo_frac = NA_real_, n_loo = 0L))
    }
    loo_atts <- loo |>
      dplyr::filter(
        .data[[etime_col]] >= w$start,
        .data[[etime_col]] <= w$end
      ) |>
      dplyr::group_by(.data$dropped_donor) |>
      dplyr::summarise(loo_att = mean(.data$loo_gap, na.rm = TRUE), .groups = "drop") |>
      dplyr::pull(.data$loo_att)
    loo_frac <- mean(sign(loo_atts[is.finite(loo_atts)]) == sign(main_att), na.rm = TRUE)
    tibble::tibble(window = w$name, loo_frac = loo_frac, n_loo = length(loo_atts))
  })
}

# ── Outcome specs (3 or 2 depending on the event) ─────────────────────────────
outcome_cols <- get_outcome_list(include_formal_hiring)
specs <- purrr::map(outcome_cols, function(o) list(outcome = o, etime_col = "event_time", is_main = TRUE))

summary_rows <- purrr::map_dfr(specs, function(spec) {
  message("  Estimating: ", spec$outcome)

  result <- fit_augscm(
    data      = monthly_panel,
    outcome   = spec$outcome,
    etime_col = spec$etime_col,
    blocks    = monthly_blocks
  )

  if (result$status != "estimated") {
    message("    Skipped: ", result$skip_reason)
    return(tibble::tibble(
      outcome    = spec$outcome,
      is_main    = spec$is_main,
      status     = "skipped",
      skip_reason = result$skip_reason
    ))
  }

  slug <- make_slug(spec$outcome)
  readr::write_csv(result$path,    file.path(d$monthly, paste0(slug, "_path.csv")),    na = "")
  readr::write_csv(result$weights, file.path(d$monthly, paste0(slug, "_weights.csv")), na = "")

  att_tbl <- compute_window_att(result$path, spec$etime_col, monthly_windows)

  loo <- run_loo_placebo(monthly_panel, spec$outcome, spec$etime_col,
                         result$donor_states, monthly_blocks)
  loo_frac_tbl <- NULL
  if (!is.null(loo) && nrow(loo) > 0) {
    readr::write_csv(loo, file.path(d$placebo_loo, paste0(slug, "_loo.csv")), na = "")
    loo_frac_tbl <- compute_loo_window_frac(loo, spec$etime_col, monthly_windows, att_tbl)
  }

  rmspe_pre <- result$path |>
    dplyr::filter(.data$event_time < 0, is.finite(.data$augmented_gap)) |>
    dplyr::summarise(rmspe = sqrt(mean(.data$augmented_gap^2))) |>
    dplyr::pull(.data$rmspe)

  base_row <- tibble::tibble(
    outcome     = spec$outcome,
    is_main     = spec$is_main,
    status      = "estimated",
    skip_reason = NA_character_,
    donor_count = length(result$donor_states),
    rmspe_pre   = rmspe_pre
  )

  att_wide <- att_tbl |>
    dplyr::select("window", "att_mean", "n_periods", "sign_consistent") |>
    tidyr::pivot_wider(
      names_from  = "window",
      values_from = c("att_mean", "n_periods", "sign_consistent")
    )

  loo_wide <- if (!is.null(loo_frac_tbl)) {
    loo_frac_tbl |>
      dplyr::select("window", "loo_frac") |>
      tidyr::pivot_wider(names_from = "window", values_from = "loo_frac",
                         names_prefix = "loo_frac_")
  } else tibble::tibble()

  dplyr::bind_cols(base_row, att_wide, loo_wide)
})

readr::write_csv(summary_rows, file.path(d$output, paste0(event_id, "_scm_summary.csv")), na = "")
message(event_id, ": SCM v2 complete (k=6, ", length(outcome_cols), " outcomes",
        if (!include_formal_hiring) " — sem CAGED" else "", ").")
print(summary_rows |>
  dplyr::filter(.data$status == "estimated") |>
  dplyr::select("outcome", "donor_count", "rmspe_pre",
                dplyr::starts_with("att_mean")))
