source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

input_path <- file.path(path_data_raw_mte, "novo_caged_state_balance_monthly.csv")
output_lookup_path <- file.path(path_data_processed, "uf_code_lookup.csv")
output_full_path <- file.path(path_data_processed, "novo_caged_state_balance_monthly_processed.csv")
output_panel_ready_path <- file.path(path_data_processed, "novo_caged_state_balance_monthly_panel_ready.csv")

if (!file.exists(input_path)) {
  stop("Input file not found: ", input_path)
}

uf_lookup <- tibble::tribble(
  ~uf, ~state_abbrev, ~state_name, ~macroregion, ~is_identified_uf, ~include_in_panel,
  "11", "RO", "Rondonia", "North", TRUE, TRUE,
  "12", "AC", "Acre", "North", TRUE, TRUE,
  "13", "AM", "Amazonas", "North", TRUE, TRUE,
  "14", "RR", "Roraima", "North", TRUE, TRUE,
  "15", "PA", "Para", "North", TRUE, TRUE,
  "16", "AP", "Amapa", "North", TRUE, TRUE,
  "17", "TO", "Tocantins", "North", TRUE, TRUE,
  "21", "MA", "Maranhao", "Northeast", TRUE, TRUE,
  "22", "PI", "Piaui", "Northeast", TRUE, TRUE,
  "23", "CE", "Ceara", "Northeast", TRUE, TRUE,
  "24", "RN", "Rio Grande do Norte", "Northeast", TRUE, TRUE,
  "25", "PB", "Paraiba", "Northeast", TRUE, TRUE,
  "26", "PE", "Pernambuco", "Northeast", TRUE, TRUE,
  "27", "AL", "Alagoas", "Northeast", TRUE, TRUE,
  "28", "SE", "Sergipe", "Northeast", TRUE, TRUE,
  "29", "BA", "Bahia", "Northeast", TRUE, TRUE,
  "31", "MG", "Minas Gerais", "Southeast", TRUE, TRUE,
  "32", "ES", "Espirito Santo", "Southeast", TRUE, TRUE,
  "33", "RJ", "Rio de Janeiro", "Southeast", TRUE, TRUE,
  "35", "SP", "Sao Paulo", "Southeast", TRUE, TRUE,
  "41", "PR", "Parana", "South", TRUE, TRUE,
  "42", "SC", "Santa Catarina", "South", TRUE, TRUE,
  "43", "RS", "Rio Grande do Sul", "South", TRUE, TRUE,
  "50", "MS", "Mato Grosso do Sul", "Center-West", TRUE, TRUE,
  "51", "MT", "Mato Grosso", "Center-West", TRUE, TRUE,
  "52", "GO", "Goias", "Center-West", TRUE, TRUE,
  "53", "DF", "Distrito Federal", "Center-West", TRUE, TRUE,
  "99", "NI", "Nao identificado", "Not identified", FALSE, FALSE
)

novo_caged <- readr::read_csv(input_path, show_col_types = FALSE) |>
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

panel_ready <- novo_caged |>
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

readr::write_csv(uf_lookup, output_lookup_path, na = "")
readr::write_csv(novo_caged, output_full_path, na = "")
readr::write_csv(panel_ready, output_panel_ready_path, na = "")

message("Saved lookup: ", output_lookup_path)
message("Saved processed file: ", output_full_path)
message("Saved panel-ready file: ", output_panel_ready_path)
