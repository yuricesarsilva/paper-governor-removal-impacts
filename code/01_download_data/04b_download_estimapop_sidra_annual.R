source(file.path("code", "01_download_data", "00_download_config.R"))

resident_population_sidra_tables <- list(
  estimapop = list(
    table_id = 6579,
    description = "Populacao residente estimada",
    api_candidates = c(
      "/t/6579/n3/all/p/all",
      "/t/6579/n3/all/v/9324/p/all"
    ),
    raw_output_path = file.path(path_data_raw_ibge, "estimapop_resident_population_annual.csv"),
    source_system = "SIDRA/EstimaPop",
    reference_date_rule = "1 July"
  ),
  contagem_2007 = list(
    table_id = 793,
    description = "Populacao residente - Contagem 2007",
    api_candidates = c("/t/793/n3/all/p/2007"),
    raw_output_path = file.path(path_data_raw_ibge, "contagem_2007_resident_population_annual.csv"),
    source_system = "SIDRA/Contagem2007",
    reference_date_rule = "31 August"
  ),
  censo_2010 = list(
    table_id = 202,
    description = "Populacao residente, por sexo e situacao do domicilio - Censo 2010",
    api_candidates = c("/t/202/n3/all/p/2010"),
    raw_output_path = file.path(path_data_raw_ibge, "censo_2010_resident_population_annual.csv"),
    source_system = "SIDRA/Censo2010",
    reference_date_rule = "31 July"
  ),
  censo_2022 = list(
    table_id = 4709,
    description = "Populacao residente - Primeiros resultados do Censo 2022",
    api_candidates = c("/t/4709/n3/all/p/2022"),
    raw_output_path = file.path(path_data_raw_ibge, "censo_2022_resident_population_annual.csv"),
    source_system = "SIDRA/Censo2022",
    reference_date_rule = "31 July"
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

download_sidra_table <- function(table_config) {
  last_error <- NULL

  for (api in table_config$api_candidates) {
    message("Downloading SIDRA table ", table_config$table_id, " with API ", api)

    raw_attempt <- tryCatch(
      sidrar::get_sidra(api = api),
      error = function(e) e
    )

    if (!inherits(raw_attempt, "error")) {
      raw_data <- clean_sidra_result(raw_attempt)
      write_raw_csv(raw_data, table_config$raw_output_path)
      return(list(raw_data = raw_data, api = api))
    }

    last_error <- raw_attempt
  }

  stop("Failed to download SIDRA table ", table_config$table_id, ": ", conditionMessage(last_error))
}

standardize_population_table <- function(raw_data, table_config, uf_lookup) {
  population_data <- raw_data |>
    dplyr::transmute(
      uf = as.integer(unidade_da_federacao_codigo),
      year = as.integer(ano_codigo),
      variable_code = as.integer(variavel_codigo),
      variable_label = as.character(variavel),
      population = parse_sidra_value(valor)
    )

  if ("situacao_do_domicilio_codigo" %in% names(raw_data)) {
    population_data$situation_code <- as.integer(raw_data$situacao_do_domicilio_codigo)
  } else {
    population_data$situation_code <- NA_integer_
  }

  if ("sexo_codigo" %in% names(raw_data)) {
    population_data$sex_code <- as.integer(raw_data$sexo_codigo)
  } else {
    population_data$sex_code <- NA_integer_
  }

  population_data <- population_data |>
    dplyr::filter(!is.na(.data$uf), !is.na(.data$year), !is.na(.data$population))

  if ("variable_label" %in% names(population_data)) {
    population_data <- population_data |>
      dplyr::filter(
        is.na(.data$variable_label) |
          stringr::str_detect(
            stringr::str_to_lower(.data$variable_label),
            "populacao residente|população residente"
          )
      )
  }

  if ("situation_code" %in% names(population_data)) {
    population_data <- population_data |>
      dplyr::filter(is.na(.data$situation_code) | .data$situation_code == 0L)
  }

  if ("sex_code" %in% names(population_data)) {
    population_data <- population_data |>
      dplyr::filter(is.na(.data$sex_code) | .data$sex_code == 0L)
  }

  population_data |>
    dplyr::distinct(.data$uf, .data$year, .keep_all = TRUE) |>
    dplyr::mutate(
      period = as.character(.data$year),
      period_date = as.Date(sprintf("%d-07-01", .data$year)),
      source_system = table_config$source_system,
      source_frequency = "annual",
      reference_date_rule = table_config$reference_date_rule,
      source_table_id = as.character(table_config$table_id),
      observation_status = "observed",
      imputation_rule = NA_character_
    ) |>
    dplyr::left_join(uf_lookup, by = "uf") |>
    dplyr::select(
      period,
      period_date,
      year,
      uf,
      state_abbrev,
      state_name,
      macroregion,
      population,
      source_system,
      source_frequency,
      reference_date_rule,
      source_table_id,
      observation_status,
      imputation_rule
    ) |>
    dplyr::arrange(.data$year, .data$state_abbrev)
}

build_2023_interpolation <- function(population_panel) {
  pop_2022 <- population_panel |>
    dplyr::filter(.data$year == 2022L) |>
    dplyr::select(
      uf,
      state_abbrev,
      state_name,
      macroregion,
      population_2022 = population
    )

  pop_2024 <- population_panel |>
    dplyr::filter(.data$year == 2024L) |>
    dplyr::select(
      uf,
      population_2024 = population
    )

  pop_2022 |>
    dplyr::inner_join(pop_2024, by = "uf") |>
    dplyr::transmute(
      period = "2023",
      period_date = as.Date("2023-07-01"),
      year = 2023L,
      uf,
      state_abbrev,
      state_name,
      macroregion,
      population = (.data$population_2022 + .data$population_2024) / 2,
      source_system = "Derived",
      source_frequency = "annual",
      reference_date_rule = "1 July",
      source_table_id = "4709|6579",
      observation_status = "imputed",
      imputation_rule = "mean_of_2022_census_and_2024_estimapop"
    )
}

uf_lookup_path <- file.path(path_data_processed, "uf_code_lookup.csv")

if (!file.exists(uf_lookup_path)) {
  stop("UF lookup file not found: ", uf_lookup_path)
}

uf_lookup <- readr::read_csv(uf_lookup_path, show_col_types = FALSE) |>
  dplyr::filter(include_in_panel) |>
  dplyr::select(uf, state_abbrev, state_name, macroregion)

download_results <- purrr::imap(
  resident_population_sidra_tables,
  ~ {
    table_result <- download_sidra_table(.x)
    standardized <- standardize_population_table(table_result$raw_data, .x, uf_lookup)

    list(
      key = .y,
      table_id = .x$table_id,
      description = .x$description,
      api = table_result$api,
      raw_output_path = .x$raw_output_path,
      raw_rows = nrow(table_result$raw_data),
      processed_rows = nrow(standardized),
      data = standardized
    )
  }
)

observed_population <- purrr::map_dfr(download_results, "data") |>
  dplyr::arrange(.data$year, .data$state_abbrev)

interpolated_2023 <- build_2023_interpolation(observed_population)

resident_population_panel <- observed_population |>
  dplyr::bind_rows(interpolated_2023) |>
  dplyr::arrange(.data$year, .data$state_abbrev)

processed_path <- file.path(path_data_processed, "resident_population_annual_processed.csv")
panel_ready_path <- file.path(path_data_processed, "resident_population_annual_panel_ready.csv")
legacy_processed_path <- file.path(path_data_processed, "estimapop_resident_population_annual_processed.csv")
legacy_panel_ready_path <- file.path(path_data_processed, "estimapop_resident_population_annual_panel_ready.csv")
registry_path <- file.path(path_data_raw_ibge, "resident_population_sidra_annual_download_registry.csv")

registry <- purrr::map_dfr(
  download_results,
  ~ {
    first_year <- if (.x$processed_rows > 0) min(.x$data$year, na.rm = TRUE) else NA_integer_
    last_year <- if (.x$processed_rows > 0) max(.x$data$year, na.rm = TRUE) else NA_integer_

    tibble::tibble(
      source_name = .x$key,
      table_id = as.character(.x$table_id),
      description = .x$description,
      api = .x$api,
      raw_output_path = .x$raw_output_path,
      raw_rows = .x$raw_rows,
      processed_rows = .x$processed_rows,
      first_year = first_year,
      last_year = last_year,
      status = "downloaded",
      downloaded_at = Sys.Date()
    )
  }
) |>
  dplyr::bind_rows(
    tibble::tibble(
      source_name = "resident_population_2023_interpolation",
      table_id = "4709|6579",
      description = "2023 resident population interpolated as mean of 2022 and 2024",
      api = NA_character_,
      raw_output_path = NA_character_,
      raw_rows = NA_integer_,
      processed_rows = nrow(interpolated_2023),
      first_year = 2023L,
      last_year = 2023L,
      status = "derived",
      downloaded_at = Sys.Date()
    )
  )

readr::write_csv(resident_population_panel, processed_path, na = "")
readr::write_csv(resident_population_panel, panel_ready_path, na = "")
readr::write_csv(resident_population_panel, legacy_processed_path, na = "")
readr::write_csv(resident_population_panel, legacy_panel_ready_path, na = "")
readr::write_csv(registry, registry_path, na = "")

message("Saved resident population processed file: ", processed_path)
message("Saved resident population panel-ready file: ", panel_ready_path)
message("Saved compatibility processed file: ", legacy_processed_path)
message("Saved compatibility panel-ready file: ", legacy_panel_ready_path)
message("Saved resident population SIDRA registry: ", registry_path)
message("Resident population SIDRA annual download script completed.")
