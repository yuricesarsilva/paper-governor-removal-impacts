source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

pilot_id    <- "pi_2001_01_v1"
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

event <- readr::read_csv(file.path(data_dir, "pi_2001_01_v1_event_metadata.csv"), show_col_types = FALSE) |>
  dplyr::slice(1)

treated_st     <- event$state_abbrev[[1]]
state_name_val <- event$state_name[[1]]

monthly_panel <- readr::read_csv(file.path(data_dir, "pi_2001_01_v1_monthly_panel.csv"), show_col_types = FALSE) |>
  dplyr::mutate(period_date = as.Date(.data$period_date))
summary_tbl <- readr::read_csv(file.path(output_root, "pi_2001_01_v1_scm_summary.csv"), show_col_types = FALSE)

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

# ── Outcome metadata (all monthly + X-13 SA) ──────────────────────────────────
outcome_meta <- tibble::tribble(
  ~outcome,                                  ~label,                                       ~channel,                   ~channel_slug, ~family,   ~specification, ~short_label,
  "va_icms_total_real_pc_sa",               "ICMS total value added, real per capita",     "State tax base (ICMS VA)", "tax_base",    "monthly", "sa", "ICMS total VA",
  "va_receita_tributaria_total_real_pc_sa", "Tax revenue value added, real per capita",    "State tax base (ICMS VA)", "tax_base",    "monthly", "sa", "Tax revenue VA",
  "va_icms_terciario_varejista_real_pc_sa", "ICMS retail-trade VA, real per capita",       "State tax base (ICMS VA)", "tax_base",    "monthly", "sa", "ICMS retail VA",
  "retail_volume_index_sa",                 "Retail volume index (PMC)",                   "Household consumption",    "consumption", "monthly", "sa", "Retail volume"
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
covariates_full <- readr::read_csv(file.path(data_dir, "pi_2001_01_v1_covariates.csv"), show_col_types = FALSE)
covariate_vars <- c("va_icms_secundario_real_pc", "va_icms_terciario_real_pc",
                    "va_icms_energia_real_pc", "va_icms_combustiveis_real_pc",
                    "fpe_real_pc", "iof_est_real_pc")
covariate_labels <- c("ICMS secondary VA pc (SA)", "ICMS tertiary VA pc (SA)",
                      "ICMS energy VA pc (SA)", "ICMS fuels VA pc (SA)",
                      "FPE transfer pc (SA)", "IOF-state pc (SA)")

treated_covs <- covariates_full |> dplyr::filter(.data$state_abbrev == treated_st) |>
  dplyr::select(dplyr::all_of(covariate_vars)) |> as.list()

preferred_spec_lookup <- outcome_meta |> dplyr::select("outcome", "family", "specification", "short_label", "channel", "channel_slug")

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
  if (nrow(odf) == 0) return(data.frame())
  treated_row <- sapply(covariate_vars, function(v) treated_covs[[v]])
  synth_mat   <- do.call(cbind, purrr::map(seq_len(nrow(odf)), function(i)
    compute_synth_covs(odf$outcome[i], odf$family[i], odf$specification[i])))
  colnames(synth_mat) <- odf$short_label
  cbind(Covariate = covariate_labels, Treated = format_num(treated_row, 4),
        as.data.frame(apply(synth_mat, 2, function(x) format_num(x, 4))))
}

balance_taxbase <- balance_channel(preferred_spec_lookup |> dplyr::filter(.data$channel_slug == "tax_base"))
balance_consum  <- balance_channel(preferred_spec_lookup |> dplyr::filter(.data$channel_slug == "consumption"))

compute_pretx_balance <- function(outcome, family, specification, short_label) {
  pf <- file.path(output_root, family, specification, paste0(make_slug(outcome), "_path.csv"))
  if (!file.exists(pf)) return(NULL)
  p <- readr::read_csv(pf, show_col_types = FALSE) |> dplyr::filter(.data$analysis_period == "pre")
  tibble::tibble(
    Outcome     = short_label,
    Treated     = format_num(mean(p$treated_value, na.rm = TRUE), 2),
    Synthetic   = format_num(mean(p$augmented_synthetic_value, na.rm = TRUE), 2),
    `RMSPE pre` = format_num(sqrt(mean((p$treated_value - p$augmented_synthetic_value)^2, na.rm = TRUE)), 2),
    `Pre periods` = as.character(nrow(p))
  )
}
pretx_balance <- purrr::map_dfr(seq_len(nrow(preferred_spec_lookup)), function(i) {
  r <- preferred_spec_lookup[i,]
  compute_pretx_balance(r$outcome, r$family, r$specification, r$short_label)
})

readr::write_csv(balance_taxbase, file.path(table_dir, "covariate_balance_tax_base.csv"),   na = "")
readr::write_csv(balance_consum,  file.path(table_dir, "covariate_balance_consumption.csv"), na = "")
readr::write_csv(pretx_balance,   file.path(table_dir, "pretx_outcome_balance.csv"),         na = "")

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
  list(label = "ICMS total VA",   slug = "va_icms_total_real_pc_sa",               family = "monthly", spec = "sa"),
  list(label = "Tax revenue VA",  slug = "va_receita_tributaria_total_real_pc_sa", family = "monthly", spec = "sa"),
  list(label = "ICMS retail VA",  slug = "va_icms_terciario_varejista_real_pc_sa", family = "monthly", spec = "sa"),
  list(label = "Retail volume",   slug = "retail_volume_index_sa",                 family = "monthly", spec = "sa")
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
readr::write_csv(loo_results, file.path(table_dir, "pi_2001_01_v1_loo_placebo_summary.csv"), na = "")

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
excluded_str <- if (length(excluded_states) == 0) "(none)" else paste0("`", excluded_states, "`", collapse = ", ")

mon_ws <- as.Date(event$monthly_window_start[[1]]); mon_we <- as.Date(event$monthly_window_end[[1]])
pre_target <- event$pre_target_months[[1]]; pre_floor <- event$pre_floor_months[[1]]; post_m <- event$post_months[[1]]
n_donors   <- 27L - length(excluded_states)

# ── Report ────────────────────────────────────────────────────────────────────
report_lines <- c(
  paste0("# ", pilot_label, " V1: results report (monthly, X-13)"),
  "",
  paste0("Generated on ", Sys.Date(), "."),
  "",
  paste0("PI 2001-01 is the first pilot built on the new CONFAZ ICMS value-added and Tesouro Transparente obligatory-transfer data, which reach back to the 1990s and let us study a pre-2007 accountability event. The design follows the V4 accountability template but at MONTHLY frequency with X-13ARIMA-SEATS seasonal adjustment. The TSE electoral cassation of Governor Mao Santa is read as a corrective accountability act; the single treatment date is the effective removal, and there is no separate crisis window. Calendar time on the x-axis; no moving averages."),
  "",
  "## Event design",
  "",
  paste0("- Treated state: `", treated_st, "` (", state_name_val, ")."),
  paste0("- Treatment (single cut): effective removal `", removal_dt, "` (TSE electoral cassation for the 1998 gubernatorial mandate)."),
  paste0("- Accountability frame: the cassation IS the treatment. Instability start and removal coincide (`", instability_dt, "`), so there is no pre-removal crisis window to model."),
  "",
  "## Window design",
  "",
  paste0("- All outcomes monthly: `", mon_ws, "` to `", mon_we, "`."),
  paste0("- Pre-treatment target = **", pre_target, " months** (default). Post-treatment = **", post_m, " months** (`", removal_dt, "` onward)."),
  paste0("- When an outcome's data does not reach ", pre_target, " months, the SCM uses the maximum available down to a documented **floor of ", pre_floor, " months**; outcomes below the floor are skipped."),
  "  - CONFAZ ICMS value added: full coverage, **36 pre-months** used.",
  "  - PMC retail volume index: PI series starts 2000-01, so **22 pre-months** are used (>= 20 floor).",
  "",
  "## Seasonal adjustment and real per-capita scaling",
  "",
  "- Every series is monthly, so seasonal adjustment is **X-13ARIMA-SEATS** (`seasonal::seas`, `final()`), applied to each state's full series before windowing. States/variables where X-13 fails (e.g. near-constant IOF-state) fall back to the raw series.",
  paste0("- Monetary outcomes and covariates are deflated to real R$ with the national IPCA index (", event$deflation[[1]], ") and divided by resident population (", event$per_capita[[1]], ")."),
  "- The retail volume index is an index level (not deflated/per-capita); it is reindexed to 100 at the first valid observation in the pilot window after SA.",
  "- No moving averages are computed.",
  "",
  "## Outcomes and covariates",
  "",
  "- **Outcomes (real per capita, X-13 SA):** ICMS total VA, tax-revenue total VA, ICMS retail-trade VA, and the PMC retail volume index.",
  "- **Covariates (real per capita, X-13 SA, pre-treatment means):** the own outcome's full pre-treatment path (lags) plus ICMS secondary VA, ICMS tertiary VA, ICMS energy VA, ICMS fuels VA, FPE transfer, and IOF-state.",
  "",
  "## Methodological strategy",
  "",
  paste0("The main donor pool excludes ", excluded_str, " (any state that is itself treated anywhere in the SCM window, pre or post). The preferred specification uses ", n_donors, " eligible donors. Augmented Synthetic Control is the headline estimator; SCM weights are estimated on the pre-treatment window. Predictors are the full pre-treatment outcome path plus the six structural covariates above."),
  "",
  "## Preliminary plots",
  "",
  "All four outcomes are shown together in a single 2x2 panel (ICMS total VA, tax-revenue VA, ICMS retail VA, retail volume).",
  "",
  figure_link("preliminary_outcomes.png"), "",
  "## Covariate and pre-treatment outcome balance",
  "",
  "### Pre-treatment outcome fit",
  "",
  make_markdown_table(pretx_balance), "",
  "### Covariate balance: state tax base (ICMS VA)",
  "",
  make_markdown_table(balance_taxbase), "",
  "### Covariate balance: household consumption",
  "",
  make_markdown_table(balance_consum), "",
  "## Main results: Augmented SCM (SA)",
  "",
  make_markdown_table(preferred_effects_md), "",
  figure_link("augmented_effect_summary.png"), "",
  "### Augmented SCM paths and gaps (all outcomes)",
  "",
  figure_link("augmented_paths_outcomes.png"), "",
  figure_link("augmented_gaps_outcomes.png"), "",
  "## Donor weights",
  "",
  figure_link("donor_weights_outcomes.png"), "",
  "## In-space placebos",
  "",
  if (has_placebo_inspace) {
    c("Each eligible donor is treated as pseudo-treated at the same dates; gaps are normalized by each unit's pre-treatment RMSPE. The p-value is the share of donor placebos with a post/pre RMSPE ratio (or absolute post gap) at least as large as the treated unit's.",
      "", make_markdown_table(placebo_md), "",
      figure_link("placebo_gaps_outcomes.png"), "",
      figure_link("placebo_rmspe_ratio_outcomes.png"))
  } else "In-space placebo output not yet available.",
  "",
  "## Leave-one-out donor placebo",
  "",
  make_markdown_table(loo_results), "",
  "## Current limitations",
  "",
  paste0("- Retail (PMC) has only 22 pre-months (vs 36 for the ICMS outcomes) because the PI PMC series starts in 2000-01. This is above the ", pre_floor, "-month floor but the retail pre-fit is shorter than the fiscal block's."),
  "- IOF-state is near-zero for most states in this era, so it carries little weight as a covariate (dropped by the row standardization when its cross-state variance is degenerate).",
  "- IPCA is chained across the 1990s currency reforms; within-window real ratios are valid, but absolute real-R$ levels are anchored to the removal month, not a recent base.",
  "- The post-removal window ends 24 months after removal, by design.",
  "",
  "## Generated files",
  "",
  "- `report/tables/augmented_effects_by_outcome.csv`",
  "- `report/tables/pretx_outcome_balance.csv`",
  "- `report/tables/covariate_balance_*.csv`",
  "- `report/tables/top_donor_weights_by_outcome.csv`",
  "- `report/tables/pi_2001_01_v1_loo_placebo_summary.csv`",
  if (has_placebo_inspace) "- `report/tables/placebo_rank_actual_rr.csv`" else NULL,
  "- `report/figures/` (preliminary, paths, gaps, weights, placebo)",
  "- `output/placebo_inspace/`, `output/placebo_loo/`"
)
readr::write_lines(report_lines, file.path(pilot_root, "pi_2001_01_v1_results_report.md"))

run_summary_lines <- c(
  paste0("# ", pilot_label, " V1 Run Summary"),
  "",
  paste0("Run date: ", Sys.Date()),
  "",
  "## What V1 (PI 2001) does",
  "",
  "- First pilot on CONFAZ ICMS value-added + Tesouro Transparente transfers (1990s coverage), enabling a pre-2007 accountability event.",
  "- Monthly frequency throughout with X-13ARIMA-SEATS seasonal adjustment (freq 12).",
  paste0("- Pre-treatment target ", pre_target, " months, floor ", pre_floor, "; post ", post_m, " months. Single accountability cut at the removal date."),
  "- Outcomes (real pc, SA): ICMS total VA, tax-revenue VA, ICMS retail VA, PMC retail volume. Covariates (real pc, SA): own lags + ICMS secondary/tertiary/energy/fuels VA, FPE, IOF-state.",
  "- Donor pool excludes any state treated anywhere in the SCM window (pre or post).",
  "",
  "## Outputs",
  "",
  paste0("- `data/", pilot_id, "_monthly_panel.csv`, `data/", pilot_id, "_covariates.csv`, `data/", pilot_id, "_event_metadata.csv`"),
  paste0("- `output/", pilot_id, "_scm_summary.csv`"),
  "- `output/placebo_inspace/`, `output/placebo_loo/`",
  paste0("- `", pilot_id, "_results_report.md`")
)
readr::write_lines(run_summary_lines, file.path(notes_dir, "run_summary.md"))

message(pilot_label, " V1 report completed.")
message("Saved report to: ", file.path(pilot_root, "pi_2001_01_v1_results_report.md"))
