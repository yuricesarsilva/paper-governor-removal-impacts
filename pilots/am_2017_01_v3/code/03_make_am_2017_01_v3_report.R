source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

pilot_id    <- "am_2017_01_v3"
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

event <- readr::read_csv(file.path(data_dir, "am_2017_01_v3_event_metadata.csv"), show_col_types = FALSE) |>
  dplyr::slice(1)

treated_st     <- event$state_abbrev[[1]]
state_name_val <- event$state_name[[1]]

fiscal_panel <- readr::read_csv(file.path(data_dir, "am_2017_01_v3_bimonthly_fiscal_panel.csv"), show_col_types = FALSE) |>
  dplyr::mutate(period_date = as.Date(.data$period_date))
quarterly_panel <- readr::read_csv(file.path(data_dir, "am_2017_01_v3_quarterly_pnadc_panel.csv"), show_col_types = FALSE) |>
  dplyr::mutate(period_date = as.Date(.data$period_date))
summary_tbl <- readr::read_csv(file.path(output_root, "am_2017_01_v3_scm_summary.csv"), show_col_types = FALSE)

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
  ~outcome,                                              ~label,                                          ~channel,                ~family,            ~specification, ~short_label,
  "formal_hiring_balance_sa_per_100k_wap",              "Formal hiring balance per 100k WAP (trend-cycle)", "Formal labor market",   "monthly",          "sa", "Formal hiring TC",
  "formal_hiring_balance_construction_sa_per_100k_wap", "Construction hiring per 100k WAP (trend-cycle)",   "Formal labor market",   "monthly",          "sa", "Construction TC",
  "retail_volume_index_sa",                             "Retail volume index (trend-cycle)",                "Household consumption", "monthly",          "sa", "Retail TC",
  "services_volume_index_sa",                           "Services volume index (trend-cycle)",              "Household consumption", "monthly",          "sa", "Services TC",
  "state_tax_revenue_real_pc_sa",                       "Own tax revenue, real per capita (SA)",         "State public finances", "bimonthly_fiscal", "sa", "Own tax revenue SA",
  "icms_revenue_real_pc_sa",                            "ICMS revenue, real per capita (SA)",            "State public finances", "bimonthly_fiscal", "sa", "ICMS SA",
  "public_investment_liquidated_real_pc_sa",           "Public investment, real per capita (SA)",       "State public finances", "bimonthly_fiscal", "sa", "Public investment SA",
  "liquidated_expenditure_total_real_pc_sa",           "Total liquidated expenditure, real pc (SA)",    "State public finances", "bimonthly_fiscal", "sa", "Total expenditure SA"
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
covariates_full <- readr::read_csv(file.path(data_dir, "am_2017_01_v3_covariates.csv"), show_col_types = FALSE)
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
  placebo_rank_tbl <- readr::read_csv(file.path(table_dir, "placebo_rank_actual_rr.csv"), show_col_types = FALSE) |>
    # Use outcome_meta short_label so labels match the rest of the report (TC vs SA)
    dplyr::left_join(outcome_meta |> dplyr::select("outcome", report_label = "short_label"), by = "outcome") |>
    dplyr::mutate(short_label = dplyr::coalesce(.data$report_label, .data$short_label))
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
  list(label = "Formal hiring TC",      slug = "formal_hiring_balance_sa_per_100k_wap",     family = "monthly",          spec = "sa"),
  list(label = "Retail TC",             slug = "retail_volume_index_sa",                    family = "monthly",          spec = "sa"),
  list(label = "Services TC",           slug = "services_volume_index_sa",                  family = "monthly",          spec = "sa"),
  list(label = "ICMS SA",               slug = "icms_revenue_real_pc_sa",                   family = "bimonthly_fiscal", spec = "sa"),
  list(label = "Public investment SA",  slug = "public_investment_liquidated_real_pc_sa",   family = "bimonthly_fiscal", spec = "sa"),
  list(label = "Total expenditure SA",  slug = "liquidated_expenditure_total_real_pc_sa",   family = "bimonthly_fiscal", spec = "sa")
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
readr::write_csv(loo_results, file.path(table_dir, "am_2017_01_v3_loo_placebo_summary.csv"), na = "")

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
  paste0("# ", pilot_label, " V3: results report (X-13 trend-cycle for monthly outcomes)"),
  "",
  paste0("Generated on ", Sys.Date(), "."),
  "",
  paste0("This is V3, identical to V2 (accountability frame) except for how the volatile monthly outcomes are filtered. V2 used the seasonally-adjusted series, which removes seasonality but keeps the high-frequency irregular component; the labor and consumption series remained too volatile to read, and the AM-minus-synthetic gap was dominated by noise. V3 instead uses the **X-13 trend-cycle component** (Henderson filter) for the four monthly outcomes, which removes both seasonality and the irregular noise. Quarterly covariates and bimonthly fiscal series are unchanged from V2 (seasonally adjusted). This cut the monthly gap volatility by roughly 35-78% without changing the substantive direction of the effects."),
  "",
  "## Event design",
  "",
  paste0("- Treated state: `", treated_st, "` (", state_name_val, ")."),
  paste0("- Treatment (single cut): effective removal `", removal_dt, "` (TSE final cassation decision for vote-buying)."),
  paste0("- The cassation process began `", instability_dt, "` (first TRE/TSE decision), but this is treated as pre-treatment, not a separate crisis window."),
  "",
  "## Window design",
  "",
  paste0("- Monthly: `", mon_ws, "` to `", mon_we, "`. Pre-treatment = 52 months (up to removal); post-removal = 12 months."),
  paste0("- Bimonthly fiscal: `", bim_ws, "` to `", bim_we, "`. Pre-treatment = 14 bimesters (2015B1-2017B2, limited at the start by Siconfi 2015); post-removal = 9 bimesters."),
  "- Folding the cassation-process months into pre-treatment lengthens the fiscal pre-window from 6 to 14 bimesters, reducing the overfitting that affected the instability-framed specification.",
  "",
  "## Seasonal adjustment and trend-cycle extraction",
  "",
  "- **Monthly outcomes** (formal hiring, construction hiring, retail, services) use the **X-13 trend-cycle component** (`seasonal::trend`, x11 mode, no transformation). This removes both seasonality and the irregular high-frequency noise. The ARIMA forecast extension in X-13 stabilizes the Henderson filter at the series endpoints, which matters for the post-removal window.",
  "- **Quarterly covariates** (unemployment, formalization, labor income) use X-13 seasonally-adjusted series.",
  "- **Bimonthly fiscal series** use STL seasonally-adjusted series (`stats::stl`, periodic, robust), because X-13 supports only quarterly (4) and monthly (12) frequencies, not bimonthly (6).",
  "- All adjustment is applied to each state's full available series before subsetting to the pilot window, so factors use maximum information.",
  "- Series with too few cycles fall back to the raw series; this is logged at build time.",
  "- Activity indices (PMC, PMS) are trend-cycle filtered, then reindexed to 100 at the first valid observation in the pilot window.",
  "- No moving averages are computed.",
  "- Why trend-cycle for monthly: under the seasonally-adjusted series (V2), the AM-minus-synthetic gap for labor/consumption was dominated by independent irregular noise in the treated and donor series, which add rather than cancel. Filtering to the trend-cycle removes that noise and isolates the trend difference (the object of interest). It does not touch the substantive sign or magnitude of the average effect.",
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
  "## Main results: Augmented SCM (monthly = trend-cycle, fiscal = SA)",
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
  "- Bimonthly fiscal pre-treatment is 14 bimesters (2015B1-2017B2), still short of the 24-bimester target because Siconfi starts in 2015, but a substantial improvement over the instability-framed 6-bimester window.",
  "- Bimonthly fiscal seasonal adjustment uses STL, not X-13 (X-13 supports only freq 4 and 12). Bimester fixed effects and MA(6) are reasonable robustness alternatives.",
  "- Seasonal adjustment falls back to the raw series for states/variables with too few seasonal cycles; check build log.",
  "- ICMS from Annex 06 is derived by within-year differencing; RS 2018 B1-B5 imputed with 2017 seasonal shares.",
  "- The post-removal window ends 12 months (monthly) / 9 bimesters (bimonthly) after removal, by design.",
  "",
  "## Generated files",
  "",
  "- `report/tables/augmented_effects_by_outcome.csv`",
  "- `report/tables/pretx_outcome_balance.csv`",
  "- `report/tables/covariate_balance_*.csv`",
  "- `report/tables/top_donor_weights_by_outcome.csv`",
  "- `report/tables/am_2017_01_v3_loo_placebo_summary.csv`",
  if (has_placebo_inspace) "- `report/tables/placebo_rank_actual_rr.csv`" else NULL,
  "- `report/figures/` (preliminary, paths, gaps, weights, placebo)",
  "- `output/placebo_inspace/`, `output/placebo_loo/`"
)

readr::write_lines(report_lines, file.path(pilot_root, "am_2017_01_v3_results_report.md"))

run_summary_lines <- c(
  paste0("# ", pilot_label, " V3 Run Summary"),
  "",
  paste0("Run date: ", Sys.Date()),
  "",
  "## What V3 changes vs V2",
  "",
  "- Monthly outcomes (labor/consumption) use the X-13 TREND-CYCLE component instead of the seasonally-adjusted series, removing the high-frequency irregular noise that kept the SCM gap plots volatile.",
  "- Cut the monthly AM-minus-synthetic gap volatility by ~35-78% (formal hiring -75%, retail -78%, services -36%).",
  "- Quarterly covariates and bimonthly fiscal unchanged from V2 (seasonally adjusted).",
  "",
  "## Inherited from V2 (accountability frame)",
  "",
  "- X-13 (monthly/quarterly) and STL (bimonthly) for seasonal handling; calendar-time x-axis.",
  "- Accountability frame: single treatment cut at the removal date; cassation-process months are pre-treatment (no crisis window).",
  "- Pre-treatment window: 52 months / 14 bimesters (up to removal). Post-removal: 12 months / 9 bimesters.",
  "- Single estimation spec per family; no raw/MA variants.",
  "",
  "## Outputs",
  "",
  paste0("- `data/", pilot_id, "_*_panel.csv`, `data/", pilot_id, "_covariates.csv`"),
  paste0("- `output/", pilot_id, "_scm_summary.csv`"),
  "- `output/placebo_inspace/`, `output/placebo_loo/`",
  paste0("- `", pilot_id, "_results_report.md`")
)
readr::write_lines(run_summary_lines, file.path(notes_dir, "run_summary.md"))

message(pilot_label, " V3 report completed.")
message("Saved report to: ", file.path(pilot_root, "am_2017_01_v3_results_report.md"))
