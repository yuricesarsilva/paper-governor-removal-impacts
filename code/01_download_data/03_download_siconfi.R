source(file.path("code", "01_download_data", "00_download_config.R"))

extra_required_packages <- c("httr", "jsonlite", "tidyr")
missing_extra_packages <- extra_required_packages[!vapply(
  extra_required_packages,
  requireNamespace,
  logical(1),
  quietly = TRUE
)]

if (length(missing_extra_packages) > 0) {
  stop(
    "Missing required packages for Siconfi/RREO block: ",
    paste(missing_extra_packages, collapse = ", "),
    ". Install them before running this script."
  )
}

path_data_raw_siconfi <- file.path(path_data_raw, "siconfi")

if (!dir.exists(path_data_raw_siconfi)) {
  dir.create(path_data_raw_siconfi, recursive = TRUE)
}

siconfi_base_url <- "https://apidatalake.tesouro.gov.br/ords/siconfi/tt/rreo"
siconfi_limit <- as.integer(Sys.getenv("SICONFI_LIMIT", unset = "5000"))
start_year <- as.integer(Sys.getenv("SICONFI_START_YEAR", unset = "2015"))
end_year <- as.integer(Sys.getenv("SICONFI_END_YEAR", unset = format(Sys.Date(), "%Y")))
output_prefix <- Sys.getenv("SICONFI_OUTPUT_PREFIX", unset = "siconfi_rreo_state_fiscal_bimonthly")

parse_integer_list_env <- function(env_name, default_values) {
  raw_value <- Sys.getenv(env_name, unset = "")

  if (!nzchar(raw_value)) {
    return(default_values)
  }

  as.integer(strsplit(raw_value, ",", fixed = TRUE)[[1]])
}

selected_years <- seq.int(start_year, end_year)
selected_bimesters <- parse_integer_list_env("SICONFI_BIMESTERS", 1:6)

uf_lookup_path <- file.path(path_data_processed, "uf_code_lookup.csv")

if (!file.exists(uf_lookup_path)) {
  stop("UF lookup file not found: ", uf_lookup_path)
}

uf_lookup <- readr::read_csv(uf_lookup_path, show_col_types = FALSE) |>
  dplyr::filter(include_in_panel) |>
  dplyr::mutate(uf = as.integer(uf)) |>
  dplyr::select(uf, state_abbrev, state_name, macroregion)

selected_ufs <- parse_integer_list_env("SICONFI_UF_CODES", uf_lookup$uf)

siconfi_annexes <- list(
  annex01 = list(
    no_anexo = "RREO-Anexo 01",
    raw_output_path = file.path(path_data_raw_siconfi, paste0(output_prefix, "_annex01_raw.csv"))
  ),
  annex02 = list(
    no_anexo = "RREO-Anexo 02",
    raw_output_path = file.path(path_data_raw_siconfi, paste0(output_prefix, "_annex02_raw.csv"))
  ),
  annex06 = list(
    no_anexo = "RREO-Anexo 06",
    raw_output_path = file.path(path_data_raw_siconfi, paste0(output_prefix, "_annex06_raw.csv"))
  )
)

parse_siconfi_value <- function(x) {
  if (is.numeric(x)) {
    return(as.numeric(x))
  }

  x_chr <- stringr::str_trim(as.character(x))
  output <- rep(NA_real_, length(x_chr))
  has_comma_decimal <- stringr::str_detect(x_chr, ",")

  output[has_comma_decimal] <- readr::parse_number(
    x_chr[has_comma_decimal],
    locale = readr::locale(decimal_mark = ",", grouping_mark = "."),
    na = c("", "NA", "null")
  )

  output[!has_comma_decimal] <- suppressWarnings(as.numeric(x_chr[!has_comma_decimal]))

  fallback <- is.na(output) & nzchar(x_chr)

  if (any(fallback)) {
    output[fallback] <- readr::parse_number(
      x_chr[fallback],
      locale = readr::locale(decimal_mark = ".", grouping_mark = ","),
      na = c("", "NA", "null")
    )
  }

  output
}

normalize_text <- function(x) {
  x |>
    as.character() |>
    iconv(from = "", to = "ASCII//TRANSLIT") |>
    tolower() |>
    stringr::str_replace_all("[^a-z0-9]+", " ") |>
    stringr::str_squish()
}

fetch_siconfi_page <- function(query) {
  response <- httr::GET(siconfi_base_url, query = query)

  if (httr::http_error(response)) {
    stop("Siconfi API request failed: HTTP ", httr::status_code(response))
  }

  content_text <- httr::content(response, as = "text", encoding = "UTF-8")
  jsonlite::fromJSON(content_text, flatten = TRUE)
}

fetch_siconfi_query <- function(query) {
  offset <- 0L
  pages <- list()

  repeat {
    page_query <- c(query, list(limit = siconfi_limit, offset = offset))
    page <- fetch_siconfi_page(page_query)
    items <- page$items

    if (is.null(items) || length(items) == 0) {
      items <- tibble::tibble()
    } else {
      items <- tibble::as_tibble(items)
    }

    pages[[length(pages) + 1L]] <- items

    has_more <- isTRUE(page$hasMore)

    if (!has_more || nrow(items) == 0) {
      break
    }

    offset <- offset + siconfi_limit
  }

  dplyr::bind_rows(pages)
}

download_one_combination <- function(year, bimester, uf_code, annex_name, annex_config) {
  query <- list(
    an_exercicio = year,
    nr_periodo = bimester,
    co_tipo_demonstrativo = "RREO",
    no_anexo = annex_config$no_anexo,
    id_ente = uf_code
  )

  message(
    "Downloading Siconfi RREO ",
    annex_config$no_anexo,
    " year ",
    year,
    " bimester ",
    bimester,
    " UF ",
    uf_code
  )

  tryCatch(
    {
      data <- fetch_siconfi_query(query) |>
        janitor::clean_names() |>
        dplyr::mutate(
          source_annex_name = annex_name,
          downloaded_at = Sys.Date()
        )

      list(
        data = data,
        registry = tibble::tibble(
          year = year,
          bimester = bimester,
          uf = uf_code,
          annex_name = annex_name,
          no_anexo = annex_config$no_anexo,
          rows = nrow(data),
          status = "downloaded",
          error_message = NA_character_
        )
      )
    },
    error = function(e) {
      list(
        data = tibble::tibble(),
        registry = tibble::tibble(
          year = year,
          bimester = bimester,
          uf = uf_code,
          annex_name = annex_name,
          no_anexo = annex_config$no_anexo,
          rows = 0L,
          status = "failed",
          error_message = conditionMessage(e)
        )
      )
    }
  )
}

grid <- tidyr::expand_grid(
  year = selected_years,
  bimester = selected_bimesters,
  uf = selected_ufs,
  annex_name = names(siconfi_annexes)
) |>
  dplyr::mutate(annex_config = purrr::map(annex_name, ~siconfi_annexes[[.x]]))

downloads <- purrr::pmap(
  list(grid$year, grid$bimester, grid$uf, grid$annex_name, grid$annex_config),
  download_one_combination
)

registry <- purrr::map(downloads, "registry") |>
  dplyr::bind_rows() |>
  dplyr::mutate(downloaded_at = Sys.Date())

raw_data <- purrr::map(downloads, "data") |>
  dplyr::bind_rows()

if (nrow(raw_data) == 0) {
  registry_path <- file.path(path_data_raw_siconfi, paste0(output_prefix, "_download_registry.csv"))
  readr::write_csv(registry, registry_path, na = "")
  stop("No Siconfi/RREO rows downloaded. Registry saved: ", registry_path)
}

for (annex_name in names(siconfi_annexes)) {
  annex_data <- raw_data |>
    dplyr::filter(source_annex_name == annex_name)

  readr::write_csv(annex_data, siconfi_annexes[[annex_name]]$raw_output_path, na = "")
  message("Saved raw Siconfi file: ", siconfi_annexes[[annex_name]]$raw_output_path)
}

registry_path <- file.path(path_data_raw_siconfi, paste0(output_prefix, "_download_registry.csv"))
readr::write_csv(registry, registry_path, na = "")

standardized <- raw_data |>
  dplyr::mutate(
    year = as.integer(exercicio),
    bimester = as.integer(periodo),
    uf = as.integer(cod_ibge),
    period = paste0(year, "B", bimester),
    bimester_end_month = bimester * 2L,
    period_date = as.Date(sprintf("%d-%02d-01", year, bimester_end_month)),
    value = parse_siconfi_value(valor),
    column_norm = normalize_text(coluna),
    account_norm = normalize_text(conta)
  )

revenue <- standardized |>
  dplyr::filter(
    source_annex_name == "annex01",
    column_norm == "no bimestre b",
    cod_conta %in% c(
      "ReceitasExcetoIntraOrcamentarias",
      "ReceitaTributaria",
      "TransferenciasCorrentesDaUniaoEDeSuasEntidades",
      "TransferenciasDeCapitalDaUniaoEDeSuasEntidades"
    )
  ) |>
  dplyr::mutate(
    series_name = dplyr::case_when(
      cod_conta == "ReceitasExcetoIntraOrcamentarias" ~ "total_revenue_nominal",
      cod_conta == "ReceitaTributaria" ~ "state_tax_revenue_nominal",
      cod_conta == "TransferenciasCorrentesDaUniaoEDeSuasEntidades" ~ "federal_current_transfers_nominal",
      cod_conta == "TransferenciasDeCapitalDaUniaoEDeSuasEntidades" ~ "federal_capital_transfers_nominal",
      TRUE ~ NA_character_
    )
  ) |>
  dplyr::select(uf, year, bimester, period, period_date, series_name, value) |>
  tidyr::pivot_wider(names_from = series_name, values_from = value)

expenditure <- standardized |>
  dplyr::filter(
    source_annex_name == "annex02",
    column_norm == "despesas liquidadas no bimestre",
    cod_conta == "RREO2TotalDespesas"
  ) |>
  dplyr::mutate(
    series_name = dplyr::case_when(
      stringr::str_detect(account_norm, "^despesas exceto intra") ~ "liquidated_expenditure_total_nominal",
      account_norm == "saude" ~ "liquidated_expenditure_health_nominal",
      account_norm == "educacao" ~ "liquidated_expenditure_education_nominal",
      account_norm == "seguranca publica" ~ "liquidated_expenditure_public_security_nominal",
      TRUE ~ NA_character_
    )
  ) |>
  dplyr::filter(!is.na(series_name)) |>
  dplyr::select(uf, year, bimester, period, period_date, series_name, value) |>
  tidyr::pivot_wider(names_from = series_name, values_from = value)

investment_cumulative <- standardized |>
  dplyr::filter(
    source_annex_name == "annex06",
    cod_conta == "RREO6Investimentos",
    stringr::str_detect(column_norm, "despesas liquidadas"),
    column_norm == "despesas liquidadas" |
      stringr::str_detect(column_norm, paste0("/ ", year, "$"))
  ) |>
  dplyr::transmute(
    uf,
    year,
    bimester,
    period,
    period_date,
    public_investment_liquidated_cumulative_nominal = value
  ) |>
  dplyr::arrange(uf, year, bimester) |>
  dplyr::group_by(uf, year) |>
  dplyr::mutate(
    public_investment_liquidated_nominal = public_investment_liquidated_cumulative_nominal -
      dplyr::lag(public_investment_liquidated_cumulative_nominal, default = 0),
    public_investment_flow_is_derived = TRUE,
    public_investment_negative_flow_flag = public_investment_liquidated_nominal < 0
  ) |>
  dplyr::ungroup()

ensure_numeric_columns <- function(data, column_names) {
  missing_columns <- setdiff(column_names, names(data))

  for (column_name in missing_columns) {
    data[[column_name]] <- NA_real_
  }

  data
}

ensure_logical_columns <- function(data, column_names) {
  missing_columns <- setdiff(column_names, names(data))

  for (column_name in missing_columns) {
    data[[column_name]] <- NA
  }

  data
}

ipca_path <- file.path(path_data_raw_ibge, "ipca_national_monthly.csv")

if (!file.exists(ipca_path)) {
  stop("IPCA raw file not found: ", ipca_path)
}

ipca <- readr::read_csv(ipca_path, show_col_types = FALSE) |>
  janitor::clean_names() |>
  dplyr::transmute(
    ipca_month_code = as.integer(mes_codigo),
    ipca_index = parse_siconfi_value(valor)
  ) |>
  dplyr::filter(!is.na(ipca_index))

base_ipca <- ipca |>
  dplyr::filter(ipca_month_code == max(ipca_month_code, na.rm = TRUE)) |>
  dplyr::summarise(
    base_ipca_month_code = dplyr::first(ipca_month_code),
    base_ipca_index = dplyr::first(ipca_index)
  )

nominal_panel <- revenue |>
  dplyr::full_join(expenditure, by = c("uf", "year", "bimester", "period", "period_date")) |>
  dplyr::full_join(investment_cumulative, by = c("uf", "year", "bimester", "period", "period_date")) |>
  ensure_numeric_columns(c(
    "total_revenue_nominal",
    "state_tax_revenue_nominal",
    "federal_current_transfers_nominal",
    "federal_capital_transfers_nominal",
    "liquidated_expenditure_total_nominal",
    "liquidated_expenditure_health_nominal",
    "liquidated_expenditure_education_nominal",
    "liquidated_expenditure_public_security_nominal",
    "public_investment_liquidated_cumulative_nominal",
    "public_investment_liquidated_nominal"
  )) |>
  ensure_logical_columns(c(
    "public_investment_flow_is_derived",
    "public_investment_negative_flow_flag"
  )) |>
  dplyr::mutate(
    federal_transfers_nominal =
      dplyr::coalesce(federal_current_transfers_nominal, 0) +
      dplyr::coalesce(federal_capital_transfers_nominal, 0),
    transfer_dependency_ratio = dplyr::if_else(
      total_revenue_nominal > 0,
      federal_transfers_nominal / total_revenue_nominal,
      NA_real_
    ),
    own_revenue_ratio = dplyr::if_else(
      total_revenue_nominal > 0,
      state_tax_revenue_nominal / total_revenue_nominal,
      NA_real_
    ),
    ipca_month_code = year * 100L + bimester * 2L
  ) |>
  dplyr::left_join(ipca, by = "ipca_month_code") |>
  dplyr::mutate(
    deflator_base_month = base_ipca$base_ipca_month_code,
    total_revenue_real = total_revenue_nominal * base_ipca$base_ipca_index / ipca_index,
    state_tax_revenue_real = state_tax_revenue_nominal * base_ipca$base_ipca_index / ipca_index,
    federal_transfers_real = federal_transfers_nominal * base_ipca$base_ipca_index / ipca_index,
    liquidated_expenditure_total_real = liquidated_expenditure_total_nominal * base_ipca$base_ipca_index / ipca_index,
    liquidated_expenditure_health_real = liquidated_expenditure_health_nominal * base_ipca$base_ipca_index / ipca_index,
    liquidated_expenditure_education_real = liquidated_expenditure_education_nominal * base_ipca$base_ipca_index / ipca_index,
    liquidated_expenditure_public_security_real =
      liquidated_expenditure_public_security_nominal * base_ipca$base_ipca_index / ipca_index,
    public_investment_liquidated_real = public_investment_liquidated_nominal * base_ipca$base_ipca_index / ipca_index
  ) |>
  dplyr::left_join(uf_lookup, by = "uf") |>
  dplyr::mutate(
    source_system = "Siconfi/RREO",
    source_frequency = "bimonthly",
    fiscal_series_version = "rreo_annex01_02_06_v1"
  ) |>
  dplyr::select(
    period,
    period_date,
    year,
    bimester,
    uf,
    state_abbrev,
    state_name,
    macroregion,
    total_revenue_nominal,
    total_revenue_real,
    state_tax_revenue_nominal,
    state_tax_revenue_real,
    federal_current_transfers_nominal,
    federal_capital_transfers_nominal,
    federal_transfers_nominal,
    federal_transfers_real,
    transfer_dependency_ratio,
    own_revenue_ratio,
    liquidated_expenditure_total_nominal,
    liquidated_expenditure_total_real,
    liquidated_expenditure_health_nominal,
    liquidated_expenditure_health_real,
    liquidated_expenditure_education_nominal,
    liquidated_expenditure_education_real,
    liquidated_expenditure_public_security_nominal,
    liquidated_expenditure_public_security_real,
    public_investment_liquidated_cumulative_nominal,
    public_investment_liquidated_nominal,
    public_investment_liquidated_real,
    public_investment_flow_is_derived,
    public_investment_negative_flow_flag,
    ipca_month_code,
    deflator_base_month,
    source_system,
    source_frequency,
    fiscal_series_version
  ) |>
  dplyr::arrange(period_date, state_abbrev)

processed_path <- file.path(path_data_processed, paste0(output_prefix, "_processed.csv"))
panel_ready_path <- file.path(path_data_processed, paste0(output_prefix, "_panel_ready.csv"))

readr::write_csv(nominal_panel, processed_path, na = "")
readr::write_csv(nominal_panel, panel_ready_path, na = "")

message("Saved Siconfi/RREO registry: ", registry_path)
message("Saved Siconfi/RREO processed file: ", processed_path)
message("Saved Siconfi/RREO panel-ready file: ", panel_ready_path)
message("Siconfi/RREO download script completed.")
