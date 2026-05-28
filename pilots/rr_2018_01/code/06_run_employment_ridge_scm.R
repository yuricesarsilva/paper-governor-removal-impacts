source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

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

output_dir <- file.path(pilot_root, "output", "employment_ridge_scm")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

trailing_partial_mean <- function(x, window) {
  purrr::map_dbl(
    seq_along(x),
    function(i) {
      start_i <- max(1, i - window + 1)
      mean(x[start_i:i], na.rm = TRUE)
    }
  )
}

trailing_partial_sum <- function(x, window) {
  purrr::map_dbl(
    seq_along(x),
    function(i) {
      start_i <- max(1, i - window + 1)
      sum(x[start_i:i], na.rm = TRUE)
    }
  )
}

panel <- readr::read_csv(monthly_panel_path, show_col_types = FALSE) |>
  dplyr::mutate(
    period_date = as.Date(period_date),
    state_abbrev = as.character(state_abbrev),
    donor_pool_main = as.logical(donor_pool_main)
  ) |>
  dplyr::filter(monthly_main_window) |>
  dplyr::arrange(state_abbrev, period_date) |>
  dplyr::group_by(state_abbrev) |>
  dplyr::mutate(
    formal_hiring_balance_ma6 = trailing_partial_mean(formal_hiring_balance, 6),
    formal_hiring_balance_6m_sum = trailing_partial_sum(formal_hiring_balance, 6)
  ) |>
  dplyr::ungroup()

lambda_grid <- 10^seq(-4, 6, length.out = 80)

make_slug <- function(x) {
  x |>
    stringr::str_replace_all("[^A-Za-z0-9]+", "_") |>
    stringr::str_replace_all("_+$", "") |>
    tolower()
}

standardize_design <- function(x_pre, x_all) {
  col_means <- colMeans(x_pre, na.rm = TRUE)
  col_sds <- apply(x_pre, 2, stats::sd, na.rm = TRUE)
  col_sds[!is.finite(col_sds) | col_sds == 0] <- 1

  list(
    x_pre = sweep(sweep(x_pre, 2, col_means, "-"), 2, col_sds, "/"),
    x_all = sweep(sweep(x_all, 2, col_means, "-"), 2, col_sds, "/"),
    col_means = col_means,
    col_sds = col_sds
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

loocv_lambda <- function(x_pre, y_pre, lambdas) {
  cv <- purrr::map_dfr(
    lambdas,
    function(lambda) {
      errors <- purrr::map_dbl(
        seq_along(y_pre),
        function(i) {
          coef <- fit_ridge(x_pre[-i, , drop = FALSE], y_pre[-i], lambda)
          y_hat <- predict_ridge(x_pre[i, , drop = FALSE], coef)
          y_pre[i] - y_hat
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

fit_ridge_synthetic <- function(data, outcome) {
  donor_states <- data |>
    dplyr::filter(donor_pool_main) |>
    dplyr::distinct(state_abbrev) |>
    dplyr::arrange(state_abbrev) |>
    dplyr::pull(state_abbrev)

  wide <- data |>
    dplyr::filter(state_abbrev %in% c(treated_state, donor_states)) |>
    dplyr::select(period_date, analysis_period, state_abbrev, value = dplyr::all_of(outcome)) |>
    tidyr::pivot_wider(names_from = state_abbrev, values_from = value) |>
    dplyr::arrange(period_date)

  pre_rows <- wide$analysis_period == "pre"

  y_pre <- wide[[treated_state]][pre_rows]
  y_center <- mean(y_pre, na.rm = TRUE)
  y_scale <- stats::sd(y_pre, na.rm = TRUE)
  if (!is.finite(y_scale) || y_scale == 0) {
    y_scale <- 1
  }
  y_pre_scaled <- (y_pre - y_center) / y_scale

  x_pre_raw <- as.matrix(wide[pre_rows, donor_states, drop = FALSE])
  x_all_raw <- as.matrix(wide[, donor_states, drop = FALSE])
  x_scaled <- standardize_design(x_pre_raw, x_all_raw)

  best_lambda <- loocv_lambda(x_scaled$x_pre, y_pre_scaled, lambda_grid)
  coef <- fit_ridge(x_scaled$x_pre, y_pre_scaled, best_lambda$lambda)

  synthetic_scaled <- predict_ridge(x_scaled$x_all, coef)
  synthetic <- synthetic_scaled * y_scale + y_center

  path <- wide |>
    dplyr::transmute(
      period_date,
      analysis_period,
      treated_value = .data[[treated_state]],
      synthetic_value = synthetic,
      gap = treated_value - synthetic,
      outcome = outcome,
      lambda = best_lambda$lambda,
      cv_rmse = best_lambda$cv_rmse
    )

  coefficients <- tibble::tibble(
    donor_state = donor_states,
    coefficient = coef[-1]
  ) |>
    dplyr::arrange(dplyr::desc(abs(coefficient)), donor_state)

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
    dplyr::mutate(
      outcome = outcome,
      lambda = best_lambda$lambda,
      cv_rmse = best_lambda$cv_rmse,
      post_pre_rmspe_ratio = rmspe_post / rmspe_pre
    )

  list(
    path = path,
    coefficients = coefficients,
    rmspe = rmspe
  )
}

run_outcome <- function(outcome) {
  outcome_slug <- make_slug(outcome)
  fit <- fit_ridge_synthetic(panel, outcome)

  readr::write_csv(
    fit$path,
    file.path(output_dir, paste0(outcome_slug, "_treated_synthetic_path.csv")),
    na = ""
  )

  readr::write_csv(
    fit$coefficients,
    file.path(output_dir, paste0(outcome_slug, "_coefficients.csv")),
    na = ""
  )

  readr::write_csv(
    fit$rmspe,
    file.path(output_dir, paste0(outcome_slug, "_rmspe.csv")),
    na = ""
  )

  path_plot <- ggplot2::ggplot(fit$path, ggplot2::aes(x = period_date)) +
    ggplot2::geom_line(ggplot2::aes(y = treated_value, color = "RR"), linewidth = 0.8) +
    ggplot2::geom_line(ggplot2::aes(y = synthetic_value, color = "Ridge synthetic RR"), linewidth = 0.8) +
    ggplot2::geom_vline(xintercept = as.Date("2019-01-01"), linetype = "dashed", color = "gray35") +
    ggplot2::scale_color_manual(values = c("RR" = "#1f6f8b", "Ridge synthetic RR" = "#7b4ab0")) +
    ggplot2::labs(
      title = paste0("RR 2018 ridge synthetic employment: ", outcome),
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

  gap_plot <- ggplot2::ggplot(fit$path, ggplot2::aes(x = period_date, y = gap)) +
    ggplot2::geom_hline(yintercept = 0, color = "gray70", linewidth = 0.3) +
    ggplot2::geom_line(color = "#7b4ab0", linewidth = 0.8) +
    ggplot2::geom_vline(xintercept = as.Date("2019-01-01"), linetype = "dashed", color = "gray35") +
    ggplot2::labs(
      title = paste0("RR 2018 ridge synthetic gap: ", outcome),
      x = NULL,
      y = "RR - Ridge synthetic RR"
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

  fit$rmspe
}

outcomes <- c(
  "formal_hiring_balance",
  "formal_hiring_balance_ma6",
  "formal_hiring_balance_6m_sum"
)

ridge_summary <- purrr::map_dfr(outcomes, run_outcome)

readr::write_csv(
  ridge_summary,
  file.path(output_dir, "ridge_employment_summary.csv"),
  na = ""
)

message("RR 2018 employment ridge synthetic controls completed.")
message("Saved outputs to: ", output_dir)
