source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

pilot_id <- "rr_2018_01"
treated_state <- "RR"
excluded_donor_states <- c("RR", "AM", "TO")

monthly_pre_start <- as.Date("2016-01-01")
monthly_pre_end <- as.Date("2018-11-01")
monthly_transition_month <- as.Date("2018-12-01")
monthly_post_start <- as.Date("2019-01-01")
monthly_post_end <- as.Date("2020-12-01")
monthly_post_end_pre_caged_break <- as.Date("2019-12-01")

fiscal_pre_start <- "2015B1"
fiscal_pre_end <- "2018B5"
fiscal_transition_period <- "2018B6"
fiscal_post_start <- "2019B1"
fiscal_post_end <- "2020B6"

pnadc_transition_period <- "2018Q4"

pilot_root <- file.path(root_dir, "pilots", pilot_id)
path_pilot_data <- file.path(pilot_root, "data")
path_pilot_output <- file.path(pilot_root, "output")

dir.create(path_pilot_data, recursive = TRUE, showWarnings = FALSE)
dir.create(path_pilot_output, recursive = TRUE, showWarnings = FALSE)

read_processed <- function(file_name) {
  readr::read_csv(file.path(path_data_processed, file_name), show_col_types = FALSE)
}

standardize_monthly_panel <- function(data, value_columns) {
  data |>
    dplyr::mutate(
      period_date = as.Date(period_date),
      state_abbrev = as.character(state_abbrev)
    ) |>
    dplyr::select(
      period_date,
      year,
      month,
      uf,
      state_abbrev,
      state_name,
      macroregion,
      dplyr::all_of(value_columns)
    )
}

caged <- read_processed("caged_state_balance_monthly_panel_ready.csv") |>
  standardize_monthly_panel(c(
    "formal_hiring_balance",
    "post_2020_caged_dummy",
    "caged_method_break_dummy"
  ))

pmc <- read_processed("pmc_retail_monthly_panel_ready.csv") |>
  standardize_monthly_panel(c(
    "retail_volume_index",
    "retail_nominal_revenue_index"
  )) |>
  dplyr::select(period_date, state_abbrev, retail_volume_index, retail_nominal_revenue_index)

pms <- read_processed("pms_services_monthly_panel_ready.csv") |>
  standardize_monthly_panel(c(
    "services_volume_index",
    "services_nominal_revenue_index"
  )) |>
  dplyr::select(period_date, state_abbrev, services_volume_index, services_nominal_revenue_index)

pnadc <- read_processed("pnadc_sidra_quarterly_state_covariates_panel_ready.csv") |>
  dplyr::mutate(
    pnadc_period = as.character(period),
    pnadc_period_date = as.Date(period_date),
    state_abbrev = as.character(state_abbrev),
    pnadc_transition_quarter = pnadc_period == pnadc_transition_period
  ) |>
  dplyr::select(
    pnadc_period,
    pnadc_period_date,
    state_abbrev,
    pnadc_population,
    unemployment_rate_pnadc,
    labor_income_real_pnadc,
    informality_rate_pnadc,
    formalization_rate_pnadc,
    pnadc_transition_quarter
  )

monthly_panel <- caged |>
  dplyr::left_join(pmc, by = c("period_date", "state_abbrev")) |>
  dplyr::left_join(pms, by = c("period_date", "state_abbrev")) |>
  dplyr::mutate(
    pnadc_period_date = lubridate::floor_date(period_date, unit = "quarter")
  ) |>
  dplyr::left_join(pnadc, by = c("pnadc_period_date", "state_abbrev")) |>
  dplyr::mutate(
    pilot_id = pilot_id,
    treated_unit = state_abbrev == treated_state,
    donor_pool_main = !(state_abbrev %in% excluded_donor_states),
    excluded_from_main_donor_pool = state_abbrev %in% excluded_donor_states,
    transition_period = period_date == monthly_transition_month,
    pnadc_predictor_valid = pnadc_period != pnadc_transition_period,
    analysis_period = dplyr::case_when(
      period_date >= monthly_pre_start & period_date <= monthly_pre_end ~ "pre",
      period_date == monthly_transition_month ~ "transition",
      period_date >= monthly_post_start & period_date <= monthly_post_end ~ "post",
      TRUE ~ "outside_window"
    ),
    post_treatment = analysis_period == "post",
    treated_post = treated_unit & post_treatment,
    post_2020_caged_dummy = as.integer(post_2020_caged_dummy),
    caged_method_break_dummy = as.integer(caged_method_break_dummy),
    caged_break_control = post_2020_caged_dummy,
    monthly_main_window = analysis_period %in% c("pre", "post"),
    monthly_pre_2020_robustness_window = analysis_period == "pre" |
      (period_date >= monthly_post_start & period_date <= monthly_post_end_pre_caged_break)
  ) |>
  dplyr::filter(
    period_date >= monthly_pre_start,
    period_date <= monthly_post_end,
    !transition_period
  ) |>
  dplyr::arrange(period_date, state_abbrev)

monthly_outcomes <- c(
  "formal_hiring_balance",
  "retail_volume_index",
  "services_volume_index"
)

monthly_covariates <- c(
  "retail_volume_index",
  "services_volume_index",
  "formal_hiring_balance",
  "unemployment_rate_pnadc",
  "formalization_rate_pnadc"
)

monthly_missing_summary <- monthly_panel |>
  dplyr::filter(monthly_main_window) |>
  dplyr::summarise(
    dplyr::across(
      dplyr::all_of(unique(c(monthly_outcomes, monthly_covariates))),
      ~sum(is.na(.x)),
      .names = "missing_{.col}"
    )
  ) |>
  tidyr::pivot_longer(
    dplyr::everything(),
    names_to = "variable",
    values_to = "missing_rows"
  ) |>
  dplyr::mutate(variable = stringr::str_remove(variable, "^missing_"))

monthly_coverage <- monthly_panel |>
  dplyr::count(period_date, analysis_period, name = "rows") |>
  dplyr::left_join(
    monthly_panel |>
      dplyr::group_by(period_date) |>
      dplyr::summarise(
        n_states = dplyr::n_distinct(state_abbrev),
        n_main_donors = dplyr::n_distinct(state_abbrev[donor_pool_main]),
        treated_present = any(treated_unit),
        .groups = "drop"
      ),
    by = "period_date"
  ) |>
  dplyr::arrange(period_date)

monthly_pre_post_summary <- monthly_panel |>
  dplyr::filter(monthly_main_window) |>
  dplyr::group_by(
    state_group = dplyr::if_else(treated_unit, "treated_rr", "main_donor_pool"),
    analysis_period
  ) |>
  dplyr::filter(treated_unit | donor_pool_main) |>
  dplyr::summarise(
    rows = dplyr::n(),
    states = dplyr::n_distinct(state_abbrev),
    formal_hiring_balance_mean = mean(formal_hiring_balance, na.rm = TRUE),
    retail_volume_index_mean = mean(retail_volume_index, na.rm = TRUE),
    services_volume_index_mean = mean(services_volume_index, na.rm = TRUE),
    unemployment_rate_pnadc_mean = mean(unemployment_rate_pnadc, na.rm = TRUE),
    formalization_rate_pnadc_mean = mean(formalization_rate_pnadc, na.rm = TRUE),
    .groups = "drop"
  )

siconfi <- read_processed("siconfi_rreo_state_fiscal_bimonthly_panel_ready.csv") |>
  dplyr::mutate(
    period = as.character(period),
    period_date = as.Date(period_date),
    state_abbrev = as.character(state_abbrev),
    social_expenditure_share_real = (
      liquidated_expenditure_health_real +
        liquidated_expenditure_education_real +
        liquidated_expenditure_public_security_real
    ) / liquidated_expenditure_total_real,
    pilot_id = pilot_id,
    treated_unit = state_abbrev == treated_state,
    donor_pool_main = !(state_abbrev %in% excluded_donor_states),
    excluded_from_main_donor_pool = state_abbrev %in% excluded_donor_states,
    transition_period = period == fiscal_transition_period,
    analysis_period = dplyr::case_when(
      period >= fiscal_pre_start & period <= fiscal_pre_end ~ "pre",
      period == fiscal_transition_period ~ "transition",
      period >= fiscal_post_start & period <= fiscal_post_end ~ "post",
      TRUE ~ "outside_window"
    ),
    post_treatment = analysis_period == "post",
    treated_post = treated_unit & post_treatment,
    fiscal_main_window = analysis_period %in% c("pre", "post")
  ) |>
  dplyr::filter(
    period >= fiscal_pre_start,
    period <= fiscal_post_end,
    !transition_period
  ) |>
  dplyr::arrange(year, bimester, state_abbrev)

fiscal_outcomes <- c(
  "liquidated_expenditure_total_real",
  "social_expenditure_share_real",
  "total_revenue_real",
  "own_revenue_ratio"
)

fiscal_covariates <- c(
  "total_revenue_real",
  "state_tax_revenue_real",
  "own_revenue_ratio"
)

fiscal_missing_summary <- siconfi |>
  dplyr::filter(fiscal_main_window) |>
  dplyr::summarise(
    dplyr::across(
      dplyr::all_of(unique(c(fiscal_outcomes, fiscal_covariates))),
      ~sum(is.na(.x)),
      .names = "missing_{.col}"
    )
  ) |>
  tidyr::pivot_longer(
    dplyr::everything(),
    names_to = "variable",
    values_to = "missing_rows"
  ) |>
  dplyr::mutate(variable = stringr::str_remove(variable, "^missing_"))

fiscal_coverage <- siconfi |>
  dplyr::count(period, period_date, analysis_period, name = "rows") |>
  dplyr::left_join(
    siconfi |>
      dplyr::group_by(period, period_date) |>
      dplyr::summarise(
        n_states = dplyr::n_distinct(state_abbrev),
        n_main_donors = dplyr::n_distinct(state_abbrev[donor_pool_main]),
        treated_present = any(treated_unit),
        .groups = "drop"
      ),
    by = c("period", "period_date")
  ) |>
  dplyr::arrange(period_date)

fiscal_pre_post_summary <- siconfi |>
  dplyr::filter(fiscal_main_window) |>
  dplyr::group_by(
    state_group = dplyr::if_else(treated_unit, "treated_rr", "main_donor_pool"),
    analysis_period
  ) |>
  dplyr::filter(treated_unit | donor_pool_main) |>
  dplyr::summarise(
    rows = dplyr::n(),
    states = dplyr::n_distinct(state_abbrev),
    liquidated_expenditure_total_real_mean = mean(liquidated_expenditure_total_real, na.rm = TRUE),
    social_expenditure_share_real_mean = mean(social_expenditure_share_real, na.rm = TRUE),
    total_revenue_real_mean = mean(total_revenue_real, na.rm = TRUE),
    own_revenue_ratio_mean = mean(own_revenue_ratio, na.rm = TRUE),
    .groups = "drop"
  )

readr::write_csv(
  monthly_panel,
  file.path(path_pilot_data, "rr_2018_01_monthly_panel.csv"),
  na = ""
)

readr::write_csv(
  siconfi,
  file.path(path_pilot_data, "rr_2018_01_fiscal_bimonthly_panel.csv"),
  na = ""
)

readr::write_csv(
  monthly_coverage,
  file.path(path_pilot_output, "rr_2018_01_monthly_coverage.csv"),
  na = ""
)

readr::write_csv(
  monthly_missing_summary,
  file.path(path_pilot_output, "rr_2018_01_monthly_missing_summary.csv"),
  na = ""
)

readr::write_csv(
  monthly_pre_post_summary,
  file.path(path_pilot_output, "rr_2018_01_monthly_pre_post_summary.csv"),
  na = ""
)

readr::write_csv(
  fiscal_coverage,
  file.path(path_pilot_output, "rr_2018_01_fiscal_coverage.csv"),
  na = ""
)

readr::write_csv(
  fiscal_missing_summary,
  file.path(path_pilot_output, "rr_2018_01_fiscal_missing_summary.csv"),
  na = ""
)

readr::write_csv(
  fiscal_pre_post_summary,
  file.path(path_pilot_output, "rr_2018_01_fiscal_pre_post_summary.csv"),
  na = ""
)

message("RR 2018 pilot panels built.")
message("Saved data to: ", path_pilot_data)
message("Saved validation outputs to: ", path_pilot_output)
