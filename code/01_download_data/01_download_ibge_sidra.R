source(file.path("code", "01_download_data", "00_download_config.R"))

clean_sidra_result <- function(data) {
  data |>
    janitor::clean_names() |>
    dplyr::mutate(downloaded_at = Sys.Date())
}

download_pmc <- function() {
  message("Downloading PMC monthly state series from SIDRA table 8880")

  pmc_raw <- sidrar::get_sidra(
    api = "/t/8880/n3/all/v/7169/p/all/c11046/all"
  )

  pmc_clean <- clean_sidra_result(pmc_raw)
  write_raw_csv(pmc_clean, sidra_tables$pmc$output_file)
}

download_pms <- function() {
  message("Downloading PMS monthly state series from SIDRA table 5906")

  pms_raw <- sidrar::get_sidra(
    api = "/t/5906/n3/all/v/7167/p/all/c11046/all"
  )

  pms_clean <- clean_sidra_result(pms_raw)
  write_raw_csv(pms_clean, sidra_tables$pms$output_file)
}

download_ipca <- function() {
  message("Downloading IPCA monthly series from SIDRA table 1737")

  ipca_raw <- sidrar::get_sidra(
    api = "/t/1737/n1/1/v/2266/p/all"
  )

  ipca_clean <- clean_sidra_result(ipca_raw)
  write_raw_csv(ipca_clean, sidra_tables$ipca$output_file)
}

download_pmc()
download_pms()
download_ipca()

message("IBGE download script completed.")
