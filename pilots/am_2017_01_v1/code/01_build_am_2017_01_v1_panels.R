source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

extra_packages <- c("tidyr", "janitor")
missing_extra <- extra_packages[!vapply(extra_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_extra) > 0) {
  stop("Missing required packages: ", paste(missing_extra, collapse = ", "))
}
invisible(lapply(extra_packages, library, character.only = TRUE))

pilot_id <- "am_2017_01_v1"
event_id <- "AM_2017_01"
treated_state <- "AM"

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

# EVENT TIME DESIGN: event_time = 0 at instability_start_date (2016-01-25, TRE cassation).
# The 465-day crisis window (TRE → TSE) is a distinct analytical segment.
# Three segments: pre (< 0) / crisis (0 to crisis_end-1) / post (≥ crisis_end).
#
# Monthly:
#   Pre:    2014-05 to 2015-12 = 20 months (event_time -20 to -1)
#   Crisis: 2016-01 to 2017-04 = 16 months (event_time  0 to 15)
#   Post:   2017-05 to 2019-12 = 31 months (event_time 16 to 46)
#
# Bimonthly (limited by Siconfi start 2015):
#   Pre:    2015B1 to 2015B6   = 6 bimesters (event_time -6 to -1) [short; acknowledged limitation]
#   Crisis: 2016B1 to 2017B2   = 8 bimesters (event_time  0 to  7)
#   Post:   2017B3 to 2019B6   = 15 bimesters (event_time 8 to 22)
monthly_window_start    <- as.Date("2014-05-01")
monthly_window_end      <- as.Date("2019-12-01")
bimonthly_window_start  <- as.Date("2015-01-01")
bimonthly_window_end    <- as.Date("2019-12-01")
quarterly_window_start  <- as.Date("2015-01-01")
quarterly_window_end    <- as.Date("2019-12-31")

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

# event_time = 0 is anchored at instability_start_date (not removal_date)
event_month_date   <- lubridate::floor_date(instability_start_date, "month")
event_bimonth_year <- lubridate::year(instability_start_date)
event_bimonth      <- ((lubridate::month(instability_start_date) - 1L) %/% 2L) + 1L
event_quarter_year <- lubridate::year(instability_start_date)
event_quarter      <- lubridate::quarter(instability_start_date)

# Crisis end: event_time at which removal_date falls (start of post segment)
removal_month_date  <- lubridate::floor_date(removal_date, "month")
crisis_end_monthly  <- 12L * (lubridate::year(removal_month_date) - lubridate::year(event_month_date)) +
                       (lubridate::month(removal_month_date) - lubridate::month(event_month_date))

removal_bimonth_year <- lubridate::year(removal_date)
removal_bimonth      <- ((lubridate::month(removal_date) - 1L) %/% 2L) + 1L
crisis_end_bimonthly <- 6L * (removal_bimonth_year - event_bimonth_year) +
                        (removal_bimonth - event_bimonth)

removal_quarter_year <- lubridate::year(removal_date)
removal_quarter      <- lubridate::quarter(removal_date)
crisis_end_quarterly <- 4L * (removal_quarter_year - event_quarter_year) +
                        (removal_quarter - event_quarter)

compute_monthly_event_time <- function(period_date) {
  12L * (lubridate::year(period_date) - lubridate::year(event_month_date)) +
    (lubridate::month(period_date) - lubridate::month(event_month_date))
}

compute_bimonthly_event_time <- function(year, bimester) {
  6L * (as.integer(year) - event_bimonth_year) + (as.integer(bimester) - event_bimonth)
}

compute_quarterly_event_time <- function(year, quarter) {
  4L * (as.integer(year) - event_quarter_year) + (as.integer(quarter) - event_quarter)
}

# 3-segment period assignment: pre / crisis / post
# crisis_end is the first event_time in the post segment (= removal date event_time)
assign_period_from_event_time <- function(event_time, crisis_end) {
  dplyr::case_when(
    event_time < 0L           ~ "pre",
    event_time < crisis_end   ~ "crisis",
    TRUE                      ~ "post"
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

# 3-segment MA: pre / crisis / post computed independently (no window crosses segment boundaries)
v5_segment_moving_average <- function(x, event_time, window, crisis_end) {
  out <- rep(NA_real_, length(x))

  pre_idx <- which(event_time < 0L)
  if (length(pre_idx) > 0L) {
    out[pre_idx] <- strict_complete_trailing_mean(x[pre_idx], window)
  }

  crisis_idx <- which(event_time >= 0L & event_time < crisis_end)
  if (length(crisis_idx) > 0L) {
    out[crisis_idx] <- strict_complete_trailing_mean(x[crisis_idx], window)
  }

  post_idx <- which(event_time >= crisis_end)
  if (length(post_idx) > 0L) {
    out[post_idx] <- strict_complete_trailing_mean(x[post_idx], window)
  }

  out
}

add_v5_moving_average <- function(data, vars, window, crisis_end) {
  data |>
    dplyr::group_by(.data$state_abbrev) |>
    dplyr::arrange(.data$period_date, .by_group = TRUE) |>
    dplyr::mutate(
      dplyr::across(
        dplyr::all_of(vars),
        ~v5_segment_moving_average(.x, .data$event_time, window, crisis_end),
        .names = "{.col}_ma{window}_v5"
      ),
      # plot_time = event_time (no shift); crisis window visible in graphs
      !!paste0("plot_time_ma", window, "_v5") := .data$event_time
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

impute_adjacent_mean <- function(data, value_col, order_col = "period_date", group_col = "state_abbrev") {
  value_sym <- rlang::sym(value_col)
  order_sym <- rlang::sym(order_col)
  group_sym <- rlang::sym(group_col)
  original_missing_col <- paste0("original_", value_col, "_missing")
  imputed_flag_col <- paste0(value_col, "_imputed_adjacent_mean")
  imputation_method_col <- paste0(value_col, "_imputation_method")

  data |>
    dplyr::group_by(!!group_sym) |>
    dplyr::arrange(!!order_sym, .by_group = TRUE) |>
    dplyr::mutate(
      !!original_missing_col := is.na(!!value_sym),
      .lag_value = dplyr::lag(!!value_sym),
      .lead_value = dplyr::lead(!!value_sym),
      .can_impute_adjacent = is.na(!!value_sym) & is.finite(.lag_value) & is.finite(.lead_value),
      !!value_sym := dplyr::if_else(
        .can_impute_adjacent,
        (.lag_value + .lead_value) / 2,
        !!value_sym
      ),
      !!imputed_flag_col := .can_impute_adjacent,
      !!imputation_method_col := dplyr::if_else(
        .can_impute_adjacent,
        "adjacent_mean_prev_next",
        NA_character_
      )
    ) |>
    dplyr::ungroup() |>
    dplyr::select(-dplyr::any_of(c(".lag_value", ".lead_value", ".can_impute_adjacent")))
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

quarterly_first_formalization_period <- pnadc_quarterly |>
  dplyr::filter(!is.na(.data$formalization_rate_pnadc)) |>
  dplyr::summarise(first_period = min(.data$period_date, na.rm = TRUE)) |>
  dplyr::pull(.data$first_period)

quarterly_window_start <- max(quarterly_window_start, quarterly_first_formalization_period)
donor_exclusion_window_start <- min(monthly_window_start, bimonthly_window_start, quarterly_window_start)

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
  file.path(root_dir, "data", "processed", "caged_state_balance_monthly_panel_ready.csv"),
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
    event_time = compute_monthly_event_time(.data$period_date),
    analysis_period = assign_period_from_event_time(.data$event_time, crisis_end_monthly),
    pre_instability_clean = .data$analysis_period == "pre",
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
  add_v5_moving_average(
    vars = c(
      "formal_hiring_balance_per_100k_wap",
      "formal_hiring_balance_construction_per_100k_wap",
      "retail_volume_index",
      "services_volume_index"
    ),
    window = 6,
    crisis_end = crisis_end_monthly
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

# === RS 2018 ICMS: SEASONAL IMPUTATION ===
# The Siconfi API returns 0 rows for RS Annex06 B1-B5 2018 (confirmed by download registry
# and direct API test). RS did not publish intermediate RREO Annex06 for those bimesters.
# The annual cumulative (B6) is available. We impute B1-B5 flows using RS 2017 intra-year
# seasonal shares applied to the 2018 annual total.
rs_uf_code <- 43L

rs_2017_flows <- icms_revenue |>
  dplyr::filter(.data$uf == rs_uf_code, .data$year == 2017L) |>
  dplyr::arrange(.data$bimester) |>
  dplyr::select(.data$bimester, .data$icms_revenue_nominal)

rs_2018_annual_cumulative <- icms_revenue |>
  dplyr::filter(.data$uf == rs_uf_code, .data$year == 2018L, .data$bimester == 6L) |>
  dplyr::pull(.data$icms_revenue_cumulative_nominal)

if (
  nrow(rs_2017_flows) == 6 &&
  all(is.finite(rs_2017_flows$icms_revenue_nominal)) &&
  length(rs_2018_annual_cumulative) == 1 &&
  is.finite(rs_2018_annual_cumulative)
) {
  rs_2017_annual_total <- sum(rs_2017_flows$icms_revenue_nominal)
  rs_2017_shares <- rs_2017_flows |>
    dplyr::mutate(share_2017 = .data$icms_revenue_nominal / rs_2017_annual_total)

  imputed_b1_b5 <- rs_2017_shares |>
    dplyr::filter(.data$bimester %in% 1L:5L) |>
    dplyr::mutate(
      uf = rs_uf_code,
      year = 2018L,
      icms_revenue_nominal = .data$share_2017 * rs_2018_annual_cumulative,
      icms_revenue_flow_is_derived = TRUE,
      icms_revenue_negative_flow_flag = FALSE,
      icms_rs_2018_seasonal_imputed = TRUE
    ) |>
    dplyr::arrange(.data$bimester) |>
    dplyr::mutate(
      icms_revenue_cumulative_nominal = cumsum(.data$icms_revenue_nominal)
    ) |>
    dplyr::select(
      .data$uf, .data$year, .data$bimester,
      .data$icms_revenue_cumulative_nominal, .data$icms_revenue_nominal,
      .data$icms_revenue_flow_is_derived, .data$icms_revenue_negative_flow_flag,
      .data$icms_rs_2018_seasonal_imputed
    )

  b5_cumulative <- imputed_b1_b5 |>
    dplyr::filter(.data$bimester == 5L) |>
    dplyr::pull(.data$icms_revenue_cumulative_nominal)

  rs_2018_b6_corrected <- tibble::tibble(
    uf = rs_uf_code,
    year = 2018L,
    bimester = 6L,
    icms_revenue_cumulative_nominal = rs_2018_annual_cumulative,
    icms_revenue_nominal = rs_2018_annual_cumulative - b5_cumulative,
    icms_revenue_flow_is_derived = TRUE,
    icms_revenue_negative_flow_flag = (rs_2018_annual_cumulative - b5_cumulative) < 0,
    icms_rs_2018_seasonal_imputed = FALSE
  )

  icms_revenue <- icms_revenue |>
    dplyr::mutate(icms_rs_2018_seasonal_imputed = FALSE) |>
    dplyr::filter(!(.data$uf == rs_uf_code & .data$year == 2018L)) |>
    dplyr::bind_rows(imputed_b1_b5, rs_2018_b6_corrected) |>
    dplyr::arrange(.data$uf, .data$year, .data$bimester)

  message("RS 2018 ICMS: imputed B1-B5 with 2017 seasonal shares; B6 flow corrected.")
} else {
  icms_revenue <- icms_revenue |>
    dplyr::mutate(icms_rs_2018_seasonal_imputed = FALSE)
  warning("RS 2018 ICMS seasonal imputation skipped: unexpected data state.")
}

# === NEGATIVE ICMS FLOW HANDLING ===
# Two derived flows are negative (MT 2015B2, RN 2018B3), likely due to cumulative
# accounting revisions in Siconfi. Replace with adjacent bimester mean and flag.
impute_negative_icms_flow <- function(data) {
  data |>
    dplyr::group_by(.data$uf, .data$year) |>
    dplyr::arrange(.data$bimester, .by_group = TRUE) |>
    dplyr::mutate(
      .lag_flow = dplyr::lag(.data$icms_revenue_nominal),
      .lead_flow = dplyr::lead(.data$icms_revenue_nominal),
      .can_replace = .data$icms_revenue_negative_flow_flag &
        is.finite(.data$.lag_flow) & .data$.lag_flow >= 0 &
        is.finite(.data$.lead_flow) & .data$.lead_flow >= 0,
      icms_revenue_nominal = dplyr::if_else(
        .data$.can_replace,
        (.data$.lag_flow + .data$.lead_flow) / 2,
        .data$icms_revenue_nominal
      ),
      icms_revenue_negative_flow_imputed = .data$.can_replace
    ) |>
    dplyr::ungroup() |>
    dplyr::select(-dplyr::any_of(c(".lag_flow", ".lead_flow", ".can_replace")))
}

icms_revenue <- impute_negative_icms_flow(icms_revenue)

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
    event_time = compute_bimonthly_event_time(.data$year, .data$bimester),
    analysis_period = assign_period_from_event_time(.data$event_time, crisis_end_bimonthly),
    pre_instability_clean = .data$analysis_period == "pre",
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
  add_v5_moving_average(
    vars = c(
      "icms_revenue_real_pc",
      "state_tax_revenue_real_pc",
      "public_investment_liquidated_real_pc",
      "liquidated_expenditure_total_real_pc"
    ),
    window = 4,
    crisis_end = crisis_end_bimonthly
  ) |>
  impute_adjacent_mean("liquidated_expenditure_health_real_pc") |>
  impute_adjacent_mean("liquidated_expenditure_education_real_pc") |>
  impute_adjacent_mean("liquidated_expenditure_public_security_real_pc")

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
    event_time = compute_quarterly_event_time(.data$year, .data$quarter),
    analysis_period = assign_period_from_event_time(.data$event_time, crisis_end_quarterly),
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
    donor_exclusion_window_end = donor_exclusion_window_end,
    crisis_end_monthly   = crisis_end_monthly,
    crisis_end_bimonthly = crisis_end_bimonthly,
    crisis_end_quarterly = crisis_end_quarterly
  )

readr::write_csv(monthly_panel, file.path(pilot_data_dir, "am_2017_01_v1_monthly_panel.csv"), na = "")
readr::write_csv(fiscal_panel, file.path(pilot_data_dir, "am_2017_01_v1_bimonthly_fiscal_panel.csv"), na = "")
readr::write_csv(quarterly_panel, file.path(pilot_data_dir, "am_2017_01_v1_quarterly_pnadc_panel.csv"), na = "")
readr::write_csv(covariates, file.path(pilot_data_dir, "am_2017_01_v1_covariates.csv"), na = "")
readr::write_csv(event_metadata, file.path(pilot_data_dir, "am_2017_01_v1_event_metadata.csv"), na = "")

message("AM 2017-01 V1 panels built:")
message("  monthly rows: ", nrow(monthly_panel))
message("  bimonthly fiscal rows: ", nrow(fiscal_panel))
message("  quarterly rows: ", nrow(quarterly_panel))
message("  covariate rows: ", nrow(covariates))

