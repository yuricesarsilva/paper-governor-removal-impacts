source(file.path("code", "01_download_data", "00_download_config.R"))

old_caged_registry <- c(
  paste0(
    "ftp://ftp.mtps.gov.br/pdet/microdados/CAGED_AJUSTES/2002a2009/CAGEDEST_AJUSTES_",
    2007:2009,
    ".7z"
  ),
  unlist(lapply(2010:2019, function(year_value) {
    sprintf(
      "ftp://ftp.mtps.gov.br/pdet/microdados/CAGED_AJUSTES/%d/CAGEDEST_AJUSTES_%02d%d.7z",
      year_value,
      1:12,
      year_value
    )
  }))
)

old_caged_registry <- tibble::tibble(
  source_url = old_caged_registry,
  target_path = file.path(path_data_raw_mte, basename(old_caged_registry))
) |>
  dplyr::mutate(
    archive_exists = file.exists(target_path)
  )

download_with_curl <- function(source_url, target_path) {
  system2(
    "curl.exe",
    c(
      "--disable-epsv",
      "--ftp-method", "nocwd",
      "-L",
      source_url,
      "--output",
      target_path
    ),
    stdout = TRUE,
    stderr = TRUE
  )
}

download_one_archive <- function(source_url, target_path, max_attempts = 3) {
  attempt <- 1
  last_status <- NULL

  while (attempt <= max_attempts) {
    result <- tryCatch(
      {
        download_with_curl(source_url, target_path)
        file.info(target_path)$size
      },
      error = function(e) e
    )

    if (is.numeric(result) && !is.na(result) && result > 0) {
      return(result)
    }

    if (file.exists(target_path)) {
      unlink(target_path)
    }

    last_status <- result
    message("Retry ", attempt, " failed for ", basename(target_path))
    Sys.sleep(2)
    attempt <- attempt + 1
  }

  stop("Download failed for ", basename(target_path))
}

download_results <- lapply(seq_len(nrow(old_caged_registry)), function(i) {
  row <- old_caged_registry[i, ]

  if (isTRUE(row$archive_exists[[1]])) {
    message("Skipping existing archive: ", basename(row$target_path[[1]]))
    return(tibble::tibble(
      target_path = row$target_path[[1]],
      status = "already_present",
      bytes = file.info(row$target_path[[1]])$size
    ))
  }

  message("Downloading archive: ", basename(row$target_path[[1]]))

  result <- tryCatch(
    {
      bytes <- download_one_archive(row$source_url[[1]], row$target_path[[1]])
      list(status = "downloaded", bytes = bytes, error_message = NA_character_)
    },
    error = function(e) {
      list(status = "download_failed", bytes = NA_real_, error_message = conditionMessage(e))
    }
  )

  tibble::tibble(
    target_path = row$target_path[[1]],
    status = result$status,
    bytes = result$bytes,
    error_message = result$error_message
  )
})

download_results <- dplyr::bind_rows(download_results)

output_path <- file.path(path_data_raw_mte, "old_caged_adjusted_download_results.csv")
readr::write_csv(download_results, output_path, na = "")

message("Saved download results: ", output_path)
