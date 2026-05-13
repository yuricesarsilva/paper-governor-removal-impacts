source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

download_start_month <- "2000-01"
download_end_month <- format(Sys.Date(), "%Y-%m")

sidra_tables <- list(
  pmc = list(
    table_id = 8880,
    description = "Retail sales volume and nominal revenue index for states",
    output_file = file.path(path_data_raw_ibge, "pmc_retail_index_monthly.csv")
  ),
  pms = list(
    table_id = 5906,
    description = "Services volume and nominal revenue index for states",
    output_file = file.path(path_data_raw_ibge, "pms_services_index_monthly.csv")
  ),
  ipca = list(
    table_id = 1737,
    description = "National CPI series for deflation",
    output_file = file.path(path_data_raw_ibge, "ipca_national_monthly.csv")
  )
)

write_raw_csv <- function(data, path) {
  readr::write_csv(data, path, na = "")
  message("Saved file: ", path)
}
