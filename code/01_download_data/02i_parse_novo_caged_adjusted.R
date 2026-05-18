source(file.path("code", "01_download_data", "00_download_config.R"))

archive_paths <- list.files(
  path = path_data_raw_mte,
  pattern = "^CAGED(MOV|FOR|EXC)[0-9]{6}\\.7z$",
  full.names = TRUE
)

if (length(archive_paths) == 0) {
  stop("No Novo Caged MOV/FOR/EXC archives were found in ", path_data_raw_mte)
}

extract_single_archive <- function(archive_path) {
  extract_dir <- tempfile(pattern = "novo_caged_adjusted_")
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

parse_single_txt <- function(txt_path, component) {
  raw_data <- readr::read_delim(
    file = txt_path,
    delim = ";",
    locale = readr::locale(encoding = "Latin1", decimal_mark = ","),
    col_select = c(1, 3, 7),
    show_col_types = FALSE,
    progress = FALSE
  )

  names(raw_data) <- c("competencia_raw", "uf_raw", "saldo_raw")

  sign_multiplier <- if (component == "CAGEDEXC") -1 else 1

  raw_data |>
    dplyr::mutate(
      competencia = as.character(competencia_raw),
      uf = stringr::str_pad(as.character(uf_raw), width = 2, side = "left", pad = "0"),
      saldo_movimentacao = sign_multiplier * as.numeric(saldo_raw),
      source_component = dplyr::case_when(
        component == "CAGEDMOV" ~ "mov",
        component == "CAGEDFOR" ~ "for",
        component == "CAGEDEXC" ~ "exc",
        TRUE ~ component
      )
    ) |>
    dplyr::group_by(competencia, uf, source_component) |>
    dplyr::summarise(
      formal_hiring_balance = sum(saldo_movimentacao, na.rm = TRUE),
      .groups = "drop"
    ) |>
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
      source_component
    )
}

component_from_path <- function(archive_path) {
  stringr::str_extract(basename(archive_path), "^CAGED(MOV|FOR|EXC)")
}

component_balance_list <- lapply(archive_paths, function(archive_path) {
  component <- component_from_path(archive_path)
  message("Parsing archive: ", basename(archive_path))
  txt_path <- extract_single_archive(archive_path)
  on.exit(unlink(dirname(txt_path), recursive = TRUE, force = TRUE), add = TRUE)
  parse_single_txt(txt_path, component)
})

component_balance <- dplyr::bind_rows(component_balance_list) |>
  dplyr::arrange(competencia, uf, source_component)

component_output_path <- file.path(path_data_raw_mte, "novo_caged_adjusted_state_balance_monthly_components.csv")
readr::write_csv(component_balance, component_output_path, na = "")

state_balance <- component_balance |>
  dplyr::group_by(competencia, uf) |>
  dplyr::summarise(
    formal_hiring_balance = sum(formal_hiring_balance, na.rm = TRUE),
    year = dplyr::first(year),
    month = dplyr::first(month),
    source_series = "novo_caged_adjusted_mov_for_exc",
    .groups = "drop"
  ) |>
  dplyr::arrange(competencia, uf)

output_path <- file.path(path_data_raw_mte, "novo_caged_adjusted_state_balance_monthly.csv")
readr::write_csv(state_balance, output_path, na = "")

message("Saved component file: ", component_output_path)
message("Saved adjusted Novo Caged state balance file: ", output_path)
