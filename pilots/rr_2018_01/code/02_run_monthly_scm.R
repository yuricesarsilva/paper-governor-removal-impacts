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

if (!file.exists(monthly_panel_path)) {
  stop("Monthly pilot panel not found: ", monthly_panel_path)
}

output_dir <- file.path(pilot_root, "output", "scm_monthly")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

panel <- readr::read_csv(monthly_panel_path, show_col_types = FALSE) |>
  dplyr::mutate(
    period_date = as.Date(period_date),
    state_abbrev = as.character(state_abbrev),
    treated_unit = as.logical(treated_unit),
    donor_pool_main = as.logical(donor_pool_main),
    pnadc_predictor_valid = as.logical(pnadc_predictor_valid)
  ) |>
  dplyr::filter(monthly_main_window)

monthly_outcomes <- c(
  "formal_hiring_balance",
  "retail_volume_index",
  "services_volume_index"
)

economic_covariates <- c(
  "retail_volume_index",
  "services_volume_index",
  "formal_hiring_balance"
)

pnadc_covariates <- c(
  "unemployment_rate_pnadc",
  "formalization_rate_pnadc"
)

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

build_predictor_matrix <- function(data, outcome, treated_state_code, donor_states) {
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

  covariates_to_use <- setdiff(economic_covariates, outcome)

  economic_predictors <- pre_data |>
    dplyr::filter(state_abbrev %in% states) |>
    dplyr::group_by(state_abbrev) |>
    dplyr::summarise(
      dplyr::across(dplyr::all_of(covariates_to_use), ~mean(.x, na.rm = TRUE)),
      .groups = "drop"
    ) |>
    tidyr::pivot_longer(-state_abbrev, names_to = "predictor", values_to = "value") |>
    tidyr::pivot_wider(names_from = state_abbrev, values_from = value) |>
    dplyr::arrange(predictor)

  economic_matrix <- economic_predictors |>
    dplyr::select(dplyr::all_of(states)) |>
    as.matrix()

  rownames(economic_matrix) <- paste0("mean_", economic_predictors$predictor)

  pnadc_predictors <- pre_data |>
    dplyr::filter(
      state_abbrev %in% states,
      pnadc_predictor_valid
    ) |>
    dplyr::group_by(state_abbrev) |>
    dplyr::summarise(
      dplyr::across(dplyr::all_of(pnadc_covariates), ~mean(.x, na.rm = TRUE)),
      .groups = "drop"
    ) |>
    tidyr::pivot_longer(-state_abbrev, names_to = "predictor", values_to = "value") |>
    tidyr::pivot_wider(names_from = state_abbrev, values_from = value) |>
    dplyr::arrange(predictor)

  pnadc_matrix <- pnadc_predictors |>
    dplyr::select(dplyr::all_of(states)) |>
    as.matrix()

  rownames(pnadc_matrix) <- paste0("mean_", pnadc_predictors$predictor)

  predictor_matrix <- rbind(outcome_matrix, economic_matrix, pnadc_matrix)

  if (anyNA(predictor_matrix)) {
    stop("Missing values found in predictor matrix for outcome: ", outcome)
  }

  predictor_matrix
}

fit_scm <- function(data, outcome, treated_state_code, donor_states) {
  predictor_matrix <- build_predictor_matrix(
    data = data,
    outcome = outcome,
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

  balance <- tibble::tibble(
    predictor = rownames(predictor_matrix),
    treated_value = as.numeric(predictor_matrix[, treated_state_code]),
    synthetic_value = as.numeric(predictor_matrix[, donor_states, drop = FALSE] %*% weights),
    difference = treated_value - synthetic_value,
    used_in_scaled_fit = standardized$keep_rows
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
    weights = weights_table,
    balance = balance,
    path = path,
    rmspe = rmspe
  )
}

run_placebos <- function(data, outcome, donor_pool_states) {
  purrr::map_dfr(
    donor_pool_states,
    function(placebo_state) {
      placebo_donors <- setdiff(donor_pool_states, placebo_state)

      fit <- fit_scm(
        data = data,
        outcome = outcome,
        treated_state_code = placebo_state,
        donor_states = placebo_donors
      )

      fit$path |>
        dplyr::mutate(placebo_state = placebo_state)
    }
  )
}

summarise_rmspe <- function(path_data) {
  path_data |>
    dplyr::group_by(analysis_period) |>
    dplyr::summarise(
      rmspe = sqrt(mean(gap^2, na.rm = TRUE)),
      mean_gap = mean(gap, na.rm = TRUE),
      .groups = "drop"
    )
}

summarise_pre_2020_rmspe_ratio <- function(path_data) {
  path_data |>
    dplyr::filter(
      analysis_period == "pre" |
        (analysis_period == "post" & period_date <= as.Date("2019-12-01"))
    ) |>
    summarise_rmspe() |>
    dplyr::select(analysis_period, rmspe) |>
    tidyr::pivot_wider(names_from = analysis_period, values_from = rmspe) |>
    dplyr::mutate(post_pre_rmspe_ratio = post / pre)
}

run_leave_one_out <- function(data, outcome, treated_state_code, donor_states, omitted_donors) {
  purrr::map_dfr(
    omitted_donors,
    function(omitted_donor) {
      loo_donors <- setdiff(donor_states, omitted_donor)

      fit <- fit_scm(
        data = data,
        outcome = outcome,
        treated_state_code = treated_state_code,
        donor_states = loo_donors
      )

      fit$path |>
        dplyr::mutate(omitted_donor = omitted_donor)
    }
  )
}

save_outcome_outputs <- function(outcome) {
  outcome_slug <- make_slug(outcome)
  donor_states <- panel |>
    dplyr::filter(donor_pool_main) |>
    dplyr::distinct(state_abbrev) |>
    dplyr::arrange(state_abbrev) |>
    dplyr::pull(state_abbrev)

  main_fit <- fit_scm(
    data = panel,
    outcome = outcome,
    treated_state_code = treated_state,
    donor_states = donor_states
  )

  placebo_paths <- run_placebos(
    data = panel,
    outcome = outcome,
    donor_pool_states = donor_states
  )

  all_gap_paths <- dplyr::bind_rows(
    main_fit$path |>
      dplyr::mutate(unit_type = "RR", placebo_state = treated_state),
    placebo_paths |>
      dplyr::mutate(unit_type = "placebo")
  )

  placebo_rmspe <- placebo_paths |>
    dplyr::group_by(placebo_state, analysis_period) |>
    dplyr::summarise(
      rmspe = sqrt(mean(gap^2, na.rm = TRUE)),
      .groups = "drop"
    ) |>
    tidyr::pivot_wider(names_from = analysis_period, values_from = rmspe) |>
    dplyr::mutate(post_pre_rmspe_ratio = post / pre) |>
    dplyr::arrange(dplyr::desc(post_pre_rmspe_ratio))

  main_rmspe_wide <- main_fit$rmspe |>
    dplyr::select(analysis_period, rmspe) |>
    tidyr::pivot_wider(names_from = analysis_period, values_from = rmspe) |>
    dplyr::mutate(
      outcome = outcome,
      treated_state = treated_state,
      post_pre_rmspe_ratio = post / pre
    )

  main_pre_2020_rmspe <- summarise_pre_2020_rmspe_ratio(main_fit$path) |>
    dplyr::mutate(
      outcome = outcome,
      treated_state = treated_state,
      robustness_window = "post_2019_01_to_2019_12"
    )

  placebo_pre_2020_rmspe <- placebo_paths |>
    dplyr::filter(
      analysis_period == "pre" |
        (analysis_period == "post" & period_date <= as.Date("2019-12-01"))
    ) |>
    dplyr::group_by(placebo_state, analysis_period) |>
    dplyr::summarise(
      rmspe = sqrt(mean(gap^2, na.rm = TRUE)),
      .groups = "drop"
    ) |>
    tidyr::pivot_wider(names_from = analysis_period, values_from = rmspe) |>
    dplyr::mutate(post_pre_rmspe_ratio = post / pre) |>
    dplyr::arrange(dplyr::desc(post_pre_rmspe_ratio))

  positive_donors <- main_fit$weights |>
    dplyr::filter(weight > 0.001) |>
    dplyr::pull(donor_state)

  leave_one_out_paths <- run_leave_one_out(
    data = panel,
    outcome = outcome,
    treated_state_code = treated_state,
    donor_states = donor_states,
    omitted_donors = positive_donors
  )

  leave_one_out_rmspe <- leave_one_out_paths |>
    dplyr::group_by(omitted_donor, analysis_period) |>
    dplyr::summarise(
      rmspe = sqrt(mean(gap^2, na.rm = TRUE)),
      mean_gap = mean(gap, na.rm = TRUE),
      .groups = "drop"
    ) |>
    tidyr::pivot_wider(
      names_from = analysis_period,
      values_from = c(rmspe, mean_gap)
    ) |>
    dplyr::mutate(
      outcome = outcome,
      post_pre_rmspe_ratio = rmspe_post / rmspe_pre
    ) |>
    dplyr::arrange(dplyr::desc(post_pre_rmspe_ratio))

  readr::write_csv(
    main_fit$weights,
    file.path(output_dir, paste0(outcome_slug, "_weights.csv")),
    na = ""
  )

  readr::write_csv(
    main_fit$balance,
    file.path(output_dir, paste0(outcome_slug, "_predictor_balance.csv")),
    na = ""
  )

  readr::write_csv(
    main_fit$path,
    file.path(output_dir, paste0(outcome_slug, "_treated_synthetic_path.csv")),
    na = ""
  )

  readr::write_csv(
    main_fit$rmspe,
    file.path(output_dir, paste0(outcome_slug, "_rmspe.csv")),
    na = ""
  )

  readr::write_csv(
    placebo_paths,
    file.path(output_dir, paste0(outcome_slug, "_placebo_paths.csv")),
    na = ""
  )

  readr::write_csv(
    placebo_rmspe,
    file.path(output_dir, paste0(outcome_slug, "_placebo_rmspe.csv")),
    na = ""
  )

  readr::write_csv(
    main_rmspe_wide,
    file.path(output_dir, paste0(outcome_slug, "_main_rmspe_ratio.csv")),
    na = ""
  )

  readr::write_csv(
    main_pre_2020_rmspe,
    file.path(output_dir, paste0(outcome_slug, "_pre_2020_robustness_rmspe_ratio.csv")),
    na = ""
  )

  readr::write_csv(
    placebo_pre_2020_rmspe,
    file.path(output_dir, paste0(outcome_slug, "_pre_2020_robustness_placebo_rmspe.csv")),
    na = ""
  )

  readr::write_csv(
    leave_one_out_paths,
    file.path(output_dir, paste0(outcome_slug, "_leave_one_out_paths.csv")),
    na = ""
  )

  readr::write_csv(
    leave_one_out_rmspe,
    file.path(output_dir, paste0(outcome_slug, "_leave_one_out_rmspe.csv")),
    na = ""
  )

  path_plot <- ggplot2::ggplot(main_fit$path, ggplot2::aes(x = period_date)) +
    ggplot2::geom_line(ggplot2::aes(y = treated_value, color = "RR"), linewidth = 0.8) +
    ggplot2::geom_line(ggplot2::aes(y = synthetic_value, color = "Synthetic RR"), linewidth = 0.8) +
    ggplot2::geom_vline(xintercept = as.Date("2019-01-01"), linetype = "dashed", color = "gray35") +
    ggplot2::scale_color_manual(values = c("RR" = "#1f6f8b", "Synthetic RR" = "#c65a2e")) +
    ggplot2::labs(
      title = paste0("RR 2018 SCM: ", outcome),
      x = NULL,
      y = outcome,
      color = NULL
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "bottom")

  ggplot2::ggsave(
    file.path(output_dir, paste0(outcome_slug, "_treated_vs_synthetic.png")),
    path_plot,
    width = 9,
    height = 5,
    dpi = 300,
    bg = "white"
  )

  gap_plot <- ggplot2::ggplot(main_fit$path, ggplot2::aes(x = period_date, y = gap)) +
    ggplot2::geom_hline(yintercept = 0, color = "gray70", linewidth = 0.3) +
    ggplot2::geom_line(color = "#1f6f8b", linewidth = 0.8) +
    ggplot2::geom_vline(xintercept = as.Date("2019-01-01"), linetype = "dashed", color = "gray35") +
    ggplot2::labs(
      title = paste0("RR 2018 SCM gap: ", outcome),
      x = NULL,
      y = "RR - Synthetic RR"
    ) +
    ggplot2::theme_minimal(base_size = 11)

  ggplot2::ggsave(
    file.path(output_dir, paste0(outcome_slug, "_gap.png")),
    gap_plot,
    width = 9,
    height = 5,
    dpi = 300,
    bg = "white"
  )

  placebo_plot <- ggplot2::ggplot(all_gap_paths, ggplot2::aes(x = period_date, y = gap, group = placebo_state)) +
    ggplot2::geom_line(
      data = dplyr::filter(all_gap_paths, unit_type == "placebo"),
      color = "gray70",
      linewidth = 0.35,
      alpha = 0.75
    ) +
    ggplot2::geom_line(
      data = dplyr::filter(all_gap_paths, unit_type == "RR"),
      color = "#b23a48",
      linewidth = 0.9
    ) +
    ggplot2::geom_hline(yintercept = 0, color = "gray55", linewidth = 0.3) +
    ggplot2::geom_vline(xintercept = as.Date("2019-01-01"), linetype = "dashed", color = "gray35") +
    ggplot2::labs(
      title = paste0("RR 2018 SCM placebo gaps: ", outcome),
      x = NULL,
      y = "Gap"
    ) +
    ggplot2::theme_minimal(base_size = 11)

  ggplot2::ggsave(
    file.path(output_dir, paste0(outcome_slug, "_placebo_gaps.png")),
    placebo_plot,
    width = 9,
    height = 5,
    dpi = 300,
    bg = "white"
  )

  leave_one_out_plot <- ggplot2::ggplot(
    leave_one_out_paths,
    ggplot2::aes(x = period_date, y = gap, color = omitted_donor)
  ) +
    ggplot2::geom_hline(yintercept = 0, color = "gray70", linewidth = 0.3) +
    ggplot2::geom_line(linewidth = 0.6, alpha = 0.85) +
    ggplot2::geom_line(
      data = main_fit$path,
      ggplot2::aes(x = period_date, y = gap),
      inherit.aes = FALSE,
      color = "black",
      linewidth = 0.9
    ) +
    ggplot2::geom_vline(xintercept = as.Date("2019-01-01"), linetype = "dashed", color = "gray35") +
    ggplot2::labs(
      title = paste0("RR 2018 SCM leave-one-out gaps: ", outcome),
      subtitle = "Black line is the main specification",
      x = NULL,
      y = "RR - Synthetic RR",
      color = "Omitted donor"
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "bottom")

  ggplot2::ggsave(
    file.path(output_dir, paste0(outcome_slug, "_leave_one_out_gaps.png")),
    leave_one_out_plot,
    width = 9,
    height = 5,
    dpi = 300,
    bg = "white"
  )

  message("Saved monthly SCM outputs for: ", outcome)
}

invisible(purrr::walk(monthly_outcomes, save_outcome_outputs))

message("RR 2018 monthly SCM completed.")
message("Saved outputs to: ", output_dir)
