source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

pilot_id      <- "rr_2018_01_v6"
event_id      <- "RR_2018_01"
treated_state <- "RR"

pilot_root  <- file.path(root_dir, "archive", "pilots", pilot_id)
data_dir    <- file.path(pilot_root, "data")
output_root <- file.path(pilot_root, "output")
table_dir   <- file.path(pilot_root, "report", "tables")
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)

# ── Load ──────────────────────────────────────────────────────────────────────
event <- readr::read_csv(
  file.path(data_dir, "rr_2018_01_v6_event_metadata.csv"), show_col_types = FALSE
) |> dplyr::slice(1)

removal_dt <- as.Date(event$removal_date[[1]])

summary_tbl <- readr::read_csv(
  file.path(output_root, "rr_2018_01_v6_scm_summary.csv"), show_col_types = FALSE
)

covariates <- readr::read_csv(
  file.path(data_dir, "rr_2018_01_v6_covariates.csv"), show_col_types = FALSE
)

# ── Helpers ───────────────────────────────────────────────────────────────────
make_slug <- function(x) {
  x |>
    stringr::str_replace_all("[^A-Za-z0-9]+", "_") |>
    stringr::str_replace_all("_+$", "") |>
    tolower()
}

fmt   <- function(x, dg = 2) ifelse(is.na(x) | !is.finite(x), "", format(round(x, dg), nsmall = dg, big.mark = ","))
mdtab <- function(df) {
  if (nrow(df) == 0) return(character(0))
  c(paste0("| ", paste(names(df), collapse = " | "), " |"),
    paste0("| ", paste(rep("---", ncol(df)), collapse = " | "), " |"),
    apply(df, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |")))
}
fig <- function(f) paste0("![", f, "](report/figures/", f, ")")

# Opcao B for k=6: post starts at event_time = 5
POST_START <- 5L

# ── Outcome catalog ───────────────────────────────────────────────────────────
main_outcomes <- c("retail_ma6_log", "icms_conf6m_pc_log", "formal_hiring_6m_per1k")

outcome_meta <- tibble::tribble(
  ~outcome,                   ~short,                         ~label,                                               ~channel,      ~transform,
  "retail_ma6_log",           "Varejo MA6 (log)",             "Retail volume, MA6 trailing, log",                   "consumption", "log",
  "formal_hiring_6m_per1k",   "Emprego formal 6m (per 1k)",   "Net formal hiring, 6m sum, per 1,000 residents",     "labor",       "level",
  "icms_conf6m_pc_log",       "ICMS CONFAZ 6m pc (log)",      "ICMS CONFAZ per capita, 6m sum, log BRL/resident",   "fiscal",      "log"
)

channel_labels <- c(
  consumption = "Household consumption",
  labor       = "Formal labor market",
  fiscal      = "State public finances"
)

covariate_vars   <- c("unemployment_rate", "formalization_rate", "labor_income_real",
                       "transfer_dependency_ratio", "health_expenditure_real_pc",
                       "education_expenditure_real_pc", "public_security_expenditure_real_pc")
covariate_labels <- c("Unemployment rate", "Formalization rate", "Labor income (real)",
                       "Transfer dependency ratio", "Health expenditure pc",
                       "Education expenditure pc", "Public security expenditure pc")

# ── Estimated outcomes ────────────────────────────────────────────────────────
est <- summary_tbl |>
  dplyr::filter(.data$status == "estimated") |>
  dplyr::left_join(outcome_meta, by = "outcome")

# ── Effects table (primary window: w6m = [5,10]) ─────────────────────────────
effects <- est |>
  dplyr::transmute(
    Channel          = channel_labels[.data$channel],
    Outcome          = .data$label,
    `Mean gap (w6m)` = fmt(.data$att_mean_w6m),
    `RMSPE pre`      = fmt(.data$rmspe_pre),
    Donors           = as.character(.data$donor_count)
  )
readr::write_csv(effects, file.path(table_dir, "augmented_effects_by_outcome.csv"), na = "")

# ── ATT by window ─────────────────────────────────────────────────────────────
att_windows <- c("w3m", "w6m", "w12m", "w24m")

att_wide <- purrr::map_dfr(seq_len(nrow(est)), function(i) {
  r   <- est[i, ]
  row <- data.frame(Outcome = r$short)
  for (w in att_windows) {
    col      <- paste0("att_mean_", w)
    row[[w]] <- if (col %in% names(r)) fmt(r[[col]]) else ""
  }
  row
})
readr::write_csv(att_wide, file.path(table_dir, "att_by_window.csv"), na = "")

# ── Pre-treatment outcome fit ─────────────────────────────────────────────────
pretx <- purrr::map_dfr(seq_len(nrow(est)), function(i) {
  r    <- est[i, ]
  slug <- make_slug(r$outcome)
  pf   <- file.path(output_root, "monthly", paste0(slug, "_path.csv"))
  if (!file.exists(pf)) return(NULL)
  p <- readr::read_csv(pf, show_col_types = FALSE) |>
    dplyr::filter(.data$event_time < 0, is.finite(.data$augmented_gap))
  tibble::tibble(
    Outcome       = r$short,
    Treated       = fmt(mean(p$treated_value,             na.rm = TRUE)),
    Synthetic     = fmt(mean(p$augmented_synthetic_value, na.rm = TRUE)),
    `RMSPE pre`   = fmt(sqrt(mean(p$augmented_gap^2,      na.rm = TRUE))),
    `Pre periods` = as.character(nrow(p))
  )
})
readr::write_csv(pretx, file.path(table_dir, "pretx_outcome_balance.csv"), na = "")

# ── Covariate balance ─────────────────────────────────────────────────────────
treated_cov <- covariates |>
  dplyr::filter(.data$state_abbrev == treated_state) |>
  dplyr::select(dplyr::all_of(covariate_vars)) |>
  unlist()

synth_cov <- function(outcome) {
  slug <- make_slug(outcome)
  wf   <- file.path(output_root, "monthly", paste0(slug, "_weights.csv"))
  if (!file.exists(wf)) return(rep(NA_real_, length(covariate_vars)))
  w  <- readr::read_csv(wf, show_col_types = FALSE)
  dc <- covariates |>
    dplyr::filter(.data$state_abbrev %in% w$donor_state) |>
    dplyr::left_join(w, by = c("state_abbrev" = "donor_state"))
  vapply(covariate_vars, function(v) sum(dc[[v]] * dc$scm_weight, na.rm = TRUE), numeric(1))
}

bal <- data.frame(Covariate = covariate_labels, Treated = fmt(treated_cov, 3))
for (i in seq_len(nrow(est))) bal[[est$short[i]]] <- fmt(synth_cov(est$outcome[i]), 3)
readr::write_csv(bal, file.path(table_dir, "covariate_balance.csv"), na = "")

# ── LOO placebo ───────────────────────────────────────────────────────────────
loo_dir <- file.path(output_root, "placebo_loo")

loo_stat <- function(outcome) {
  slug <- make_slug(outcome)
  lf   <- file.path(loo_dir, paste0(slug, "_loo.csv"))
  pf   <- file.path(output_root, "monthly", paste0(slug, "_path.csv"))
  if (!file.exists(lf) || !file.exists(pf)) return(NULL)
  loo  <- readr::read_csv(lf, show_col_types = FALSE)
  main <- readr::read_csv(pf, show_col_types = FALSE)
  mg <- main |>
    dplyr::filter(.data$event_time >= POST_START, is.finite(.data$augmented_gap)) |>
    dplyr::summarise(m = mean(.data$augmented_gap, na.rm = TRUE)) |>
    dplyr::pull(.data$m)
  lg <- loo |>
    dplyr::filter(.data$event_time >= POST_START, is.finite(.data$loo_gap)) |>
    dplyr::group_by(.data$dropped_donor) |>
    dplyr::summarise(m = mean(.data$loo_gap, na.rm = TRUE), .groups = "drop") |>
    dplyr::pull(.data$m)
  ag <- c(mg, lg[is.finite(lg)])
  n  <- length(ag)
  rk <- rank(ag)[1]
  list(gap = round(mg, 3), rank = rk, n = n,
       pval = round(min(rk, n - rk + 1) / n, 3))
}

loo_md <- purrr::map_dfr(main_outcomes, function(o) {
  r  <- est[est$outcome == o, ]
  if (nrow(r) == 0) return(NULL)
  st <- loo_stat(o)
  if (is.null(st)) {
    return(tibble::tibble(Outcome = r$short, `Gap post` = "", `LOO rank` = "", `p (2-sided)` = ""))
  }
  tibble::tibble(
    Outcome       = r$short,
    `Gap post`    = as.character(st$gap),
    `LOO rank`    = paste0(st$rank, " / ", st$n),
    `p (2-sided)` = as.character(st$pval)
  )
})
readr::write_csv(loo_md, file.path(table_dir, "loo_placebo_summary.csv"), na = "")

# ── Evidence classification ───────────────────────────────────────────────────
THRESHOLD_LOG   <- 0.05
THRESHOLD_LEVEL <- 0.5   # per 1k residents, 6m net formal hires

thresholds <- c(
  retail_ma6_log          = THRESHOLD_LOG,
  icms_conf6m_pc_log      = THRESHOLD_LOG,
  formal_hiring_6m_per1k  = THRESHOLD_LEVEL
)

classify_tier_loo <- function(loo_p, att_w6m, att_w12m, threshold, sign_consistent) {
  if (!isTRUE(sign_consistent)) return("weak")
  thresh_met <- (is.finite(att_w6m)  && abs(att_w6m)  >= threshold) ||
                (is.finite(att_w12m) && abs(att_w12m) >= threshold)
  if (!thresh_met) return("weak")
  if (!is.finite(loo_p)) return("weak")
  if (loo_p <= 0.05) "strong"
  else if (loo_p <= 0.10) "moderate"
  else if (loo_p <= 0.15) "suggestive"
  else "weak"
}

evid <- purrr::map_dfr(seq_len(nrow(est)), function(i) {
  r    <- est[i, ]
  slug <- make_slug(r$outcome)
  pf   <- file.path(output_root, "monthly", paste0(slug, "_path.csv"))
  if (!file.exists(pf)) return(NULL)

  path <- readr::read_csv(pf, show_col_types = FALSE)
  post <- path |> dplyr::filter(.data$event_time >= POST_START, is.finite(.data$augmented_gap))
  pre  <- path |> dplyr::filter(.data$event_time < 0,           is.finite(.data$augmented_gap))

  gap_post    <- if (nrow(post) > 0) mean(post$augmented_gap, na.rm = TRUE) else NA_real_
  pre_sd      <- stats::sd(pre$treated_value, na.rm = TRUE)
  mag_sd      <- if (is.finite(pre_sd) && pre_sd > 0) abs(gap_post) / pre_sd else NA_real_
  persistence <- if (nrow(post) > 0 && is.finite(gap_post)) {
    mean(sign(post$augmented_gap) == sign(gap_post), na.rm = TRUE)
  } else NA_real_
  pre_fit_corr <- tryCatch(
    stats::cor(pre$treated_value, pre$augmented_synthetic_value), error = function(e) NA_real_
  )
  pre_rmspe_in <- sqrt(mean((pre$treated_value - pre$augmented_synthetic_value)^2, na.rm = TRUE))
  pre_fit_r2   <- if (is.finite(pre_sd) && pre_sd > 0) {
    1 - pre_rmspe_in^2 / stats::var(pre$treated_value, na.rm = TRUE)
  } else NA_real_
  pre_trend_p <- tryCatch({
    if (nrow(pre) >= 4) {
      summary(stats::lm(augmented_gap ~ as.numeric(period_date), data = pre))$coefficients[2, 4]
    } else NA_real_
  }, error = function(e) NA_real_)
  poor_fit <- !is.finite(pre_fit_corr) || pre_fit_corr < 0.70

  loo_info     <- loo_stat(r$outcome)
  loo_p        <- if (!is.null(loo_info)) loo_info$pval else NA_real_
  loo_rank_str <- if (!is.null(loo_info)) paste0(loo_info$rank, "/", loo_info$n) else NA_character_

  lf       <- file.path(loo_dir, paste0(slug, "_loo.csv"))
  loo_frac <- NA_real_
  if (file.exists(lf) && is.finite(gap_post)) {
    loo_data <- readr::read_csv(lf, show_col_types = FALSE)
    lg <- loo_data |>
      dplyr::filter(.data$event_time >= POST_START) |>
      dplyr::group_by(.data$dropped_donor) |>
      dplyr::summarise(m = mean(.data$loo_gap, na.rm = TRUE), .groups = "drop") |>
      dplyr::pull(.data$m)
    if (length(lg) > 0) loo_frac <- mean(sign(lg[is.finite(lg)]) == sign(gap_post), na.rm = TRUE)
  }

  sign_consistent <- is.finite(persistence) && persistence >= 0.5
  thresh  <- if (r$outcome %in% names(thresholds)) thresholds[[r$outcome]] else THRESHOLD_LOG
  att_w6m  <- if ("att_mean_w6m"  %in% names(r)) r$att_mean_w6m  else NA_real_
  att_w12m <- if ("att_mean_w12m" %in% names(r)) r$att_mean_w12m else NA_real_

  primary_att  <- att_w6m
  effect_label <- if (r$transform == "log" && is.finite(primary_att)) {
    paste0(formatC(100 * (exp(primary_att) - 1), format = "f", digits = 1, flag = "+"), "%")
  } else if (is.finite(primary_att)) {
    formatC(primary_att, format = "f", digits = 1, flag = "+")
  } else ""

  tier <- classify_tier_loo(loo_p, att_w6m, att_w12m, thresh, sign_consistent)

  tibble::tibble(
    outcome = r$outcome, short = r$short, channel = r$channel, transform = r$transform,
    gap_post = gap_post, effect_label = effect_label, mag_sd = mag_sd,
    persistence = persistence, pre_trend_p = pre_trend_p,
    pre_fit_corr = pre_fit_corr, pre_fit_r2 = pre_fit_r2,
    poor_fit = poor_fit, loo_rank = loo_rank_str, loo_p = loo_p,
    loo_frac = loo_frac, tier = tier,
    considerable = tier %in% c("strong", "moderate", "suggestive")
  )
})

# ── Nova Estrategia classification ────────────────────────────────────────────
get_affected <- function(o) {
  r <- evid[evid$outcome == o, ]
  if (nrow(r) == 0) return(FALSE)
  thresh  <- thresholds[[o]]
  att_w6  <- if ("att_mean_w6m"  %in% names(est)) est$att_mean_w6m[est$outcome  == o] else NA_real_
  att_w12 <- if ("att_mean_w12m" %in% names(est)) est$att_mean_w12m[est$outcome == o] else NA_real_
  thresh_met <- (is.finite(att_w6)  && abs(att_w6)  >= thresh) ||
                (is.finite(att_w12) && abs(att_w12) >= thresh)
  loo_ok <- is.finite(r$loo_frac[[1]]) && r$loo_frac[[1]] >= 0.6
  sc     <- isTRUE(r$persistence[[1]] >= 0.5)
  thresh_met && sc && loo_ok
}

retail_aff  <- get_affected("retail_ma6_log")
icms_aff    <- get_affected("icms_conf6m_pc_log")
hiring_aff  <- get_affected("formal_hiring_6m_per1k")

alcance <- dplyr::case_when(
  hiring_aff & icms_aff & retail_aff ~ "Propagado",
  icms_aff   & retail_aff            ~ "Ampliado",
  retail_aff                          ~ "Restrito",
  TRUE                                ~ "Nulo"
)

affected_which <- c(retail_aff, icms_aff, hiring_aff)
affected_list  <- main_outcomes[affected_which]
durable_any <- if (length(affected_list) == 0) FALSE else {
  purrr::map_lgl(affected_list, function(o) {
    thresh  <- thresholds[[o]]
    att_12m <- if ("att_mean_w12m" %in% names(est)) est$att_mean_w12m[est$outcome == o] else NA_real_
    att_24m <- if ("att_mean_w24m" %in% names(est)) est$att_mean_w24m[est$outcome == o] else NA_real_
    any(abs(c(att_12m, att_24m)[is.finite(c(att_12m, att_24m))]) >= thresh)
  }) |> any()
}

duracao <- if (isTRUE(durable_any)) "Persistente" else "Transitorio"

nova_class <- tibble::tibble(
  Event = event_id, Alcance = alcance, Duracao = duracao,
  Retail = as.character(retail_aff),
  ICMS   = as.character(icms_aff),
  Hiring = as.character(hiring_aff)
)
readr::write_csv(nova_class, file.path(table_dir, "nova_estrategia_classification.csv"), na = "")
readr::write_csv(evid,       file.path(table_dir, "evidence_classification.csv"),        na = "")

n_cons <- sum(evid$considerable, na.rm = TRUE)

evid_md <- evid |>
  dplyr::transmute(
    Outcome        = .data$short,
    Tier           = .data$tier,
    `Effect (w6m)` = .data$effect_label,
    `LOO p`        = fmt(.data$loo_p, 3),
    `LOO rank`     = dplyr::coalesce(.data$loo_rank, ""),
    `Mag (pre-SD)` = fmt(.data$mag_sd, 2),
    Persist        = fmt(.data$persistence, 2),
    `LOO sign`     = fmt(.data$loo_frac, 2),
    `Pre-trend p`  = fmt(.data$pre_trend_p, 2),
    `Pre corr`     = fmt(.data$pre_fit_corr, 2),
    `Pre R2`       = fmt(.data$pre_fit_r2, 2),
    `afitw`        = ifelse(.data$poor_fit, "yes", "")
  )

# ── Report ────────────────────────────────────────────────────────────────────
excluded <- covariates |>
  dplyr::filter(.data$excluded_from_main_donor_pool) |>
  dplyr::pull(.data$state_abbrev) |>
  sort()
excl_str <- paste0("`", excluded, "`", collapse = ", ")
n_don    <- 27L - length(excluded)

lines <- c(
  paste0("# ", pilot_id, " results report (nova estrategia, k=6)"), "",
  paste0("Generated on ", Sys.Date(), "."), "",
  paste0("Treated state: `RR` (Roraima). Removal: `", removal_dt, "`."), "",
  "## Window design", "",
  "- Accumulation window: **k = 6** for all outcomes.",
  "  - Retail: trailing 6-month mean, log (`retail_ma6_log`)",
  "  - Formal hiring: CAGED net balance, 6m sum, per 1,000 residents (`formal_hiring_6m_per1k`)",
  "  - ICMS: CONFAZ monthly per capita (BRL/resident), 6m sum, log (`icms_conf6m_pc_log`)",
  "- Opcao B (k=6): first clean post-treatment reading at event_time = +5.",
  "- Pre-treatment blocks: 5 non-overlapping semi-annual blocks [-30,-25], [-24,-19], [-18,-13], [-12,-7], [-6,-1].",
  "  Valid pre-treatment window: event_time -31 to -1 (31 months; first 5 observations are NA due to k=6 initialization).",
  "- ATT windows: w3m [+5,+7], w6m [+5,+10], w12m [+5,+16], w24m [+5,+28].", "",
  "## Methodological strategy", "",
  paste0("Donor pool excludes ", excl_str, " (", n_don, " eligible donors)."),
  "AugSCM with 5 non-overlapping semi-annual block-level AND block-slope predictors + 7 structural covariates (17 predictor rows total).",
  "Slope rows force the SCM to match the within-block trend direction, not just the block-mean level.",
  "Ridge penalty by LOO-CV. LOO donor placebo is the primary robustness test.",
  "LOO donor placebo is the primary robustness test.", "",
  "## Preliminary plots", "",
  fig("preliminary_main_outcomes.png"), "",
  "## Covariate and pre-treatment balance", "",
  "### Pre-treatment outcome fit", "",
  mdtab(pretx), "",
  "### Covariate balance", "",
  mdtab(bal), "",
  "## Main results: Augmented SCM", "",
  mdtab(effects), "",
  fig("att_summary.png"), "",
  fig("paths_main_outcomes.png"), "",
  fig("gaps_main_outcomes.png"), "",
  "### ATT by window", "",
  mdtab(att_wide), "",
  "## Donor weights", "",
  fig("weights_main_outcomes.png"), "",
  "## In-space placebos", "",
  "Not available in this pilot.", "",
  "## Leave-one-out donor placebo", "",
  mdtab(loo_md), "",
  "## Evidence classification", "",
  paste0("Tier: LOO rank test. Thresholds: log >= 0.05; formal_hiring_6m_per1k >= 0.5 (per 1k residents). Poor fit: pre corr < 0.70."), "",
  paste0("Considerable: **", n_cons, "** / 3."), "",
  mdtab(evid_md), "",
  "### Nova Estrategia (Alcance x Duracao)", "",
  paste0("- **Alcance**: ", alcance),
  paste0("- **Duracao**: ", duracao), "",
  "| Variable | Affected |",
  "| --- | --- |",
  paste0("| Retail MA6 (log) | ", retail_aff, " |"),
  paste0("| ICMS CONFAZ 6m per capita (log) | ", icms_aff, " |"),
  paste0("| Formal hiring 6m per 1k residents | ", hiring_aff, " |")
)

readr::write_lines(
  lines[!vapply(lines, is.null, logical(1))],
  file.path(pilot_root, "rr_2018_01_v6_results_report.md")
)
message("=== report ", pilot_id, " done (k=6, ", nrow(effects), " outcomes) ===")
