source(file.path("code", "01_download_data", "00_download_config.R"))

start_month <- Sys.getenv("CAGED_START_MONTH", unset = "2007-01")
end_month <- Sys.getenv("CAGED_END_MONTH", unset = "2019-12")

month_seq <- seq.Date(
  as.Date(paste0(start_month, "-01")),
  as.Date(paste0(end_month, "-01")),
  by = "month"
)

old_caged_registry <- tibble::tibble(
  competencia = format(month_seq, "%Y%m"),
  year = format(month_seq, "%Y"),
  file_name = paste0("CAGEDEST_", format(month_seq, "%m%Y"), ".7z"),
  source_url = paste0(
    "ftp://ftp.mtps.gov.br/pdet/microdados/CAGED/",
    year,
    "/",
    file_name
  ),
  target_path = file.path(path_data_raw_mte, file_name)
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
      shQuote(source_url),
      "--output",
      shQuote(target_path)
    ),
    stdout = TRUE,
    stderr = TRUE
  )
}

download_one_archive <- function(source_url, target_path, max_attempts = 3) {
  attempt <- 1

  while (attempt <= max_attempts) {
    result <- tryCatch(
      {
        curl_output <- download_with_curl(source_url, target_path)
        curl_status <- attr(curl_output, "status")

        if (!is.null(curl_status) && curl_status != 0) {
          stop("curl exited with status ", curl_status)
        }

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
      competencia = row$competencia[[1]],
      target_path = row$target_path[[1]],
      status = "already_present",
      bytes = file.info(row$target_path[[1]])$size,
      error_message = NA_character_
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
    competencia = row$competencia[[1]],
    target_path = row$target_path[[1]],
    status = result$status,
    bytes = result$bytes,
    error_message = result$error_message
  )
})

download_results <- dplyr::bind_rows(download_results)

output_path <- file.path(path_data_raw_mte, "old_caged_complete_download_results.csv")
readr::write_csv(download_results, output_path, na = "")

message("Saved download results: ", output_path)
