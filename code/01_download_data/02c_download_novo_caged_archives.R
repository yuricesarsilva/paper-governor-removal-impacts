source(file.path("code", "01_download_data", "00_download_config.R"))

registry_path <- file.path(path_data_raw_mte, "caged_download_registry.csv")

if (!file.exists(registry_path)) {
  stop("Registry file not found: ", registry_path)
}

registry <- readr::read_csv(registry_path, show_col_types = FALSE) |>
  dplyr::filter(source_type == "new_caged_ftp_archive") |>
  dplyr::filter(status == "ready_to_download") |>
  dplyr::mutate(
    archive_exists = file.exists(target_path)
  )

download_one_archive <- function(source_url, target_path, max_attempts = 3) {
  old_timeout <- getOption("timeout")
  on.exit(options(timeout = old_timeout), add = TRUE)
  options(timeout = 600)

  attempt <- 1
  last_error <- NULL

  while (attempt <= max_attempts) {
    last_error <- tryCatch(
      {
        utils::download.file(
          url = source_url,
          destfile = target_path,
          mode = "wb",
          quiet = FALSE
        )
        return(file.info(target_path)$size)
      },
      error = function(e) e
    )

    if (is.numeric(last_error)) {
      return(last_error)
    }

    if (file.exists(target_path)) {
      unlink(target_path)
    }

    message("Retry ", attempt, " failed for ", basename(target_path), ": ", last_error$message)
    Sys.sleep(2)
    attempt <- attempt + 1
  }

  stop(last_error$message)
}

download_results <- lapply(seq_len(nrow(registry)), function(i) {
  row <- registry[i, ]

  if (isTRUE(row$archive_exists[[1]])) {
    message("Skipping existing archive: ", basename(row$target_path[[1]]))
    return(tibble::tibble(
      series_block = row$series_block[[1]],
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
    series_block = row$series_block[[1]],
    target_path = row$target_path[[1]],
    status = result$status,
    bytes = result$bytes,
    error_message = result$error_message
  )
})

download_results <- dplyr::bind_rows(download_results)

results_path <- file.path(path_data_raw_mte, "novo_caged_download_results.csv")
readr::write_csv(download_results, results_path, na = "")

message("Saved download results: ", results_path)
