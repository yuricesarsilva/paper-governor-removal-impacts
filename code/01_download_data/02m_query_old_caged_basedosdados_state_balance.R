source(file.path("code", "01_download_data", "00_download_config.R"))

if (!requireNamespace("basedosdados", quietly = TRUE)) {
  stop(
    "Package basedosdados is required for this script. ",
    "Install it with install.packages('basedosdados') and configure a Google Cloud ",
    "billing project before running."
  )
}

integrity_path <- file.path(path_data_raw_mte, "old_caged_complete_integrity_7z.csv")

if (!file.exists(integrity_path)) {
  stop("Integrity inventory not found: ", integrity_path)
}

query_scope <- Sys.getenv("BD_CAGED_QUERY_SCOPE", unset = "failed_months")
billing_project_id <- Sys.getenv("BD_BILLING_PROJECT_ID", unset = "")

if (!nzchar(billing_project_id)) {
  billing_project_id <- tryCatch(
    basedosdados::get_billing_id(),
    error = function(e) ""
  )
}

if (!nzchar(billing_project_id)) {
  stop(
    "No Base dos Dados/BigQuery billing project was found. ",
    "Set BD_BILLING_PROJECT_ID or run basedosdados::set_billing_id('<PROJECT_ID>')."
  )
}

parse_caged_file_month <- function(file_name) {
  match <- stringr::str_match(file_name, "^CAGEDEST_([0-9]{2})([0-9]{4})\\.7z$")

  tibble::tibble(
    file = file_name,
    month = as.integer(match[, 2]),
    year = as.integer(match[, 3])
  )
}

integrity_inventory <- readr::read_csv(integrity_path, show_col_types = FALSE)

failed_months <- integrity_inventory |>
  dplyr::filter(integrity_status == "failed") |>
  dplyr::pull(file) |>
  purrr::map_dfr(parse_caged_file_month) |>
  dplyr::filter(!is.na(year), !is.na(month)) |>
  dplyr::distinct(year, month) |>
  dplyr::arrange(year, month)

if (query_scope == "failed_months" && nrow(failed_months) == 0) {
  stop("No failed months were found in ", integrity_path)
}

target_months_sql <- failed_months |>
  dplyr::transmute(
    filter_sql = sprintf("(ano = %d AND mes = %d)", year, month)
  ) |>
  dplyr::pull(filter_sql) |>
  paste(collapse = "\n  OR ")

where_clause <- switch(
  query_scope,
  "failed_months" = paste0(
    "WHERE ",
    target_months_sql
  ),
  "all_2007_2019" = "WHERE ano BETWEEN 2007 AND 2019",
  stop(
    "Unsupported BD_CAGED_QUERY_SCOPE: ", query_scope,
    ". Use 'failed_months' or 'all_2007_2019'."
  )
)

query <- paste0(
  "SELECT\n",
  "  ano,\n",
  "  mes,\n",
  "  sigla_uf,\n",
  "  SUM(saldo_movimentacao) AS formal_hiring_balance,\n",
  "  COUNT(*) AS n_records\n",
  "FROM `basedosdados.br_me_caged.microdados_antigos`\n",
  where_clause,
  "\nGROUP BY ano, mes, sigla_uf\n",
  "ORDER BY ano, mes, sigla_uf"
)

query_output_path <- file.path(
  path_data_raw_mte,
  paste0("old_caged_basedosdados_state_balance_query_", query_scope, ".sql")
)

readr::write_lines(query, query_output_path)

message("Saved Base dos Dados query: ", query_output_path)
message("Running query with scope: ", query_scope)

state_balance <- basedosdados::read_sql(
  query = query,
  billing_project_id = billing_project_id
) |>
  dplyr::mutate(
    year = as.integer(ano),
    month = as.integer(mes),
    competencia = sprintf("%04d%02d", year, month),
    state_abbrev = as.character(sigla_uf),
    formal_hiring_balance = as.integer(formal_hiring_balance),
    n_records = as.integer(n_records),
    source_series = "old_caged_basedosdados_microdados_antigos",
    query_scope = query_scope
  ) |>
  dplyr::select(
    competencia,
    year,
    month,
    state_abbrev,
    formal_hiring_balance,
    n_records,
    source_series,
    query_scope
  ) |>
  dplyr::arrange(competencia, state_abbrev)

output_path <- file.path(
  path_data_raw_mte,
  paste0("old_caged_basedosdados_state_balance_monthly_", query_scope, ".csv")
)

readr::write_csv(state_balance, output_path, na = "")

coverage <- state_balance |>
  dplyr::group_by(competencia, year, month) |>
  dplyr::summarise(
    n_ufs = dplyr::n_distinct(state_abbrev),
    total_balance = sum(formal_hiring_balance, na.rm = TRUE),
    total_records = sum(n_records, na.rm = TRUE),
    .groups = "drop"
  ) |>
  dplyr::arrange(competencia)

coverage_output_path <- file.path(
  path_data_raw_mte,
  paste0("old_caged_basedosdados_state_balance_coverage_", query_scope, ".csv")
)

readr::write_csv(coverage, coverage_output_path, na = "")

message("Saved Base dos Dados state balance file: ", output_path)
message("Saved Base dos Dados coverage file: ", coverage_output_path)
