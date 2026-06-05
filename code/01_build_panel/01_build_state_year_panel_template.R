source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

resident_population_path <- file.path(path_data_processed, "resident_population_annual_panel_ready.csv")
uf_lookup_path <- file.path(path_data_processed, "uf_code_lookup.csv")
output_path <- file.path(path_data_processed, "state_year_panel_template.csv")

if (!file.exists(resident_population_path)) {
  stop("Resident population panel not found: ", resident_population_path)
}

if (!file.exists(uf_lookup_path)) {
  stop("UF lookup file not found: ", uf_lookup_path)
}

resident_population <- readr::read_csv(resident_population_path, show_col_types = FALSE) |>
  dplyr::mutate(
    year = as.integer(.data$year),
    population = as.numeric(.data$population)
  ) |>
  dplyr::select(
    .data$state_abbrev,
    .data$state_name,
    .data$year,
    .data$population
  )

uf_lookup <- readr::read_csv(uf_lookup_path, show_col_types = FALSE) |>
  dplyr::filter(.data$include_in_panel) |>
  dplyr::select(.data$state_abbrev, .data$state_name)

year_grid <- sort(unique(resident_population$year))

state_year_panel <- tidyr::expand_grid(
  state_abbrev = uf_lookup$state_abbrev,
  year = year_grid
) |>
  dplyr::left_join(uf_lookup, by = "state_abbrev") |>
  dplyr::left_join(
    resident_population,
    by = c("state_abbrev", "state_name", "year")
  ) |>
  dplyr::mutate(
    gdp_per_capita_real = NA_real_,
    formal_employment_stock = NA_real_,
    formal_hiring_balance = NA_real_,
    state_tax_revenue_real = NA_real_,
    total_revenue_real = NA_real_,
    investment_expenditure_real = NA_real_,
    federal_transfers_real = NA_real_,
    homicide_rate = NA_real_,
    bolsa_familia_beneficiaries = NA_real_,
    sus_primary_care_coverage = NA_real_,
    treated_case = FALSE,
    post_treatment = FALSE,
    treatment_year = NA_integer_,
    event_id = NA_character_
  ) |>
  dplyr::arrange(.data$state_abbrev, .data$year) |>
  dplyr::select(
    .data$state_abbrev,
    .data$state_name,
    .data$year,
    .data$population,
    .data$gdp_per_capita_real,
    .data$formal_employment_stock,
    .data$formal_hiring_balance,
    .data$state_tax_revenue_real,
    .data$total_revenue_real,
    .data$investment_expenditure_real,
    .data$federal_transfers_real,
    .data$homicide_rate,
    .data$bolsa_familia_beneficiaries,
    .data$sus_primary_care_coverage,
    .data$treated_case,
    .data$post_treatment,
    .data$treatment_year,
    .data$event_id
  )

expected_rows <- nrow(uf_lookup) * length(year_grid)

if (nrow(state_year_panel) != expected_rows) {
  stop("State-year panel row count mismatch. Expected ", expected_rows, " but found ", nrow(state_year_panel))
}

missing_population <- state_year_panel |>
  dplyr::filter(!is.finite(.data$population))

if (nrow(missing_population) > 0) {
  stop("State-year panel still has missing population rows.")
}

readr::write_csv(state_year_panel, output_path, na = "")

message("Saved state-year panel template: ", output_path)
message("Rows: ", nrow(state_year_panel))
