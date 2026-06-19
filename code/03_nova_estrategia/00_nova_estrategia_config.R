# ── Nova Estrategia v2 engine: configuration ──────────────────────────────────
# Generalizes archive/pilots/rr_2018_01_v6/ (AugSCM, k=6, block level+slope
# predictors, ridge augmentation by LOO-CV) across every event the data
# supports. Sourced by every stage script. Performs no data reads itself.
#
# Scope (confirmed against data bounds: CAGED monthly starts 2007-01; CONFAZ
# ICMS complete only through 2023-12) cross-checked with the old engine's own
# `qualifying_monthly_outcomes` field in output/<event_id>/data/<event_id>_event_metadata.csv:
#   - 10 events get all 3 outcomes (retail, formal_hiring, icms).
#   - 5 events (CAGED does not cover the required pre-window) drop formal_hiring
#     and run with retail + icms only.
#   - AL_1997_01, TO_2025_01, RR_2026_01 are excluded entirely (not even 2
#     outcomes are viable: AL_1997_01 predates almost every source; the other
#     two have no observable post-treatment window yet).
nova_estrategia_events <- tibble::tribble(
  ~event_id,    ~treated_state, ~include_formal_hiring,
  "PI_2001_01", "PI",           FALSE,
  "RR_2004_01", "RR",           FALSE,
  "PB_2009_01", "PB",           FALSE,
  "MA_2009_01", "MA",           FALSE,
  "TO_2009_01", "TO",           FALSE,
  "DF_2010_01", "DF",           TRUE,
  "RJ_2014_01", "RJ",           TRUE,
  "AM_2017_01", "AM",           TRUE,
  "TO_2018_01", "TO",           TRUE,
  "RR_2018_01", "RR",           TRUE,
  "RJ_2020_01", "RJ",           TRUE,
  "SC_2020_01", "SC",           TRUE,
  "SC_2021_01", "SC",           TRUE,
  "TO_2021_01", "TO",           TRUE,
  "AL_2022_01", "AL",           TRUE
)

get_event_spec <- function(event_id) {
  row <- nova_estrategia_events[nova_estrategia_events$event_id == event_id, ]
  if (nrow(row) == 0) stop("Unknown event_id for nova estrategia v2: ", event_id)
  row
}

# Outcome column order is fixed: retail, [formal_hiring], icms.
get_outcome_list <- function(include_formal_hiring) {
  if (isTRUE(include_formal_hiring)) {
    c("retail_ma6_log", "formal_hiring_6m_per1k", "icms_conf6m_pc_log")
  } else {
    c("retail_ma6_log", "icms_conf6m_pc_log")
  }
}

# ── Pre-treatment blocks and post-treatment ATT windows (verbatim from the
#    rr_2018_01_v6 pilot) ───────────────────────────────────────────────────
monthly_blocks <- list(
  list(name = "block_m30_m25", start = -30L, end = -25L),
  list(name = "block_m24_m19", start = -24L, end = -19L),
  list(name = "block_m18_m13", start = -18L, end = -13L),
  list(name = "block_m12_m7",  start = -12L, end =  -7L),
  list(name = "block_m6_m1",   start =  -6L, end =  -1L)
)

# Opcao B for k=6: first clean post-treatment reading at event_time = +5.
monthly_windows <- list(
  list(name = "w3m",  start = 5L,  end = 7L),
  list(name = "w6m",  start = 5L,  end = 10L),
  list(name = "w12m", start = 5L,  end = 16L),
  list(name = "w24m", start = 5L,  end = 28L)
)

# ── Outcome metadata (label, channel, transform, evidence threshold) ─────────
outcome_catalog_v2 <- tibble::tribble(
  ~outcome,                  ~short,                        ~label,                                              ~channel,      ~transform, ~threshold,
  "retail_ma6_log",          "Varejo MA6 (log)",            "Retail volume, MA6 trailing, log",                  "consumption", "log",      0.05,
  "formal_hiring_6m_per1k",  "Emprego formal 6m (per 1k)",  "Net formal hiring, 6m sum, per 1,000 residents",    "labor",       "level",    0.5,
  "icms_conf6m_pc_log",      "ICMS CONFAZ 6m pc (log)",     "ICMS CONFAZ per capita, 6m sum, log BRL/resident",  "fiscal",      "log",      0.05
)

channel_labels_v2 <- c(
  consumption = "Household consumption",
  labor       = "Formal labor market",
  fiscal      = "State public finances"
)

# ── Covariate labels (both data regimes the old engine produced) ─────────────
# Regime "confaz": 6 CONFAZ/FPE/IOF covariates. Regime "siconfi": 7 PNADc/
# SICONFI covariates. The v2 scripts read whichever columns are actually
# present in each event's covariates.csv (see 02_run_event_scm_v2.R), so this
# lookup only supplies display labels and is a no-op for unrecognized names.
covariate_labels_lookup <- c(
  va_icms_secundario_real_pc           = "ICMS secondary VA pc",
  va_icms_terciario_real_pc            = "ICMS tertiary VA pc",
  va_icms_energia_real_pc              = "ICMS energy VA pc",
  va_icms_combustiveis_real_pc         = "ICMS fuels VA pc",
  fpe_real_pc                          = "FPE transfer pc",
  iof_est_real_pc                      = "IOF-state pc",
  unemployment_rate                    = "Unemployment rate",
  formalization_rate                   = "Formalization rate",
  labor_income_real                    = "Labor income (real)",
  transfer_dependency_ratio            = "Transfer dependency ratio",
  health_expenditure_real_pc           = "Health expenditure pc",
  education_expenditure_real_pc        = "Education expenditure pc",
  public_security_expenditure_real_pc  = "Public security expenditure pc"
)

covariate_label <- function(x) {
  out <- unname(covariate_labels_lookup[x])
  ifelse(is.na(out), x, out)
}

make_slug <- function(x) {
  x |>
    stringr::str_replace_all("[^A-Za-z0-9]+", "_") |>
    stringr::str_replace_all("_+$", "") |>
    tolower()
}

# ── Paths (output_v2/ is a new sibling of output/; output/ is left untouched) ─
path_output_v2 <- file.path(root_dir, "output_v2")

event_dirs_v2 <- function(event_id) {
  r <- file.path(path_output_v2, event_id)
  list(
    root        = r,
    data        = file.path(r, "data"),
    output      = file.path(r, "output"),
    monthly     = file.path(r, "output", "monthly"),
    placebo_loo = file.path(r, "output", "placebo_loo"),
    report      = file.path(r, "report"),
    figures     = file.path(r, "report", "figures"),
    tables      = file.path(r, "report", "tables")
  )
}

ensure_event_dirs_v2 <- function(event_id) {
  d <- event_dirs_v2(event_id)
  invisible(lapply(d, dir.create, recursive = TRUE, showWarnings = FALSE))
  d
}

summary_root_v2 <- function() file.path(path_output_v2, "_summary")

# Resolve event_id from a command-line argument (stages run one event at a time).
resolve_event_id <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) < 1 || !nzchar(args[[1]])) {
    stop("This stage requires an event_id argument, e.g. Rscript <stage>.R RR_2018_01")
  }
  args[[1]]
}

# Locate the Rscript executable used to spawn per-stage subprocesses (04_run_all_events_v2.R).
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
