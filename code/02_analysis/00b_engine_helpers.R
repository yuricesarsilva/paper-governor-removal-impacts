# ── Event-study engine: shared helpers ────────────────────────────────────────
# Seasonal adjustment (X-13 for monthly/quarterly, STL for bimonthly), index
# rebasing, and the Augmented SCM primitives. Ported from the validated pilots
# (pi_2001_01_v1, am_2017_01_v4) and parameterised (no reliance on globals).

make_slug <- function(x) {
  x |>
    stringr::str_replace_all("[^A-Za-z0-9]+", "_") |>
    stringr::str_replace_all("_+$", "") |>
    tolower()
}

# Parse a SICONFI `valor` field. CRITICAL: if it is already numeric (cents
# included, e.g. 5051450607.51), return it as-is. Forcing as.character +
# parse_number with a BR locale would treat the decimal point as a thousands
# separator and inflate the value ~100x. Only fall back to BR parsing for
# genuinely character-formatted input.
parse_siconfi_value <- function(x) {
  if (is.numeric(x)) return(as.numeric(x))
  xc <- stringr::str_trim(as.character(x))
  p  <- suppressWarnings(readr::parse_number(
    xc, locale = readr::locale(decimal_mark = ",", grouping_mark = "."),
    na = c("", "NA", "null")))
  fb <- is.na(p) & nzchar(xc)
  p[fb] <- suppressWarnings(as.numeric(xc[fb]))
  p
}

# ── Evidence classification (literature-aligned) ──────────────────────────────
# Inference follows the standard placebo/permutation approach (Abadie, Diamond &
# Hainmueller 2010): the tier is the treated unit's position in the placebo
# distribution of the post/pre RMSPE ratio (discrete p = rank/N), which already
# self-normalises for pre-treatment fit. To rise above "weak" an effect must also
# be substantively large (|post gap| >= 1 pre-period SD) and free of a pre-trend
# (the parallel-pre condition). Persistence and leave-one-out stability are
# REPORTED as supporting robustness, not used as gates.
#
# Pre-treatment FIT QUALITY (pre-RMSPE percentile among donors + treated-vs-
# synthetic pre correlation + R^2) is reported SEPARATELY and never bins a result
# as "non-interpretable": the SCM literature has no fixed fit threshold (fit is
# judged visually and relative to the effect), so poor-fit results are flagged for
# the reader, not hidden.
#   tier:  strong     placebo p <= 0.05   (+ magnitude + no pre-trend)
#          moderate   placebo p <= 0.10   (+ magnitude + no pre-trend)
#          suggestive placebo p <= 0.15   (+ magnitude + no pre-trend)
#          weak       otherwise
#   considerable = strong / moderate / suggestive.
# All inputs come from files already written by stages 02/02b; no refitting.
evidence_thresholds <- list(mag_sd = 1.0, persist = 0.60, loo = 0.80, pretrend_p = 0.10,
                            p_strong = 0.05, p_moderate = 0.10, p_suggestive = 0.15,
                            fit_corr_ok = 0.50)

# Tier = placebo band, conditional on a substantive effect with no pre-trend.
classify_tier <- function(eligible, classic_p, thr = evidence_thresholds) {
  if (!isTRUE(eligible) || !is.finite(classic_p)) return("weak")
  if (classic_p <= thr$p_strong) "strong"
  else if (classic_p <= thr$p_moderate) "moderate"
  else if (classic_p <= thr$p_suggestive) "suggestive"
  else "weak"
}

build_evidence_table <- function(event_id, thr = evidence_thresholds) {
  d  <- event_dirs(event_id)
  sm <- readr::read_csv(file.path(d$scm, paste0(event_id, "_scm_summary.csv")), show_col_types = FALSE) |>
    dplyr::filter(.data$status == "estimated")
  if (nrow(sm) == 0) return(tibble::tibble())
  prk_f <- file.path(d$tables, "placebo_rank_actual_rr.csv")
  ps_f  <- file.path(d$scm, "placebo_inspace", "placebo_summary.csv")
  prk <- if (file.exists(prk_f)) readr::read_csv(prk_f, show_col_types = FALSE) else NULL
  ps  <- if (file.exists(ps_f))  readr::read_csv(ps_f,  show_col_types = FALSE) else NULL

  purrr::map_dfr(seq_len(nrow(sm)), function(i) {
    o <- sm$outcome[i]; fam <- sm$family[i]
    cat_o <- outcome_catalog[[o]]
    path_f <- file.path(d$scm, fam, "sa", paste0(make_slug(o), "_path.csv"))
    if (!file.exists(path_f)) return(NULL)
    p <- readr::read_csv(path_f, show_col_types = FALSE)
    post <- p |> dplyr::filter(.data$analysis_period == "post")
    pre  <- p |> dplyr::filter(.data$analysis_period == "pre")
    transform      <- if (!is.null(cat_o$transform)) cat_o$transform else "level"
    mag_threshold  <- if (!is.null(cat_o$mag_threshold)) cat_o$mag_threshold else 0.05
    effect_display <- if (!is.null(cat_o$effect_display)) cat_o$effect_display else "pct"
    gap_post <- mean(post$augmented_gap, na.rm = TRUE)
    synth_post <- mean(post$augmented_synthetic_value, na.rm = TRUE)
    # % effect of synthetic: for log outcomes exp(gap)-1; for level outcomes gap/synth.
    # Flow outcomes (synth ~ 0) are reported as the absolute gap, not %.
    pct_effect <- if (identical(effect_display, "absolute")) {
      NA_real_
    } else if (identical(transform, "log")) {
      100 * (exp(gap_post) - 1)
    } else if (is.finite(synth_post) && abs(synth_post) > 1e-9) {
      100 * gap_post / synth_post
    } else NA_real_
    effect_for_plot <- if (identical(effect_display, "absolute")) gap_post else pct_effect
    effect_label <- if (identical(effect_display, "absolute")) {
      formatC(gap_post, format = "f", digits = 1, flag = "+")
    } else if (is.finite(pct_effect)) {
      paste0(formatC(pct_effect, format = "f", digits = 1, flag = "+"), "%")
    } else ""
    pre_sd <- stats::sd(pre$treated_value, na.rm = TRUE)
    mag_sd <- if (is.finite(pre_sd) && pre_sd > 0) abs(gap_post) / pre_sd else NA_real_
    # Pre-treatment fit quality: how well the synthetic tracks the treated path.
    pre_fit_corr <- tryCatch(stats::cor(pre$treated_value, pre$augmented_synthetic_value), error = function(e) NA_real_)
    pre_rmspe_in <- sqrt(mean((pre$treated_value - pre$augmented_synthetic_value)^2, na.rm = TRUE))
    pre_fit_r2 <- if (is.finite(pre_sd) && pre_sd > 0) 1 - pre_rmspe_in^2 / stats::var(pre$treated_value, na.rm = TRUE) else NA_real_
    persistence <- mean(sign(post$augmented_gap) == sign(gap_post), na.rm = TRUE)
    pre_trend_p <- tryCatch({
      if (nrow(pre) >= 4) summary(stats::lm(augmented_gap ~ as.numeric(period_date), data = pre))$coefficients[2, 4] else NA_real_
    }, error = function(e) NA_real_)

    treated_pre <- sm$augmented_rmspe_pre[i]
    donor_pre <- if (!is.null(ps)) ps$pre_rmspe[ps$outcome == o] else numeric(0)
    med_donor_pre <- if (length(donor_pre)) stats::median(donor_pre, na.rm = TRUE) else NA_real_
    pre_pctile <- if (length(donor_pre)) mean(donor_pre < treated_pre, na.rm = TRUE) else NA_real_
    no_pretrend <- is.na(pre_trend_p) || pre_trend_p >= thr$pretrend_p
    # Pre-fit quality flag (reported, not a gate): combine the treated's pre-RMSPE
    # rank among donors with how well the synthetic tracks the treated path.
    prefit_class <- if (!is.finite(pre_pctile)) "D" else if (pre_pctile <= 0.25) "A" else
      if (pre_pctile <= 0.50) "B" else if (pre_pctile <= 0.75) "C" else "D"
    tracks_ok <- is.finite(pre_fit_corr) && pre_fit_corr >= thr$fit_corr_ok
    poor_fit  <- prefit_class == "D" || !tracks_ok

    rank <- NA_integer_; n_units <- NA_integer_; classic_p <- NA_real_
    if (!is.null(prk) && o %in% prk$outcome) {
      pr <- prk[prk$outcome == o, ][1, ]
      npl <- pr$donor_placebo_count; k <- round(pr$ratio_p_value * npl)
      rank <- k + 1L; n_units <- npl + 1L; classic_p <- rank / n_units
    }

    loo_f <- file.path(d$scm, "placebo_loo", paste0(make_slug(o), "_loo_placebo.csv"))
    loo_frac <- NA_real_
    if (file.exists(loo_f)) {
      loo <- readr::read_csv(loo_f, show_col_types = FALSE) |> dplyr::filter(.data$analysis_period == "post")
      lg <- loo |> dplyr::group_by(.data$dropped_donor) |>
        dplyr::summarise(m = mean(.data$loo_gap, na.rm = TRUE), .groups = "drop")
      if (nrow(lg)) loo_frac <- mean(sign(lg$m) == sign(gap_post), na.rm = TRUE)
    }

    magnitude_ok <- is.finite(mag_sd) && mag_sd >= thr$mag_sd      # substantive
    persistence_ok <- is.finite(persistence) && persistence >= thr$persist
    loo_ok <- is.finite(loo_frac) && loo_frac >= thr$loo
    robust <- persistence_ok && loo_ok                            # supporting robustness
    # Eligible to rise above "weak": substantive effect with no pre-trend.
    eligible <- magnitude_ok && no_pretrend
    tier <- classify_tier(eligible, classic_p)

    tibble::tibble(
      event_id = event_id, outcome = o, short = cat_o$short, channel = cat_o$channel, family = fam,
      gap_post = gap_post, pct_effect = pct_effect, effect_display = effect_display,
      effect_for_plot = effect_for_plot, effect_label = effect_label,
      mag_sd = mag_sd, magnitude_ok = magnitude_ok, persistence = persistence, persistence_ok = persistence_ok,
      pre_trend_p = pre_trend_p, no_pretrend = no_pretrend,
      treated_pre_rmspe = treated_pre, median_donor_pre_rmspe = med_donor_pre,
      pre_fit_corr = pre_fit_corr, pre_fit_r2 = pre_fit_r2, prefit_class = prefit_class, poor_fit = poor_fit,
      rank = rank, n_units = n_units, classic_p = classic_p,
      loo_frac_same_sign = loo_frac, loo_ok = loo_ok, robust = robust,
      tier = tier, considerable = tier %in% c("strong", "moderate", "suggestive"),
      direction = ifelse(gap_post < 0, "negative", "positive")
    )
  })
}
# Applied to each unit's FULL series before windowing. X-13ARIMA-SEATS for
# monthly (12) and quarterly (4); STL for bimonthly (6, which X-13 cannot do).
# Falls back to the raw series if the method fails or there are too few cycles.
x13_adjust <- function(x, dates, freq, state_id = "") {
  out <- x
  finite_idx <- which(is.finite(x))
  if (length(finite_idx) == 0L) return(out)

  runs       <- split(finite_idx, cumsum(c(1L, diff(finite_idx) != 1L)))
  longest    <- runs[[which.max(vapply(runs, length, integer(1)))]]
  min_needed <- 3L * freq
  if (length(longest) < min_needed) return(out)

  span_x     <- x[longest]
  span_dates <- dates[longest]
  start_yr   <- lubridate::year(span_dates[[1L]])
  start_sub  <- if (freq == 12L) {
    lubridate::month(span_dates[[1L]])
  } else if (freq == 6L) {
    ((lubridate::month(span_dates[[1L]]) - 1L) %/% 2L) + 1L
  } else {
    lubridate::quarter(span_dates[[1L]])
  }

  ts_obj <- ts(span_x, start = c(start_yr, start_sub), frequency = freq)

  adjusted <- tryCatch({
    if (freq %in% c(12L, 4L)) {
      fit <- seasonal::seas(ts_obj, transform.function = "none", x11 = "", outlier = NULL)
      sa  <- as.numeric(seasonal::final(fit))
    } else {
      fit <- stats::stl(ts_obj, s.window = "periodic", robust = TRUE)
      sa  <- as.numeric(ts_obj) - as.numeric(fit$time.series[, "seasonal"])
    }
    if (length(sa) == length(span_x)) sa else NULL
  }, error = function(e) {
    message("  SA failed (", state_id, ", freq=", freq, "): ",
            conditionMessage(e), " - using raw series for this unit.")
    NULL
  })

  if (!is.null(adjusted)) out[longest] <- adjusted
  out
}

apply_sa_to_panel <- function(data, vars, date_col, group_col, freq) {
  message("  SA (freq=", freq, "): ", paste(vars, collapse = ", "))
  data |>
    dplyr::group_by(dplyr::across(dplyr::all_of(group_col))) |>
    dplyr::arrange(dplyr::across(dplyr::all_of(date_col)), .by_group = TRUE) |>
    dplyr::mutate(dplyr::across(
      dplyr::all_of(vars),
      function(col_vals) x13_adjust(col_vals, .data[[date_col]], freq, dplyr::cur_group()[[group_col]]),
      .names = "{.col}_sa"
    )) |>
    dplyr::ungroup()
}

# Rebase SA index series to 100 at the first valid observation within the window.
rebase_sa_in_window <- function(data, vars, window_start, window_end) {
  dw <- data |> dplyr::filter(.data$period_date >= window_start, .data$period_date <= window_end)
  for (v in vars) {
    v_sym <- rlang::sym(v)
    base_tbl <- dw |>
      dplyr::group_by(.data$state_abbrev) |>
      dplyr::arrange(.data$period_date, .by_group = TRUE) |>
      dplyr::summarise(.base = {
        fv <- (!!v_sym)[is.finite(!!v_sym)]
        if (length(fv) == 0L) NA_real_ else fv[[1L]]
      }, .groups = "drop")
    dw <- dw |>
      dplyr::left_join(base_tbl, by = "state_abbrev") |>
      dplyr::mutate(!!v_sym := dplyr::if_else(
        is.finite(.data$.base) & .data$.base != 0, 100 * (!!v_sym) / .data$.base, NA_real_
      )) |>
      dplyr::select(-dplyr::any_of(".base"))
  }
  dw
}

# Impute an interior NA with the mean of its finite neighbours (siconfi flows).
impute_adjacent_mean <- function(data, value_col,
                                 order_col = "period_date", group_col = "state_abbrev") {
  vs <- rlang::sym(value_col)
  data |>
    dplyr::group_by(dplyr::across(dplyr::all_of(group_col))) |>
    dplyr::arrange(dplyr::across(dplyr::all_of(order_col)), .by_group = TRUE) |>
    dplyr::mutate(
      .lag = dplyr::lag(!!vs), .lead = dplyr::lead(!!vs),
      .can = is.na(!!vs) & is.finite(.lag) & is.finite(.lead),
      !!vs := dplyr::if_else(.data$.can, (.lag + .lead) / 2, !!vs)
    ) |>
    dplyr::ungroup() |>
    dplyr::select(-dplyr::any_of(c(".lag", ".lead", ".can")))
}

# ── SCM primitives ────────────────────────────────────────────────────────────
standardize_by_row <- function(x) {
  rm <- rowMeans(x, na.rm = TRUE); rs <- apply(x, 1, stats::sd, na.rm = TRUE)
  keep <- is.finite(rs) & rs > 0
  xs <- sweep(x[keep, , drop = FALSE], 1, rm[keep], "-")
  xs <- sweep(xs, 1, rs[keep], "/")
  list(x = xs, keep = keep)
}
standardize_units <- function(x_train, x_all) {
  cm <- colMeans(x_train, na.rm = TRUE); cs <- apply(x_train, 2, stats::sd, na.rm = TRUE)
  cs[!is.finite(cs) | cs == 0] <- 1
  list(x_all = sweep(sweep(x_all, 2, cm, "-"), 2, cs, "/"))
}
solve_weights <- function(x1, x0) {
  dmat <- 2 * crossprod(x0) + diag(1e-8, ncol(x0))
  dvec <- 2 * as.numeric(crossprod(x0, x1))
  amat <- cbind(rep(1, ncol(x0)), diag(ncol(x0)))
  bvec <- c(1, rep(0, ncol(x0)))
  sol  <- quadprog::solve.QP(dmat, dvec, amat, bvec, meq = 1)
  w <- pmax(sol$solution, 0); w / sum(w)
}
fit_ridge <- function(x, y, lambda) {
  d <- cbind(1, x); p <- diag(ncol(d)); p[1, 1] <- 0
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

# Collapse the full pre-outcome path (periods x states) to one row per calendar
# year (the parsimonious outcome representation used by spec "yearmeans_plus_covariates").
yearly_means_mat <- function(om, years) {
  ys <- sort(unique(years))
  out <- t(vapply(ys, function(y) {
    r <- which(years == y)
    if (length(r) == 1L) om[r, ] else colMeans(om[r, , drop = FALSE])
  }, numeric(ncol(om))))
  rownames(out) <- paste0("ym_", ys); colnames(out) <- colnames(om)
  out
}

# Predictor matrix. scm_predictors (config) selects the outcome representation:
#   "lags_plus_covariates"      -> full pre path + covariate means
#   "lags_only"                 -> full pre path only
#   "yearmeans_plus_covariates" -> yearly means of the pre path + covariate means
build_predictor_matrix <- function(data, outcome, treated_state, donor_states,
                                    covariate_data, min_pre) {
  states <- c(treated_state, donor_states)
  pre_data <- data |>
    dplyr::filter(.data$analysis_period == "pre", .data$state_abbrev %in% states) |>
    dplyr::select(.data$state_abbrev, .data$period_date, value = dplyr::all_of(outcome)) |>
    tidyr::pivot_wider(names_from = .data$state_abbrev, values_from = .data$value) |>
    dplyr::arrange(.data$period_date) |>
    dplyr::filter(stats::complete.cases(dplyr::across(dplyr::all_of(states))))
  if (nrow(pre_data) < min_pre) stop("Too few complete pre periods: ", outcome)

  om <- pre_data |> dplyr::select(dplyr::all_of(states)) |> as.matrix()
  rownames(om) <- paste0("pre_", format(pre_data$period_date, "%Y_%m_%d"))

  outcome_block <- if (identical(scm_predictors, "yearmeans_plus_covariates")) {
    yearly_means_mat(om, lubridate::year(pre_data$period_date))
  } else om

  cov_cols <- setdiff(names(covariate_data), "state_abbrev")
  if (identical(scm_predictors, "lags_only") || length(cov_cols) == 0) {
    if (anyNA(outcome_block)) stop("Missing values in predictor matrix: ", outcome)
    return(outcome_block)
  }

  cl <- covariate_data |>
    dplyr::filter(.data$state_abbrev %in% states) |>
    tidyr::pivot_longer(-.data$state_abbrev, names_to = "pred", values_to = "val") |>
    tidyr::pivot_wider(names_from = .data$state_abbrev, values_from = .data$val) |>
    dplyr::arrange(.data$pred)
  cm <- cl |> dplyr::select(dplyr::all_of(states)) |> as.matrix()
  rownames(cm) <- paste0("cov_", cl$pred)

  pm <- rbind(outcome_block, cm)
  if (anyNA(pm)) stop("Missing values in predictor matrix: ", outcome)
  pm
}

# Fit Augmented SCM for one outcome. Writes path + weights to out_dir; returns the
# rmspe summary row. `family` labels the frequency block (monthly/bimonthly).
fit_augmented_scm <- function(data, outcome, treated_state, main_donor_states,
                              covariate_data, min_pre, family, specification, out_dir) {
  treated_pre_dates <- data |>
    dplyr::filter(.data$state_abbrev == treated_state, .data$analysis_period == "pre",
                  is.finite(.data[[outcome]])) |>
    dplyr::arrange(.data$period_date) |>
    dplyr::pull(.data$period_date)

  skip <- function(reason) tibble::tibble(
    family = family, specification = specification, outcome = outcome,
    status = "skipped", skip_reason = reason
  )
  if (length(treated_pre_dates) < min_pre)
    return(skip(paste0("Insufficient pre-treatment data (<", min_pre, "): ", outcome)))

  candidate_states <- intersect(
    main_donor_states,
    covariate_data$state_abbrev[stats::complete.cases(covariate_data[, -1, drop = FALSE])]
  )
  donor_states <- purrr::keep(candidate_states, function(st) {
    dp <- data |> dplyr::filter(.data$state_abbrev == st, .data$analysis_period == "pre",
                                .data$period_date %in% treated_pre_dates)
    nrow(dp) == length(treated_pre_dates) && all(is.finite(dp[[outcome]]))
  })
  if (length(donor_states) < 2) return(skip(paste0("Fewer than 2 complete donors: ", outcome)))

  pm <- build_predictor_matrix(data, outcome, treated_state, donor_states, covariate_data, min_pre)
  sc <- standardize_by_row(pm)
  x1 <- sc$x[, treated_state, drop = FALSE]; x0 <- sc$x[, donor_states, drop = FALSE]
  w  <- solve_weights(x1, x0); names(w) <- donor_states

  unit_pred  <- t(pm)
  donor_pred <- unit_pred[donor_states, , drop = FALSE]
  all_pred   <- unit_pred[c(treated_state, donor_states), , drop = FALSE]
  su <- standardize_units(donor_pred, all_pred)
  treated_p <- su$x_all[treated_state, , drop = FALSE]
  donor_ps  <- su$x_all[donor_states, , drop = FALSE]
  imbalance <- treated_p - matrix(as.numeric(t(w) %*% donor_ps), nrow = 1)

  all_states <- c(treated_state, donor_states)
  wide <- data |>
    dplyr::filter(.data$state_abbrev %in% all_states) |>
    dplyr::select(.data$period_date, .data$analysis_period, .data$state_abbrev,
                  value = dplyr::all_of(outcome)) |>
    tidyr::pivot_wider(names_from = .data$state_abbrev, values_from = .data$value) |>
    dplyr::arrange(.data$period_date) |>
    dplyr::filter(stats::complete.cases(dplyr::across(dplyr::all_of(all_states))))

  corrections <- purrr::map_dfr(seq_len(nrow(wide)), function(i) {
    yd <- as.numeric(wide[i, donor_states, drop = TRUE])
    yc <- mean(yd, na.rm = TRUE); ys <- stats::sd(yd, na.rm = TRUE)
    if (!is.finite(ys) || ys == 0) ys <- 1
    yds <- (yd - yc) / ys
    lam <- loocv_lambda(donor_ps, yds, lambda_grid)
    co  <- fit_ridge(donor_ps, yds, lam)
    tibble::tibble(period_date = wide$period_date[i],
                   augmentation_correction = as.numeric(imbalance %*% co[-1]) * ys)
  })

  synth <- as.matrix(wide[, donor_states, drop = FALSE]) %*% w
  path <- wide |>
    dplyr::transmute(.data$period_date, .data$analysis_period,
                     treated_value = .data[[treated_state]],
                     scm_synthetic_value = as.numeric(synth)) |>
    dplyr::left_join(corrections, by = "period_date") |>
    dplyr::mutate(
      augmented_synthetic_value = .data$scm_synthetic_value + .data$augmentation_correction,
      scm_gap = .data$treated_value - .data$scm_synthetic_value,
      augmented_gap = .data$treated_value - .data$augmented_synthetic_value,
      outcome = outcome
    )

  weights <- tibble::tibble(donor_state = donor_states, scm_weight = as.numeric(w)) |>
    dplyr::arrange(dplyr::desc(.data$scm_weight))

  rmspe <- path |>
    dplyr::group_by(.data$analysis_period) |>
    dplyr::summarise(
      scm_rmspe = sqrt(mean(.data$scm_gap^2, na.rm = TRUE)),
      augmented_rmspe = sqrt(mean(.data$augmented_gap^2, na.rm = TRUE)),
      scm_mean_gap = mean(.data$scm_gap, na.rm = TRUE),
      augmented_mean_gap = mean(.data$augmented_gap, na.rm = TRUE),
      n_periods = dplyr::n(), .groups = "drop"
    ) |>
    tidyr::pivot_wider(names_from = .data$analysis_period,
      values_from = c("scm_rmspe", "augmented_rmspe", "scm_mean_gap",
                      "augmented_mean_gap", "n_periods")) |>
    dplyr::mutate(outcome = outcome, donor_count = length(donor_states),
                  family = family, specification = specification,
                  status = "estimated", skip_reason = NA_character_)

  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  slug <- make_slug(outcome)
  readr::write_csv(path,    file.path(out_dir, paste0(slug, "_path.csv")), na = "")
  readr::write_csv(weights, file.path(out_dir, paste0(slug, "_weights.csv")), na = "")
  rmspe
}

# Leave-one-out donor placebo for one outcome.
run_loo_placebo <- function(data, outcome, treated_state, main_donor_states,
                            covariate_data, min_pre) {
  treated_pre_dates <- data |>
    dplyr::filter(.data$state_abbrev == treated_state, .data$analysis_period == "pre",
                  is.finite(.data[[outcome]])) |>
    dplyr::pull(.data$period_date)
  if (length(treated_pre_dates) < min_pre) return(NULL)

  full_donors <- purrr::keep(
    intersect(main_donor_states,
              covariate_data$state_abbrev[stats::complete.cases(covariate_data[, -1, drop = FALSE])]),
    function(st) {
      dp <- data |> dplyr::filter(.data$state_abbrev == st, .data$analysis_period == "pre",
                                  .data$period_date %in% treated_pre_dates)
      nrow(dp) == length(treated_pre_dates) && all(is.finite(dp[[outcome]]))
    })
  if (length(full_donors) < 3) return(NULL)

  purrr::map_dfr(full_donors, function(dropped) {
    loo_donors <- setdiff(full_donors, dropped)
    if (length(loo_donors) < 2) return(NULL)
    pm <- tryCatch(build_predictor_matrix(data, outcome, treated_state, loo_donors, covariate_data, min_pre),
                   error = function(e) NULL)
    if (is.null(pm)) return(NULL)
    sc <- standardize_by_row(pm)
    w  <- solve_weights(sc$x[, treated_state, drop = FALSE], sc$x[, loo_donors, drop = FALSE])
    names(w) <- loo_donors
    loo_states <- c(treated_state, loo_donors)
    wide <- data |>
      dplyr::filter(.data$state_abbrev %in% loo_states) |>
      dplyr::select(.data$period_date, .data$analysis_period, .data$state_abbrev,
                    value = dplyr::all_of(outcome)) |>
      tidyr::pivot_wider(names_from = .data$state_abbrev, values_from = .data$value) |>
      dplyr::arrange(.data$period_date) |>
      dplyr::filter(stats::complete.cases(dplyr::across(dplyr::all_of(loo_states))))
    synth <- as.matrix(wide[, loo_donors, drop = FALSE]) %*% w
    tibble::tibble(dropped_donor = dropped, period_date = wide$period_date,
                   analysis_period = wide$analysis_period,
                   loo_gap = wide[[treated_state]] - as.numeric(synth))
  })
}

# In-space placebo: fit ASCM treating one donor as pseudo-treated.
fit_ascm_for_unit <- function(data, outcome, pseudo_treated, donor_pool, covariate_data, min_pre) {
  # Mirror the main fit: keep only donors with complete data on the pseudo-treated
  # unit's pre-dates, so partially-covered series (e.g. Annex06 ICMS) don't
  # collapse the complete-case pre-window across the full donor pool.
  pre_dates <- data |>
    dplyr::filter(.data$state_abbrev == pseudo_treated, .data$analysis_period == "pre",
                  is.finite(.data[[outcome]])) |>
    dplyr::pull(.data$period_date)
  if (length(pre_dates) < min_pre) return(NULL)
  donor_pool <- purrr::keep(donor_pool, function(st) {
    dp <- data |> dplyr::filter(.data$state_abbrev == st, .data$analysis_period == "pre",
                                .data$period_date %in% pre_dates)
    nrow(dp) == length(pre_dates) && all(is.finite(dp[[outcome]]))
  })
  if (length(donor_pool) < 2) return(NULL)
  all_st <- c(pseudo_treated, donor_pool)
  pre <- data |>
    dplyr::filter(.data$analysis_period == "pre", .data$state_abbrev %in% all_st) |>
    dplyr::select(.data$state_abbrev, .data$period_date, value = dplyr::all_of(outcome)) |>
    tidyr::pivot_wider(names_from = .data$state_abbrev, values_from = .data$value) |>
    dplyr::arrange(.data$period_date) |>
    dplyr::filter(stats::complete.cases(dplyr::across(dplyr::all_of(all_st))))
  if (nrow(pre) < min_pre) return(NULL)

  om <- pre |> dplyr::select(dplyr::all_of(all_st)) |> as.matrix()
  rownames(om) <- paste0("pre_", format(pre$period_date, "%Y_%m_%d"))
  outcome_block <- if (identical(scm_predictors, "yearmeans_plus_covariates")) {
    yearly_means_mat(om, lubridate::year(pre$period_date))
  } else om
  if (identical(scm_predictors, "lags_only") || length(setdiff(names(covariate_data), "state_abbrev")) == 0) {
    pm <- outcome_block
  } else {
    cl <- covariate_data |>
      dplyr::filter(.data$state_abbrev %in% all_st) |>
      tidyr::pivot_longer(-.data$state_abbrev, names_to = "p", values_to = "v") |>
      tidyr::pivot_wider(names_from = .data$state_abbrev, values_from = .data$v) |>
      dplyr::arrange(.data$p)
    cm <- cl |> dplyr::select(dplyr::all_of(all_st)) |> as.matrix()
    rownames(cm) <- paste0("cov_", cl$p)
    pm <- rbind(outcome_block, cm)
  }
  if (anyNA(pm)) return(NULL)

  sc <- standardize_by_row(pm)
  w  <- solve_weights(sc$x[, pseudo_treated, drop = FALSE], sc$x[, donor_pool, drop = FALSE])
  names(w) <- donor_pool
  up <- t(pm); dp <- up[donor_pool, , drop = FALSE]; ap <- up[all_st, , drop = FALSE]
  su <- standardize_units(dp, ap)
  imb <- su$x_all[pseudo_treated, , drop = FALSE] - matrix(as.numeric(t(w) %*% su$x_all[donor_pool, , drop = FALSE]), nrow = 1)
  dps <- su$x_all[donor_pool, , drop = FALSE]

  wide <- data |>
    dplyr::filter(.data$state_abbrev %in% all_st) |>
    dplyr::select(.data$period_date, .data$analysis_period, .data$state_abbrev,
                  value = dplyr::all_of(outcome)) |>
    tidyr::pivot_wider(names_from = .data$state_abbrev, values_from = .data$value) |>
    dplyr::arrange(.data$period_date) |>
    dplyr::filter(stats::complete.cases(dplyr::across(dplyr::all_of(all_st))))
  corr <- purrr::map_dfr(seq_len(nrow(wide)), function(i) {
    yd <- as.numeric(wide[i, donor_pool, drop = TRUE]); yc <- mean(yd, na.rm = TRUE); ys <- stats::sd(yd, na.rm = TRUE)
    if (!is.finite(ys) || ys == 0) ys <- 1
    lam <- loocv_lambda(dps, (yd - yc) / ys, lambda_grid); co <- fit_ridge(dps, (yd - yc) / ys, lam)
    tibble::tibble(period_date = wide$period_date[i], augmentation_correction = as.numeric(imb %*% co[-1]) * ys)
  })
  synth <- as.matrix(wide[, donor_pool, drop = FALSE]) %*% w
  path <- wide |>
    dplyr::transmute(.data$period_date, .data$analysis_period,
                     treated_value = .data[[pseudo_treated]], scm_synthetic = as.numeric(synth)) |>
    dplyr::left_join(corr, by = "period_date") |>
    dplyr::mutate(augmented_synthetic = .data$scm_synthetic + .data$augmentation_correction,
                  augmented_gap = .data$treated_value - .data$augmented_synthetic)
  rmspe_pre  <- sqrt(mean(path$augmented_gap[path$analysis_period == "pre"]^2, na.rm = TRUE))
  rmspe_post <- sqrt(mean(path$augmented_gap[path$analysis_period == "post"]^2, na.rm = TRUE))
  list(path = path, rmspe = tibble::tibble(
    pre_rmspe = rmspe_pre, post_rmspe = rmspe_post,
    mean_abs_gap_post = mean(abs(path$augmented_gap[path$analysis_period == "post"]), na.rm = TRUE),
    post_pre_ratio = rmspe_post / rmspe_pre))
}
