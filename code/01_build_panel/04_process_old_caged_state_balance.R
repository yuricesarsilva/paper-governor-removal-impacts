source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

input_path <- file.path(path_data_raw_mte, "old_caged_state_balance_monthly.csv")
uf_lookup_path <- file.path(path_data_processed, "uf_code_lookup.csv")
output_full_path <- file.path(path_data_processed, "old_caged_state_balance_monthly_processed.csv")
output_panel_ready_path <- file.path(path_data_processed, "old_caged_state_balance_monthly_panel_ready.csv")

if (!file.exists(input_path)) {
  stop("Input file not found: ", input_path)
}

if (!file.exists(uf_lookup_path)) {
  stop("UF lookup file not found: ", uf_lookup_path)
}

uf_lookup <- readr::read_csv(uf_lookup_path, show_col_types = FALSE) |>
  dplyr::mutate(
    uf = stringr::str_pad(as.character(uf), width = 2, side = "left", pad = "0")
  )

old_caged <- readr::read_csv(input_path, show_col_types = FALSE) |>
  dplyr::mutate(
    competencia = as.character(competencia),
    year = as.integer(year),
    month = as.integer(month),
    uf = stringr::str_pad(as.character(uf), width = 2, side = "left", pad = "0"),
    period_date = as.Date(paste0(competencia, "01"), format = "%Y%m%d")
  ) |>
  dplyr::left_join(uf_lookup, by = "uf") |>
  dplyr::mutate(
    uf_mapping_status = dplyr::if_else(is.na(state_abbrev), "unmapped", "mapped")
  ) |>
  dplyr::arrange(period_date, uf)

panel_ready <- old_caged |>
  dplyr::filter(include_in_panel) |>
  dplyr::select(
    competencia,
    period_date,
    year,
    month,
    uf,
    state_abbrev,
    state_name,
    macroregion,
    formal_hiring_balance,
    source_series
  )

readr::write_csv(old_caged, output_full_path, na = "")
readr::write_csv(panel_ready, output_panel_ready_path, na = "")

message("Saved processed file: ", output_full_path)
message("Saved panel-ready file: ", output_panel_ready_path)
