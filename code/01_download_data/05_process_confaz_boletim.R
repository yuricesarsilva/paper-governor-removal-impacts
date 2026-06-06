source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

source_candidates <- c(
  file.path(path_data_raw_confaz, "confaz_boletim_tributos_estaduais_20260330.xls"),
  file.path(root_dir, "20260330_dados-abertos.xls")
)

source_path <- source_candidates[file.exists(source_candidates)][1]

if (is.na(source_path)) {
  stop("CONFAZ source workbook not found in expected locations.")
}

dir.create(path_data_raw_confaz, recursive = TRUE, showWarnings = FALSE)
dir.create(path_output, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(path_output, "validation"), recursive = TRUE, showWarnings = FALSE)

canonical_raw_path <- file.path(
  path_data_raw_confaz,
  "confaz_boletim_tributos_estaduais_20260330.xls"
)

if (!file.exists(canonical_raw_path) || normalizePath(source_path, winslash = "/", mustWork = TRUE) != normalizePath(canonical_raw_path, winslash = "/", mustWork = FALSE)) {
  file.copy(source_path, canonical_raw_path, overwrite = TRUE)
}

uf_lookup_path <- file.path(path_data_processed, "uf_code_lookup.csv")
if (!file.exists(uf_lookup_path)) {
  stop("UF lookup file not found: ", uf_lookup_path)
}

uf_lookup <- readr::read_csv(uf_lookup_path, show_col_types = FALSE) |>
  dplyr::mutate(
    uf = as.integer(uf)
  )

trim_empty_edges <- function(data) {
  keep_cols <- vapply(
    data,
    function(col) {
      any(!is.na(col) & trimws(as.character(col)) != "")
    },
    logical(1)
  )

  data[, keep_cols, drop = FALSE]
}

read_confaz_sheet <- function(path, sheet_name, spurious_header_index = NULL) {
  raw <- readxl::read_excel(
    path,
    sheet = sheet_name,
    col_names = FALSE
  )

  metadata_row <- raw[1, , drop = FALSE]
  header_row <- raw[2, , drop = FALSE]
  data <- raw[-c(1, 2), , drop = FALSE]

  header_values <- header_row |>
    as.list() |>
    unlist(use.names = FALSE) |>
    as.character()

  # The "arrecadacao por setor" header row carries a spurious `id_usuario` label
  # that has no matching data column: the value columns (va_icms_*) actually
  # start one position to the LEFT of their header labels, so every downstream
  # label is shifted right by one relative to the data. Dropping the spurious
  # label realigns every label to its true data column. Verified across all rows:
  # with this shift, `total == sum of the 7 sectors` holds in ~98% of rows and
  # `receita == total + outros_tributos` in ~99.7%; without it, 0%.
  if (!is.null(spurious_header_index)) {
    header_values <- header_values[-spurious_header_index]
    if (length(header_values) < ncol(data)) {
      header_values <- c(
        header_values,
        paste0("drop_extra_", seq_len(ncol(data) - length(header_values)))
      )
    } else if (length(header_values) > ncol(data)) {
      header_values <- header_values[seq_len(ncol(data))]
    }
  }

  header_values[is.na(header_values) | trimws(header_values) == ""] <- paste0(
    "blank_col_",
    seq_len(sum(is.na(header_values) | trimws(header_values) == ""))
  )

  names(data) <- janitor::make_clean_names(header_values, ascii = TRUE)
  data <- trim_empty_edges(data)

  list(
    metadata = metadata_row,
    data = tibble::as_tibble(data)
  )
}

coerce_numeric_columns <- function(data, numeric_cols) {
  numeric_cols <- intersect(numeric_cols, names(data))
  if (length(numeric_cols) == 0) {
    return(data)
  }

  data |>
    dplyr::mutate(
      dplyr::across(
        dplyr::all_of(numeric_cols),
        ~ suppressWarnings(as.numeric(as.character(.x)))
      )
    )
}

build_variable_coverage <- function(data, id_cols) {
  value_cols <- setdiff(names(data), id_cols)

  purrr::map_dfr(
    value_cols,
    function(col_name) {
      series <- data[[col_name]]
      non_missing_idx <- which(!is.na(series))
      is_numeric_series <- is.numeric(series)

      tibble::tibble(
        variable = col_name,
        data_class = class(series)[1],
        non_missing_rows = length(non_missing_idx),
        missing_rows = sum(is.na(series)),
        missing_share = mean(is.na(series)),
        first_period = if (length(non_missing_idx) == 0) NA_character_ else as.character(min(data$competencia[non_missing_idx])),
        last_period = if (length(non_missing_idx) == 0) NA_character_ else as.character(max(data$competencia[non_missing_idx])),
        n_states_with_data = if (length(non_missing_idx) == 0) 0L else dplyr::n_distinct(data$state_abbrev[non_missing_idx]),
        min_value = suppressWarnings(
          if (!is_numeric_series || length(non_missing_idx) == 0) NA_real_ else min(series[non_missing_idx], na.rm = TRUE)
        ),
        max_value = suppressWarnings(
          if (!is_numeric_series || length(non_missing_idx) == 0) NA_real_ else max(series[non_missing_idx], na.rm = TRUE)
        )
      )
    }
  ) |>
    dplyr::arrange(variable)
}

# spurious_header_index = 6 drops the bogus `id_usuario` header label so the
# va_icms_* value columns realign to their correct labels (see read_confaz_sheet).
setorial_sheet <- read_confaz_sheet(canonical_raw_path, "arrecadacao por setor ", spurious_header_index = 6)

setorial_numeric_cols <- c(
  "id_arrecadacao", "co_periodo", "ano2", "mes", "id_usuario",
  "va_icms_primario", "va_icms_secundario", "va_icms_terciario",
  "va_icms_terciario_atacadista", "va_icms_terciario_varejista",
  "va_icms_terciario_transportes", "va_icms_terciario_comunicacao",
  "va_icms_terciario_outros", "va_icms_energia", "va_icms_energia_secundario",
  "va_icms_energia_terciario", "va_icms_combustiveis", "va_icms_combustiveis_secundario",
  "va_icms_combustiveis_terciario", "va_icms_divida_ativa", "va_icms_outras",
  "va_icms_total", "va_outros_tributos_ipva", "va_outros_tributos_itcd",
  "va_outros_tributos_taxas", "va_outros_tributos_outros", "va_outros_tributos_total",
  "va_receita_tributaria_total"
)

setorial <- setorial_sheet$data |>
  dplyr::rename(
    state_abbrev = id_uf,
    year = ano2,
    month = mes
  ) |>
  dplyr::select(-dplyr::matches("^blank_col_"), -dplyr::matches("^coluna[1-4]$"), -dplyr::matches("^false$"), -dplyr::matches("^drop_extra_")) |>
  coerce_numeric_columns(setorial_numeric_cols) |>
  dplyr::mutate(
    state_abbrev = stringr::str_trim(as.character(state_abbrev)),
    co_periodo = suppressWarnings(as.integer(co_periodo)),
    year = suppressWarnings(as.integer(year)),
    month = suppressWarnings(as.integer(month))
  ) |>
  dplyr::left_join(
    uf_lookup |>
      dplyr::select(uf, state_abbrev, state_name, macroregion, include_in_panel),
    by = "state_abbrev"
  ) |>
  dplyr::mutate(
    competencia = sprintf("%04d%02d", year, month),
    period_date = as.Date(paste0(competencia, "01"), format = "%Y%m%d"),
    source_system = "confaz_boletim_tributos_estaduais",
    source_sheet = "arrecadacao_por_setor",
    source_file = basename(canonical_raw_path),
    source_series_version = "20260330",
    uf_mapping_status = dplyr::if_else(is.na(state_abbrev), "unmapped", "mapped")
  ) |>
  dplyr::arrange(period_date, uf)

setorial_processed_path <- file.path(path_data_processed, "confaz_state_tax_revenue_monthly_processed.csv")
setorial_panel_ready_path <- file.path(path_data_processed, "confaz_state_tax_revenue_monthly_panel_ready.csv")

setorial_panel_ready <- setorial |>
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
    va_icms_primario,
    va_icms_secundario,
    va_icms_terciario,
    va_icms_terciario_atacadista,
    va_icms_terciario_varejista,
    va_icms_terciario_transportes,
    va_icms_terciario_comunicacao,
    va_icms_terciario_outros,
    va_icms_energia,
    va_icms_energia_secundario,
    va_icms_energia_terciario,
    va_icms_combustiveis,
    va_icms_combustiveis_secundario,
    va_icms_combustiveis_terciario,
    va_icms_divida_ativa,
    va_icms_outras,
    va_icms_total,
    va_outros_tributos_ipva,
    va_outros_tributos_itcd,
    va_outros_tributos_taxas,
    va_outros_tributos_outros,
    va_outros_tributos_total,
    va_receita_tributaria_total,
    source_system,
    source_sheet,
    source_file,
    source_series_version
  )

setorial_coverage <- setorial_panel_ready |>
  dplyr::group_by(competencia, period_date, year, month) |>
  dplyr::summarise(
    n_states = dplyr::n_distinct(state_abbrev),
    rows = dplyr::n(),
    .groups = "drop"
  ) |>
  dplyr::arrange(period_date)

setorial_missing_summary <- build_variable_coverage(
  setorial_panel_ready,
  id_cols = c(
    "competencia", "period_date", "year", "month", "uf", "state_abbrev",
    "state_name", "macroregion", "source_system", "source_sheet",
    "source_file", "source_series_version"
  )
)

planilha1_sheet <- read_confaz_sheet(canonical_raw_path, "Planilha1")

planilha1 <- planilha1_sheet$data |>
  dplyr::rename(
    uf = id_uf,
    year = ano,
    month = mes
  ) |>
  dplyr::select(-dplyr::matches("^blank_col_")) |>
  dplyr::mutate(
    dplyr::across(
      -c(descricao_da_uf),
      ~ suppressWarnings(as.numeric(as.character(.x)))
    ),
    uf = as.integer(uf),
    co_periodo = as.integer(co_periodo),
    year = as.integer(year),
    month = as.integer(month)
  ) |>
  dplyr::left_join(uf_lookup, by = "uf") |>
  dplyr::mutate(
    competencia = sprintf("%04d%02d", year, month),
    period_date = as.Date(paste0(competencia, "01"), format = "%Y%m%d"),
    source_system = "confaz_boletim_tributos_estaduais",
    source_sheet = "planilha1",
    source_file = basename(canonical_raw_path),
    source_series_version = "20260330",
    uf_mapping_status = dplyr::if_else(is.na(state_abbrev), "unmapped", "mapped")
  ) |>
  dplyr::arrange(period_date, uf)

planilha1_processed_path <- file.path(path_data_processed, "confaz_state_tax_revenue_cnae_monthly_processed.csv")

planilha1_coverage <- planilha1 |>
  dplyr::filter(include_in_panel) |>
  dplyr::group_by(competencia, period_date, year, month) |>
  dplyr::summarise(
    n_states = dplyr::n_distinct(state_abbrev),
    rows = dplyr::n(),
    .groups = "drop"
  ) |>
  dplyr::arrange(period_date)

planilha1_missing_summary <- build_variable_coverage(
  planilha1 |>
    dplyr::filter(include_in_panel),
  id_cols = c(
    "descricao_da_uf", "competencia", "period_date", "year", "month", "uf", "state_abbrev",
    "state_name", "macroregion", "source_system", "source_sheet",
    "source_file", "source_series_version"
  )
)

registry <- tibble::tibble(
  source_file = basename(canonical_raw_path),
  source_path = canonical_raw_path,
  imported_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
  source_sheet = c("arrecadacao por setor ", "Planilha1"),
  metadata_line = c(
    as.character(setorial_sheet$metadata[[1, 1]]),
    as.character(planilha1_sheet$metadata[[1, 1]])
  ),
  first_period = c(
    min(setorial_panel_ready$competencia, na.rm = TRUE),
    min(planilha1$competencia[planilha1$include_in_panel], na.rm = TRUE)
  ),
  last_period = c(
    max(setorial_panel_ready$competencia, na.rm = TRUE),
    max(planilha1$competencia[planilha1$include_in_panel], na.rm = TRUE)
  ),
  rows_imported = c(nrow(setorial), nrow(planilha1)),
  rows_panel_ready = c(nrow(setorial_panel_ready), sum(planilha1$include_in_panel, na.rm = TRUE))
)

readr::write_csv(setorial, setorial_processed_path, na = "")
readr::write_csv(setorial_panel_ready, setorial_panel_ready_path, na = "")
readr::write_csv(planilha1, planilha1_processed_path, na = "")
readr::write_csv(registry, file.path(path_data_raw_confaz, "confaz_boletim_import_registry.csv"), na = "")

readr::write_csv(
  setorial_coverage,
  file.path(path_output, "validation", "confaz_state_tax_revenue_monthly_coverage.csv"),
  na = ""
)
readr::write_csv(
  setorial_missing_summary,
  file.path(path_output, "validation", "confaz_state_tax_revenue_monthly_missing_summary.csv"),
  na = ""
)
readr::write_csv(
  planilha1_coverage,
  file.path(path_output, "validation", "confaz_state_tax_revenue_cnae_monthly_coverage.csv"),
  na = ""
)
readr::write_csv(
  planilha1_missing_summary,
  file.path(path_output, "validation", "confaz_state_tax_revenue_cnae_monthly_missing_summary.csv"),
  na = ""
)

message("Saved processed CONFAZ setorial file: ", setorial_processed_path)
message("Saved CONFAZ panel-ready file: ", setorial_panel_ready_path)
message("Saved processed CONFAZ CNAE file: ", planilha1_processed_path)
