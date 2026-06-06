source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

extra_packages <- c("tidyr", "janitor")
missing_extra <- extra_packages[!vapply(extra_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_extra) > 0) {
  stop("Missing required packages: ", paste(missing_extra, collapse = ", "))
}
invisible(lapply(extra_packages, library, character.only = TRUE))

pilot_id <- "rr_2018_01_v4"
event_id <- "RR_2018_01"
treated_state <- "RR"

pilot_root <- file.path(root_dir, "pilots", pilot_id)
pilot_data_dir <- file.path(pilot_root, "data")
dir.create(pilot_data_dir, recursive = TRUE, showWarnings = FALSE)

event_inventory <- readr::read_csv(
  file.path(root_dir, "data", "raw", "governor_removal_events.csv"),
  show_col_types = FALSE
)

event <- event_inventory |>
  dplyr::filter(.data$event_id == !!event_id) |>
  dplyr::slice(1) |>
  dplyr::mutate(
    instability_start_date = as.Date(.data$instability_start_date),
    removal_date = as.Date(.data$removal_date)
  )

instability_start_date <- event$instability_start_date[[1]]
removal_date <- event$removal_date[[1]]

monthly_window_start <- as.Date("2015-11-01")
monthly_window_end <- as.Date("2019-12-01")
bimonthly_window_start <- as.Date("2015-01-01")
bimonthly_window_end <- as.Date("2019-12-01")
quarterly_window_start <- as.Date("2015-01-01")
quarterly_window_end <- as.Date("2019-12-31")

donor_exclusion_window_start <- min(monthly_window_start, bimonthly_window_start, quarterly_window_start)
donor_exclusion_window_end <- max(monthly_window_end, bimonthly_window_end, quarterly_window_end)

excluded_event_lookup <- event_inventory |>
  dplyr::mutate(removal_date = as.Date(.data$removal_date)) |>
  dplyr::filter(
    .data$include_extended_sample == 1,
    !is.na(.data$removal_date),
    .data$removal_date >= donor_exclusion_window_start,
    .data$removal_date <= donor_exclusion_window_end
  ) |>
  dplyr::group_by(.data$state_abbrev) |>
  dplyr::summarise(
    donor_pool_exclusion_reason = paste0(
      "coded_rupture_in_main_estimation_window:",
      paste(sort(unique(.data$event_id)), collapse = ",")
    ),
    .groups = "drop"
  )

excluded_donor_states <- sort(unique(c(
  treated_state,
  excluded_event_lookup$state_abbrev
)))

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

strict_complete_trailing_mean <- function(x, window) {
  purrr::map_dbl(
    seq_along(x),
    function(i) {
      if (i < window) {
        return(NA_real_)
      }
      vals <- x[(i - window + 1):i]
      if (any(!is.finite(vals))) {
        return(NA_real_)
      }
      mean(vals)
    }
  )
}

strict_expanding_trailing_mean <- function(x, window) {
  purrr::map_dbl(
    seq_along(x),
    function(i) {
      start_i <- max(1, i - window + 1)
      vals <- x[start_i:i]
      if (any(!is.finite(vals))) {
        return(NA_real_)
      }
      mean(vals)
    }
  )
}

v4_segment_moving_average <- function(x, analysis_period, window) {
  out <- rep(NA_real_, length(x))

  pre_idx <- which(analysis_period == "pre")
  if (length(pre_idx) > 0) {
    out[pre_idx] <- strict_complete_trailing_mean(x[pre_idx], window)
  }

  for (segment in c("crisis", "post")) {
    seg_idx <- which(analysis_period == segment)
    if (length(seg_idx) == 0) {
      next
    }
    out[seg_idx] <- strict_expanding_trailing_mean(x[seg_idx], window)
  }

  out
}

add_v4_moving_average <- function(data, vars, window) {
  data |>
    dplyr::group_by(.data$state_abbrev) |>
    dplyr::arrange(.data$period_date, .by_group = TRUE) |>
    dplyr::mutate(
      dplyr::across(
        dplyr::all_of(vars),
        ~v4_segment_moving_average(.x, .data$analysis_period, window),
        .names = "{.col}_ma{window}_v4"
      )
    ) |>
    dplyr::ungroup()
}

rebase_to_first_valid <- function(data, vars) {
  data |>
    dplyr::group_by(.data$state_abbrev) |>
    dplyr::arrange(.data$period_date, .by_group = TRUE) |>
    dplyr::mutate(
      dplyr::across(
        dplyr::all_of(vars),
        function(x) {
          first_valid <- which(is.finite(x))[1]
          if (!is.finite(first_valid)) {
            return(rep(NA_real_, length(x)))
          }
          base <- x[[first_valid]]
          if (!is.finite(base) || base == 0) {
            return(rep(NA_real_, length(x)))
          }
          100 * x / base
        }
      )
    ) |>
    dplyr::ungroup()
}

parse_siconfi_value <- function(x) {
  if (is.numeric(x)) {
    return(as.numeric(x))
  }

  x_chr <- stringr::str_trim(as.character(x))
  parsed <- readr::parse_number(
    x_chr,
    locale = readr::locale(decimal_mark = ",", grouping_mark = "."),
    na = c("", "NA", "null")
  )

  fallback <- is.na(parsed) & nzchar(x_chr)
  parsed[fallback] <- suppressWarnings(as.numeric(x_chr[fallback]))
  parsed
}

read_icms_annex06 <- function(start_year, end_year) {
  raw_path <- file.path(root_dir, "data", "raw", "siconfi", "siconfi_rreo_state_fiscal_bimonthly_annex06_raw.csv")
  readr::read_csv(raw_path, show_col_types = FALSE) |>
    janitor::clean_names() |>
    dplyr::filter(
      .data$cod_conta == "RREO6ICMS",
      .data$exercicio >= start_year,
      .data$exercicio <= end_year
    ) |>
    dplyr::mutate(
      year = as.integer(.data$exercicio),
      bimester = as.integer(.data$periodo),
      uf = as.integer(.data$cod_ibge),
      coluna = as.character(.data$coluna),
      value = parse_siconfi_value(.data$valor),
      realized_current_year = .data$coluna == "RECEITAS REALIZADAS (a)" |
        stringr::str_detect(.data$coluna, paste0("At\\u00e9 o Bimestre / ", .data$year))
    ) |>
    dplyr::filter(.data$realized_current_year) |>
    dplyr::group_by(.data$uf, .data$year, .data$bimester) |>
    dplyr::summarise(
      icms_revenue_cumulative_nominal = dplyr::first(.data$value[is.finite(.data$value)]),
      .groups = "drop"
    ) |>
    dplyr::group_by(.data$uf, .data$year) |>
    dplyr::arrange(.data$bimester, .by_group = TRUE) |>
    dplyr::mutate(
      icms_revenue_nominal = .data$icms_revenue_cumulative_nominal - dplyr::lag(.data$icms_revenue_cumulative_nominal, default = 0),
      icms_revenue_flow_is_derived = TRUE,
      icms_revenue_negative_flow_flag = .data$icms_revenue_nominal < 0
    ) |>
    dplyr::ungroup()
}

state_year_panel <- readr::read_csv(
  file.path(root_dir, "data", "processed", "state_year_panel_template.csv"),
  show_col_types = FALSE
) |>
  dplyr::transmute(
    state_abbrev = .data$state_abbrev,
    year = as.integer(.data$year),
    resident_population_annual = as.numeric(.data$population)
  )

pnadc_quarterly <- readr::read_csv(
  file.path(root_dir, "data", "processed", "pnadc_sidra_quarterly_state_covariates_panel_ready.csv"),
  show_col_types = FALSE
) |>
  dplyr::mutate(
    period_date = as.Date(.data$period_date),
    year = as.integer(.data$year),
    quarter = as.integer(.data$quarter),
    pnadc_population = as.numeric(.data$pnadc_population),
    unemployment_rate_pnadc = as.numeric(.data$unemployment_rate_pnadc),
    formalization_rate_pnadc = as.numeric(.data$formalization_rate_pnadc),
    labor_income_real_pnadc = as.numeric(.data$labor_income_real_pnadc)
  )

retail_monthly <- readr::read_csv(
  file.path(root_dir, "data", "processed", "pmc_retail_monthly_panel_ready.csv"),
  show_col_types = FALSE
) |>
  dplyr::transmute(
    state_abbrev = .data$state_abbrev,
    period_date = as.Date(.data$period_date),
    year = as.integer(.data$year),
    month = as.integer(.data$month),
    retail_volume_index = as.numeric(.data$retail_volume_index)
  )

services_monthly <- readr::read_csv(
  file.path(root_dir, "data", "processed", "pms_services_monthly_panel_ready.csv"),
  show_col_types = FALSE
) |>
  dplyr::transmute(
    state_abbrev = .data$state_abbrev,
    period_date = as.Date(.data$period_date),
    year = as.integer(.data$year),
    month = as.integer(.data$month),
    services_volume_index = as.numeric(.data$services_volume_index)
  )

formal_monthly <- readr::read_csv(
  file.path(root_dir, "data", "processed", "old_caged_state_balance_monthly_panel_ready.csv"),
  show_col_types = FALSE
) |>
  dplyr::transmute(
    state_abbrev = .data$state_abbrev,
    state_name = .data$state_name,
    macroregion = .data$macroregion,
    uf = as.integer(.data$uf),
    period_date = as.Date(.data$period_date),
    year = as.integer(.data$year),
    month = as.integer(.data$month),
    formal_hiring_balance = as.numeric(.data$formal_hiring_balance)
  )

construction_monthly <- readr::read_csv(
  file.path(root_dir, "data", "processed", "caged_construction_state_balance_monthly_panel_ready.csv"),
  show_col_types = FALSE
) |>
  dplyr::transmute(
    state_abbrev = .data$state_abbrev,
    period_date = as.Date(.data$period_date),
    formal_hiring_balance_construction = as.numeric(.data$formal_hiring_balance_construction)
  )

monthly_panel <- formal_monthly |>
  dplyr::left_join(construction_monthly, by = c("state_abbrev", "period_date")) |>
  dplyr::left_join(retail_monthly, by = c("state_abbrev", "period_date", "year", "month")) |>
  dplyr::left_join(services_monthly, by = c("state_abbrev", "period_date", "year", "month")) |>
  dplyr::mutate(
    quarter = lubridate::quarter(.data$period_date)
  ) |>
  dplyr::left_join(
    pnadc_quarterly |>
      dplyr::select(
        .data$state_abbrev,
        .data$year,
        .data$quarter,
        .data$pnadc_population
      ),
    by = c("state_abbrev", "year", "quarter")
  ) |>
  dplyr::filter(
    .data$period_date >= monthly_window_start,
    .data$period_date <= monthly_window_end
  ) |>
  dplyr::mutate(
    treated_unit = .data$state_abbrev == treated_state,
    donor_pool_main = !(.data$state_abbrev %in% excluded_donor_states),
    excluded_from_main_donor_pool = .data$state_abbrev %in% excluded_donor_states,
    donor_pool_exclusion_reason = dplyr::if_else(
      .data$state_abbrev == treated_state,
      "treated_unit",
      NA_character_
    ),
    analysis_period = assign_period_monthly(.data$period_date),
    formal_hiring_balance_per_100k_wap = 100000 * .data$formal_hiring_balance / .data$pnadc_population,
    formal_hiring_balance_construction_per_100k_wap = 100000 * .data$formal_hiring_balance_construction / .data$pnadc_population,
    instability_start_date = instability_start_date,
    removal_date = removal_date
  ) |>
  dplyr::left_join(excluded_event_lookup, by = "state_abbrev", suffix = c("", "_event")) |>
  dplyr::mutate(
    donor_pool_exclusion_reason = dplyr::coalesce(
      .data$donor_pool_exclusion_reason,
      .data$donor_pool_exclusion_reason_event
    )
  ) |>
  dplyr::select(-dplyr::any_of("donor_pool_exclusion_reason_event")) |>
  rebase_to_first_valid(c("retail_volume_index", "services_volume_index")) |>
  add_v4_moving_average(
    vars = c(
      "formal_hiring_balance_per_100k_wap",
      "formal_hiring_balance_construction_per_100k_wap",
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
    period_date = as.Date(.data$period_date),
    year = as.integer(.data$year),
    bimester = as.integer(.data$bimester),
    quarter = lubridate::quarter(.data$period_date)
  )

icms_revenue <- read_icms_annex06(2015, 2019)

fiscal_panel <- fiscal_raw |>
  dplyr::left_join(icms_revenue, by = c("uf", "year", "bimester")) |>
  dplyr::left_join(state_year_panel, by = c("state_abbrev", "year")) |>
  dplyr::left_join(
    pnadc_quarterly |>
      dplyr::select(.data$state_abbrev, .data$year, .data$quarter, .data$pnadc_population),
    by = c("state_abbrev", "year", "quarter")
  ) |>
  dplyr::filter(
    .data$period_date >= bimonthly_window_start,
    .data$period_date <= bimonthly_window_end
  ) |>
  dplyr::mutate(
    treated_unit = .data$state_abbrev == treated_state,
    donor_pool_main = !(.data$state_abbrev %in% excluded_donor_states),
    excluded_from_main_donor_pool = .data$state_abbrev %in% excluded_donor_states,
    donor_pool_exclusion_reason = dplyr::if_else(
      .data$state_abbrev == treated_state,
      "treated_unit",
      NA_character_
    ),
    analysis_period = assign_period_bimonthly(.data$year, .data$bimester),
    fiscal_deflator_factor = dplyr::if_else(
      is.finite(.data$state_tax_revenue_nominal) & .data$state_tax_revenue_nominal > 0,
      .data$state_tax_revenue_real / .data$state_tax_revenue_nominal,
      NA_real_
    ),
    fiscal_population_denominator = .data$resident_population_annual,
    fiscal_population_source = "resident_population_annual",
    icms_revenue_real = .data$icms_revenue_nominal * .data$fiscal_deflator_factor,
    icms_revenue_real_pc = .data$icms_revenue_real / .data$fiscal_population_denominator,
    state_tax_revenue_real_pc = .data$state_tax_revenue_real / .data$fiscal_population_denominator,
    public_investment_liquidated_real_pc = .data$public_investment_liquidated_real / .data$fiscal_population_denominator,
    liquidated_expenditure_total_real_pc = .data$liquidated_expenditure_total_real / .data$fiscal_population_denominator,
    transfer_dependency_ratio = as.numeric(.data$transfer_dependency_ratio),
    liquidated_expenditure_health_real_pc = .data$liquidated_expenditure_health_real / .data$fiscal_population_denominator,
    liquidated_expenditure_education_real_pc = .data$liquidated_expenditure_education_real / .data$fiscal_population_denominator,
    liquidated_expenditure_public_security_real_pc = .data$liquidated_expenditure_public_security_real / .data$fiscal_population_denominator,
    instability_start_date = instability_start_date,
    removal_date = removal_date
  ) |>
  dplyr::left_join(excluded_event_lookup, by = "state_abbrev", suffix = c("", "_event")) |>
  dplyr::mutate(
    donor_pool_exclusion_reason = dplyr::coalesce(
      .data$donor_pool_exclusion_reason,
      .data$donor_pool_exclusion_reason_event
    )
  ) |>
  dplyr::select(-dplyr::any_of("donor_pool_exclusion_reason_event")) |>
  add_v4_moving_average(
    vars = c(
      "icms_revenue_real_pc",
      "state_tax_revenue_real_pc",
      "public_investment_liquidated_real_pc",
      "liquidated_expenditure_total_real_pc"
    ),
    window = 4
  )

quarterly_panel <- pnadc_quarterly |>
  dplyr::filter(
    .data$period_date >= quarterly_window_start,
    .data$period_date <= quarterly_window_end
  ) |>
  dplyr::mutate(
    treated_unit = .data$state_abbrev == treated_state,
    donor_pool_main = !(.data$state_abbrev %in% excluded_donor_states),
    excluded_from_main_donor_pool = .data$state_abbrev %in% excluded_donor_states,
    donor_pool_exclusion_reason = dplyr::if_else(
      .data$state_abbrev == treated_state,
      "treated_unit",
      NA_character_
    ),
    analysis_period = assign_period_quarterly(.data$year, .data$quarter),
    instability_start_date = instability_start_date,
    removal_date = removal_date
  ) |>
  dplyr::left_join(excluded_event_lookup, by = "state_abbrev", suffix = c("", "_event")) |>
  dplyr::mutate(
    donor_pool_exclusion_reason = dplyr::coalesce(
      .data$donor_pool_exclusion_reason,
      .data$donor_pool_exclusion_reason_event
    )
  ) |>
  dplyr::select(-dplyr::any_of("donor_pool_exclusion_reason_event"))

covariates <- monthly_panel |>
  dplyr::filter(.data$analysis_period == "pre") |>
  dplyr::group_by(.data$state_abbrev) |>
  dplyr::summarise(
    monthly_pre_periods = dplyr::n(),
    .groups = "drop"
  ) |>
  dplyr::left_join(
    quarterly_panel |>
      dplyr::filter(.data$analysis_period == "pre") |>
      dplyr::group_by(.data$state_abbrev) |>
      dplyr::summarise(
        unemployment_rate = mean(.data$unemployment_rate_pnadc, na.rm = TRUE),
        formalization_rate = mean(.data$formalization_rate_pnadc, na.rm = TRUE),
        labor_income_real = mean(.data$labor_income_real_pnadc, na.rm = TRUE),
        .groups = "drop"
      ),
    by = "state_abbrev"
  ) |>
  dplyr::left_join(
    fiscal_panel |>
      dplyr::filter(.data$analysis_period == "pre") |>
      dplyr::group_by(.data$state_abbrev) |>
      dplyr::summarise(
        transfer_dependency_ratio = mean(.data$transfer_dependency_ratio, na.rm = TRUE),
        health_expenditure_real_pc = mean(.data$liquidated_expenditure_health_real_pc, na.rm = TRUE),
        education_expenditure_real_pc = mean(.data$liquidated_expenditure_education_real_pc, na.rm = TRUE),
        public_security_expenditure_real_pc = mean(.data$liquidated_expenditure_public_security_real_pc, na.rm = TRUE),
        .groups = "drop"
      ),
    by = "state_abbrev"
  ) |>
  dplyr::mutate(
    donor_pool_main = !(.data$state_abbrev %in% excluded_donor_states),
    excluded_from_main_donor_pool = .data$state_abbrev %in% excluded_donor_states
  ) |>
  dplyr::left_join(
    excluded_event_lookup,
    by = "state_abbrev"
  ) |>
  dplyr::mutate(
    donor_pool_exclusion_reason = dplyr::case_when(
      .data$state_abbrev == treated_state ~ "treated_unit",
      .data$excluded_from_main_donor_pool ~ .data$donor_pool_exclusion_reason,
      TRUE ~ NA_character_
    )
  ) |>
  dplyr::arrange(.data$state_abbrev)

event_metadata <- event |>
  dplyr::mutate(
    pilot_id = pilot_id,
    monthly_window_start = monthly_window_start,
    monthly_window_end = monthly_window_end,
    bimonthly_window_start = bimonthly_window_start,
    bimonthly_window_end = bimonthly_window_end,
    quarterly_window_start = quarterly_window_start,
    quarterly_window_end = quarterly_window_end,
    donor_exclusion_window_start = donor_exclusion_window_start,
    donor_exclusion_window_end = donor_exclusion_window_end
  )

readr::write_csv(monthly_panel, file.path(pilot_data_dir, "rr_2018_01_v4_monthly_panel.csv"), na = "")
readr::write_csv(fiscal_panel, file.path(pilot_data_dir, "rr_2018_01_v4_bimonthly_fiscal_panel.csv"), na = "")
readr::write_csv(quarterly_panel, file.path(pilot_data_dir, "rr_2018_01_v4_quarterly_pnadc_panel.csv"), na = "")
readr::write_csv(covariates, file.path(pilot_data_dir, "rr_2018_01_v4_covariates.csv"), na = "")
readr::write_csv(event_metadata, file.path(pilot_data_dir, "rr_2018_01_v4_event_metadata.csv"), na = "")

message("RR 2018-01 V4 panels built:")
message("  monthly rows: ", nrow(monthly_panel))
message("  bimonthly fiscal rows: ", nrow(fiscal_panel))
message("  quarterly rows: ", nrow(quarterly_panel))
message("  covariate rows: ", nrow(covariates))
