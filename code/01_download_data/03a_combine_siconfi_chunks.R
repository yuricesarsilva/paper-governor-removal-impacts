source(file.path("code", "01_download_data", "00_download_config.R"))

chunk_prefix_glob <- Sys.getenv(
  "SICONFI_CHUNK_PREFIX_GLOB",
  unset = "siconfi_rreo_state_fiscal_bimonthly_????"
)

final_prefix <- Sys.getenv(
  "SICONFI_FINAL_OUTPUT_PREFIX",
  unset = "siconfi_rreo_state_fiscal_bimonthly"
)

path_data_raw_siconfi <- file.path(path_data_raw, "siconfi")

combine_csv_files <- function(files, output_path, key_cols = NULL) {
  if (length(files) == 0) {
    warning("No chunk files found for: ", output_path)
    return(invisible(NULL))
  }

  combined <- files |>
    purrr::map(readr::read_csv, show_col_types = FALSE) |>
    dplyr::bind_rows()

  if (!is.null(key_cols) && all(key_cols %in% names(combined))) {
    duplicate_count <- combined |>
      dplyr::count(dplyr::across(dplyr::all_of(key_cols)), name = "n") |>
      dplyr::filter(n > 1) |>
      nrow()

    if (duplicate_count > 0) {
      stop("Duplicated keys found while combining chunks for: ", output_path)
    }
  }

  readr::write_csv(combined, output_path, na = "")
  message("Saved combined file: ", output_path)

  invisible(combined)
}

processed_files <- Sys.glob(file.path(path_data_processed, paste0(chunk_prefix_glob, "_processed.csv")))
panel_ready_files <- Sys.glob(file.path(path_data_processed, paste0(chunk_prefix_glob, "_panel_ready.csv")))
registry_files <- Sys.glob(file.path(path_data_raw_siconfi, paste0(chunk_prefix_glob, "_download_registry.csv")))
annex01_files <- Sys.glob(file.path(path_data_raw_siconfi, paste0(chunk_prefix_glob, "_annex01_raw.csv")))
annex02_files <- Sys.glob(file.path(path_data_raw_siconfi, paste0(chunk_prefix_glob, "_annex02_raw.csv")))
annex06_files <- Sys.glob(file.path(path_data_raw_siconfi, paste0(chunk_prefix_glob, "_annex06_raw.csv")))

combine_csv_files(
  processed_files,
  file.path(path_data_processed, paste0(final_prefix, "_processed.csv")),
  key_cols = c("year", "bimester", "state_abbrev")
)

combine_csv_files(
  panel_ready_files,
  file.path(path_data_processed, paste0(final_prefix, "_panel_ready.csv")),
  key_cols = c("year", "bimester", "state_abbrev")
)

combine_csv_files(
  registry_files,
  file.path(path_data_raw_siconfi, paste0(final_prefix, "_download_registry.csv"))
)

combine_csv_files(
  annex01_files,
  file.path(path_data_raw_siconfi, paste0(final_prefix, "_annex01_raw.csv"))
)

combine_csv_files(
  annex02_files,
  file.path(path_data_raw_siconfi, paste0(final_prefix, "_annex02_raw.csv"))
)

combine_csv_files(
  annex06_files,
  file.path(path_data_raw_siconfi, paste0(final_prefix, "_annex06_raw.csv"))
)

message("Siconfi/RREO chunk combine script completed.")
