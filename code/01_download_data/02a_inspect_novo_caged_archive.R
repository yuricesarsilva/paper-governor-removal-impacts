source(file.path("code", "01_download_data", "00_download_config.R"))

reference_month <- "2026-03"
reference_month_compact <- gsub("-", "", reference_month)

registry <- readr::read_csv(
  file.path(path_data_raw_mte, "caged_download_registry.csv"),
  show_col_types = FALSE
)

target_row <- registry |>
  dplyr::filter(series_block == paste0("new_caged_", gsub("-", "_", reference_month)))

if (nrow(target_row) != 1) {
  stop("Could not find a unique Novo Caged registry row for reference month ", reference_month)
}

archive_url <- target_row$source_url[[1]]
archive_path <- file.path(path_data_raw_mte, paste0("CAGEDMOV", reference_month_compact, ".7z"))
listing_path <- file.path(path_data_raw_mte, paste0("CAGEDMOV", reference_month_compact, "_contents.csv"))

old_timeout <- getOption("timeout")
on.exit(options(timeout = old_timeout), add = TRUE)
options(timeout = 600)

utils::download.file(
  url = archive_url,
  destfile = archive_path,
  mode = "wb",
  quiet = FALSE
)

archive_listing <- archive::archive(archive_path) |>
  janitor::clean_names()

readr::write_csv(archive_listing, listing_path, na = "")

message("Saved archive file: ", archive_path)
message("Saved archive listing: ", listing_path)
