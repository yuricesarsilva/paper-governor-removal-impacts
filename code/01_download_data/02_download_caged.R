source(file.path("code", "01_download_data", "00_download_config.R"))

# This script builds a download plan for the formal-employment series using
# official MTE sources. The project will keep the original source distinction
# between Old Caged and Novo Caged.

caged_reference_urls <- list(
  old_caged_landing = "https://www.gov.br/trabalho-e-emprego/pt-br/assuntos/estatisticas-trabalho/caged",
  new_caged_landing = "https://www.gov.br/trabalho-e-emprego/pt-br/assuntos/estatisticas-trabalho/novo-caged",
  microdata_landing = "https://www.gov.br/trabalho-e-emprego/pt-br/assuntos/estatisticas-trabalho/microdados-rais-e-caged",
  ftp_root = "ftp://ftp.mtps.gov.br/pdet/microdados/",
  ftp_novo_caged = "ftp://ftp.mtps.gov.br/pdet/microdados/NOVO%20CAGED/",
  ftp_novo_caged_layout = "ftp://ftp.mtps.gov.br/pdet/microdados/NOVO%20CAGED/Layout%20N%C3%A3o-identificado%20Novo%20Caged%20Movimenta%C3%A7%C3%A3o.xlsx",
  old_caged_tables_xls = "https://www.gov.br/trabalho-e-emprego/pt-br/assuntos/estatisticas-trabalho/caged/4-tabelas.xls",
  old_caged_municipal_balance_xls = "https://www.gov.br/trabalho-e-emprego/pt-br/assuntos/estatisticas-trabalho/caged/6-saldomunicipioajustado.xls"
)

list_ftp_entries <- function(url) {
  out <- system2("curl.exe", c("-s", "--list-only", shQuote(url)), stdout = TRUE, stderr = FALSE)
  out <- iconv(out, from = "", to = "UTF-8", sub = "")
  out <- trimws(out)
  out[nzchar(out)]
}

build_new_caged_link_registry <- function() {
  years <- list_ftp_entries(caged_reference_urls$ftp_novo_caged)
  years <- years[grepl("^20[0-9]{2}$", years)]

  registry <- purrr::map_dfr(years, function(year_value) {
    year_url <- paste0(caged_reference_urls$ftp_novo_caged, year_value, "/")
    competencies <- list_ftp_entries(year_url)
    competencies <- competencies[grepl(paste0("^", year_value, "[0-9]{2}$"), competencies)]

    purrr::map_dfr(competencies, function(comp_value) {
      month_url <- paste0(year_url, comp_value, "/")
      files <- list_ftp_entries(month_url)
      mov_file <- files[grepl(paste0("^CAGEDMOV", comp_value, "\\.7z$"), files)]
      exc_file <- files[grepl(paste0("^CAGEDEXC", comp_value, "\\.7z$"), files)]
      for_file <- files[grepl(paste0("^CAGEDFOR", comp_value, "\\.7z$"), files)]

      tibble::tibble(
        reference_month = paste0(substr(comp_value, 1, 4), "-", substr(comp_value, 5, 6)),
        ftp_month_url = month_url,
        movement_file = dplyr::if_else(length(mov_file) > 0, mov_file[1], NA_character_),
        exclusion_file = dplyr::if_else(length(exc_file) > 0, exc_file[1], NA_character_),
        fora_file = dplyr::if_else(length(for_file) > 0, for_file[1], NA_character_),
        movement_url = dplyr::if_else(length(mov_file) > 0, paste0(month_url, mov_file[1]), NA_character_),
        exclusion_url = dplyr::if_else(length(exc_file) > 0, paste0(month_url, exc_file[1]), NA_character_),
        fora_url = dplyr::if_else(length(for_file) > 0, paste0(month_url, for_file[1]), NA_character_),
        source_type = "new_caged_ftp_archive",
        status = dplyr::if_else(length(mov_file) > 0, "ready_to_download", "needs_manual_check")
      )
    })
  })

  registry
}

build_caged_download_registry <- function() {
  old_registry <- tibble::tribble(
    ~series_block, ~source_type, ~frequency, ~source_url, ~target_path, ~status, ~notes,
    "old_caged_tables", "old_caged_summary_xls", "monthly", caged_reference_urls$old_caged_tables_xls, file.path(path_data_raw_mte, "old_caged_tables_legacy.xls"), "ready_to_download", "Official old Caged tables workbook on gov.br",
    "old_caged_municipal_balance", "old_caged_adjusted_balance_xls", "monthly", caged_reference_urls$old_caged_municipal_balance_xls, file.path(path_data_raw_mte, "old_caged_adjusted_balance_legacy.xls"), "ready_to_download", "Official old Caged adjusted balance workbook on gov.br"
  )

  new_registry <- build_new_caged_link_registry() |>
    dplyr::transmute(
      series_block = paste0("new_caged_", gsub("-", "_", reference_month)),
      source_type,
      frequency = "monthly",
      source_url = movement_url,
      target_path = file.path(path_data_raw_mte, paste0("CAGEDMOV", gsub("-", "", reference_month), ".7z")),
      status,
      notes = paste("FTP month folder:", ftp_month_url)
    )

  dplyr::bind_rows(old_registry, new_registry)
}

download_binary_file <- function(url, destfile) {
  old_timeout <- getOption("timeout")
  on.exit(options(timeout = old_timeout), add = TRUE)
  options(timeout = 600)
  utils::download.file(url = url, destfile = destfile, mode = "wb", quiet = FALSE)
  message("Saved file: ", destfile)
}

write_link_registry <- function(registry) {
  output_path <- file.path(path_data_raw_mte, "caged_download_registry.csv")
  readr::write_csv(registry, output_path, na = "")
  message("Saved file: ", output_path)
}

download_old_caged_files <- function() {
  download_binary_file(
    caged_reference_urls$old_caged_tables_xls,
    file.path(path_data_raw_mte, "old_caged_tables_legacy.xls")
  )

  tryCatch(
    download_binary_file(
      caged_reference_urls$old_caged_municipal_balance_xls,
      file.path(path_data_raw_mte, "old_caged_adjusted_balance_legacy.xls")
    ),
    error = function(e) {
      message("Municipal adjusted balance workbook could not be fully downloaded: ", e$message)
      message("The script will keep the registry and the legacy summary workbook already downloaded.")
    }
  )
}

registry <- build_caged_download_registry()
write_link_registry(registry)
download_old_caged_files()

message("Caged download script completed for the currently automated legacy files.")
