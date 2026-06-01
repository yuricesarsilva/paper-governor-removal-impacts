source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

extra_packages <- c("tidyr")
missing_extra <- extra_packages[!vapply(extra_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_extra) > 0) {
  stop("Missing required packages: ", paste(missing_extra, collapse = ", "))
}
invisible(lapply(extra_packages, library, character.only = TRUE))

raw_annex06_path <- file.path(
  path_data_raw_siconfi,
  "siconfi_rreo_state_fiscal_bimonthly_annex06_raw.csv"
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
  "siconfi_rreo_investment_repair_audit.csv"
)

dir.create(dirname(audit_output_path), recursive = TRUE, showWarnings = FALSE)

extract_recovered_investment <- function(raw_path) {
  readr::read_csv(raw_path, show_col_types = FALSE) |>
    dplyr::mutate(
      year = as.integer(.data$exercicio),
      bimester = as.integer(.data$periodo),
      column_lower = stringr::str_to_lower(stringr::str_squish(.data$coluna))
    ) |>
    dplyr::filter(
      .data$cod_conta == "RREO6Investimentos",
      stringr::str_detect(.data$column_lower, "despesas liquidadas"),
      .data$column_lower == "despesas liquidadas" |
        stringr::str_detect(.data$column_lower, paste0("/ ", .data$year, "$"))
    ) |>
    dplyr::distinct(.data$uf, .data$year, .data$bimester, .keep_all = TRUE) |>
    dplyr::transmute(
      state_abbrev = .data$uf,
      year = .data$year,
      bimester = .data$bimester,
      recovered_investment_cumulative_nominal = as.numeric(.data$valor)
    ) |>
    dplyr::arrange(.data$state_abbrev, .data$year, .data$bimester) |>
    dplyr::group_by(.data$state_abbrev, .data$year) |>
    dplyr::mutate(
      recovered_investment_nominal =
        .data$recovered_investment_cumulative_nominal -
        dplyr::lag(.data$recovered_investment_cumulative_nominal, default = 0),
      recovered_investment_flow_is_derived = TRUE,
      recovered_investment_negative_flow_flag = .data$recovered_investment_nominal < 0
    ) |>
    dplyr::ungroup()
}

repair_panel <- function(panel, recovered) {
  if (!"investment_recovered_from_raw" %in% names(panel)) {
    panel$investment_recovered_from_raw <- FALSE
  }
  if (!"original_public_investment_missing" %in% names(panel)) {
    panel$original_public_investment_missing <- is.na(panel$public_investment_liquidated_real)
  }

  panel |>
    dplyr::mutate(
      original_public_investment_missing =
        .data$original_public_investment_missing |
        is.na(.data$public_investment_liquidated_real),
      investment_deflator_factor = dplyr::case_when(
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
      investment_recovered_from_raw =
        .data$investment_recovered_from_raw |
        (
          is.na(.data$public_investment_liquidated_real) &
          !is.na(.data$recovered_investment_nominal)
        ),
      public_investment_liquidated_cumulative_nominal =
        dplyr::coalesce(
          .data$recovered_investment_cumulative_nominal,
          .data$public_investment_liquidated_cumulative_nominal
        ),
      public_investment_liquidated_nominal =
        dplyr::coalesce(
          .data$recovered_investment_nominal,
          .data$public_investment_liquidated_nominal
        ),
      public_investment_flow_is_derived =
        dplyr::coalesce(
          .data$recovered_investment_flow_is_derived,
          .data$public_investment_flow_is_derived
        ),
      public_investment_negative_flow_flag =
        dplyr::coalesce(
          .data$recovered_investment_negative_flow_flag,
          .data$public_investment_negative_flow_flag,
          FALSE
        ),
      public_investment_liquidated_real =
        dplyr::case_when(
          !is.na(.data$recovered_investment_nominal) &
            !is.na(.data$investment_deflator_factor) ~
            .data$recovered_investment_nominal * .data$investment_deflator_factor,
          TRUE ~ .data$public_investment_liquidated_real
        )
    ) |>
    dplyr::select(
      -dplyr::starts_with("recovered_investment_"),
      -investment_deflator_factor
    )
}

impute_investment_adjacent_mean <- function(panel) {
  if (!"public_investment_imputed_adjacent_mean" %in% names(panel)) {
    panel$public_investment_imputed_adjacent_mean <- FALSE
  }
  if (!"public_investment_imputation_method" %in% names(panel)) {
    panel$public_investment_imputation_method <- NA_character_
  }

  panel |>
    dplyr::arrange(.data$state_abbrev, .data$period_date) |>
    dplyr::group_by(.data$state_abbrev) |>
    dplyr::group_modify(
      function(.x, .y) {
        row_index <- seq_len(nrow(.x))
        missing_before <- is.na(.x$public_investment_liquidated_real)
        observed <- !missing_before

        imputed_real <- .x$public_investment_liquidated_real
        imputed_nominal <- .x$public_investment_liquidated_nominal

        if (sum(observed) >= 2) {
          imputed_real <- stats::approx(
            x = row_index[observed],
            y = .x$public_investment_liquidated_real[observed],
            xout = row_index,
            method = "linear",
            rule = 1,
            ties = "ordered"
          )$y

          nominal_observed <- !is.na(.x$public_investment_liquidated_nominal)
          if (sum(nominal_observed) >= 2) {
            imputed_nominal <- stats::approx(
              x = row_index[nominal_observed],
              y = .x$public_investment_liquidated_nominal[nominal_observed],
              xout = row_index,
              method = "linear",
              rule = 1,
              ties = "ordered"
            )$y
          }
        }

        newly_imputed_flag <- missing_before & !is.na(imputed_real)
        imputed_flag <- .x$public_investment_imputed_adjacent_mean | newly_imputed_flag

        .x |>
          dplyr::mutate(
            public_investment_liquidated_real = imputed_real,
            public_investment_liquidated_nominal = imputed_nominal,
            public_investment_imputed_adjacent_mean = imputed_flag,
            public_investment_imputation_method = dplyr::case_when(
              newly_imputed_flag ~ "linear_interpolation_between_adjacent_observed_bimesters",
              TRUE ~ NA_character_
            ) |>
              dplyr::coalesce(.data$public_investment_imputation_method),
            public_investment_flow_is_derived = dplyr::case_when(
              imputed_flag ~ TRUE,
              TRUE ~ .data$public_investment_flow_is_derived
            ),
            public_investment_negative_flow_flag = dplyr::case_when(
              imputed_flag ~ .data$public_investment_liquidated_nominal < 0,
              TRUE ~ .data$public_investment_negative_flow_flag
            )
          )
      }
    ) |>
    dplyr::ungroup()
}

recovered <- extract_recovered_investment(raw_annex06_path)

processed <- readr::read_csv(processed_path, show_col_types = FALSE)
panel_ready <- readr::read_csv(panel_ready_path, show_col_types = FALSE)

processed_repaired <- repair_panel(processed, recovered) |>
  impute_investment_adjacent_mean()
panel_ready_repaired <- repair_panel(panel_ready, recovered) |>
  impute_investment_adjacent_mean()

audit <- panel_ready_repaired |>
  dplyr::group_by(.data$year) |>
  dplyr::summarise(
    rows = dplyr::n(),
    investment_missing_after_repair = sum(is.na(.data$public_investment_liquidated_real)),
    investment_recovered_from_raw = sum(.data$investment_recovered_from_raw, na.rm = TRUE),
    investment_imputed_adjacent_mean = sum(.data$public_investment_imputed_adjacent_mean, na.rm = TRUE),
    negative_investment_flows = sum(.data$public_investment_negative_flow_flag, na.rm = TRUE),
    .groups = "drop"
  )

readr::write_csv(processed_repaired, processed_path, na = "")
readr::write_csv(panel_ready_repaired, panel_ready_path, na = "")
readr::write_csv(audit, audit_output_path, na = "")

message("Siconfi/RREO investment repair completed.")
message("Recovered rows: ", sum(panel_ready_repaired$investment_recovered_from_raw, na.rm = TRUE))
message("Imputed rows: ", sum(panel_ready_repaired$public_investment_imputed_adjacent_mean, na.rm = TRUE))
message("Remaining missing investment rows: ", sum(is.na(panel_ready_repaired$public_investment_liquidated_real)))
message("Audit saved to: ", audit_output_path)
