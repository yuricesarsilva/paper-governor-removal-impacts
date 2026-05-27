source(file.path("code", "00_setup", "00_project_paths.R"))

stop(
  "The PNADc microdata route is suspended for now. ",
  "Use code/01_download_data/04_download_pnadc_sidra_quarterly.R instead."
)

required_packages <- c("PNADcIBGE", "survey", "readr", "dplyr", "purrr", "tibble", "tidyr", "stringr")

missing_packages <- required_packages[!vapply(
  required_packages,
  requireNamespace,
  logical(1),
  quietly = TRUE
)]

if (length(missing_packages) > 0) {
  stop(
    "Missing required packages for PNADc quarterly block: ",
    paste(missing_packages, collapse = ", ")
  )
}

invisible(lapply(required_packages, library, character.only = TRUE))

pnadc_raw_dir <- file.path(path_data_raw_ibge, "pnadc")
if (!dir.exists(pnadc_raw_dir)) {
  dir.create(pnadc_raw_dir, recursive = TRUE)
}

start_year <- as.integer(Sys.getenv("PNADC_START_YEAR", unset = "2025"))
start_quarter <- as.integer(Sys.getenv("PNADC_START_QUARTER", unset = "4"))
end_year <- as.integer(Sys.getenv("PNADC_END_YEAR", unset = as.character(start_year)))
end_quarter <- as.integer(Sys.getenv("PNADC_END_QUARTER", unset = as.character(start_quarter)))
reload <- tolower(Sys.getenv("PNADC_RELOAD", unset = "false")) %in% c("true", "1", "yes", "sim")

quarter_grid <- tidyr::expand_grid(
  year = seq.int(start_year, end_year),
  quarter = 1:4
) |>
  dplyr::filter(
    year * 10 + quarter >= start_year * 10 + start_quarter,
    year * 10 + quarter <= end_year * 10 + end_quarter
  ) |>
  dplyr::arrange(year, quarter)

if (nrow(quarter_grid) == 0) {
  stop("No PNADc quarters selected")
}

base_vars <- c(
  "Ano",
  "Trimestre",
  "UF",
  "VD4002",
  "VD4009",
  "V4019",
  "VD4020"
)

as_numeric_safely <- function(x) {
  if (is.factor(x)) {
    x <- as.character(x)
  }
  if (is.character(x)) {
    x <- gsub("\\.", "", x)
    x <- gsub(",", ".", x, fixed = TRUE)
  }
  suppressWarnings(as.numeric(x))
}

clean_svyby <- function(x, by_name = "UF") {
  x <- tibble::as_tibble(x)
  attr(x, "svyby") <- NULL
  names(x) <- gsub("^se\\.", "se_", names(x))
  x |>
    dplyr::rename(uf_label = dplyr::all_of(by_name))
}

process_one_quarter <- function(year, quarter) {
  message("Processing PNADc quarter: ", year, " Q", quarter)

  pnadc_design <- PNADcIBGE::get_pnadc(
    year = year,
    quarter = quarter,
    selected = FALSE,
    vars = base_vars,
    labels = TRUE,
    deflator = TRUE,
    design = TRUE,
    reload = reload,
    savedir = pnadc_raw_dir
  )

  available_vars <- names(pnadc_design$variables)

  required_vars <- c("UF", "VD4002", "VD4009", "V4019")
  missing_vars <- setdiff(required_vars, available_vars)
  if (length(missing_vars) > 0) {
    stop(
      "Missing required PNADc variables in ",
      year,
      " Q",
      quarter,
      ": ",
      paste(missing_vars, collapse = ", ")
    )
  }

  has_real_labor_income_vars <- all(c("VD4020", "Efetivo") %in% available_vars)

  if (has_real_labor_income_vars) {
    pnadc_design <- update(
      pnadc_design,
      VD4020_real = as.numeric(VD4020) * as.numeric(Efetivo)
    )
  } else {
    stop("VD4020 and/or Efetivo not found in ", year, " Q", quarter)
  }

  pnadc_design <- update(
    pnadc_design,
    person_count = 1,
    formal_occupied = as.numeric(
      VD4002 == "Pessoas ocupadas" &
        (
          VD4009 == "Empregado no setor privado com carteira de trabalho assinada" |
            VD4009 == "Trabalhador doméstico com carteira de trabalho assinada" |
            VD4009 == "Empregado no setor público com carteira de trabalho assinada" |
            VD4009 == "Militar e servidor estatutário" |
            (VD4009 == "Empregador" & V4019 == "Sim") |
            (VD4009 == "Conta-própria" & V4019 == "Sim")
        )
    ),
    informal_occupied = as.numeric(
      VD4002 == "Pessoas ocupadas" &
        (
          VD4009 == "Empregado no setor privado sem carteira de trabalho assinada" |
            VD4009 == "Trabalhador doméstico sem carteira de trabalho assinada" |
            VD4009 == "Empregado no setor público sem carteira de trabalho assinada" |
            VD4009 == "Trabalhador familiar auxiliar" |
            (VD4009 == "Empregador" & V4019 == "Não") |
            (VD4009 == "Conta-própria" & V4019 == "Não")
        )
    ),
    unemployed = as.numeric(VD4002 == "Pessoas desocupadas"),
    labor_force = as.numeric(VD4002 %in% c("Pessoas ocupadas", "Pessoas desocupadas"))
  )

  totals <- survey::svyby(
    ~person_count + formal_occupied + informal_occupied + unemployed + labor_force,
    ~UF,
    pnadc_design,
    survey::svytotal,
    na.rm = TRUE,
    vartype = "se",
    keep.names = FALSE
  ) |>
    clean_svyby()

  income_mean <- totals |>
    dplyr::transmute(
      uf_label,
      household_income_per_capita_source = NA_real_,
      se_household_income_per_capita_source = NA_real_
    )

  labor_income_mean <- survey::svyby(
    ~VD4020_real,
    ~UF,
    pnadc_design,
    survey::svymean,
    na.rm = TRUE,
    vartype = "se",
    keep.names = FALSE
  ) |>
    clean_svyby()

  result <- totals |>
    dplyr::left_join(income_mean, by = "uf_label") |>
    dplyr::left_join(labor_income_mean, by = "uf_label") |>
    dplyr::mutate(
      year = year,
      quarter = quarter,
      period = paste0(year, "Q", quarter),
      period_date = as.Date(sprintf("%d-%02d-01", year, (quarter - 1) * 3 + 1)),
      pnadc_population = person_count,
      formal_occupied_pnadc = formal_occupied,
      informal_occupied_pnadc = informal_occupied,
      classified_occupied_pnadc = formal_occupied + informal_occupied,
      unemployed_pnadc = unemployed,
      labor_force_pnadc = labor_force,
      formalization_rate_pnadc = dplyr::if_else(
        classified_occupied_pnadc > 0,
        formal_occupied_pnadc / classified_occupied_pnadc,
        NA_real_
      ),
      unemployment_rate_pnadc = dplyr::if_else(
        labor_force_pnadc > 0,
        unemployed_pnadc / labor_force_pnadc,
        NA_real_
      ),
      household_income_per_capita_pnadc = household_income_per_capita_source,
      labor_income_real_pnadc = VD4020_real,
      income_variable_used = "VD4020_real"
    ) |>
    dplyr::select(
      period,
      period_date,
      year,
      quarter,
      uf_label,
      pnadc_population,
      formal_occupied_pnadc,
      informal_occupied_pnadc,
      classified_occupied_pnadc,
      unemployed_pnadc,
      labor_force_pnadc,
      formalization_rate_pnadc,
      unemployment_rate_pnadc,
      household_income_per_capita_pnadc,
      labor_income_real_pnadc,
      income_variable_used,
      dplyr::starts_with("se_")
    )

  registry <- tibble::tibble(
    year = year,
    quarter = quarter,
    period = paste0(year, "Q", quarter),
    status = "processed",
    rows = nrow(result),
    income_variable_used = "VD4020_real",
    error_message = NA_character_
  )

  list(data = result, registry = registry)
}

quarter_results <- purrr::pmap(
  quarter_grid,
  function(year, quarter) {
    tryCatch(
      process_one_quarter(year, quarter),
      error = function(e) {
        list(
          data = tibble::tibble(),
          registry = tibble::tibble(
            year = year,
            quarter = quarter,
            period = paste0(year, "Q", quarter),
            status = "failed",
            rows = 0L,
            income_variable_used = NA_character_,
            error_message = conditionMessage(e)
          )
        )
      }
    )
  }
)

pnadc_processed <- purrr::map(quarter_results, "data") |>
  dplyr::bind_rows()

download_registry <- purrr::map(quarter_results, "registry") |>
  dplyr::bind_rows()

registry_path <- file.path(path_data_raw_ibge, "pnadc_quarterly_download_registry.csv")
processed_path <- file.path(path_data_processed, "pnadc_quarterly_state_covariates_processed.csv")
panel_ready_path <- file.path(path_data_processed, "pnadc_quarterly_state_covariates_panel_ready.csv")

readr::write_csv(download_registry, registry_path, na = "")

if (nrow(pnadc_processed) > 0) {
  readr::write_csv(pnadc_processed, processed_path, na = "")
  readr::write_csv(pnadc_processed, panel_ready_path, na = "")
  message("Saved PNADc processed file: ", processed_path)
  message("Saved PNADc panel-ready file: ", panel_ready_path)
} else {
  warning("No PNADc data processed successfully. See registry: ", registry_path)
}

message("Saved PNADc registry: ", registry_path)
