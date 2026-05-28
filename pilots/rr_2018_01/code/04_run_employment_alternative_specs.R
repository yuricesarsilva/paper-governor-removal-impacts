source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

if (!requireNamespace("quadprog", quietly = TRUE)) {
  stop("Missing required package: quadprog")
}

if (!requireNamespace("ggplot2", quietly = TRUE)) {
  stop("Missing required package: ggplot2")
}

pilot_id <- "rr_2018_01"
treated_state <- "RR"
pilot_root <- file.path(root_dir, "pilots", pilot_id)

monthly_panel_path <- file.path(
  pilot_root,
  "data",
  "rr_2018_01_monthly_panel.csv"
)

output_dir <- file.path(pilot_root, "output", "employment_alternative_specs")
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

trailing_partial_sum <- function(x, window) {
  purrr::map_dbl(
    seq_along(x),
    function(i) {
      start_i <- max(1, i - window + 1)
      sum(x[start_i:i], na.rm = TRUE)
    }
  )
}

panel <- panel |>
  dplyr::group_by(state_abbrev) |>
  dplyr::arrange(period_date, .by_group = TRUE) |>
  dplyr::mutate(
    formal_hiring_balance_6m_sum = trailing_partial_sum(formal_hiring_balance, 6),
    formal_hiring_balance_cumulative = cumsum(formal_hiring_balance),
    semester_id = paste0(year, "S", dplyr::if_else(month <= 6, 1L, 2L))
  ) |>
  dplyr::ungroup()

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

build_predictor_matrix <- function(data, outcome, treated_state_code, donor_states, outcome_predictor_mode) {
  pre_data <- data |>
    dplyr::filter(analysis_period == "pre")

  states <- c(treated_state_code, donor_states)

  if (outcome_predictor_mode == "monthly_lags") {
    outcome_predictors <- pre_data |>
      dplyr::filter(state_abbrev %in% states) |>
      dplyr::select(state_abbrev, period_date, value = dplyr::all_of(outcome)) |>
      tidyr::pivot_wider(names_from = state_abbrev, values_from = value) |>
      dplyr::arrange(period_date)

    outcome_matrix <- outcome_predictors |>
      dplyr::select(dplyr::all_of(states)) |>
      as.matrix()

    rownames(outcome_matrix) <- paste0("lag_", format(outcome_predictors$period_date, "%Y_%m"))
  } else if (outcome_predictor_mode == "semester_means") {
    outcome_predictors <- pre_data |>
      dplyr::filter(state_abbrev %in% states) |>
      dplyr::group_by(state_abbrev, semester_id) |>
      dplyr::summarise(value = mean(.data[[outcome]], na.rm = TRUE), .groups = "drop") |>
      tidyr::pivot_wider(names_from = state_abbrev, values_from = value) |>
      dplyr::arrange(semester_id)

    outcome_matrix <- outcome_predictors |>
      dplyr::select(dplyr::all_of(states)) |>
      as.matrix()

    rownames(outcome_matrix) <- paste0("semester_mean_", outcome_predictors$semester_id)
  } else {
    stop("Unknown outcome predictor mode: ", outcome_predictor_mode)
  }

  covariate_matrix <- pre_data |>
    dplyr::filter(state_abbrev %in% states) |>
    dplyr::group_by(state_abbrev) |>
    dplyr::summarise(
      retail_volume_index = mean(retail_volume_index, na.rm = TRUE),
      services_volume_index = mean(services_volume_index, na.rm = TRUE),
      unemployment_rate_pnadc = mean(unemployment_rate_pnadc[pnadc_predictor_valid], na.rm = TRUE),
      formalization_rate_pnadc = mean(formalization_rate_pnadc[pnadc_predictor_valid], na.rm = TRUE),
      .groups = "drop"
    ) |>
    tidyr::pivot_longer(-state_abbrev, names_to = "predictor", values_to = "value") |>
    tidyr::pivot_wider(names_from = state_abbrev, values_from = value) |>
    dplyr::arrange(predictor)

  covariate_matrix_values <- covariate_matrix |>
    dplyr::select(dplyr::all_of(states)) |>
    as.matrix()

  rownames(covariate_matrix_values) <- paste0("mean_", covariate_matrix$predictor)

  predictor_matrix <- rbind(outcome_matrix, covariate_matrix_values)

  if (anyNA(predictor_matrix)) {
    stop("Missing values found in predictor matrix for outcome: ", outcome)
  }

  predictor_matrix
}

fit_scm <- function(data, outcome, treated_state_code, donor_states, outcome_predictor_mode) {
  predictor_matrix <- build_predictor_matrix(
    data = data,
    outcome = outcome,
    treated_state_code = treated_state_code,
    donor_states = donor_states,
    outcome_predictor_mode = outcome_predictor_mode
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
    dplyr::mutate(gap = treated_value - synthetic_value)

  weights_table <- tibble::tibble(
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
    tidyr::pivot_wider(
      names_from = analysis_period,
      values_from = c(rmspe, mean_gap)
    ) |>
    dplyr::mutate(post_pre_rmspe_ratio = rmspe_post / rmspe_pre)

  balance <- tibble::tibble(
    predictor = rownames(predictor_matrix),
    treated_value = as.numeric(predictor_matrix[, treated_state_code]),
    synthetic_value = as.numeric(predictor_matrix[, donor_states, drop = FALSE] %*% weights),
    difference = treated_value - synthetic_value,
    used_in_scaled_fit = standardized$keep_rows
  )

  list(
    path = path,
    weights = weights_table,
    rmspe = rmspe,
    balance = balance
  )
}

specs <- tibble::tribble(
  ~spec_id, ~outcome, ~outcome_predictor_mode, ~description,
  "level_semester_predictors", "formal_hiring_balance", "semester_means", "Monthly CAGED level outcome with semester-mean pre-treatment outcome predictors",
  "six_month_sum", "formal_hiring_balance_6m_sum", "monthly_lags", "Trailing 6-month accumulated CAGED balance",
  "cumulative_since_2016", "formal_hiring_balance_cumulative", "monthly_lags", "Cumulative CAGED balance since the start of the pilot panel"
)

donor_states <- panel |>
  dplyr::filter(donor_pool_main) |>
  dplyr::distinct(state_abbrev) |>
  dplyr::arrange(state_abbrev) |>
  dplyr::pull(state_abbrev)

run_spec <- function(spec_id, outcome, outcome_predictor_mode, description) {
  fit <- fit_scm(
    data = panel,
    outcome = outcome,
    treated_state_code = treated_state,
    donor_states = donor_states,
    outcome_predictor_mode = outcome_predictor_mode
  )

  spec_dir <- file.path(output_dir, spec_id)
  dir.create(spec_dir, recursive = TRUE, showWarnings = FALSE)

  readr::write_csv(fit$path, file.path(spec_dir, "treated_synthetic_path.csv"), na = "")
  readr::write_csv(fit$weights, file.path(spec_dir, "weights.csv"), na = "")
  readr::write_csv(fit$rmspe, file.path(spec_dir, "rmspe.csv"), na = "")
  readr::write_csv(fit$balance, file.path(spec_dir, "predictor_balance.csv"), na = "")

  plot_data <- fit$path |>
    dplyr::mutate(period_date = as.Date(period_date))

  path_plot <- ggplot2::ggplot(plot_data, ggplot2::aes(x = period_date)) +
    ggplot2::geom_line(ggplot2::aes(y = treated_value, color = "RR"), linewidth = 0.8) +
    ggplot2::geom_line(ggplot2::aes(y = synthetic_value, color = "Synthetic RR"), linewidth = 0.8) +
    ggplot2::geom_vline(xintercept = as.Date("2019-01-01"), linetype = "dashed", color = "gray35") +
    ggplot2::scale_color_manual(values = c("RR" = "#1f6f8b", "Synthetic RR" = "#c65a2e")) +
    ggplot2::labs(
      title = paste0("RR 2018 employment SCM: ", spec_id),
      subtitle = description,
      x = NULL,
      y = outcome,
      color = NULL
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "bottom")

  ggplot2::ggsave(
    file.path(spec_dir, "treated_vs_synthetic.png"),
    path_plot,
    width = 9,
    height = 5,
    dpi = 300,
    bg = "white"
  )

  gap_plot <- ggplot2::ggplot(plot_data, ggplot2::aes(x = period_date, y = gap)) +
    ggplot2::geom_hline(yintercept = 0, color = "gray70", linewidth = 0.3) +
    ggplot2::geom_line(color = "#1f6f8b", linewidth = 0.8) +
    ggplot2::geom_vline(xintercept = as.Date("2019-01-01"), linetype = "dashed", color = "gray35") +
    ggplot2::labs(
      title = paste0("RR 2018 employment gap: ", spec_id),
      x = NULL,
      y = "RR - Synthetic RR"
    ) +
    ggplot2::theme_minimal(base_size = 11)

  ggplot2::ggsave(
    file.path(spec_dir, "gap.png"),
    gap_plot,
    width = 9,
    height = 5,
    dpi = 300,
    bg = "white"
  )

  fit$rmspe |>
    dplyr::mutate(
      spec_id = spec_id,
      outcome = outcome,
      outcome_predictor_mode = outcome_predictor_mode,
      description = description
    )
}

alternative_summary <- purrr::pmap_dfr(specs, run_spec)

baseline_summary <- readr::read_csv(
  file.path(
    pilot_root,
    "output",
    "scm_monthly",
    "formal_hiring_balance_main_rmspe_ratio.csv"
  ),
  show_col_types = FALSE
) |>
  dplyr::transmute(
    rmspe_pre = pre,
    mean_gap_pre = NA_real_,
    rmspe_post = post,
    mean_gap_post = NA_real_,
    post_pre_rmspe_ratio = post_pre_rmspe_ratio,
    spec_id = "baseline_monthly_lags",
    outcome = "formal_hiring_balance",
    outcome_predictor_mode = "monthly_lags",
    description = "Monthly CAGED level outcome with full monthly pre-treatment outcome path"
  )

comparison <- dplyr::bind_rows(
  baseline_summary,
  alternative_summary
) |>
  dplyr::arrange(rmspe_pre)

readr::write_csv(
  comparison,
  file.path(output_dir, "employment_alternative_specs_comparison.csv"),
  na = ""
)

message("RR 2018 employment alternative SCM specifications completed.")
message("Saved outputs to: ", output_dir)
