# ── Nova Estrategia v2 engine: core AugSCM fitting functions ──────────────────
# Shared by 02_run_event_scm_v2.R (main fit + LOO donor placebo) and
# 02b_run_event_placebo_inspace_v2.R (in-space placebo: each donor refit as if
# it were the treated unit). Extracted here so both scripts use one
# implementation. Relies on `covariate_data` and `treated_state` being defined
# as globals by the sourcing script before these functions are called (lexical
# scoping resolves them at call time from .GlobalEnv, same as if they were
# defined inline).

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
# `unit` defaults to the real treated_state so existing call sites (the main
# fit, the LOO placebo) are unaffected; the in-space placebo script passes a
# different `unit` (a donor pretending to be treated) explicitly.
build_block_predictor_matrix <- function(data, outcome, etime_col, donor_states, blocks,
                                          unit = treated_state) {
  states <- c(unit, donor_states)

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

  rbind(level_matrix, slope_matrix, cov_vals)
}

# ── Augmented SCM estimator ───────────────────────────────────────────────────
# `unit` / `candidate_pool` default to the real treated unit and its main
# donor pool, so the main-fit call site (no extra args) is unaffected. The
# in-space placebo script calls this with a donor as `unit` and the remaining
# donors (real treated state excluded) as `candidate_pool`.
fit_augscm <- function(data, outcome, etime_col, blocks,
                        unit = treated_state, candidate_pool = main_donor_states) {
  lambda_grid <- 10^seq(-4, 5, length.out = 20)

  core_block <- blocks[[which(purrr::map_chr(blocks, "name") == "block_m12_m7")[[1]]]]

  candidate_states <- intersect(
    candidate_pool,
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

  pm <- build_block_predictor_matrix(data, outcome, etime_col, donor_states, blocks, unit = unit)
  if (anyNA(pm)) pm[!is.finite(pm)] <- 0

  scaled <- standardize_rows(pm)
  x1     <- scaled$x[, unit, drop = FALSE]
  x0     <- scaled$x[, donor_states,  drop = FALSE]
  scm_w  <- solve_scm_weights(x1, x0)
  names(scm_w) <- donor_states

  unit_pred   <- t(pm)
  donor_pred  <- unit_pred[donor_states, , drop = FALSE]
  all_pred    <- unit_pred[c(unit, donor_states), , drop = FALSE]
  scaled_unit <- standardize_cols_by_train(donor_pred, all_pred)
  treat_p     <- scaled_unit[unit, , drop = FALSE]
  donor_p     <- scaled_unit[donor_states, , drop = FALSE]
  w_donor_p   <- matrix(as.numeric(t(scm_w) %*% donor_p), nrow = 1)
  imbalance   <- treat_p - w_donor_p

  states_needed <- c(unit, donor_states)
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
      treated_value       = .data[[unit]],
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
