source(file.path("code", "01_download_data", "00_download_config.R"))

integrity_path <- file.path(path_data_raw_mte, "old_caged_complete_integrity_7z.csv")
bd_patch_path <- file.path(
  path_data_raw_mte,
  "old_caged_basedosdados_state_balance_monthly_failed_months.csv"
)
uf_lookup_path <- file.path(path_data_processed, "uf_code_lookup.csv")

if (!file.exists(integrity_path)) {
  stop("Integrity inventory not found: ", integrity_path)
}

if (!file.exists(bd_patch_path)) {
  stop("Base dos Dados patch not found: ", bd_patch_path)
}

if (!file.exists(uf_lookup_path)) {
  stop("UF lookup not found: ", uf_lookup_path)
}

integrity_inventory <- readr::read_csv(integrity_path, show_col_types = FALSE)

ok_archive_paths <- integrity_inventory |>
  dplyr::filter(integrity_status == "ok") |>
  dplyr::mutate(archive_path = file.path(path_data_raw_mte, file)) |>
  dplyr::filter(file.exists(archive_path)) |>
  dplyr::pull(archive_path)

if (length(ok_archive_paths) == 0) {
  stop("No integrity-ok complete Old Caged archives were found.")
}

extract_single_archive <- function(archive_path) {
  extract_dir <- tempfile(pattern = "old_caged_complete_ok_")
  dir.create(extract_dir, recursive = TRUE)

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

  txt_files[[1]]
}

parse_single_txt <- function(txt_path) {
  raw_data <- readr::read_delim(
    file = txt_path,
    delim = ";",
    locale = readr::locale(encoding = "Latin1", decimal_mark = ","),
    col_select = c(2, 18, 24),
    show_col_types = FALSE,
    progress = FALSE
  )

  names(raw_data) <- c("competencia_raw", "saldo_raw", "uf_raw")

  raw_data |>
    dplyr::mutate(
      competencia = as.character(competencia_raw),
      uf = stringr::str_pad(as.character(uf_raw), width = 2, side = "left", pad = "0"),
      saldo_movimentacao = as.numeric(saldo_raw)
    ) |>
    dplyr::filter(
      grepl("^[0-9]{6}$", competencia),
      grepl("^[0-9]{2}$", uf),
      !is.na(saldo_movimentacao)
    ) |>
    dplyr::group_by(competencia, uf) |>
    dplyr::summarise(
      formal_hiring_balance = sum(saldo_movimentacao, na.rm = TRUE),
      .groups = "drop"
    )
}

ftp_state_balance <- purrr::map_dfr(ok_archive_paths, function(archive_path) {
  message("Parsing integrity-ok archive: ", basename(archive_path))
  txt_path <- extract_single_archive(archive_path)
  on.exit(unlink(dirname(txt_path), recursive = TRUE, force = TRUE), add = TRUE)

  parse_single_txt(txt_path) |>
    dplyr::mutate(
      source_series = "old_caged_complete_ftp_integrity_ok",
      source_archive = basename(archive_path)
    )
})

uf_lookup <- readr::read_csv(uf_lookup_path, show_col_types = FALSE) |>
  dplyr::mutate(
    uf = stringr::str_pad(as.character(uf), width = 2, side = "left", pad = "0")
  ) |>
  dplyr::select(uf, state_abbrev)

bd_patch <- readr::read_csv(bd_patch_path, show_col_types = FALSE) |>
  dplyr::left_join(uf_lookup, by = "state_abbrev") |>
  dplyr::transmute(
    competencia = as.character(competencia),
    uf = stringr::str_pad(as.character(uf), width = 2, side = "left", pad = "0"),
    formal_hiring_balance = as.integer(formal_hiring_balance),
    source_series = "old_caged_basedosdados_microdados_antigos_patch",
    source_archive = NA_character_
  )

missing_patch_uf <- bd_patch |>
  dplyr::filter(is.na(uf))

if (nrow(missing_patch_uf) > 0) {
  stop("Base dos Dados patch has state abbreviations not mapped to UF codes.")
}

old_caged <- dplyr::bind_rows(ftp_state_balance, bd_patch) |>
  dplyr::mutate(
    year = substr(competencia, 1, 4),
    month = substr(competencia, 5, 6)
  ) |>
  dplyr::select(
    competencia,
    year,
    month,
    uf,
    formal_hiring_balance,
    source_series,
    source_archive
  ) |>
  dplyr::arrange(competencia, uf)

duplicates <- old_caged |>
  dplyr::count(competencia, uf) |>
  dplyr::filter(n > 1)

if (nrow(duplicates) > 0) {
  stop("Duplicated competencia x UF rows found in old Caged final build.")
}

coverage <- old_caged |>
  dplyr::group_by(competencia) |>
  dplyr::summarise(
    n_ufs = dplyr::n_distinct(uf),
    total_balance = sum(formal_hiring_balance, na.rm = TRUE),
    .groups = "drop"
  ) |>
  dplyr::arrange(competencia)

expected_months <- seq.Date(
  as.Date("2007-01-01"),
  as.Date("2019-12-01"),
  by = "month"
) |>
  format("%Y%m")

missing_months <- setdiff(expected_months, coverage$competencia)
incomplete_months <- coverage |>
  dplyr::filter(n_ufs != 27)

if (length(missing_months) > 0 || nrow(incomplete_months) > 0) {
  stop(
    "Old Caged final coverage is incomplete. Missing months: ",
    paste(missing_months, collapse = ", "),
    ". Incomplete months: ",
    paste(incomplete_months$competencia, collapse = ", ")
  )
}

output_path <- file.path(path_data_raw_mte, "old_caged_complete_state_balance_monthly.csv")
final_output_path <- file.path(path_data_raw_mte, "old_caged_complete_state_balance_monthly_final.csv")
coverage_output_path <- file.path(path_data_raw_mte, "old_caged_complete_state_balance_monthly_final_coverage.csv")

readr::write_csv(old_caged, output_path, na = "")
readr::write_csv(old_caged, final_output_path, na = "")
readr::write_csv(coverage, coverage_output_path, na = "")

message("Saved Old Caged complete final file: ", output_path)
message("Saved Old Caged complete final copy: ", final_output_path)
message("Saved Old Caged complete coverage file: ", coverage_output_path)
print(dplyr::count(old_caged, source_series))
