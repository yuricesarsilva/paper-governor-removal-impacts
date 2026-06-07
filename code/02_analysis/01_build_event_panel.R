# ── Event-study engine: build panels (arg: event_id) ──────────────────────────
# Builds, for one event, the monthly panel (always) and — in Regime B — the
# bimonthly SICONFI panel, plus the regime-specific covariate table and event
# metadata. Regime is resolved from the treated unit's SICONFI pre-coverage.
#
# Usage: Rscript code/02_analysis/01_build_event_panel.R <EVENT_ID>

source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))
source(file.path("code", "02_analysis", "00_event_config.R"))
source(file.path("code", "02_analysis", "00b_engine_helpers.R"))

extra <- c("tidyr", "janitor", "seasonal")
miss  <- extra[!vapply(extra, requireNamespace, logical(1), quietly = TRUE)]
if (length(miss)) stop("Missing packages: ", paste(miss, collapse = ", "))
invisible(lapply(extra, library, character.only = TRUE))

event_id <- resolve_event_id()
event    <- get_event(event_id)
treated_state          <- event$state_abbrev[[1]]
state_name_val         <- event$state_name[[1]]
removal_date           <- event$removal_date[[1]]
instability_start_date <- event$instability_start_date[[1]]
removal_month          <- lubridate::floor_date(removal_date, "month")

d <- ensure_event_dirs(event_id)
message("=== BUILD ", event_id, " (", treated_state, ", removal ", removal_date, ") ===")

dp <- function(f) file.path(root_dir, "data", "processed", f)

# ── Population (annual; year clamped for SA continuity) + IPCA deflator ───────
population <- readr::read_csv(dp("resident_population_annual_panel_ready.csv"), show_col_types = FALSE) |>
  dplyr::transmute(state_abbrev = .data$state_abbrev, year = as.integer(.data$year),
                   population = as.numeric(.data$population))
pop_min <- min(population$year); pop_max <- max(population$year)
pop_for_year <- function(st, yr) {
  yy <- pmin(pmax(yr, pop_min), pop_max)
  tibble::tibble(state_abbrev = st, pop_year = yy) |>
    dplyr::left_join(population |> dplyr::rename(pop_year = "year"),
                     by = c("state_abbrev", "pop_year")) |>
    dplyr::pull(.data$population)
}

ipca <- readr::read_csv(file.path(root_dir, "data", "raw", "ibge", "ipca_national_monthly.csv"),
                        show_col_types = FALSE) |>
  dplyr::transmute(mes_codigo = as.integer(.data$mes_codigo), ipca_index = as.numeric(.data$valor)) |>
  dplyr::arrange(.data$mes_codigo)
ipca_base_code  <- as.integer(lubridate::year(removal_month) * 100 + lubridate::month(removal_month))
ipca_base_value <- ipca$ipca_index[ipca$mes_codigo == ipca_base_code]
if (length(ipca_base_value) != 1 || !is.finite(ipca_base_value)) stop("IPCA base not found: ", ipca_base_code)
ipca_deflator <- ipca |>
  dplyr::transmute(period_date = as.Date(sprintf("%d-%02d-01", .data$mes_codigo %/% 100L, .data$mes_codigo %% 100L)),
                   ipca_deflator_factor = ipca_base_value / .data$ipca_index)

# ── Resolve regime from SICONFI pre-coverage of the treated unit ──────────────
siconfi <- readr::read_csv(dp("siconfi_rreo_state_fiscal_bimonthly_panel_ready.csv"), show_col_types = FALSE) |>
  dplyr::mutate(period_date = as.Date(.data$period_date))
bim_pre_start  <- removal_month %m-% months(spec$bimonthly$pre_target * 2L)
post_end       <- removal_month %m+% months(spec$bimonthly$post * 2L)   # 24 months
sic_treated <- siconfi |>
  dplyr::filter(.data$state_abbrev == treated_state, is.finite(.data$state_tax_revenue_real))
n_sic_pre  <- sum(sic_treated$period_date >= bim_pre_start & sic_treated$period_date < removal_month)
n_sic_post <- sum(sic_treated$period_date >= removal_month & sic_treated$period_date < post_end)
regime <- if (n_sic_pre >= regime_b_min_pre_bim && n_sic_post >= spec$bimonthly$post) "siconfi" else "confaz"
message("  regime = ", regime, "  (SICONFI pre bimesters = ", n_sic_pre, ", post = ", n_sic_post, ")")

# ── Windows + donor exclusion + period assignment ─────────────────────────────
max_pre_months       <- if (regime == "siconfi") spec$bimonthly$pre_target * 2L else spec$monthly$pre_target
monthly_window_start <- removal_month %m-% months(spec$monthly$pre_target)
monthly_window_end   <- removal_month %m+% months(spec$monthly$post - 1L)         # inclusive last post month
# Bimonthly window by explicit bimester COUNT (robust to removal landing on an
# odd month): the last pre_target bimesters before removal + the first post
# bimesters from removal. Avoids the off-by-one from month-arithmetic windows.
all_bims <- sort(unique(siconfi$period_date))
pre_bims_seq  <- utils::tail(all_bims[all_bims <  removal_month], spec$bimonthly$pre_target)
post_bims_seq <- utils::head(all_bims[all_bims >= removal_month], spec$bimonthly$post)
bim_window_start <- if (length(pre_bims_seq))  min(pre_bims_seq)  else removal_month %m-% months(spec$bimonthly$pre_target * 2L)
bim_window_end   <- if (length(post_bims_seq)) max(post_bims_seq) else removal_month %m+% months(spec$bimonthly$post * 2L - 2L)

excl_start <- removal_month %m-% months(max_pre_months)
excl_end   <- removal_month %m+% months(spec$monthly$post)
inv <- readr::read_csv(file.path(root_dir, "data", "raw", "governor_removal_events.csv"), show_col_types = FALSE) |>
  dplyr::mutate(removal_date = as.Date(.data$removal_date))
excluded_event_lookup <- inv |>
  dplyr::filter(!is.na(.data$removal_date), .data$removal_date >= excl_start, .data$removal_date <= excl_end) |>
  dplyr::group_by(.data$state_abbrev) |>
  dplyr::summarise(donor_pool_exclusion_reason = paste0("coded_removal_in_scm_window:",
                   paste(sort(unique(.data$event_id)), collapse = ",")), .groups = "drop")
excluded_donor_states <- sort(unique(c(treated_state, excluded_event_lookup$state_abbrev)))

assign_period <- function(period_date) dplyr::if_else(period_date < removal_month, "pre", "post")
panel_states  <- sort(unique(population$state_abbrev))

add_event_cols <- function(df) {
  df |>
    dplyr::mutate(
      treated_unit                  = .data$state_abbrev == treated_state,
      donor_pool_main               = !(.data$state_abbrev %in% excluded_donor_states),
      excluded_from_main_donor_pool = .data$state_abbrev %in% excluded_donor_states,
      analysis_period               = assign_period(.data$period_date),
      pre_instability_clean         = .data$analysis_period == "pre",
      instability_start_date        = instability_start_date,
      removal_date                  = removal_date
    ) |>
    dplyr::left_join(excluded_event_lookup, by = "state_abbrev") |>
    dplyr::mutate(donor_pool_exclusion_reason = dplyr::case_when(
      .data$state_abbrev == treated_state ~ "treated_unit",
      .data$excluded_from_main_donor_pool ~ .data$donor_pool_exclusion_reason,
      TRUE ~ NA_character_))
}

# ── Monthly panel (non-fiscal always; CONFAZ fiscal in Regime A) ──────────────
load_monthly <- function(f, col) readr::read_csv(dp(f), show_col_types = FALSE) |>
  dplyr::transmute(state_abbrev = .data$state_abbrev, period_date = as.Date(.data$period_date),
                   value = as.numeric(.data[[col]]))

log_pos <- function(x) ifelse(is.finite(x) & x > 0, log(x), NA_real_)

retail <- load_monthly("pmc_retail_monthly_panel_ready.csv", "retail_volume_index")
services <- load_monthly("pms_services_monthly_panel_ready.csv", "services_volume_index")
# Labor: monthly net hiring balance (flow) per 100k resident population.
caged <- load_monthly("caged_state_balance_monthly_panel_ready.csv", "formal_hiring_balance")
caged_c <- load_monthly("caged_construction_state_balance_monthly_panel_ready.csv", "formal_hiring_balance_construction")

monthly_keys <- regime_outcomes[[regime]]
monthly_keys <- monthly_keys[vapply(monthly_keys, function(k) outcome_catalog[[k]]$freq == "M", logical(1))]

# Full monthly grid for SA (union of source coverage).
all_m_dates <- sort(unique(c(retail$period_date, services$period_date, caged$period_date, caged_c$period_date)))
m_grid <- tidyr::expand_grid(state_abbrev = panel_states, period_date = all_m_dates) |>
  dplyr::mutate(year = lubridate::year(.data$period_date)) |>
  dplyr::left_join(ipca_deflator, by = "period_date")
m_grid$population <- pop_for_year(m_grid$state_abbrev, m_grid$year)

# Scaled (pre-SA) value per monthly outcome key:
#   retail/services -> SA index LEVEL (common base, no rebase)
#   formal_hiring/construction -> LOG(employment stock / pop) = log employment rate
#   icms/tax (CONFAZ) -> LOG(real per capita)
scaled_monthly <- m_grid |> dplyr::select("state_abbrev", "period_date", "year")
join_val <- function(g, src, newname) g |>
  dplyr::left_join(src |> dplyr::rename(!!newname := "value"), by = c("state_abbrev", "period_date"))

scaled_monthly <- scaled_monthly |>
  join_val(retail, "retail") |> join_val(services, "services") |>
  join_val(caged, "caged_bal") |> join_val(caged_c, "caged_c_bal")
scaled_monthly$population <- m_grid$population
scaled_monthly$ipca_deflator_factor <- m_grid$ipca_deflator_factor

build_scaled <- list(
  retail   = scaled_monthly$retail,
  services = scaled_monthly$services,
  # labor: net hiring balance (flow) per 100k resident population
  formal_hiring = 1e5 * scaled_monthly$caged_bal / scaled_monthly$population,
  construction  = 1e5 * scaled_monthly$caged_c_bal / scaled_monthly$population
)
if (regime == "confaz") {
  confaz <- readr::read_csv(dp("confaz_state_tax_revenue_monthly_panel_ready.csv"), show_col_types = FALSE) |>
    dplyr::transmute(state_abbrev = .data$state_abbrev, period_date = as.Date(.data$period_date),
                     va_icms_total = as.numeric(.data$va_icms_total),
                     va_receita_tributaria_total = as.numeric(.data$va_receita_tributaria_total))
  scaled_monthly <- scaled_monthly |> dplyr::left_join(confaz, by = c("state_abbrev", "period_date"))
  build_scaled$icms_confaz <- log_pos(scaled_monthly$va_icms_total * scaled_monthly$ipca_deflator_factor / scaled_monthly$population)
  build_scaled$tax_confaz  <- log_pos(scaled_monthly$va_receita_tributaria_total * scaled_monthly$ipca_deflator_factor / scaled_monthly$population)
}
for (k in monthly_keys) scaled_monthly[[k]] <- build_scaled[[k]]

monthly_sa <- apply_sa_to_panel(scaled_monthly, monthly_keys, "period_date", "state_abbrev", 12L)

monthly_window_dates <- seq(monthly_window_start, monthly_window_end, by = "1 month")
monthly_panel <- tidyr::expand_grid(state_abbrev = panel_states, period_date = monthly_window_dates) |>
  dplyr::mutate(year = lubridate::year(.data$period_date), month = lubridate::month(.data$period_date)) |>
  dplyr::left_join(monthly_sa |> dplyr::select("state_abbrev", "period_date", dplyr::ends_with("_sa")),
                   by = c("state_abbrev", "period_date")) |>
  add_event_cols()
# Rename <key>_sa -> <key>. Indices stay at the common-base SA level (no rebase);
# fiscal/labor are already in logs.
names(monthly_panel) <- sub("_sa$", "", names(monthly_panel))

# ── Bimonthly SICONFI panel + ICMS (Annex06) — Regime B only ──────────────────
bimonthly_panel <- NULL
bim_keys <- character(0)
if (regime == "siconfi") {
  bim_keys <- regime_outcomes[[regime]]
  bim_keys <- bim_keys[vapply(bim_keys, function(k) outcome_catalog[[k]]$freq == "B", logical(1))]

  # ICMS from RREO Annex06 (within-year differencing of cumulative realized).
  icms_raw <- readr::read_csv(file.path(root_dir, "data", "raw", "siconfi",
                  "siconfi_rreo_state_fiscal_bimonthly_annex06_raw.csv"), show_col_types = FALSE) |>
    janitor::clean_names() |>
    dplyr::filter(.data$cod_conta == "RREO6ICMS") |>
    dplyr::mutate(year = as.integer(.data$exercicio), bimester = as.integer(.data$periodo),
                  uf = as.integer(.data$cod_ibge), coluna = as.character(.data$coluna),
                  value = parse_siconfi_value(.data$valor),
                  realized = .data$coluna == "RECEITAS REALIZADAS (a)" |
                    stringr::str_detect(.data$coluna, paste0("Até o Bimestre / ", .data$year))) |>
    dplyr::filter(.data$realized) |>
    dplyr::group_by(.data$uf, .data$year, .data$bimester) |>
    dplyr::summarise(icms_cum = dplyr::first(.data$value[is.finite(.data$value)]), .groups = "drop") |>
    dplyr::group_by(.data$uf, .data$year) |>
    dplyr::arrange(.data$bimester, .by_group = TRUE) |>
    dplyr::mutate(icms_revenue_nominal = .data$icms_cum - dplyr::lag(.data$icms_cum, default = 0)) |>
    dplyr::ungroup()

  fiscal <- siconfi |>
    dplyr::mutate(year = as.integer(.data$year), bimester = as.integer(.data$bimester),
                  uf = as.integer(.data$uf)) |>
    dplyr::left_join(icms_raw |> dplyr::select("uf", "year", "bimester", "icms_revenue_nominal"),
                     by = c("uf", "year", "bimester"))
  fiscal$population <- pop_for_year(fiscal$state_abbrev, fiscal$year)
  fiscal <- fiscal |>
    dplyr::mutate(
      deflator_factor = dplyr::if_else(is.finite(.data$state_tax_revenue_nominal) & .data$state_tax_revenue_nominal > 0,
                                       .data$state_tax_revenue_real / .data$state_tax_revenue_nominal, NA_real_),
      icms_revenue_real_pc          = log_pos(.data$icms_revenue_nominal * .data$deflator_factor / .data$population),
      tax_siconfi_val               = log_pos(.data$state_tax_revenue_real / .data$population),
      investment_siconfi_val        = log_pos(.data$public_investment_liquidated_real / .data$population),
      totalexp_siconfi_val          = log_pos(.data$liquidated_expenditure_total_real / .data$population)
    )
  bim_scaled <- fiscal |>
    dplyr::transmute(.data$state_abbrev, .data$period_date,
                     icms_siconfi = .data$icms_revenue_real_pc,
                     tax_siconfi = .data$tax_siconfi_val,
                     investment_siconfi = .data$investment_siconfi_val,
                     totalexp_siconfi = .data$totalexp_siconfi_val)
  bim_sa <- apply_sa_to_panel(bim_scaled, bim_keys, "period_date", "state_abbrev", 6L)

  bim_window_dates <- siconfi$period_date[siconfi$period_date >= bim_window_start & siconfi$period_date <= bim_window_end]
  bim_window_dates <- sort(unique(bim_window_dates))
  bimonthly_panel <- tidyr::expand_grid(state_abbrev = panel_states, period_date = bim_window_dates) |>
    dplyr::left_join(bim_sa |> dplyr::select("state_abbrev", "period_date", dplyr::ends_with("_sa")),
                     by = c("state_abbrev", "period_date")) |>
    add_event_cols()
  names(bimonthly_panel) <- sub("_sa$", "", names(bimonthly_panel))
}

# ── Per-outcome qualification (treated: pre >= floor, post complete) ──────────
qualifies <- function(panel, key, freq) {
  fl <- if (freq == "M") spec$monthly$pre_floor else spec$bimonthly$pre_floor
  rp <- if (freq == "M") spec$monthly$post else spec$bimonthly$post
  t  <- panel |> dplyr::filter(.data$state_abbrev == treated_state, is.finite(.data[[key]]))
  npre <- sum(t$analysis_period == "pre"); npost <- sum(t$analysis_period == "post")
  npre >= fl && npost >= rp
}
qual_monthly <- monthly_keys[vapply(monthly_keys, function(k) qualifies(monthly_panel, k, "M"), logical(1))]
qual_bim <- if (regime == "siconfi") bim_keys[vapply(bim_keys, function(k) qualifies(bimonthly_panel, k, "B"), logical(1))] else character(0)

# ── Covariates (pre-treatment means of SA series), per regime ─────────────────
if (regime == "confaz") {
  conf_cov <- readr::read_csv(dp("confaz_state_tax_revenue_monthly_panel_ready.csv"), show_col_types = FALSE) |>
    dplyr::transmute(state_abbrev = .data$state_abbrev, period_date = as.Date(.data$period_date), year = as.integer(.data$year),
                     va_icms_secundario = as.numeric(.data$va_icms_secundario),
                     va_icms_terciario = as.numeric(.data$va_icms_terciario),
                     va_icms_energia = as.numeric(.data$va_icms_energia),
                     va_icms_combustiveis = as.numeric(.data$va_icms_combustiveis))
  tes <- readr::read_csv(dp("tesouro_transferencias_obrigatorias_state_month_panel_ready.csv"), show_col_types = FALSE) |>
    dplyr::transmute(state_abbrev = .data$state_abbrev, period_date = as.Date(.data$period_date),
                     fpe = as.numeric(.data$fpe), iof_est = as.numeric(.data$iof_est))
  cov_raw <- conf_cov |> dplyr::left_join(tes, by = c("state_abbrev", "period_date")) |>
    dplyr::left_join(ipca_deflator, by = "period_date")
  cov_raw$population <- pop_for_year(cov_raw$state_abbrev, cov_raw$year)
  for (v in c("va_icms_secundario", "va_icms_terciario", "va_icms_energia", "va_icms_combustiveis", "fpe", "iof_est"))
    cov_raw[[paste0(v, "_real_pc")]] <- cov_raw[[v]] * cov_raw$ipca_deflator_factor / cov_raw$population
  cov_vars <- covariate_sets$confaz
  cov_sa <- apply_sa_to_panel(cov_raw, cov_vars, "period_date", "state_abbrev", 12L)
  covariates <- cov_sa |>
    dplyr::mutate(analysis_period = assign_period(.data$period_date)) |>
    dplyr::filter(.data$analysis_period == "pre") |>
    dplyr::group_by(.data$state_abbrev) |>
    dplyr::summarise(dplyr::across(dplyr::all_of(paste0(cov_vars, "_sa")), ~mean(.x, na.rm = TRUE)), .groups = "drop")
  names(covariates) <- sub("_sa$", "", names(covariates))
} else {
  pnadc <- readr::read_csv(dp("pnadc_sidra_quarterly_state_covariates_panel_ready.csv"), show_col_types = FALSE) |>
    dplyr::transmute(state_abbrev = .data$state_abbrev, period_date = as.Date(.data$period_date),
                     unemployment_rate = as.numeric(.data$unemployment_rate_pnadc),
                     formalization_rate = as.numeric(.data$formalization_rate_pnadc),
                     labor_income_real = as.numeric(.data$labor_income_real_pnadc))
  pnadc_sa <- apply_sa_to_panel(pnadc, c("unemployment_rate", "formalization_rate", "labor_income_real"),
                                "period_date", "state_abbrev", 4L)
  fiscal_cov <- siconfi
  fiscal_cov$population <- pop_for_year(fiscal_cov$state_abbrev, as.integer(fiscal_cov$year))
  fiscal_cov <- fiscal_cov |>
    dplyr::mutate(health_expenditure_real_pc = .data$liquidated_expenditure_health_real / .data$population,
                  education_expenditure_real_pc = .data$liquidated_expenditure_education_real / .data$population,
                  public_security_expenditure_real_pc = .data$liquidated_expenditure_public_security_real / .data$population)
  fcov_vars <- c("transfer_dependency_ratio", "health_expenditure_real_pc",
                 "education_expenditure_real_pc", "public_security_expenditure_real_pc")
  fiscal_cov_sa <- apply_sa_to_panel(fiscal_cov, fcov_vars, "period_date", "state_abbrev", 6L)
  pre_means <- function(df, vars) df |>
    dplyr::mutate(analysis_period = assign_period(.data$period_date)) |>
    dplyr::filter(.data$analysis_period == "pre") |>
    dplyr::group_by(.data$state_abbrev) |>
    dplyr::summarise(dplyr::across(dplyr::all_of(vars), ~mean(.x, na.rm = TRUE)), .groups = "drop")
  cov_p <- pre_means(pnadc_sa, paste0(c("unemployment_rate", "formalization_rate", "labor_income_real"), "_sa"))
  cov_f <- pre_means(fiscal_cov_sa, paste0(fcov_vars, "_sa"))
  covariates <- cov_p |> dplyr::full_join(cov_f, by = "state_abbrev")
  names(covariates) <- sub("_sa$", "", names(covariates))
}
covariates <- covariates |>
  dplyr::mutate(donor_pool_main = !(.data$state_abbrev %in% excluded_donor_states),
                excluded_from_main_donor_pool = .data$state_abbrev %in% excluded_donor_states) |>
  dplyr::left_join(excluded_event_lookup, by = "state_abbrev") |>
  dplyr::mutate(donor_pool_exclusion_reason = dplyr::case_when(
    .data$state_abbrev == treated_state ~ "treated_unit",
    .data$excluded_from_main_donor_pool ~ .data$donor_pool_exclusion_reason, TRUE ~ NA_character_)) |>
  dplyr::arrange(.data$state_abbrev)

# ── Metadata + write ──────────────────────────────────────────────────────────
event_metadata <- event |>
  dplyr::mutate(
    regime = regime,
    monthly_window_start = monthly_window_start, monthly_window_end = monthly_window_end,
    bim_window_start = bim_window_start, bim_window_end = bim_window_end,
    removal_month = removal_month,
    monthly_pre_target = spec$monthly$pre_target, monthly_pre_floor = spec$monthly$pre_floor,
    monthly_post = spec$monthly$post,
    bim_pre_target = spec$bimonthly$pre_target, bim_pre_floor = spec$bimonthly$pre_floor, bim_post = spec$bimonthly$post,
    donor_exclusion_window_start = excl_start, donor_exclusion_window_end = excl_end,
    qualifying_monthly_outcomes = paste(qual_monthly, collapse = ","),
    qualifying_bimonthly_outcomes = paste(qual_bim, collapse = ","),
    covariate_set = paste(covariate_sets[[regime]], collapse = ","),
    treatment_frame = "accountability: single cut at removal_date",
    sa_method = "monthly X-13 (freq 12); bimonthly STL (freq 6)",
    deflation = paste0("IPCA real R$ of ", ipca_base_code, " (CONFAZ); SICONFI panel real columns"),
    per_capita = "resident population (annual, year clamped)"
  )

readr::write_csv(monthly_panel, file.path(d$data, paste0(event_id, "_monthly_panel.csv")), na = "")
if (!is.null(bimonthly_panel)) readr::write_csv(bimonthly_panel, file.path(d$data, paste0(event_id, "_bimonthly_panel.csv")), na = "")
readr::write_csv(covariates, file.path(d$data, paste0(event_id, "_covariates.csv")), na = "")
readr::write_csv(event_metadata, file.path(d$data, paste0(event_id, "_event_metadata.csv")), na = "")

message("  regime: ", regime)
message("  qualifying monthly outcomes: ", paste(qual_monthly, collapse = ", "))
message("  qualifying bimonthly outcomes: ", if (length(qual_bim)) paste(qual_bim, collapse = ", ") else "(none)")
message("  excluded donors: ", paste(excluded_donor_states, collapse = ", "))
message("  monthly panel rows: ", nrow(monthly_panel),
        if (!is.null(bimonthly_panel)) paste0("; bimonthly rows: ", nrow(bimonthly_panel)) else "")
