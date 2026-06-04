source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

extra_packages <- c("tidyr", "quadprog")
missing_extra <- extra_packages[!vapply(extra_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_extra) > 0) stop("Missing packages: ", paste(missing_extra, collapse = ", "))
invisible(lapply(extra_packages, library, character.only = TRUE))

pilot_id     <- "am_2017_01_v1"
treated_state <- "AM"

pilot_root  <- file.path(root_dir, "pilots", pilot_id)
data_dir    <- file.path(pilot_root, "data")
output_root <- file.path(pilot_root, "output")
table_dir   <- file.path(pilot_root, "report", "tables")
placebo_dir <- file.path(output_root, "placebo_inspace")
dir.create(placebo_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(table_dir,   recursive = TRUE, showWarnings = FALSE)

covariates_raw <- readr::read_csv(
  file.path(data_dir, "am_2017_01_v1_covariates.csv"), show_col_types = FALSE
)

main_donor_states <- covariates_raw |>
  dplyr::filter(.data$donor_pool_main) |>
  dplyr::pull(.data$state_abbrev) |>
  sort()

covariates <- covariates_raw |>
  dplyr::select(-dplyr::any_of(c(
    "donor_pool_main", "excluded_from_main_donor_pool",
    "donor_pool_exclusion_reason", "monthly_pre_periods"
  )))

monthly_panel <- readr::read_csv(
  file.path(data_dir, "am_2017_01_v1_monthly_panel.csv"), show_col_types = FALSE
) |> dplyr::mutate(period_date = as.Date(.data$period_date))

fiscal_panel <- readr::read_csv(
  file.path(data_dir, "am_2017_01_v1_bimonthly_fiscal_panel.csv"), show_col_types = FALSE
) |> dplyr::mutate(period_date = as.Date(.data$period_date))

scm_summary <- readr::read_csv(
  file.path(output_root, "am_2017_01_v1_scm_summary.csv"), show_col_types = FALSE
)

make_slug <- function(x) {
  x |>
    stringr::str_replace_all("[^A-Za-z0-9]+", "_") |>
    stringr::str_replace_all("_+$", "") |>
    tolower()
}

# ── SCM helpers ──────────────────────────────────────────────────────────────

standardize_by_row <- function(x) {
  row_means <- rowMeans(x, na.rm = TRUE)
  row_sds   <- apply(x, 1, stats::sd, na.rm = TRUE)
  keep <- is.finite(row_sds) & row_sds > 0
  xs   <- sweep(x[keep, , drop = FALSE], 1, row_means[keep], "-")
  xs   <- sweep(xs, 1, row_sds[keep], "/")
  list(x = xs, keep = keep)
}

standardize_units <- function(x_train, x_all) {
  col_means <- colMeans(x_train, na.rm = TRUE)
  col_sds   <- apply(x_train, 2, stats::sd, na.rm = TRUE)
  col_sds[!is.finite(col_sds) | col_sds == 0] <- 1
  list(x_all = sweep(sweep(x_all, 2, col_means, "-"), 2, col_sds, "/"))
}

solve_weights <- function(x1, x0) {
  dmat  <- 2 * crossprod(x0) + diag(1e-8, ncol(x0))
  dvec  <- 2 * as.numeric(crossprod(x0, x1))
  amat  <- cbind(rep(1, ncol(x0)), diag(ncol(x0)))
  bvec  <- c(1, rep(0, ncol(x0)))
  sol   <- quadprog::solve.QP(dmat, dvec, amat, bvec, meq = 1)
  w     <- pmax(sol$solution, 0)
  w / sum(w)
}

fit_ridge <- function(x, y, lambda) {
  d <- cbind(1, x)
  p <- diag(ncol(d)); p[1, 1] <- 0
  as.numeric(solve(crossprod(d) + lambda * p, crossprod(d, y)))
}

predict_ridge <- function(x, coef) as.numeric(cbind(1, x) %*% coef)

loocv_lambda <- function(x, y, lambdas) {
  if (nrow(x) < 5) return(1)
  cv <- vapply(lambdas, function(lam) {
    errs <- vapply(seq_along(y), function(i) {
      co <- fit_ridge(x[-i, , drop = FALSE], y[-i], lam)
      y[i] - predict_ridge(x[i, , drop = FALSE], co)
    }, numeric(1))
    sqrt(mean(errs^2, na.rm = TRUE))
  }, numeric(1))
  lambdas[which.min(cv)]
}

lambda_grid <- 10^seq(-4, 5, length.out = 20)

# ── Generalized fit function ──────────────────────────────────────────────────

fit_ascm_for_unit <- function(data, outcome, pseudo_treated, donor_pool, covariate_data) {
  all_states  <- c(pseudo_treated, donor_pool)

  pre_data <- data |>
    dplyr::filter(.data$analysis_period == "pre", .data$state_abbrev %in% all_states) |>
    dplyr::select(.data$state_abbrev, .data$period_date, value = dplyr::all_of(outcome)) |>
    tidyr::pivot_wider(names_from = .data$state_abbrev, values_from = .data$value) |>
    dplyr::arrange(.data$period_date) |>
    dplyr::filter(stats::complete.cases(dplyr::across(dplyr::all_of(all_states))))

  if (nrow(pre_data) < 6) return(NULL)

  outcome_mat <- pre_data |> dplyr::select(dplyr::all_of(all_states)) |> as.matrix()
  rownames(outcome_mat) <- paste0("pre_", format(pre_data$period_date, "%Y_%m_%d"))

  cov_long <- covariate_data |>
    dplyr::filter(.data$state_abbrev %in% all_states) |>
    tidyr::pivot_longer(-.data$state_abbrev, names_to = "pred", values_to = "val") |>
    tidyr::pivot_wider(names_from = .data$state_abbrev, values_from = .data$val) |>
    dplyr::arrange(.data$pred)

  cov_mat <- cov_long |> dplyr::select(dplyr::all_of(all_states)) |> as.matrix()
  rownames(cov_mat) <- paste0("cov_", cov_long$pred)

  pm <- rbind(outcome_mat, cov_mat)
  if (anyNA(pm)) return(NULL)

  sc  <- standardize_by_row(pm)
  x1  <- sc$x[, pseudo_treated, drop = FALSE]
  x0  <- sc$x[, donor_pool,     drop = FALSE]
  w   <- solve_weights(x1, x0)
  names(w) <- donor_pool

  unit_pred  <- t(pm)
  donor_pred <- unit_pred[donor_pool, , drop = FALSE]
  all_pred   <- unit_pred[all_states, , drop = FALSE]
  su         <- standardize_units(donor_pred, all_pred)
  treated_p  <- su$x_all[pseudo_treated, , drop = FALSE]
  donor_ps   <- su$x_all[donor_pool,     , drop = FALSE]
  imbalance  <- treated_p - matrix(as.numeric(t(w) %*% donor_ps), nrow = 1)

  wide <- data |>
    dplyr::filter(.data$state_abbrev %in% all_states) |>
    dplyr::select(.data$period_date, .data$analysis_period, .data$state_abbrev,
                  value = dplyr::all_of(outcome)) |>
    tidyr::pivot_wider(names_from = .data$state_abbrev, values_from = .data$value) |>
    dplyr::arrange(.data$period_date) |>
    dplyr::filter(stats::complete.cases(dplyr::across(dplyr::all_of(all_states))))

  corrections <- purrr::map_dfr(seq_len(nrow(wide)), function(i) {
    yd    <- as.numeric(wide[i, donor_pool, drop = TRUE])
    yc    <- mean(yd, na.rm = TRUE)
    ys    <- stats::sd(yd, na.rm = TRUE)
    if (!is.finite(ys) || ys == 0) ys <- 1
    yd_sc <- (yd - yc) / ys
    lam   <- loocv_lambda(donor_ps, yd_sc, lambda_grid)
    co    <- fit_ridge(donor_ps, yd_sc, lam)
    corr  <- as.numeric(imbalance %*% co[-1]) * ys
    tibble::tibble(period_date = wide$period_date[i], augmentation_correction = corr)
  })

  synth <- as.matrix(wide[, donor_pool, drop = FALSE]) %*% w

  path <- wide |>
    dplyr::transmute(
      .data$period_date,
      .data$analysis_period,
      treated_value      = .data[[pseudo_treated]],
      scm_synthetic      = as.numeric(synth)
    ) |>
    dplyr::left_join(corrections, by = "period_date") |>
    dplyr::mutate(
      augmented_synthetic = .data$scm_synthetic + .data$augmentation_correction,
      augmented_gap       = .data$treated_value - .data$augmented_synthetic
    )

  rmspe <- path |>
    dplyr::group_by(.data$analysis_period) |>
    dplyr::summarise(
      pre_rmspe  = sqrt(mean(.data$augmented_gap[.data$analysis_period == "pre"]^2, na.rm = TRUE)),
      post_rmspe = sqrt(mean(.data$augmented_gap[.data$analysis_period == "post"]^2, na.rm = TRUE)),
      mean_abs_gap_post = mean(abs(.data$augmented_gap[.data$analysis_period == "post"]), na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::slice(1) |>
    dplyr::transmute(
      pre_rmspe  = sqrt(mean(path$augmented_gap[path$analysis_period == "pre"]^2,  na.rm = TRUE)),
      post_rmspe = sqrt(mean(path$augmented_gap[path$analysis_period == "post"]^2, na.rm = TRUE)),
      mean_abs_gap_post = mean(abs(path$augmented_gap[path$analysis_period == "post"]), na.rm = TRUE)
    )

  list(path = path, rmspe = rmspe)
}

# ── Preferred smooth outcome specs ───────────────────────────────────────────

preferred_specs <- tibble::tribble(
  ~outcome,                                                   ~family,            ~specification, ~channel_slug,  ~short_label,
  "formal_hiring_balance_per_100k_wap_ma6_v5",               "monthly",          "ma6_v5",       "labor_market",  "Formal hiring, MA6",
  "formal_hiring_balance_construction_per_100k_wap_ma6_v5",  "monthly",          "ma6_v5",       "labor_market",  "Construction hiring, MA6",
  "retail_volume_index_ma6_v5",                              "monthly",          "ma6_v5",       "consumption",   "Retail, MA6",
  "services_volume_index_ma6_v5",                            "monthly",          "ma6_v5",       "consumption",   "Services, MA6",
  "state_tax_revenue_real_pc_ma4_v5",                        "bimonthly_fiscal", "ma4_v5",       "public_sector", "Own tax revenue, MA4",
  "icms_revenue_real_pc_ma4_v5",                             "bimonthly_fiscal", "ma4_v5",       "public_sector", "ICMS, MA4",
  "public_investment_liquidated_real_pc_ma4_v5",             "bimonthly_fiscal", "ma4_v5",       "public_sector", "Public investment, MA4",
  "liquidated_expenditure_total_real_pc_ma4_v5",             "bimonthly_fiscal", "ma4_v5",       "public_sector", "Total expenditure, MA4"
)

get_panel <- function(family) {
  if (family == "monthly") return(monthly_panel)
  fiscal_panel
}

# ── Run placebo for all pseudo-treated states ─────────────────────────────────

message("Running in-space placebo for ", length(main_donor_states), " states × ",
        nrow(preferred_specs), " outcomes...")

all_paths   <- list()
all_rmspe   <- list()
n_completed <- 0L

for (ps in main_donor_states) {
  donor_pool <- setdiff(main_donor_states, ps)

  for (i in seq_len(nrow(preferred_specs))) {
    spec   <- preferred_specs[i, ]
    panel  <- get_panel(spec$family)

    res <- tryCatch(
      fit_ascm_for_unit(panel, spec$outcome, ps, donor_pool, covariates),
      error = function(e) NULL
    )

    if (!is.null(res)) {
      path_row <- res$path |>
        dplyr::transmute(
          pseudo_treated_state = ps,
          outcome              = spec$outcome,
          short_label          = spec$short_label,
          channel_slug         = spec$channel_slug,
          .data$period_date,
          .data$analysis_period,
          .data$augmented_gap
        )
      all_paths[[length(all_paths) + 1L]] <- path_row

      rmspe_row <- res$rmspe |>
        dplyr::mutate(
          pseudo_treated_state = ps,
          outcome              = spec$outcome,
          short_label          = spec$short_label,
          channel_slug         = spec$channel_slug
        )
      all_rmspe[[length(all_rmspe) + 1L]] <- rmspe_row

      n_completed <- n_completed + 1L
    }
  }
  message("  Completed pseudo-treated: ", ps, " (", n_completed, " models so far)")
}

placebo_paths   <- dplyr::bind_rows(all_paths)
placebo_summary <- dplyr::bind_rows(all_rmspe) |>
  dplyr::mutate(post_pre_ratio = .data$post_rmspe / .data$pre_rmspe)

readr::write_csv(placebo_paths,   file.path(placebo_dir, "placebo_paths_preferred_smooth.csv"),   na = "")
readr::write_csv(placebo_summary, file.path(placebo_dir, "placebo_summary_preferred_smooth.csv"), na = "")
message("Saved placebo paths and summary.")

# ── Compute RMSPE ratios for RR and p-values ─────────────────────────────────

# Filter scm_summary to preferred specs only, then join with preferred_specs metadata
preferred_outcomes_vec <- preferred_specs$outcome

rr_rmspe <- scm_summary |>
  dplyr::filter(
    .data$status == "estimated",
    .data$specification %in% c("ma6_v5", "ma4_v5"),
    .data$outcome %in% preferred_outcomes_vec
  ) |>
  dplyr::left_join(
    preferred_specs |> dplyr::select("outcome", "short_label", "channel_slug"),
    by = "outcome"
  ) |>
  dplyr::transmute(
    outcome       = .data$outcome,
    short_label   = .data$short_label,
    channel_slug  = .data$channel_slug,
    rr_pre_rmspe  = .data$augmented_rmspe_pre,
    rr_post_rmspe = .data$augmented_rmspe_post,
    rr_ratio      = .data$augmented_rmspe_post / .data$augmented_rmspe_pre,
    rr_abs_gap    = abs(.data$augmented_mean_gap_post)
  )

placebo_rank <- purrr::map_dfr(seq_len(nrow(rr_rmspe)), function(i) {
  row    <- rr_rmspe[i, ]
  p_rows <- placebo_summary |>
    dplyr::filter(.data$outcome == row$outcome)

  n_placebos <- nrow(p_rows)
  if (n_placebos == 0) {
    return(tibble::tibble(
      outcome = row$outcome, short_label = row$short_label, channel_slug = row$channel_slug,
      post_pre_rmspe_ratio = row$rr_ratio,
      donor_placebo_count  = 0L,
      ratio_p_value        = NA_real_,
      abs_gap_p_value      = NA_real_
    ))
  }

  ratio_p   <- mean(p_rows$post_pre_ratio >= row$rr_ratio, na.rm = TRUE)
  abs_gap_p <- mean(p_rows$mean_abs_gap_post >= row$rr_abs_gap, na.rm = TRUE)

  tibble::tibble(
    outcome              = row$outcome,
    short_label          = row$short_label,
    channel_slug         = row$channel_slug,
    post_pre_rmspe_ratio = row$rr_ratio,
    donor_placebo_count  = n_placebos,
    ratio_p_value        = ratio_p,
    abs_gap_p_value      = abs_gap_p
  )
})

readr::write_csv(placebo_rank, file.path(table_dir, "placebo_rank_actual_rr.csv"), na = "")
message("Saved placebo rank table.")

message("In-space placebo completed. Models estimated: ", n_completed)
