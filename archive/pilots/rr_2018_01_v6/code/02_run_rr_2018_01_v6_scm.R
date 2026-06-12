source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

extra_packages <- c("tidyr", "quadprog")
missing_extra <- extra_packages[!vapply(extra_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_extra) > 0) stop("Missing packages: ", paste(missing_extra, collapse = ", "))
invisible(lapply(extra_packages, library, character.only = TRUE))

pilot_id      <- "rr_2018_01_v6"
treated_state <- "RR"

pilot_root  <- file.path(root_dir, "archive", "pilots", pilot_id)
data_dir    <- file.path(pilot_root, "data")
output_root <- file.path(pilot_root, "output")
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

# ── Load panels ───────────────────────────────────────────────────────────────
event <- readr::read_csv(
  file.path(data_dir, "rr_2018_01_v6_event_metadata.csv"), show_col_types = FALSE
) |> dplyr::slice(1)

covariates <- readr::read_csv(
  file.path(data_dir, "rr_2018_01_v6_covariates.csv"), show_col_types = FALSE
)

monthly_panel <- readr::read_csv(
  file.path(data_dir, "rr_2018_01_v6_monthly_panel.csv"), show_col_types = FALSE
) |> dplyr::mutate(period_date = as.Date(.data$period_date))

main_donor_states <- covariates |>
  dplyr::filter(.data$donor_pool_main) |>
  dplyr::pull(.data$state_abbrev) |>
  sort()

covariate_vars <- c(
  "unemployment_rate", "formalization_rate", "labor_income_real",
  "transfer_dependency_ratio", "health_expenditure_real_pc",
  "education_expenditure_real_pc", "public_security_expenditure_real_pc"
)

covariate_data <- covariates |>
  dplyr::select(dplyr::all_of(c("state_abbrev", covariate_vars)))

# ── Block predictor definitions ───────────────────────────────────────────────
monthly_blocks <- list(
  list(name = "block_m30_m25", start = -30L, end = -25L),
  list(name = "block_m24_m19", start = -24L, end = -19L),
  list(name = "block_m18_m13", start = -18L, end = -13L),
  list(name = "block_m12_m7",  start = -12L, end =  -7L),
  list(name = "block_m6_m1",   start =  -6L, end =  -1L)
)

# ── ATT window definitions ────────────────────────────────────────────────────
# Opção B for k=6: first clean post-treatment reading at event_time = +5
# (trailing 6-month window at +5 covers months 0,1,2,3,4,5 — all post-removal)
monthly_windows <- list(
  list(name = "w3m",  start = 5L,  end = 7L),
  list(name = "w6m",  start = 5L,  end = 10L),
  list(name = "w12m", start = 5L,  end = 16L),
  list(name = "w24m", start = 5L,  end = 28L)
)

# ── Core SCM functions ────────────────────────────────────────────────────────
make_slug <- function(x) {
  x |>
    stringr::str_replace_all("[^A-Za-z0-9]+", "_") |>
    stringr::str_replace_all("_+$", "") |>
    tolower()
}

standardize_rows <- function(x) {
  row_means <- rowMeans(x, na.rm = TRUE)
  row_sds   <- apply(x, 1, stats::sd, na.rm = TRUE)
  keep      <- is.finite(row_sds) & row_sds > 0
  x_sc      <- sweep(x[keep, , drop = FALSE], 1, row_means[keep], "-")
  x_sc      <- sweep(x_sc, 1, row_sds[keep], "/")
  list(x = x_sc, keep = keep)
}

standardize_cols_by_train <- function(x_train, x_all) {
  col_means <- colMeans(x_train, na.rm = TRUE)
  col_sds   <- apply(x_train, 2, stats::sd, na.rm = TRUE)
  col_sds[!is.finite(col_sds) | col_sds == 0] <- 1
  sweep(sweep(x_all, 2, col_means, "-"), 2, col_sds, "/")
}

solve_scm_weights <- function(x1, x0) {
  dmat <- 2 * crossprod(x0) + diag(1e-8, ncol(x0))
  dvec <- 2 * as.numeric(crossprod(x0, x1))
  amat <- cbind(rep(1, ncol(x0)), diag(ncol(x0)))
  bvec <- c(1, rep(0, ncol(x0)))
  sol  <- quadprog::solve.QP(dmat, dvec, amat, bvec, meq = 1)
  w    <- pmax(sol$solution, 0)
  w / sum(w)
}

fit_ridge <- function(x, y, lambda) {
  des <- cbind(intercept = 1, x)
  pen <- diag(ncol(des)); pen[1, 1] <- 0
  as.numeric(solve(crossprod(des) + lambda * pen, crossprod(des, y)))
}

predict_ridge <- function(x, coef) as.numeric(cbind(1, x) %*% coef)

loocv_lambda <- function(x_train, y_train, lambdas) {
  if (nrow(x_train) < 5) return(tibble::tibble(lambda = 1, cv_rmse = NA_real_))
  cv <- purrr::map_dfr(lambdas, function(lambda) {
    errs <- purrr::map_dbl(seq_along(y_train), function(i) {
      coef  <- fit_ridge(x_train[-i, , drop = FALSE], y_train[-i], lambda)
      y_hat <- predict_ridge(x_train[i, , drop = FALSE], coef)
      y_train[i] - y_hat
    })
    tibble::tibble(lambda = lambda, cv_rmse = sqrt(mean(errs^2, na.rm = TRUE)))
  })
  cv |> dplyr::arrange(.data$cv_rmse, .data$lambda) |> dplyr::slice(1)
}

# ── Block predictor matrix with level AND slope rows ──────────────────────────
build_block_predictor_matrix <- function(data, outcome, etime_col, donor_states, blocks) {
  states <- c(treated_state, donor_states)

  # Level rows: mean of outcome within each block
  level_rows <- purrr::map(blocks, function(b) {
    vals <- purrr::map_dbl(states, function(s) {
      data |>
        dplyr::filter(
          .data$state_abbrev == s,
          .data[[etime_col]] >= b$start,
          .data[[etime_col]] <= b$end
        ) |>
        dplyr::pull(dplyr::all_of(outcome)) |>
        (\(v) mean(v[is.finite(v)], na.rm = TRUE))()
    })
    setNames(vals, states)
  })
  level_matrix <- do.call(rbind, level_rows)
  rownames(level_matrix) <- purrr::map_chr(blocks, "name")

  # Slope rows: OLS slope of outcome on event_time within each block
  # Forces SCM to match within-block trend direction, not just level
  slope_rows <- purrr::map(blocks, function(b) {
    vals <- purrr::map_dbl(states, function(s) {
      sub <- data |>
        dplyr::filter(
          .data$state_abbrev == s,
          .data[[etime_col]] >= b$start,
          .data[[etime_col]] <= b$end
        )
      y <- sub[[outcome]]
      t <- sub[[etime_col]]
      ok <- is.finite(y) & is.finite(t)
      if (sum(ok) < 2) return(NA_real_)
      tryCatch(
        stats::lm.fit(cbind(1, t[ok]), y[ok])$coefficients[[2]],
        error = function(e) NA_real_
      )
    })
    setNames(vals, states)
  })
  slope_matrix <- do.call(rbind, slope_rows)
  rownames(slope_matrix) <- paste0(purrr::map_chr(blocks, "name"), "_slope")

  cov_matrix <- covariate_data |>
    dplyr::filter(.data$state_abbrev %in% states) |>
    tidyr::pivot_longer(-"state_abbrev", names_to = "pred", values_to = "val") |>
    tidyr::pivot_wider(names_from = "state_abbrev", values_from = "val") |>
    dplyr::arrange(.data$pred)
  cov_vals <- cov_matrix |>
    dplyr::select(dplyr::all_of(states)) |>
    as.matrix()
  rownames(cov_vals) <- paste0("cov_", cov_matrix$pred)

  # 5 level + 5 slope + 7 covariates = 17 predictor rows
  rbind(level_matrix, slope_matrix, cov_vals)
}

# ── Augmented SCM estimator ───────────────────────────────────────────────────
fit_augscm <- function(data, outcome, etime_col, blocks) {
  lambda_grid <- 10^seq(-4, 5, length.out = 20)

  core_block <- blocks[[which(purrr::map_chr(blocks, "name") == "block_m12_m7")[[1]]]]

  candidate_states <- intersect(
    main_donor_states,
    covariate_data$state_abbrev[stats::complete.cases(covariate_data[, -1])]
  )

  donor_states <- purrr::keep(candidate_states, function(s) {
    vals <- data |>
      dplyr::filter(
        .data$state_abbrev == s,
        .data[[etime_col]] >= core_block$start,
        .data[[etime_col]] <= core_block$end
      ) |>
      dplyr::pull(dplyr::all_of(outcome))
    any(is.finite(vals))
  })

  if (length(donor_states) < 2) {
    return(list(status = "skipped", skip_reason = paste0("< 2 donors for ", outcome)))
  }

  pm <- build_block_predictor_matrix(data, outcome, etime_col, donor_states, blocks)
  if (anyNA(pm)) pm[!is.finite(pm)] <- 0

  scaled <- standardize_rows(pm)
  x1     <- scaled$x[, treated_state, drop = FALSE]
  x0     <- scaled$x[, donor_states,  drop = FALSE]
  scm_w  <- solve_scm_weights(x1, x0)
  names(scm_w) <- donor_states

  unit_pred   <- t(pm)
  donor_pred  <- unit_pred[donor_states, , drop = FALSE]
  all_pred    <- unit_pred[c(treated_state, donor_states), , drop = FALSE]
  scaled_unit <- standardize_cols_by_train(donor_pred, all_pred)
  treat_p     <- scaled_unit[treated_state, , drop = FALSE]
  donor_p     <- scaled_unit[donor_states, , drop = FALSE]
  w_donor_p   <- matrix(as.numeric(t(scm_w) %*% donor_p), nrow = 1)
  imbalance   <- treat_p - w_donor_p

  states_needed <- c(treated_state, donor_states)
  wide <- data |>
    dplyr::filter(.data$state_abbrev %in% states_needed) |>
    dplyr::select("period_date", "state_abbrev", dplyr::all_of(etime_col),
                  value = dplyr::all_of(outcome)) |>
    tidyr::pivot_wider(names_from = "state_abbrev", values_from = "value") |>
    dplyr::arrange(dplyr::all_of(etime_col)) |>
    dplyr::filter(stats::complete.cases(dplyr::across(dplyr::all_of(states_needed))))

  correction_rows <- purrr::map_dfr(seq_len(nrow(wide)), function(i) {
    y_d  <- as.numeric(wide[i, donor_states, drop = TRUE])
    y_c  <- mean(y_d, na.rm = TRUE)
    y_s  <- stats::sd(y_d, na.rm = TRUE)
    if (!is.finite(y_s) || y_s == 0) y_s <- 1
    y_ds <- (y_d - y_c) / y_s
    best_lam <- loocv_lambda(donor_p, y_ds, lambda_grid)
    coef     <- fit_ridge(donor_p, y_ds, best_lam$lambda)
    corr_s   <- as.numeric(imbalance %*% coef[-1])
    tibble::tibble(
      period_date = wide$period_date[[i]],
      !!etime_col := wide[[etime_col]][[i]],
      augmentation_correction = corr_s * y_s,
      augmentation_lambda     = best_lam$lambda
    )
  })

  scm_synthetic <- as.matrix(wide[, donor_states, drop = FALSE]) %*% scm_w

  path <- wide |>
    dplyr::transmute(
      period_date         = .data$period_date,
      !!etime_col        := .data[[etime_col]],
      treated_value       = .data[[treated_state]],
      scm_synthetic_value = as.numeric(scm_synthetic)
    ) |>
    dplyr::left_join(correction_rows, by = c("period_date", etime_col)) |>
    dplyr::mutate(
      augmented_synthetic_value = .data$scm_synthetic_value + .data$augmentation_correction,
      scm_gap       = .data$treated_value - .data$scm_synthetic_value,
      augmented_gap = .data$treated_value - .data$augmented_synthetic_value,
      outcome       = outcome
    )

  weights <- tibble::tibble(
    donor_state = donor_states,
    scm_weight  = as.numeric(scm_w)
  ) |> dplyr::arrange(dplyr::desc(.data$scm_weight))

  list(status = "estimated", path = path, weights = weights,
       donor_states = donor_states, imbalance = imbalance, donor_pred = donor_p)
}

# ── Window ATT computation ────────────────────────────────────────────────────
compute_window_att <- function(path, etime_col, windows) {
  purrr::map_dfr(windows, function(w) {
    gaps <- path |>
      dplyr::filter(
        .data[[etime_col]] >= w$start,
        .data[[etime_col]] <= w$end,
        is.finite(.data$augmented_gap)
      ) |>
      dplyr::pull(.data$augmented_gap)

    if (length(gaps) == 0) {
      return(tibble::tibble(window = w$name, n_periods = 0L,
                            att_mean = NA_real_, sign_consistent = NA))
    }
    att_mean <- mean(gaps)
    frac_same_sign <- if (is.finite(att_mean) && att_mean != 0) {
      mean(sign(gaps) == sign(att_mean))
    } else NA_real_

    tibble::tibble(
      window          = w$name,
      n_periods       = length(gaps),
      att_mean        = att_mean,
      sign_consistent = frac_same_sign >= 0.5
    )
  })
}

# ── LOO placebo ───────────────────────────────────────────────────────────────
run_loo_placebo <- function(data, outcome, etime_col, donor_states, blocks) {
  if (length(donor_states) < 3) return(NULL)

  states_needed <- c(treated_state, donor_states)
  wide_full <- data |>
    dplyr::filter(.data$state_abbrev %in% states_needed) |>
    dplyr::select("period_date", "state_abbrev", dplyr::all_of(etime_col),
                  value = dplyr::all_of(outcome)) |>
    tidyr::pivot_wider(names_from = "state_abbrev", values_from = "value") |>
    dplyr::arrange(dplyr::all_of(etime_col)) |>
    dplyr::filter(stats::complete.cases(dplyr::across(dplyr::all_of(states_needed))))

  purrr::map_dfr(donor_states, function(dropped) {
    loo_donors <- setdiff(donor_states, dropped)
    if (length(loo_donors) < 2) return(NULL)

    pm <- tryCatch(
      build_block_predictor_matrix(data, outcome, etime_col, loo_donors, blocks),
      error = function(e) NULL
    )
    if (is.null(pm)) return(NULL)
    if (anyNA(pm)) pm[!is.finite(pm)] <- 0

    scaled <- standardize_rows(pm)
    x1 <- scaled$x[, treated_state, drop = FALSE]
    x0 <- scaled$x[, loo_donors,    drop = FALSE]
    w  <- solve_scm_weights(x1, x0)
    names(w) <- loo_donors

    loo_states <- c(treated_state, loo_donors)
    wide_loo <- wide_full |>
      dplyr::filter(stats::complete.cases(dplyr::across(dplyr::all_of(loo_states))))

    synthetic <- as.matrix(wide_loo[, loo_donors, drop = FALSE]) %*% w
    gap       <- wide_loo[[treated_state]] - as.numeric(synthetic)

    tibble::tibble(
      dropped_donor = dropped,
      period_date   = wide_loo$period_date,
      !!etime_col  := wide_loo[[etime_col]],
      loo_gap       = gap
    )
  })
}

compute_loo_window_frac <- function(loo, etime_col, windows, main_att_by_window) {
  if (is.null(loo) || nrow(loo) == 0) return(NULL)
  purrr::map_dfr(windows, function(w) {
    main_att <- main_att_by_window |>
      dplyr::filter(.data$window == w$name) |>
      dplyr::pull(.data$att_mean)
    if (length(main_att) == 0 || !is.finite(main_att)) {
      return(tibble::tibble(window = w$name, loo_frac = NA_real_, n_loo = 0L))
    }
    loo_atts <- loo |>
      dplyr::filter(
        .data[[etime_col]] >= w$start,
        .data[[etime_col]] <= w$end
      ) |>
      dplyr::group_by(.data$dropped_donor) |>
      dplyr::summarise(loo_att = mean(.data$loo_gap, na.rm = TRUE), .groups = "drop") |>
      dplyr::pull(.data$loo_att)
    loo_frac <- mean(sign(loo_atts[is.finite(loo_atts)]) == sign(main_att), na.rm = TRUE)
    tibble::tibble(window = w$name, loo_frac = loo_frac, n_loo = length(loo_atts))
  })
}

# ── Outcome specs ─────────────────────────────────────────────────────────────
specs <- list(
  list(outcome = "retail_ma6_log",          etime_col = "event_time", is_main = TRUE),
  list(outcome = "formal_hiring_6m_per1k",  etime_col = "event_time", is_main = TRUE),
  list(outcome = "icms_conf6m_pc_log",      etime_col = "event_time", is_main = TRUE)
)

loo_output_dir <- file.path(output_root, "placebo_loo")
dir.create(loo_output_dir, recursive = TRUE, showWarnings = FALSE)
monthly_out_dir <- file.path(output_root, "monthly")
dir.create(monthly_out_dir, recursive = TRUE, showWarnings = FALSE)

summary_rows <- purrr::map_dfr(specs, function(spec) {
  message("  Estimating: ", spec$outcome)

  result <- fit_augscm(
    data      = monthly_panel,
    outcome   = spec$outcome,
    etime_col = spec$etime_col,
    blocks    = monthly_blocks
  )

  if (result$status != "estimated") {
    message("    Skipped: ", result$skip_reason)
    return(tibble::tibble(
      outcome    = spec$outcome,
      is_main    = spec$is_main,
      status     = "skipped",
      skip_reason = result$skip_reason
    ))
  }

  slug <- make_slug(spec$outcome)
  readr::write_csv(result$path,    file.path(monthly_out_dir, paste0(slug, "_path.csv")),    na = "")
  readr::write_csv(result$weights, file.path(monthly_out_dir, paste0(slug, "_weights.csv")), na = "")

  att_tbl <- compute_window_att(result$path, spec$etime_col, monthly_windows)

  loo <- run_loo_placebo(monthly_panel, spec$outcome, spec$etime_col,
                         result$donor_states, monthly_blocks)
  loo_frac_tbl <- NULL
  if (!is.null(loo) && nrow(loo) > 0) {
    readr::write_csv(loo, file.path(loo_output_dir, paste0(slug, "_loo.csv")), na = "")
    loo_frac_tbl <- compute_loo_window_frac(loo, spec$etime_col, monthly_windows, att_tbl)
  }

  rmspe_pre <- result$path |>
    dplyr::filter(.data$event_time < 0, is.finite(.data$augmented_gap)) |>
    dplyr::summarise(rmspe = sqrt(mean(.data$augmented_gap^2))) |>
    dplyr::pull(.data$rmspe)

  base_row <- tibble::tibble(
    outcome     = spec$outcome,
    is_main     = spec$is_main,
    status      = "estimated",
    skip_reason = NA_character_,
    donor_count = length(result$donor_states),
    rmspe_pre   = rmspe_pre
  )

  att_wide <- att_tbl |>
    dplyr::select("window", "att_mean", "n_periods", "sign_consistent") |>
    tidyr::pivot_wider(
      names_from  = "window",
      values_from = c("att_mean", "n_periods", "sign_consistent")
    )

  loo_wide <- if (!is.null(loo_frac_tbl)) {
    loo_frac_tbl |>
      dplyr::select("window", "loo_frac") |>
      tidyr::pivot_wider(names_from = "window", values_from = "loo_frac",
                         names_prefix = "loo_frac_")
  } else tibble::tibble()

  dplyr::bind_cols(base_row, att_wide, loo_wide)
})

readr::write_csv(summary_rows, file.path(output_root, "rr_2018_01_v6_scm_summary.csv"), na = "")
message("RR 2018-01 V6 SCM complete (k=6, slope predictors, CAGED per1k, ICMS per capita).")
print(summary_rows |>
  dplyr::filter(.data$status == "estimated") |>
  dplyr::select("outcome", "donor_count", "rmspe_pre",
                dplyr::starts_with("att_mean")))
