source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

extra_packages <- c("tidyr", "quadprog", "ggplot2")
missing_extra <- extra_packages[!vapply(extra_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_extra) > 0) {
  stop("Missing required packages: ", paste(missing_extra, collapse = ", "))
}
invisible(lapply(extra_packages, library, character.only = TRUE))

pilot_id <- "rr_2018_01_v2"
treated_state <- "RR"
pilot_root <- file.path(root_dir, "pilots", pilot_id)
data_dir <- file.path(pilot_root, "data")
output_root <- file.path(pilot_root, "output")
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

covariates <- readr::read_csv(
  file.path(data_dir, "rr_2018_01_v2_covariates.csv"),
  show_col_types = FALSE
)

event <- readr::read_csv(
  file.path(data_dir, "rr_2018_01_v2_event_metadata.csv"),
  show_col_types = FALSE
) |>
  dplyr::slice(1) |>
  dplyr::mutate(
    instability_start_date = as.Date(instability_start_date),
    removal_date = as.Date(removal_date)
  )

lambda_grid <- 10^seq(-4, 5, length.out = 60)

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

  x_standardized <- sweep(x[keep_rows, , drop = FALSE], 1, row_means[keep_rows], "-")
  x_standardized <- sweep(x_standardized, 1, row_sds[keep_rows], "/")

  list(x = x_standardized, keep_rows = keep_rows)
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

standardize_unit_predictors <- function(x_train, x_all) {
  col_means <- colMeans(x_train, na.rm = TRUE)
  col_sds <- apply(x_train, 2, stats::sd, na.rm = TRUE)
  col_sds[!is.finite(col_sds) | col_sds == 0] <- 1

  list(
    x_all = sweep(sweep(x_all, 2, col_means, "-"), 2, col_sds, "/")
  )
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

get_complete_states <- function(data, outcome, covariate_data) {
  outcome_states <- data |>
    dplyr::filter(.data$analysis_period == "pre") |>
    dplyr::group_by(.data$state_abbrev) |>
    dplyr::summarise(
      complete_pre_periods = sum(is.finite(.data[[outcome]])),
      has_outcome = complete_pre_periods >= 6,
      .groups = "drop"
    ) |>
    dplyr::filter(.data$has_outcome) |>
    dplyr::pull(.data$state_abbrev)

  covariate_states <- covariate_data |>
    dplyr::filter(stats::complete.cases(dplyr::across(-.data$state_abbrev))) |>
    dplyr::pull(.data$state_abbrev)

  intersect(outcome_states, covariate_states)
}

build_predictor_matrix <- function(data, outcome, states, covariate_data) {
  outcome_predictors <- data |>
    dplyr::filter(
      .data$analysis_period == "pre",
      .data$state_abbrev %in% states
    ) |>
    dplyr::select(.data$state_abbrev, .data$period_date, value = dplyr::all_of(outcome)) |>
    tidyr::pivot_wider(names_from = .data$state_abbrev, values_from = .data$value) |>
    dplyr::arrange(.data$period_date) |>
    dplyr::filter(stats::complete.cases(dplyr::across(dplyr::all_of(states))))

  outcome_matrix <- outcome_predictors |>
    dplyr::select(dplyr::all_of(states)) |>
    as.matrix()
  rownames(outcome_matrix) <- paste0("pre_", format(outcome_predictors$period_date, "%Y_%m_%d"))

  covariate_matrix <- covariate_data |>
    dplyr::filter(.data$state_abbrev %in% states) |>
    dplyr::select(.data$state_abbrev, dplyr::everything()) |>
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
    stop("Missing values found in predictor matrix for outcome: ", outcome)
  }

  predictor_matrix
}

fit_augmented_scm <- function(data, outcome, covariate_data) {
  complete_states <- get_complete_states(data, outcome, covariate_data)
  donor_states <- setdiff(sort(complete_states), treated_state)

  if (!(treated_state %in% complete_states)) {
    stop("Treated state has incomplete pre-treatment data for outcome: ", outcome)
  }
  if (length(donor_states) < 2) {
    stop("Fewer than two donor states available for outcome: ", outcome)
  }

  states <- c(treated_state, donor_states)
  predictor_matrix <- build_predictor_matrix(data, outcome, states, covariate_data)

  scaled <- standardize_predictors_by_row(predictor_matrix)
  predictor_matrix_scaled <- scaled$x
  x1 <- predictor_matrix_scaled[, treated_state, drop = FALSE]
  x0 <- predictor_matrix_scaled[, donor_states, drop = FALSE]

  scm_weights <- solve_scm_weights(x1, x0)
  names(scm_weights) <- donor_states

  unit_predictors <- t(predictor_matrix)
  donor_predictors <- unit_predictors[donor_states, , drop = FALSE]
  all_predictors <- unit_predictors[states, , drop = FALSE]
  standardized_units <- standardize_unit_predictors(donor_predictors, all_predictors)

  treated_predictor <- standardized_units$x_all[treated_state, , drop = FALSE]
  donor_predictors_scaled <- standardized_units$x_all[donor_states, , drop = FALSE]
  weighted_donor_predictor <- matrix(as.numeric(t(scm_weights) %*% donor_predictors_scaled), nrow = 1)
  predictor_imbalance <- treated_predictor - weighted_donor_predictor

  wide <- data |>
    dplyr::filter(.data$state_abbrev %in% states) |>
    dplyr::select(.data$period_date, .data$analysis_period, .data$state_abbrev, value = dplyr::all_of(outcome)) |>
    tidyr::pivot_wider(names_from = .data$state_abbrev, values_from = .data$value) |>
    dplyr::arrange(.data$period_date) |>
    dplyr::filter(stats::complete.cases(dplyr::across(dplyr::all_of(states))))

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
      donor_count = length(donor_states)
    )

  list(path = path, weights = weights, rmspe = rmspe)
}

plot_paths <- function(path, outcome, output_path) {
  ggplot2::ggplot(path, ggplot2::aes(x = .data$period_date)) +
    ggplot2::geom_rect(
      ggplot2::aes(
        xmin = event$instability_start_date,
        xmax = event$removal_date,
        ymin = -Inf,
        ymax = Inf
      ),
      inherit.aes = FALSE,
      fill = "gray85",
      alpha = 0.5
    ) +
    ggplot2::geom_line(ggplot2::aes(y = .data$treated_value, color = "RR"), linewidth = 0.8) +
    ggplot2::geom_line(ggplot2::aes(y = .data$scm_synthetic_value, color = "Classic SCM"), linewidth = 0.75) +
    ggplot2::geom_line(ggplot2::aes(y = .data$augmented_synthetic_value, color = "Augmented SCM"), linewidth = 0.8) +
    ggplot2::geom_vline(xintercept = event$instability_start_date, linetype = "dotted", color = "gray30") +
    ggplot2::geom_vline(xintercept = event$removal_date, linetype = "dashed", color = "gray10") +
    ggplot2::scale_color_manual(values = c("RR" = "#1f6f8b", "Classic SCM" = "#c65a2e", "Augmented SCM" = "#6a3d9a")) +
    ggplot2::labs(
      title = paste0("RR 2018-01 V2: ", outcome),
      subtitle = "Dotted line = instability start; dashed line = effective removal",
      x = NULL,
      y = outcome,
      color = NULL
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "bottom")
}

plot_gaps <- function(path, outcome) {
  path |>
    dplyr::select(.data$period_date, .data$scm_gap, .data$augmented_gap) |>
    tidyr::pivot_longer(-.data$period_date, names_to = "gap_type", values_to = "gap") |>
    dplyr::mutate(
      gap_type = dplyr::recode(
        .data$gap_type,
        scm_gap = "Classic SCM",
        augmented_gap = "Augmented SCM"
      )
    ) |>
    ggplot2::ggplot(ggplot2::aes(x = .data$period_date, y = .data$gap, color = .data$gap_type)) +
    ggplot2::geom_rect(
      ggplot2::aes(
        xmin = event$instability_start_date,
        xmax = event$removal_date,
        ymin = -Inf,
        ymax = Inf
      ),
      inherit.aes = FALSE,
      fill = "gray85",
      alpha = 0.5
    ) +
    ggplot2::geom_hline(yintercept = 0, color = "gray70", linewidth = 0.3) +
    ggplot2::geom_line(linewidth = 0.8) +
    ggplot2::geom_vline(xintercept = event$instability_start_date, linetype = "dotted", color = "gray30") +
    ggplot2::geom_vline(xintercept = event$removal_date, linetype = "dashed", color = "gray10") +
    ggplot2::scale_color_manual(values = c("Classic SCM" = "#c65a2e", "Augmented SCM" = "#6a3d9a")) +
    ggplot2::labs(
      title = paste0("RR 2018-01 V2 gaps: ", outcome),
      subtitle = "Dotted line = instability start; dashed line = effective removal",
      x = NULL,
      y = "RR - Synthetic RR",
      color = NULL
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "bottom")
}

run_outcome <- function(data, outcome, family, specification) {
  output_path <- file.path(output_root, family, specification)
  dir.create(output_path, recursive = TRUE, showWarnings = FALSE)

  outcome_slug <- make_slug(outcome)
  fit <- tryCatch(
    fit_augmented_scm(data, outcome, covariates),
    error = function(e) e
  )

  if (inherits(fit, "error")) {
    skipped <- tibble::tibble(
      outcome = outcome,
      family = family,
      specification = specification,
      status = "skipped",
      skip_reason = conditionMessage(fit)
    )
    readr::write_csv(skipped, file.path(output_path, paste0(outcome_slug, "_skipped.csv")), na = "")
    return(skipped)
  }

  readr::write_csv(fit$path, file.path(output_path, paste0(outcome_slug, "_path.csv")), na = "")
  readr::write_csv(fit$weights, file.path(output_path, paste0(outcome_slug, "_weights.csv")), na = "")
  readr::write_csv(fit$rmspe, file.path(output_path, paste0(outcome_slug, "_rmspe.csv")), na = "")

  ggplot2::ggsave(
    file.path(output_path, paste0(outcome_slug, "_path.png")),
    plot_paths(fit$path, outcome, output_path),
    width = 9,
    height = 5,
    dpi = 300,
    bg = "white"
  )

  ggplot2::ggsave(
    file.path(output_path, paste0(outcome_slug, "_gaps.png")),
    plot_gaps(fit$path, outcome),
    width = 9,
    height = 5,
    dpi = 300,
    bg = "white"
  )

  fit$rmspe |>
    dplyr::mutate(
      family = family,
      specification = specification,
      outcome = outcome,
      status = "estimated",
      skip_reason = NA_character_
    )
}

run_visual_for_clean_outcome <- function(data, clean_outcome, visual_outcome, family, specification) {
  clean_output_path <- file.path(output_root, family, specification)
  output_path <- file.path(clean_output_path, "visual_partial_window")
  dir.create(output_path, recursive = TRUE, showWarnings = FALSE)

  clean_slug <- make_slug(clean_outcome)
  clean_path_file <- file.path(clean_output_path, paste0(clean_slug, "_path.csv"))
  if (!file.exists(clean_path_file)) {
    return(tibble::tibble(
      outcome = visual_outcome,
      family = family,
      specification = paste0(specification, "_visual"),
      status = "skipped",
      skip_reason = paste0("Clean path not found for ", clean_outcome)
    ))
  }

  clean_path <- readr::read_csv(clean_path_file, show_col_types = FALSE) |>
    dplyr::select(
      "period_date",
      "analysis_period",
      clean_treated_value = "treated_value",
      clean_scm_synthetic_value = "scm_synthetic_value",
      clean_augmented_synthetic_value = "augmented_synthetic_value"
    ) |>
    dplyr::mutate(period_date = as.Date(.data$period_date))

  visual_values <- data |>
    dplyr::filter(.data$state_abbrev == treated_state) |>
    dplyr::select(
      .data$period_date,
      visual_treated_value = dplyr::all_of(visual_outcome)
    ) |>
    dplyr::mutate(period_date = as.Date(.data$period_date))

  plot_data <- clean_path |>
    dplyr::left_join(visual_values, by = "period_date") |>
    dplyr::mutate(
      display_treated_value = dplyr::coalesce(
        .data$clean_treated_value,
        .data$visual_treated_value
      )
    )

  plot <- ggplot2::ggplot(plot_data, ggplot2::aes(x = .data$period_date)) +
    ggplot2::annotate(
      "rect",
      xmin = event$instability_start_date,
      xmax = event$removal_date,
      ymin = -Inf,
      ymax = Inf,
      fill = "gray85",
      alpha = 0.5
    ) +
    ggplot2::geom_line(ggplot2::aes(y = .data$display_treated_value, color = "RR visual MA"), linewidth = 0.8) +
    ggplot2::geom_line(ggplot2::aes(y = .data$clean_scm_synthetic_value, color = "Classic SCM clean MA"), linewidth = 0.75) +
    ggplot2::geom_line(ggplot2::aes(y = .data$clean_augmented_synthetic_value, color = "Augmented SCM clean MA"), linewidth = 0.8) +
    ggplot2::geom_vline(xintercept = event$instability_start_date, linetype = "dotted", color = "gray30") +
    ggplot2::geom_vline(xintercept = event$removal_date, linetype = "dashed", color = "gray10") +
    ggplot2::scale_color_manual(values = c(
      "RR visual MA" = "#1f6f8b",
      "Classic SCM clean MA" = "#c65a2e",
      "Augmented SCM clean MA" = "#6a3d9a"
    )) +
    ggplot2::labs(
      title = paste0("RR 2018-01 V2 visual partial-window MA: ", visual_outcome),
      subtitle = "Treated line uses partial-window MA inside each segment; synthetic lines use clean complete-window MA",
      x = NULL,
      y = visual_outcome,
      color = NULL
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "bottom")

  visual_slug <- make_slug(visual_outcome)
  readr::write_csv(plot_data, file.path(output_path, paste0(visual_slug, "_plot_data.csv")), na = "")
  ggplot2::ggsave(
    file.path(output_path, paste0(visual_slug, "_visual_path.png")),
    plot,
    width = 9,
    height = 5,
    dpi = 300,
    bg = "white"
  )

  tibble::tibble(
    outcome = visual_outcome,
    family = family,
    specification = paste0(specification, "_visual"),
    status = "visual_only",
    skip_reason = NA_character_
  )
}

monthly_panel <- readr::read_csv(
  file.path(data_dir, "rr_2018_01_v2_monthly_panel.csv"),
  show_col_types = FALSE
) |>
  dplyr::mutate(period_date = as.Date(period_date))

fiscal_panel <- readr::read_csv(
  file.path(data_dir, "rr_2018_01_v2_bimonthly_fiscal_panel.csv"),
  show_col_types = FALSE
) |>
  dplyr::mutate(period_date = as.Date(period_date))

quarterly_panel <- readr::read_csv(
  file.path(data_dir, "rr_2018_01_v2_quarterly_pnadc_panel.csv"),
  show_col_types = FALSE
) |>
  dplyr::mutate(period_date = as.Date(period_date))

specs <- list(
  list(
    data = monthly_panel,
    family = "monthly",
    specification = "raw",
    outcomes = c(
      "formal_hiring_balance_per_100k_wap",
      "retail_volume_index",
      "services_volume_index"
    )
  ),
  list(
    data = monthly_panel,
    family = "monthly",
    specification = "ma6_clean",
    outcomes = c(
      "formal_hiring_balance_per_100k_wap_ma6_clean",
      "retail_volume_index_ma6_clean",
      "services_volume_index_ma6_clean"
    )
  ),
  list(
    data = fiscal_panel,
    family = "bimonthly_fiscal",
    specification = "raw",
    outcomes = c(
      "state_tax_revenue_real_pc",
      "public_investment_liquidated_real_pc",
      "liquidated_expenditure_total_real_pc"
    )
  ),
  list(
    data = fiscal_panel,
    family = "bimonthly_fiscal",
    specification = "ma4_clean",
    outcomes = c(
      "state_tax_revenue_real_pc_ma4_clean",
      "public_investment_liquidated_real_pc_ma4_clean",
      "liquidated_expenditure_total_real_pc_ma4_clean"
    )
  )
)

summary <- purrr::map_dfr(
  specs,
  function(spec) {
    purrr::map_dfr(
      spec$outcomes,
      function(outcome) {
        run_outcome(
          data = spec$data,
          outcome = outcome,
          family = spec$family,
          specification = spec$specification
        )
      }
    )
  }
)

visual_specs <- list(
  list(
    data = monthly_panel,
    family = "monthly",
    specification = "ma6_clean",
    clean_visual_pairs = tibble::tribble(
      ~clean_outcome, ~visual_outcome,
      "formal_hiring_balance_per_100k_wap_ma6_clean", "formal_hiring_balance_per_100k_wap_ma6_visual",
      "retail_volume_index_ma6_clean", "retail_volume_index_ma6_visual",
      "services_volume_index_ma6_clean", "services_volume_index_ma6_visual"
    )
  ),
  list(
    data = fiscal_panel,
    family = "bimonthly_fiscal",
    specification = "ma4_clean",
    clean_visual_pairs = tibble::tribble(
      ~clean_outcome, ~visual_outcome,
      "state_tax_revenue_real_pc_ma4_clean", "state_tax_revenue_real_pc_ma4_visual",
      "public_investment_liquidated_real_pc_ma4_clean", "public_investment_liquidated_real_pc_ma4_visual",
      "liquidated_expenditure_total_real_pc_ma4_clean", "liquidated_expenditure_total_real_pc_ma4_visual"
    )
  )
)

visual_summary <- purrr::map_dfr(
  visual_specs,
  function(spec) {
    purrr::pmap_dfr(
      spec$clean_visual_pairs,
      function(clean_outcome, visual_outcome) {
        run_visual_for_clean_outcome(
          data = spec$data,
          clean_outcome = clean_outcome,
          visual_outcome = visual_outcome,
          family = spec$family,
          specification = spec$specification
        )
      }
    )
  }
)

summary <- dplyr::bind_rows(summary, visual_summary)

readr::write_csv(summary, file.path(output_root, "rr_2018_01_v2_scm_summary.csv"), na = "")

message("RR 2018-01 V2 SCM completed.")
message("Saved summary to: ", file.path(output_root, "rr_2018_01_v2_scm_summary.csv"))
