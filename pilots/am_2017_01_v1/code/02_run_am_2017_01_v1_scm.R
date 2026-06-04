source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

extra_packages <- c("tidyr", "quadprog", "ggplot2")
missing_extra <- extra_packages[!vapply(extra_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_extra) > 0) {
  stop("Missing required packages: ", paste(missing_extra, collapse = ", "))
}
invisible(lapply(extra_packages, library, character.only = TRUE))

pilot_id <- "am_2017_01_v1"
treated_state <- "AM"

pilot_root <- file.path(root_dir, "pilots", pilot_id)
data_dir <- file.path(pilot_root, "data")
output_root <- file.path(pilot_root, "output")
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

event <- readr::read_csv(
  file.path(data_dir, "am_2017_01_v1_event_metadata.csv"),
  show_col_types = FALSE
) |>
  dplyr::slice(1) |>
  dplyr::mutate(
    instability_start_date = as.Date(.data$instability_start_date),
    removal_date = as.Date(.data$removal_date)
  )

covariates <- readr::read_csv(
  file.path(data_dir, "am_2017_01_v1_covariates.csv"),
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
  file.path(data_dir, "am_2017_01_v1_monthly_panel.csv"),
  show_col_types = FALSE
) |>
  dplyr::mutate(period_date = as.Date(.data$period_date))

fiscal_panel <- readr::read_csv(
  file.path(data_dir, "am_2017_01_v1_bimonthly_fiscal_panel.csv"),
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

build_predictor_matrix <- function(data, outcome, donor_states, covariate_data,
                                   weight_period = "pre") {
  states <- c(treated_state, donor_states)

  period_filter <- if (weight_period == "pre_clean") {
    quote(.data$pre_instability_clean == TRUE)
  } else {
    quote(.data$analysis_period == "pre")
  }

  outcome_pre <- data |>
    dplyr::filter(!!period_filter, .data$state_abbrev %in% states) |>
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

fit_augmented_scm <- function(data, outcome, family, specification, plot_time_var,
                              weight_period = "pre") {
  lambda_grid <- 10^seq(-4, 5, length.out = 20)

  pre_filter <- if (weight_period == "pre_clean") {
    quote(.data$pre_instability_clean == TRUE)
  } else {
    quote(.data$analysis_period == "pre")
  }

  treated_pre_dates <- data |>
    dplyr::filter(
      .data$state_abbrev == treated_state,
      !!pre_filter,
      is.finite(.data[[outcome]])
    ) |>
    dplyr::arrange(.data$period_date) |>
    dplyr::pull(.data$period_date)

  if (length(treated_pre_dates) < 6) {
    return(tibble::tibble(
      family = family,
      specification = specification,
      outcome = outcome,
      status = "skipped",
      skip_reason = paste0("Treated state has incomplete pre-treatment data for outcome: ", outcome)
    ))
  }

  candidate_states <- intersect(
    main_donor_states,
    covariate_data$state_abbrev[stats::complete.cases(covariate_data[, -1])]
  )

  donor_states <- purrr::keep(
    candidate_states,
    function(state) {
      donor_pre <- data |>
        dplyr::filter(
          .data$state_abbrev == state,
          !!pre_filter,
          .data$period_date %in% treated_pre_dates
        ) |>
        dplyr::arrange(.data$period_date)

      nrow(donor_pre) == length(treated_pre_dates) &&
        all(is.finite(donor_pre[[outcome]]))
    }
  )

  if (length(donor_states) < 2) {
    return(tibble::tibble(
      family = family,
      specification = specification,
      outcome = outcome,
      status = "skipped",
      skip_reason = paste0("Fewer than two complete donor states for outcome: ", outcome)
    ))
  }

  predictor_matrix <- build_predictor_matrix(data, outcome, donor_states, covariate_data,
                                              weight_period = weight_period)
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

  index_tbl <- data |>
    dplyr::filter(.data$state_abbrev == treated_state) |>
    dplyr::transmute(
      .data$period_date,
      event_time = .data$event_time,
      plot_time = .data[[plot_time_var]],
      analysis_period = .data$analysis_period
    )

  wide <- data |>
    dplyr::filter(.data$state_abbrev %in% c(treated_state, donor_states)) |>
    dplyr::select(
      .data$period_date,
      .data$state_abbrev,
      value = dplyr::all_of(outcome)
    ) |>
    tidyr::pivot_wider(names_from = .data$state_abbrev, values_from = .data$value) |>
    dplyr::left_join(index_tbl, by = "period_date") |>
    dplyr::arrange(.data$event_time) |>
    dplyr::filter(stats::complete.cases(dplyr::across(dplyr::all_of(c(treated_state, donor_states)))))

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
        event_time = wide$event_time[[i]],
        plot_time = wide$plot_time[[i]],
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
      event_time = .data$event_time,
      plot_time = .data$plot_time,
      analysis_period = .data$analysis_period,
      treated_value = .data[[treated_state]],
      scm_synthetic_value = as.numeric(scm_synthetic)
    ) |>
    dplyr::left_join(correction_rows, by = c("period_date", "event_time", "plot_time")) |>
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
    (\(df) {
      needed_real <- c(
        "scm_rmspe_event", "augmented_rmspe_event", "scm_mean_gap_event", "augmented_mean_gap_event",
        "scm_rmspe_crisis", "augmented_rmspe_crisis", "scm_mean_gap_crisis", "augmented_mean_gap_crisis"
      )
      needed_int <- c("n_periods_event", "n_periods_crisis")

      for (nm in needed_real) {
        if (!nm %in% names(df)) {
          df[[nm]] <- NA_real_
        }
      }

      for (nm in needed_int) {
        if (!nm %in% names(df)) {
          df[[nm]] <- 0
        }
      }

      df
    })() |>
    dplyr::mutate(
      scm_rmspe_crisis = dplyr::coalesce(.data$scm_rmspe_event, .data$scm_rmspe_crisis),
      augmented_rmspe_crisis = dplyr::coalesce(.data$augmented_rmspe_event, .data$augmented_rmspe_crisis),
      scm_mean_gap_crisis = dplyr::coalesce(.data$scm_mean_gap_event, .data$scm_mean_gap_crisis),
      augmented_mean_gap_crisis = dplyr::coalesce(.data$augmented_mean_gap_event, .data$augmented_mean_gap_crisis),
      n_periods_crisis = dplyr::coalesce(.data$n_periods_event, .data$n_periods_crisis)
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

  rmspe
}

specs <- list(
  list(
    data = monthly_panel,
    family = "monthly",
    specification = "raw",
    plot_time_var = "event_time",
    weight_period = "pre",
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
    specification = "ma6_v5",
    plot_time_var = "plot_time_ma6_v5",
    weight_period = "pre",
    outcomes = c(
      "formal_hiring_balance_per_100k_wap_ma6_v5",
      "formal_hiring_balance_construction_per_100k_wap_ma6_v5",
      "retail_volume_index_ma6_v5",
      "services_volume_index_ma6_v5"
    )
  ),
  list(
    data = monthly_panel,
    family = "monthly",
    specification = "ma6_v5_instability",
    plot_time_var = "plot_time_ma6_v5",
    weight_period = "pre_clean",
    outcomes = c(
      "formal_hiring_balance_per_100k_wap_ma6_v5",
      "formal_hiring_balance_construction_per_100k_wap_ma6_v5",
      "retail_volume_index_ma6_v5",
      "services_volume_index_ma6_v5"
    )
  ),
  list(
    data = fiscal_panel,
    family = "bimonthly_fiscal",
    specification = "raw",
    plot_time_var = "event_time",
    weight_period = "pre",
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
    specification = "ma4_v5",
    plot_time_var = "plot_time_ma4_v5",
    weight_period = "pre",
    outcomes = c(
      "state_tax_revenue_real_pc_ma4_v5",
      "icms_revenue_real_pc_ma4_v5",
      "public_investment_liquidated_real_pc_ma4_v5",
      "liquidated_expenditure_total_real_pc_ma4_v5"
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
          specification = spec$specification,
          plot_time_var = spec$plot_time_var,
          weight_period = spec$weight_period
        )
      }
    )
  }
)

# === PLACEBO INFERENCE: LEAVE-ONE-OUT DONOR ===
# For each outcome, re-estimate the SCM with each donor removed in turn.
# Produces a distribution of treated-vs-synthetic gaps to assess whether the
# main estimate is driven by any single donor.

run_loo_placebo <- function(data, outcome, family, specification, plot_time_var,
                            weight_period = "pre") {
  pre_filter <- if (weight_period == "pre_clean") {
    quote(.data$pre_instability_clean == TRUE)
  } else {
    quote(.data$analysis_period == "pre")
  }

  treated_pre_dates <- data |>
    dplyr::filter(
      .data$state_abbrev == treated_state,
      !!pre_filter,
      is.finite(.data[[outcome]])
    ) |>
    dplyr::pull(.data$period_date)

  if (length(treated_pre_dates) < 6) {
    return(NULL)
  }

  candidate_states <- intersect(
    main_donor_states,
    covariate_data$state_abbrev[stats::complete.cases(covariate_data[, -1])]
  )

  full_donor_states <- purrr::keep(candidate_states, function(state) {
    dp <- data |>
      dplyr::filter(.data$state_abbrev == state, !!pre_filter,
                    .data$period_date %in% treated_pre_dates)
    nrow(dp) == length(treated_pre_dates) && all(is.finite(dp[[outcome]]))
  })

  if (length(full_donor_states) < 3) {
    return(NULL)
  }

  all_dates <- data |>
    dplyr::filter(.data$state_abbrev == treated_state) |>
    dplyr::arrange(.data$period_date) |>
    dplyr::pull(.data$period_date)

  index_tbl <- data |>
    dplyr::filter(.data$state_abbrev == treated_state) |>
    dplyr::transmute(.data$period_date, .data$event_time,
                     plot_time = .data[[plot_time_var]], .data$analysis_period)

  purrr::map_dfr(full_donor_states, function(dropped_state) {
    loo_donors <- setdiff(full_donor_states, dropped_state)
    if (length(loo_donors) < 2) {
      return(NULL)
    }

    pm <- tryCatch(
      build_predictor_matrix(data, outcome, loo_donors, covariate_data,
                             weight_period = weight_period),
      error = function(e) NULL
    )
    if (is.null(pm)) return(NULL)

    scaled <- standardize_predictors_by_row(pm)
    x1 <- scaled$x[, treated_state, drop = FALSE]
    x0 <- scaled$x[, loo_donors, drop = FALSE]
    w <- solve_scm_weights(x1, x0)
    names(w) <- loo_donors

    states_needed <- c(treated_state, loo_donors)
    wide <- data |>
      dplyr::filter(.data$state_abbrev %in% states_needed) |>
      dplyr::select(.data$period_date, .data$state_abbrev,
                    value = dplyr::all_of(outcome)) |>
      tidyr::pivot_wider(names_from = .data$state_abbrev, values_from = .data$value) |>
      dplyr::left_join(index_tbl, by = "period_date") |>
      dplyr::arrange(.data$event_time) |>
      dplyr::filter(stats::complete.cases(
        dplyr::across(dplyr::all_of(states_needed))
      ))

    synthetic <- as.matrix(wide[, loo_donors, drop = FALSE]) %*% w
    gap <- wide[[treated_state]] - as.numeric(synthetic)

    tibble::tibble(
      dropped_donor = dropped_state,
      period_date = wide$period_date,
      event_time = wide$event_time,
      plot_time = wide$plot_time,
      analysis_period = wide$analysis_period,
      loo_gap = gap
    )
  })
}

placebo_specs <- list(
  list(
    data = monthly_panel,
    family = "monthly",
    specification = "ma6_v5",
    plot_time_var = "plot_time_ma6_v5",
    weight_period = "pre",
    outcomes = c(
      "formal_hiring_balance_per_100k_wap_ma6_v5",
      "retail_volume_index_ma6_v5",
      "services_volume_index_ma6_v5"
    )
  ),
  list(
    data = fiscal_panel,
    family = "bimonthly_fiscal",
    specification = "ma4_v5",
    plot_time_var = "plot_time_ma4_v5",
    weight_period = "pre",
    outcomes = c(
      "icms_revenue_real_pc_ma4_v5",
      "public_investment_liquidated_real_pc_ma4_v5",
      "liquidated_expenditure_total_real_pc_ma4_v5"
    )
  )
)

placebo_output_dir <- file.path(output_root, "placebo_loo")
dir.create(placebo_output_dir, recursive = TRUE, showWarnings = FALSE)

purrr::walk(placebo_specs, function(spec) {
  purrr::walk(spec$outcomes, function(outcome) {
    loo <- run_loo_placebo(
      data = spec$data,
      outcome = outcome,
      family = spec$family,
      specification = spec$specification,
      plot_time_var = spec$plot_time_var,
      weight_period = spec$weight_period
    )
    if (!is.null(loo) && nrow(loo) > 0) {
      outcome_slug <- make_slug(outcome)
      out_path <- file.path(placebo_output_dir,
                            paste0(outcome_slug, "_", spec$specification, "_loo_placebo.csv"))
      readr::write_csv(loo, out_path, na = "")
      message("Saved LOO placebo: ", out_path)
    }
  })
})

readr::write_csv(summary, file.path(output_root, "am_2017_01_v1_scm_summary.csv"), na = "")

message("AM 2017-01 V1 SCM completed.")
message("Saved summary to: ", file.path(output_root, "am_2017_01_v1_scm_summary.csv"))

