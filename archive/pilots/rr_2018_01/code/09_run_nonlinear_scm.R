source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

if (!requireNamespace("CVXR", quietly = TRUE)) {
  stop("Missing required package: CVXR")
}
library(CVXR)

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

output_dir <- file.path(pilot_root, "output", "nonlinear_scm_monthly")
employment_rate_output_dir <- file.path(pilot_root, "output", "nonlinear_scm_monthly_employment_per_100k")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(employment_rate_output_dir, recursive = TRUE, showWarnings = FALSE)

trailing_partial_mean <- function(x, window) {
  purrr::map_dbl(
    seq_along(x),
    function(i) {
      start_i <- max(1, i - window + 1)
      mean(x[start_i:i], na.rm = TRUE)
    }
  )
}

add_post_clean_ma6_columns <- function(data) {
  data |>
    dplyr::group_by(state_abbrev, analysis_period) |>
    dplyr::arrange(period_date, .by_group = TRUE) |>
    dplyr::mutate(
      formal_hiring_balance_ma6_post_clean = trailing_partial_mean(formal_hiring_balance, 6),
      retail_volume_index_ma6_post_clean = trailing_partial_mean(retail_volume_index, 6),
      services_volume_index_ma6_post_clean = trailing_partial_mean(services_volume_index, 6)
    ) |>
    dplyr::ungroup()
}

add_employment_rate_columns <- function(data) {
  data |>
    dplyr::mutate(
      formal_hiring_balance_per_100k = 100000 * formal_hiring_balance / pnadc_population
    ) |>
    dplyr::group_by(state_abbrev, analysis_period) |>
    dplyr::arrange(period_date, .by_group = TRUE) |>
    dplyr::mutate(
      formal_hiring_balance_per_100k_ma6_post_clean = trailing_partial_mean(
        formal_hiring_balance_per_100k,
        6
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

standardize_rows <- function(z) {
  row_means <- rowMeans(z, na.rm = TRUE)
  row_sds <- apply(z, 1, stats::sd, na.rm = TRUE)
  keep <- is.finite(row_sds) & row_sds > 0

  z_scaled <- sweep(z[keep, , drop = FALSE], 1, row_means[keep], "-")
  z_scaled <- sweep(z_scaled, 1, row_sds[keep], "/")
  z_scaled
}

positive_eigenvalues <- function(x) {
  eig <- sort(Re(base::eigen(x, symmetric = TRUE, only.values = TRUE)$values))
  eig[eig > sqrt(.Machine$double.eps)]
}

scale_tuning_parameters <- function(z0, a_star, b_star) {
  eig_b <- positive_eigenvalues(tcrossprod(z0))
  if (length(eig_b) == 0) {
    eig_b <- 1
  }

  b_raw <- if (b_star <= 0) {
    0
  } else {
    b_star * eig_b[max(1, ceiling(length(eig_b) * b_star))]
  }

  eig_a <- positive_eigenvalues(tcrossprod(z0) + b_raw * base::diag(nrow(z0)))
  if (length(eig_a) == 0) {
    eig_a <- 1
  }

  a_raw <- if (a_star <= 0) {
    0
  } else {
    a_star * eig_a[max(1, ceiling(length(eig_a) * a_star))]
  }

  list(a = a_raw, b = b_raw)
}

solve_nsc_weights <- function(z1, z0, a_star, b_star) {
  tuning <- scale_tuning_parameters(z0, a_star, b_star)
  distances <- sqrt(colSums((z0 - as.numeric(z1))^2))

  w <- CVXR::Variable(ncol(z0))
  objective <- CVXR::Minimize(
    CVXR::sum_squares(z1 - z0 %*% w) +
      tuning$a * sum(distances * abs(w)) +
      tuning$b * CVXR::sum_squares(w)
  )
  constraints <- list(CVXR::sum_entries(w) == 1)

  problem <- CVXR::Problem(objective, constraints)
  result <- solve(problem, solver = "OSQP", verbose = FALSE)

  if (!result$status %in% c("optimal", "optimal_inaccurate")) {
    result <- solve(problem, solver = "CLARABEL", verbose = FALSE)
  }

  if (!result$status %in% c("optimal", "optimal_inaccurate")) {
    stop("NSC optimization failed with status: ", result$status)
  }

  as.numeric(result$getValue(w))
}

build_matching_matrix <- function(data, outcome, states, covariates) {
  pre_data <- data |>
    dplyr::filter(analysis_period == "pre")

  outcome_matrix <- pre_data |>
    dplyr::filter(state_abbrev %in% states) |>
    dplyr::select(state_abbrev, period_date, value = dplyr::all_of(outcome)) |>
    tidyr::pivot_wider(names_from = state_abbrev, values_from = value) |>
    dplyr::arrange(period_date)

  z_outcome <- outcome_matrix |>
    dplyr::select(dplyr::all_of(states)) |>
    as.matrix()

  rownames(z_outcome) <- paste0("lag_", format(outcome_matrix$period_date, "%Y_%m"))

  if (length(covariates) == 0) {
    return(z_outcome)
  }

  z_covariates <- pre_data |>
    dplyr::filter(
      state_abbrev %in% states,
      pnadc_predictor_valid
    ) |>
    dplyr::group_by(state_abbrev) |>
    dplyr::summarise(
      dplyr::across(dplyr::all_of(covariates), ~mean(.x, na.rm = TRUE)),
      .groups = "drop"
    ) |>
    tidyr::pivot_longer(-state_abbrev, names_to = "predictor", values_to = "value") |>
    tidyr::pivot_wider(names_from = state_abbrev, values_from = value) |>
    dplyr::arrange(predictor)

  z_covariate_matrix <- z_covariates |>
    dplyr::select(dplyr::all_of(states)) |>
    as.matrix()

  rownames(z_covariate_matrix) <- paste0("mean_", z_covariates$predictor)
  rbind(z_outcome, z_covariate_matrix)
}

prepare_outcome_data <- function(data, outcome, treated_state_code, donor_states) {
  states <- c(treated_state_code, donor_states)

  wide <- data |>
    dplyr::filter(state_abbrev %in% states) |>
    dplyr::select(period_date, analysis_period, state_abbrev, value = dplyr::all_of(outcome)) |>
    tidyr::pivot_wider(names_from = state_abbrev, values_from = value) |>
    dplyr::arrange(period_date)

  if (anyNA(wide |> dplyr::select(dplyr::all_of(states)))) {
    stop("Missing outcome values found for outcome: ", outcome)
  }

  wide
}

fit_nsc_given_tuning <- function(data, outcome, treated_state_code, donor_states, covariates, a_star, b_star) {
  states <- c(treated_state_code, donor_states)
  z <- build_matching_matrix(data, outcome, states, covariates)
  z <- standardize_rows(z)

  z1 <- z[, treated_state_code, drop = FALSE]
  z0 <- z[, donor_states, drop = FALSE]
  weights <- solve_nsc_weights(z1, z0, a_star, b_star)
  names(weights) <- donor_states

  wide <- prepare_outcome_data(data, outcome, treated_state_code, donor_states)
  counterfactual <- as.matrix(wide[, donor_states, drop = FALSE]) %*% weights

  path <- wide |>
    dplyr::transmute(
      period_date,
      analysis_period,
      treated_value = .data[[treated_state_code]],
      synthetic_value = as.numeric(counterfactual),
      gap = treated_value - synthetic_value,
      outcome = outcome
    )

  list(
    path = path,
    weights = tibble::tibble(
      donor_state = donor_states,
      weight = as.numeric(weights)
    ) |>
      dplyr::arrange(dplyr::desc(abs(weight)), donor_state),
    z = z
  )
}

cv_score_controls <- function(data, outcome, donor_states, covariates, a_star, b_star) {
  errors <- purrr::map_dbl(
    donor_states,
    function(pseudo_treated) {
      pseudo_donors <- setdiff(donor_states, pseudo_treated)
      fit <- fit_nsc_given_tuning(
        data = data,
        outcome = outcome,
        treated_state_code = pseudo_treated,
        donor_states = pseudo_donors,
        covariates = covariates,
        a_star = a_star,
        b_star = b_star
      )

      pre_path <- fit$path |>
        dplyr::filter(analysis_period == "pre")

      mean(pre_path$gap^2, na.rm = TRUE)
    }
  )

  mean(errors, na.rm = TRUE)
}

select_tuning_parameters <- function(data, outcome, donor_states, covariates, grid, max_iterations = 3) {
  a_star <- 0
  b_star <- 0
  trace <- tibble::tibble()

  for (iteration in seq_len(max_iterations)) {
    a_scores <- purrr::map_dfr(
      grid,
      function(candidate_a) {
        tibble::tibble(
          iteration = iteration,
          step = "a",
          a_star = candidate_a,
          b_star = b_star,
          cv_mspe = cv_score_controls(data, outcome, donor_states, covariates, candidate_a, b_star)
        )
      }
    )
    a_star_new <- a_scores |>
      dplyr::arrange(cv_mspe, a_star) |>
      dplyr::slice(1) |>
      dplyr::pull(a_star)

    b_scores <- purrr::map_dfr(
      grid,
      function(candidate_b) {
        tibble::tibble(
          iteration = iteration,
          step = "b",
          a_star = a_star_new,
          b_star = candidate_b,
          cv_mspe = cv_score_controls(data, outcome, donor_states, covariates, a_star_new, candidate_b)
        )
      }
    )
    b_star_new <- b_scores |>
      dplyr::arrange(cv_mspe, b_star) |>
      dplyr::slice(1) |>
      dplyr::pull(b_star)

    trace <- dplyr::bind_rows(trace, a_scores, b_scores)

    if (identical(a_star, a_star_new) && identical(b_star, b_star_new)) {
      break
    }

    a_star <- a_star_new
    b_star <- b_star_new
  }

  list(
    a_star = a_star,
    b_star = b_star,
    cv_trace = trace
  )
}

doudchenko_imbens_inference <- function(data, outcome, donor_states, covariates, a_star, b_star, alpha = 0.05) {
  residuals <- purrr::map_dfr(
    donor_states,
    function(pseudo_treated) {
      pseudo_donors <- setdiff(donor_states, pseudo_treated)
      fit <- fit_nsc_given_tuning(
        data = data,
        outcome = outcome,
        treated_state_code = pseudo_treated,
        donor_states = pseudo_donors,
        covariates = covariates,
        a_star = a_star,
        b_star = b_star
      )

      fit$path |>
        dplyr::transmute(
          period_date,
          pseudo_treated = pseudo_treated,
          residual = gap
        )
    }
  )

  period_variance <- residuals |>
    dplyr::group_by(period_date) |>
    dplyr::summarise(
      period_variance = mean(residual^2, na.rm = TRUE),
      period_se = sqrt(period_variance),
      .groups = "drop"
    )

  z_value <- stats::qnorm(1 - alpha / 2)

  list(
    period_variance = period_variance,
    z_value = z_value
  )
}

run_outcome <- function(outcome, output_path = output_dir) {
  message("Running NSC for: ", outcome)

  covariates <- c("unemployment_rate_pnadc", "formalization_rate_pnadc")
  donor_states <- panel |>
    dplyr::filter(donor_pool_main) |>
    dplyr::distinct(state_abbrev) |>
    dplyr::arrange(state_abbrev) |>
    dplyr::pull(state_abbrev)

  tuning <- select_tuning_parameters(
    data = panel,
    outcome = outcome,
    donor_states = donor_states,
    covariates = covariates,
    grid = seq(0, 1, by = 0.1),
    max_iterations = 3
  )

  fit <- fit_nsc_given_tuning(
    data = panel,
    outcome = outcome,
    treated_state_code = treated_state,
    donor_states = donor_states,
    covariates = covariates,
    a_star = tuning$a_star,
    b_star = tuning$b_star
  )

  inference <- doudchenko_imbens_inference(
    data = panel,
    outcome = outcome,
    donor_states = donor_states,
    covariates = covariates,
    a_star = tuning$a_star,
    b_star = tuning$b_star,
    alpha = 0.05
  )

  path <- fit$path |>
    dplyr::left_join(inference$period_variance, by = "period_date") |>
    dplyr::mutate(
      gap_lower = gap - inference$z_value * period_se,
      gap_upper = gap + inference$z_value * period_se,
      a_star = tuning$a_star,
      b_star = tuning$b_star
    )

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
    )

  post_path <- path |>
    dplyr::filter(analysis_period == "post")

  att <- mean(post_path$gap, na.rm = TRUE)
  att_se <- sqrt(mean(post_path$period_variance, na.rm = TRUE)) / sqrt(nrow(post_path))
  att_lower <- att - inference$z_value * att_se
  att_upper <- att + inference$z_value * att_se
  p_value <- 2 * stats::pnorm(abs(att / att_se), lower.tail = FALSE)

  summary <- rmspe |>
    dplyr::mutate(
      outcome = outcome,
      a_star = tuning$a_star,
      b_star = tuning$b_star,
      post_pre_rmspe_ratio = rmspe_post / rmspe_pre,
      att = att,
      att_se = att_se,
      att_lower = att_lower,
      att_upper = att_upper,
      p_value = p_value,
      negative_weight_sum = sum(abs(fit$weights$weight[fit$weights$weight < 0])),
      effective_donors = 1 / sum(fit$weights$weight^2)
    )

  outcome_slug <- make_slug(outcome)

  readr::write_csv(
    path,
    file.path(output_path, paste0(outcome_slug, "_path.csv")),
    na = ""
  )

  readr::write_csv(
    fit$weights,
    file.path(output_path, paste0(outcome_slug, "_weights.csv")),
    na = ""
  )

  readr::write_csv(
    tuning$cv_trace,
    file.path(output_path, paste0(outcome_slug, "_cv_trace.csv")),
    na = ""
  )

  readr::write_csv(
    summary,
    file.path(output_path, paste0(outcome_slug, "_summary.csv")),
    na = ""
  )

  path_plot <- ggplot2::ggplot(path, ggplot2::aes(x = period_date)) +
    ggplot2::geom_line(ggplot2::aes(y = treated_value, color = "RR"), linewidth = 0.8) +
    ggplot2::geom_line(ggplot2::aes(y = synthetic_value, color = "Nonlinear SCM"), linewidth = 0.8) +
    ggplot2::geom_vline(xintercept = as.Date("2019-01-01"), linetype = "dashed", color = "gray35") +
    ggplot2::scale_color_manual(values = c("RR" = "#1f6f8b", "Nonlinear SCM" = "#7b4ab0")) +
    ggplot2::labs(
      title = paste0("RR 2018 nonlinear SCM: ", outcome),
      x = NULL,
      y = outcome,
      color = NULL
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "bottom")

  ggplot2::ggsave(
    file.path(output_path, paste0(outcome_slug, "_treated_vs_nonlinear_scm.png")),
    path_plot,
    width = 9,
    height = 5,
    dpi = 300,
    bg = "white"
  )

  gap_line_plot <- ggplot2::ggplot(path, ggplot2::aes(x = period_date, y = gap)) +
    ggplot2::geom_hline(yintercept = 0, color = "gray70", linewidth = 0.3) +
    ggplot2::geom_line(color = "#7b4ab0", linewidth = 0.8) +
    ggplot2::geom_vline(xintercept = as.Date("2019-01-01"), linetype = "dashed", color = "gray35") +
    ggplot2::labs(
      title = paste0("RR 2018 nonlinear SCM gap: ", outcome),
      x = NULL,
      y = "RR - Nonlinear SCM"
    ) +
    ggplot2::theme_minimal(base_size = 11)

  ggplot2::ggsave(
    file.path(output_path, paste0(outcome_slug, "_gap.png")),
    gap_line_plot,
    width = 9,
    height = 5,
    dpi = 300,
    bg = "white"
  )

  gap_plot <- ggplot2::ggplot(path, ggplot2::aes(x = period_date, y = gap)) +
    ggplot2::geom_ribbon(
      ggplot2::aes(ymin = gap_lower, ymax = gap_upper),
      fill = "#7b4ab0",
      alpha = 0.18
    ) +
    ggplot2::geom_hline(yintercept = 0, color = "gray70", linewidth = 0.3) +
    ggplot2::geom_line(color = "#7b4ab0", linewidth = 0.8) +
    ggplot2::geom_vline(xintercept = as.Date("2019-01-01"), linetype = "dashed", color = "gray35") +
    ggplot2::labs(
      title = paste0("RR 2018 nonlinear SCM gap: ", outcome),
      x = NULL,
      y = "RR - Nonlinear SCM"
    ) +
    ggplot2::theme_minimal(base_size = 11)

  ggplot2::ggsave(
    file.path(output_path, paste0(outcome_slug, "_gap_ci.png")),
    gap_plot,
    width = 9,
    height = 5,
    dpi = 300,
    bg = "white"
  )

  summary
}

panel <- readr::read_csv(monthly_panel_path, show_col_types = FALSE) |>
  dplyr::mutate(
    period_date = as.Date(period_date),
    state_abbrev = as.character(state_abbrev),
    treated_unit = as.logical(treated_unit),
    donor_pool_main = as.logical(donor_pool_main),
    pnadc_predictor_valid = as.logical(pnadc_predictor_valid)
  ) |>
  dplyr::filter(monthly_main_window) |>
  dplyr::arrange(state_abbrev, period_date) |>
  add_post_clean_ma6_columns() |>
  add_employment_rate_columns()

outcomes <- c(
  "formal_hiring_balance",
  "formal_hiring_balance_ma6_post_clean",
  "retail_volume_index",
  "retail_volume_index_ma6_post_clean",
  "services_volume_index",
  "services_volume_index_ma6_post_clean"
)

summary <- purrr::map_dfr(outcomes, run_outcome) |>
  dplyr::select(
    outcome,
    a_star,
    b_star,
    rmspe_pre,
    rmspe_post,
    post_pre_rmspe_ratio,
    mean_gap_pre,
    mean_gap_post,
    att,
    att_se,
    att_lower,
    att_upper,
    p_value,
    negative_weight_sum,
    effective_donors
  )

readr::write_csv(
  summary,
  file.path(output_dir, "nonlinear_scm_monthly_summary.csv"),
  na = ""
)

employment_rate_outcomes <- c(
  "formal_hiring_balance_per_100k",
  "formal_hiring_balance_per_100k_ma6_post_clean"
)

employment_rate_summary <- purrr::map_dfr(
  employment_rate_outcomes,
  ~run_outcome(.x, output_path = employment_rate_output_dir)
) |>
  dplyr::select(
    outcome,
    a_star,
    b_star,
    rmspe_pre,
    rmspe_post,
    post_pre_rmspe_ratio,
    mean_gap_pre,
    mean_gap_post,
    att,
    att_se,
    att_lower,
    att_upper,
    p_value,
    negative_weight_sum,
    effective_donors
  )

readr::write_csv(
  employment_rate_summary,
  file.path(employment_rate_output_dir, "nonlinear_scm_monthly_employment_per_100k_summary.csv"),
  na = ""
)

message("RR 2018 nonlinear SCM monthly models completed.")
message("Saved outputs to: ", output_dir)
message("Saved employment per-100k outputs to: ", employment_rate_output_dir)
