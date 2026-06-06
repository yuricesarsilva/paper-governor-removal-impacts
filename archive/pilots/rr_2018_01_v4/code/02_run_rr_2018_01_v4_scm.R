source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

extra_packages <- c("tidyr", "quadprog", "ggplot2")
missing_extra <- extra_packages[!vapply(extra_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_extra) > 0) {
  stop("Missing required packages: ", paste(missing_extra, collapse = ", "))
}
invisible(lapply(extra_packages, library, character.only = TRUE))

pilot_id <- "rr_2018_01_v4"
treated_state <- "RR"

pilot_root <- file.path(root_dir, "pilots", pilot_id)
data_dir <- file.path(pilot_root, "data")
output_root <- file.path(pilot_root, "output")
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

event <- readr::read_csv(
  file.path(data_dir, "rr_2018_01_v4_event_metadata.csv"),
  show_col_types = FALSE
) |>
  dplyr::slice(1) |>
  dplyr::mutate(
    instability_start_date = as.Date(.data$instability_start_date),
    removal_date = as.Date(.data$removal_date)
  )

covariates <- readr::read_csv(
  file.path(data_dir, "rr_2018_01_v4_covariates.csv"),
  show_col_types = FALSE
)

main_donor_states <- covariates |>
  dplyr::filter(.data$donor_pool_main) |>
  dplyr::pull(.data$state_abbrev) |>
  sort()

covariate_data <- covariates |>
  dplyr::select(
    .data$state_abbrev,
    .data$unemployment_rate,
    .data$formalization_rate,
    .data$labor_income_real,
    .data$transfer_dependency_ratio,
    .data$health_expenditure_real_pc,
    .data$education_expenditure_real_pc,
    .data$public_security_expenditure_real_pc
  )

monthly_panel <- readr::read_csv(
  file.path(data_dir, "rr_2018_01_v4_monthly_panel.csv"),
  show_col_types = FALSE
) |>
  dplyr::mutate(period_date = as.Date(.data$period_date))

fiscal_panel <- readr::read_csv(
  file.path(data_dir, "rr_2018_01_v4_bimonthly_fiscal_panel.csv"),
  show_col_types = FALSE
) |>
  dplyr::mutate(period_date = as.Date(.data$period_date))

make_slug <- function(x) {
  x |>
    stringr::str_replace_all("[^A-Za-z0-9]+", "_") |>
    stringr::str_replace_all("_+$", "") |>
    tolower()
}

standardize_predictors_by_row <- function(x) {
  row_means <- rowMeans(x, na.rm = TRUE)
  row_sds <- apply(x, 1, stats::sd, na.rm = TRUE)
  keep_rows <- is.finite(row_sds) & row_sds > 0
  x_scaled <- sweep(x[keep_rows, , drop = FALSE], 1, row_means[keep_rows], "-")
  x_scaled <- sweep(x_scaled, 1, row_sds[keep_rows], "/")
  list(x = x_scaled, keep_rows = keep_rows)
}

standardize_unit_predictors <- function(x_train, x_all) {
  col_means <- colMeans(x_train, na.rm = TRUE)
  col_sds <- apply(x_train, 2, stats::sd, na.rm = TRUE)
  col_sds[!is.finite(col_sds) | col_sds == 0] <- 1

  list(
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
    dplyr::arrange(.data$cv_rmse, .data$lambda) |>
    dplyr::slice(1)
}

build_predictor_matrix <- function(data, outcome, donor_states, covariate_data) {
  states <- c(treated_state, donor_states)

  outcome_pre <- data |>
    dplyr::filter(
      .data$analysis_period == "pre",
      .data$state_abbrev %in% states
    ) |>
    dplyr::select(.data$state_abbrev, .data$period_date, value = dplyr::all_of(outcome)) |>
    tidyr::pivot_wider(names_from = .data$state_abbrev, values_from = .data$value) |>
    dplyr::arrange(.data$period_date) |>
    dplyr::filter(stats::complete.cases(dplyr::across(dplyr::all_of(states))))

  outcome_matrix <- outcome_pre |>
    dplyr::select(dplyr::all_of(states)) |>
    as.matrix()

  rownames(outcome_matrix) <- paste0("pre_", format(outcome_pre$period_date, "%Y_%m_%d"))

  covariate_matrix <- covariate_data |>
    dplyr::filter(.data$state_abbrev %in% states) |>
    tidyr::pivot_longer(-.data$state_abbrev, names_to = "predictor", values_to = "value") |>
    tidyr::pivot_wider(names_from = .data$state_abbrev, values_from = .data$value) |>
    dplyr::arrange(.data$predictor)

  covariate_matrix_values <- covariate_matrix |>
    dplyr::select(dplyr::all_of(states)) |>
    as.matrix()

  rownames(covariate_matrix_values) <- paste0("cov_", covariate_matrix$predictor)

  predictor_matrix <- rbind(outcome_matrix, covariate_matrix_values)

  if (nrow(outcome_matrix) < 6) {
    stop("Too few complete pre-treatment periods for outcome: ", outcome)
  }

  if (anyNA(predictor_matrix)) {
    stop("Missing values in predictor matrix for outcome: ", outcome)
  }

  predictor_matrix
}

fit_augmented_scm <- function(data, outcome, family, specification) {
  lambda_grid <- 10^seq(-4, 5, length.out = 60)

  complete_states <- data |>
    dplyr::filter(.data$analysis_period == "pre") |>
    dplyr::group_by(.data$state_abbrev) |>
    dplyr::summarise(complete_pre_periods = sum(is.finite(.data[[outcome]])), .groups = "drop") |>
    dplyr::filter(.data$complete_pre_periods >= 6) |>
    dplyr::pull(.data$state_abbrev)

  donor_states <- intersect(main_donor_states, complete_states)
  donor_states <- donor_states[
    donor_states %in% covariate_data$state_abbrev[stats::complete.cases(covariate_data[, -1])]
  ]

  if (!(treated_state %in% complete_states)) {
    return(tibble::tibble(
      family = family,
      specification = specification,
      outcome = outcome,
      status = "skipped",
      skip_reason = paste0("Treated state has incomplete pre-treatment data for outcome: ", outcome)
    ))
  }

  if (length(donor_states) < 2) {
    return(tibble::tibble(
      family = family,
      specification = specification,
      outcome = outcome,
      status = "skipped",
      skip_reason = paste0("Fewer than two complete donor states for outcome: ", outcome)
    ))
  }

  predictor_matrix <- build_predictor_matrix(data, outcome, donor_states, covariate_data)
  scaled <- standardize_predictors_by_row(predictor_matrix)
  x1 <- scaled$x[, treated_state, drop = FALSE]
  x0 <- scaled$x[, donor_states, drop = FALSE]
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
    dplyr::filter(.data$state_abbrev %in% c(treated_state, donor_states)) |>
    dplyr::select(.data$period_date, .data$analysis_period, .data$state_abbrev, value = dplyr::all_of(outcome)) |>
    tidyr::pivot_wider(names_from = .data$state_abbrev, values_from = .data$value) |>
    dplyr::arrange(.data$period_date)

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
        period_date = wide$period_date[[i]],
        augmentation_correction = correction,
        augmentation_lambda = best_lambda$lambda,
        augmentation_cv_rmse = best_lambda$cv_rmse
      )
    }
  )

  scm_synthetic <- as.matrix(wide[, donor_states, drop = FALSE]) %*% scm_weights

  path <- wide |>
    dplyr::transmute(
      period_date = .data$period_date,
      analysis_period = .data$analysis_period,
      treated_value = .data[[treated_state]],
      scm_synthetic_value = as.numeric(scm_synthetic)
    ) |>
    dplyr::left_join(correction_rows, by = "period_date") |>
    dplyr::mutate(
      augmented_synthetic_value = .data$scm_synthetic_value + .data$augmentation_correction,
      scm_gap = .data$treated_value - .data$scm_synthetic_value,
      augmented_gap = .data$treated_value - .data$augmented_synthetic_value,
      outcome = outcome
    )

  weights <- tibble::tibble(
    donor_state = donor_states,
    scm_weight = as.numeric(scm_weights)
  ) |>
    dplyr::arrange(dplyr::desc(.data$scm_weight), .data$donor_state)

  rmspe <- path |>
    dplyr::group_by(.data$analysis_period) |>
    dplyr::summarise(
      scm_rmspe = sqrt(mean(.data$scm_gap^2, na.rm = TRUE)),
      augmented_rmspe = sqrt(mean(.data$augmented_gap^2, na.rm = TRUE)),
      scm_mean_gap = mean(.data$scm_gap, na.rm = TRUE),
      augmented_mean_gap = mean(.data$augmented_gap, na.rm = TRUE),
      n_periods = dplyr::n(),
      .groups = "drop"
    ) |>
    tidyr::pivot_wider(
      names_from = .data$analysis_period,
      values_from = c(.data$scm_rmspe, .data$augmented_rmspe, .data$scm_mean_gap, .data$augmented_mean_gap, .data$n_periods)
    ) |>
    dplyr::mutate(
      outcome = outcome,
      donor_count = length(donor_states),
      family = family,
      specification = specification,
      status = "estimated",
      skip_reason = NA_character_
    )

  output_dir <- file.path(output_root, family, specification)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  outcome_slug <- make_slug(outcome)

  readr::write_csv(path, file.path(output_dir, paste0(outcome_slug, "_path.csv")), na = "")
  readr::write_csv(weights, file.path(output_dir, paste0(outcome_slug, "_weights.csv")), na = "")

  path_plot <- ggplot2::ggplot(path, ggplot2::aes(x = .data$period_date)) +
    ggplot2::annotate(
      "rect",
      xmin = event$instability_start_date,
      xmax = event$removal_date,
      ymin = -Inf,
      ymax = Inf,
      fill = "gray85",
      alpha = 0.5
    ) +
    ggplot2::geom_line(ggplot2::aes(y = .data$treated_value, color = "Roraima"), linewidth = 0.9) +
    ggplot2::geom_line(ggplot2::aes(y = .data$augmented_synthetic_value, color = "Augmented synthetic"), linewidth = 0.9) +
    ggplot2::geom_vline(xintercept = event$instability_start_date, linetype = "dotted", color = "gray30") +
    ggplot2::geom_vline(xintercept = event$removal_date, linetype = "dashed", color = "gray10") +
    ggplot2::scale_color_manual(values = c("Roraima" = "#1f6f8b", "Augmented synthetic" = "#6a3d9a")) +
    ggplot2::labs(title = outcome, x = NULL, y = NULL, color = NULL) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "bottom")

  gap_plot <- ggplot2::ggplot(path, ggplot2::aes(x = .data$period_date, y = .data$augmented_gap)) +
    ggplot2::annotate(
      "rect",
      xmin = event$instability_start_date,
      xmax = event$removal_date,
      ymin = -Inf,
      ymax = Inf,
      fill = "gray85",
      alpha = 0.5
    ) +
    ggplot2::geom_hline(yintercept = 0, color = "gray70", linewidth = 0.4) +
    ggplot2::geom_line(color = "#6a3d9a", linewidth = 0.9) +
    ggplot2::geom_vline(xintercept = event$instability_start_date, linetype = "dotted", color = "gray30") +
    ggplot2::geom_vline(xintercept = event$removal_date, linetype = "dashed", color = "gray10") +
    ggplot2::labs(title = paste0(outcome, " gap"), x = NULL, y = NULL) +
    ggplot2::theme_minimal(base_size = 11)

  ggplot2::ggsave(file.path(output_dir, paste0(outcome_slug, "_path.png")), path_plot, width = 9, height = 5, dpi = 300, bg = "white")
  ggplot2::ggsave(file.path(output_dir, paste0(outcome_slug, "_gap.png")), gap_plot, width = 9, height = 5, dpi = 300, bg = "white")

  rmspe
}

specs <- list(
  list(
    data = monthly_panel,
    family = "monthly",
    specification = "raw",
    outcomes = c(
      "formal_hiring_balance_per_100k_wap",
      "formal_hiring_balance_construction_per_100k_wap",
      "retail_volume_index",
      "services_volume_index"
    )
  ),
  list(
    data = monthly_panel,
    family = "monthly",
    specification = "ma6_v4",
    outcomes = c(
      "formal_hiring_balance_per_100k_wap_ma6_v4",
      "formal_hiring_balance_construction_per_100k_wap_ma6_v4",
      "retail_volume_index_ma6_v4",
      "services_volume_index_ma6_v4"
    )
  ),
  list(
    data = fiscal_panel,
    family = "bimonthly_fiscal",
    specification = "raw",
    outcomes = c(
      "state_tax_revenue_real_pc",
      "icms_revenue_real_pc",
      "public_investment_liquidated_real_pc",
      "liquidated_expenditure_total_real_pc"
    )
  ),
  list(
    data = fiscal_panel,
    family = "bimonthly_fiscal",
    specification = "ma4_v4",
    outcomes = c(
      "state_tax_revenue_real_pc_ma4_v4",
      "icms_revenue_real_pc_ma4_v4",
      "public_investment_liquidated_real_pc_ma4_v4",
      "liquidated_expenditure_total_real_pc_ma4_v4"
    )
  )
)

summary <- purrr::map_dfr(
  specs,
  function(spec) {
    purrr::map_dfr(
      spec$outcomes,
      function(outcome) {
        fit_augmented_scm(
          data = spec$data,
          outcome = outcome,
          family = spec$family,
          specification = spec$specification
        )
      }
    )
  }
)

readr::write_csv(summary, file.path(output_root, "rr_2018_01_v4_scm_summary.csv"), na = "")

message("RR 2018-01 V4 SCM completed.")
message("Saved summary to: ", file.path(output_root, "rr_2018_01_v4_scm_summary.csv"))
