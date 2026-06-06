source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

extra_packages <- c("tidyr", "janitor", "seasonal")
missing_extra <- extra_packages[!vapply(extra_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_extra) > 0) {
  stop("Missing required packages: ", paste(missing_extra, collapse = ", "))
}
invisible(lapply(extra_packages, library, character.only = TRUE))

pilot_id      <- "pi_2001_01_v1"
event_id      <- "PI_2001_01"
treated_state <- "PI"

pilot_root     <- file.path(root_dir, "pilots", pilot_id)
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

# ── Window design (ACCOUNTABILITY FRAME, all monthly, X-13) ───────────────────
#
# Treatment = the effective removal (TSE electoral cassation, 2001-11-06). No
# separate crisis window: this is an accountability event with a single cut at
# the removal date.
#
# Pre-treatment target = 36 MONTHS (default). When an outcome's data does not
# reach 36 months, the SCM uses the MAXIMUM AVAILABLE down to a documented floor
# of 20 months (`min_pre_periods`); outcomes with fewer than 20 pre-months are
# skipped. Post = 24 MONTHS.
#
#   Pre  (36m): 1998-11 .. 2001-10
#   Post (24m): 2001-11 .. 2003-10
#
# Availability differs by outcome and is handled per-outcome by the SCM
# (complete-case pre-window):
#   - CONFAZ ICMS value-added: full coverage from 1997 -> 36 pre-months.
#   - PMC retail volume index: PI starts 2000-01 -> 22 pre-months (>= 20 floor).

min_pre_periods      <- 20L
removal_month        <- lubridate::floor_date(removal_date, "month")
monthly_window_start <- removal_month %m-% months(36L)          # 1998-11-01
monthly_window_end   <- removal_month %m+% months(24L - 1L)     # 2003-10-01

donor_exclusion_window_start <- monthly_window_start
donor_exclusion_window_end   <- monthly_window_end

# ── Donor-pool exclusions ─────────────────────────────────────────────────────
# Exclude any state that is itself a treated unit anywhere in the SCM window
# (pre OR post), i.e. any state with a coded removal in
# [monthly_window_start, monthly_window_end].
excluded_event_lookup <- event_inventory |>
  dplyr::mutate(removal_date = as.Date(.data$removal_date)) |>
  dplyr::filter(
    !is.na(.data$removal_date),
    .data$removal_date >= donor_exclusion_window_start,
    .data$removal_date <= donor_exclusion_window_end
  ) |>
  dplyr::group_by(.data$state_abbrev) |>
  dplyr::summarise(
    donor_pool_exclusion_reason = paste0(
      "coded_removal_in_scm_window:",
      paste(sort(unique(.data$event_id)), collapse = ",")
    ),
    .groups = "drop"
  )

excluded_donor_states <- sort(unique(c(treated_state, excluded_event_lookup$state_abbrev)))

# ── Period assignment (ACCOUNTABILITY: single cut at removal_month) ────────────
assign_period_monthly <- function(period_date) {
  dplyr::if_else(period_date < removal_month, "pre", "post")
}

# ── X-13 seasonal adjustment ──────────────────────────────────────────────────
# Applied to the FULL available series per state (not just the pilot window) to
# get the best estimate of seasonal factors. All series are monthly (freq 12),
# so X-13ARIMA-SEATS is used throughout. Falls back to the original series if
# X-13 fails for a given state (e.g. constant/all-zero series).
x13_adjust <- function(x, dates, freq, state_id = "") {
  out <- x
  finite_idx <- which(is.finite(x))
  if (length(finite_idx) == 0L) return(out)

  runs       <- split(finite_idx, cumsum(c(1L, diff(finite_idx) != 1L)))
  longest    <- runs[[which.max(vapply(runs, length, integer(1)))]]
  min_needed <- 3L * freq

  if (length(longest) < min_needed) return(out)

  span_x     <- x[longest]
  span_dates <- dates[longest]
  start_yr   <- lubridate::year(span_dates[[1L]])
  start_sub  <- lubridate::month(span_dates[[1L]])

  ts_obj <- ts(span_x, start = c(start_yr, start_sub), frequency = freq)

  adjusted <- tryCatch({
    fit <- seasonal::seas(ts_obj, transform.function = "none", x11 = "", outlier = NULL)
    sa  <- as.numeric(seasonal::final(fit))
    if (length(sa) == length(span_x)) sa else NULL
  }, error = function(e) {
    message("  SA failed (", state_id, ", freq=", freq, "): ",
            conditionMessage(e), " - using original series for this state.")
    NULL
  })

  if (!is.null(adjusted)) out[longest] <- adjusted
  out
}

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

# Rebase an SA index series to 100 at the first valid observation in the window.
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
          100 * (!!v_sym) / .data$.base, NA_real_
        )
      ) |>
      dplyr::select(-.data$.base)
  }
  data_window
}

# ── Load source panels ────────────────────────────────────────────────────────

confaz <- readr::read_csv(
  file.path(root_dir, "data", "processed",
            "confaz_state_tax_revenue_monthly_panel_ready.csv"),
  show_col_types = FALSE
) |>
  dplyr::transmute(
    state_abbrev = .data$state_abbrev,
    period_date  = as.Date(.data$period_date),
    year         = as.integer(.data$year),
    month        = as.integer(.data$month),
    va_icms_total               = as.numeric(.data$va_icms_total),
    va_receita_tributaria_total = as.numeric(.data$va_receita_tributaria_total),
    va_icms_terciario_varejista = as.numeric(.data$va_icms_terciario_varejista),
    va_icms_secundario          = as.numeric(.data$va_icms_secundario),
    va_icms_terciario           = as.numeric(.data$va_icms_terciario),
    va_icms_energia             = as.numeric(.data$va_icms_energia),
    va_icms_combustiveis        = as.numeric(.data$va_icms_combustiveis)
  )

tesouro <- readr::read_csv(
  file.path(root_dir, "data", "processed",
            "tesouro_transferencias_obrigatorias_state_month_panel_ready.csv"),
  show_col_types = FALSE
) |>
  dplyr::transmute(
    state_abbrev = .data$state_abbrev,
    period_date  = as.Date(.data$period_date),
    fpe          = as.numeric(.data$fpe),
    iof_est      = as.numeric(.data$iof_est)
  )

retail_full <- readr::read_csv(
  file.path(root_dir, "data", "processed", "pmc_retail_monthly_panel_ready.csv"),
  show_col_types = FALSE
) |>
  dplyr::transmute(
    state_abbrev        = .data$state_abbrev,
    period_date         = as.Date(.data$period_date),
    retail_volume_index = as.numeric(.data$retail_volume_index)
  )

population <- readr::read_csv(
  file.path(root_dir, "data", "processed", "resident_population_annual_panel_ready.csv"),
  show_col_types = FALSE
) |>
  dplyr::transmute(
    state_abbrev = .data$state_abbrev,
    year         = as.integer(.data$year),
    population   = as.numeric(.data$population)
  )

pop_year_min <- min(population$year)
pop_year_max <- max(population$year)

# IPCA national index (base dez/1993 = 100; chained across currency reforms,
# so within-window ratios are valid). Deflate to real R$ of the removal month.
ipca <- readr::read_csv(
  file.path(root_dir, "data", "raw", "ibge", "ipca_national_monthly.csv"),
  show_col_types = FALSE
) |>
  dplyr::transmute(
    mes_codigo = as.integer(.data$mes_codigo),
    ipca_index = as.numeric(.data$valor)
  ) |>
  dplyr::arrange(.data$mes_codigo)

ipca_base_code  <- as.integer(lubridate::year(removal_month) * 100 + lubridate::month(removal_month))
ipca_base_value <- ipca$ipca_index[ipca$mes_codigo == ipca_base_code]
if (length(ipca_base_value) != 1 || !is.finite(ipca_base_value)) {
  stop("IPCA base index not found for ", ipca_base_code)
}

ipca_deflator <- ipca |>
  dplyr::transmute(
    period_date  = as.Date(sprintf("%d-%02d-01", .data$mes_codigo %/% 100L, .data$mes_codigo %% 100L)),
    ipca_deflator_factor = ipca_base_value / .data$ipca_index   # real R$ of removal month
  )

# ── Assemble the nominal monthly panel ────────────────────────────────────────
# CONFAZ drives the panel (full ICMS coverage 1997-2023). Tesouro / retail /
# population / IPCA are joined on.
nominal_panel <- confaz |>
  dplyr::left_join(tesouro, by = c("state_abbrev", "period_date")) |>
  dplyr::left_join(retail_full, by = c("state_abbrev", "period_date")) |>
  dplyr::left_join(ipca_deflator, by = "period_date") |>
  dplyr::mutate(pop_year = pmin(pmax(.data$year, pop_year_min), pop_year_max)) |>
  dplyr::left_join(
    population |> dplyr::rename(pop_year = "year"),
    by = c("state_abbrev", "pop_year")
  )

# Real per capita = nominal * deflator / population (real R$ of removal month).
monetary_vars <- c(
  "va_icms_total", "va_receita_tributaria_total", "va_icms_terciario_varejista",
  "va_icms_secundario", "va_icms_terciario", "va_icms_energia",
  "va_icms_combustiveis", "fpe", "iof_est"
)

real_pc_panel <- nominal_panel
for (v in monetary_vars) {
  real_pc_panel[[paste0(v, "_real_pc")]] <-
    real_pc_panel[[v]] * real_pc_panel$ipca_deflator_factor / real_pc_panel$population
}

# ── X-13 seasonal adjustment (freq 12) on the full series ─────────────────────
sa_vars <- c(paste0(monetary_vars, "_real_pc"), "retail_volume_index")

sa_panel <- real_pc_panel |>
  apply_x13_to_panel(sa_vars, "period_date", "state_abbrev", 12L)

# ── Build the pilot-window monthly panel ──────────────────────────────────────
# Driven by a FULL state x month grid over the window so every outcome can use
# its maximum available pre-window; missing months stay NA and the SCM handles
# them per-outcome via complete-case.
panel_states <- sort(unique(confaz$state_abbrev))
window_dates <- seq(monthly_window_start, monthly_window_end, by = "1 month")

monthly_grid <- tidyr::expand_grid(
  state_abbrev = panel_states,
  period_date  = window_dates
) |>
  dplyr::mutate(
    year  = lubridate::year(.data$period_date),
    month = lubridate::month(.data$period_date)
  )

monthly_panel <- monthly_grid |>
  dplyr::left_join(
    sa_panel |> dplyr::select(-dplyr::any_of(c("year", "month", "pop_year"))),
    by = c("state_abbrev", "period_date")
  ) |>
  dplyr::filter(
    .data$period_date >= monthly_window_start,
    .data$period_date <= monthly_window_end
  ) |>
  dplyr::mutate(
    treated_unit                  = .data$state_abbrev == treated_state,
    donor_pool_main               = !(.data$state_abbrev %in% excluded_donor_states),
    excluded_from_main_donor_pool = .data$state_abbrev %in% excluded_donor_states,
    donor_pool_exclusion_reason   = dplyr::if_else(
      .data$state_abbrev == treated_state, "treated_unit", NA_character_
    ),
    analysis_period       = assign_period_monthly(.data$period_date),
    pre_instability_clean = .data$analysis_period == "pre",
    instability_start_date = instability_start_date,
    removal_date           = removal_date
  ) |>
  dplyr::left_join(excluded_event_lookup, by = "state_abbrev", suffix = c("", "_ev")) |>
  dplyr::mutate(
    donor_pool_exclusion_reason = dplyr::coalesce(
      .data$donor_pool_exclusion_reason, .data$donor_pool_exclusion_reason_ev
    )
  ) |>
  dplyr::select(-dplyr::any_of("donor_pool_exclusion_reason_ev"))

# Rebase the retail index (SA) to 100 at the first valid window observation.
monthly_panel <- rebase_sa_in_window(
  monthly_panel, "retail_volume_index_sa",
  monthly_window_start, monthly_window_end
)

# ── Covariates (pre-treatment means of SA real-per-capita series) ─────────────
# "own variable (lags)" enters automatically as the full pre-path in the SCM
# predictor matrix; these are the additional covariates requested.
covariate_sa_vars <- c(
  "va_icms_secundario_real_pc_sa", "va_icms_terciario_real_pc_sa",
  "va_icms_energia_real_pc_sa", "va_icms_combustiveis_real_pc_sa",
  "fpe_real_pc_sa", "iof_est_real_pc_sa"
)

covariates <- monthly_panel |>
  dplyr::filter(.data$analysis_period == "pre") |>
  dplyr::group_by(.data$state_abbrev) |>
  dplyr::summarise(
    monthly_pre_periods            = dplyr::n(),
    va_icms_secundario_real_pc     = mean(.data$va_icms_secundario_real_pc_sa,   na.rm = TRUE),
    va_icms_terciario_real_pc      = mean(.data$va_icms_terciario_real_pc_sa,    na.rm = TRUE),
    va_icms_energia_real_pc        = mean(.data$va_icms_energia_real_pc_sa,      na.rm = TRUE),
    va_icms_combustiveis_real_pc   = mean(.data$va_icms_combustiveis_real_pc_sa, na.rm = TRUE),
    fpe_real_pc                    = mean(.data$fpe_real_pc_sa,                  na.rm = TRUE),
    iof_est_real_pc                = mean(.data$iof_est_real_pc_sa,              na.rm = TRUE),
    .groups = "drop"
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
    pilot_id                     = pilot_id,
    monthly_window_start         = monthly_window_start,
    monthly_window_end           = monthly_window_end,
    removal_month                = removal_month,
    pre_target_months            = 36L,
    pre_floor_months             = min_pre_periods,
    post_months                  = 24L,
    donor_exclusion_window_start = donor_exclusion_window_start,
    donor_exclusion_window_end   = donor_exclusion_window_end,
    treatment_frame              = "accountability: single cut at removal_date; no crisis window",
    sa_method                    = "all outcomes monthly + X-13 (freq 12)",
    deflation                    = paste0("IPCA index (base dez/1993); real R$ of removal month ", ipca_base_code),
    per_capita                   = "resident population (annual; year clamped to [1999,2025] for SA continuity)"
  )

# ── Write outputs ─────────────────────────────────────────────────────────────
readr::write_csv(monthly_panel,  file.path(pilot_data_dir, "pi_2001_01_v1_monthly_panel.csv"),    na = "")
readr::write_csv(covariates,     file.path(pilot_data_dir, "pi_2001_01_v1_covariates.csv"),        na = "")
readr::write_csv(event_metadata, file.path(pilot_data_dir, "pi_2001_01_v1_event_metadata.csv"),    na = "")

message("PI 2001-01 V1 panels built (all monthly + X-13 freq 12):")
message("  monthly panel rows: ", nrow(monthly_panel))
message("  covariate rows: ",     nrow(covariates))
message("  excluded donor states: ", paste(excluded_donor_states, collapse = ", "))
message("  pre window: ", monthly_window_start, " .. ", removal_month %m-% months(1L),
        " (target 36m, floor ", min_pre_periods, "m)")
message("  post window: ", removal_month, " .. ", monthly_window_end, " (24m)")
