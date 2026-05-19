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

integrity_path <- file.path(path_data_raw_mte, "old_caged_complete_integrity_7z.csv")

if (!file.exists(integrity_path)) {
  stop("Integrity inventory not found: ", integrity_path)
}

salvage_dir <- file.path(path_data_raw_mte, "old_caged_complete_salvage")
dir.create(salvage_dir, recursive = TRUE, showWarnings = FALSE)

failed_archives <- readr::read_csv(integrity_path, show_col_types = FALSE) |>
  dplyr::filter(integrity_status == "failed") |>
  dplyr::mutate(
    archive_path = file.path(path_data_raw_mte, file)
  ) |>
  dplyr::filter(file.exists(archive_path))

if (nrow(failed_archives) == 0) {
  stop("No failed archives found in ", integrity_path)
}

parse_number_br <- function(x) {
  x <- stringr::str_replace_all(as.character(x), "\\.", "")
  x <- stringr::str_replace_all(x, ",", ".")
  suppressWarnings(as.numeric(x))
}

parse_salvaged_txt <- function(txt_path, archive_file) {
  lines <- readr::read_lines(
    file = txt_path,
    locale = readr::locale(encoding = "Latin1"),
    progress = FALSE
  )

  if (length(lines) < 2) {
    return(list(
      data = tibble::tibble(),
      report = tibble::tibble(
        file = archive_file,
        txt_file = basename(txt_path),
        txt_size_bytes = file.info(txt_path)$size,
        total_lines = length(lines),
        header_fields = NA_integer_,
        complete_data_lines = 0L,
        invalid_data_lines = max(length(lines) - 1L, 0L),
        valid_essential_lines = 0L,
        salvage_status = "empty_or_header_only"
      )
    ))
  }

  header_fields <- stringr::str_count(lines[[1]], fixed(";")) + 1L
  data_lines <- lines[-1]
  field_counts <- stringr::str_count(data_lines, fixed(";")) + 1L
  complete_lines <- data_lines[field_counts == header_fields]
  invalid_data_lines <- length(data_lines) - length(complete_lines)

  parsed <- readr::read_delim(
    file = I(paste(complete_lines, collapse = "\n")),
    delim = ";",
    col_names = FALSE,
    locale = readr::locale(encoding = "Latin1", decimal_mark = ","),
    show_col_types = FALSE,
    progress = FALSE
  )

  state_balance <- parsed |>
    dplyr::transmute(
      competencia = as.character(.data$X2),
      uf = stringr::str_pad(as.character(.data$X24), width = 2, side = "left", pad = "0"),
      saldo_movimentacao = parse_number_br(.data$X18)
    ) |>
    dplyr::filter(
      grepl("^[0-9]{6}$", competencia),
      grepl("^[0-9]{2}$", uf),
      !is.na(saldo_movimentacao)
    )

  report <- tibble::tibble(
    file = archive_file,
    txt_file = basename(txt_path),
    txt_size_bytes = file.info(txt_path)$size,
    total_lines = length(lines),
    header_fields = header_fields,
    complete_data_lines = length(complete_lines),
    invalid_data_lines = invalid_data_lines,
    valid_essential_lines = nrow(state_balance),
    salvage_status = "parsed"
  )

  aggregated <- state_balance |>
    dplyr::group_by(competencia, uf) |>
    dplyr::summarise(
      formal_hiring_balance = sum(saldo_movimentacao, na.rm = TRUE),
      salvaged_records = dplyr::n(),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      year = substr(competencia, 1, 4),
      month = substr(competencia, 5, 6),
      source_series = "old_caged_complete_salvaged_partial",
      source_archive = archive_file
    ) |>
    dplyr::select(
      competencia,
      year,
      month,
      uf,
      formal_hiring_balance,
      salvaged_records,
      source_series,
      source_archive
    )

  list(data = aggregated, report = report)
}

salvage_one_archive <- function(archive_path) {
  archive_file <- basename(archive_path)
  archive_id <- tools::file_path_sans_ext(archive_file)
  extract_dir <- file.path(salvage_dir, archive_id)

  if (dir.exists(extract_dir)) {
    unlink(extract_dir, recursive = TRUE, force = TRUE)
  }
  dir.create(extract_dir, recursive = TRUE)

  message("Salvaging archive: ", archive_file)

  extract_output <- system2(
    command = seven_zip_path,
    args = c("x", archive_path, paste0("-o", extract_dir), "-y"),
    stdout = TRUE,
    stderr = TRUE
  )

  extract_exit_code <- attr(extract_output, "status")
  if (is.null(extract_exit_code)) {
    extract_exit_code <- 0L
  }

  txt_files <- list.files(
    extract_dir,
    pattern = "\\.txt$",
    recursive = TRUE,
    full.names = TRUE,
    ignore.case = TRUE
  )

  if (length(txt_files) == 0) {
    unlink(extract_dir, recursive = TRUE, force = TRUE)
    return(list(
      data = tibble::tibble(),
      report = tibble::tibble(
        file = archive_file,
        txt_file = NA_character_,
        txt_size_bytes = NA_real_,
        total_lines = 0L,
        header_fields = NA_integer_,
        complete_data_lines = 0L,
        invalid_data_lines = 0L,
        valid_essential_lines = 0L,
        salvage_status = "no_txt_extracted",
        extract_exit_code = as.integer(extract_exit_code)
      )
    ))
  }

  parsed <- parse_salvaged_txt(txt_files[[1]], archive_file)
  parsed$report <- parsed$report |>
    dplyr::mutate(extract_exit_code = as.integer(extract_exit_code))

  unlink(extract_dir, recursive = TRUE, force = TRUE)
  parsed
}

salvage_results <- purrr::map(failed_archives$archive_path, salvage_one_archive)

salvaged_state_balance <- purrr::map_dfr(salvage_results, "data") |>
  dplyr::arrange(competencia, uf, source_archive)

salvage_report <- purrr::map_dfr(salvage_results, "report") |>
  dplyr::arrange(file)

state_balance_output_path <- file.path(
  path_data_raw_mte,
  "old_caged_complete_salvaged_state_balance_monthly.csv"
)

report_output_path <- file.path(
  path_data_raw_mte,
  "old_caged_complete_salvage_report.csv"
)

readr::write_csv(salvaged_state_balance, state_balance_output_path, na = "")
readr::write_csv(salvage_report, report_output_path, na = "")

message("Saved salvaged state balance file: ", state_balance_output_path)
message("Saved salvage report file: ", report_output_path)
