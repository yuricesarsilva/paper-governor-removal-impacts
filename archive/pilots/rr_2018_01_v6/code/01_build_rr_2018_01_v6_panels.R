source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

pilot_id      <- "rr_2018_01_v6"
event_id      <- "RR_2018_01"
treated_state <- "RR"

pilot_root      <- file.path(root_dir, "archive", "pilots", pilot_id)
pilot_data_dir  <- file.path(pilot_root, "data")
engine_data_dir <- file.path(root_dir, "output", event_id, "data")
confaz_path     <- file.path(root_dir, "data", "processed",
                             "confaz_state_tax_revenue_monthly_panel_ready.csv")
caged_path      <- file.path(root_dir, "data", "processed",
                             "caged_state_balance_monthly_panel_ready.csv")
pop_path        <- file.path(root_dir, "data", "processed",
                             "estimapop_resident_population_annual_panel_ready.csv")
dir.create(pilot_data_dir, recursive = TRUE, showWarnings = FALSE)

# ── Event metadata ────────────────────────────────────────────────────────────
event_meta <- readr::read_csv(
  file.path(engine_data_dir, paste0(event_id, "_event_metadata.csv")),
  show_col_types = FALSE
) |> dplyr::slice(1)

removal_date           <- as.Date(event_meta$removal_date[[1]])
instability_start_date <- as.Date(event_meta$instability_start_date[[1]])

event_month_date <- lubridate::floor_date(removal_date, "month")  # 2018-12-01

compute_event_time <- function(period_date) {
  12L * (lubridate::year(period_date) - lubridate::year(event_month_date)) +
    (lubridate::month(period_date) - lubridate::month(event_month_date))
}

# ── Trailing-window helpers ───────────────────────────────────────────────────
trailing_mean_k <- function(x, k) {
  purrr::map_dbl(seq_along(x), function(i) {
    if (i < k) return(NA_real_)
    vals <- x[(i - k + 1):i]
    if (any(!is.finite(vals))) return(NA_real_)
    mean(vals)
  })
}

trailing_sum_k <- function(x, k) {
  purrr::map_dbl(seq_along(x), function(i) {
    if (i < k) return(NA_real_)
    vals <- x[(i - k + 1):i]
    if (any(!is.finite(vals))) return(NA_real_)
    sum(vals)
  })
}

# ── Monthly base panel (engine output) ───────────────────────────────────────
monthly_raw <- readr::read_csv(
  file.path(engine_data_dir, paste0(event_id, "_monthly_panel.csv")),
  show_col_types = FALSE
) |>
  dplyr::mutate(period_date = as.Date(.data$period_date),
                event_time  = compute_event_time(.data$period_date))

# ── CONFAZ ICMS: join nominal monthly series ──────────────────────────────────
confaz_raw <- readr::read_csv(confaz_path, show_col_types = FALSE) |>
  dplyr::mutate(period_date = as.Date(.data$period_date)) |>
  dplyr::select("state_abbrev", "period_date", icms_nominal = "va_icms_total")

monthly_raw <- monthly_raw |>
  dplyr::left_join(confaz_raw, by = c("state_abbrev", "period_date"))

# ── CAGED formal hiring balance (individual workers) ─────────────────────────
caged_raw <- readr::read_csv(caged_path, show_col_types = FALSE) |>
  dplyr::mutate(period_date = as.Date(.data$period_date)) |>
  dplyr::select("state_abbrev", "period_date", caged_balance = "formal_hiring_balance")

monthly_raw <- monthly_raw |>
  dplyr::left_join(caged_raw, by = c("state_abbrev", "period_date"))

# ── Population: annual resident population (mid-year estimate) ────────────────
pop_raw <- readr::read_csv(pop_path, show_col_types = FALSE) |>
  dplyr::select("state_abbrev", "year", "population")

monthly_raw <- monthly_raw |>
  dplyr::left_join(pop_raw, by = c("state_abbrev", "year"))

# ── Compute transformations per state ────────────────────────────────────────
monthly_panel <- monthly_raw |>
  dplyr::group_by(.data$state_abbrev) |>
  dplyr::arrange(.data$period_date, .by_group = TRUE) |>
  dplyr::mutate(
    # Primary 1: retail MA6 → log (index, no per-capita needed)
    retail_ma6       = trailing_mean_k(.data$retail, 6L),
    retail_ma6_log   = log(.data$retail_ma6),

    # Primary 2: CAGED net formal hires, 6m sum, per 1,000 residents
    # caged_balance in individual workers; population in persons
    formal_hiring_6m_per1k = trailing_sum_k(.data$caged_balance, 6L) *
                              1000 / .data$population,

    # Primary 3: ICMS CONFAZ per capita → 6m sum → log
    # icms_nominal in BRL; population in persons → BRL per person
    icms_pc          = .data$icms_nominal / .data$population,
    icms_sum6m_pc    = trailing_sum_k(.data$icms_pc, 6L),
    icms_conf6m_pc_log = dplyr::if_else(
      .data$icms_sum6m_pc > 0, log(.data$icms_sum6m_pc), NA_real_
    )
  ) |>
  dplyr::ungroup()

# ── Covariates ────────────────────────────────────────────────────────────────
covariates <- readr::read_csv(
  file.path(engine_data_dir, paste0(event_id, "_covariates.csv")),
  show_col_types = FALSE
)

# ── Event metadata to save ────────────────────────────────────────────────────
event_metadata_out <- event_meta |>
  dplyr::mutate(
    pilot_id         = pilot_id,
    event_month_date = event_month_date
  )

# ── Write outputs ─────────────────────────────────────────────────────────────
readr::write_csv(monthly_panel,      file.path(pilot_data_dir, "rr_2018_01_v6_monthly_panel.csv"),   na = "")
readr::write_csv(covariates,         file.path(pilot_data_dir, "rr_2018_01_v6_covariates.csv"),      na = "")
readr::write_csv(event_metadata_out, file.path(pilot_data_dir, "rr_2018_01_v6_event_metadata.csv"), na = "")

message("RR 2018-01 V6 panels built (k=6, CAGED per1k, ICMS per capita).")
message("  monthly rows: ", nrow(monthly_panel))

monthly_panel |>
  dplyr::filter(.data$state_abbrev == treated_state, .data$event_time >= 0) |>
  dplyr::select("period_date", "event_time", "retail_ma6_log",
                "formal_hiring_6m_per1k", "icms_conf6m_pc_log") |>
  dplyr::slice_head(n = 6) |>
  print()
