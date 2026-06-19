source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))
source(file.path("code", "03_nova_estrategia", "00_nova_estrategia_config.R"))

event_id      <- resolve_event_id()
event_spec    <- get_event_spec(event_id)
treated_state <- event_spec$treated_state[[1]]
include_formal_hiring <- event_spec$include_formal_hiring[[1]]

d <- ensure_event_dirs_v2(event_id)

engine_data_dir <- file.path(path_output, event_id, "data")
confaz_path <- file.path(path_data_processed, "confaz_state_tax_revenue_monthly_panel_ready.csv")
caged_path  <- file.path(path_data_processed, "caged_state_balance_monthly_panel_ready.csv")
pop_path    <- file.path(path_data_processed, "estimapop_resident_population_annual_panel_ready.csv")

# ── Event metadata ────────────────────────────────────────────────────────────
event_meta <- readr::read_csv(
  file.path(engine_data_dir, paste0(event_id, "_event_metadata.csv")),
  show_col_types = FALSE
) |> dplyr::slice(1)

removal_date           <- as.Date(event_meta$removal_date[[1]])
instability_start_date <- as.Date(event_meta$instability_start_date[[1]])

event_month_date <- lubridate::floor_date(removal_date, "month")

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

# ── CAGED formal hiring balance (individual workers) — only if this event
#    has enough CAGED pre-treatment coverage (per nova_estrategia_events) ────
if (include_formal_hiring) {
  caged_raw <- readr::read_csv(caged_path, show_col_types = FALSE) |>
    dplyr::mutate(period_date = as.Date(.data$period_date)) |>
    dplyr::select("state_abbrev", "period_date", caged_balance = "formal_hiring_balance")

  monthly_raw <- monthly_raw |>
    dplyr::left_join(caged_raw, by = c("state_abbrev", "period_date"))
}

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
    # Primary 1: retail MA6 -> log (index, no per-capita needed)
    retail_ma6       = trailing_mean_k(.data$retail, 6L),
    retail_ma6_log   = log(.data$retail_ma6),

    # Primary 2: ICMS CONFAZ per capita -> 6m sum -> log
    icms_pc            = .data$icms_nominal / .data$population,
    icms_sum6m_pc      = trailing_sum_k(.data$icms_pc, 6L),
    icms_conf6m_pc_log = dplyr::if_else(
      .data$icms_sum6m_pc > 0, log(.data$icms_sum6m_pc), NA_real_
    )
  )

# Primary 3 (conditional): CAGED net formal hires, 6m sum, per 1,000 residents.
# Added as a second grouped mutate so it still respects the state grouping above.
if (include_formal_hiring) {
  monthly_panel <- monthly_panel |>
    dplyr::mutate(
      formal_hiring_6m_per1k = trailing_sum_k(.data$caged_balance, 6L) * 1000 / .data$population
    )
}

monthly_panel <- monthly_panel |> dplyr::ungroup()

# ── Covariates (already built by the old engine; donor pool flags reused as-is) ─
covariates <- readr::read_csv(
  file.path(engine_data_dir, paste0(event_id, "_covariates.csv")),
  show_col_types = FALSE
)

# ── Event metadata to save ────────────────────────────────────────────────────
event_metadata_out <- event_meta |>
  dplyr::mutate(
    event_id_v2      = event_id,
    event_month_date = event_month_date
  )

# ── Write outputs ─────────────────────────────────────────────────────────────
readr::write_csv(monthly_panel,      file.path(d$data, paste0(event_id, "_monthly_panel.csv")),   na = "")
readr::write_csv(covariates,         file.path(d$data, paste0(event_id, "_covariates.csv")),      na = "")
readr::write_csv(event_metadata_out, file.path(d$data, paste0(event_id, "_event_metadata.csv")), na = "")

message(event_id, ": panels v2 built (k=6, ICMS per capita",
        if (include_formal_hiring) ", CAGED per1k)" else ", sem CAGED)")
message("  monthly rows: ", nrow(monthly_panel))

outcome_cols <- get_outcome_list(include_formal_hiring)
monthly_panel |>
  dplyr::filter(.data$state_abbrev == treated_state, .data$event_time >= 0) |>
  dplyr::select("period_date", "event_time", dplyr::all_of(outcome_cols)) |>
  dplyr::slice_head(n = 6) |>
  print()
