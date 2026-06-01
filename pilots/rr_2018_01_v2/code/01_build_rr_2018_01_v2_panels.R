source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

extra_packages <- c("tidyr")
missing_extra <- extra_packages[!vapply(extra_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_extra) > 0) {
  stop("Missing required packages: ", paste(missing_extra, collapse = ", "))
}
invisible(lapply(extra_packages, library, character.only = TRUE))

pilot_id <- "rr_2018_01_v2"
event_id <- "RR_2018_01"
treated_state <- "RR"
pilot_root <- file.path(root_dir, "pilots", pilot_id)
pilot_data_dir <- file.path(pilot_root, "data")
dir.create(pilot_data_dir, recursive = TRUE, showWarnings = FALSE)

event <- readr::read_csv(
  file.path(root_dir, "data", "raw", "governor_removal_events.csv"),
  show_col_types = FALSE
) |>
  dplyr::filter(.data$event_id == !!event_id) |>
  dplyr::slice(1)

instability_start_date <- as.Date(event$instability_start_date)
removal_date <- as.Date(event$removal_date)

monthly_window_start <- as.Date("2015-11-01")
monthly_window_end <- as.Date("2020-12-01")
bimonthly_window_start <- as.Date("2015-01-01")
bimonthly_window_end <- as.Date("2020-12-01")
quarterly_window_start <- as.Date("2015-01-01")
quarterly_window_end <- as.Date("2020-12-31")

assign_period_monthly <- function(period_date) {
  dplyr::case_when(
    period_date < lubridate::floor_date(instability_start_date, "month") ~ "pre",
    period_date < lubridate::ceiling_date(removal_date, "month") ~ "crisis",
    TRUE ~ "post"
  )
}

assign_period_bimonthly <- function(year, bimester) {
  dplyr::case_when(
    year < 2018 ~ "pre",
    year == 2018 & bimester <= 5 ~ "pre",
    year == 2018 & bimester == 6 ~ "crisis",
    TRUE ~ "post"
  )
}

assign_period_quarterly <- function(year, quarter) {
  dplyr::case_when(
    year < 2018 ~ "pre",
    year == 2018 & quarter <= 3 ~ "pre",
    year == 2018 & quarter == 4 ~ "crisis",
    TRUE ~ "post"
  )
}

complete_trailing_mean <- function(x, window) {
  purrr::map_dbl(
    seq_along(x),
    function(i) {
      if (i < window) {
        return(NA_real_)
      }
      mean(x[(i - window + 1):i], na.rm = TRUE)
    }
  )
}

partial_trailing_mean <- function(x, window) {
  purrr::map_dbl(
    seq_along(x),
    function(i) {
      start_i <- max(1, i - window + 1)
      mean(x[start_i:i], na.rm = TRUE)
    }
  )
}

add_clean_ma <- function(data, vars, window) {
  data |>
    dplyr::group_by(.data$state_abbrev, .data$analysis_period) |>
    dplyr::arrange(.data$period_date, .by_group = TRUE) |>
    dplyr::mutate(
      dplyr::across(
        dplyr::all_of(vars),
        ~complete_trailing_mean(.x, window),
        .names = "{.col}_ma{window}_clean"
      )
    ) |>
    dplyr::ungroup()
}

add_visual_ma <- function(data, vars, window) {
  data |>
    dplyr::group_by(.data$state_abbrev, .data$analysis_period) |>
    dplyr::arrange(.data$period_date, .by_group = TRUE) |>
    dplyr::mutate(
      dplyr::across(
        dplyr::all_of(vars),
        ~partial_trailing_mean(.x, window),
        .names = "{.col}_ma{window}_visual"
      )
    ) |>
    dplyr::ungroup()
}

pnadc <- readr::read_csv(
  file.path(root_dir, "data", "processed", "pnadc_sidra_quarterly_state_covariates_panel_ready.csv"),
  show_col_types = FALSE
) |>
  dplyr::mutate(
    period_date = as.Date(period_date),
    year = as.integer(year),
    quarter = as.integer(quarter),
    pnadc_population = as.numeric(pnadc_population),
    unemployment_rate_pnadc = as.numeric(unemployment_rate_pnadc),
    formalization_rate_pnadc = as.numeric(formalization_rate_pnadc),
    labor_income_real_pnadc = as.numeric(labor_income_real_pnadc)
  )

monthly_pnadc <- pnadc |>
  dplyr::select(
    state_abbrev,
    year,
    quarter,
    pnadc_population,
    unemployment_rate_pnadc,
    formalization_rate_pnadc
  )

caged <- readr::read_csv(
  file.path(root_dir, "data", "processed", "caged_state_balance_monthly_panel_ready.csv"),
  show_col_types = FALSE
) |>
  dplyr::mutate(period_date = as.Date(period_date))

pmc <- readr::read_csv(
  file.path(root_dir, "data", "processed", "pmc_retail_monthly_panel_ready.csv"),
  show_col_types = FALSE
) |>
  dplyr::mutate(period_date = as.Date(period_date)) |>
  dplyr::filter(.data$include_in_panel == 1)

pms <- readr::read_csv(
  file.path(root_dir, "data", "processed", "pms_services_monthly_panel_ready.csv"),
  show_col_types = FALSE
) |>
  dplyr::mutate(period_date = as.Date(period_date)) |>
  dplyr::filter(.data$include_in_panel == 1)

monthly_panel <- caged |>
  dplyr::select(
    period_date,
    year,
    month,
    state_abbrev,
    state_name,
    macroregion,
    formal_hiring_balance,
    post_2020_caged_dummy,
    caged_method_break_dummy,
    source_regime,
    source_component,
    series_version
  ) |>
  dplyr::left_join(
    pmc |>
      dplyr::select(period_date, state_abbrev, retail_volume_index),
    by = c("period_date", "state_abbrev")
  ) |>
  dplyr::left_join(
    pms |>
      dplyr::select(period_date, state_abbrev, services_volume_index),
    by = c("period_date", "state_abbrev")
  ) |>
  dplyr::mutate(quarter = lubridate::quarter(period_date)) |>
  dplyr::left_join(
    monthly_pnadc,
    by = c("state_abbrev", "year", "quarter")
  ) |>
  dplyr::mutate(
    treated_unit = .data$state_abbrev == treated_state,
    analysis_period = assign_period_monthly(.data$period_date),
    formal_hiring_balance_per_100k_wap = 100000 * .data$formal_hiring_balance / .data$pnadc_population,
    instability_start_date = instability_start_date,
    removal_date = removal_date
  ) |>
  dplyr::filter(
    .data$period_date >= monthly_window_start,
    .data$period_date <= monthly_window_end
  ) |>
  add_clean_ma(
    vars = c(
      "formal_hiring_balance_per_100k_wap",
      "retail_volume_index",
      "services_volume_index"
    ),
    window = 6
  ) |>
  add_visual_ma(
    vars = c(
      "formal_hiring_balance_per_100k_wap",
      "retail_volume_index",
      "services_volume_index"
    ),
    window = 6
  )

fiscal_raw <- readr::read_csv(
  file.path(root_dir, "data", "processed", "siconfi_rreo_state_fiscal_bimonthly_panel_ready.csv"),
  show_col_types = FALSE
) |>
  dplyr::mutate(
    period_date = as.Date(period_date),
    year = as.integer(year),
    bimester = as.integer(bimester),
    quarter = lubridate::quarter(period_date)
  )

fiscal_panel <- fiscal_raw |>
  dplyr::left_join(
    pnadc |>
      dplyr::select(state_abbrev, year, quarter, pnadc_population),
    by = c("state_abbrev", "year", "quarter")
  ) |>
  dplyr::mutate(
    treated_unit = .data$state_abbrev == treated_state,
    analysis_period = assign_period_bimonthly(.data$year, .data$bimester),
    state_tax_revenue_real_pc = .data$state_tax_revenue_real / .data$pnadc_population,
    public_investment_liquidated_real_pc = .data$public_investment_liquidated_real / .data$pnadc_population,
    liquidated_expenditure_total_real_pc = .data$liquidated_expenditure_total_real / .data$pnadc_population,
    liquidated_expenditure_health_real_pc = .data$liquidated_expenditure_health_real / .data$pnadc_population,
    liquidated_expenditure_education_real_pc = .data$liquidated_expenditure_education_real / .data$pnadc_population,
    liquidated_expenditure_public_security_real_pc = .data$liquidated_expenditure_public_security_real / .data$pnadc_population,
    instability_start_date = instability_start_date,
    removal_date = removal_date
  ) |>
  dplyr::filter(
    .data$period_date >= bimonthly_window_start,
    .data$period_date <= bimonthly_window_end
  ) |>
  add_clean_ma(
    vars = c(
      "state_tax_revenue_real_pc",
      "public_investment_liquidated_real_pc",
      "liquidated_expenditure_total_real_pc"
    ),
    window = 4
  ) |>
  add_visual_ma(
    vars = c(
      "state_tax_revenue_real_pc",
      "public_investment_liquidated_real_pc",
      "liquidated_expenditure_total_real_pc"
    ),
    window = 4
  )

quarterly_panel <- pnadc |>
  dplyr::mutate(
    treated_unit = .data$state_abbrev == treated_state,
    analysis_period = assign_period_quarterly(.data$year, .data$quarter),
    instability_start_date = instability_start_date,
    removal_date = removal_date
  ) |>
  dplyr::filter(
    .data$period_date >= quarterly_window_start,
    .data$period_date <= quarterly_window_end
  )

pnadc_covariates <- quarterly_panel |>
  dplyr::filter(.data$analysis_period == "pre") |>
  dplyr::group_by(.data$state_abbrev) |>
  dplyr::summarise(
    unemployment_rate = mean(.data$unemployment_rate_pnadc, na.rm = TRUE),
    formalization_rate = mean(.data$formalization_rate_pnadc, na.rm = TRUE),
    .groups = "drop"
  )

fiscal_covariates <- fiscal_panel |>
  dplyr::filter(.data$analysis_period == "pre") |>
  dplyr::group_by(.data$state_abbrev) |>
  dplyr::summarise(
    transfer_dependency_ratio = mean(.data$transfer_dependency_ratio, na.rm = TRUE),
    liquidated_expenditure_health_real_pc = mean(.data$liquidated_expenditure_health_real_pc, na.rm = TRUE),
    liquidated_expenditure_education_real_pc = mean(.data$liquidated_expenditure_education_real_pc, na.rm = TRUE),
    liquidated_expenditure_public_security_real_pc = mean(.data$liquidated_expenditure_public_security_real_pc, na.rm = TRUE),
    .groups = "drop"
  )

covariate_panel <- pnadc_covariates |>
  dplyr::left_join(fiscal_covariates, by = "state_abbrev")

event_metadata <- event |>
  dplyr::select(
    event_id,
    state_abbrev,
    state_name,
    governor_name,
    removal_date,
    instability_start_date,
    instability_start_type,
    instability_start_confidence,
    instability_duration_days,
    instability_coding_notes
  )

readr::write_csv(monthly_panel, file.path(pilot_data_dir, "rr_2018_01_v2_monthly_panel.csv"), na = "")
readr::write_csv(fiscal_panel, file.path(pilot_data_dir, "rr_2018_01_v2_bimonthly_fiscal_panel.csv"), na = "")
readr::write_csv(quarterly_panel, file.path(pilot_data_dir, "rr_2018_01_v2_quarterly_pnadc_panel.csv"), na = "")
readr::write_csv(covariate_panel, file.path(pilot_data_dir, "rr_2018_01_v2_covariates.csv"), na = "")
readr::write_csv(event_metadata, file.path(pilot_data_dir, "rr_2018_01_v2_event_metadata.csv"), na = "")

message("RR 2018-01 V2 panels built:")
message("  monthly rows: ", nrow(monthly_panel))
message("  bimonthly fiscal rows: ", nrow(fiscal_panel))
message("  quarterly PNADc rows: ", nrow(quarterly_panel))
message("  covariate rows: ", nrow(covariate_panel))
