source(file.path("code", "01_download_data", "00_download_config.R"))

pnadc_sidra_tables <- list(
  population_14_plus = list(
    table_id = 6463,
    variable_code = 1641,
    condition_code = 32385,
    series_name = "pnadc_population",
    description = "Pessoas de 14 anos ou mais de idade - Total",
    api = "/t/6463/n3/all/v/1641/p/all/c629/32385",
    raw_output_path = file.path(path_data_raw_ibge, "pnadc_sidra_population_14_plus_quarterly.csv")
  ),
  unemployment_rate = list(
    table_id = 6468,
    variable_code = 4099,
    series_name = "unemployment_rate_pnadc",
    description = "Taxa de desocupacao das pessoas de 14 anos ou mais",
    api = "/t/6468/n3/all/v/4099/p/all",
    raw_output_path = file.path(path_data_raw_ibge, "pnadc_sidra_unemployment_rate_quarterly.csv")
  ),
  labor_income_real = list(
    table_id = 6469,
    variable_code = 5935,
    series_name = "labor_income_real_pnadc",
    description = "Rendimento medio mensal real efetivamente recebido em todos os trabalhos",
    api = "/t/6469/n3/all/v/5935/p/all",
    raw_output_path = file.path(path_data_raw_ibge, "pnadc_sidra_labor_income_real_quarterly.csv")
  ),
  informality_rate = list(
    table_id = 8529,
    variable_code = 12466,
    series_name = "informality_rate_pnadc",
    description = "Taxa de informalidade das pessoas ocupadas de 14 anos ou mais",
    api = "/t/8529/n3/all/v/12466/p/all",
    raw_output_path = file.path(path_data_raw_ibge, "pnadc_sidra_informality_rate_quarterly.csv")
  )
)

clean_sidra_result <- function(data) {
  data |>
    janitor::clean_names() |>
    dplyr::mutate(downloaded_at = Sys.Date())
}

parse_sidra_value <- function(x) {
  readr::parse_number(
    as.character(x),
    locale = readr::locale(decimal_mark = ".", grouping_mark = ","),
    na = c("", "...", "-", "NA")
  )
}

list_item_or_na <- function(x, name) {
  if (name %in% names(x)) {
    x[[name]]
  } else {
    NA_integer_
  }
}

get_required_col <- function(data, candidates) {
  present <- candidates[candidates %in% names(data)]

  if (length(present) == 0) {
    stop(
      "Could not find required SIDRA column. Candidates: ",
      paste(candidates, collapse = ", ")
    )
  }

  present[[1]]
}

download_pnadc_sidra_table <- function(table_config) {
  message(
    "Downloading PNADc SIDRA table ",
    table_config$table_id,
    " variable ",
    table_config$variable_code
  )

  raw_data <- sidrar::get_sidra(api = table_config$api)
  clean_data <- clean_sidra_result(raw_data)

  write_raw_csv(clean_data, table_config$raw_output_path)

  clean_data
}

standardize_sidra_quarterly <- function(data, table_config, output_name, transform = identity) {
  uf_col <- get_required_col(data, "unidade_da_federacao_codigo")
  state_name_col <- get_required_col(data, "unidade_da_federacao")
  quarter_col <- get_required_col(data, "trimestre_codigo")
  value_col <- get_required_col(data, "valor")
  unit_col <- get_required_col(data, "unidade_de_medida")
  variable_code_col <- get_required_col(data, "variavel_codigo")
  variable_col <- get_required_col(data, "variavel")

  data |>
    dplyr::transmute(
      uf = as.integer(.data[[uf_col]]),
      state_name_sidra = as.character(.data[[state_name_col]]),
      sidra_period_code = as.integer(.data[[quarter_col]]),
      year = sidra_period_code %/% 100,
      quarter = sidra_period_code %% 100,
      period = paste0(year, "Q", quarter),
      sidra_period_label = paste0(quarter, " trimestre ", year),
      period_date = as.Date(sprintf("%d-%02d-01", year, (quarter - 1L) * 3L + 1L)),
      "{output_name}" := transform(parse_sidra_value(.data[[value_col]])),
      sidra_unit = as.character(.data[[unit_col]]),
      sidra_table_id = table_config$table_id,
      sidra_variable_code = as.integer(.data[[variable_code_col]]),
      sidra_variable_label = as.character(.data[[variable_col]])
    )
}

raw_downloads <- purrr::imap(
  pnadc_sidra_tables,
  ~download_pnadc_sidra_table(.x)
)

population <- standardize_sidra_quarterly(
  raw_downloads$population_14_plus,
  pnadc_sidra_tables$population_14_plus,
  "pnadc_population",
  transform = function(x) x * 1000
) |>
  dplyr::mutate(pnadc_population_original_unit = "Mil pessoas")

unemployment <- standardize_sidra_quarterly(
  raw_downloads$unemployment_rate,
  pnadc_sidra_tables$unemployment_rate,
  "unemployment_rate_pnadc",
  transform = function(x) x / 100
)

income <- standardize_sidra_quarterly(
  raw_downloads$labor_income_real,
  pnadc_sidra_tables$labor_income_real,
  "labor_income_real_pnadc"
)

informality <- standardize_sidra_quarterly(
  raw_downloads$informality_rate,
  pnadc_sidra_tables$informality_rate,
  "informality_rate_pnadc",
  transform = function(x) x / 100
) |>
  dplyr::mutate(
    formalization_rate_pnadc = dplyr::if_else(
      is.na(informality_rate_pnadc),
      NA_real_,
      1 - informality_rate_pnadc
    )
  )

uf_lookup_path <- file.path(path_data_processed, "uf_code_lookup.csv")

if (!file.exists(uf_lookup_path)) {
  stop("UF lookup file not found: ", uf_lookup_path)
}

uf_lookup <- readr::read_csv(uf_lookup_path, show_col_types = FALSE) |>
  dplyr::filter(include_in_panel) |>
  dplyr::select(uf, state_abbrev, state_name, macroregion)

pnadc_processed <- population |>
  dplyr::select(
    uf,
    sidra_period_code,
    sidra_period_label,
    year,
    quarter,
    period,
    period_date,
    pnadc_population,
    pnadc_population_original_unit
  ) |>
  dplyr::full_join(
    unemployment |>
      dplyr::select(uf, sidra_period_code, unemployment_rate_pnadc),
    by = c("uf", "sidra_period_code")
  ) |>
  dplyr::full_join(
    income |>
      dplyr::select(uf, sidra_period_code, labor_income_real_pnadc),
    by = c("uf", "sidra_period_code")
  ) |>
  dplyr::full_join(
    informality |>
      dplyr::select(
        uf,
        sidra_period_code,
        informality_rate_pnadc,
        formalization_rate_pnadc
      ),
    by = c("uf", "sidra_period_code")
  ) |>
  dplyr::left_join(uf_lookup, by = "uf") |>
  dplyr::mutate(
    source_system = "SIDRA/PNADCT",
    income_variable_used = "SIDRA table 6469 variable 5935",
    population_concept = "Pessoas de 14 anos ou mais de idade",
    formalization_rule = "1 - SIDRA table 8529 variable 12466 / 100"
  ) |>
  dplyr::select(
    period,
    period_date,
    year,
    quarter,
    sidra_period_code,
    sidra_period_label,
    uf,
    state_abbrev,
    state_name,
    macroregion,
    pnadc_population,
    pnadc_population_original_unit,
    unemployment_rate_pnadc,
    labor_income_real_pnadc,
    informality_rate_pnadc,
    formalization_rate_pnadc,
    income_variable_used,
    population_concept,
    formalization_rule,
    source_system
  ) |>
  dplyr::arrange(period_date, state_abbrev)

registry <- purrr::imap_dfr(
  pnadc_sidra_tables,
  function(table_config, table_name) {
    tibble::tibble(
      source_name = table_name,
      table_id = table_config$table_id,
      variable_code = table_config$variable_code,
      condition_code = list_item_or_na(table_config, "condition_code"),
      series_name = table_config$series_name,
      description = table_config$description,
      api = table_config$api,
      raw_output_path = table_config$raw_output_path,
      raw_rows = nrow(raw_downloads[[table_name]]),
      status = "downloaded",
      downloaded_at = Sys.Date()
    )
  }
)

processed_path <- file.path(path_data_processed, "pnadc_sidra_quarterly_state_covariates_processed.csv")
panel_ready_path <- file.path(path_data_processed, "pnadc_sidra_quarterly_state_covariates_panel_ready.csv")
registry_path <- file.path(path_data_raw_ibge, "pnadc_sidra_quarterly_download_registry.csv")

readr::write_csv(pnadc_processed, processed_path, na = "")
readr::write_csv(pnadc_processed, panel_ready_path, na = "")
readr::write_csv(registry, registry_path, na = "")

message("Saved PNADc SIDRA processed file: ", processed_path)
message("Saved PNADc SIDRA panel-ready file: ", panel_ready_path)
message("Saved PNADc SIDRA registry: ", registry_path)
message("PNADc SIDRA download script completed.")
