# ── Event-study engine: configuration ─────────────────────────────────────────
# Sourced by every analysis stage. Holds the event registry, the shared analysis
# spec (windows, SA, floors), the outcome/covariate catalogs per data regime, and
# path helpers. This file performs NO data reads — it is pure configuration.
#
# Two data regimes, chosen per event by data availability (resolved in the build
# from the treated unit's SICONFI coverage; persisted to event_metadata):
#
#   Regime A ("confaz"):  fiscal outcomes from CONFAZ (monthly, X-13). Used when
#     SICONFI does not cover a complete bimonthly pre-window. Covariates: CONFAZ
#     ICMS sectors + obligatory transfers (FPE, IOF), real per capita.
#
#   Regime B ("siconfi"): fiscal outcomes from SICONFI/RREO (bimonthly, STL),
#     privileged whenever the complete (>= floor) bimonthly pre-window is met.
#     Covariates: PNADc labor (unemployment, formalization, income) + SICONFI
#     (transfer dependency, health/education/public-security expenditure pc).
#
# Non-fiscal outcomes (retail, services, formal hiring, construction) are ALWAYS
# monthly (X-13) in both regimes.

# Treated events analysed by the engine. Excluded:
#   AL_1997_01 (CONFAZ starts 1997-01: no pre-window),
#   TO_2025_01, RR_2026_01 (post-removal window still in the future).
analysis_events <- c(
  "PI_2001_01", "RR_2004_01", "PB_2009_01", "MA_2009_01", "TO_2009_01",
  "DF_2010_01", "RJ_2014_01", "AM_2017_01", "TO_2018_01", "RR_2018_01",
  "RJ_2020_01", "SC_2020_01", "SC_2021_01", "TO_2021_01", "AL_2022_01"
)

# Shared window / seasonal-adjustment spec.
spec <- list(
  monthly = list(
    freq = 12L, sa = "x13",
    pre_target = 36L, pre_floor = 20L,   # target 36 months; enter if >= 20
    post = 24L                           # require complete 24-month post
  ),
  bimonthly = list(
    freq = 6L, sa = "stl",
    pre_target = 24L, pre_floor = 21L,   # target 24 bimesters; enter if >= 21 (RR_2018 = 23, accepted)
    post = 12L                           # require complete 12-bimester (24-month) post
  )
)

# Regime B is used when the treated unit has >= this many complete SICONFI
# bimonthly pre-periods (and a complete post). Otherwise Regime A.
regime_b_min_pre_bim <- spec$bimonthly$pre_floor

# SCM predictors:
#   "yearmeans_plus_covariates" -> yearly means of the pre-outcome path + covariate
#       means. Parsimonious outcome representation so covariates retain weight
#       (Kaul, Klössner, Pfeifer & Schieler 2022). A held-out validation pilot
#       (RJ_2020) showed this matches the out-of-sample prediction of the full-lags
#       spec while giving a substantially more credible covariate balance.
#   "lags_plus_covariates"      -> full pre path + covariate means.
#   "lags_only"                 -> full pre path only (covariates dropped from fit).
scm_predictors <- "yearmeans_plus_covariates"

# ── Outcome catalog ───────────────────────────────────────────────────────────
# Pre-specified transformations (literature-grounded; see notes):
#   scaling "real_pc_log"  -> deflate to real R$, /resident pop, then LOG (fiscal R$)
#   scaling "index_level"  -> SA index level on the common base (NO window rebase)
#   scaling "log_emp_rate" -> LOG(employment stock / resident pop) = log formal
#                             employment rate (labor; stock anchored to Novo CAGED
#                             Jan/2020 + reconstructed via flows)
# transform: "log" -> the modelled series is in logs (effect read as exp(gap)-1 %)
#            "level" -> modelled in levels (effect read as gap / synthetic)
# mag_threshold: |% effect| required to count as substantive (criterion C2):
#            0.05 everywhere, 0.02 for labor (formal employment is sticky).
# panel: which built panel holds the SA series ("monthly" or "bimonthly").
outcome_catalog <- list(
  retail = list(
    label = "Retail volume index (PMC, SA level)", short = "Retail volume",
    source = "pmc", value_col = "retail_volume_index",
    freq = "M", scaling = "index_level", transform = "level", mag_threshold = 0.05,
    panel = "monthly", channel = "consumption"
  ),
  services = list(
    label = "Services volume index (PMS, SA level)", short = "Services volume",
    source = "pms", value_col = "services_volume_index",
    freq = "M", scaling = "index_level", transform = "level", mag_threshold = 0.05,
    panel = "monthly", channel = "consumption"
  ),
  formal_hiring = list(
    label = "Formal hiring balance per 100k pop", short = "Formal hiring",
    source = "caged", value_col = "formal_hiring_balance",
    freq = "M", scaling = "per100k", transform = "level", mag_threshold = 0.02,
    panel = "monthly", channel = "labor_market", effect_display = "absolute"
  ),
  construction = list(
    label = "Construction hiring balance per 100k pop", short = "Construction",
    source = "caged_construction", value_col = "formal_hiring_balance_construction",
    freq = "M", scaling = "per100k", transform = "level", mag_threshold = 0.02,
    panel = "monthly", channel = "labor_market", effect_display = "absolute"
  ),
  # Regime A fiscal (CONFAZ, monthly)
  icms_confaz = list(
    label = "ICMS value added, log real per capita (CONFAZ)", short = "ICMS",
    source = "confaz", value_col = "va_icms_total",
    freq = "M", scaling = "real_pc_log", transform = "log", mag_threshold = 0.05,
    panel = "monthly", channel = "public_sector"
  ),
  tax_confaz = list(
    label = "Tax revenue value added, log real per capita (CONFAZ)", short = "Tax revenue",
    source = "confaz", value_col = "va_receita_tributaria_total",
    freq = "M", scaling = "real_pc_log", transform = "log", mag_threshold = 0.05,
    panel = "monthly", channel = "public_sector"
  ),
  # Regime B fiscal (SICONFI, bimonthly)
  icms_siconfi = list(
    label = "ICMS revenue, log real per capita (SICONFI)", short = "ICMS",
    source = "siconfi_icms", value_col = "icms_revenue_real_pc",
    freq = "B", scaling = "prebuilt_real_pc_log", transform = "log", mag_threshold = 0.05,
    panel = "bimonthly", channel = "public_sector"
  ),
  tax_siconfi = list(
    label = "Own tax revenue, log real per capita (SICONFI)", short = "Tax revenue",
    source = "siconfi", value_col = "state_tax_revenue_real",
    freq = "B", scaling = "real_pc_log", transform = "log", mag_threshold = 0.05,
    panel = "bimonthly", channel = "public_sector"
  ),
  investment_siconfi = list(
    label = "Public investment, log real per capita (SICONFI)", short = "Public investment",
    source = "siconfi", value_col = "public_investment_liquidated_real",
    freq = "B", scaling = "real_pc_log", transform = "log", mag_threshold = 0.05,
    panel = "bimonthly", channel = "public_sector"
  ),
  totalexp_siconfi = list(
    label = "Total liquidated expenditure, log real per capita (SICONFI)", short = "Total expenditure",
    source = "siconfi", value_col = "liquidated_expenditure_total_real",
    freq = "B", scaling = "real_pc_log", transform = "log", mag_threshold = 0.05,
    panel = "bimonthly", channel = "public_sector"
  )
)

# Candidate outcomes per regime (further filtered by per-outcome window feasibility
# in the build). Order defines facet / report order.
regime_outcomes <- list(
  confaz  = c("retail", "services", "formal_hiring", "construction",
              "icms_confaz", "tax_confaz"),
  siconfi = c("retail", "services", "formal_hiring", "construction",
              "icms_siconfi", "tax_siconfi", "investment_siconfi", "totalexp_siconfi")
)

# ── Covariate catalog (pre-treatment means of SA series) ──────────────────────
# Each entry: the covariate column produced in the build's covariate table.
covariate_sets <- list(
  confaz = c(
    "va_icms_secundario_real_pc", "va_icms_terciario_real_pc",
    "va_icms_energia_real_pc", "va_icms_combustiveis_real_pc",
    "fpe_real_pc", "iof_est_real_pc"
  ),
  siconfi = c(
    "unemployment_rate", "formalization_rate", "labor_income_real",
    "transfer_dependency_ratio", "health_expenditure_real_pc",
    "education_expenditure_real_pc", "public_security_expenditure_real_pc"
  )
)

covariate_labels <- c(
  va_icms_secundario_real_pc = "ICMS secondary VA pc",
  va_icms_terciario_real_pc  = "ICMS tertiary VA pc",
  va_icms_energia_real_pc    = "ICMS energy VA pc",
  va_icms_combustiveis_real_pc = "ICMS fuels VA pc",
  fpe_real_pc = "FPE transfer pc",
  iof_est_real_pc = "IOF-state pc",
  unemployment_rate = "Unemployment rate",
  formalization_rate = "Formalization rate",
  labor_income_real = "Labor income (real)",
  transfer_dependency_ratio = "Transfer dependency ratio",
  health_expenditure_real_pc = "Health expenditure pc",
  education_expenditure_real_pc = "Education expenditure pc",
  public_security_expenditure_real_pc = "Public security expenditure pc"
)

channel_labels <- c(
  consumption   = "Household consumption",
  labor_market  = "Formal labor market",
  public_sector = "State public finances"
)

# ── Path helpers ──────────────────────────────────────────────────────────────
# Per-event results live under output/<event_id>/. Requires path_output from
# code/00_setup/00_project_paths.R to be sourced first.
event_root  <- function(event_id) file.path(path_output, event_id)
event_dirs  <- function(event_id) {
  r <- event_root(event_id)
  list(
    root    = r,
    data    = file.path(r, "data"),
    scm     = file.path(r, "scm"),
    report  = file.path(r, "report"),
    figures = file.path(r, "report", "figures"),
    tables  = file.path(r, "report", "tables"),
    notes   = file.path(r, "notes")
  )
}
ensure_event_dirs <- function(event_id) {
  d <- event_dirs(event_id)
  invisible(lapply(d, dir.create, recursive = TRUE, showWarnings = FALSE))
  d
}
summary_root <- function() file.path(path_output, "_summary")

# Read an event row from the inventory.
get_event <- function(event_id) {
  inv <- readr::read_csv(
    file.path(root_dir, "data", "raw", "governor_removal_events.csv"),
    show_col_types = FALSE
  )
  e <- inv |>
    dplyr::filter(.data$event_id == !!event_id) |>
    dplyr::slice(1) |>
    dplyr::mutate(
      instability_start_date = as.Date(.data$instability_start_date),
      removal_date           = as.Date(.data$removal_date)
    )
  if (nrow(e) == 0) stop("Event not found in inventory: ", event_id)
  e
}

# Resolve event_id from a command-line argument (engine stages are run per event).
resolve_event_id <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) < 1 || !nzchar(args[[1]])) {
    stop("This stage requires an event_id argument, e.g. Rscript <stage>.R PI_2001_01")
  }
  args[[1]]
}

# Locate the x64 Rscript used to spawn per-stage subprocesses (run_analysis.R).
find_rscript <- function() {
  cand <- c(
    file.path(R.home("bin"), "x64", "Rscript.exe"),
    file.path(R.home("bin"), "Rscript.exe"),
    file.path(R.home("bin"), "Rscript")
  )
  hit <- cand[file.exists(cand)]
  if (length(hit) == 0) stop("Rscript executable not found under ", R.home("bin"))
  hit[[1]]
}
