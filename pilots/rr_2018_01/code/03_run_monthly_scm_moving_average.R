source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

if (!requireNamespace("quadprog", quietly = TRUE)) {
  stop("Missing required package: quadprog")
}

pilot_id <- "rr_2018_01"
treated_state <- "RR"
pilot_root <- file.path(root_dir, "pilots", pilot_id)

monthly_panel_path <- file.path(
  pilot_root,
  "data",
  "rr_2018_01_monthly_panel.csv"
)

output_dir <- file.path(pilot_root, "output", "scm_monthly_moving_average")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

panel <- readr::read_csv(monthly_panel_path, show_col_types = FALSE) |>
  dplyr::mutate(
    period_date = as.Date(period_date),
    state_abbrev = as.character(state_abbrev),
    treated_unit = as.logical(treated_unit),
    donor_pool_main = as.logical(donor_pool_main),
    pnadc_predictor_valid = as.logical(pnadc_predictor_valid)
  ) |>
  dplyr::filter(monthly_main_window) |>
  dplyr::arrange(state_abbrev, period_date)

trailing_partial_mean <- function(x, window) {
  purrr::map_dbl(
    seq_along(x),
    function(i) {
      start_i <- max(1, i - window + 1)
      mean(x[start_i:i], na.rm = TRUE)
    }
  )
}

base_outcomes <- c(
  "formal_hiring_balance",
  "retail_volume_index",
  "services_volume_index"
)

for (window in c(3, 6)) {
  panel <- panel |>
    dplyr::group_by(state_abbrev) |>
    dplyr::arrange(period_date, .by_group = TRUE) |>
    dplyr::mutate(
      dplyr::across(
        dplyr::all_of(base_outcomes),
        ~trailing_partial_mean(.x, window),
        .names = "{.col}_ma{window}"
      )
    ) |>
    dplyr::ungroup()
}

make_slug <- function(x) {
  x |>
    stringr::str_replace_all("[^A-Za-z0-9]+", "_") |>
    stringr::str_replace_all("_+$", "") |>
    tolower()
}

standardize_predictors <- function(x) {
  row_means <- rowMeans(x, na.rm = TRUE)
  row_sds <- apply(x, 1, stats::sd, na.rm = TRUE)
  keep_rows <- is.finite(row_sds) & row_sds > 0

  x_standardized <- sweep(x[keep_rows, , drop = FALSE], 1, row_means[keep_rows], "-")
  x_standardized <- sweep(x_standardized, 1, row_sds[keep_rows], "/")

  list(
    x = x_standardized,
    keep_rows = keep_rows
  )
}

solve_scm_weights <- function(x1, x0) {
  dmat <- 2 * crossprod(x0) + diag(1e-8, ncol(x0))
  dvec <- 2 * as.numeric(crossprod(x0, x1))
  amat <- cbind(rep(1, ncol(x0)), diag(ncol(x0)))
  bvec <- c(1, rep(0, ncol(x0)))

  solution <- quadprog::solve.QP(
    Dmat = dmat,
    dvec = dvec,
    Amat = amat,
    bvec = bvec,
    meq = 1
  )

  weights <- pmax(solution$solution, 0)
  weights / sum(weights)
}

build_predictor_matrix <- function(data, outcome, covariates, treated_state_code, donor_states) {
  pre_data <- data |>
    dplyr::filter(analysis_period == "pre")

  states <- c(treated_state_code, donor_states)

  outcome_predictors <- pre_data |>
    dplyr::filter(state_abbrev %in% states) |>
    dplyr::select(state_abbrev, period_date, value = dplyr::all_of(outcome)) |>
    tidyr::pivot_wider(names_from = state_abbrev, values_from = value) |>
    dplyr::arrange(period_date)

  outcome_matrix <- outcome_predictors |>
    dplyr::select(dplyr::all_of(states)) |>
    as.matrix()

  rownames(outcome_matrix) <- paste0("lag_", format(outcome_predictors$period_date, "%Y_%m"))

  economic_covariates <- setdiff(covariates, outcome)

  economic_matrix <- pre_data |>
    dplyr::filter(state_abbrev %in% states) |>
    dplyr::group_by(state_abbrev) |>
    dplyr::summarise(
      dplyr::across(dplyr::all_of(economic_covariates), ~mean(.x, na.rm = TRUE)),
      .groups = "drop"
    ) |>
    tidyr::pivot_longer(-state_abbrev, names_to = "predictor", values_to = "value") |>
    tidyr::pivot_wider(names_from = state_abbrev, values_from = value) |>
    dplyr::arrange(predictor)

  economic_matrix_values <- economic_matrix |>
    dplyr::select(dplyr::all_of(states)) |>
    as.matrix()

  rownames(economic_matrix_values) <- paste0("mean_", economic_matrix$predictor)

  pnadc_matrix <- pre_data |>
    dplyr::filter(
      state_abbrev %in% states,
      pnadc_predictor_valid
    ) |>
    dplyr::group_by(state_abbrev) |>
    dplyr::summarise(
      unemployment_rate_pnadc = mean(unemployment_rate_pnadc, na.rm = TRUE),
      formalization_rate_pnadc = mean(formalization_rate_pnadc, na.rm = TRUE),
      .groups = "drop"
    ) |>
    tidyr::pivot_longer(-state_abbrev, names_to = "predictor", values_to = "value") |>
    tidyr::pivot_wider(names_from = state_abbrev, values_from = value) |>
    dplyr::arrange(predictor)

  pnadc_matrix_values <- pnadc_matrix |>
    dplyr::select(dplyr::all_of(states)) |>
    as.matrix()

  rownames(pnadc_matrix_values) <- paste0("mean_", pnadc_matrix$predictor)

  predictor_matrix <- rbind(outcome_matrix, economic_matrix_values, pnadc_matrix_values)

  if (anyNA(predictor_matrix)) {
    stop("Missing values found in predictor matrix for outcome: ", outcome)
  }

  predictor_matrix
}

fit_scm <- function(data, outcome, covariates, treated_state_code, donor_states) {
  predictor_matrix <- build_predictor_matrix(
    data = data,
    outcome = outcome,
    covariates = covariates,
    treated_state_code = treated_state_code,
    donor_states = donor_states
  )

  standardized <- standardize_predictors(predictor_matrix)
  predictor_matrix_scaled <- standardized$x

  x1 <- predictor_matrix_scaled[, treated_state_code, drop = FALSE]
  x0 <- predictor_matrix_scaled[, donor_states, drop = FALSE]

  weights <- solve_scm_weights(x1 = x1, x0 = x0)
  names(weights) <- donor_states

  fit_data <- data |>
    dplyr::filter(state_abbrev %in% c(treated_state_code, donor_states)) |>
    dplyr::select(period_date, state_abbrev, analysis_period, value = dplyr::all_of(outcome))

  treated_path <- fit_data |>
    dplyr::filter(state_abbrev == treated_state_code) |>
    dplyr::select(period_date, analysis_period, treated_value = value)

  donor_paths <- fit_data |>
    dplyr::filter(state_abbrev %in% donor_states) |>
    dplyr::select(period_date, state_abbrev, value) |>
    tidyr::pivot_wider(names_from = state_abbrev, values_from = value) |>
    dplyr::arrange(period_date)

  synthetic_values <- as.matrix(donor_paths[, donor_states, drop = FALSE]) %*% weights

  path <- treated_path |>
    dplyr::left_join(
      tibble::tibble(
        period_date = donor_paths$period_date,
        synthetic_value = as.numeric(synthetic_values)
      ),
      by = "period_date"
    ) |>
    dplyr::mutate(
      gap = treated_value - synthetic_value,
      outcome = outcome,
      treated_state = treated_state_code
    )

  weights_table <- tibble::tibble(
    outcome = outcome,
    donor_state = names(weights),
    weight = as.numeric(weights)
  ) |>
    dplyr::arrange(dplyr::desc(weight), donor_state)

  rmspe <- path |>
    dplyr::group_by(analysis_period) |>
    dplyr::summarise(
      rmspe = sqrt(mean(gap^2, na.rm = TRUE)),
      mean_gap = mean(gap, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      outcome = outcome,
      treated_state = treated_state_code
    )

  list(
    path = path,
    weights = weights_table,
    rmspe = rmspe
  )
}

run_one_smoothed_outcome <- function(base_outcome, window) {
  suffix <- paste0("_ma", window)
  outcome <- paste0(base_outcome, suffix)
  covariates <- paste0(base_outcomes, suffix)
  outcome_slug <- make_slug(outcome)

  donor_states <- panel |>
    dplyr::filter(donor_pool_main) |>
    dplyr::distinct(state_abbrev) |>
    dplyr::arrange(state_abbrev) |>
    dplyr::pull(state_abbrev)

  fit <- fit_scm(
    data = panel,
    outcome = outcome,
    covariates = covariates,
    treated_state_code = treated_state,
    donor_states = donor_states
  )

  rmspe_wide <- fit$rmspe |>
    dplyr::select(analysis_period, rmspe, mean_gap) |>
    tidyr::pivot_wider(
      names_from = analysis_period,
      values_from = c(rmspe, mean_gap)
    ) |>
    dplyr::mutate(
      base_outcome = base_outcome,
      outcome = outcome,
      moving_average_window = window,
      post_pre_rmspe_ratio = rmspe_post / rmspe_pre
    )

  readr::write_csv(
    fit$path,
    file.path(output_dir, paste0(outcome_slug, "_treated_synthetic_path.csv")),
    na = ""
  )

  readr::write_csv(
    fit$weights,
    file.path(output_dir, paste0(outcome_slug, "_weights.csv")),
    na = ""
  )

  readr::write_csv(
    rmspe_wide,
    file.path(output_dir, paste0(outcome_slug, "_rmspe_ratio.csv")),
    na = ""
  )

  rmspe_wide
}

moving_average_summary <- purrr::map_dfr(
  base_outcomes,
  function(base_outcome) {
    purrr::map_dfr(c(3, 6), ~run_one_smoothed_outcome(base_outcome, .x))
  }
)

original_rmspe <- purrr::map_dfr(
  base_outcomes,
  function(base_outcome) {
    readr::read_csv(
      file.path(
        pilot_root,
        "output",
        "scm_monthly",
        paste0(base_outcome, "_main_rmspe_ratio.csv")
      ),
      show_col_types = FALSE
    ) |>
      dplyr::transmute(
        base_outcome = base_outcome,
        outcome = base_outcome,
        moving_average_window = 1L,
        rmspe_pre = pre,
        rmspe_post = post,
        mean_gap_pre = NA_real_,
        mean_gap_post = NA_real_,
        post_pre_rmspe_ratio = post_pre_rmspe_ratio
      )
  }
)

comparison <- dplyr::bind_rows(
  original_rmspe,
  moving_average_summary
) |>
  dplyr::arrange(base_outcome, moving_average_window)

readr::write_csv(
  comparison,
  file.path(output_dir, "moving_average_rmspe_comparison.csv"),
  na = ""
)

message("RR 2018 monthly moving-average SCM completed.")
message("Saved outputs to: ", output_dir)
