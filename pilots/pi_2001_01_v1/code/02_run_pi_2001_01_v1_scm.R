source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

extra_packages <- c("tidyr", "quadprog")
missing_extra  <- extra_packages[!vapply(extra_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_extra) > 0) stop("Missing packages: ", paste(missing_extra, collapse = ", "))
invisible(lapply(extra_packages, library, character.only = TRUE))

pilot_id      <- "pi_2001_01_v1"
treated_state <- "PI"
min_pre_periods <- 20L  # 36-month target; documented floor when data is shorter

pilot_root  <- file.path(root_dir, "pilots", pilot_id)
data_dir    <- file.path(pilot_root, "data")
output_root <- file.path(pilot_root, "output")
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

event <- readr::read_csv(
  file.path(data_dir, "pi_2001_01_v1_event_metadata.csv"), show_col_types = FALSE
) |>
  dplyr::slice(1) |>
  dplyr::mutate(
    instability_start_date = as.Date(.data$instability_start_date),
    removal_date           = as.Date(.data$removal_date)
  )

covariates <- readr::read_csv(
  file.path(data_dir, "pi_2001_01_v1_covariates.csv"), show_col_types = FALSE
)

main_donor_states <- covariates |>
  dplyr::filter(.data$donor_pool_main) |>
  dplyr::pull(.data$state_abbrev) |>
  sort()

covariate_data <- covariates |>
  dplyr::select(
    .data$state_abbrev,
    .data$va_icms_secundario_real_pc,
    .data$va_icms_terciario_real_pc,
    .data$va_icms_energia_real_pc,
    .data$va_icms_combustiveis_real_pc,
    .data$fpe_real_pc,
    .data$iof_est_real_pc
  )

# V1: a single monthly panel holds all 4 outcomes (X-13 SA, freq 12).
monthly_panel <- readr::read_csv(
  file.path(data_dir, "pi_2001_01_v1_monthly_panel.csv"), show_col_types = FALSE
) |> dplyr::mutate(period_date = as.Date(.data$period_date))
fiscal_panel <- monthly_panel  # alias for any legacy reference

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
  keep      <- is.finite(row_sds) & row_sds > 0
  xs        <- sweep(x[keep, , drop = FALSE], 1, row_means[keep], "-")
  xs        <- sweep(xs, 1, row_sds[keep], "/")
  list(x = xs, keep = keep)
}

standardize_units <- function(x_train, x_all) {
  col_means <- colMeans(x_train, na.rm = TRUE)
  col_sds   <- apply(x_train, 2, stats::sd, na.rm = TRUE)
  col_sds[!is.finite(col_sds) | col_sds == 0] <- 1
  list(x_all = sweep(sweep(x_all, 2, col_means, "-"), 2, col_sds, "/"))
}

solve_weights <- function(x1, x0) {
  dmat <- 2 * crossprod(x0) + diag(1e-8, ncol(x0))
  dvec <- 2 * as.numeric(crossprod(x0, x1))
  amat <- cbind(rep(1, ncol(x0)), diag(ncol(x0)))
  bvec <- c(1, rep(0, ncol(x0)))
  sol  <- quadprog::solve.QP(dmat, dvec, amat, bvec, meq = 1)
  w    <- pmax(sol$solution, 0)
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

build_predictor_matrix <- function(data, outcome, donor_states, covariate_data,
                                   weight_period = "pre") {
  states <- c(treated_state, donor_states)

  period_filter <- if (weight_period == "pre_clean") {
    quote(.data$pre_instability_clean == TRUE)
  } else {
    quote(.data$analysis_period == "pre")
  }

  pre_data <- data |>
    dplyr::filter(!!period_filter, .data$state_abbrev %in% states) |>
    dplyr::select(.data$state_abbrev, .data$period_date, value = dplyr::all_of(outcome)) |>
    tidyr::pivot_wider(names_from = .data$state_abbrev, values_from = .data$value) |>
    dplyr::arrange(.data$period_date) |>
    dplyr::filter(stats::complete.cases(dplyr::across(dplyr::all_of(states))))

  if (nrow(pre_data) < min_pre_periods) stop("Too few complete pre-treatment periods: ", outcome)

  outcome_mat <- pre_data |> dplyr::select(dplyr::all_of(states)) |> as.matrix()
  rownames(outcome_mat) <- paste0("pre_", format(pre_data$period_date, "%Y_%m_%d"))

  cov_long <- covariate_data |>
    dplyr::filter(.data$state_abbrev %in% states) |>
    tidyr::pivot_longer(-.data$state_abbrev, names_to = "pred", values_to = "val") |>
    tidyr::pivot_wider(names_from = .data$state_abbrev, values_from = .data$val) |>
    dplyr::arrange(.data$pred)

  cov_mat <- cov_long |> dplyr::select(dplyr::all_of(states)) |> as.matrix()
  rownames(cov_mat) <- paste0("cov_", cov_long$pred)

  pm <- rbind(outcome_mat, cov_mat)
  if (anyNA(pm)) stop("Missing values in predictor matrix: ", outcome)
  pm
}

fit_augmented_scm <- function(data, outcome, family, specification,
                               weight_period = "pre") {
  period_filter <- if (weight_period == "pre_clean") {
    quote(.data$pre_instability_clean == TRUE)
  } else {
    quote(.data$analysis_period == "pre")
  }

  treated_pre_dates <- data |>
    dplyr::filter(
      .data$state_abbrev == treated_state,
      !!period_filter,
      is.finite(.data[[outcome]])
    ) |>
    dplyr::arrange(.data$period_date) |>
    dplyr::pull(.data$period_date)

  if (length(treated_pre_dates) < min_pre_periods) {
    return(tibble::tibble(
      family = family, specification = specification, outcome = outcome,
      status = "skipped",
      skip_reason = paste0("Insufficient pre-treatment data (<", min_pre_periods, " months): ", outcome)
    ))
  }

  candidate_states <- intersect(
    main_donor_states,
    covariate_data$state_abbrev[stats::complete.cases(covariate_data[, -1])]
  )

  donor_states <- purrr::keep(candidate_states, function(state) {
    dp <- data |>
      dplyr::filter(
        .data$state_abbrev == state, !!period_filter,
        .data$period_date %in% treated_pre_dates
      )
    nrow(dp) == length(treated_pre_dates) && all(is.finite(dp[[outcome]]))
  })

  if (length(donor_states) < 2) {
    return(tibble::tibble(
      family = family, specification = specification, outcome = outcome,
      status = "skipped",
      skip_reason = paste0("Fewer than 2 complete donor states: ", outcome)
    ))
  }

  pm     <- build_predictor_matrix(data, outcome, donor_states, covariate_data, weight_period)
  sc     <- standardize_by_row(pm)
  x1     <- sc$x[, treated_state, drop = FALSE]
  x0     <- sc$x[, donor_states,  drop = FALSE]
  w      <- solve_weights(x1, x0)
  names(w) <- donor_states

  unit_pred  <- t(pm)
  donor_pred <- unit_pred[donor_states, , drop = FALSE]
  all_pred   <- unit_pred[c(treated_state, donor_states), , drop = FALSE]
  su         <- standardize_units(donor_pred, all_pred)
  treated_p  <- su$x_all[treated_state, , drop = FALSE]
  donor_ps   <- su$x_all[donor_states,  , drop = FALSE]
  imbalance  <- treated_p - matrix(as.numeric(t(w) %*% donor_ps), nrow = 1)

  all_states <- c(treated_state, donor_states)
  wide <- data |>
    dplyr::filter(.data$state_abbrev %in% all_states) |>
    dplyr::select(.data$period_date, .data$analysis_period, .data$state_abbrev,
                  value = dplyr::all_of(outcome)) |>
    tidyr::pivot_wider(names_from = .data$state_abbrev, values_from = .data$value) |>
    dplyr::arrange(.data$period_date) |>
    dplyr::filter(stats::complete.cases(dplyr::across(dplyr::all_of(all_states))))

  corrections <- purrr::map_dfr(seq_len(nrow(wide)), function(i) {
    yd  <- as.numeric(wide[i, donor_states, drop = TRUE])
    yc  <- mean(yd, na.rm = TRUE)
    ys  <- stats::sd(yd, na.rm = TRUE)
    if (!is.finite(ys) || ys == 0) ys <- 1
    yds <- (yd - yc) / ys
    lam <- loocv_lambda(donor_ps, yds, lambda_grid)
    co  <- fit_ridge(donor_ps, yds, lam)
    tibble::tibble(
      period_date             = wide$period_date[i],
      augmentation_correction = as.numeric(imbalance %*% co[-1]) * ys
    )
  })

  synth <- as.matrix(wide[, donor_states, drop = FALSE]) %*% w
  path  <- wide |>
    dplyr::transmute(
      .data$period_date, .data$analysis_period,
      treated_value      = .data[[treated_state]],
      scm_synthetic_value = as.numeric(synth)
    ) |>
    dplyr::left_join(corrections, by = "period_date") |>
    dplyr::mutate(
      augmented_synthetic_value = .data$scm_synthetic_value + .data$augmentation_correction,
      scm_gap       = .data$treated_value - .data$scm_synthetic_value,
      augmented_gap = .data$treated_value - .data$augmented_synthetic_value,
      outcome       = outcome
    )

  weights <- tibble::tibble(
    donor_state = donor_states,
    scm_weight  = as.numeric(w)
  ) |> dplyr::arrange(dplyr::desc(.data$scm_weight))

  rmspe <- path |>
    dplyr::group_by(.data$analysis_period) |>
    dplyr::summarise(
      scm_rmspe         = sqrt(mean(.data$scm_gap^2,       na.rm = TRUE)),
      augmented_rmspe   = sqrt(mean(.data$augmented_gap^2, na.rm = TRUE)),
      scm_mean_gap      = mean(.data$scm_gap,              na.rm = TRUE),
      augmented_mean_gap = mean(.data$augmented_gap,       na.rm = TRUE),
      n_periods         = dplyr::n(),
      .groups           = "drop"
    ) |>
    tidyr::pivot_wider(
      names_from  = .data$analysis_period,
      values_from = c(.data$scm_rmspe, .data$augmented_rmspe,
                      .data$scm_mean_gap, .data$augmented_mean_gap,
                      .data$n_periods)
    ) |>
    (\(df) {
      for (nm in c("scm_rmspe_event",    "augmented_rmspe_event",
                   "scm_mean_gap_event", "augmented_mean_gap_event",
                   "scm_rmspe_crisis",   "augmented_rmspe_crisis",
                   "scm_mean_gap_crisis","augmented_mean_gap_crisis")) {
        if (!nm %in% names(df)) df[[nm]] <- NA_real_
      }
      for (nm in c("n_periods_event", "n_periods_crisis")) {
        if (!nm %in% names(df)) df[[nm]] <- 0L
      }
      df
    })() |>
    dplyr::mutate(
      outcome      = outcome,
      donor_count  = length(donor_states),
      family       = family,
      specification = specification,
      status       = "estimated",
      skip_reason  = NA_character_
    )

  output_dir  <- file.path(output_root, family, specification)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  outcome_slug <- make_slug(outcome)
  readr::write_csv(path,    file.path(output_dir, paste0(outcome_slug, "_path.csv")),    na = "")
  readr::write_csv(weights, file.path(output_dir, paste0(outcome_slug, "_weights.csv")), na = "")

  rmspe
}

# ── LOO placebo ────────────────────────────────────────────────────────────────
run_loo_placebo <- function(data, outcome, family, specification, weight_period = "pre") {
  period_filter <- if (weight_period == "pre_clean") {
    quote(.data$pre_instability_clean == TRUE)
  } else {
    quote(.data$analysis_period == "pre")
  }

  treated_pre_dates <- data |>
    dplyr::filter(.data$state_abbrev == treated_state, !!period_filter,
                  is.finite(.data[[outcome]])) |>
    dplyr::pull(.data$period_date)

  if (length(treated_pre_dates) < min_pre_periods) return(NULL)

  full_donors <- purrr::keep(
    intersect(main_donor_states,
              covariate_data$state_abbrev[stats::complete.cases(covariate_data[, -1])]),
    function(state) {
      dp <- data |>
        dplyr::filter(.data$state_abbrev == state, !!period_filter,
                      .data$period_date %in% treated_pre_dates)
      nrow(dp) == length(treated_pre_dates) && all(is.finite(dp[[outcome]]))
    }
  )

  if (length(full_donors) < 3) return(NULL)

  all_states <- c(treated_state, full_donors)
  wide_all   <- data |>
    dplyr::filter(.data$state_abbrev %in% all_states) |>
    dplyr::select(.data$period_date, .data$analysis_period, .data$state_abbrev,
                  value = dplyr::all_of(outcome)) |>
    tidyr::pivot_wider(names_from = .data$state_abbrev, values_from = .data$value) |>
    dplyr::arrange(.data$period_date) |>
    dplyr::filter(stats::complete.cases(dplyr::across(dplyr::all_of(all_states))))

  purrr::map_dfr(full_donors, function(dropped) {
    loo_donors <- setdiff(full_donors, dropped)
    if (length(loo_donors) < 2) return(NULL)

    pm <- tryCatch(
      build_predictor_matrix(data, outcome, loo_donors, covariate_data, weight_period),
      error = function(e) NULL
    )
    if (is.null(pm)) return(NULL)

    sc   <- standardize_by_row(pm)
    x1   <- sc$x[, treated_state, drop = FALSE]
    x0   <- sc$x[, loo_donors,    drop = FALSE]
    w    <- solve_weights(x1, x0)
    names(w) <- loo_donors

    loo_states <- c(treated_state, loo_donors)
    wide <- wide_all |>
      dplyr::filter(stats::complete.cases(dplyr::across(dplyr::all_of(loo_states))))

    synth <- as.matrix(wide[, loo_donors, drop = FALSE]) %*% w
    tibble::tibble(
      dropped_donor   = dropped,
      period_date     = wide$period_date,
      analysis_period = wide$analysis_period,
      loo_gap         = wide[[treated_state]] - as.numeric(synth)
    )
  })
}

# ── Specifications ─────────────────────────────────────────────────────────────
# V1: all 4 outcomes are monthly + X-13 (freq 12). One family, one estimation spec.
specs <- list(
  list(
    data          = monthly_panel,
    family        = "monthly",
    specification = "sa",
    weight_period = "pre",
    outcomes      = c(
      "va_icms_total_real_pc_sa",
      "va_receita_tributaria_total_real_pc_sa",
      "va_icms_terciario_varejista_real_pc_sa",
      "retail_volume_index_sa"
    )
  )
)

summary_tbl <- purrr::map_dfr(specs, function(spec) {
  purrr::map_dfr(spec$outcomes, function(outcome) {
    fit_augmented_scm(
      data          = spec$data,
      outcome       = outcome,
      family        = spec$family,
      specification = spec$specification,
      weight_period = spec$weight_period
    )
  })
})

readr::write_csv(summary_tbl, file.path(output_root, "pi_2001_01_v1_scm_summary.csv"), na = "")

# ── LOO placebo ───────────────────────────────────────────────────────────────
placebo_specs <- list(
  list(data = monthly_panel, family = "monthly", specification = "sa",
       weight_period = "pre",
       outcomes = c("va_icms_total_real_pc_sa",
                    "va_receita_tributaria_total_real_pc_sa",
                    "va_icms_terciario_varejista_real_pc_sa",
                    "retail_volume_index_sa"))
)

placebo_loo_dir <- file.path(output_root, "placebo_loo")
dir.create(placebo_loo_dir, recursive = TRUE, showWarnings = FALSE)

purrr::walk(placebo_specs, function(spec) {
  purrr::walk(spec$outcomes, function(outcome) {
    loo <- run_loo_placebo(spec$data, outcome, spec$family, spec$specification, spec$weight_period)
    if (!is.null(loo) && nrow(loo) > 0) {
      out_path <- file.path(placebo_loo_dir, paste0(make_slug(outcome), "_", spec$specification, "_loo_placebo.csv"))
      readr::write_csv(loo, out_path, na = "")
      message("Saved LOO: ", basename(out_path))
    }
  })
})

message("PI 2001-01 V1 SCM completed.")
message("Saved: ", file.path(output_root, "pi_2001_01_v1_scm_summary.csv"))
