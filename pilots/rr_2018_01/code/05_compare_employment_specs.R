source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

pilot_id <- "rr_2018_01"
pilot_root <- file.path(root_dir, "pilots", pilot_id)

panel_path <- file.path(
  pilot_root,
  "data",
  "rr_2018_01_monthly_panel.csv"
)

output_dir <- file.path(pilot_root, "output", "employment_alternative_specs")
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

add_employment_moving_averages <- function(data, reset_at_treatment = FALSE, suffix = "") {
  grouping_vars <- if (reset_at_treatment) {
    c("state_abbrev", "analysis_period")
  } else {
    "state_abbrev"
  }

  data |>
    dplyr::group_by(dplyr::across(dplyr::all_of(grouping_vars))) |>
    dplyr::arrange(period_date, .by_group = TRUE) |>
    dplyr::mutate(
      "{paste0('formal_hiring_balance_ma3', suffix)}" := trailing_partial_mean(formal_hiring_balance, 3),
      "{paste0('formal_hiring_balance_ma6', suffix)}" := trailing_partial_mean(formal_hiring_balance, 6)
    ) |>
    dplyr::ungroup()
}

panel <- readr::read_csv(panel_path, show_col_types = FALSE) |>
  dplyr::mutate(
    period_date = as.Date(period_date),
    state_abbrev = as.character(state_abbrev)
  ) |>
  dplyr::filter(monthly_main_window) |>
  dplyr::arrange(state_abbrev, period_date) |>
  add_employment_moving_averages(reset_at_treatment = FALSE) |>
  add_employment_moving_averages(reset_at_treatment = TRUE, suffix = "_post_clean") |>
  dplyr::group_by(state_abbrev) |>
  dplyr::mutate(
    formal_hiring_balance_6m_sum = trailing_partial_sum(formal_hiring_balance, 6),
    formal_hiring_balance_cumulative = cumsum(formal_hiring_balance)
  ) |>
  dplyr::ungroup()

spec_paths <- tibble::tribble(
  ~spec_id, ~outcome, ~path,
  "baseline_monthly_lags", "formal_hiring_balance", file.path(pilot_root, "output", "scm_monthly", "formal_hiring_balance_treated_synthetic_path.csv"),
  "level_semester_predictors", "formal_hiring_balance", file.path(pilot_root, "output", "employment_alternative_specs", "level_semester_predictors", "treated_synthetic_path.csv"),
  "moving_average_3m", "formal_hiring_balance_ma3", file.path(pilot_root, "output", "scm_monthly_moving_average", "formal_hiring_balance_ma3_treated_synthetic_path.csv"),
  "moving_average_6m", "formal_hiring_balance_ma6", file.path(pilot_root, "output", "scm_monthly_moving_average", "formal_hiring_balance_ma6_treated_synthetic_path.csv"),
  "moving_average_3m_post_clean", "formal_hiring_balance_ma3_post_clean", file.path(pilot_root, "output", "scm_monthly_moving_average_post_clean", "formal_hiring_balance_ma3_treated_synthetic_path.csv"),
  "moving_average_6m_post_clean", "formal_hiring_balance_ma6_post_clean", file.path(pilot_root, "output", "scm_monthly_moving_average_post_clean", "formal_hiring_balance_ma6_treated_synthetic_path.csv"),
  "six_month_sum", "formal_hiring_balance_6m_sum", file.path(pilot_root, "output", "employment_alternative_specs", "six_month_sum", "treated_synthetic_path.csv"),
  "cumulative_since_2016", "formal_hiring_balance_cumulative", file.path(pilot_root, "output", "employment_alternative_specs", "cumulative_since_2016", "treated_synthetic_path.csv")
)

comparison <- purrr::pmap_dfr(
  spec_paths,
  function(spec_id, outcome, path) {
    path_data <- readr::read_csv(path, show_col_types = FALSE)

    pre_path <- path_data |>
      dplyr::filter(analysis_period == "pre")

    post_path <- path_data |>
      dplyr::filter(analysis_period == "post")

    treated_pre <- panel |>
      dplyr::filter(
        state_abbrev == "RR",
        analysis_period == "pre"
      ) |>
      dplyr::pull(dplyr::all_of(outcome))

    tibble::tibble(
      spec_id = spec_id,
      outcome = outcome,
      pre_rmspe = sqrt(mean(pre_path$gap^2, na.rm = TRUE)),
      post_rmspe = sqrt(mean(post_path$gap^2, na.rm = TRUE)),
      post_pre_rmspe_ratio = post_rmspe / pre_rmspe,
      treated_pre_sd = stats::sd(treated_pre, na.rm = TRUE),
      pre_rmspe_over_treated_sd = pre_rmspe / treated_pre_sd,
      pre_correlation = stats::cor(
        pre_path$treated_value,
        pre_path$synthetic_value,
        use = "complete.obs"
      ),
      pre_mean_gap = mean(pre_path$gap, na.rm = TRUE),
      post_mean_gap = mean(post_path$gap, na.rm = TRUE)
    )
  }
) |>
  dplyr::arrange(pre_rmspe_over_treated_sd)

readr::write_csv(
  comparison,
  file.path(output_dir, "employment_specs_normalized_comparison.csv"),
  na = ""
)

message("Saved employment specification normalized comparison.")
