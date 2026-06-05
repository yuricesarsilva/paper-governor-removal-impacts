source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

pilot_id    <- "am_2017_01_v4"
pilot_root  <- file.path(root_dir, "pilots", pilot_id)
data_dir    <- file.path(pilot_root, "data")
output_root <- file.path(pilot_root, "output")
report_dir  <- file.path(pilot_root, "report")
figure_dir  <- file.path(report_dir, "figures")
table_dir   <- file.path(report_dir, "tables")
notes_dir   <- file.path(pilot_root, "notes")
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(table_dir,  recursive = TRUE, showWarnings = FALSE)
dir.create(notes_dir,  recursive = TRUE, showWarnings = FALSE)

event <- readr::read_csv(file.path(data_dir, "am_2017_01_v4_event_metadata.csv"), show_col_types = FALSE) |>
  dplyr::slice(1)

treated_st     <- event$state_abbrev[[1]]
state_name_val <- event$state_name[[1]]

fiscal_panel <- readr::read_csv(file.path(data_dir, "am_2017_01_v4_bimonthly_fiscal_panel.csv"), show_col_types = FALSE) |>
  dplyr::mutate(period_date = as.Date(.data$period_date))
quarterly_panel <- readr::read_csv(file.path(data_dir, "am_2017_01_v4_quarterly_pnadc_panel.csv"), show_col_types = FALSE) |>
  dplyr::mutate(period_date = as.Date(.data$period_date))
summary_tbl <- readr::read_csv(file.path(output_root, "am_2017_01_v4_scm_summary.csv"), show_col_types = FALSE)

format_num <- function(x, digits = 2) ifelse(is.na(x), "", format(round(x, digits), nsmall = digits, big.mark = ","))
make_slug  <- function(x) x |> stringr::str_replace_all("[^A-Za-z0-9]+", "_") |> stringr::str_replace_all("_+$", "") |> tolower()
make_markdown_table <- function(data) {
  if (nrow(data) == 0) return(character(0))
  header    <- paste0("| ", paste(names(data), collapse = " | "), " |")
  separator <- paste0("| ", paste(rep("---", ncol(data)), collapse = " | "), " |")
  rows      <- apply(data, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |"))
  c(header, separator, rows)
}
figure_link <- function(filename) paste0("![", filename, "](report/figures/", filename, ")")

# ── Outcome metadata (SA only) ─────────────────────────────────────────────────
outcome_meta <- tibble::tribble(
  ~outcome,                                              ~label,                                          ~channel,                ~family,     ~specification, ~short_label,
  "formal_hiring_balance_sa_per_100k_wap",              "Formal hiring balance per 100k WAP",             "Formal labor market",   "bimonthly", "sa", "Formal hiring",
  "formal_hiring_balance_construction_sa_per_100k_wap", "Construction hiring per 100k WAP",               "Formal labor market",   "bimonthly", "sa", "Construction",
  "retail_volume_index_sa",                             "Retail volume index",                            "Household consumption", "bimonthly", "sa", "Retail",
  "services_volume_index_sa",                           "Services volume index",                          "Household consumption", "bimonthly", "sa", "Services",
  "state_tax_revenue_real_pc_sa",                       "Own tax revenue, real per capita",               "State public finances", "bimonthly", "sa", "Own tax revenue",
  "icms_revenue_real_pc_sa",                            "ICMS revenue, real per capita",                  "State public finances", "bimonthly", "sa", "ICMS",
  "public_investment_liquidated_real_pc_sa",           "Public investment, real per capita",             "State public finances", "bimonthly", "sa", "Public investment",
  "liquidated_expenditure_total_real_pc_sa",           "Total liquidated expenditure, real pc",          "State public finances", "bimonthly", "sa", "Total expenditure"
)

effects_tbl <- summary_tbl |>
  dplyr::left_join(outcome_meta, by = c("outcome", "family", "specification")) |>
  dplyr::filter(.data$status == "estimated") |>
  dplyr::transmute(
    outcome, label, channel, short_label,
    mean_gap_post   = .data$augmented_mean_gap_post,
    mean_gap_pre    = .data$augmented_mean_gap_pre,
    augmented_rmspe_pre, augmented_rmspe_post, donor_count
  )

readr::write_csv(effects_tbl, file.path(table_dir, "augmented_effects_by_outcome.csv"), na = "")

# ── Covariate / pre-treatment balance ─────────────────────────────────────────
covariates_full <- readr::read_csv(file.path(data_dir, "am_2017_01_v4_covariates.csv"), show_col_types = FALSE)
covariate_vars <- c("unemployment_rate", "formalization_rate", "labor_income_real",
                    "transfer_dependency_ratio", "health_expenditure_real_pc",
                    "education_expenditure_real_pc", "public_security_expenditure_real_pc")
covariate_labels <- c("Unemployment rate (SA)", "Formalization rate (SA)", "Labor income (SA, R$)",
                      "Transfer dependency ratio (SA)", "Health expenditure pc (SA, R$)",
                      "Education expenditure pc (SA, R$)", "Public security expenditure pc (SA, R$)")

treated_covs <- covariates_full |> dplyr::filter(.data$state_abbrev == treated_st) |>
  dplyr::select(dplyr::all_of(covariate_vars)) |> as.list()

preferred_spec_lookup <- outcome_meta |> dplyr::select("outcome", "family", "specification", "short_label", "channel")

compute_synth_covs <- function(outcome, family, specification) {
  wf <- file.path(output_root, family, specification, paste0(make_slug(outcome), "_weights.csv"))
  if (!file.exists(wf)) return(rep(NA_real_, length(covariate_vars)))
  w  <- readr::read_csv(wf, show_col_types = FALSE)
  dc <- covariates_full |> dplyr::filter(.data$state_abbrev %in% w$donor_state) |>
    dplyr::left_join(w, by = c("state_abbrev" = "donor_state")) |>
    dplyr::filter(!is.na(.data$scm_weight))
  sapply(covariate_vars, function(v) sum(dc[[v]] * dc$scm_weight, na.rm = TRUE))
}

balance_channel <- function(odf) {
  treated_row <- sapply(covariate_vars, function(v) treated_covs[[v]])
  synth_mat   <- do.call(cbind, purrr::map(seq_len(nrow(odf)), function(i)
    compute_synth_covs(odf$outcome[i], odf$family[i], odf$specification[i])))
  colnames(synth_mat) <- odf$short_label
  cbind(Covariate = covariate_labels, Treated = format_num(treated_row, 3),
        as.data.frame(apply(synth_mat, 2, function(x) format_num(x, 3))))
}

psl_ch <- preferred_spec_lookup |>
  dplyr::mutate(channel_slug = dplyr::case_when(
    grepl("formal_hiring|construction", .data$outcome) ~ "labor_market",
    grepl("retail|services",            .data$outcome) ~ "consumption",
    TRUE                                               ~ "public_sector"))

balance_labor  <- balance_channel(psl_ch |> dplyr::filter(.data$channel_slug == "labor_market"))
balance_consum <- balance_channel(psl_ch |> dplyr::filter(.data$channel_slug == "consumption"))
balance_fiscal <- balance_channel(psl_ch |> dplyr::filter(.data$channel_slug == "public_sector"))

compute_pretx_balance <- function(outcome, family, specification, short_label) {
  pf <- file.path(output_root, family, specification, paste0(make_slug(outcome), "_path.csv"))
  if (!file.exists(pf)) return(NULL)
  p <- readr::read_csv(pf, show_col_types = FALSE) |> dplyr::filter(.data$analysis_period == "pre")
  tibble::tibble(
    Outcome     = short_label,
    Treated     = format_num(mean(p$treated_value, na.rm = TRUE), 2),
    Synthetic   = format_num(mean(p$augmented_synthetic_value, na.rm = TRUE), 2),
    `RMSPE pre` = format_num(sqrt(mean((p$treated_value - p$augmented_synthetic_value)^2, na.rm = TRUE)), 2)
  )
}

pretx_balance <- purrr::map_dfr(seq_len(nrow(preferred_spec_lookup)), function(i) {
  r <- preferred_spec_lookup[i,]
  compute_pretx_balance(r$outcome, r$family, r$specification, r$short_label)
})

readr::write_csv(balance_labor,  file.path(table_dir, "covariate_balance_labor_market.csv"),  na = "")
readr::write_csv(balance_consum, file.path(table_dir, "covariate_balance_consumption.csv"),   na = "")
readr::write_csv(balance_fiscal, file.path(table_dir, "covariate_balance_public_sector.csv"), na = "")
readr::write_csv(pretx_balance,  file.path(table_dir, "pretx_outcome_balance.csv"),           na = "")

# ── Top donor weights ─────────────────────────────────────────────────────────
top_weights_tbl <- purrr::map_dfr(seq_len(nrow(preferred_spec_lookup)), function(i) {
  r  <- preferred_spec_lookup[i,]
  wf <- file.path(output_root, r$family, r$specification, paste0(make_slug(r$outcome), "_weights.csv"))
  if (!file.exists(wf)) return(NULL)
  readr::read_csv(wf, show_col_types = FALSE) |>
    dplyr::arrange(dplyr::desc(.data$scm_weight)) |> dplyr::slice_head(n = 5) |>
    dplyr::mutate(short_label = r$short_label)
})
readr::write_csv(top_weights_tbl, file.path(table_dir, "top_donor_weights_by_outcome.csv"), na = "")

# ── In-space placebo ──────────────────────────────────────────────────────────
has_placebo_inspace <- file.exists(file.path(table_dir, "placebo_rank_actual_rr.csv"))
if (has_placebo_inspace) {
  placebo_rank_tbl <- readr::read_csv(file.path(table_dir, "placebo_rank_actual_rr.csv"), show_col_types = FALSE)
  placebo_md <- placebo_rank_tbl |> dplyr::transmute(
    Outcome = short_label,
    `RMSPE ratio (post/pre)` = format_num(post_pre_rmspe_ratio),
    `p-value (ratio)`   = format_num(ratio_p_value, 3),
    `p-value (abs gap)` = format_num(abs_gap_p_value, 3),
    Placebos = as.character(donor_placebo_count))
} else placebo_md <- NULL

# ── LOO placebo summary ───────────────────────────────────────────────────────
placebo_loo_dir <- file.path(output_root, "placebo_loo")
compute_loo_stats <- function(loo_file, main_path_file) {
  if (!file.exists(loo_file) || !file.exists(main_path_file)) return(NULL)
  loo  <- readr::read_csv(loo_file,       show_col_types = FALSE)
  main <- readr::read_csv(main_path_file, show_col_types = FALSE)
  main_gap <- main |> dplyr::filter(.data$analysis_period == "post") |>
    dplyr::summarise(m = mean(.data$augmented_gap, na.rm = TRUE)) |> dplyr::pull(.data$m)
  loo_gaps <- loo |> dplyr::filter(.data$analysis_period == "post") |>
    dplyr::group_by(.data$dropped_donor) |>
    dplyr::summarise(m = mean(.data$loo_gap, na.rm = TRUE), .groups = "drop") |> dplyr::pull(.data$m)
  all_g <- c(main_gap, loo_gaps); n <- length(all_g); r <- rank(all_g)[1]
  list(gap = round(main_gap, 2), rank = r, n = n,
       pval = round(min(r, n - r + 1) / n, 3),
       direction = if (main_gap >= 0) "positive" else "negative")
}

loo_specs <- list(
  list(label = "Formal hiring",      slug = "formal_hiring_balance_sa_per_100k_wap",     family = "bimonthly", spec = "sa"),
  list(label = "Retail",             slug = "retail_volume_index_sa",                    family = "bimonthly", spec = "sa"),
  list(label = "Services",           slug = "services_volume_index_sa",                  family = "bimonthly", spec = "sa"),
  list(label = "ICMS",               slug = "icms_revenue_real_pc_sa",                   family = "bimonthly", spec = "sa"),
  list(label = "Public investment",  slug = "public_investment_liquidated_real_pc_sa",   family = "bimonthly", spec = "sa"),
  list(label = "Total expenditure",  slug = "liquidated_expenditure_total_real_pc_sa",   family = "bimonthly", spec = "sa")
)
loo_results <- purrr::map_dfr(loo_specs, function(s) {
  loo_file  <- file.path(placebo_loo_dir, paste0(s$slug, "_", s$spec, "_loo_placebo.csv"))
  path_file <- file.path(output_root, s$family, s$spec, paste0(s$slug, "_path.csv"))
  st <- compute_loo_stats(loo_file, path_file)
  if (is.null(st)) return(tibble::tibble(Outcome = s$label, `Gap post` = NA_character_,
    `LOO rank` = NA_character_, `p-value (2-sided)` = NA_character_, Note = "not available"))
  near_top    <- st$rank > st$n * 0.9
  near_bottom <- st$rank <= st$n * 0.1
  note <- dplyr::case_when(
    st$pval > 0.10 ~ "Not extreme vs LOO distribution",
    near_top    & st$direction == "positive" ~ "Unusually large positive gap",
    near_top    & st$direction == "negative" ~ "Unusually large negative gap",
    near_bottom & st$direction == "positive" ~ "Unusually small positive gap",
    near_bottom & st$direction == "negative" ~ "Unusually small negative gap",
    TRUE ~ "Extreme vs LOO distribution")
  tibble::tibble(Outcome = s$label, `Gap post` = as.character(st$gap),
    `LOO rank` = paste0(st$rank, " / ", st$n),
    `p-value (2-sided)` = as.character(st$pval), Note = note)
})
readr::write_csv(loo_results, file.path(table_dir, "am_2017_01_v4_loo_placebo_summary.csv"), na = "")

# ── Effects markdown ──────────────────────────────────────────────────────────
preferred_effects_md <- effects_tbl |>
  dplyr::transmute(
    Channel = channel, Outcome = label,
    `Mean gap post`   = format_num(mean_gap_post),
    `RMSPE pre`       = format_num(augmented_rmspe_pre),
    `RMSPE post`      = format_num(augmented_rmspe_post),
    Donors = as.character(donor_count))

# ── Dynamic event strings ─────────────────────────────────────────────────────
removal_dt     <- as.Date(event$removal_date[[1]])
instability_dt <- as.Date(event$instability_start_date[[1]])
removal_year   <- lubridate::year(removal_dt)
pilot_label    <- paste0(treated_st, " ", removal_year, "-01")

excluded_states <- covariates_full |> dplyr::filter(.data$excluded_from_main_donor_pool) |>
  dplyr::pull(.data$state_abbrev) |> sort()
excluded_str <- paste0("`", excluded_states, "`", collapse = ", ")

mon_ws <- as.Date(event$monthly_window_start[[1]]); mon_we <- as.Date(event$monthly_window_end[[1]])
bim_ws <- as.Date(event$bimonthly_window_start[[1]]); bim_we <- as.Date(event$bimonthly_window_end[[1]])

# ── Report ────────────────────────────────────────────────────────────────────
report_lines <- c(
  paste0("# ", pilot_label, " V4: results report (all bimonthly + STL)"),
  "",
  paste0("Generated on ", Sys.Date(), "."),
  "",
  paste0("V4 standardizes the whole pilot to a single frequency. Starting from V2 (accountability frame), the four monthly outcomes are aggregated to bimonthly and seasonally adjusted with STL, exactly like the fiscal block. All eight outcomes now share one frequency, one SA method (STL), one window, and one estimation family. The electoral cassation is read as a corrective accountability act; the single treatment date is the effective removal, and the cassation-process months count as ordinary pre-treatment. Calendar time on the x-axis; no moving averages."),
  "",
  "## Event design",
  "",
  paste0("- Treated state: `", treated_st, "` (", state_name_val, ")."),
  paste0("- Treatment (single cut): effective removal `", removal_dt, "` (TSE final cassation decision for vote-buying)."),
  paste0("- The cassation process began `", instability_dt, "` (first TRE/TSE decision), but this is treated as pre-treatment, not a separate crisis window."),
  "",
  "## Window design",
  "",
  paste0("- All outcomes bimonthly: `", bim_ws, "` to `", bim_we, "`. Target pre-treatment = 24 bimesters (2013B3-2017B2); post-removal = 9 bimesters."),
  "- **Pre-window availability differs by outcome** and is handled per-outcome by the SCM (complete-case pre-window):",
  "  - Labor (CAGED) and consumption (PMC/PMS): data from 2007, so the full **24-bimester** pre-window is used.",
  "  - Fiscal (Siconfi/RREO) starts only at 2015B1, so the fiscal pre-window is the **maximum available = 14 bimesters** (2015B1-2017B2), not 24. It cannot be extended without pre-2015 fiscal data.",
  "- Extending labor/consumption to 24 bimesters removes the overfitting seen at 14 bimesters: their pre-fit RMSPE is now honest (e.g. formal hiring ~45, retail ~1.1) rather than near-zero. The fiscal block still has the tight 14-period pre-fit; read it with the placebo inference.",
  "",
  "## Bimonthly aggregation and seasonal adjustment",
  "",
  "- **Formal hiring and construction hiring** are flows (net balances), so the two monthly balances are SUMMED to the bimester.",
  "- **Retail and services volume indices** are index levels, so the two monthly indices are AVERAGED (the bimonthly index relative to the same monthly base is the mean of the two; summing would double the level).",
  "- A bimester is kept only when both constituent months are present and finite.",
  "- All eight bimonthly outcomes are then seasonally adjusted with STL (`stats::stl`, periodic, robust): SA series = observed minus STL seasonal component. Applied to each state's full series before windowing.",
  "- Quarterly PNADc covariates remain X-13 seasonally adjusted.",
  "- Volume indices are reindexed to 100 at the first valid observation in the pilot window after SA.",
  "- No moving averages are computed.",
  "- Robustness alternatives noted for the article: bimester fixed effects and MA(6).",
  "",
  "## Methodological strategy",
  "",
  paste0("The main donor pool excludes ", excluded_str, ". The preferred specification uses ", 27L - length(excluded_states), " eligible donors. Augmented Synthetic Control is the headline estimator; SCM weights are estimated on the pre-treatment window (everything before the removal date). Predictors are the full pre-treatment outcome path plus six structural covariates (all seasonally adjusted): unemployment rate, formalization rate, transfer dependency ratio, and health, education, and public security expenditure per capita."),
  "",
  "## Preliminary plots",
  "",
  figure_link("preliminary_labor_market.png"), "",
  figure_link("preliminary_consumption.png"), "",
  figure_link("preliminary_public_sector.png"), "",
  "## Covariate and pre-treatment outcome balance",
  "",
  "### Pre-treatment outcome fit",
  "",
  make_markdown_table(pretx_balance), "",
  "### Covariate balance: formal labor market",
  "",
  make_markdown_table(balance_labor), "",
  "### Covariate balance: household consumption",
  "",
  make_markdown_table(balance_consum), "",
  "### Covariate balance: state public finances",
  "",
  make_markdown_table(balance_fiscal), "",
  "## Main results: Augmented SCM (SA)",
  "",
  make_markdown_table(preferred_effects_md), "",
  figure_link("augmented_effect_summary.png"), "",
  "### Formal labor market",
  "",
  figure_link("augmented_paths_labor_market.png"), "",
  figure_link("augmented_gaps_labor_market.png"), "",
  "### Household consumption",
  "",
  figure_link("augmented_paths_consumption.png"), "",
  figure_link("augmented_gaps_consumption.png"), "",
  "### State public finances",
  "",
  figure_link("augmented_paths_public_sector.png"), "",
  figure_link("augmented_gaps_public_sector.png"), "",
  "## Donor weights",
  "",
  figure_link("donor_weights_labor_market.png"), "",
  figure_link("donor_weights_consumption.png"), "",
  figure_link("donor_weights_public_sector.png"), "",
  "## In-space placebos",
  "",
  if (has_placebo_inspace) {
    c("Each eligible donor is treated as pseudo-treated at the same dates; gaps are normalized by each unit's pre-treatment RMSPE.",
      "", make_markdown_table(placebo_md), "",
      figure_link("placebo_gaps_labor_market.png"), "",
      figure_link("placebo_rmspe_ratio_labor_market.png"), "",
      figure_link("placebo_gaps_consumption.png"), "",
      figure_link("placebo_rmspe_ratio_consumption.png"), "",
      figure_link("placebo_gaps_public_sector.png"), "",
      figure_link("placebo_rmspe_ratio_public_sector.png"))
  } else "In-space placebo output not yet available.",
  "",
  "## Leave-one-out donor placebo",
  "",
  make_markdown_table(loo_results), "",
  "## Current limitations",
  "",
  "- Pre-window is 24 bimesters for labor/consumption but only 14 for fiscal, because Siconfi/RREO starts at 2015B1. The fiscal pre-fit is therefore tight (low RMSPE_pre) and prone to overfitting; rely on the placebo inference, not the raw gap. This asymmetry cannot be removed without a pre-2015 fiscal source.",
  "- All seasonal adjustment is STL (freq 6). X-13 cannot process bimonthly (freq 6). Bimester fixed effects and MA(6) are reasonable robustness alternatives.",
  "- Seasonal adjustment falls back to the raw series for states/variables with too few cycles; check build log.",
  "- ICMS from Annex 06 is derived by within-year differencing; RS 2018 B1-B5 imputed with 2017 seasonal shares.",
  "- The post-removal window ends 9 bimesters after removal, by design.",
  "",
  "## Generated files",
  "",
  "- `report/tables/augmented_effects_by_outcome.csv`",
  "- `report/tables/pretx_outcome_balance.csv`",
  "- `report/tables/covariate_balance_*.csv`",
  "- `report/tables/top_donor_weights_by_outcome.csv`",
  "- `report/tables/am_2017_01_v4_loo_placebo_summary.csv`",
  if (has_placebo_inspace) "- `report/tables/placebo_rank_actual_rr.csv`" else NULL,
  "- `report/figures/` (preliminary, paths, gaps, weights, placebo)",
  "- `output/placebo_inspace/`, `output/placebo_loo/`"
)

readr::write_lines(report_lines, file.path(pilot_root, "am_2017_01_v4_results_report.md"))

run_summary_lines <- c(
  paste0("# ", pilot_label, " V4 Run Summary"),
  "",
  paste0("Run date: ", Sys.Date()),
  "",
  "## What V4 changes vs V2",
  "",
  "- All eight outcomes are now bimonthly. Monthly labor/consumption series are aggregated to bimonthly: labor balances SUMMED, volume indices AVERAGED.",
  "- Single SA method for everything: STL (freq 6). One estimation family (`bimonthly`), one window.",
  "- Target pre-window = 24 bimesters. Labor/consumption use the full 24 (data from 2007); fiscal uses the max available 14 (Siconfi starts 2015). At 24 bimesters the labor/consumption overfitting (near-zero RMSPE_pre) disappears.",
  "",
  "## Inherited from V2 (accountability frame)",
  "",
  "- Calendar-time x-axis; single treatment cut at the removal date; cassation-process months are pre-treatment.",
  "- Pre-treatment up to 24 bimesters (labor/consumption); 14 for fiscal. Post-removal 9 bimesters.",
  "",
  "## Outputs",
  "",
  paste0("- `data/", pilot_id, "_*_panel.csv`, `data/", pilot_id, "_covariates.csv`"),
  paste0("- `output/", pilot_id, "_scm_summary.csv`"),
  "- `output/placebo_inspace/`, `output/placebo_loo/`",
  paste0("- `", pilot_id, "_results_report.md`")
)
readr::write_lines(run_summary_lines, file.path(notes_dir, "run_summary.md"))

message(pilot_label, " V4 report completed.")
message("Saved report to: ", file.path(pilot_root, "am_2017_01_v4_results_report.md"))
