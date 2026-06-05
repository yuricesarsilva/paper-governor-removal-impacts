source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

extra_packages <- c("tidyr")
missing_extra <- extra_packages[!vapply(extra_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_extra) > 0) {
  stop("Missing required packages: ", paste(missing_extra, collapse = ", "))
}
invisible(lapply(extra_packages, library, character.only = TRUE))

base_panel_path <- file.path(path_data_processed, "caged_state_balance_monthly_panel_ready.csv")
integrity_path <- file.path(path_data_raw_mte, "old_caged_complete_integrity_7z.csv")
output_full_path <- file.path(path_data_processed, "caged_construction_state_balance_monthly_processed.csv")
output_panel_ready_path <- file.path(path_data_processed, "caged_construction_state_balance_monthly_panel_ready.csv")
output_coverage_path <- file.path(path_output, "validation", "caged_construction_monthly_coverage.csv")

if (!file.exists(base_panel_path)) {
  stop("Base CAGED panel not found: ", base_panel_path)
}

if (!file.exists(integrity_path)) {
  stop("Integrity inventory not found: ", integrity_path)
}

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

parse_number_br <- function(x) {
  x <- stringr::str_replace_all(as.character(x), "\\.", "")
  x <- stringr::str_replace_all(x, ",", ".")
  suppressWarnings(as.numeric(x))
}

is_construction_old <- function(x) {
  stringr::str_detect(as.character(x), "^(41|42|43)")
}

is_construction_novo <- function(section, subclass) {
  section_chr <- stringr::str_trim(as.character(section))
  subclass_chr <- as.character(subclass)

  section_chr == "F" | stringr::str_detect(subclass_chr, "^(41|42|43)")
}

parse_old_ok_archive <- function(archive_path) {
  extract_dir <- tempfile(pattern = "caged_construction_old_ok_")
  dir.create(extract_dir, recursive = TRUE)
  on.exit(unlink(extract_dir, recursive = TRUE, force = TRUE), add = TRUE)

  archive::archive_extract(archive_path, dir = extract_dir)

  txt_files <- list.files(
    path = extract_dir,
    pattern = "\\.txt$",
    full.names = TRUE,
    recursive = TRUE,
    ignore.case = TRUE
  )

  if (length(txt_files) != 1) {
    stop("Expected exactly one txt file inside ", archive_path, " but found ", length(txt_files))
  }

  raw_data <- readr::read_delim(
    file = txt_files[[1]],
    delim = ";",
    locale = readr::locale(encoding = "Latin1", decimal_mark = ","),
    col_select = c(2, 8, 18, 24),
    show_col_types = FALSE,
    progress = FALSE
  )

  names(raw_data) <- c("competencia_raw", "cnae20_subclasse_raw", "saldo_raw", "uf_raw")

  raw_data |>
    dplyr::transmute(
      competencia = as.character(.data$competencia_raw),
      uf = stringr::str_pad(as.character(.data$uf_raw), width = 2, side = "left", pad = "0"),
      cnae20_subclasse = as.character(.data$cnae20_subclasse_raw),
      saldo_movimentacao = as.numeric(.data$saldo_raw)
    ) |>
    dplyr::filter(
      grepl("^[0-9]{6}$", .data$competencia),
      grepl("^[0-9]{2}$", .data$uf),
      is_construction_old(.data$cnae20_subclasse),
      !is.na(.data$saldo_movimentacao)
    ) |>
    dplyr::group_by(.data$competencia, .data$uf) |>
    dplyr::summarise(
      formal_hiring_balance_construction = sum(.data$saldo_movimentacao, na.rm = TRUE),
      .groups = "drop"
    )
}

parse_old_failed_archive <- function(archive_path) {
  archive_file <- basename(archive_path)
  archive_id <- tools::file_path_sans_ext(archive_file)
  extract_dir <- tempfile(pattern = paste0("caged_construction_old_failed_", archive_id, "_"))
  dir.create(extract_dir, recursive = TRUE)
  on.exit(unlink(extract_dir, recursive = TRUE, force = TRUE), add = TRUE)

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
    stop("Failed to extract txt file from corrupt archive: ", archive_file)
  }

  lines <- readr::read_lines(
    file = txt_files[[1]],
    locale = readr::locale(encoding = "Latin1"),
    progress = FALSE
  )

  if (length(lines) < 2) {
    return(tibble::tibble())
  }

  header_fields <- stringr::str_count(lines[[1]], fixed(";")) + 1L
  data_lines <- lines[-1]
  field_counts <- stringr::str_count(data_lines, fixed(";")) + 1L
  complete_lines <- data_lines[field_counts == header_fields]

  if (length(complete_lines) == 0) {
    return(tibble::tibble())
  }

  parsed <- readr::read_delim(
    file = I(paste(complete_lines, collapse = "\n")),
    delim = ";",
    col_names = FALSE,
    locale = readr::locale(encoding = "Latin1", decimal_mark = ","),
    show_col_types = FALSE,
    progress = FALSE
  )

  parsed |>
    dplyr::transmute(
      competencia = as.character(.data$X2),
      uf = stringr::str_pad(as.character(.data$X24), width = 2, side = "left", pad = "0"),
      cnae20_subclasse = as.character(.data$X8),
      saldo_movimentacao = parse_number_br(.data$X18)
    ) |>
    dplyr::filter(
      grepl("^[0-9]{6}$", .data$competencia),
      grepl("^[0-9]{2}$", .data$uf),
      is_construction_old(.data$cnae20_subclasse),
      !is.na(.data$saldo_movimentacao)
    ) |>
    dplyr::group_by(.data$competencia, .data$uf) |>
    dplyr::summarise(
      formal_hiring_balance_construction = sum(.data$saldo_movimentacao, na.rm = TRUE),
      .groups = "drop"
    )
}

parse_novo_component_archive <- function(archive_path) {
  component <- stringr::str_extract(basename(archive_path), "^CAGED(MOV|FOR|EXC)")
  sign_multiplier <- if (component == "CAGEDEXC") -1 else 1

  extract_dir <- tempfile(pattern = "caged_construction_novo_")
  dir.create(extract_dir, recursive = TRUE)
  on.exit(unlink(extract_dir, recursive = TRUE, force = TRUE), add = TRUE)

  archive::archive_extract(archive_path, dir = extract_dir)

  txt_files <- list.files(
    path = extract_dir,
    pattern = "\\.txt$",
    full.names = TRUE,
    recursive = TRUE,
    ignore.case = TRUE
  )

  if (length(txt_files) != 1) {
    stop("Expected exactly one txt file inside ", archive_path, " but found ", length(txt_files))
  }

  raw_data <- readr::read_delim(
    file = txt_files[[1]],
    delim = ";",
    locale = readr::locale(encoding = "Latin1", decimal_mark = ","),
    col_select = c(1, 3, 5, 6, 7),
    show_col_types = FALSE,
    progress = FALSE
  )

  names(raw_data) <- c(
    "competencia_raw",
    "uf_raw",
    "section_raw",
    "subclass_raw",
    "saldo_raw"
  )

  raw_data |>
    dplyr::transmute(
      competencia = as.character(.data$competencia_raw),
      uf = stringr::str_pad(as.character(.data$uf_raw), width = 2, side = "left", pad = "0"),
      section = as.character(.data$section_raw),
      subclass = as.character(.data$subclass_raw),
      saldo_movimentacao = sign_multiplier * as.numeric(.data$saldo_raw)
    ) |>
    dplyr::filter(
      grepl("^[0-9]{6}$", .data$competencia),
      grepl("^[0-9]{2}$", .data$uf),
      is_construction_novo(.data$section, .data$subclass),
      !is.na(.data$saldo_movimentacao)
    ) |>
    dplyr::group_by(.data$competencia, .data$uf) |>
    dplyr::summarise(
      formal_hiring_balance_construction = sum(.data$saldo_movimentacao, na.rm = TRUE),
      .groups = "drop"
    )
}

base_panel <- readr::read_csv(base_panel_path, show_col_types = FALSE) |>
  dplyr::mutate(
    competencia = as.character(.data$competencia),
    uf = stringr::str_pad(as.character(.data$uf), width = 2, side = "left", pad = "0"),
    period_date = as.Date(.data$period_date)
  )

integrity_inventory <- readr::read_csv(integrity_path, show_col_types = FALSE) |>
  dplyr::mutate(archive_path = file.path(path_data_raw_mte, .data$file)) |>
  dplyr::filter(file.exists(.data$archive_path))

old_ok_paths <- integrity_inventory |>
  dplyr::filter(.data$integrity_status == "ok") |>
  dplyr::pull(.data$archive_path)

old_failed_paths <- integrity_inventory |>
  dplyr::filter(.data$integrity_status == "failed") |>
  dplyr::pull(.data$archive_path)

old_construction <- purrr::map_dfr(old_ok_paths, parse_old_ok_archive) |>
  dplyr::bind_rows(purrr::map_dfr(old_failed_paths, parse_old_failed_archive))

novo_paths <- list.files(
  path = path_data_raw_mte,
  pattern = "^CAGED(MOV|FOR|EXC)[0-9]{6}\\.7z$",
  full.names = TRUE
) 

novo_construction <- purrr::map_dfr(novo_paths, parse_novo_component_archive)

construction_raw <- dplyr::bind_rows(old_construction, novo_construction) |>
  dplyr::group_by(.data$competencia, .data$uf) |>
  dplyr::summarise(
    formal_hiring_balance_construction = sum(.data$formal_hiring_balance_construction, na.rm = TRUE),
    .groups = "drop"
  )

construction_panel <- base_panel |>
  dplyr::left_join(construction_raw, by = c("competencia", "uf")) |>
  dplyr::mutate(
    formal_hiring_balance_construction = dplyr::coalesce(.data$formal_hiring_balance_construction, 0L)
  ) |>
  dplyr::select(
    .data$competencia,
    .data$period_date,
    .data$year,
    .data$month,
    .data$uf,
    .data$state_abbrev,
    .data$state_name,
    .data$macroregion,
    .data$formal_hiring_balance_construction,
    .data$source_regime,
    .data$source_component,
    .data$post_2020_caged_dummy,
    .data$caged_method_break_dummy,
    .data$series_version
  ) |>
  dplyr::arrange(.data$period_date, .data$state_abbrev)

coverage <- construction_panel |>
  dplyr::group_by(.data$competencia) |>
  dplyr::summarise(
    n_ufs = dplyr::n_distinct(.data$state_abbrev),
    total_balance = sum(.data$formal_hiring_balance_construction, na.rm = TRUE),
    .groups = "drop"
  ) |>
  dplyr::arrange(.data$competencia)

if (nrow(coverage) != dplyr::n_distinct(base_panel$competencia)) {
  stop("Construction coverage does not match base CAGED monthly coverage.")
}

if (any(coverage$n_ufs != 27L)) {
  stop("Construction panel does not have 27 UFs in every competence.")
}

dir.create(dirname(output_coverage_path), recursive = TRUE, showWarnings = FALSE)

readr::write_csv(construction_panel, output_full_path, na = "")
readr::write_csv(construction_panel, output_panel_ready_path, na = "")
readr::write_csv(coverage, output_coverage_path, na = "")

message("Saved processed construction CAGED file: ", output_full_path)
message("Saved panel-ready construction CAGED file: ", output_panel_ready_path)
message("Saved construction coverage file: ", output_coverage_path)
