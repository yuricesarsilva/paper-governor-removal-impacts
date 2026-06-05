source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

pilot_id <- "am_2017_01_v1"
pilot_root <- file.path(root_dir, "pilots", pilot_id)
data_dir <- file.path(pilot_root, "data")
output_root <- file.path(pilot_root, "output")
report_dir <- file.path(pilot_root, "report")
figure_dir <- file.path(report_dir, "figures")
table_dir <- file.path(report_dir, "tables")
notes_dir <- file.path(pilot_root, "notes")

dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(notes_dir, recursive = TRUE, showWarnings = FALSE)

event <- readr::read_csv(
  file.path(data_dir, "am_2017_01_v1_event_metadata.csv"),
  show_col_types = FALSE
) |>
  dplyr::slice(1)

treated_st     <- event$state_abbrev[[1]]
state_name_val <- event$state_name[[1]]

fiscal_panel <- readr::read_csv(
  file.path(data_dir, "am_2017_01_v1_bimonthly_fiscal_panel.csv"),
  show_col_types = FALSE
) |>
  dplyr::mutate(period_date = as.Date(.data$period_date))

quarterly_panel <- readr::read_csv(
  file.path(data_dir, "am_2017_01_v1_quarterly_pnadc_panel.csv"),
  show_col_types = FALSE
) |>
  dplyr::mutate(period_date = as.Date(.data$period_date))

summary_tbl <- readr::read_csv(
  file.path(output_root, "am_2017_01_v1_scm_summary.csv"),
  show_col_types = FALSE
)

format_num <- function(x, digits = 2) {
  ifelse(is.na(x), "", format(round(x, digits), nsmall = digits, big.mark = ","))
}

make_slug <- function(x) {
  x |>
    stringr::str_replace_all("[^A-Za-z0-9]+", "_") |>
    stringr::str_replace_all("_+$", "") |>
    tolower()
}

make_markdown_table <- function(data) {
  if (nrow(data) == 0) {
    return(character(0))
  }
  header <- paste0("| ", paste(names(data), collapse = " | "), " |")
  separator <- paste0("| ", paste(rep("---", ncol(data)), collapse = " | "), " |")
  rows <- apply(data, 1, function(row) paste0("| ", paste(row, collapse = " | "), " |"))
  c(header, separator, rows)
}

figure_link <- function(filename) {
  paste0("![", filename, "](report/figures/", filename, ")")
}

outcome_meta <- tibble::tribble(
  ~outcome, ~label, ~channel, ~subblock, ~preferred,
  "formal_hiring_balance_per_100k_wap", "Formal hiring balance per 100k working-age population", "Formal labor market", NA_character_, FALSE,
  "formal_hiring_balance_construction_per_100k_wap", "Construction hiring balance per 100k working-age population", "Formal labor market", NA_character_, FALSE,
  "retail_volume_index", "Retail volume index", "Household consumption", NA_character_, FALSE,
  "services_volume_index", "Services volume index", "Household consumption", NA_character_, FALSE,
  "state_tax_revenue_real_pc", "Own tax revenue, real per capita", "State public finances", "revenues", TRUE,
  "icms_revenue_real_pc", "ICMS revenue, real per capita", "State public finances", "revenues", TRUE,
  "public_investment_liquidated_real_pc", "Public investment, liquidated, real per capita", "State public finances", "expenditures", TRUE,
  "liquidated_expenditure_total_real_pc", "Total liquidated expenditure, real per capita", "State public finances", "expenditures", TRUE,
  "formal_hiring_balance_per_100k_wap_ma6_v5", "Formal hiring balance per 100k working-age population, MA6 V5", "Formal labor market", NA_character_, TRUE,
  "formal_hiring_balance_construction_per_100k_wap_ma6_v5", "Construction hiring balance per 100k working-age population, MA6 V5", "Formal labor market", NA_character_, TRUE,
  "retail_volume_index_ma6_v5", "Retail volume index, MA6 V5", "Household consumption", NA_character_, TRUE,
  "services_volume_index_ma6_v5", "Services volume index, MA6 V5", "Household consumption", NA_character_, TRUE,
  "state_tax_revenue_real_pc_ma4_v5", "Own tax revenue, real per capita, MA4 V5", "State public finances", "revenues", FALSE,
  "icms_revenue_real_pc_ma4_v5", "ICMS revenue, real per capita, MA4 V5", "State public finances", "revenues", FALSE,
  "public_investment_liquidated_real_pc_ma4_v5", "Public investment, liquidated, real per capita, MA4 V5", "State public finances", "expenditures", FALSE,
  "liquidated_expenditure_total_real_pc_ma4_v5", "Total liquidated expenditure, real per capita, MA4 V5", "State public finances", "expenditures", FALSE
)

effects_tbl <- summary_tbl |>
  dplyr::left_join(outcome_meta, by = "outcome") |>
  dplyr::filter(.data$status == "estimated") |>
  dplyr::transmute(
    outcome,
    label,
    channel,
    subblock,
    family,
    specification,
    preferred,
    mean_gap_crisis = .data$augmented_mean_gap_crisis,
    mean_gap_post = .data$augmented_mean_gap_post,
    mean_gap_pre = .data$augmented_mean_gap_pre,
    augmented_rmspe_pre = .data$augmented_rmspe_pre,
    augmented_rmspe_post = .data$augmented_rmspe_post,
    donor_count = .data$donor_count
  )

readr::write_csv(effects_tbl, file.path(table_dir, "augmented_effects_by_outcome.csv"), na = "")

# Top donor weights per preferred outcome
read_weights_safe <- function(family, specification, outcome) {
  f <- file.path(output_root, family, specification, paste0(make_slug(outcome), "_weights.csv"))
  if (!file.exists(f)) return(NULL)
  readr::read_csv(f, show_col_types = FALSE) |> dplyr::mutate(outcome = outcome)
}

# NOTE: MA4 fiscal is not feasible with only 6 bimonthly pre-treatment periods
# (Siconfi starts 2015; event_time=0 at instability 2016-01). Raw fiscal is used instead.
preferred_spec_lookup <- tibble::tribble(
  ~outcome,                                                   ~family,            ~specification, ~short_label,
  "formal_hiring_balance_per_100k_wap_ma6_v5",               "monthly",          "ma6_v5",       "Formal hiring, MA6",
  "formal_hiring_balance_construction_per_100k_wap_ma6_v5",  "monthly",          "ma6_v5",       "Construction hiring, MA6",
  "retail_volume_index_ma6_v5",                              "monthly",          "ma6_v5",       "Retail, MA6",
  "services_volume_index_ma6_v5",                            "monthly",          "ma6_v5",       "Services, MA6",
  "state_tax_revenue_real_pc",                               "bimonthly_fiscal", "raw",          "Own tax revenue (raw)",
  "icms_revenue_real_pc",                                    "bimonthly_fiscal", "raw",          "ICMS (raw)",
  "public_investment_liquidated_real_pc",                    "bimonthly_fiscal", "raw",          "Public investment (raw)",
  "liquidated_expenditure_total_real_pc",                    "bimonthly_fiscal", "raw",          "Total expenditure (raw)"
)

# === COVARIATE BALANCE TABLE ===
covariates_full <- readr::read_csv(
  file.path(data_dir, "am_2017_01_v1_covariates.csv"), show_col_types = FALSE
)

covariate_vars <- c(
  "unemployment_rate", "formalization_rate", "labor_income_real",
  "transfer_dependency_ratio", "health_expenditure_real_pc",
  "education_expenditure_real_pc", "public_security_expenditure_real_pc"
)

covariate_labels <- c(
  "Unemployment rate", "Formalization rate", "Labor income (real, R$)",
  "Transfer dependency ratio", "Health expenditure pc (real, R$)",
  "Education expenditure pc (real, R$)", "Public security expenditure pc (real, R$)"
)

rr_covs <- covariates_full |>
  dplyr::filter(.data$state_abbrev == treated_st) |>
  dplyr::select(dplyr::all_of(covariate_vars)) |>
  as.list()

compute_synthetic_covariates <- function(outcome, family, specification) {
  w_file <- file.path(output_root, family, specification,
                      paste0(make_slug(outcome), "_weights.csv"))
  if (!file.exists(w_file)) return(rep(NA_real_, length(covariate_vars)))
  weights <- readr::read_csv(w_file, show_col_types = FALSE)
  donor_covs <- covariates_full |>
    dplyr::filter(.data$state_abbrev %in% weights$donor_state) |>
    dplyr::left_join(weights, by = c("state_abbrev" = "donor_state")) |>
    dplyr::filter(!is.na(.data$scm_weight))
  sapply(covariate_vars, function(v) {
    sum(donor_covs[[v]] * donor_covs$scm_weight, na.rm = TRUE)
  })
}

balance_channel <- function(outcomes_df, caption) {
  rr_row   <- sapply(covariate_vars, function(v) rr_covs[[v]])
  synth_mat <- purrr::map(seq_len(nrow(outcomes_df)), function(i) {
    compute_synthetic_covariates(outcomes_df$outcome[i],
                                 outcomes_df$family[i],
                                 outcomes_df$specification[i])
  })
  synth_mat <- do.call(cbind, synth_mat)
  colnames(synth_mat) <- outcomes_df$short_label

  tbl <- cbind(
    Covariate = covariate_labels,
    Roraima   = format_num(rr_row, 3),
    as.data.frame(apply(synth_mat, 2, function(x) format_num(x, 3)))
  )
  tbl
}

preferred_spec_lookup_channels <- preferred_spec_lookup |>
  dplyr::mutate(channel = dplyr::case_when(
    grepl("formal_hiring|construction", .data$outcome) ~ "labor_market",
    grepl("retail|services",            .data$outcome) ~ "consumption",
    TRUE                                               ~ "public_sector"
  ))

balance_labor   <- balance_channel(
  preferred_spec_lookup_channels |> dplyr::filter(.data$channel == "labor_market"),
  "Formal labor market"
)
balance_consum  <- balance_channel(
  preferred_spec_lookup_channels |> dplyr::filter(.data$channel == "consumption"),
  "Household consumption"
)
balance_fiscal  <- balance_channel(
  preferred_spec_lookup_channels |> dplyr::filter(.data$channel == "public_sector"),
  "State public finances"
)

# Also compute pre-treatment outcome balance (treated mean vs synthetic mean)
compute_pretx_outcome_balance <- function(outcome, family, specification, short_label) {
  path_file <- file.path(output_root, family, specification,
                         paste0(make_slug(outcome), "_path.csv"))
  if (!file.exists(path_file)) return(NULL)
  path <- readr::read_csv(path_file, show_col_types = FALSE) |>
    dplyr::filter(.data$analysis_period == "pre")
  tibble::tibble(
    Outcome   = short_label,
    Roraima   = format_num(mean(path$treated_value,           na.rm = TRUE), 2),
    Synthetic = format_num(mean(path$augmented_synthetic_value, na.rm = TRUE), 2),
    `RMSPE pre` = format_num(sqrt(mean((path$treated_value - path$augmented_synthetic_value)^2, na.rm = TRUE)), 2)
  )
}

pretx_balance <- purrr::map_dfr(seq_len(nrow(preferred_spec_lookup)), function(i) {
  row <- preferred_spec_lookup[i, ]
  compute_pretx_outcome_balance(row$outcome, row$family, row$specification, row$short_label)
})

readr::write_csv(balance_labor,  file.path(table_dir, "covariate_balance_labor_market.csv"),   na = "")
readr::write_csv(balance_consum, file.path(table_dir, "covariate_balance_consumption.csv"),    na = "")
readr::write_csv(balance_fiscal, file.path(table_dir, "covariate_balance_public_sector.csv"),  na = "")
readr::write_csv(pretx_balance,  file.path(table_dir, "pretx_outcome_balance.csv"),            na = "")

top_weights_tbl <- purrr::map_dfr(seq_len(nrow(preferred_spec_lookup)), function(i) {
  row <- preferred_spec_lookup[i, ]
  w   <- read_weights_safe(row$family, row$specification, row$outcome)
  if (is.null(w)) return(NULL)
  w |>
    dplyr::arrange(dplyr::desc(.data$scm_weight)) |>
    dplyr::slice_head(n = 5) |>
    dplyr::mutate(short_label = row$short_label)
})

readr::write_csv(top_weights_tbl, file.path(table_dir, "top_donor_weights_by_outcome.csv"), na = "")

# In-space placebo rank table (if available)
placebo_inspace_dir <- file.path(output_root, "placebo_inspace")
has_placebo_inspace <- file.exists(file.path(table_dir, "placebo_rank_actual_rr.csv"))

if (has_placebo_inspace) {
  placebo_rank_tbl <- readr::read_csv(
    file.path(table_dir, "placebo_rank_actual_rr.csv"), show_col_types = FALSE
  )
  placebo_md <- placebo_rank_tbl |>
    dplyr::transmute(
      Outcome              = short_label,
      `RMSPE ratio (post/pre)` = format_num(post_pre_rmspe_ratio),
      `p-value (ratio)`    = format_num(ratio_p_value, 3),
      `p-value (abs gap)`  = format_num(abs_gap_p_value, 3),
      Placebos             = as.character(donor_placebo_count)
    )
} else {
  placebo_md <- NULL
}

icms_audit <- fiscal_panel |>
  dplyr::filter(.data$state_abbrev == treated_st) |>
  dplyr::select(
    .data$period,
    .data$period_date,
    .data$analysis_period,
    .data$icms_revenue_cumulative_nominal,
    .data$icms_revenue_nominal,
    .data$icms_revenue_real,
    .data$resident_population_annual,
    .data$icms_revenue_real_pc,
    .data$icms_revenue_real_pc_ma4_v5
  )

total_expenditure_audit <- fiscal_panel |>
  dplyr::filter(.data$state_abbrev == treated_st) |>
  dplyr::select(
    .data$period,
    .data$period_date,
    .data$analysis_period,
    .data$liquidated_expenditure_total_nominal,
    .data$liquidated_expenditure_total_real,
    .data$resident_population_annual,
    .data$liquidated_expenditure_total_real_pc,
    .data$liquidated_expenditure_total_real_pc_ma4_v5,
    .data$original_liquidated_expenditure_total_missing,
    .data$liquidated_expenditure_total_recovered_from_raw,
    .data$liquidated_expenditure_total_imputed_adjacent_mean,
    .data$liquidated_expenditure_total_imputation_method
  )

readr::write_csv(icms_audit, file.path(table_dir, "am_2017_01_v1_icms_audit.csv"), na = "")
readr::write_csv(total_expenditure_audit, file.path(table_dir, "am_2017_01_v1_total_expenditure_audit.csv"), na = "")

sectoral_covariate_imputation_audit <- fiscal_panel |>
  dplyr::filter(
    .data$liquidated_expenditure_health_real_pc_imputed_adjacent_mean |
      .data$liquidated_expenditure_education_real_pc_imputed_adjacent_mean |
      .data$liquidated_expenditure_public_security_real_pc_imputed_adjacent_mean
  ) |>
  dplyr::select(
    .data$state_abbrev,
    .data$period,
    .data$period_date,
    .data$analysis_period,
    .data$original_liquidated_expenditure_health_real_pc_missing,
    .data$liquidated_expenditure_health_real_pc,
    .data$liquidated_expenditure_health_real_pc_imputed_adjacent_mean,
    .data$liquidated_expenditure_health_real_pc_imputation_method,
    .data$original_liquidated_expenditure_education_real_pc_missing,
    .data$liquidated_expenditure_education_real_pc,
    .data$liquidated_expenditure_education_real_pc_imputed_adjacent_mean,
    .data$liquidated_expenditure_education_real_pc_imputation_method,
    .data$original_liquidated_expenditure_public_security_real_pc_missing,
    .data$liquidated_expenditure_public_security_real_pc,
    .data$liquidated_expenditure_public_security_real_pc_imputed_adjacent_mean,
    .data$liquidated_expenditure_public_security_real_pc_imputation_method
  )

quarterly_coverage_audit <- quarterly_panel |>
  dplyr::group_by(.data$state_abbrev) |>
  dplyr::summarise(
    first_period_in_panel = min(.data$period_date, na.rm = TRUE),
    quarterly_periods = dplyr::n(),
    .groups = "drop"
  )

readr::write_csv(
  sectoral_covariate_imputation_audit,
  file.path(table_dir, "am_2017_01_v1_sectoral_fiscal_covariate_imputations.csv"),
  na = ""
)
readr::write_csv(
  quarterly_coverage_audit,
  file.path(table_dir, "am_2017_01_v1_quarterly_covariate_coverage.csv"),
  na = ""
)

# === LOO PLACEBO TABLE (dynamic) ===
placebo_loo_dir <- file.path(output_root, "placebo_loo")

compute_loo_stats <- function(loo_file, main_path_file) {
  if (!file.exists(loo_file) || !file.exists(main_path_file)) {
    return(NULL)
  }
  loo <- readr::read_csv(loo_file, show_col_types = FALSE)
  main <- readr::read_csv(main_path_file, show_col_types = FALSE)
  main_gap <- main |>
    dplyr::filter(.data$analysis_period == "post") |>
    dplyr::summarise(m = mean(.data$augmented_gap, na.rm = TRUE)) |>
    dplyr::pull(.data$m)
  loo_gaps <- loo |>
    dplyr::filter(.data$analysis_period == "post") |>
    dplyr::group_by(.data$dropped_donor) |>
    dplyr::summarise(m = mean(.data$loo_gap, na.rm = TRUE), .groups = "drop") |>
    dplyr::pull(.data$m)
  all_gaps <- c(main_gap, loo_gaps)
  n <- length(all_gaps)
  r <- rank(all_gaps)[1]
  pval_two_sided <- min(r, n - r + 1) / n
  direction <- if (main_gap >= 0) "positive" else "negative"
  list(
    gap = round(main_gap, 2),
    rank = r,
    n = n,
    pval = round(pval_two_sided, 3),
    direction = direction
  )
}

loo_specs <- list(
  list(label = "Formal hiring (MA6)", family = "monthly", spec = "ma6_v5",
       outcome_slug = "formal_hiring_balance_per_100k_wap_ma6_v5"),
  list(label = "Retail index (MA6)", family = "monthly", spec = "ma6_v5",
       outcome_slug = "retail_volume_index_ma6_v5"),
  list(label = "Services index (MA6)", family = "monthly", spec = "ma6_v5",
       outcome_slug = "services_volume_index_ma6_v5"),
  list(label = "ICMS revenue (MA4)", family = "bimonthly_fiscal", spec = "ma4_v5",
       outcome_slug = "icms_revenue_real_pc_ma4_v5"),
  list(label = "Public investment (MA4)", family = "bimonthly_fiscal", spec = "ma4_v5",
       outcome_slug = "public_investment_liquidated_real_pc_ma4_v5"),
  list(label = "Total expenditure (MA4)", family = "bimonthly_fiscal", spec = "ma4_v5",
       outcome_slug = "liquidated_expenditure_total_real_pc_ma4_v5")
)

loo_results <- purrr::map_dfr(loo_specs, function(s) {
  loo_file <- file.path(placebo_loo_dir,
    paste0(s$outcome_slug, "_", s$spec, "_loo_placebo.csv"))
  path_file <- file.path(output_root, s$family, s$spec,
    paste0(s$outcome_slug, "_path.csv"))
  stats <- compute_loo_stats(loo_file, path_file)
  if (is.null(stats)) {
    return(tibble::tibble(
      Outcome = s$label,
      `Gap post` = NA_character_,
      `LOO rank` = NA_character_,
      `p-value (2-sided)` = NA_character_,
      Note = "LOO file not found"
    ))
  }
  near_top <- stats$rank > stats$n * 0.9
  near_bottom <- stats$rank <= stats$n * 0.1
  note <- dplyr::case_when(
    stats$pval > 0.10 ~ "Not extreme relative to LOO distribution",
    near_top & stats$direction == "positive" ~ "Unusually large positive gap",
    near_top & stats$direction == "negative" ~ "Unusually large negative gap (extreme)",
    near_bottom & stats$direction == "positive" ~
      "Unusually small positive gap (most LOO estimates are larger)",
    near_bottom & stats$direction == "negative" ~
      "Unusually small negative gap (most LOO estimates are smaller)",
    TRUE ~ "Extreme relative to LOO distribution"
  )
  tibble::tibble(
    Outcome = s$label,
    `Gap post` = as.character(stats$gap),
    `LOO rank` = paste0(stats$rank, " / ", stats$n),
    `p-value (2-sided)` = as.character(stats$pval),
    Note = note
  )
})

readr::write_csv(loo_results, file.path(table_dir, "am_2017_01_v1_loo_placebo_summary.csv"), na = "")

preferred_effects_md <- effects_tbl |>
  dplyr::filter(.data$preferred, !grepl("instability", .data$specification)) |>
  dplyr::transmute(
    Channel = channel,
    Outcome = label,
    `Mean gap crisis` = format_num(mean_gap_crisis),
    `Mean gap post` = format_num(mean_gap_post),
    `RMSPE pre` = format_num(augmented_rmspe_pre),
    `RMSPE post` = format_num(augmented_rmspe_post),
    Donors = as.character(donor_count)
  )

raw_effects_md <- effects_tbl |>
  dplyr::filter(!.data$preferred, !grepl("instability", .data$specification),
                .data$specification == "raw") |>
  dplyr::transmute(
    Channel = channel,
    Outcome = label,
    `Mean gap crisis` = format_num(mean_gap_crisis),
    `Mean gap post` = format_num(mean_gap_post),
    `RMSPE pre` = format_num(augmented_rmspe_pre),
    `RMSPE post` = format_num(augmented_rmspe_post),
    Donors = as.character(donor_count)
  )

# === DYNAMIC EVENT STRINGS ===
removal_date_dt    <- as.Date(event$removal_date[[1]])
instability_dt     <- as.Date(event$instability_start_date[[1]])
treated_st         <- event$state_abbrev[[1]]
state_name_val     <- event$state_name[[1]]
# event_time = 0 is anchored at instability_start_date (not removal_date)
event_year_val     <- lubridate::year(instability_dt)
event_month_label  <- format(lubridate::floor_date(instability_dt, "month"), "%Y-%m")
event_bimonth_num  <- ((lubridate::month(instability_dt) - 1L) %/% 2L) + 1L
event_bimonth_label <- paste0(event_year_val, "B", event_bimonth_num)
removal_year_val   <- lubridate::year(removal_date_dt)
crisis_end_monthly_val   <- as.integer(event$crisis_end_monthly[[1]])
crisis_end_bimstr_val    <- as.integer(event$crisis_end_bimonthly[[1]])

monthly_ws   <- as.Date(event$monthly_window_start[[1]])
monthly_we   <- as.Date(event$monthly_window_end[[1]])
bim_ws       <- as.Date(event$bimonthly_window_start[[1]])

monthly_pre_n  <- 12L * (event_year_val - lubridate::year(monthly_ws)) +
                  (lubridate::month(instability_dt) - lubridate::month(monthly_ws))
monthly_post_n <- 12L * (lubridate::year(monthly_we) - event_year_val) +
                  (lubridate::month(monthly_we) - lubridate::month(removal_date_dt))

bim_ws_year  <- lubridate::year(bim_ws)
bim_ws_bim   <- ((lubridate::month(bim_ws) - 1L) %/% 2L) + 1L
bim_pre_n    <- 6L * (event_year_val - bim_ws_year) + (event_bimonth_num - bim_ws_bim)
bim_post_n   <- 6L * (lubridate::year(as.Date(event$bimonthly_window_end[[1]])) - event_year_val) +
                (3L - event_bimonth_num)  # rough; overridden below
bim_we_year  <- lubridate::year(as.Date(event$bimonthly_window_end[[1]]))
bim_we_bim   <- 6L
bim_post_n   <- 6L * (bim_we_year - event_year_val) + (bim_we_bim - event_bimonth_num)

# Excluded states (from the panel covariates)
excluded_states <- covariates_full |>
  dplyr::filter(.data$excluded_from_main_donor_pool) |>
  dplyr::pull(.data$state_abbrev) |>
  sort()
excluded_str <- paste0("`", excluded_states, "`", collapse = ", ")

# Instability start type description
instability_type_desc <- dplyr::case_when(
  grepl("pgr|presidential", event$instability_start_type[[1]], ignore.case = TRUE) ~ "PGR intervention request",
  grepl("tre|tse.*cassation.*decision", event$instability_start_type[[1]], ignore.case = TRUE) ~ "first TRE/TSE cassation decision",
  grepl("police_operation", event$instability_start_type[[1]], ignore.case = TRUE) ~ "public police operation",
  grepl("impeachment_request", event$instability_start_type[[1]], ignore.case = TRUE) ~ "impeachment request filed",
  TRUE ~ event$instability_start_type[[1]]
)

# Removal mechanism description
mechanism_desc <- dplyr::case_when(
  grepl("TSE_final_decision", event$removal_mechanism[[1]], ignore.case = TRUE) ~ "TSE final cassation decision",
  grepl("presidential_decree", event$removal_mechanism[[1]], ignore.case = TRUE) ~ "presidential decree",
  grepl("STJ", event$removal_mechanism[[1]], ignore.case = TRUE) ~ "STJ cautelar suspension",
  TRUE ~ event$removal_mechanism[[1]]
)

pilot_label <- paste0(treated_st, " ", removal_year_val, "-01")

report_lines <- c(
  paste0("# ", pilot_label, ": results report"),
  "",
  paste0("Generated on ", Sys.Date(), "."),
  "",
  paste0("This document consolidates the Augmented Synthetic Control results for the ", state_name_val, " ", event_year_val, " case across three channels: formal labor market, household consumption, and state public finances. The design follows the project-wide protocol for gubernatorial removal events in Brazil."),
  "",
  "## Event design",
  "",
  paste0("- Treated state: `", treated_st, "` (", state_name_val, ")."),
  paste0("- Instability start: `", instability_dt, "` (", instability_type_desc, ")."),
  paste0("- Effective removal/intervention: `", removal_date_dt, "` (", mechanism_desc, ")."),
  paste0("- Monthly event time: ", event_month_label, " (instability onset) is coded as 0. Pre-treatment: -", monthly_pre_n, " to -1. Crisis window: 0 to ", crisis_end_monthly_val - 1L, " (", event_month_label, " to ", format(lubridate::floor_date(removal_date_dt, "month") - months(1), "%Y-%m"), "). Post-removal: ", crisis_end_monthly_val, " onward."),
  paste0("- Bimonthly event time: ", event_bimonth_label, " (instability onset) is coded as 0. Pre-treatment: -", bim_pre_n, " to -1. Crisis: 0 to ", crisis_end_bimstr_val - 1L, ". Post-removal: ", crisis_end_bimstr_val, " onward."),
  "- Pre-treatment weight estimation uses only `analysis_period == pre` observations (before instability onset).",
  "",
  "## Methodological strategy",
  "",
  paste0("The main donor pool excludes ", excluded_str, ". The treated state is excluded as the intervention unit. Other states are excluded for coded rupture events within the estimation window. The preferred specification uses ", 27L - length(excluded_states), " eligible donors."),
  "",
  "For each outcome, the method constructs a convex combination of donor states that approximates the treated state's pre-treatment trajectory and pre-event covariates. Let \\(Y_{1t}\\) be the outcome observed in Roraima at period \\(t\\) and \\(Y_{jt}\\) in donor \\(j\\). The classic synthetic control is:",
  "",
  "\\[",
  "\\widehat{Y}^{SCM}_{1t} = \\sum_{j=2}^{J+1} w_j Y_{jt}, \\qquad w_j \\geq 0, \\qquad \\sum_{j=2}^{J+1} w_j = 1.",
  "\\]",
  "",
  "Weights \\(w_j\\) minimize the distance between the treated state's predictors \\(X_1\\) and the weighted donor predictors \\(X_0 W\\). Predictors include the full pre-treatment outcome path and six structural covariates: unemployment rate, formalization rate, transfer dependency ratio, and health, education, and public security expenditure per capita.",
  "",
  "The headline estimator is the Augmented SCM, which adds a ridge-based bias correction:",
  "",
  "\\[",
  "\\widehat{Y}^{ASCM}_{1t} = \\widehat{Y}^{SCM}_{1t} + \\widehat{m}_t(X_1) - \\sum_{j=2}^{J+1} \\widehat{w}_j \\widehat{m}_t(X_j),",
  "\\]",
  "",
  "where \\(\\widehat{m}_t(\\cdot)\\) is a ridge function fit to the donor states at each period \\(t\\). The ridge penalty \\(\\lambda\\) is selected by leave-one-out cross-validation on the donor pool. The estimated effect is:",
  "",
  "\\[",
  "\\widehat{\\tau}_{1t} = Y_{1t} - \\widehat{Y}^{ASCM}_{1t}.",
  "\\]",
  "",
  paste0("Positive gaps indicate ", state_name_val, " performed above the synthetic counterfactual; negative gaps indicate below. Each monthly and bimonthly outcome is estimated in both a raw and a clean moving-average specification. Moving averages are computed separately within each segment (pre, event, post) and use complete trailing windows only."),
  "",
  "## Outcomes and channels",
  "",
  "- Formal labor market: formal hiring balance per 100k working-age population (CAGED); construction hiring balance per 100k working-age population.",
  "- Household consumption: retail volume index (PMC); services volume index (PMS). Both are reindexed to 100 at the first valid observation in the pilot window.",
  "- State public finances, revenues: own tax revenue real per capita; ICMS revenue real per capita (Siconfi/RREO Annex 06).",
  "- State public finances, expenditures: public investment liquidated real per capita; total liquidated expenditure real per capita.",
  "",
  "Fiscal variables are per resident population. Employment variables are per 100k working-age population (PNADc). Activity indices use the official IBGE index level reanchored at the start of the pilot window.",
  "",
  "## Donor pool rule",
  "",
  "- Exclude the treated state.",
  "- Exclude any state with a coded rupture episode whose removal date falls within the main estimation window.",
  paste0("- For ", pilot_label, ", this excludes ", excluded_str, "."),
  "",
  "## Data handling",
  "",
  "### CAGED formal hiring source correction",
  "",
  "- An audit of all data sources identified that an earlier version of this script loaded `old_caged_state_balance_monthly_panel_ready.csv` for the formal hiring balance outcome.",
  "- The project validation note (`notes/caged_final_validation.md`) explicitly marks that file as 'not to use directly' and designates `caged_state_balance_monthly_panel_ready.csv` as the preferred analysis file.",
  "- The correct file uses Old CAGED complete monthly microdata for 2007–2019 and adjusted Novo CAGED (CAGEDMOV + CAGEDFOR − CAGEDEXC) from 2020 onward, under version label `old_complete_novo_mov_for_exc_v1`.",
  "- Correcting this source was identified during the RR 2018-01 V5 audit; this pilot uses the validated final CAGED file from the start.",
  "- All other data sources (construction CAGED, PMC retail, PMS services, PNADc quarterly, Siconfi fiscal) were confirmed correct by the same audit.",
  "",
  paste0("- Quarterly PNADc covariates now start at `", event$quarterly_window_start[[1]], "`, which is the first quarter with observed formalization data in the source panel."),
  "- Missing fiscal sector covariates for health, education, and public security are imputed only when the missing observation is bracketed by observed adjacent bimesters in the same state.",
  "- The imputation rule is the simple average of the previous and next observed bimesters (`adjacent_mean_prev_next`).",
  "- These repairs are limited to covariates and are documented in `report/tables/am_2017_01_v1_sectoral_fiscal_covariate_imputations.csv`.",
  "",
  "### RS 2018 ICMS seasonal imputation",
  "",
  "- The Siconfi API returns 0 rows for Rio Grande do Sul (RS) Annex06 in bimesters 2018B1–2018B5. RS did not publish intermediate RREO Annex06 reports for those bimesters.",
  "- The annual cumulative (2018B6) is available. The missing bimestral flows were imputed using the intra-annual seasonal distribution observed for RS in 2017, applied to the 2018 annual total.",
  "- All five imputed bimesters are flagged with `icms_rs_2018_seasonal_imputed = TRUE` in the fiscal panel.",
  "- The B6 flow was recalculated as `B6_cumulative - imputed_B5_cumulative` to preserve internal consistency.",
  "- This imputation restores RS to the ICMS donor pool (24 donors instead of 23) and yields a modest improvement in pre-treatment RMSPE for ICMS.",
  "",
  "### Negative ICMS flow handling",
  "",
  "- Two derived ICMS flows were negative due to cumulative accounting revisions in Siconfi: MT 2015B2 and RN 2018B3.",
  "- These were replaced by the average of adjacent bimesters within the same state-year. Replacements are flagged with `icms_revenue_negative_flow_imputed = TRUE`.",
  "",
  "### Instability weight window",
  "",
  "- A `pre_instability_clean` column marks periods that are both pre-treatment and before the instability start date.",
  "- For the monthly panel, `instability_start_date = 2018-11-07` places November 2018 (event_time = -1) outside the clean pre-treatment window.",
  "- For the bimonthly panel, the instability start falls in bimester 6 of 2018, which is already the event period; all bimonthly pre-treatment periods are clean.",
  "- The specification `ma6_v5_instability` estimates SCM weights using only `pre_instability_clean` periods. Results are nearly identical to the baseline for this case (only one monthly period affected).",
  "",
  "## Preliminary plots",
  "",
  figure_link("preliminary_labor_market_raw.png"),
  "",
  figure_link("preliminary_labor_market_smooth.png"),
  "",
  figure_link("preliminary_consumption_raw.png"),
  "",
  figure_link("preliminary_consumption_smooth.png"),
  "",
  figure_link("preliminary_public_sector_raw.png"),
  "",
  figure_link("preliminary_public_sector_smooth.png"),
  "",
  "## Covariate and pre-treatment outcome balance",
  "",
  "The tables below compare Roraima's pre-treatment covariate values against the synthetic control for each preferred smoothed outcome. Covariates are pre-treatment means used as predictors in the SCM. Synthetic values are weighted averages of donor states using the SCM weights. Closer alignment indicates better pre-treatment comparability on observable characteristics.",
  "",
  "### Pre-treatment outcome fit",
  "",
  "Mean of the outcome variable in the pre-treatment period for Roraima, the augmented synthetic, and the implied RMSPE.",
  "",
  make_markdown_table(pretx_balance),
  "",
  "### Covariate balance: formal labor market",
  "",
  make_markdown_table(balance_labor),
  "",
  "### Covariate balance: household consumption",
  "",
  make_markdown_table(balance_consum),
  "",
  "### Covariate balance: state public finances",
  "",
  make_markdown_table(balance_fiscal),
  "",
  "Audit CSVs: `covariate_balance_labor_market.csv`, `covariate_balance_consumption.csv`, `covariate_balance_public_sector.csv`, `pretx_outcome_balance.csv`.",
  "",
  "## Preferred smoothed results",
  "",
  make_markdown_table(preferred_effects_md),
  "",
  figure_link("augmented_effect_summary.png"),
  "",
  "## Augmented SCM paths",
  "",
  "### Formal labor market",
  "",
  figure_link("augmented_paths_labor_market_raw.png"),
  "",
  figure_link("augmented_gaps_labor_market_raw.png"),
  "",
  figure_link("augmented_paths_labor_market_smooth.png"),
  "",
  figure_link("augmented_gaps_labor_market_smooth.png"),
  "",
  "The formal hiring balance and construction hiring balance capture two complementary margins of formal employment. The raw series reveals month-to-month volatility. The MA6 smoothed specification is the headline specification for interpretation.",
  "",
  "### Household consumption",
  "",
  figure_link("augmented_paths_consumption_raw.png"),
  "",
  figure_link("augmented_gaps_consumption_raw.png"),
  "",
  figure_link("augmented_paths_consumption_smooth.png"),
  "",
  figure_link("augmented_gaps_consumption_smooth.png"),
  "",
  "Retail and services indices are reanchored at 100. Both series capture household demand from different angles. Families may adjust goods and services consumption differently in response to political uncertainty.",
  "",
  "### State public finances",
  "",
  figure_link("augmented_paths_public_sector_raw.png"),
  "",
  figure_link("augmented_gaps_public_sector_raw.png"),
  "",
  figure_link("augmented_paths_public_sector_smooth.png"),
  "",
  figure_link("augmented_gaps_public_sector_smooth.png"),
  "",
  "The revenue block combines own tax revenue and ICMS. The expenditure block combines public investment and total expenditure. Both series required gap-repair in Siconfi/RREO and should be read together with audit tables.",
  "",
  "## Donor weights",
  "",
  "Raw specification weights:",
  "",
  figure_link("donor_weights_labor_market_raw.png"),
  "",
  figure_link("donor_weights_consumption_raw.png"),
  "",
  figure_link("donor_weights_public_sector_raw.png"),
  "",
  "Smoothed specification weights:",
  "",
  figure_link("donor_weights_labor_market_smooth.png"),
  "",
  figure_link("donor_weights_consumption_smooth.png"),
  "",
  figure_link("donor_weights_public_sector_smooth.png"),
  "",
  "## Robustness",
  "",
  "The first robustness check compares raw and smoothed specifications side by side. Raw series preserve short-term shocks but amplify operational noise, seasonality, and administrative irregularities. Smoothed series reduce this noise and are the preferred headline specification.",
  "",
  "Raw specification results:",
  "",
  make_markdown_table(raw_effects_md),
  "",
  "Smoothed specification results (preferred):",
  "",
  make_markdown_table(preferred_effects_md),
  "",
  "The second check is the explicit separation between the crisis window (instability start to removal date) and the post-removal period. For this case, November 2018 (event_time = -1) is the only month in the crisis window under the monthly specification. Results are nearly identical between the full pre-treatment and the pre-instability-only weight estimation, confirming that the short crisis window does not materially affect the estimates.",
  "",
  "The third check is the pre-treatment fit quality. Outcomes with high RMSPE_pre should receive lower interpretive weight because the synthetic counterfactual is less credible. Total expenditure (RMSPE_pre ≈ 98.5) is the most notable case.",
  "",
  "## In-space placebos",
  "",
  if (has_placebo_inspace) {
    c(
      "In-space placebos re-estimate the Augmented SCM treating each eligible donor state as if it had received the treatment, at the same event date as Roraima. AM and TO are not used as placebos because they were also excluded from the main donor pool. RR remains outside all placebo donor pools. Gaps are normalized by each unit's own pre-treatment RMSPE:",
      "",
      "\\[",
      "g^{norm}_{it} = \\frac{Y_{it} - \\widehat{Y}^{ASCM}_{it}}{RMSPE^{pre}_i}.",
      "\\]",
      "",
      "This normalization makes units with different scales comparable. The test is not formal randomization inference, but provides ordinal evidence: if Roraima ranks among the largest normalized post-treatment gaps, the result is consistent with an exceptional effect of the event.",
      "",
      make_markdown_table(placebo_md),
      "",
      "### In-space placebo figures",
      "",
      figure_link("placebo_gaps_labor_market_smooth.png"),
      "",
      figure_link("placebo_rmspe_ratio_labor_market_smooth.png"),
      "",
      figure_link("placebo_gaps_consumption_smooth.png"),
      "",
      figure_link("placebo_rmspe_ratio_consumption_smooth.png"),
      "",
      figure_link("placebo_gaps_public_sector_smooth.png"),
      "",
      figure_link("placebo_rmspe_ratio_public_sector_smooth.png")
    )
  } else {
    "In-space placebo output not yet available. Run `02b_run_am_2017_01_v1_placebo_inspace.R` to generate."
  },
  "",
  "## Placebo inference: leave-one-out donor",
  "",
  "A leave-one-out (LOO) placebo was run for six outcomes: formal hiring balance, retail index, services index (monthly MA6), and ICMS, public investment, and total expenditure (bimonthly MA4). For each outcome, the SCM was re-estimated 24 times, each time dropping one donor state. The two-sided p-value reports the fraction of the LOO distribution that is more extreme than the main estimate in either direction.",
  "",
  make_markdown_table(loo_results),
  "",
  "The LOO files are saved in `output/placebo_loo/`. A summary CSV is at `report/tables/am_2017_01_v1_loo_placebo_summary.csv`.",
  "",
  "LOO notes: examine outcomes with p-value ≤ 0.10 carefully. Outcomes with high RMSPE_pre may show near-significant LOO results driven by poor pre-treatment fit rather than genuine causal effects.",
  "",
  "## Instability vs full pre-treatment: comparison",
  "",
  paste0("The `ma6_v5_instability` specification estimates SCM weights using only periods before the instability start (`", instability_dt, "`). For this case the instability window spans ", event$instability_duration_days[[1]], " days. Differences between the full pre-treatment and pre-instability specifications indicate how much the crisis period contaminates the weight estimation."),
  "",
  "## Current limitations",
  "",
  "- ICMS from Annex 06 is reported as realized cumulative revenue; the bimestral flow is derived by differencing within each year.",
  "- Public investment and total liquidated expenditure underwent gap repair in Siconfi/RREO; both should be read together with their audit tables.",
  "- RS 2018 ICMS bimesters B1–B5 were imputed using 2017 seasonal shares (Siconfi API returned 0 rows for those periods).",
  paste0("- The post-treatment window closes at end of ", lubridate::year(as.Date(event$monthly_window_end[[1]])), " to avoid pandemic overlap and the January 2020 CAGED methodological break."),
  paste0("- This document is a preliminary consolidation of the ", state_name_val, " ", event_year_val, " pilot, not the final results section of the article."),
  "",
  "## Generated files",
  "",
  "**Output tables:**",
  "- `report/tables/augmented_effects_by_outcome.csv`",
  "- `report/tables/pretx_outcome_balance.csv`",
  "- `report/tables/covariate_balance_labor_market.csv`",
  "- `report/tables/covariate_balance_consumption.csv`",
  "- `report/tables/covariate_balance_public_sector.csv`",
  "- `report/tables/top_donor_weights_by_outcome.csv`",
  "- `report/tables/am_2017_01_v1_loo_placebo_summary.csv`",
  if (has_placebo_inspace) "- `report/tables/placebo_rank_actual_rr.csv`" else NULL,
  "- `report/tables/am_2017_01_v1_icms_audit.csv`",
  "- `report/tables/am_2017_01_v1_total_expenditure_audit.csv`",
  "- `report/tables/am_2017_01_v1_sectoral_fiscal_covariate_imputations.csv`",
  "- `report/tables/am_2017_01_v1_quarterly_covariate_coverage.csv`",
  "",
  "**Output figures:** `report/figures/` (preliminary, paths, gaps, weights, placebo)",
  "",
  if (has_placebo_inspace) {
    c("**Placebo data:** `output/placebo_inspace/`",
      "- `placebo_paths_preferred_smooth.csv`",
      "- `placebo_summary_preferred_smooth.csv`")
  } else NULL,
  "",
  "**LOO placebo data:** `output/placebo_loo/` (6 leave-one-out placebo CSVs)"
)

readr::write_lines(
  report_lines,
  file.path(pilot_root, "am_2017_01_v1_results_report.md")
)

run_summary_lines <- c(
  paste0("# ", pilot_label, " Run Summary"),
  "",
  paste0("Run date: ", Sys.Date()),
  "",
  "## Pipeline",
  "",
  "- Built from the V5 template (rr_2018_01_v5). All methodological improvements from V5 are included.",
  "- Uses the validated final CAGED series (`caged_state_balance_monthly_panel_ready.csv`).",
  "- RS 2018 ICMS B1-B5 imputed with 2017 seasonal shares.",
  "- `pre_instability_clean` column marks periods before instability_start_date.",
  "- Specification `ma6_v5_instability` uses pre-instability-only weight estimation.",
  "- Leave-one-out and in-space placebo inference included.",
  "- Covariate balance and pre-treatment outcome fit tables included.",
  "",
  "## Main outputs",
  "",
  paste0("- `data/", pilot_id, "_monthly_panel.csv`"),
  paste0("- `data/", pilot_id, "_bimonthly_fiscal_panel.csv`"),
  paste0("- `data/", pilot_id, "_quarterly_pnadc_panel.csv`"),
  paste0("- `data/", pilot_id, "_covariates.csv`"),
  paste0("- `output/", pilot_id, "_scm_summary.csv`"),
  "- `output/placebo_inspace/` (in-space placebo outputs)",
  "- `output/placebo_loo/` (6 LOO placebo CSVs)",
  paste0("- `", pilot_id, "_results_report.md`"),
  "",
  "## Notes",
  "",
  paste0("- Instability window: ", event$instability_duration_days[[1]], " days (", instability_dt, " to ", removal_date_dt, ")."),
  paste0("- Monthly pre-treatment periods: ", monthly_pre_n, "; post-treatment periods (until end of window): ", monthly_post_n, "."),
  paste0("- Bimonthly pre-treatment bimesters: ", bim_pre_n, "; post: ", bim_post_n, "."),
  paste0("- Excluded donor states: ", excluded_str, ".")
)

readr::write_lines(run_summary_lines, file.path(notes_dir, "run_summary.md"))

readr::write_lines(
  c(
    "# RR 2018-01 Pilot V5",
    "",
    "This folder contains a clean rebuild of the Roraima 2018 pilot under the current three-block article design.",
    "",
    "## Core principles",
    "",
    "- Built from scratch rather than copied from an earlier pilot.",
    "- Uses the V5 smoothing rule: complete trailing windows through -1, event coded as 0, and first post-treatment moving average at +1.",
    "- Keeps the main post-treatment window inside 2019 to avoid pandemic overlap and the CAGED methodology break.",
    "",
    "## Scripts",
    "",
    "1. `code/01_build_am_2017_01_v1_panels.R`",
    "2. `code/02_run_am_2017_01_v1_scm.R`",
    "3. `code/03b_make_am_2017_01_v1_report_figures.R`",
    "4. `code/03_make_am_2017_01_v1_report.R`"
  ),
  file.path(pilot_root, "README.md")
)

message(paste0(pilot_label, " report completed."))
message("Saved report to: ", file.path(pilot_root, "am_2017_01_v1_results_report.md"))

