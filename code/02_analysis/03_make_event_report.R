# ── Event-study engine: results report (arg: event_id) ────────────────────────
# Builds the per-event tables and the markdown results report from the SCM and
# placebo outputs. Adapts to whichever outcomes qualified and to the regime's
# covariate set. Writes report/tables/*.csv and <id>_results_report.md.
#
# Usage: Rscript code/02_analysis/03_make_event_report.R <EVENT_ID>

source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))
source(file.path("code", "02_analysis", "00_event_config.R"))
source(file.path("code", "02_analysis", "00b_engine_helpers.R"))

event_id <- resolve_event_id()
d <- event_dirs(event_id)
meta <- readr::read_csv(file.path(d$data, paste0(event_id, "_event_metadata.csv")), show_col_types = FALSE) |> dplyr::slice(1)
treated_state  <- meta$state_abbrev[[1]]
state_name_val <- meta$state_name[[1]]
regime         <- meta$regime[[1]]
removal_dt     <- as.Date(meta$removal_date[[1]])

split_csv <- function(x) { x <- as.character(x); if (is.na(x) || !nzchar(x)) character(0) else strsplit(x, ",")[[1]] }
qual_monthly <- split_csv(meta$qualifying_monthly_outcomes[[1]])
qual_bim     <- split_csv(meta$qualifying_bimonthly_outcomes[[1]])
cov_vars     <- split_csv(meta$covariate_set[[1]])

fmt  <- function(x, dg = 2) ifelse(is.na(x), "", format(round(x, dg), nsmall = dg, big.mark = ","))
mdtab <- function(df) { if (nrow(df) == 0) return(character(0))
  c(paste0("| ", paste(names(df), collapse = " | "), " |"),
    paste0("| ", paste(rep("---", ncol(df)), collapse = " | "), " |"),
    apply(df, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |"))) }
fig <- function(f) paste0("![", f, "](report/figures/", f, ")")

otab <- tibble::tibble(outcome = c(qual_monthly, qual_bim),
                       family = c(rep("monthly", length(qual_monthly)), rep("bimonthly", length(qual_bim))))
order_keys <- intersect(names(outcome_catalog), otab$outcome)
otab <- otab |> dplyr::arrange(match(.data$outcome, order_keys)) |>
  dplyr::mutate(short = vapply(.data$outcome, function(k) outcome_catalog[[k]]$short, character(1)),
                label = vapply(.data$outcome, function(k) outcome_catalog[[k]]$label, character(1)),
                channel = vapply(.data$outcome, function(k) outcome_catalog[[k]]$channel, character(1)))

summary_tbl <- readr::read_csv(file.path(d$scm, paste0(event_id, "_scm_summary.csv")), show_col_types = FALSE)
covariates_full <- readr::read_csv(file.path(d$data, paste0(event_id, "_covariates.csv")), show_col_types = FALSE)

# ── Effects table ─────────────────────────────────────────────────────────────
effects <- summary_tbl |> dplyr::filter(.data$status == "estimated") |>
  dplyr::left_join(otab |> dplyr::select("outcome", "label", "channel"), by = "outcome") |>
  dplyr::transmute(Channel = channel_labels[.data$channel], Outcome = .data$label,
                   `Mean gap post` = fmt(.data$augmented_mean_gap_post),
                   `RMSPE pre` = fmt(.data$augmented_rmspe_pre),
                   `RMSPE post` = fmt(.data$augmented_rmspe_post),
                   Donors = as.character(.data$donor_count), Freq = .data$family)
readr::write_csv(effects, file.path(d$tables, "augmented_effects_by_outcome.csv"), na = "")

# ── Covariate balance (treated vs synthetic, per outcome) ─────────────────────
treated_cov <- covariates_full |> dplyr::filter(.data$state_abbrev == treated_state) |>
  dplyr::select(dplyr::all_of(cov_vars)) |> unlist()
synth_cov <- function(outcome, family) {
  wf <- file.path(d$scm, family, "sa", paste0(make_slug(outcome), "_weights.csv"))
  if (!file.exists(wf)) return(rep(NA_real_, length(cov_vars)))
  w <- readr::read_csv(wf, show_col_types = FALSE)
  dc <- covariates_full |> dplyr::filter(.data$state_abbrev %in% w$donor_state) |>
    dplyr::left_join(w, by = c("state_abbrev" = "donor_state"))
  vapply(cov_vars, function(v) sum(dc[[v]] * dc$scm_weight, na.rm = TRUE), numeric(1))
}
bal <- data.frame(Covariate = unname(covariate_labels[cov_vars]), Treated = fmt(treated_cov, 3))
for (i in seq_len(nrow(otab))) bal[[otab$short[i]]] <- fmt(synth_cov(otab$outcome[i], otab$family[i]), 3)
readr::write_csv(bal, file.path(d$tables, "covariate_balance.csv"), na = "")

# ── Pre-treatment outcome fit ─────────────────────────────────────────────────
pretx <- purrr::map_dfr(seq_len(nrow(otab)), function(i) {
  r <- otab[i, ]; pf <- file.path(d$scm, r$family, "sa", paste0(make_slug(r$outcome), "_path.csv"))
  if (!file.exists(pf)) return(NULL)
  p <- readr::read_csv(pf, show_col_types = FALSE) |> dplyr::filter(.data$analysis_period == "pre")
  tibble::tibble(Outcome = r$short, Treated = fmt(mean(p$treated_value, na.rm = TRUE)),
                 Synthetic = fmt(mean(p$augmented_synthetic_value, na.rm = TRUE)),
                 `RMSPE pre` = fmt(sqrt(mean((p$treated_value - p$augmented_synthetic_value)^2, na.rm = TRUE))),
                 `Pre periods` = as.character(nrow(p)))
})
readr::write_csv(pretx, file.path(d$tables, "pretx_outcome_balance.csv"), na = "")

# ── Top donor weights ─────────────────────────────────────────────────────────
topw <- purrr::map_dfr(seq_len(nrow(otab)), function(i) {
  r <- otab[i, ]; wf <- file.path(d$scm, r$family, "sa", paste0(make_slug(r$outcome), "_weights.csv"))
  if (!file.exists(wf)) return(NULL)
  readr::read_csv(wf, show_col_types = FALSE) |> dplyr::arrange(dplyr::desc(.data$scm_weight)) |>
    dplyr::slice_head(n = 5) |> dplyr::mutate(outcome = r$short)
})
readr::write_csv(topw, file.path(d$tables, "top_donor_weights_by_outcome.csv"), na = "")

# ── In-space placebo ──────────────────────────────────────────────────────────
prk_file <- file.path(d$tables, "placebo_rank_actual_rr.csv")
placebo_md <- NULL
if (file.exists(prk_file)) {
  prk <- readr::read_csv(prk_file, show_col_types = FALSE)
  placebo_md <- prk |> dplyr::transmute(Outcome = .data$short_label,
    `RMSPE ratio (post/pre)` = fmt(.data$post_pre_rmspe_ratio),
    `p (ratio)` = fmt(.data$ratio_p_value, 3), `p (abs gap)` = fmt(.data$abs_gap_p_value, 3),
    Placebos = as.character(.data$donor_placebo_count))
}

# ── LOO placebo ───────────────────────────────────────────────────────────────
loo_dir <- file.path(d$scm, "placebo_loo")
loo_stat <- function(outcome, family) {
  lf <- file.path(loo_dir, paste0(make_slug(outcome), "_loo_placebo.csv"))
  pf <- file.path(d$scm, family, "sa", paste0(make_slug(outcome), "_path.csv"))
  if (!file.exists(lf) || !file.exists(pf)) return(NULL)
  loo <- readr::read_csv(lf, show_col_types = FALSE); main <- readr::read_csv(pf, show_col_types = FALSE)
  mg <- main |> dplyr::filter(.data$analysis_period == "post") |> dplyr::summarise(m = mean(.data$augmented_gap, na.rm = TRUE)) |> dplyr::pull(.data$m)
  lg <- loo |> dplyr::filter(.data$analysis_period == "post") |> dplyr::group_by(.data$dropped_donor) |>
    dplyr::summarise(m = mean(.data$loo_gap, na.rm = TRUE), .groups = "drop") |> dplyr::pull(.data$m)
  ag <- c(mg, lg); n <- length(ag); rk <- rank(ag)[1]
  list(gap = round(mg, 2), rank = rk, n = n, pval = round(min(rk, n - rk + 1) / n, 3))
}
loo_md <- purrr::map_dfr(seq_len(nrow(otab)), function(i) {
  r <- otab[i, ]; st <- loo_stat(r$outcome, r$family)
  if (is.null(st)) return(tibble::tibble(Outcome = r$short, `Gap post` = "", `LOO rank` = "", `p (2-sided)` = ""))
  tibble::tibble(Outcome = r$short, `Gap post` = as.character(st$gap),
                 `LOO rank` = paste0(st$rank, " / ", st$n), `p (2-sided)` = as.character(st$pval))
})
readr::write_csv(loo_md, file.path(d$tables, "loo_placebo_summary.csv"), na = "")

# ── Evidence classification (5-criterion AugSCM ruler) ────────────────────────
evid <- build_evidence_table(event_id)
readr::write_csv(evid, file.path(d$tables, "evidence_classification.csv"), na = "")
evid_md <- if (nrow(evid) == 0) NULL else evid |>
  dplyr::arrange(match(.data$outcome, order_keys)) |>
  dplyr::transmute(
    Outcome = .data$short, Tier = .data$tier, Score = paste0(.data$robustness_score, "/5"),
    `% effect` = fmt(.data$pct_effect, 1), `Mag (pre-SD)` = fmt(.data$mag_sd, 2),
    Persist = fmt(.data$persistence, 2), `Pre-fit` = .data$prefit_class,
    `Placebo rank` = ifelse(is.na(.data$rank), "", paste0(.data$rank, "/", .data$n_units)),
    `p (rank/N)` = fmt(.data$classic_p, 3), `LOO sign` = fmt(.data$loo_frac_same_sign, 2))
n_cons <- sum(evid$considerable)

# ── Report markdown ───────────────────────────────────────────────────────────
excluded <- covariates_full |> dplyr::filter(.data$excluded_from_main_donor_pool) |> dplyr::pull(.data$state_abbrev) |> sort()
excl_str <- if (length(excluded) == 0) "(none)" else paste0("`", excluded, "`", collapse = ", ")
n_don <- 27L - length(excluded)
freq_note <- if (regime == "siconfi")
  "Fiscal outcomes (ICMS, tax revenue, public investment, total expenditure) are bimonthly from SICONFI/RREO (STL). Non-fiscal outcomes (retail, services, formal hiring, construction) are monthly (X-13)." else
  "All outcomes are monthly (X-13); fiscal outcomes (ICMS, tax revenue) are from CONFAZ."
cov_note <- if (regime == "siconfi")
  "PNADc labor covariates (unemployment, formalization, labor income) plus SICONFI transfer dependency and health/education/public-security expenditure per capita." else
  "CONFAZ ICMS sectors (secondary, tertiary, energy, fuels) plus FPE and IOF-state, real per capita."

lines <- c(
  paste0("# ", event_id, " results report (", regime, " regime)"), "",
  paste0("Generated on ", Sys.Date(), "."), "",
  paste0("Treated state: `", treated_state, "` (", state_name_val, "). Treatment (single accountability cut): effective removal `", removal_dt, "`."),
  paste0("Data regime: **", regime, "**. ", freq_note), "",
  "## Window design", "",
  paste0("- Monthly outcomes: target ", meta$monthly_pre_target, "-month pre (floor ", meta$monthly_pre_floor, "), ", meta$monthly_post, "-month post."),
  if (regime == "siconfi") paste0("- Bimonthly (SICONFI) outcomes: target ", meta$bim_pre_target, "-bimester pre (floor ", meta$bim_pre_floor, "), ", meta$bim_post, "-bimester post.") else NULL,
  "- An outcome enters only if the treated unit meets its pre-window floor and a complete post-window.", "",
  paste0("Qualifying outcomes: ", paste(otab$short, collapse = ", "), "."), "",
  "## Methodological strategy", "",
  paste0("Main donor pool excludes ", excl_str, " (any state treated anywhere in the SCM window). Preferred specification uses ", n_don, " eligible donors. Augmented SCM is the headline estimator; weights are estimated on the pre-treatment window. Predictors: the full pre-treatment outcome path plus the regime covariates: ", cov_note), "",
  "## Preliminary plots", "", fig("preliminary_outcomes.png"), "",
  "## Covariate and pre-treatment balance", "",
  "### Pre-treatment outcome fit", "", mdtab(pretx), "",
  "### Covariate balance (treated vs synthetic by outcome)", "", mdtab(bal), "",
  "## Main results: Augmented SCM (SA)", "", mdtab(effects), "", fig("augmented_effect_summary.png"), "",
  fig("augmented_paths_outcomes.png"), "", fig("augmented_gaps_outcomes.png"), "",
  "## Donor weights", "", fig("donor_weights_outcomes.png"), "",
  "## In-space placebos", "",
  if (!is.null(placebo_md)) c("Each eligible donor is treated as pseudo-treated; p = share of placebos with a post/pre RMSPE ratio (or absolute post gap) at least as large as the treated unit's.", "",
    mdtab(placebo_md), "", fig("placebo_gaps_outcomes.png"), "", fig("placebo_rmspe_ratio_outcomes.png")) else "Not available.", "",
  "## Leave-one-out donor placebo", "", mdtab(loo_md), "",
  "## Evidence classification (5-criterion AugSCM ruler)", "",
  paste0("We do not rely on placebo p-value thresholds alone. Each outcome is graded on five criteria — (C1) pre-treatment fit (treated pre-RMSPE vs the donor median, no pre-trend), (C2) substantive magnitude (post gap >= 1 pre-period SD), (C3) persistence (share of post periods keeping the gap's sign), (C4) placebo position (discrete rank/N p <= 0.15), (C5) robustness (>= 80% of leave-one-out variants keep the sign) — into a 0-5 score. Pre-fit is a hard gate: a poor pre-fit makes the effect *non-interpretable* regardless of the rest. Tiers: **strong** (5/5), **moderate** (>=4 with placebo), **suggestive** (>=3 with magnitude or placebo), **weak**, **non-interpretable**. A *considerable* effect is strong/moderate/suggestive."), "",
  paste0("Considerable effects for this event: **", n_cons, "** of ", nrow(otab), " outcomes."), "",
  if (!is.null(evid_md)) mdtab(evid_md) else "Not available.", "",
  paste0("Note: placebo-based inference in synthetic control is discrete and low-resolution with few donors (here the finest p is ~1/N). Results with p slightly above conventional thresholds but a high placebo rank, good pre-fit, substantive magnitude and persistence are read as *suggestive* evidence, not as conventional statistical significance."), ""
)
readr::write_lines(lines[!vapply(lines, is.null, logical(1))], file.path(d$root, paste0(event_id, "_results_report.md")))
message("=== report ", event_id, " done (", nrow(effects), " outcomes) ===")
