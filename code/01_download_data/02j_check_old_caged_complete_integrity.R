source(file.path("code", "01_download_data", "00_download_config.R"))

seven_zip_path <- Sys.getenv("SEVEN_ZIP_PATH", unset = "")

if (!nzchar(seven_zip_path)) {
  candidate_paths <- c(
    "C:/Program Files/7-Zip/7z.exe",
    "C:/Program Files (x86)/7-Zip/7z.exe",
    "C:/Program Files/AMD/CIM/Bin64/7z.exe"
  )

  seven_zip_path <- candidate_paths[file.exists(candidate_paths)][1]
}

if (is.na(seven_zip_path) || !file.exists(seven_zip_path)) {
  stop(
    "7z.exe was not found. Set SEVEN_ZIP_PATH to the full path of 7z.exe ",
    "and rerun this script."
  )
}

archive_paths <- list.files(
  path = path_data_raw_mte,
  pattern = "^CAGEDEST_[0-9]{6}\\.7z$",
  full.names = TRUE
)

if (length(archive_paths) == 0) {
  stop("No complete Old Caged archives were found in ", path_data_raw_mte)
}

test_single_archive <- function(archive_path) {
  message("Testing archive: ", basename(archive_path))

  output <- system2(
    command = seven_zip_path,
    args = c("t", archive_path),
    stdout = TRUE,
    stderr = TRUE
  )

  exit_code <- attr(output, "status")
  if (is.null(exit_code)) {
    exit_code <- 0L
  }

  diagnostic <- output[
    grepl("Everything is Ok|ERROR|Error|Unexpected end|Data Error|Headers Error",
      output,
      ignore.case = FALSE
    )
  ]

  tibble::tibble(
    file = basename(archive_path),
    size_bytes = file.info(archive_path)$size,
    test_exit_code = as.integer(exit_code),
    integrity_status = dplyr::if_else(exit_code == 0L, "ok", "failed"),
    diagnostic = paste(diagnostic, collapse = " | ")
  )
}

integrity_results <- purrr::map_dfr(sort(archive_paths), test_single_archive)

output_path <- file.path(
  path_data_raw_mte,
  "old_caged_complete_integrity_7z.csv"
)

readr::write_csv(integrity_results, output_path, na = "")

message("Saved Old Caged integrity inventory: ", output_path)
print(dplyr::count(integrity_results, integrity_status))
