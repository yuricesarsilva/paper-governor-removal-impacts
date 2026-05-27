source(file.path("code", "01_download_data", "00_download_config.R"))

pnad_legacy_sidra_tables <- list(
  activity = list(
    table_id = 1864,
    variable_code = 140,
    description = "Pessoas de 10 anos ou mais por condicao de atividade",
    api = "/t/1864/n3/all/v/140/p/all/c90/all/c2/0/c1/0/c58/0",
    raw_output_path = file.path(path_data_raw_ibge, "pnad_legacy_activity_10_plus_annual.csv")
  ),
  unemployed = list(
    table_id = 1868,
    variable_code = 777,
    description = "Pessoas de 10 anos ou mais desocupadas que procuraram trabalho",
    api = "/t/1868/n3/all/v/777/p/all/c11284/98626/c2/0/c58/0",
    raw_output_path = file.path(path_data_raw_ibge, "pnad_legacy_unemployed_10_plus_annual.csv")
  ),
  labor_income = list(
    table_id = 1871,
    variable_code = 778,
    description = "Rendimento medio mensal nominal de todos os trabalhos",
    api = "/t/1871/n3/all/v/778/p/all/c2/6794/c12025/99149",
    raw_output_path = file.path(path_data_raw_ibge, "pnad_legacy_labor_income_nominal_annual.csv")
  ),
  previd_contribution = list(
    table_id = 1901,
    variable_code = 696,
    description = "Ocupados por contribuicao para instituto de previdencia",
    api = "/t/1901/n3/all/v/696/p/all/c12038/all/c2/0/c58/0",
    raw_output_path = file.path(path_data_raw_ibge, "pnad_legacy_previd_contribution_annual.csv")
  )
)

parse_sidra_value <- function(x) {
  readr::parse_number(
    as.character(x),
    locale = readr::locale(decimal_mark = ".", grouping_mark = ","),
    na = c("", "...", "-", "NA")
  )
}

first_or_na <- function(x) {
  x <- x[!is.na(x)]

  if (length(x) == 0) {
    NA_real_
  } else {
    x[[1]]
  }
}

clean_sidra_result <- function(data) {
  data |>
    janitor::clean_names() |>
    dplyr::mutate(downloaded_at = Sys.Date())
}

download_pnad_legacy_table <- function(table_config) {
  message(
    "Downloading PNAD legacy SIDRA table ",
    table_config$table_id,
    " variable ",
    table_config$variable_code
  )

  raw_data <- sidrar::get_sidra(api = table_config$api)
  clean_data <- clean_sidra_result(raw_data)

  write_raw_csv(clean_data, table_config$raw_output_path)

  clean_data
}

raw_downloads <- purrr::imap(
  pnad_legacy_sidra_tables,
  ~download_pnad_legacy_table(.x)
)

activity <- raw_downloads$activity |>
  dplyr::transmute(
    uf = as.integer(unidade_da_federacao_codigo),
    year = as.integer(ano_codigo),
    activity_code = as.integer(condicao_de_atividade_codigo),
    value = parse_sidra_value(valor) * 1000
  ) |>
  dplyr::group_by(uf, year) |>
  dplyr::summarise(
    pnad_legacy_population_10_plus = first_or_na(value[activity_code == 95355]),
    labor_force_pnad_legacy = first_or_na(value[activity_code == 3287]),
    non_labor_force_pnad_legacy = first_or_na(value[activity_code == 3288]),
    .groups = "drop"
  )

unemployed <- raw_downloads$unemployed |>
  dplyr::transmute(
    uf = as.integer(unidade_da_federacao_codigo),
    year = as.integer(ano_codigo),
    unemployed_pnad_legacy = parse_sidra_value(valor) * 1000
  )

income <- raw_downloads$labor_income |>
  dplyr::transmute(
    uf = as.integer(unidade_da_federacao_codigo),
    year = as.integer(ano_codigo),
    labor_income_nominal_pnad_legacy = parse_sidra_value(valor)
  )

previd <- raw_downloads$previd_contribution |>
  dplyr::transmute(
    uf = as.integer(unidade_da_federacao_codigo),
    year = as.integer(ano_codigo),
    previd_code = as.integer(contribuicao_para_instituto_de_previdencia_codigo),
    value = parse_sidra_value(valor) * 1000
  ) |>
  dplyr::group_by(uf, year) |>
  dplyr::summarise(
    occupied_pnad_legacy = first_or_na(value[previd_code == 0]),
    previd_contributors_any_work_pnad_legacy = first_or_na(value[previd_code == 99325]),
    previd_non_contributors_any_work_pnad_legacy = first_or_na(value[previd_code == 99326]),
    .groups = "drop"
  )

ipca_path <- file.path(path_data_raw_ibge, "ipca_national_monthly.csv")

if (!file.exists(ipca_path)) {
  stop("IPCA raw file not found: ", ipca_path)
}

ipca <- readr::read_csv(ipca_path, show_col_types = FALSE) |>
  janitor::clean_names() |>
  dplyr::transmute(
    month_code = as.integer(mes_codigo),
    year = month_code %/% 100,
    month = month_code %% 100,
    ipca_index = parse_sidra_value(valor)
  ) |>
  dplyr::filter(!is.na(ipca_index))

base_ipca <- ipca |>
  dplyr::filter(month_code == max(month_code, na.rm = TRUE)) |>
  dplyr::summarise(base_month_code = first_or_na(month_code), base_index = first_or_na(ipca_index))

ipca_september <- ipca |>
  dplyr::filter(month == 9) |>
  dplyr::select(year, ipca_reference_index = ipca_index)

uf_lookup_path <- file.path(path_data_processed, "uf_code_lookup.csv")

if (!file.exists(uf_lookup_path)) {
  stop("UF lookup file not found: ", uf_lookup_path)
}

uf_lookup <- readr::read_csv(uf_lookup_path, show_col_types = FALSE) |>
  dplyr::filter(include_in_panel) |>
  dplyr::select(uf, state_abbrev, state_name, macroregion)

observed_panel <- activity |>
  dplyr::full_join(unemployed, by = c("uf", "year")) |>
  dplyr::full_join(income, by = c("uf", "year")) |>
  dplyr::full_join(previd, by = c("uf", "year")) |>
  dplyr::left_join(ipca_september, by = "year") |>
  dplyr::mutate(
    labor_income_real_pnad_legacy = labor_income_nominal_pnad_legacy *
      base_ipca$base_index / ipca_reference_index,
    unemployment_rate_pnad_legacy = dplyr::if_else(
      labor_force_pnad_legacy > 0,
      unemployed_pnad_legacy / labor_force_pnad_legacy,
      NA_real_
    ),
    formalization_proxy_pnad_legacy = dplyr::if_else(
      occupied_pnad_legacy > 0,
      previd_contributors_any_work_pnad_legacy / occupied_pnad_legacy,
      NA_real_
    ),
    is_observed_pnad_legacy_year = TRUE,
    imputation_method = NA_character_
  )

impute_2010 <- function(data) {
  data |>
    dplyr::filter(year %in% c(2009, 2011)) |>
    dplyr::group_by(uf) |>
    dplyr::summarise(
      pnad_legacy_population_10_plus = mean(pnad_legacy_population_10_plus, na.rm = TRUE),
      labor_force_pnad_legacy = mean(labor_force_pnad_legacy, na.rm = TRUE),
      non_labor_force_pnad_legacy = mean(non_labor_force_pnad_legacy, na.rm = TRUE),
      unemployed_pnad_legacy = mean(unemployed_pnad_legacy, na.rm = TRUE),
      labor_income_nominal_pnad_legacy = mean(labor_income_nominal_pnad_legacy, na.rm = TRUE),
      occupied_pnad_legacy = mean(occupied_pnad_legacy, na.rm = TRUE),
      previd_contributors_any_work_pnad_legacy = mean(previd_contributors_any_work_pnad_legacy, na.rm = TRUE),
      previd_non_contributors_any_work_pnad_legacy = mean(previd_non_contributors_any_work_pnad_legacy, na.rm = TRUE),
      ipca_reference_index = mean(ipca_reference_index, na.rm = TRUE),
      labor_income_real_pnad_legacy = mean(labor_income_real_pnad_legacy, na.rm = TRUE),
      unemployment_rate_pnad_legacy = mean(unemployment_rate_pnad_legacy, na.rm = TRUE),
      formalization_proxy_pnad_legacy = mean(formalization_proxy_pnad_legacy, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      year = 2010L,
      is_observed_pnad_legacy_year = FALSE,
      imputation_method = "linear_interpolation_2009_2011"
    )
}

imputed_2010 <- impute_2010(observed_panel)

pnad_legacy_processed <- dplyr::bind_rows(observed_panel, imputed_2010) |>
  dplyr::left_join(uf_lookup, by = "uf") |>
  dplyr::mutate(
    period = as.character(year),
    period_date = as.Date(sprintf("%d-09-01", year)),
    source_system = "SIDRA/PNAD legacy",
    source_frequency = "annual",
    labor_market_age_concept = "Pessoas de 10 anos ou mais",
    formalization_rule = "previd_contributors_any_work_pnad_legacy / occupied_pnad_legacy",
    income_deflator_rule = paste0(
      "IPCA national index, September of PNAD year to ",
      base_ipca$base_month_code
    )
  ) |>
  dplyr::select(
    period,
    period_date,
    year,
    uf,
    state_abbrev,
    state_name,
    macroregion,
    pnad_legacy_population_10_plus,
    labor_force_pnad_legacy,
    non_labor_force_pnad_legacy,
    unemployed_pnad_legacy,
    unemployment_rate_pnad_legacy,
    occupied_pnad_legacy,
    previd_contributors_any_work_pnad_legacy,
    previd_non_contributors_any_work_pnad_legacy,
    formalization_proxy_pnad_legacy,
    labor_income_nominal_pnad_legacy,
    labor_income_real_pnad_legacy,
    ipca_reference_index,
    is_observed_pnad_legacy_year,
    imputation_method,
    labor_market_age_concept,
    formalization_rule,
    income_deflator_rule,
    source_system,
    source_frequency
  ) |>
  dplyr::arrange(year, state_abbrev)

registry <- purrr::imap_dfr(
  pnad_legacy_sidra_tables,
  function(table_config, table_name) {
    tibble::tibble(
      source_name = table_name,
      table_id = table_config$table_id,
      variable_code = table_config$variable_code,
      description = table_config$description,
      api = table_config$api,
      raw_output_path = table_config$raw_output_path,
      raw_rows = nrow(raw_downloads[[table_name]]),
      status = "downloaded",
      downloaded_at = Sys.Date()
    )
  }
)

processed_path <- file.path(path_data_processed, "pnad_legacy_sidra_annual_state_covariates_processed.csv")
panel_ready_path <- file.path(path_data_processed, "pnad_legacy_sidra_annual_state_covariates_panel_ready.csv")
registry_path <- file.path(path_data_raw_ibge, "pnad_legacy_sidra_annual_download_registry.csv")

readr::write_csv(pnad_legacy_processed, processed_path, na = "")
readr::write_csv(pnad_legacy_processed, panel_ready_path, na = "")
readr::write_csv(registry, registry_path, na = "")

message("Saved PNAD legacy SIDRA processed file: ", processed_path)
message("Saved PNAD legacy SIDRA panel-ready file: ", panel_ready_path)
message("Saved PNAD legacy SIDRA registry: ", registry_path)
message("PNAD legacy SIDRA annual download script completed.")
