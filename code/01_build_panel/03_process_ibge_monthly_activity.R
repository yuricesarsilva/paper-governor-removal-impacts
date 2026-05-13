source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

pmc_input_path <- file.path(path_data_raw_ibge, "pmc_retail_index_monthly.csv")
pms_input_path <- file.path(path_data_raw_ibge, "pms_services_index_monthly.csv")
uf_lookup_path <- file.path(path_data_processed, "uf_code_lookup.csv")

if (!file.exists(pmc_input_path)) {
  stop("PMC input file not found: ", pmc_input_path)
}

if (!file.exists(pms_input_path)) {
  stop("PMS input file not found: ", pms_input_path)
}

if (!file.exists(uf_lookup_path)) {
  stop("UF lookup file not found: ", uf_lookup_path)
}

uf_lookup <- readr::read_csv(uf_lookup_path, show_col_types = FALSE) |>
  dplyr::mutate(
    uf = stringr::str_pad(as.character(uf), width = 2, side = "left", pad = "0")
  ) |>
  dplyr::filter(include_in_panel)

prepare_ibge_monthly_index <- function(
  data,
  nominal_code,
  volume_code,
  output_stub,
  nominal_output_name,
  volume_output_name
) {
  data_wide <- data |>
    dplyr::mutate(
      uf = stringr::str_pad(as.character(unidade_da_federacao_codigo), width = 2, side = "left", pad = "0"),
      competencia = as.character(mes_codigo),
      year = as.integer(substr(competencia, 1, 4)),
      month = as.integer(substr(competencia, 5, 6)),
      period_date = as.Date(paste0(competencia, "01"), format = "%Y%m%d"),
      series_name = dplyr::case_when(
        tipos_de_indice_codigo == nominal_code ~ "nominal_revenue_index",
        tipos_de_indice_codigo == volume_code ~ "volume_index",
        TRUE ~ "other"
      )
    ) |>
    dplyr::filter(series_name != "other") |>
    dplyr::select(
      competencia,
      period_date,
      year,
      month,
      uf,
      unidade_da_federacao,
      series_name,
      valor
    ) |>
    tidyr::pivot_wider(
      names_from = series_name,
      values_from = valor
    ) |>
    dplyr::rename(
      !!nominal_output_name := nominal_revenue_index,
      !!volume_output_name := volume_index
    ) |>
    dplyr::left_join(uf_lookup, by = "uf") |>
    dplyr::mutate(
      uf_mapping_status = dplyr::if_else(is.na(state_abbrev), "unmapped", "mapped")
    ) |>
    dplyr::arrange(period_date, uf)

  processed_path <- file.path(path_data_processed, paste0(output_stub, "_processed.csv"))
  panel_ready_path <- file.path(path_data_processed, paste0(output_stub, "_panel_ready.csv"))

  readr::write_csv(data_wide, processed_path, na = "")
  readr::write_csv(data_wide, panel_ready_path, na = "")

  message("Saved processed file: ", processed_path)
  message("Saved panel-ready file: ", panel_ready_path)
}

pmc_raw <- readr::read_csv(pmc_input_path, show_col_types = FALSE)
pms_raw <- readr::read_csv(pms_input_path, show_col_types = FALSE)

prepare_ibge_monthly_index(
  data = pmc_raw,
  nominal_code = 56733,
  volume_code = 56734,
  output_stub = "pmc_retail_monthly",
  nominal_output_name = "retail_nominal_revenue_index",
  volume_output_name = "retail_volume_index"
)

prepare_ibge_monthly_index(
  data = pms_raw,
  nominal_code = 56725,
  volume_code = 56726,
  output_stub = "pms_services_monthly",
  nominal_output_name = "services_nominal_revenue_index",
  volume_output_name = "services_volume_index"
)
