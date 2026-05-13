source(file.path("code", "01_download_data", "00_download_config.R"))

raw_mte_files <- list.files(
  path = path_data_raw_mte,
  pattern = "^CAGEDMOV[0-9]{6}\\.7z$",
  full.names = TRUE
)

if (length(raw_mte_files) == 0) {
  stop("No Novo Caged movement archives were found in ", path_data_raw_mte)
}

extract_single_archive <- function(archive_path) {
  archive_id <- tools::file_path_sans_ext(basename(archive_path))
  extract_dir <- file.path(path_data_raw_mte, archive_id)

  if (!dir.exists(extract_dir)) {
    dir.create(extract_dir, recursive = TRUE)
  }

  txt_files <- list.files(
    path = extract_dir,
    pattern = "\\.txt$",
    full.names = TRUE
  )

  if (length(txt_files) == 1) {
    return(txt_files[[1]])
  }

  archive::archive_extract(archive_path, dir = extract_dir)

  txt_files <- list.files(
    path = extract_dir,
    pattern = "\\.txt$",
    full.names = TRUE
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
    col_select = c(1, 3, 7),
    show_col_types = FALSE,
    progress = FALSE
  )

  names(raw_data) <- c("competencia_raw", "uf_raw", "saldo_raw")

  raw_data |>
    dplyr::mutate(
      competencia = as.character(competencia_raw),
      uf = stringr::str_pad(as.character(uf_raw), width = 2, side = "left", pad = "0"),
      saldo_movimentacao = as.numeric(saldo_raw)
    ) |>
    dplyr::group_by(competencia, uf) |>
    dplyr::summarise(
      formal_hiring_balance = sum(saldo_movimentacao, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      year = substr(competencia, 1, 4),
      month = substr(competencia, 5, 6),
      source_series = "novo_caged_mov"
    ) |>
    dplyr::select(
      competencia,
      year,
      month,
      uf,
      formal_hiring_balance,
      source_series
    )
}

state_balance_list <- lapply(raw_mte_files, function(archive_path) {
  txt_path <- extract_single_archive(archive_path)
  parse_single_txt(txt_path)
})

state_balance <- dplyr::bind_rows(state_balance_list) |>
  dplyr::arrange(competencia, uf)

output_path <- file.path(path_data_raw_mte, "novo_caged_state_balance_monthly.csv")
readr::write_csv(state_balance, output_path, na = "")

message("Saved parsed Novo Caged state balance file: ", output_path)
