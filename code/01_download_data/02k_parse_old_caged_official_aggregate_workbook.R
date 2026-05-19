source(file.path("code", "01_download_data", "00_download_config.R"))

if (!requireNamespace("readxl", quietly = TRUE)) {
  stop(
    "Package readxl is required for this script. ",
    "Install it with install.packages('readxl') and rerun."
  )
}

if (!requireNamespace("tidyr", quietly = TRUE)) {
  stop(
    "Package tidyr is required for this script. ",
    "Install it with install.packages('tidyr') and rerun."
  )
}

input_path <- file.path(path_data_raw_mte, "saldomunicipioajustado_dez2019.xls")
uf_lookup_path <- file.path(path_data_processed, "uf_code_lookup.csv")

if (!file.exists(input_path)) {
  stop("Input workbook not found: ", input_path)
}

uf_lookup <- readr::read_csv(uf_lookup_path, show_col_types = FALSE) |>
  dplyr::mutate(
    uf = stringr::str_pad(as.character(uf), width = 2, side = "left", pad = "0"),
    state_abbrev_lower = tolower(state_abbrev)
  ) |>
  dplyr::select(uf, state_abbrev, state_abbrev_lower)

parse_number_br <- function(x) {
  x <- as.character(x)
  x <- stringr::str_replace_all(x, "\\.", "")
  x <- stringr::str_replace_all(x, ",", ".")
  suppressWarnings(as.numeric(x))
}

extract_state_abbrev <- function(municipality) {
  municipality |>
    as.character() |>
    stringr::str_extract("^[A-Za-z]{2}(?=-)") |>
    tolower()
}

normalize_text <- function(x) {
  x |>
    iconv(from = "", to = "ASCII//TRANSLIT") |>
    tolower()
}

parse_annual_sheet <- function() {
  workbook_sheets <- readxl::excel_sheets(input_path)
  annual_sheet <- workbook_sheets[
    normalize_text(workbook_sheets) == "serie 2002 a 2019"
  ][1]

  if (is.na(annual_sheet)) {
    stop("Could not find the annual sheet named 'serie 2002 A 2019'.")
  }

  raw_data <- readxl::read_excel(
    path = input_path,
    sheet = annual_sheet,
    col_names = FALSE,
    .name_repair = "minimal"
  )
  names(raw_data) <- paste0("col_", seq_along(raw_data))

  header <- as.character(unlist(raw_data[2, ]))
  year_columns <- which(grepl("^20[0-9]{2}", header))
  year_column_names <- names(raw_data)[year_columns]

  raw_data |>
    dplyr::slice(-(1:2)) |>
    dplyr::select(municipio_raw = 1, dplyr::all_of(year_column_names)) |>
    stats::setNames(c("municipio_raw", header[year_columns])) |>
    tidyr::pivot_longer(
      cols = -municipio_raw,
      names_to = "year_label",
      values_to = "formal_hiring_balance"
    ) |>
    dplyr::mutate(
      year = as.integer(stringr::str_extract(year_label, "^20[0-9]{2}")),
      uf_abbrev_lower = extract_state_abbrev(municipio_raw),
      formal_hiring_balance = parse_number_br(formal_hiring_balance)
    ) |>
    dplyr::filter(!is.na(year), !is.na(uf_abbrev_lower), !is.na(formal_hiring_balance)) |>
    dplyr::left_join(uf_lookup, by = c("uf_abbrev_lower" = "state_abbrev_lower")) |>
    dplyr::group_by(year, uf, state_abbrev) |>
    dplyr::summarise(
      formal_hiring_balance = sum(formal_hiring_balance, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(source_series = "old_caged_official_adjusted_workbook_annual") |>
    dplyr::arrange(year, uf)
}

month_lookup <- tibble::tribble(
  ~month_label, ~month,
  "jan", 1L,
  "fev", 2L,
  "mar", 3L,
  "abr", 4L,
  "mai", 5L,
  "maio", 5L,
  "jun", 6L,
  "jul", 7L,
  "ago", 8L,
  "set", 9L,
  "out", 10L,
  "nov", 11L,
  "dez", 12L
)

parse_sheet_period <- function(sheet_name) {
  normalized_name <- normalize_text(sheet_name)

  year <- as.integer(stringr::str_extract(normalized_name, "20[0-9]{2}$"))
  if (is.na(year)) {
    return(NULL)
  }

  month_label <- stringr::str_match(normalized_name, "a ([[:alpha:]]+) 20[0-9]{2}$")[, 2]
  if (is.na(month_label)) {
    month_label <- stringr::str_match(normalized_name, "^([[:alpha:]]+) 20[0-9]{2}$")[, 2]
  }

  month <- month_lookup$month[match(month_label, month_lookup$month_label)]

  if (is.na(month)) {
    return(NULL)
  }

  tibble::tibble(sheet_name = sheet_name, year = year, month = month)
}

parse_cumulative_month_sheet <- function(sheet_name, year, month) {
  raw_data <- readxl::read_excel(
    path = input_path,
    sheet = sheet_name,
    col_names = FALSE,
    .name_repair = "minimal"
  )
  names(raw_data) <- paste0("col_", seq_along(raw_data))

  first_column <- normalize_text(as.character(raw_data[[1]]))
  header_row <- which(first_column == "municipio")[1]

  if (is.na(header_row)) {
    stop("Could not find municipality header in sheet: ", sheet_name)
  }

  header <- normalize_text(as.character(unlist(raw_data[header_row, ])))
  total_column <- which(header == "total")[1]

  if (is.na(total_column)) {
    stop("Could not find Total column in sheet: ", sheet_name)
  }

  municipality_column_name <- names(raw_data)[1]
  total_column_name <- names(raw_data)[total_column]

  raw_data |>
    dplyr::slice((header_row + 1):dplyr::n()) |>
    dplyr::transmute(
      municipio_raw = .data[[municipality_column_name]],
      cumulative_balance = parse_number_br(.data[[total_column_name]])
    ) |>
    dplyr::mutate(
      year = year,
      month = month,
      uf_abbrev_lower = extract_state_abbrev(municipio_raw)
    ) |>
    dplyr::filter(!is.na(uf_abbrev_lower), !is.na(cumulative_balance)) |>
    dplyr::left_join(uf_lookup, by = c("uf_abbrev_lower" = "state_abbrev_lower")) |>
    dplyr::group_by(year, month, uf, state_abbrev) |>
    dplyr::summarise(
      cumulative_balance = sum(cumulative_balance, na.rm = TRUE),
      .groups = "drop"
    )
}

sheet_periods <- readxl::excel_sheets(input_path) |>
  purrr::map(parse_sheet_period) |>
  purrr::compact() |>
  dplyr::bind_rows() |>
  dplyr::filter(year >= 2017, year <= 2019)

annual_state_balance <- parse_annual_sheet()

cumulative_monthly_state_balance <- purrr::pmap_dfr(
  sheet_periods,
  parse_cumulative_month_sheet
) |>
  dplyr::arrange(uf, year, month)

monthly_state_balance <- cumulative_monthly_state_balance |>
  dplyr::group_by(uf, year) |>
  dplyr::arrange(month, .by_group = TRUE) |>
  dplyr::mutate(
    formal_hiring_balance = cumulative_balance - dplyr::lag(cumulative_balance, default = 0)
  ) |>
  dplyr::ungroup() |>
  dplyr::mutate(
    competencia = sprintf("%04d%02d", year, month),
    source_series = "old_caged_official_adjusted_workbook_monthly_from_cumulative"
  ) |>
  dplyr::select(
    competencia,
    year,
    month,
    uf,
    state_abbrev,
    formal_hiring_balance,
    cumulative_balance,
    source_series
  ) |>
  dplyr::arrange(competencia, uf)

annual_output_path <- file.path(
  path_data_raw_mte,
  "old_caged_official_adjusted_state_balance_annual.csv"
)

monthly_output_path <- file.path(
  path_data_raw_mte,
  "old_caged_official_adjusted_state_balance_monthly_2017_2019.csv"
)

readr::write_csv(annual_state_balance, annual_output_path, na = "")
readr::write_csv(monthly_state_balance, monthly_output_path, na = "")

message("Saved official annual aggregate file: ", annual_output_path)
message("Saved official monthly aggregate file: ", monthly_output_path)
