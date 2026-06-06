source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

extra_packages <- c("tidyr")
missing_extra <- extra_packages[!vapply(extra_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_extra) > 0) {
  stop("Missing required packages: ", paste(missing_extra, collapse = ", "))
}
invisible(lapply(extra_packages, library, character.only = TRUE))

pilot_id <- "rr_2018_01_v3"
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
  dplyr::slice(1)

state_year_panel <- readr::read_csv(
  file.path(root_dir, "data", "processed", "state_year_panel_template.csv"),
  show_col_types = FALSE
) |>
  dplyr::filter(!is.na(.data$population)) |>
  dplyr::mutate(
    year = as.integer(.data$year),
    population = as.numeric(.data$population),
    anchor_date = as.Date(sprintf("%s-07-01", .data$year))
  ) |>
  dplyr::select(.data$state_abbrev, .data$year, .data$population, .data$anchor_date)

instability_start_date <- as.Date(event$instability_start_date)
removal_date <- as.Date(event$removal_date)

monthly_window_start <- as.Date("2015-11-01")
monthly_window_end <- as.Date("2019-12-01")
bimonthly_window_start <- as.Date("2015-01-01")
bimonthly_window_end <- as.Date("2019-12-01")
quarterly_window_start <- as.Date("2015-01-01")
quarterly_window_end <- as.Date("2019-12-31")

donor_exclusion_window_start <- min(monthly_window_start, bimonthly_window_start, quarterly_window_start)
donor_exclusion_window_end <- max(monthly_window_end, bimonthly_window_end, quarterly_window_end)
donor_exclusion_rule <- paste0(
  "exclude_treated_state_and_any_state_with_coded_rupture_between_",
  format(donor_exclusion_window_start, "%Y_%m_%d"),
  "_and_",
  format(donor_exclusion_window_end, "%Y_%m_%d")
)

excluded_event_states <- event_inventory |>
  dplyr::mutate(removal_date = as.Date(.data$removal_date)) |>
  dplyr::filter(
    .data$include_extended_sample == 1,
    !is.na(.data$removal_date),
    .data$removal_date >= donor_exclusion_window_start,
    .data$removal_date <= donor_exclusion_window_end
  ) |>
  dplyr::distinct(.data$state_abbrev) |>
  dplyr::pull(.data$state_abbrev)

excluded_donor_states <- sort(unique(c(treated_state, excluded_event_states)))

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
      window_values <- x[(i - window + 1):i]
      if (any(!is.finite(window_values))) {
        return(NA_real_)
      }
      mean(window_values)
    }
  )
}

strict_partial_trailing_mean <- function(x, window) {
  purrr::map_dbl(
    seq_along(x),
    function(i) {
      start_i <- max(1, i - window + 1)
      window_values <- x[start_i:i]
      if (any(!is.finite(window_values))) {
        return(NA_real_)
      }
      mean(window_values)
    }
  )
}

pre_complete_post_partial_mean <- function(x, analysis_period, window) {
  output <- rep(NA_real_, length(x))

  for (segment in c("pre", "crisis", "post")) {
    idx <- which(analysis_period == segment)
    if (length(idx) == 0) {
      next
    }

    segment_values <- x[idx]
    output[idx] <- if (segment == "pre") {
      strict_complete_trailing_mean(segment_values, window)
    } else {
      strict_partial_trailing_mean(segment_values, window)
    }
  }

  output
}

resident_population_lookup <- state_year_panel |>
  dplyr::select(.data$state_abbrev, .data$year, population_current = .data$population) |>
  dplyr::left_join(
    state_year_panel |>
      dplyr::transmute(
        state_abbrev = .data$state_abbrev,
        year = .data$year - 1L,
        population_next = .data$population
      ),
    by = c("state_abbrev", "year")
  )

add_interpolated_resident_population <- function(data, date_col = "period_date") {
  data |>
    dplyr::mutate(
      interpolation_year = lubridate::year(.data[[date_col]]),
      interpolation_month = lubridate::month(.data[[date_col]])
    ) |>
    dplyr::left_join(
      resident_population_lookup,
      by = c("state_abbrev", "interpolation_year" = "year")
    ) |>
    dplyr::mutate(
      resident_population = dplyr::if_else(
        is.finite(.data$population_current) & is.finite(.data$population_next),
        .data$population_current +
          ((.data$interpolation_month - 1) / 12) *
            (.data$population_next - .data$population_current),
        .data$population_current
      )
    ) |>
    dplyr::select(
      -dplyr::any_of(c(
        "interpolation_year",
        "interpolation_month",
        "population_current",
        "population_next"
      ))
    )
}

add_clean_ma <- function(data, vars, window) {
  data |>
    dplyr::group_by(.data$state_abbrev) |>
    dplyr::arrange(.data$period_date, .by_group = TRUE) |>
    dplyr::mutate(
      dplyr::across(
        dplyr::all_of(vars),
        ~pre_complete_post_partial_mean(.x, .data$analysis_period, window),
        .names = "{.col}_ma{window}_clean"
      )
    ) |>
    dplyr::ungroup()
}

add_visual_ma <- function(data, vars, window) {
  data |>
    dplyr::group_by(.data$state_abbrev) |>
    dplyr::arrange(.data$period_date, .by_group = TRUE) |>
    dplyr::mutate(
      dplyr::across(
        dplyr::all_of(vars),
        ~pre_complete_post_partial_mean(.x, .data$analysis_period, window),
        .names = "{.col}_ma{window}_visual"
      )
    ) |>
    dplyr::ungroup()
}

rebase_to_first_period <- function(data, vars) {
  data |>
    dplyr::group_by(.data$state_abbrev) |>
    dplyr::arrange(.data$period_date, .by_group = TRUE) |>
    dplyr::mutate(
      dplyr::across(
        dplyr::all_of(vars),
        function(x) {
          base_value <- x[which(is.finite(x))[1]]
          if (!is.finite(base_value) || base_value == 0) {
            return(rep(NA_real_, length(x)))
          }
          100 * x / base_value
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
  output <- rep(NA_real_, length(x_chr))
  has_comma_decimal <- stringr::str_detect(x_chr, ",")

  output[has_comma_decimal] <- readr::parse_number(
    x_chr[has_comma_decimal],
    locale = readr::locale(decimal_mark = ",", grouping_mark = "."),
    na = c("", "NA", "null")
  )
  output[!has_comma_decimal] <- suppressWarnings(as.numeric(x_chr[!has_comma_decimal]))

  fallback <- is.na(output) & nzchar(x_chr)

  if (any(fallback)) {
    output[fallback] <- readr::parse_number(
      x_chr[fallback],
      locale = readr::locale(decimal_mark = ".", grouping_mark = ","),
      na = c("", "NA", "null")
    )
  }

  output
}

read_icms_annex06 <- function(start_year, end_year) {
  annex06_files <- file.path(
    root_dir,
    "data",
    "raw",
    "siconfi",
    sprintf("siconfi_rreo_state_fiscal_bimonthly_%d_annex06_raw.csv", start_year:end_year)
  )

  missing_files <- annex06_files[!file.exists(annex06_files)]
  if (length(missing_files) > 0) {
    stop("Missing Siconfi/RREO Annex 06 files for ICMS extraction: ", paste(missing_files, collapse = ", "))
  }

  purrr::map_dfr(
    annex06_files,
    function(path) {
      readr::read_csv(path, show_col_types = FALSE, col_types = readr::cols(.default = "c")) |>
        dplyr::filter(.data$cod_conta == "RREO6ICMS") |>
        dplyr::mutate(
          year = as.integer(.data$exercicio),
          bimester = as.integer(.data$periodo),
          uf = as.integer(.data$cod_ibge),
          value = parse_siconfi_value(.data$valor),
          realized_current_year = .data$coluna == "RECEITAS REALIZADAS (a)" |
            stringr::str_detect(.data$coluna, paste0("At\\u00e9 o Bimestre / ", .data$year))
        ) |>
        dplyr::filter(.data$realized_current_year) |>
        dplyr::group_by(.data$uf, .data$year, .data$bimester) |>
        dplyr::summarise(
          icms_revenue_cumulative_nominal = dplyr::first(.data$value[is.finite(.data$value)]),
          .groups = "drop"
        )
    }
  ) |>
    dplyr::arrange(.data$uf, .data$year, .data$bimester) |>
    dplyr::group_by(.data$uf, .data$year) |>
    dplyr::mutate(
      icms_revenue_nominal =
        .data$icms_revenue_cumulative_nominal -
        dplyr::lag(.data$icms_revenue_cumulative_nominal, default = 0),
      icms_revenue_flow_is_derived = TRUE,
      icms_revenue_negative_flow_flag = .data$icms_revenue_nominal < 0
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

caged_construction_path <- file.path(
  root_dir,
  "data",
  "processed",
  "caged_construction_state_balance_monthly_panel_ready.csv"
)

if (!file.exists(caged_construction_path)) {
  stop(
    "Construction CAGED file not found: ", caged_construction_path,
    ". Run code/01_build_panel/05a_build_caged_construction_state_balance_final.R first."
  )
}

caged_construction <- readr::read_csv(
  caged_construction_path,
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
    caged_construction |>
      dplyr::select(period_date, state_abbrev, formal_hiring_balance_construction),
    by = c("period_date", "state_abbrev")
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
  add_interpolated_resident_population() |>
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
    formal_hiring_balance_construction_per_100k_wap =
      100000 * .data$formal_hiring_balance_construction / .data$pnadc_population,
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
  dplyr::filter(
    .data$period_date >= monthly_window_start,
    .data$period_date <= monthly_window_end
  ) |>
  rebase_to_first_period(
    vars = c(
      "retail_volume_index",
      "services_volume_index"
    )
  ) |>
  add_clean_ma(
    vars = c(
      "formal_hiring_balance_per_100k_wap",
      "formal_hiring_balance_construction_per_100k_wap",
      "retail_volume_index",
      "services_volume_index"
    ),
    window = 6
  ) |>
  add_visual_ma(
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
    period_date = as.Date(period_date),
    year = as.integer(year),
    bimester = as.integer(bimester),
    quarter = lubridate::quarter(period_date)
  )

icms_revenue <- read_icms_annex06(
  start_year = lubridate::year(bimonthly_window_start),
  end_year = lubridate::year(bimonthly_window_end)
)

fiscal_panel <- fiscal_raw |>
  dplyr::left_join(
    icms_revenue,
    by = c("uf", "year", "bimester")
  ) |>
  dplyr::left_join(
    pnadc |>
      dplyr::select(state_abbrev, year, quarter, pnadc_population),
    by = c("state_abbrev", "year", "quarter")
  ) |>
  add_interpolated_resident_population() |>
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
      .data$state_tax_revenue_nominal > 0,
      .data$state_tax_revenue_real / .data$state_tax_revenue_nominal,
      NA_real_
    ),
    fiscal_population_denominator = dplyr::coalesce(.data$resident_population, .data$pnadc_population),
    fiscal_population_source = dplyr::case_when(
      is.finite(.data$resident_population) ~ "resident_population_interpolated",
      is.finite(.data$pnadc_population) ~ "pnadc_population_fallback",
      TRUE ~ NA_character_
    ),
    icms_revenue_real = .data$icms_revenue_nominal * .data$fiscal_deflator_factor,
    icms_revenue_real_pc = .data$icms_revenue_real / .data$fiscal_population_denominator,
    state_tax_revenue_real_pc = .data$state_tax_revenue_real / .data$fiscal_population_denominator,
    total_revenue_real_pc = .data$total_revenue_real / .data$fiscal_population_denominator,
    public_investment_liquidated_real_pc = .data$public_investment_liquidated_real / .data$fiscal_population_denominator,
    liquidated_expenditure_total_real_pc = .data$liquidated_expenditure_total_real / .data$fiscal_population_denominator,
    liquidated_expenditure_health_real_pc = .data$liquidated_expenditure_health_real / .data$fiscal_population_denominator,
    liquidated_expenditure_education_real_pc = .data$liquidated_expenditure_education_real / .data$fiscal_population_denominator,
    liquidated_expenditure_public_security_real_pc = .data$liquidated_expenditure_public_security_real / .data$fiscal_population_denominator,
    public_investment_share_total = dplyr::if_else(
      .data$liquidated_expenditure_total_real > 0,
      .data$public_investment_liquidated_real / .data$liquidated_expenditure_total_real,
      NA_real_
    ),
    priority_expenditure_share_total = dplyr::if_else(
      .data$liquidated_expenditure_total_real > 0,
      (
        .data$liquidated_expenditure_health_real +
          .data$liquidated_expenditure_education_real +
          .data$liquidated_expenditure_public_security_real
      ) / .data$liquidated_expenditure_total_real,
      NA_real_
    ),
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
  dplyr::filter(
    .data$period_date >= bimonthly_window_start,
    .data$period_date <= bimonthly_window_end
  ) |>
  add_clean_ma(
    vars = c(
      "icms_revenue_real_pc",
      "state_tax_revenue_real_pc",
      "total_revenue_real_pc",
      "public_investment_liquidated_real_pc",
      "liquidated_expenditure_total_real_pc",
      "priority_expenditure_share_total"
    ),
    window = 4
  ) |>
  add_visual_ma(
    vars = c(
      "icms_revenue_real_pc",
      "state_tax_revenue_real_pc",
      "total_revenue_real_pc",
      "public_investment_liquidated_real_pc",
      "liquidated_expenditure_total_real_pc",
      "priority_expenditure_share_total"
    ),
    window = 4
  )

quarterly_panel <- pnadc |>
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
  dplyr::select(-dplyr::any_of("donor_pool_exclusion_reason_event")) |>
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
  dplyr::left_join(fiscal_covariates, by = "state_abbrev") |>
  dplyr::mutate(
    donor_pool_main = !(.data$state_abbrev %in% excluded_donor_states),
    excluded_from_main_donor_pool = .data$state_abbrev %in% excluded_donor_states,
    donor_pool_exclusion_reason = dplyr::if_else(
      .data$state_abbrev == treated_state,
      "treated_unit",
      NA_character_
    )
  ) |>
  dplyr::left_join(excluded_event_lookup, by = "state_abbrev", suffix = c("", "_event")) |>
  dplyr::mutate(
    donor_pool_exclusion_reason = dplyr::coalesce(
      .data$donor_pool_exclusion_reason,
      .data$donor_pool_exclusion_reason_event
    )
  ) |>
  dplyr::select(-dplyr::any_of("donor_pool_exclusion_reason_event"))

event_metadata <- event |>
  dplyr::transmute(
    event_id,
    state_abbrev,
    state_name,
    governor_name,
    removal_date,
    instability_start_date,
    instability_start_type,
    instability_start_confidence,
    instability_duration_days,
    instability_coding_notes,
    main_monthly_window_start = monthly_window_start,
    main_monthly_window_end = monthly_window_end,
    main_bimonthly_window_start = bimonthly_window_start,
    main_bimonthly_window_end = bimonthly_window_end,
    main_quarterly_window_start = quarterly_window_start,
    main_quarterly_window_end = quarterly_window_end,
    donor_exclusion_window_start = donor_exclusion_window_start,
    donor_exclusion_window_end = donor_exclusion_window_end,
    donor_exclusion_rule = donor_exclusion_rule,
    donor_excluded_states = paste(excluded_donor_states, collapse = ",")
  )

readr::write_csv(monthly_panel, file.path(pilot_data_dir, "rr_2018_01_v3_monthly_panel.csv"), na = "")
readr::write_csv(fiscal_panel, file.path(pilot_data_dir, "rr_2018_01_v3_bimonthly_fiscal_panel.csv"), na = "")
readr::write_csv(quarterly_panel, file.path(pilot_data_dir, "rr_2018_01_v3_quarterly_pnadc_panel.csv"), na = "")
readr::write_csv(covariate_panel, file.path(pilot_data_dir, "rr_2018_01_v3_covariates.csv"), na = "")
readr::write_csv(event_metadata, file.path(pilot_data_dir, "rr_2018_01_v3_event_metadata.csv"), na = "")

message("RR 2018-01 V3 panels built:")
message("  monthly rows: ", nrow(monthly_panel))
message("  bimonthly fiscal rows: ", nrow(fiscal_panel))
message("  quarterly PNADc rows: ", nrow(quarterly_panel))
message("  covariate rows: ", nrow(covariate_panel))

