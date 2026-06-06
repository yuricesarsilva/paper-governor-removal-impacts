source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

pilot_id <- "rr_2018_01_v5"
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
  file.path(data_dir, "rr_2018_01_v5_event_metadata.csv"),
  show_col_types = FALSE
) |>
  dplyr::slice(1)

fiscal_panel <- readr::read_csv(
  file.path(data_dir, "rr_2018_01_v5_bimonthly_fiscal_panel.csv"),
  show_col_types = FALSE
) |>
  dplyr::mutate(period_date = as.Date(.data$period_date))

summary_tbl <- readr::read_csv(
  file.path(output_root, "rr_2018_01_v5_scm_summary.csv"),
  show_col_types = FALSE
)

format_num <- function(x, digits = 2) {
  ifelse(is.na(x), "", format(round(x, digits), nsmall = digits, big.mark = ","))
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
  "state_tax_revenue_real_pc", "Own tax revenue, real per capita", "State public finances", "revenues", FALSE,
  "icms_revenue_real_pc", "ICMS revenue, real per capita", "State public finances", "revenues", FALSE,
  "public_investment_liquidated_real_pc", "Public investment, liquidated, real per capita", "State public finances", "expenditures", FALSE,
  "liquidated_expenditure_total_real_pc", "Total liquidated expenditure, real per capita", "State public finances", "expenditures", FALSE,
  "formal_hiring_balance_per_100k_wap_ma6_V5", "Formal hiring balance per 100k working-age population, MA6 V5", "Formal labor market", NA_character_, TRUE,
  "formal_hiring_balance_construction_per_100k_wap_ma6_V5", "Construction hiring balance per 100k working-age population, MA6 V5", "Formal labor market", NA_character_, TRUE,
  "retail_volume_index_ma6_V5", "Retail volume index, MA6 V5", "Household consumption", NA_character_, TRUE,
  "services_volume_index_ma6_V5", "Services volume index, MA6 V5", "Household consumption", NA_character_, TRUE,
  "state_tax_revenue_real_pc_ma4_V5", "Own tax revenue, real per capita, MA4 V5", "State public finances", "revenues", TRUE,
  "icms_revenue_real_pc_ma4_V5", "ICMS revenue, real per capita, MA4 V5", "State public finances", "revenues", TRUE,
  "public_investment_liquidated_real_pc_ma4_V5", "Public investment, liquidated, real per capita, MA4 V5", "State public finances", "expenditures", TRUE,
  "liquidated_expenditure_total_real_pc_ma4_V5", "Total liquidated expenditure, real per capita, MA4 V5", "State public finances", "expenditures", TRUE
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

icms_audit <- fiscal_panel |>
  dplyr::filter(.data$state_abbrev == "RR") |>
  dplyr::select(
    .data$period,
    .data$period_date,
    .data$analysis_period,
    .data$icms_revenue_cumulative_nominal,
    .data$icms_revenue_nominal,
    .data$icms_revenue_real,
    .data$resident_population_annual,
    .data$icms_revenue_real_pc,
    .data$icms_revenue_real_pc_ma4_V5
  )

total_expenditure_audit <- fiscal_panel |>
  dplyr::filter(.data$state_abbrev == "RR") |>
  dplyr::select(
    .data$period,
    .data$period_date,
    .data$analysis_period,
    .data$liquidated_expenditure_total_nominal,
    .data$liquidated_expenditure_total_real,
    .data$resident_population_annual,
    .data$liquidated_expenditure_total_real_pc,
    .data$liquidated_expenditure_total_real_pc_ma4_V5,
    .data$original_liquidated_expenditure_total_missing,
    .data$liquidated_expenditure_total_recovered_from_raw,
    .data$liquidated_expenditure_total_imputed_adjacent_mean,
    .data$liquidated_expenditure_total_imputation_method
  )

readr::write_csv(icms_audit, file.path(table_dir, "rr_2018_01_v5_icms_audit.csv"), na = "")
readr::write_csv(total_expenditure_audit, file.path(table_dir, "rr_2018_01_v5_total_expenditure_audit.csv"), na = "")

preferred_effects_md <- effects_tbl |>
  dplyr::filter(.data$preferred) |>
  dplyr::transmute(
    Channel = channel,
    Outcome = label,
    `Mean gap crisis` = format_num(mean_gap_crisis),
    `Mean gap post` = format_num(mean_gap_post),
    `RMSPE pre` = format_num(augmented_rmspe_pre),
    `RMSPE post` = format_num(augmented_rmspe_post),
    Donors = as.character(donor_count)
  )

report_lines <- c(
  "# RR 2018-01 V5: clean pilot rebuild",
  "",
  paste0("Generated on ", Sys.Date(), "."),
  "",
  "This pilot was rebuilt from scratch for the Roraima 2018 case. The objective is to keep the empirical design transparent and publication-oriented: no inherited outputs, no copied folder tree, and one explicit smoothing rule for every smoothed outcome.",
  "",
  "## Event design",
  "",
  paste0("- Treated state: `", event$state_abbrev[[1]], "`."),
  paste0("- Instability start: `", event$instability_start_date[[1]], "`."),
  paste0("- Effective removal/intervention: `", event$removal_date[[1]], "`."),
  "- Monthly coding: pre through 2018-10, crisis in 2018-11 and 2018-12, post from 2019-01 onward.",
  "- Bimonthly coding: pre through 2018B5, crisis in 2018B6, post from 2019B1 onward.",
  "",
  "## V5 smoothing rule",
  "",
  "- Pre-treatment: moving averages use complete trailing windows through the final pre-treatment period.",
  "- Crisis and post-treatment: the moving average restarts at the break and expands from 1, 2, 3 observations until the full window is reached.",
  "- Monthly outcomes use a 6-month window.",
  "- Bimonthly fiscal outcomes use a 4-bimester window.",
  "",
  "## Outcome blocks",
  "",
  "- Formal labor market: formal hiring balance per 100k working-age population; construction hiring balance per 100k working-age population.",
  "- Household consumption: retail volume index; services volume index.",
  "- State public finances, revenues: own tax revenue per capita; ICMS revenue per capita.",
  "- State public finances, expenditures: public investment per capita; total liquidated expenditure per capita.",
  "",
  "## Donor pool rule",
  "",
  "- Exclude the treated state.",
  "- Exclude any state with a coded rupture in the main pilot estimation window.",
  "- For RR 2018-01, this excludes `RR`, `AM`, and `TO` in the main donor pool.",
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
  "## Preferred smoothed results",
  "",
  make_markdown_table(preferred_effects_md),
  "",
  figure_link("augmented_effect_summary.png"),
  "",
  "## Augmented SCM paths",
  "",
  figure_link("augmented_paths_labor_market_smooth.png"),
  "",
  figure_link("augmented_paths_consumption_smooth.png"),
  "",
  figure_link("augmented_paths_public_sector_smooth.png"),
  "",
  "## Augmented SCM gaps",
  "",
  figure_link("augmented_gaps_labor_market_smooth.png"),
  "",
  figure_link("augmented_gaps_consumption_smooth.png"),
  "",
  figure_link("augmented_gaps_public_sector_smooth.png"),
  "",
  "## Donor weights",
  "",
  figure_link("donor_weights_labor_market_smooth.png"),
  "",
  figure_link("donor_weights_consumption_smooth.png"),
  "",
  figure_link("donor_weights_public_sector_smooth.png"),
  "",
  "## Audit tables",
  "",
  "- ICMS audit: `report/tables/rr_2018_01_v5_icms_audit.csv`.",
  "- Total expenditure audit: `report/tables/rr_2018_01_v5_total_expenditure_audit.csv`.",
  "",
  "## Scope note",
  "",
  "This V5 pilot prioritizes clean reconstruction and internal consistency. It does not yet bundle placebo inference into the reporting layer. That step should come after the current specification is fully stabilized."
)

readr::write_lines(
  report_lines,
  file.path(pilot_root, "rr_2018_01_v5_results_report.md")
)

run_summary_lines <- c(
  "# RR 2018-01 V5 Run Summary",
  "",
  paste0("Run date: ", Sys.Date()),
  "",
  "## What V5 changes",
  "",
  "- Rebuilt from scratch instead of copying an earlier pilot folder.",
  "- Uses one explicit smoothing rule: complete pre-treatment windows and expanding post-break windows.",
  "- Uses resident annual population from the general project base for fiscal per-capita outcomes.",
  "- Uses the project-wide construction-sector CAGED series for the sectoral labor-market outcome.",
  "",
  "## Main outputs",
  "",
  "- `data/rr_2018_01_v5_monthly_panel.csv`",
  "- `data/rr_2018_01_v5_bimonthly_fiscal_panel.csv`",
  "- `data/rr_2018_01_v5_quarterly_pnadc_panel.csv`",
  "- `data/rr_2018_01_v5_covariates.csv`",
  "- `output/rr_2018_01_v5_scm_summary.csv`",
  "- `rr_2018_01_v5_results_report.md`",
  "",
  "## Remaining work for article use",
  "",
  "- Add placebo inference and leave-one-out diagnostics to the clean V5 pipeline.",
  "- Decide whether the crisis block should be retained in the headline tables or treated as descriptive only.",
  "- Review writing, narrative emphasis, and effect interpretation after the preferred specification is frozen."
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
    "- Uses the V5 smoothing rule: complete trailing windows in pre-treatment, expanding windows after the break.",
    "- Keeps the main post-treatment window inside 2019 to avoid pandemic overlap and the CAGED methodology break.",
    "",
    "## Scripts",
    "",
    "1. `code/01_build_rr_2018_01_v5_panels.R`",
    "2. `code/02_run_rr_2018_01_v5_scm.R`",
    "3. `code/03b_make_rr_2018_01_v5_report_figures.R`",
    "4. `code/03_make_rr_2018_01_v5_report.R`"
  ),
  file.path(pilot_root, "README.md")
)

message("RR 2018-01 V5 report completed.")
message("Saved report to: ", file.path(pilot_root, "rr_2018_01_v5_results_report.md"))

