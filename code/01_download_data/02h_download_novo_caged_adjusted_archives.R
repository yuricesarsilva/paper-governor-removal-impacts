source(file.path("code", "01_download_data", "00_download_config.R"))

start_month <- Sys.getenv("CAGED_START_MONTH", unset = "2020-01")
end_month <- Sys.getenv("CAGED_END_MONTH", unset = "2026-03")
components <- c("CAGEDMOV", "CAGEDFOR", "CAGEDEXC")

month_seq <- seq.Date(
  as.Date(paste0(start_month, "-01")),
  as.Date(paste0(end_month, "-01")),
  by = "month"
)

novo_caged_registry <- tidyr::crossing(
  period_date = month_seq,
  component = components
) |>
  dplyr::mutate(
    competencia = format(period_date, "%Y%m"),
    year = format(period_date, "%Y"),
    file_name = paste0(component, competencia, ".7z"),
    source_url = paste0(
      "ftp://ftp.mtps.gov.br/pdet/microdados/NOVO%20CAGED/",
      year,
      "/",
      competencia,
      "/",
      file_name
    ),
    target_path = file.path(path_data_raw_mte, file_name),
    archive_exists = file.exists(target_path)
  )

download_with_curl <- function(source_url, target_path) {
  result <- system2(
    "curl.exe",
    c(
      "--disable-epsv",
      "--ftp-method", "nocwd",
      "--fail",
      "-L",
      shQuote(source_url),
      "--output",
      shQuote(target_path)
    ),
    stdout = TRUE,
    stderr = TRUE
  )

  status <- attr(result, "status")
  if (!is.null(status) && status != 0) {
    stop(paste(result, collapse = "\n"))
  }

  result
}

download_one_archive <- function(source_url, target_path, max_attempts = 2) {
  attempt <- 1

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

    message("Retry ", attempt, " failed for ", basename(target_path))
    Sys.sleep(2)
    attempt <- attempt + 1
  }

  stop(conditionMessage(result))
}

download_results <- lapply(seq_len(nrow(novo_caged_registry)), function(i) {
  row <- novo_caged_registry[i, ]

  if (isTRUE(row$archive_exists[[1]])) {
    message("Skipping existing archive: ", basename(row$target_path[[1]]))
    return(tibble::tibble(
      competencia = row$competencia[[1]],
      component = row$component[[1]],
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
      error_message <- conditionMessage(e)
      status <- if (grepl("550|404|The requested URL returned error", error_message)) {
        "not_available"
      } else {
        "download_failed"
      }
      list(status = status, bytes = NA_real_, error_message = error_message)
    }
  )

  tibble::tibble(
    competencia = row$competencia[[1]],
    component = row$component[[1]],
    target_path = row$target_path[[1]],
    status = result$status,
    bytes = result$bytes,
    error_message = result$error_message
  )
})

download_results <- dplyr::bind_rows(download_results)

output_path <- file.path(path_data_raw_mte, "novo_caged_adjusted_download_results.csv")
readr::write_csv(download_results, output_path, na = "")

message("Saved download results: ", output_path)
