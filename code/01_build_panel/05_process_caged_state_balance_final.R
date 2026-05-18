source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

old_input_path <- file.path(path_data_raw_mte, "old_caged_complete_state_balance_monthly.csv")
novo_input_path <- file.path(path_data_raw_mte, "novo_caged_adjusted_state_balance_monthly.csv")
uf_lookup_path <- file.path(path_data_processed, "uf_code_lookup.csv")
output_full_path <- file.path(path_data_processed, "caged_state_balance_monthly_processed.csv")
output_panel_ready_path <- file.path(path_data_processed, "caged_state_balance_monthly_panel_ready.csv")

if (!file.exists(old_input_path)) {
  stop("Input file not found: ", old_input_path)
}

if (!file.exists(novo_input_path)) {
  stop("Input file not found: ", novo_input_path)
}

if (!file.exists(uf_lookup_path)) {
  stop("UF lookup file not found: ", uf_lookup_path)
}

uf_lookup <- readr::read_csv(uf_lookup_path, show_col_types = FALSE) |>
  dplyr::mutate(
    uf = stringr::str_pad(as.character(uf), width = 2, side = "left", pad = "0")
  )

old_caged <- readr::read_csv(old_input_path, show_col_types = FALSE) |>
  dplyr::mutate(
    source_regime = "old_caged",
    source_component = "complete",
    series_version = "old_complete_novo_mov_for_exc_v1"
  )

novo_caged <- readr::read_csv(novo_input_path, show_col_types = FALSE) |>
  dplyr::mutate(
    source_regime = "novo_caged",
    source_component = "mov_for_exc",
    series_version = "old_complete_novo_mov_for_exc_v1"
  )

caged <- dplyr::bind_rows(old_caged, novo_caged) |>
  dplyr::mutate(
    competencia = as.character(competencia),
    year = as.integer(year),
    month = as.integer(month),
    uf = stringr::str_pad(as.character(uf), width = 2, side = "left", pad = "0"),
    period_date = as.Date(paste0(competencia, "01"), format = "%Y%m%d"),
    post_2020_caged_dummy = as.integer(period_date >= as.Date("2020-01-01")),
    caged_method_break_dummy = post_2020_caged_dummy
  ) |>
  dplyr::left_join(uf_lookup, by = "uf") |>
  dplyr::mutate(
    uf_mapping_status = dplyr::if_else(is.na(state_abbrev), "unmapped", "mapped")
  ) |>
  dplyr::arrange(period_date, uf)

panel_ready <- caged |>
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
    source_regime,
    source_component,
    post_2020_caged_dummy,
    caged_method_break_dummy,
    series_version
  )

readr::write_csv(caged, output_full_path, na = "")
readr::write_csv(panel_ready, output_panel_ready_path, na = "")

message("Saved processed file: ", output_full_path)
message("Saved panel-ready file: ", output_panel_ready_path)
