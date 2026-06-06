source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

siconfi_path <- file.path(
  path_data_processed,
  "siconfi_rreo_state_fiscal_bimonthly_panel_ready.csv"
)
registry_path <- file.path(
  path_data_raw,
  "siconfi",
  "siconfi_rreo_state_fiscal_bimonthly_download_registry.csv"
)

if (!file.exists(siconfi_path)) {
  stop("Input file not found: ", siconfi_path)
}

if (!file.exists(registry_path)) {
  stop("Registry file not found: ", registry_path)
}

validation_dir <- path_output_validation
if (!dir.exists(validation_dir)) {
  dir.create(validation_dir, recursive = TRUE)
}

siconfi <- readr::read_csv(siconfi_path, show_col_types = FALSE) |>
  dplyr::mutate(
    period = as.character(period),
    period_date = as.Date(period_date),
    state_abbrev = as.character(state_abbrev),
    public_investment_flow_is_derived = as.logical(public_investment_flow_is_derived),
    public_investment_negative_flow_flag = as.logical(public_investment_negative_flow_flag)
  )

registry <- readr::read_csv(
  registry_path,
  col_types = readr::cols(.default = readr::col_character())
)

required_columns <- c(
  "period",
  "period_date",
  "year",
  "bimester",
  "uf",
  "state_abbrev",
  "state_name",
  "macroregion",
  "total_revenue_nominal",
  "total_revenue_real",
  "state_tax_revenue_nominal",
  "state_tax_revenue_real",
  "federal_current_transfers_nominal",
  "federal_capital_transfers_nominal",
  "federal_transfers_nominal",
  "federal_transfers_real",
  "transfer_dependency_ratio",
  "own_revenue_ratio",
  "liquidated_expenditure_total_nominal",
  "liquidated_expenditure_total_real",
  "liquidated_expenditure_health_nominal",
  "liquidated_expenditure_health_real",
  "liquidated_expenditure_education_nominal",
  "liquidated_expenditure_education_real",
  "liquidated_expenditure_public_security_nominal",
  "liquidated_expenditure_public_security_real",
  "public_investment_liquidated_cumulative_nominal",
  "public_investment_liquidated_nominal",
  "public_investment_liquidated_real",
  "public_investment_flow_is_derived",
  "public_investment_negative_flow_flag",
  "ipca_month_code",
  "deflator_base_month",
  "source_system",
  "source_frequency",
  "fiscal_series_version"
)

missing_columns <- setdiff(required_columns, names(siconfi))
if (length(missing_columns) > 0) {
  stop("Missing columns in final Siconfi panel-ready file: ", paste(missing_columns, collapse = ", "))
}

duplicate_keys <- siconfi |>
  dplyr::count(year, bimester, state_abbrev, name = "n") |>
  dplyr::filter(n > 1)

if (nrow(duplicate_keys) > 0) {
  stop("Duplicated year x bimester x state_abbrev rows found in final Siconfi panel-ready file")
}

period_coverage <- siconfi |>
  dplyr::group_by(year, bimester, period, period_date) |>
  dplyr::summarise(
    n_states = dplyr::n_distinct(state_abbrev),
    rows = dplyr::n(),
    .groups = "drop"
  ) |>
  dplyr::arrange(year, bimester)

incomplete_periods <- period_coverage |>
  dplyr::filter(n_states < 27 | rows < 27)

missing_value_summary <- tibble::tibble(
  variable = c(
    "total_revenue_real",
    "state_tax_revenue_real",
    "federal_transfers_real",
    "liquidated_expenditure_total_real",
    "liquidated_expenditure_health_real",
    "liquidated_expenditure_education_real",
    "liquidated_expenditure_public_security_real",
    "public_investment_liquidated_real",
    "transfer_dependency_ratio",
    "own_revenue_ratio"
  )
) |>
  dplyr::mutate(
    missing_rows = purrr::map_int(variable, ~sum(is.na(siconfi[[.x]]))),
    non_missing_rows = nrow(siconfi) - missing_rows,
    missing_share = missing_rows / nrow(siconfi)
  )

missing_investment_by_year <- siconfi |>
  dplyr::filter(is.na(public_investment_liquidated_real)) |>
  dplyr::count(year, name = "missing_investment_rows") |>
  dplyr::arrange(year)

negative_investment_flows <- siconfi |>
  dplyr::filter(public_investment_negative_flow_flag %in% TRUE) |>
  dplyr::select(
    period,
    period_date,
    state_abbrev,
    state_name,
    public_investment_liquidated_cumulative_nominal,
    public_investment_liquidated_nominal,
    public_investment_liquidated_real
  ) |>
  dplyr::arrange(period, state_abbrev)

registry_status <- registry |>
  dplyr::count(status, name = "requests")

failed_registry <- registry |>
  dplyr::filter(status != "downloaded") |>
  dplyr::arrange(year, bimester, uf, annex_name)

validation_summary <- tibble::tibble(
  metric = c(
    "panel_ready_rows",
    "periods",
    "first_period",
    "last_period",
    "min_states_per_period",
    "max_states_per_period",
    "duplicate_keys",
    "incomplete_periods",
    "registry_requests",
    "registry_failed_requests",
    "missing_total_revenue_rows",
    "missing_total_expenditure_rows",
    "missing_investment_rows",
    "negative_investment_flow_flags"
  ),
  value = as.character(c(
    nrow(siconfi),
    dplyr::n_distinct(siconfi$period),
    min(siconfi$period),
    max(siconfi$period),
    min(period_coverage$n_states),
    max(period_coverage$n_states),
    nrow(duplicate_keys),
    nrow(incomplete_periods),
    nrow(registry),
    nrow(failed_registry),
    sum(is.na(siconfi$total_revenue_real)),
    sum(is.na(siconfi$liquidated_expenditure_total_real)),
    sum(is.na(siconfi$public_investment_liquidated_real)),
    nrow(negative_investment_flows)
  ))
)

readr::write_csv(
  validation_summary,
  file.path(validation_dir, "siconfi_rreo_validation_summary.csv"),
  na = ""
)

readr::write_csv(
  period_coverage,
  file.path(validation_dir, "siconfi_rreo_period_coverage.csv"),
  na = ""
)

readr::write_csv(
  incomplete_periods,
  file.path(validation_dir, "siconfi_rreo_incomplete_periods.csv"),
  na = ""
)

readr::write_csv(
  missing_value_summary,
  file.path(validation_dir, "siconfi_rreo_missing_value_summary.csv"),
  na = ""
)

readr::write_csv(
  missing_investment_by_year,
  file.path(validation_dir, "siconfi_rreo_missing_investment_by_year.csv"),
  na = ""
)

readr::write_csv(
  negative_investment_flows,
  file.path(validation_dir, "siconfi_rreo_negative_investment_flows.csv"),
  na = ""
)

readr::write_csv(
  registry_status,
  file.path(validation_dir, "siconfi_rreo_registry_status.csv"),
  na = ""
)

readr::write_csv(
  failed_registry,
  file.path(validation_dir, "siconfi_rreo_failed_registry.csv"),
  na = ""
)

message("Final Siconfi/RREO validation completed.")
message("Saved validation outputs to: ", validation_dir)
