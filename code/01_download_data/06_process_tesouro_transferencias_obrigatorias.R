source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

input_path <- file.path(
  path_data_raw_tesouro,
  "transferencias_obrigatorias_uniao_dados_consolidados.xlsx"
)

if (!file.exists(input_path)) {
  stop("Tesouro workbook not found: ", input_path)
}

uf_lookup_path <- file.path(path_data_processed, "uf_code_lookup.csv")
if (!file.exists(uf_lookup_path)) {
  stop("UF lookup file not found: ", uf_lookup_path)
}

dir.create(path_data_raw_tesouro, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(path_output, "validation"), recursive = TRUE, showWarnings = FALSE)

uf_lookup <- readr::read_csv(uf_lookup_path, show_col_types = FALSE) |>
  dplyr::filter(include_in_panel) |>
  dplyr::select(uf, state_abbrev, state_name, macroregion)

sheets <- readxl::excel_sheets(input_path)

sheet_scope <- function(sheet_name) {
  dplyr::case_when(
    stringr::str_detect(sheet_name, "_EST$") ~ "states_direct",
    stringr::str_detect(sheet_name, "_MUN$") ~ "municipal_aggregate_to_state",
    sheet_name %in% c("FPE", "TCP") ~ "states_direct",
    sheet_name %in% c("FPM", "FPM_CAPITAIS", "ITR") ~ "municipal_aggregate_to_state",
    TRUE ~ "other"
  )
}

sheet_variable_name <- function(sheet_name) {
  name <- tolower(sheet_name)
  name <- stringr::str_replace_all(name, "-", "_")
  name <- stringr::str_replace_all(name, "[^a-z0-9_]", "_")
  janitor::make_clean_names(name, ascii = TRUE)
}

parse_transfer_sheet <- function(sheet_name) {
  raw <- readxl::read_excel(
    input_path,
    sheet = sheet_name,
    col_names = FALSE,
    skip = 7
  )

  if (nrow(raw) < 3) {
    stop("Sheet has too few rows to parse: ", sheet_name)
  }

  header_row <- raw[1, , drop = FALSE]
  data_rows <- raw[-c(1, 2), , drop = FALSE]

  date_serials <- suppressWarnings(as.numeric(header_row[1, -c(1, 2)]))
  valid_date_positions <- which(!is.na(date_serials))

  if (length(valid_date_positions) == 0) {
    stop("No valid monthly date columns found in sheet: ", sheet_name)
  }

  state_name_col <- as.character(data_rows[[1]])
  state_abbrev_col <- as.character(data_rows[[2]])
  first_col_name <- names(data_rows)[1]
  second_col_name <- names(data_rows)[2]

  parsed <- data_rows |>
    tibble::as_tibble() |>
    dplyr::mutate(
      state_name_raw = stringr::str_squish(as.character(.data[[first_col_name]])),
      state_abbrev = stringr::str_squish(as.character(.data[[second_col_name]]))
    ) |>
    dplyr::filter(state_abbrev %in% uf_lookup$state_abbrev) |>
    dplyr::select(state_name_raw, state_abbrev, dplyr::all_of(names(data_rows)[valid_date_positions + 2]))

  names(parsed)[-(1:2)] <- paste0("m_", seq_along(valid_date_positions))
  month_value_cols <- names(parsed)[-(1:2)]

  parsed <- parsed |>
    dplyr::mutate(
      dplyr::across(
        dplyr::all_of(month_value_cols),
        ~ suppressWarnings(as.numeric(as.character(.x)))
      )
    )

  month_lookup <- tibble::tibble(
    column_name = month_value_cols,
    period_date = as.Date(date_serials[valid_date_positions], origin = "1899-12-30"),
    competencia = format(period_date, "%Y%m"),
    year = as.integer(format(period_date, "%Y")),
    month = as.integer(format(period_date, "%m"))
  )

  parsed |>
    tidyr::pivot_longer(
      cols = -c(state_name_raw, state_abbrev),
      names_to = "column_name",
      values_to = "transfer_value_nominal"
    ) |>
    dplyr::mutate(
      transfer_value_nominal = suppressWarnings(as.numeric(as.character(transfer_value_nominal))),
      transfer_sheet = sheet_name,
      transfer_scope = sheet_scope(sheet_name),
      transfer_variable = sheet_variable_name(sheet_name)
    ) |>
    dplyr::left_join(month_lookup, by = "column_name") |>
    dplyr::left_join(uf_lookup, by = "state_abbrev") |>
    dplyr::select(
      transfer_sheet,
      transfer_scope,
      transfer_variable,
      competencia,
      period_date,
      year,
      month,
      state_abbrev,
      state_name,
      macroregion,
      state_name_raw,
      transfer_value_nominal
    ) |>
    dplyr::arrange(period_date, state_abbrev)
}

transfers_long <- purrr::map_dfr(sheets, parse_transfer_sheet)

processed_long_path <- file.path(
  path_data_processed,
  "tesouro_transferencias_obrigatorias_long_processed.csv"
)

panel_ready_path <- file.path(
  path_data_processed,
  "tesouro_transferencias_obrigatorias_state_month_panel_ready.csv"
)

registry_path <- file.path(
  path_data_raw_tesouro,
  "tesouro_transferencias_obrigatorias_import_registry.csv"
)

coverage_path <- file.path(
  path_output,
  "validation",
  "tesouro_transferencias_obrigatorias_sheet_coverage.csv"
)

missing_summary_path <- file.path(
  path_output,
  "validation",
  "tesouro_transferencias_obrigatorias_missing_summary.csv"
)

wide_panel <- transfers_long |>
  dplyr::select(
    competencia,
    period_date,
    year,
    month,
    state_abbrev,
    state_name,
    macroregion,
    transfer_variable,
    transfer_value_nominal
  ) |>
  tidyr::pivot_wider(
    names_from = transfer_variable,
    values_from = transfer_value_nominal
  ) |>
  dplyr::arrange(period_date, state_abbrev)

sheet_coverage <- transfers_long |>
  dplyr::group_by(transfer_sheet, transfer_variable, transfer_scope) |>
  dplyr::summarise(
    first_period = min(competencia, na.rm = TRUE),
    last_period = max(competencia, na.rm = TRUE),
    n_periods = dplyr::n_distinct(competencia),
    n_states = dplyr::n_distinct(state_abbrev),
    non_missing_rows = sum(!is.na(transfer_value_nominal)),
    missing_rows = sum(is.na(transfer_value_nominal)),
    .groups = "drop"
  ) |>
  dplyr::arrange(transfer_sheet)

missing_summary <- transfers_long |>
  dplyr::group_by(transfer_sheet, competencia, period_date) |>
  dplyr::summarise(
    n_states = dplyr::n_distinct(state_abbrev),
    missing_rows = sum(is.na(transfer_value_nominal)),
    .groups = "drop"
  ) |>
  dplyr::arrange(transfer_sheet, period_date)

registry <- sheet_coverage |>
  dplyr::mutate(
    source_file = basename(input_path),
    imported_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  ) |>
  dplyr::select(
    source_file,
    imported_at,
    transfer_sheet,
    transfer_variable,
    transfer_scope,
    first_period,
    last_period,
    n_periods,
    n_states,
    non_missing_rows,
    missing_rows
  )

readr::write_csv(transfers_long, processed_long_path, na = "")
readr::write_csv(wide_panel, panel_ready_path, na = "")
readr::write_csv(registry, registry_path, na = "")
readr::write_csv(sheet_coverage, coverage_path, na = "")
readr::write_csv(missing_summary, missing_summary_path, na = "")

message("Saved long processed file: ", processed_long_path)
message("Saved wide panel-ready file: ", panel_ready_path)
message("Saved import registry: ", registry_path)
