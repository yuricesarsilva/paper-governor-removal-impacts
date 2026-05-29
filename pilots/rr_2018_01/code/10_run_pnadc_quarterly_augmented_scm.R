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
excluded_donors <- c("RR", "AM", "TO")
pilot_root <- file.path(root_dir, "pilots", pilot_id)

pnadc_panel_path <- file.path(
  root_dir,
  "data",
  "processed",
  "pnadc_sidra_quarterly_state_covariates_panel_ready.csv"
)

output_dir <- file.path(pilot_root, "output", "augmented_scm_pnadc_quarterly")
full_window_output_dir <- file.path(pilot_root, "output", "augmented_scm_pnadc_quarterly_full_window")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(full_window_output_dir, recursive = TRUE, showWarnings = FALSE)

lambda_grid <- 10^seq(-4, 5, length.out = 60)

trailing_partial_mean <- function(x, window) {
  purrr::map_dbl(
    seq_along(x),
    function(i) {
      start_i <- max(1, i - window + 1)
      mean(x[start_i:i], na.rm = TRUE)
    }
  )
}

add_post_clean_ma4_columns <- function(data) {
  data |>
    dplyr::group_by(state_abbrev, analysis_period) |>
    dplyr::arrange(period_date, .by_group = TRUE) |>
    dplyr::mutate(
      labor_income_real_pnadc_ma2_post_clean = trailing_partial_mean(
        labor_income_real_pnadc,
        2
      ),
      labor_income_real_pnadc_ma4_post_clean = trailing_partial_mean(
        labor_income_real_pnadc,
        4
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

quarter_label <- function(date) {
  paste0(lubridate::year(date), "Q", lubridate::quarter(date))
}

standardize_predictors_by_row <- function(x) {
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

standardize_unit_predictors <- function(x_train, x_all) {
  col_means <- colMeans(x_train, na.rm = TRUE)
  col_sds <- apply(x_train, 2, stats::sd, na.rm = TRUE)
  col_sds[!is.finite(col_sds) | col_sds == 0] <- 1

  list(
    x_train = sweep(sweep(x_train, 2, col_means, "-"), 2, col_sds, "/"),
    x_all = sweep(sweep(x_all, 2, col_means, "-"), 2, col_sds, "/")
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

fit_ridge <- function(x, y, lambda) {
  design <- cbind(intercept = 1, x)
  penalty <- diag(ncol(design))
  penalty[1, 1] <- 0

  as.numeric(solve(crossprod(design) + lambda * penalty, crossprod(design, y)))
}

predict_ridge <- function(x, coef) {
  as.numeric(cbind(intercept = 1, x) %*% coef)
}

loocv_lambda <- function(x_train, y_train, lambdas) {
  if (nrow(x_train) < 5) {
    return(tibble::tibble(lambda = 1, cv_rmse = NA_real_))
  }

  cv <- purrr::map_dfr(
    lambdas,
    function(lambda) {
      errors <- purrr::map_dbl(
        seq_along(y_train),
        function(i) {
          coef <- fit_ridge(x_train[-i, , drop = FALSE], y_train[-i], lambda)
          y_hat <- predict_ridge(x_train[i, , drop = FALSE], coef)
          y_train[i] - y_hat
        }
      )

      tibble::tibble(
        lambda = lambda,
        cv_rmse = sqrt(mean(errors^2, na.rm = TRUE))
      )
    }
  )

  cv |>
    dplyr::arrange(cv_rmse, lambda) |>
    dplyr::slice(1)
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

  rownames(outcome_matrix) <- paste0("lag_", quarter_label(outcome_predictors$period_date))

  pnadc_covariates <- setdiff(
    c("labor_income_real_pnadc", "unemployment_rate_pnadc", "formalization_rate_pnadc"),
    outcome
  )

  pnadc_matrix <- pre_data |>
    dplyr::filter(state_abbrev %in% states) |>
    dplyr::group_by(state_abbrev) |>
    dplyr::summarise(
      dplyr::across(dplyr::all_of(pnadc_covariates), ~mean(.x, na.rm = TRUE)),
      .groups = "drop"
    ) |>
    tidyr::pivot_longer(-state_abbrev, names_to = "predictor", values_to = "value") |>
    tidyr::pivot_wider(names_from = state_abbrev, values_from = value) |>
    dplyr::arrange(predictor)

  pnadc_matrix_values <- pnadc_matrix |>
    dplyr::select(dplyr::all_of(states)) |>
    as.matrix()

  rownames(pnadc_matrix_values) <- paste0("mean_", pnadc_matrix$predictor)

  predictor_matrix <- rbind(outcome_matrix, pnadc_matrix_values)

  if (anyNA(predictor_matrix)) {
    stop("Missing values found in predictor matrix for outcome: ", outcome)
  }

  predictor_matrix
}

fit_augmented_scm <- function(data, outcome) {
  donor_states <- data |>
    dplyr::filter(donor_pool_main) |>
    dplyr::distinct(state_abbrev) |>
    dplyr::arrange(state_abbrev) |>
    dplyr::pull(state_abbrev)

  predictor_matrix <- build_predictor_matrix(
    data = data,
    outcome = outcome,
    treated_state_code = treated_state,
    donor_states = donor_states
  )

  scaled <- standardize_predictors_by_row(predictor_matrix)
  predictor_matrix_scaled <- scaled$x
  x1 <- predictor_matrix_scaled[, treated_state, drop = FALSE]
  x0 <- predictor_matrix_scaled[, donor_states, drop = FALSE]

  scm_weights <- solve_scm_weights(x1, x0)
  names(scm_weights) <- donor_states

  unit_predictors <- t(predictor_matrix)
  donor_predictors <- unit_predictors[donor_states, , drop = FALSE]
  all_predictors <- unit_predictors[c(treated_state, donor_states), , drop = FALSE]
  standardized_units <- standardize_unit_predictors(donor_predictors, all_predictors)

  treated_predictor <- standardized_units$x_all[treated_state, , drop = FALSE]
  donor_predictors_scaled <- standardized_units$x_all[donor_states, , drop = FALSE]
  weighted_donor_predictor <- matrix(as.numeric(t(scm_weights) %*% donor_predictors_scaled), nrow = 1)
  predictor_imbalance <- treated_predictor - weighted_donor_predictor

  wide <- data |>
    dplyr::filter(state_abbrev %in% c(treated_state, donor_states)) |>
    dplyr::select(period_date, analysis_period, state_abbrev, value = dplyr::all_of(outcome)) |>
    tidyr::pivot_wider(names_from = state_abbrev, values_from = value) |>
    dplyr::arrange(period_date)

  correction_rows <- purrr::map_dfr(
    seq_len(nrow(wide)),
    function(i) {
      y_donor <- as.numeric(wide[i, donor_states, drop = TRUE])
      y_center <- mean(y_donor, na.rm = TRUE)
      y_scale <- stats::sd(y_donor, na.rm = TRUE)
      if (!is.finite(y_scale) || y_scale == 0) {
        y_scale <- 1
      }
      y_donor_scaled <- (y_donor - y_center) / y_scale

      best_lambda <- loocv_lambda(donor_predictors_scaled, y_donor_scaled, lambda_grid)
      coef <- fit_ridge(donor_predictors_scaled, y_donor_scaled, best_lambda$lambda)

      correction_scaled <- as.numeric(predictor_imbalance %*% coef[-1])
      correction <- correction_scaled * y_scale

      tibble::tibble(
        period_date = wide$period_date[i],
        augmentation_correction = correction,
        augmentation_lambda = best_lambda$lambda,
        augmentation_cv_rmse = best_lambda$cv_rmse
      )
    }
  )

  scm_synthetic <- as.matrix(wide[, donor_states, drop = FALSE]) %*% scm_weights

  path <- wide |>
    dplyr::transmute(
      period_date,
      period = quarter_label(period_date),
      analysis_period,
      treated_value = .data[[treated_state]],
      scm_synthetic_value = as.numeric(scm_synthetic)
    ) |>
    dplyr::left_join(correction_rows, by = "period_date") |>
    dplyr::mutate(
      augmented_synthetic_value = scm_synthetic_value + augmentation_correction,
      scm_gap = treated_value - scm_synthetic_value,
      augmented_gap = treated_value - augmented_synthetic_value,
      outcome = outcome
    )

  weights <- tibble::tibble(
    donor_state = donor_states,
    scm_weight = as.numeric(scm_weights)
  ) |>
    dplyr::arrange(dplyr::desc(scm_weight), donor_state)

  rmspe <- path |>
    dplyr::group_by(analysis_period) |>
    dplyr::summarise(
      scm_rmspe = sqrt(mean(scm_gap^2, na.rm = TRUE)),
      augmented_rmspe = sqrt(mean(augmented_gap^2, na.rm = TRUE)),
      scm_mean_gap = mean(scm_gap, na.rm = TRUE),
      augmented_mean_gap = mean(augmented_gap, na.rm = TRUE),
      .groups = "drop"
    ) |>
    tidyr::pivot_wider(
      names_from = analysis_period,
      values_from = c(scm_rmspe, augmented_rmspe, scm_mean_gap, augmented_mean_gap)
    ) |>
    dplyr::mutate(
      outcome = outcome,
      scm_post_pre_rmspe_ratio = scm_rmspe_post / scm_rmspe_pre,
      augmented_post_pre_rmspe_ratio = augmented_rmspe_post / augmented_rmspe_pre
    )

  list(
    path = path,
    weights = weights,
    rmspe = rmspe
  )
}

run_outcome <- function(outcome, output_path = output_dir) {
  outcome_slug <- make_slug(outcome)
  fit <- fit_augmented_scm(panel, outcome)

  readr::write_csv(
    fit$path,
    file.path(output_path, paste0(outcome_slug, "_path.csv")),
    na = ""
  )

  readr::write_csv(
    fit$weights,
    file.path(output_path, paste0(outcome_slug, "_scm_weights.csv")),
    na = ""
  )

  readr::write_csv(
    fit$rmspe,
    file.path(output_path, paste0(outcome_slug, "_rmspe.csv")),
    na = ""
  )

  path_plot <- ggplot2::ggplot(fit$path, ggplot2::aes(x = period_date)) +
    ggplot2::geom_line(ggplot2::aes(y = treated_value, color = "RR"), linewidth = 0.8) +
    ggplot2::geom_line(ggplot2::aes(y = scm_synthetic_value, color = "Classic SCM"), linewidth = 0.7, alpha = 0.75) +
    ggplot2::geom_line(ggplot2::aes(y = augmented_synthetic_value, color = "Augmented SCM"), linewidth = 0.8) +
    ggplot2::geom_vline(xintercept = as.Date("2019-01-01"), linetype = "dashed", color = "gray35") +
    ggplot2::scale_color_manual(values = c("RR" = "#1f6f8b", "Classic SCM" = "#c65a2e", "Augmented SCM" = "#7b4ab0")) +
    ggplot2::labs(
      title = paste0("RR 2018 quarterly PNADc augmented SCM: ", outcome),
      x = NULL,
      y = outcome,
      color = NULL
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "bottom")

  ggplot2::ggsave(
    file.path(output_path, paste0(outcome_slug, "_treated_scm_augmented.png")),
    path_plot,
    width = 9,
    height = 5,
    dpi = 300,
    bg = "white"
  )

  gap_plot <- fit$path |>
    dplyr::select(period_date, scm_gap, augmented_gap) |>
    tidyr::pivot_longer(-period_date, names_to = "gap_type", values_to = "gap") |>
    dplyr::mutate(
      gap_type = dplyr::recode(
        gap_type,
        scm_gap = "Classic SCM",
        augmented_gap = "Augmented SCM"
      )
    ) |>
    ggplot2::ggplot(ggplot2::aes(x = period_date, y = gap, color = gap_type)) +
    ggplot2::geom_hline(yintercept = 0, color = "gray70", linewidth = 0.3) +
    ggplot2::geom_line(linewidth = 0.8) +
    ggplot2::geom_vline(xintercept = as.Date("2019-01-01"), linetype = "dashed", color = "gray35") +
    ggplot2::scale_color_manual(values = c("Classic SCM" = "#c65a2e", "Augmented SCM" = "#7b4ab0")) +
    ggplot2::labs(
      title = paste0("RR 2018 quarterly PNADc gaps: ", outcome),
      x = NULL,
      y = "RR - Synthetic RR",
      color = NULL
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "bottom")

  ggplot2::ggsave(
    file.path(output_path, paste0(outcome_slug, "_gaps.png")),
    gap_plot,
    width = 9,
    height = 5,
    dpi = 300,
    bg = "white"
  )

  fit$rmspe
}

panel <- readr::read_csv(pnadc_panel_path, show_col_types = FALSE) |>
  dplyr::mutate(
    period_date = as.Date(period_date),
    state_abbrev = as.character(state_abbrev),
    period = as.character(period),
    donor_pool_main = !state_abbrev %in% excluded_donors,
    treated_unit = state_abbrev == treated_state,
    transition_period = period == "2018Q4",
    analysis_period = dplyr::case_when(
      period_date >= as.Date("2016-01-01") & period_date <= as.Date("2018-07-01") ~ "pre",
      period_date >= as.Date("2019-01-01") & period_date <= as.Date("2020-10-01") ~ "post",
      TRUE ~ NA_character_
    )
  ) |>
  dplyr::filter(
    !transition_period,
    !is.na(analysis_period),
    period_date >= as.Date("2016-01-01"),
    period_date <= as.Date("2020-10-01")
  ) |>
  dplyr::arrange(state_abbrev, period_date) |>
  add_post_clean_ma4_columns()

outcomes <- c(
  "labor_income_real_pnadc",
  "labor_income_real_pnadc_ma2_post_clean",
  "labor_income_real_pnadc_ma4_post_clean",
  "unemployment_rate_pnadc",
  "formalization_rate_pnadc"
)

summary <- purrr::map_dfr(outcomes, run_outcome)

panel_ma2_full_window <- panel |>
  dplyr::mutate(
    analysis_period = dplyr::case_when(
      analysis_period == "post" &
        period_date < as.Date("2019-04-01") ~ "post_partial_window_ma2",
      TRUE ~ analysis_period
    )
  )

panel_ma4_full_window <- panel |>
  dplyr::mutate(
    analysis_period = dplyr::case_when(
      analysis_period == "post" &
        period_date < as.Date("2019-10-01") ~ "post_partial_window_ma4",
      TRUE ~ analysis_period
    )
  )

panel_original <- panel

panel <- panel_ma2_full_window
ma2_full_window_summary <- run_outcome(
  "labor_income_real_pnadc_ma2_post_clean",
  output_path = full_window_output_dir
)

panel <- panel_ma4_full_window
ma4_full_window_summary <- run_outcome(
  "labor_income_real_pnadc_ma4_post_clean",
  output_path = full_window_output_dir
)

panel <- panel_original

full_window_summary <- dplyr::bind_rows(
  ma2_full_window_summary,
  ma4_full_window_summary
)

readr::write_csv(
  summary,
  file.path(output_dir, "augmented_scm_pnadc_quarterly_summary.csv"),
  na = ""
)

readr::write_csv(
  full_window_summary,
  file.path(full_window_output_dir, "augmented_scm_pnadc_quarterly_summary.csv"),
  na = ""
)

message("RR 2018 quarterly PNADc augmented SCM models completed.")
message("Saved outputs to: ", output_dir)
message("Saved full-window outputs to: ", full_window_output_dir)
