source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

extra_packages <- c("tidyr")
missing_extra <- extra_packages[!vapply(extra_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_extra) > 0) {
  stop("Missing required packages: ", paste(missing_extra, collapse = ", "))
}
invisible(lapply(extra_packages, library, character.only = TRUE))

raw_annex02_path <- file.path(
  path_data_raw_siconfi,
  "siconfi_rreo_state_fiscal_bimonthly_annex02_raw.csv"
)

processed_path <- file.path(
  path_data_processed,
  "siconfi_rreo_state_fiscal_bimonthly_processed.csv"
)

panel_ready_path <- file.path(
  path_data_processed,
  "siconfi_rreo_state_fiscal_bimonthly_panel_ready.csv"
)

audit_output_path <- file.path(
  root_dir,
  "output",
  "validation",
  "siconfi_rreo_total_expenditure_repair_audit.csv"
)

dir.create(dirname(audit_output_path), recursive = TRUE, showWarnings = FALSE)

normalize_text <- function(x) {
  x |>
    as.character() |>
    iconv(from = "", to = "ASCII//TRANSLIT") |>
    tolower() |>
    stringr::str_replace_all("[^a-z0-9]+", " ") |>
    stringr::str_squish()
}

extract_recovered_total_expenditure <- function(raw_path) {
  readr::read_csv(raw_path, show_col_types = FALSE) |>
    dplyr::mutate(
      year = as.integer(.data$exercicio),
      bimester = as.integer(.data$periodo),
      column_norm = normalize_text(.data$coluna),
      account_norm = normalize_text(.data$conta)
    ) |>
    dplyr::filter(
      .data$cod_conta == "RREO2TotalDespesas",
      .data$column_norm == "despesas liquidadas ate o bimestre d",
      stringr::str_detect(.data$account_norm, "^despesas exceto intra")
    ) |>
    dplyr::distinct(.data$uf, .data$year, .data$bimester, .keep_all = TRUE) |>
    dplyr::transmute(
      state_abbrev = .data$uf,
      year = .data$year,
      bimester = .data$bimester,
      recovered_total_expenditure_cumulative_nominal = as.numeric(.data$valor)
    ) |>
    dplyr::arrange(.data$state_abbrev, .data$year, .data$bimester) |>
    dplyr::group_by(.data$state_abbrev, .data$year) |>
    dplyr::mutate(
      recovered_total_expenditure_nominal =
        .data$recovered_total_expenditure_cumulative_nominal -
        dplyr::lag(.data$recovered_total_expenditure_cumulative_nominal, default = 0),
      recovered_total_expenditure_flow_is_derived = TRUE,
      recovered_total_expenditure_negative_flow_flag =
        .data$recovered_total_expenditure_nominal < 0
    ) |>
    dplyr::ungroup()
}

repair_panel <- function(panel, recovered) {
  if (!"original_liquidated_expenditure_total_missing" %in% names(panel)) {
    panel$original_liquidated_expenditure_total_missing <- is.na(panel$liquidated_expenditure_total_real)
  }
  if (!"liquidated_expenditure_total_recovered_from_raw" %in% names(panel)) {
    panel$liquidated_expenditure_total_recovered_from_raw <- FALSE
  }
  if (!"liquidated_expenditure_total_flow_is_derived" %in% names(panel)) {
    panel$liquidated_expenditure_total_flow_is_derived <- NA
  }
  if (!"liquidated_expenditure_total_negative_flow_flag" %in% names(panel)) {
    panel$liquidated_expenditure_total_negative_flow_flag <- NA
  }

  panel |>
    dplyr::mutate(
      original_liquidated_expenditure_total_missing =
        .data$original_liquidated_expenditure_total_missing |
        is.na(.data$liquidated_expenditure_total_real),
      expenditure_deflator_factor = dplyr::case_when(
        is.finite(.data$total_revenue_nominal) & .data$total_revenue_nominal != 0 ~
          .data$total_revenue_real / .data$total_revenue_nominal,
        is.finite(.data$state_tax_revenue_nominal) & .data$state_tax_revenue_nominal != 0 ~
          .data$state_tax_revenue_real / .data$state_tax_revenue_nominal,
        TRUE ~ NA_real_
      )
    ) |>
    dplyr::left_join(
      recovered,
      by = c("state_abbrev", "year", "bimester")
    ) |>
    dplyr::mutate(
      liquidated_expenditure_total_recovered_from_raw =
        .data$liquidated_expenditure_total_recovered_from_raw |
        (
          is.na(.data$liquidated_expenditure_total_real) &
          !is.na(.data$recovered_total_expenditure_nominal)
        ),
      liquidated_expenditure_total_nominal =
        dplyr::coalesce(
          .data$recovered_total_expenditure_nominal,
          .data$liquidated_expenditure_total_nominal
        ),
      liquidated_expenditure_total_flow_is_derived =
        dplyr::coalesce(
          .data$recovered_total_expenditure_flow_is_derived,
          .data$liquidated_expenditure_total_flow_is_derived
        ),
      liquidated_expenditure_total_negative_flow_flag =
        dplyr::coalesce(
          .data$recovered_total_expenditure_negative_flow_flag,
          .data$liquidated_expenditure_total_negative_flow_flag,
          FALSE
        ),
      liquidated_expenditure_total_real =
        dplyr::case_when(
          !is.na(.data$recovered_total_expenditure_nominal) &
            !is.na(.data$expenditure_deflator_factor) ~
            .data$recovered_total_expenditure_nominal * .data$expenditure_deflator_factor,
          TRUE ~ .data$liquidated_expenditure_total_real
        )
    ) |>
    dplyr::select(
      -dplyr::starts_with("recovered_total_expenditure_"),
      -expenditure_deflator_factor
    )
}

impute_total_expenditure_adjacent_mean <- function(panel) {
  if (!"liquidated_expenditure_total_imputed_adjacent_mean" %in% names(panel)) {
    panel$liquidated_expenditure_total_imputed_adjacent_mean <- FALSE
  }
  if (!"liquidated_expenditure_total_imputation_method" %in% names(panel)) {
    panel$liquidated_expenditure_total_imputation_method <- NA_character_
  }

  panel |>
    dplyr::arrange(.data$state_abbrev, .data$period_date) |>
    dplyr::group_by(.data$state_abbrev) |>
    dplyr::group_modify(
      function(.x, .y) {
        row_index <- seq_len(nrow(.x))
        missing_before <- is.na(.x$liquidated_expenditure_total_real)
        observed <- !missing_before

        imputed_real <- .x$liquidated_expenditure_total_real
        imputed_nominal <- .x$liquidated_expenditure_total_nominal

        if (sum(observed) >= 2) {
          imputed_real <- stats::approx(
            x = row_index[observed],
            y = .x$liquidated_expenditure_total_real[observed],
            xout = row_index,
            method = "linear",
            rule = 1,
            ties = "ordered"
          )$y

          nominal_observed <- !is.na(.x$liquidated_expenditure_total_nominal)
          if (sum(nominal_observed) >= 2) {
            imputed_nominal <- stats::approx(
              x = row_index[nominal_observed],
              y = .x$liquidated_expenditure_total_nominal[nominal_observed],
              xout = row_index,
              method = "linear",
              rule = 1,
              ties = "ordered"
            )$y
          }
        }

        newly_imputed_flag <- missing_before & !is.na(imputed_real)
        imputed_flag <- .x$liquidated_expenditure_total_imputed_adjacent_mean | newly_imputed_flag

        .x |>
          dplyr::mutate(
            liquidated_expenditure_total_real = imputed_real,
            liquidated_expenditure_total_nominal = imputed_nominal,
            liquidated_expenditure_total_imputed_adjacent_mean = imputed_flag,
            liquidated_expenditure_total_imputation_method = dplyr::case_when(
              newly_imputed_flag ~ "linear_interpolation_between_adjacent_observed_bimesters",
              TRUE ~ NA_character_
            ) |>
              dplyr::coalesce(.data$liquidated_expenditure_total_imputation_method),
            liquidated_expenditure_total_flow_is_derived = dplyr::case_when(
              imputed_flag ~ TRUE,
              TRUE ~ .data$liquidated_expenditure_total_flow_is_derived
            ),
            liquidated_expenditure_total_negative_flow_flag = dplyr::case_when(
              imputed_flag ~ .data$liquidated_expenditure_total_nominal < 0,
              TRUE ~ .data$liquidated_expenditure_total_negative_flow_flag
            )
          )
      }
    ) |>
    dplyr::ungroup()
}

recovered <- extract_recovered_total_expenditure(raw_annex02_path)

processed <- readr::read_csv(processed_path, show_col_types = FALSE)
panel_ready <- readr::read_csv(panel_ready_path, show_col_types = FALSE)

processed_repaired <- repair_panel(processed, recovered) |>
  impute_total_expenditure_adjacent_mean()
panel_ready_repaired <- repair_panel(panel_ready, recovered) |>
  impute_total_expenditure_adjacent_mean()

audit <- panel_ready_repaired |>
  dplyr::group_by(.data$year) |>
  dplyr::summarise(
    rows = dplyr::n(),
    total_expenditure_missing_after_repair = sum(is.na(.data$liquidated_expenditure_total_real)),
    total_expenditure_recovered_from_raw =
      sum(.data$liquidated_expenditure_total_recovered_from_raw, na.rm = TRUE),
    total_expenditure_imputed_adjacent_mean =
      sum(.data$liquidated_expenditure_total_imputed_adjacent_mean, na.rm = TRUE),
    negative_total_expenditure_flows =
      sum(.data$liquidated_expenditure_total_negative_flow_flag, na.rm = TRUE),
    .groups = "drop"
  )

readr::write_csv(processed_repaired, processed_path, na = "")
readr::write_csv(panel_ready_repaired, panel_ready_path, na = "")
readr::write_csv(audit, audit_output_path, na = "")

message("Siconfi/RREO total expenditure repair completed.")
message(
  "Recovered rows: ",
  sum(panel_ready_repaired$liquidated_expenditure_total_recovered_from_raw, na.rm = TRUE)
)
message(
  "Imputed rows: ",
  sum(panel_ready_repaired$liquidated_expenditure_total_imputed_adjacent_mean, na.rm = TRUE)
)
message(
  "Remaining missing total expenditure rows: ",
  sum(is.na(panel_ready_repaired$liquidated_expenditure_total_real))
)
message("Audit saved to: ", audit_output_path)
