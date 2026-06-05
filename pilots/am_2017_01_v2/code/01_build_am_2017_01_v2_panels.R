source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

extra_packages <- c("tidyr", "janitor", "seasonal")
missing_extra <- extra_packages[!vapply(extra_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_extra) > 0) {
  stop("Missing required packages: ", paste(missing_extra, collapse = ", "))
}
invisible(lapply(extra_packages, library, character.only = TRUE))

pilot_id      <- "am_2017_01_v2"
event_id      <- "AM_2017_01"
treated_state <- "AM"

pilot_root    <- file.path(root_dir, "pilots", pilot_id)
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
    removal_date           = as.Date(.data$removal_date)
  )

instability_start_date <- event$instability_start_date[[1]]
removal_date           <- event$removal_date[[1]]

# ── Window design ─────────────────────────────────────────────────────────────
#
# Monthly (freq = 12):
#   Pre-treatment:  36 months before instability_start → 2013-01-01 to 2015-12-01
#   Crisis:         instability → removal               → 2016-01-01 to 2017-04-01
#   Post-removal:   12 months after removal             → 2017-05-01 to 2018-04-01
#   Total window:   2013-01-01 to 2018-04-01
#
# Bimonthly fiscal (freq = 6):
#   Pre-treatment:  24 bimesters desired, limited by Siconfi start 2015 → 6 available
#   Crisis:         2016B1 to 2017B2  (8 bimesters)
#   Post-removal:   9 bimesters after removal (2017B3) → 2017B3 to 2018B5
#   Total window:   2015-01-01 to 2018-10-01 (period_date = bimester*2 month)

monthly_window_start   <- as.Date("2013-01-01")
monthly_window_end     <- as.Date("2018-04-01")
bimonthly_window_start <- as.Date("2015-01-01")
bimonthly_window_end   <- as.Date("2018-10-01")
quarterly_window_start <- as.Date("2012-01-01")
quarterly_window_end   <- as.Date("2018-06-30")

donor_exclusion_window_start <- min(monthly_window_start, bimonthly_window_start)
donor_exclusion_window_end   <- max(monthly_window_end,   bimonthly_window_end)

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

excluded_donor_states <- sort(unique(c(treated_state, excluded_event_lookup$state_abbrev)))

# ── Crisis-end event times ─────────────────────────────────────────────────────
instability_month   <- lubridate::floor_date(instability_start_date, "month")
removal_month       <- lubridate::floor_date(removal_date, "month")

instability_bim_yr  <- lubridate::year(instability_start_date)
instability_bim     <- ((lubridate::month(instability_start_date) - 1L) %/% 2L) + 1L
removal_bim_yr      <- lubridate::year(removal_date)
removal_bim         <- ((lubridate::month(removal_date) - 1L) %/% 2L) + 1L

crisis_end_monthly   <- 12L * (lubridate::year(removal_month) - lubridate::year(instability_month)) +
                        (lubridate::month(removal_month) - lubridate::month(instability_month))
crisis_end_bimonthly <- 6L * (removal_bim_yr - instability_bim_yr) +
                        (removal_bim - instability_bim)

# ── Period assignment (3-segment: pre / crisis / post) ─────────────────────────
# Pre:    period_date <  instability_start (floor to month/bimester)
# Crisis: instability_start ≤ period_date < removal_date
# Post:   period_date ≥ removal_date (floor to month/bimester)
assign_period_monthly <- function(period_date) {
  dplyr::case_when(
    period_date < instability_month ~ "pre",
    period_date < removal_month     ~ "crisis",
    TRUE                            ~ "post"
  )
}

assign_period_bimonthly <- function(year, bimester) {
  yr  <- as.integer(year)
  bim <- as.integer(bimester)
  dplyr::case_when(
    yr < instability_bim_yr | (yr == instability_bim_yr & bim < instability_bim) ~ "pre",
    yr < removal_bim_yr     | (yr == removal_bim_yr     & bim < removal_bim)     ~ "crisis",
    TRUE                                                                           ~ "post"
  )
}

assign_period_quarterly <- function(period_date) {
  instability_q <- lubridate::floor_date(instability_start_date, "quarter")
  removal_q     <- lubridate::floor_date(removal_date,           "quarter")
  dplyr::case_when(
    period_date < instability_q ~ "pre",
    period_date < removal_q     ~ "crisis",
    TRUE                        ~ "post"
  )
}

# ── X-13 seasonal adjustment ──────────────────────────────────────────────────
# Applied to the FULL available series per state (not just the pilot window)
# to get the best estimate of seasonal factors. The pilot-window subset is
# extracted after adjustment.
#
# Parameters:
#   x          : numeric vector (the full series for one state)
#   dates      : Date vector aligned to x
#   freq       : seasonal frequency (12 monthly, 6 bimonthly, 4 quarterly)
#   state_id   : character label for warning messages
#
# Returns the seasonally adjusted vector (same length as x).
# Falls back to the original series if X-13 fails.

x13_adjust <- function(x, dates, freq, state_id = "") {
  out <- x  # default: unchanged (preserves length and NA positions)

  finite_idx <- which(is.finite(x))
  if (length(finite_idx) == 0L) return(out)

  # Use the longest contiguous run of finite values (X-13 needs a gap-free ts)
  runs       <- split(finite_idx, cumsum(c(1L, diff(finite_idx) != 1L)))
  longest    <- runs[[which.max(vapply(runs, length, integer(1)))]]
  min_needed <- 3L * freq  # at least 3 full cycles

  if (length(longest) < min_needed) return(out)

  span_x     <- x[longest]
  span_dates <- dates[longest]
  start_yr   <- lubridate::year(span_dates[[1L]])
  start_sub  <- if (freq == 12L) {
    lubridate::month(span_dates[[1L]])
  } else if (freq == 6L) {
    ((lubridate::month(span_dates[[1L]]) - 1L) %/% 2L) + 1L
  } else {
    lubridate::quarter(span_dates[[1L]])
  }

  ts_obj <- ts(span_x, start = c(start_yr, start_sub), frequency = freq)

  adjusted <- tryCatch({
    if (freq %in% c(12L, 4L)) {
      # X-13ARIMA-SEATS (native support only for monthly and quarterly)
      fit <- seasonal::seas(ts_obj, transform.function = "none", x11 = "", outlier = NULL)
      sa  <- as.numeric(seasonal::final(fit))
    } else {
      # X-13 cannot process freq != 4, 12 (e.g. bimonthly = 6).
      # Fall back to STL: seasonally adjusted = observed - seasonal component.
      fit <- stats::stl(ts_obj, s.window = "periodic", robust = TRUE)
      seasonal_comp <- as.numeric(fit$time.series[, "seasonal"])
      sa  <- as.numeric(ts_obj) - seasonal_comp
    }
    if (length(sa) == length(span_x)) sa else NULL
  }, error = function(e) {
    message("  SA failed (", state_id, ", freq=", freq, "): ",
            conditionMessage(e), " - using original series for this state.")
    NULL
  })

  if (!is.null(adjusted)) out[longest] <- adjusted
  out
}

# Apply X-13 to a long-format panel (one column per outcome variable)
# Returns the panel with additional *_sa columns
apply_x13_to_panel <- function(data, vars, date_col, group_col, freq) {
  message("Applying X-13 (freq=", freq, ") to: ", paste(vars, collapse = ", "))
  data |>
    dplyr::group_by(dplyr::across(dplyr::all_of(group_col))) |>
    dplyr::arrange(dplyr::across(dplyr::all_of(date_col)), .by_group = TRUE) |>
    dplyr::mutate(
      dplyr::across(
        dplyr::all_of(vars),
        function(col_vals) {
          state_id <- dplyr::cur_group()[[group_col]]
          x13_adjust(col_vals, .data[[date_col]], freq, state_id)
        },
        .names = "{.col}_sa"
      )
    ) |>
    dplyr::ungroup()
}

# ── ICMS from Annex 06 ──────────────────────────────────────────────────────
parse_siconfi_value <- function(x) {
  if (is.numeric(x)) return(as.numeric(x))
  x_chr  <- stringr::str_trim(as.character(x))
  parsed <- readr::parse_number(x_chr,
    locale = readr::locale(decimal_mark = ",", grouping_mark = "."),
    na = c("", "NA", "null"))
  fallback <- is.na(parsed) & nzchar(x_chr)
  parsed[fallback] <- suppressWarnings(as.numeric(x_chr[fallback]))
  parsed
}

impute_adjacent_mean <- function(data, value_col,
                                 order_col = "period_date",
                                 group_col = "state_abbrev") {
  value_sym <- rlang::sym(value_col)
  data |>
    dplyr::group_by(dplyr::across(dplyr::all_of(group_col))) |>
    dplyr::arrange(dplyr::across(dplyr::all_of(order_col)), .by_group = TRUE) |>
    dplyr::mutate(
      !!paste0("original_", value_col, "_missing") := is.na(!!value_sym),
      .lag  = dplyr::lag(!!value_sym),
      .lead = dplyr::lead(!!value_sym),
      .can  = is.na(!!value_sym) & is.finite(.lag) & is.finite(.lead),
      !!value_sym := dplyr::if_else(.can, (.lag + .lead) / 2, !!value_sym),
      !!paste0(value_col, "_imputed_adjacent_mean") := .can
    ) |>
    dplyr::ungroup() |>
    dplyr::select(-dplyr::any_of(c(".lag", ".lead", ".can")))
}

read_icms_annex06 <- function(start_year, end_year) {
  raw_path <- file.path(root_dir, "data", "raw", "siconfi",
                        "siconfi_rreo_state_fiscal_bimonthly_annex06_raw.csv")
  readr::read_csv(raw_path, show_col_types = FALSE) |>
    janitor::clean_names() |>
    dplyr::filter(
      .data$cod_conta == "RREO6ICMS",
      .data$exercicio >= start_year,
      .data$exercicio <= end_year
    ) |>
    dplyr::mutate(
      year     = as.integer(.data$exercicio),
      bimester = as.integer(.data$periodo),
      uf       = as.integer(.data$cod_ibge),
      coluna   = as.character(.data$coluna),
      value    = parse_siconfi_value(.data$valor),
      realized = .data$coluna == "RECEITAS REALIZADAS (a)" |
        stringr::str_detect(.data$coluna,
                            paste0("Até o Bimestre / ", .data$year))
    ) |>
    dplyr::filter(.data$realized) |>
    dplyr::group_by(.data$uf, .data$year, .data$bimester) |>
    dplyr::summarise(
      icms_revenue_cumulative_nominal = dplyr::first(.data$value[is.finite(.data$value)]),
      .groups = "drop"
    ) |>
    dplyr::group_by(.data$uf, .data$year) |>
    dplyr::arrange(.data$bimester, .by_group = TRUE) |>
    dplyr::mutate(
      icms_revenue_nominal           = .data$icms_revenue_cumulative_nominal -
                                       dplyr::lag(.data$icms_revenue_cumulative_nominal, default = 0),
      icms_revenue_flow_is_derived   = TRUE,
      icms_revenue_negative_flow_flag = .data$icms_revenue_nominal < 0
    ) |>
    dplyr::ungroup()
}

# ── Load source panels ────────────────────────────────────────────────────────

state_year_panel <- readr::read_csv(
  file.path(root_dir, "data", "processed", "state_year_panel_template.csv"),
  show_col_types = FALSE
) |>
  dplyr::transmute(
    state_abbrev           = .data$state_abbrev,
    year                   = as.integer(.data$year),
    resident_population_annual = as.numeric(.data$population)
  )

pnadc_quarterly <- readr::read_csv(
  file.path(root_dir, "data", "processed",
            "pnadc_sidra_quarterly_state_covariates_panel_ready.csv"),
  show_col_types = FALSE
) |>
  dplyr::mutate(
    period_date              = as.Date(.data$period_date),
    year                     = as.integer(.data$year),
    quarter                  = as.integer(.data$quarter),
    pnadc_population         = as.numeric(.data$pnadc_population),
    unemployment_rate_pnadc  = as.numeric(.data$unemployment_rate_pnadc),
    formalization_rate_pnadc = as.numeric(.data$formalization_rate_pnadc),
    labor_income_real_pnadc  = as.numeric(.data$labor_income_real_pnadc)
  )

retail_full <- readr::read_csv(
  file.path(root_dir, "data", "processed", "pmc_retail_monthly_panel_ready.csv"),
  show_col_types = FALSE
) |>
  dplyr::mutate(
    period_date        = as.Date(.data$period_date),
    retail_volume_index = as.numeric(.data$retail_volume_index)
  )

services_full <- readr::read_csv(
  file.path(root_dir, "data", "processed", "pms_services_monthly_panel_ready.csv"),
  show_col_types = FALSE
) |>
  dplyr::mutate(
    period_date          = as.Date(.data$period_date),
    services_volume_index = as.numeric(.data$services_volume_index)
  )

caged_full <- readr::read_csv(
  file.path(root_dir, "data", "processed",
            "caged_state_balance_monthly_panel_ready.csv"),
  show_col_types = FALSE
) |>
  dplyr::mutate(
    period_date           = as.Date(.data$period_date),
    formal_hiring_balance = as.numeric(.data$formal_hiring_balance)
  )

construction_full <- readr::read_csv(
  file.path(root_dir, "data", "processed",
            "caged_construction_state_balance_monthly_panel_ready.csv"),
  show_col_types = FALSE
) |>
  dplyr::mutate(
    period_date                       = as.Date(.data$period_date),
    formal_hiring_balance_construction = as.numeric(.data$formal_hiring_balance_construction)
  )

fiscal_full <- readr::read_csv(
  file.path(root_dir, "data", "processed",
            "siconfi_rreo_state_fiscal_bimonthly_panel_ready.csv"),
  show_col_types = FALSE
) |>
  dplyr::mutate(
    period_date = as.Date(.data$period_date),
    year        = as.integer(.data$year),
    bimester    = as.integer(.data$bimester),
    quarter     = lubridate::quarter(.data$period_date)
  )

# ── Apply X-13 to full series before subsetting to pilot window ───────────────

message("--- X-13 seasonal adjustment ---")

# Monthly employment (freq = 12)
caged_sa <- caged_full |>
  dplyr::select(.data$state_abbrev, .data$period_date, .data$formal_hiring_balance) |>
  apply_x13_to_panel("formal_hiring_balance", "period_date", "state_abbrev", 12L)

construction_sa <- construction_full |>
  dplyr::select(.data$state_abbrev, .data$period_date, .data$formal_hiring_balance_construction) |>
  apply_x13_to_panel("formal_hiring_balance_construction", "period_date", "state_abbrev", 12L)

# Rebase index series to 100 at first valid value in pilot window before X-13,
# because PMC/PMS are already indices; X-13 applied to the index level directly.
retail_sa <- retail_full |>
  dplyr::select(.data$state_abbrev, .data$period_date, .data$retail_volume_index) |>
  apply_x13_to_panel("retail_volume_index", "period_date", "state_abbrev", 12L)

services_sa <- services_full |>
  dplyr::select(.data$state_abbrev, .data$period_date, .data$services_volume_index) |>
  apply_x13_to_panel("services_volume_index", "period_date", "state_abbrev", 12L)

# Quarterly PNADc covariates (freq = 4)
pnadc_sa <- pnadc_quarterly |>
  dplyr::select(.data$state_abbrev, .data$period_date,
                .data$unemployment_rate_pnadc, .data$formalization_rate_pnadc,
                .data$labor_income_real_pnadc) |>
  apply_x13_to_panel(
    c("unemployment_rate_pnadc", "formalization_rate_pnadc", "labor_income_real_pnadc"),
    "period_date", "state_abbrev", 4L
  )

# ── ICMS with RS 2018 imputation (same as v1) ─────────────────────────────────
icms_revenue <- read_icms_annex06(2014, 2019)

rs_uf_code <- 43L
rs_2017_flows <- icms_revenue |>
  dplyr::filter(.data$uf == rs_uf_code, .data$year == 2017L) |>
  dplyr::arrange(.data$bimester) |>
  dplyr::select(.data$bimester, .data$icms_revenue_nominal)

rs_2018_annual <- icms_revenue |>
  dplyr::filter(.data$uf == rs_uf_code, .data$year == 2018L, .data$bimester == 6L) |>
  dplyr::pull(.data$icms_revenue_cumulative_nominal)

if (nrow(rs_2017_flows) == 6 && all(is.finite(rs_2017_flows$icms_revenue_nominal)) &&
    length(rs_2018_annual) == 1 && is.finite(rs_2018_annual)) {
  total_2017 <- sum(rs_2017_flows$icms_revenue_nominal)
  imputed_b1b5 <- rs_2017_flows |>
    dplyr::filter(.data$bimester %in% 1L:5L) |>
    dplyr::mutate(
      uf = rs_uf_code, year = 2018L,
      icms_revenue_nominal = .data$icms_revenue_nominal / total_2017 * rs_2018_annual,
      icms_revenue_flow_is_derived    = TRUE,
      icms_revenue_negative_flow_flag = FALSE,
      icms_rs_2018_seasonal_imputed   = TRUE
    ) |>
    dplyr::arrange(.data$bimester) |>
    dplyr::mutate(icms_revenue_cumulative_nominal = cumsum(.data$icms_revenue_nominal)) |>
    dplyr::select("uf", "year", "bimester", "icms_revenue_cumulative_nominal",
                  "icms_revenue_nominal", "icms_revenue_flow_is_derived",
                  "icms_revenue_negative_flow_flag", "icms_rs_2018_seasonal_imputed")

  b5_cumul <- imputed_b1b5 |> dplyr::filter(.data$bimester == 5L) |>
    dplyr::pull(.data$icms_revenue_cumulative_nominal)

  rs_b6_fix <- tibble::tibble(
    uf = rs_uf_code, year = 2018L, bimester = 6L,
    icms_revenue_cumulative_nominal = rs_2018_annual,
    icms_revenue_nominal            = rs_2018_annual - b5_cumul,
    icms_revenue_flow_is_derived    = TRUE,
    icms_revenue_negative_flow_flag = (rs_2018_annual - b5_cumul) < 0,
    icms_rs_2018_seasonal_imputed   = FALSE
  )

  icms_revenue <- icms_revenue |>
    dplyr::mutate(icms_rs_2018_seasonal_imputed = FALSE) |>
    dplyr::filter(!(.data$uf == rs_uf_code & .data$year == 2018L)) |>
    dplyr::bind_rows(imputed_b1b5, rs_b6_fix) |>
    dplyr::arrange(.data$uf, .data$year, .data$bimester)
  message("RS 2018 ICMS: imputed B1-B5 with 2017 seasonal shares.")
} else {
  icms_revenue <- icms_revenue |> dplyr::mutate(icms_rs_2018_seasonal_imputed = FALSE)
}

# Handle negative ICMS flows
icms_revenue <- icms_revenue |>
  dplyr::group_by(.data$uf, .data$year) |>
  dplyr::arrange(.data$bimester, .by_group = TRUE) |>
  dplyr::mutate(
    .lg = dplyr::lag(.data$icms_revenue_nominal),
    .ld = dplyr::lead(.data$icms_revenue_nominal),
    .fix = .data$icms_revenue_negative_flow_flag &
           is.finite(.lg) & .lg >= 0 & is.finite(.ld) & .ld >= 0,
    icms_revenue_nominal = dplyr::if_else(.data$.fix, (.lg + .ld) / 2,
                                          .data$icms_revenue_nominal),
    icms_revenue_negative_flow_imputed = .data$.fix
  ) |>
  dplyr::ungroup() |>
  dplyr::select(-dplyr::any_of(c(".lg", ".ld", ".fix")))

# ── Bimonthly fiscal panel with X-13 ─────────────────────────────────────────
fiscal_joined <- fiscal_full |>
  dplyr::left_join(icms_revenue, by = c("uf", "year", "bimester")) |>
  dplyr::left_join(state_year_panel, by = c("state_abbrev", "year")) |>
  dplyr::left_join(
    pnadc_quarterly |>
      dplyr::select("state_abbrev", "year", "quarter", "pnadc_population"),
    by = c("state_abbrev", "year", "quarter")
  ) |>
  dplyr::mutate(
    fiscal_deflator_factor = dplyr::if_else(
      is.finite(.data$state_tax_revenue_nominal) & .data$state_tax_revenue_nominal > 0,
      .data$state_tax_revenue_real / .data$state_tax_revenue_nominal, NA_real_
    ),
    icms_revenue_real    = .data$icms_revenue_nominal * .data$fiscal_deflator_factor,
    icms_revenue_real_pc = .data$icms_revenue_real / .data$resident_population_annual,
    state_tax_revenue_real_pc          = .data$state_tax_revenue_real / .data$resident_population_annual,
    public_investment_liquidated_real_pc = .data$public_investment_liquidated_real / .data$resident_population_annual,
    liquidated_expenditure_total_real_pc = .data$liquidated_expenditure_total_real / .data$resident_population_annual,
    liquidated_expenditure_health_real_pc       = .data$liquidated_expenditure_health_real / .data$resident_population_annual,
    liquidated_expenditure_education_real_pc    = .data$liquidated_expenditure_education_real / .data$resident_population_annual,
    liquidated_expenditure_public_security_real_pc = .data$liquidated_expenditure_public_security_real / .data$resident_population_annual,
    transfer_dependency_ratio = as.numeric(.data$transfer_dependency_ratio)
  ) |>
  impute_adjacent_mean("liquidated_expenditure_health_real_pc") |>
  impute_adjacent_mean("liquidated_expenditure_education_real_pc") |>
  impute_adjacent_mean("liquidated_expenditure_public_security_real_pc")

# Apply X-13 to bimonthly fiscal outcomes (freq = 6)
fiscal_outcome_vars <- c(
  "icms_revenue_real_pc", "state_tax_revenue_real_pc",
  "public_investment_liquidated_real_pc", "liquidated_expenditure_total_real_pc"
)
fiscal_cov_vars <- c(
  "liquidated_expenditure_health_real_pc",
  "liquidated_expenditure_education_real_pc",
  "liquidated_expenditure_public_security_real_pc",
  "transfer_dependency_ratio"
)

fiscal_sa <- fiscal_joined |>
  apply_x13_to_panel(c(fiscal_outcome_vars, fiscal_cov_vars),
                     "period_date", "state_abbrev", 6L)

# ── Build pilot-window panels ─────────────────────────────────────────────────

# Rebase SA index series to 100 at first valid observation within pilot window
rebase_sa_in_window <- function(data, vars, window_start, window_end) {
  data_window <- data |> dplyr::filter(
    .data$period_date >= window_start, .data$period_date <= window_end
  )

  for (v in vars) {
    v_sym <- rlang::sym(v)
    base_tbl <- data_window |>
      dplyr::group_by(.data$state_abbrev) |>
      dplyr::arrange(.data$period_date, .by_group = TRUE) |>
      dplyr::summarise(
        .base = {
          vals <- (!!v_sym)
          finite_vals <- vals[is.finite(vals)]
          if (length(finite_vals) == 0L) NA_real_ else finite_vals[[1L]]
        },
        .groups = "drop"
      )

    data_window <- data_window |>
      dplyr::left_join(base_tbl, by = "state_abbrev") |>
      dplyr::mutate(
        !!v_sym := dplyr::if_else(
          is.finite(.data$.base) & .data$.base != 0,
          100 * (!!v_sym) / .data$.base,
          NA_real_
        )
      ) |>
      dplyr::select(-.data$.base)
  }
  data_window
}

# Monthly panel
monthly_base <- caged_sa |>
  dplyr::left_join(construction_sa |> dplyr::select("state_abbrev", "period_date",
                   "formal_hiring_balance_construction_sa"),
                   by = c("state_abbrev", "period_date")) |>
  dplyr::left_join(retail_sa |> dplyr::select("state_abbrev", "period_date",
                   "retail_volume_index_sa"),
                   by = c("state_abbrev", "period_date")) |>
  dplyr::left_join(services_sa |> dplyr::select("state_abbrev", "period_date",
                   "services_volume_index_sa"),
                   by = c("state_abbrev", "period_date")) |>
  dplyr::left_join(caged_full |> dplyr::select("state_abbrev", "period_date",
                   "state_name", "macroregion", "uf",
                   "year", "month" = dplyr::any_of("month")),
                   by = c("state_abbrev", "period_date")) |>
  dplyr::mutate(quarter = lubridate::quarter(.data$period_date)) |>
  dplyr::left_join(
    pnadc_quarterly |> dplyr::select("state_abbrev", "year", "quarter", "pnadc_population"),
    by = c("state_abbrev", "year", "quarter")
  ) |>
  dplyr::filter(
    .data$period_date >= monthly_window_start,
    .data$period_date <= monthly_window_end
  )

# Rebase retail/services SA to 100 at first valid in pilot window
monthly_base <- rebase_sa_in_window(
  monthly_base,
  c("retail_volume_index_sa", "services_volume_index_sa"),
  monthly_window_start, monthly_window_end
)

monthly_panel <- monthly_base |>
  dplyr::mutate(
    treated_unit              = .data$state_abbrev == treated_state,
    donor_pool_main           = !(.data$state_abbrev %in% excluded_donor_states),
    excluded_from_main_donor_pool = .data$state_abbrev %in% excluded_donor_states,
    donor_pool_exclusion_reason   = dplyr::if_else(
      .data$state_abbrev == treated_state, "treated_unit", NA_character_
    ),
    analysis_period           = assign_period_monthly(.data$period_date),
    pre_instability_clean     = .data$analysis_period == "pre",
    formal_hiring_balance_sa_per_100k_wap =
      100000 * .data$formal_hiring_balance_sa / .data$pnadc_population,
    formal_hiring_balance_construction_sa_per_100k_wap =
      100000 * .data$formal_hiring_balance_construction_sa / .data$pnadc_population,
    instability_start_date    = instability_start_date,
    removal_date              = removal_date
  ) |>
  dplyr::left_join(excluded_event_lookup, by = "state_abbrev", suffix = c("", "_ev")) |>
  dplyr::mutate(
    donor_pool_exclusion_reason = dplyr::coalesce(
      .data$donor_pool_exclusion_reason, .data$donor_pool_exclusion_reason_ev
    )
  ) |>
  dplyr::select(-dplyr::any_of("donor_pool_exclusion_reason_ev"))

# Bimonthly fiscal panel
fiscal_panel <- fiscal_sa |>
  dplyr::filter(
    .data$period_date >= bimonthly_window_start,
    .data$period_date <= bimonthly_window_end
  ) |>
  dplyr::mutate(
    treated_unit              = .data$state_abbrev == treated_state,
    donor_pool_main           = !(.data$state_abbrev %in% excluded_donor_states),
    excluded_from_main_donor_pool = .data$state_abbrev %in% excluded_donor_states,
    donor_pool_exclusion_reason   = dplyr::if_else(
      .data$state_abbrev == treated_state, "treated_unit", NA_character_
    ),
    analysis_period           = assign_period_bimonthly(.data$year, .data$bimester),
    pre_instability_clean     = .data$analysis_period == "pre",
    instability_start_date    = instability_start_date,
    removal_date              = removal_date
  ) |>
  dplyr::left_join(excluded_event_lookup, by = "state_abbrev", suffix = c("", "_ev")) |>
  dplyr::mutate(
    donor_pool_exclusion_reason = dplyr::coalesce(
      .data$donor_pool_exclusion_reason, .data$donor_pool_exclusion_reason_ev
    )
  ) |>
  dplyr::select(-dplyr::any_of("donor_pool_exclusion_reason_ev"))

# Quarterly PNADc panel (SA covariates only)
quarterly_panel <- pnadc_sa |>
  dplyr::filter(
    .data$period_date >= quarterly_window_start,
    .data$period_date <= quarterly_window_end
  ) |>
  dplyr::mutate(
    year    = lubridate::year(.data$period_date),
    quarter = lubridate::quarter(.data$period_date),
    treated_unit              = .data$state_abbrev == treated_state,
    donor_pool_main           = !(.data$state_abbrev %in% excluded_donor_states),
    excluded_from_main_donor_pool = .data$state_abbrev %in% excluded_donor_states,
    donor_pool_exclusion_reason   = dplyr::if_else(
      .data$state_abbrev == treated_state, "treated_unit", NA_character_
    ),
    analysis_period           = assign_period_quarterly(.data$period_date),
    instability_start_date    = instability_start_date,
    removal_date              = removal_date
  ) |>
  dplyr::left_join(excluded_event_lookup, by = "state_abbrev", suffix = c("", "_ev")) |>
  dplyr::mutate(
    donor_pool_exclusion_reason = dplyr::coalesce(
      .data$donor_pool_exclusion_reason, .data$donor_pool_exclusion_reason_ev
    )
  ) |>
  dplyr::select(-dplyr::any_of("donor_pool_exclusion_reason_ev"))

# ── Covariates (pre-treatment means of SA series) ──────────────────────────────
covariates <- monthly_panel |>
  dplyr::filter(.data$analysis_period == "pre") |>
  dplyr::group_by(.data$state_abbrev) |>
  dplyr::summarise(monthly_pre_periods = dplyr::n(), .groups = "drop") |>
  dplyr::left_join(
    quarterly_panel |>
      dplyr::filter(.data$analysis_period == "pre") |>
      dplyr::group_by(.data$state_abbrev) |>
      dplyr::summarise(
        unemployment_rate  = mean(.data$unemployment_rate_pnadc_sa,  na.rm = TRUE),
        formalization_rate = mean(.data$formalization_rate_pnadc_sa, na.rm = TRUE),
        labor_income_real  = mean(.data$labor_income_real_pnadc_sa,  na.rm = TRUE),
        .groups = "drop"
      ),
    by = "state_abbrev"
  ) |>
  dplyr::left_join(
    fiscal_panel |>
      dplyr::filter(.data$analysis_period == "pre") |>
      dplyr::group_by(.data$state_abbrev) |>
      dplyr::summarise(
        transfer_dependency_ratio          = mean(.data$transfer_dependency_ratio_sa,                    na.rm = TRUE),
        health_expenditure_real_pc         = mean(.data$liquidated_expenditure_health_real_pc_sa,        na.rm = TRUE),
        education_expenditure_real_pc      = mean(.data$liquidated_expenditure_education_real_pc_sa,     na.rm = TRUE),
        public_security_expenditure_real_pc = mean(.data$liquidated_expenditure_public_security_real_pc_sa, na.rm = TRUE),
        .groups = "drop"
      ),
    by = "state_abbrev"
  ) |>
  dplyr::mutate(
    donor_pool_main               = !(.data$state_abbrev %in% excluded_donor_states),
    excluded_from_main_donor_pool = .data$state_abbrev %in% excluded_donor_states
  ) |>
  dplyr::left_join(excluded_event_lookup, by = "state_abbrev") |>
  dplyr::mutate(
    donor_pool_exclusion_reason = dplyr::case_when(
      .data$state_abbrev == treated_state ~ "treated_unit",
      .data$excluded_from_main_donor_pool ~ .data$donor_pool_exclusion_reason,
      TRUE ~ NA_character_
    )
  ) |>
  dplyr::arrange(.data$state_abbrev)

# ── Event metadata ────────────────────────────────────────────────────────────
event_metadata <- event |>
  dplyr::mutate(
    pilot_id                 = pilot_id,
    monthly_window_start     = monthly_window_start,
    monthly_window_end       = monthly_window_end,
    bimonthly_window_start   = bimonthly_window_start,
    bimonthly_window_end     = bimonthly_window_end,
    quarterly_window_start   = quarterly_window_start,
    quarterly_window_end     = quarterly_window_end,
    donor_exclusion_window_start = donor_exclusion_window_start,
    donor_exclusion_window_end   = donor_exclusion_window_end,
    crisis_end_monthly           = crisis_end_monthly,
    crisis_end_bimonthly         = crisis_end_bimonthly,
    sa_method                    = "X-13 (freq 12/4); STL fallback for bimonthly freq 6"
  )

# ── Write outputs ─────────────────────────────────────────────────────────────
readr::write_csv(monthly_panel,   file.path(pilot_data_dir, "am_2017_01_v2_monthly_panel.csv"),           na = "")
readr::write_csv(fiscal_panel,    file.path(pilot_data_dir, "am_2017_01_v2_bimonthly_fiscal_panel.csv"),  na = "")
readr::write_csv(quarterly_panel, file.path(pilot_data_dir, "am_2017_01_v2_quarterly_pnadc_panel.csv"),   na = "")
readr::write_csv(covariates,      file.path(pilot_data_dir, "am_2017_01_v2_covariates.csv"),              na = "")
readr::write_csv(event_metadata,  file.path(pilot_data_dir, "am_2017_01_v2_event_metadata.csv"),          na = "")

message("AM 2017-01 V2 panels built (X-13 SA):")
message("  monthly rows: ",          nrow(monthly_panel))
message("  bimonthly fiscal rows: ", nrow(fiscal_panel))
message("  quarterly rows: ",        nrow(quarterly_panel))
message("  covariate rows: ",        nrow(covariates))
