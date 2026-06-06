source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

caged_path <- file.path(path_data_processed, "caged_state_balance_monthly_panel_ready.csv")
full_caged_path <- file.path(path_data_processed, "caged_state_balance_monthly_processed.csv")

if (!file.exists(caged_path)) {
  stop("Input file not found: ", caged_path)
}

if (!file.exists(full_caged_path)) {
  stop("Input file not found: ", full_caged_path)
}

validation_dir <- path_output_validation
if (!dir.exists(validation_dir)) {
  dir.create(validation_dir, recursive = TRUE)
}

caged <- readr::read_csv(caged_path, show_col_types = FALSE) |>
  dplyr::mutate(
    competencia = as.character(competencia),
    period_date = as.Date(period_date),
    state_abbrev = as.character(state_abbrev),
    post_2020_caged_dummy = as.integer(post_2020_caged_dummy),
    caged_method_break_dummy = as.integer(caged_method_break_dummy)
  )

caged_full <- readr::read_csv(full_caged_path, show_col_types = FALSE) |>
  dplyr::mutate(
    competencia = as.character(competencia),
    period_date = as.Date(period_date),
    state_abbrev = as.character(state_abbrev)
  )

required_columns <- c(
  "competencia",
  "period_date",
  "year",
  "month",
  "uf",
  "state_abbrev",
  "state_name",
  "macroregion",
  "formal_hiring_balance",
  "source_regime",
  "source_component",
  "post_2020_caged_dummy",
  "caged_method_break_dummy",
  "series_version"
)

missing_columns <- setdiff(required_columns, names(caged))
if (length(missing_columns) > 0) {
  stop("Missing columns in final CAGED panel-ready file: ", paste(missing_columns, collapse = ", "))
}

duplicate_keys <- caged |>
  dplyr::count(competencia, state_abbrev, name = "n") |>
  dplyr::filter(n > 1)

if (nrow(duplicate_keys) > 0) {
  stop("Duplicated competencia x state_abbrev rows found in final CAGED panel-ready file")
}

expected_months <- seq.Date(
  from = as.Date("2007-01-01"),
  to = as.Date("2026-03-01"),
  by = "month"
)

expected_competencias <- format(expected_months, "%Y%m")
observed_competencias <- sort(unique(caged$competencia))
missing_competencias <- setdiff(expected_competencias, observed_competencias)
extra_competencias <- setdiff(observed_competencias, expected_competencias)

if (length(missing_competencias) > 0) {
  stop("Missing CAGED competencias: ", paste(missing_competencias, collapse = ", "))
}

if (length(extra_competencias) > 0) {
  stop("Unexpected CAGED competencias: ", paste(extra_competencias, collapse = ", "))
}

monthly_coverage <- caged |>
  dplyr::group_by(competencia, period_date, source_regime) |>
  dplyr::summarise(
    n_states = dplyr::n_distinct(state_abbrev),
    rows = dplyr::n(),
    total_balance = sum(formal_hiring_balance, na.rm = TRUE),
    .groups = "drop"
  ) |>
  dplyr::arrange(period_date)

bad_monthly_coverage <- monthly_coverage |>
  dplyr::filter(n_states != 27 | rows != 27)

if (nrow(bad_monthly_coverage) > 0) {
  stop("Some CAGED months do not have exactly 27 identified UFs")
}

expected_regime_by_month <- monthly_coverage |>
  dplyr::mutate(
    expected_source_regime = dplyr::if_else(
      period_date < as.Date("2020-01-01"),
      "old_caged",
      "novo_caged"
    ),
    source_regime_ok = source_regime == expected_source_regime
  )

if (any(!expected_regime_by_month$source_regime_ok)) {
  stop("Some CAGED months do not match the expected Old/Novo regime split")
}

dummy_check <- caged |>
  dplyr::mutate(
    expected_dummy = as.integer(period_date >= as.Date("2020-01-01")),
    dummy_ok = post_2020_caged_dummy == expected_dummy &
      caged_method_break_dummy == expected_dummy
  )

if (any(!dummy_check$dummy_ok)) {
  stop("CAGED break dummies are inconsistent with the January 2020 regime break")
}

uf_period_summary <- caged |>
  dplyr::mutate(
    validation_window = dplyr::case_when(
      period_date >= as.Date("2018-01-01") & period_date <= as.Date("2019-12-01") ~ "old_caged_2018_2019",
      period_date >= as.Date("2020-01-01") & period_date <= as.Date("2021-12-01") ~ "novo_caged_2020_2021",
      period_date >= as.Date("2022-01-01") & period_date <= as.Date("2023-12-01") ~ "novo_caged_2022_2023",
      TRUE ~ NA_character_
    )
  ) |>
  dplyr::filter(!is.na(validation_window)) |>
  dplyr::group_by(state_abbrev, state_name, validation_window) |>
  dplyr::summarise(
    months = dplyr::n(),
    mean_balance = mean(formal_hiring_balance, na.rm = TRUE),
    median_balance = stats::median(formal_hiring_balance, na.rm = TRUE),
    sd_balance = stats::sd(formal_hiring_balance, na.rm = TRUE),
    min_balance = min(formal_hiring_balance, na.rm = TRUE),
    max_balance = max(formal_hiring_balance, na.rm = TRUE),
    .groups = "drop"
  ) |>
  dplyr::arrange(state_abbrev, validation_window)

source_composition <- caged_full |>
  dplyr::count(source_regime, source_component, series_version, name = "rows") |>
  dplyr::arrange(source_regime, source_component)

validation_summary <- tibble::tibble(
  metric = c(
    "panel_ready_rows",
    "panel_ready_months",
    "first_competencia",
    "last_competencia",
    "min_states_per_month",
    "max_states_per_month",
    "old_caged_rows_panel_ready",
    "novo_caged_rows_panel_ready",
    "full_processed_rows",
    "full_processed_non_panel_rows",
    "duplicate_keys",
    "missing_competencias",
    "extra_competencias",
    "break_dummy_errors"
  ),
  value = as.character(c(
    nrow(caged),
    length(observed_competencias),
    min(caged$competencia),
    max(caged$competencia),
    min(monthly_coverage$n_states),
    max(monthly_coverage$n_states),
    sum(caged$source_regime == "old_caged"),
    sum(caged$source_regime == "novo_caged"),
    nrow(caged_full),
    nrow(caged_full) - nrow(caged),
    nrow(duplicate_keys),
    length(missing_competencias),
    length(extra_competencias),
    sum(!dummy_check$dummy_ok)
  ))
)

readr::write_csv(
  validation_summary,
  file.path(validation_dir, "caged_final_validation_summary.csv"),
  na = ""
)

readr::write_csv(
  monthly_coverage,
  file.path(validation_dir, "caged_final_monthly_coverage.csv"),
  na = ""
)

readr::write_csv(
  uf_period_summary,
  file.path(validation_dir, "caged_final_uf_pre_post_2020_summary.csv"),
  na = ""
)

readr::write_csv(
  source_composition,
  file.path(validation_dir, "caged_final_source_composition.csv"),
  na = ""
)

message("Final CAGED validation passed.")
message("Saved validation outputs to: ", validation_dir)
