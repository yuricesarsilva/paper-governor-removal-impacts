# ── Nova Estrategia v2 engine: SCM puro vs. AugSCM robustness table ──────────
# fit_augscm() (00b_augscm_core.R) already computes and saves, for every
# event-outcome, BOTH `scm_gap` (plain SCM weights, no ridge augmentation) and
# `augmented_gap` (the full AugSCM). This script just aggregates that
# already-computed pair into a compact ATT comparison table across all 15
# events, answering: "does the augmentation step change the conclusion?"
#
# Usage: Rscript code/03_nova_estrategia/08_make_robustness_tables_v2.R

source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))
source(file.path("code", "03_nova_estrategia", "00_nova_estrategia_config.R"))

summary_dir <- summary_root_v2()
dir.create(summary_dir, recursive = TRUE, showWarnings = FALSE)

windows_for_table <- list(
  w6m  = list(start = 5L, end = 10L),
  w12m = list(start = 5L, end = 16L)
)

fmt_effect <- function(att, transform) {
  ifelse(!is.finite(att), "",
         ifelse(transform == "log",
                paste0(formatC(100 * (exp(att) - 1), format = "f", digits = 1, flag = "+"), "%"),
                formatC(att, format = "f", digits = 1, flag = "+")))
}

rows <- purrr::map_dfr(seq_len(nrow(nova_estrategia_events)), function(i) {
  eid        <- nova_estrategia_events$event_id[i]
  include_fh <- nova_estrategia_events$include_formal_hiring[i]
  d  <- event_dirs_v2(eid)
  outcome_cols <- get_outcome_list(include_fh)

  purrr::map_dfr(outcome_cols, function(outcome) {
    slug <- make_slug(outcome)
    pf <- file.path(d$monthly, paste0(slug, "_path.csv"))
    if (!file.exists(pf)) return(NULL)
    p <- readr::read_csv(pf, show_col_types = FALSE)
    om <- outcome_catalog_v2[outcome_catalog_v2$outcome == outcome, ]
    transform <- om$transform[[1]]; short <- om$short[[1]]

    att_for <- function(gap_col, w) {
      v <- p[[gap_col]][p$event_time >= w$start & p$event_time <= w$end]
      v <- v[is.finite(v)]
      if (length(v) == 0) return(NA_real_)
      mean(v)
    }

    tibble::tibble(
      event_id = eid, outcome = outcome, short = short, transform = transform,
      scm_w6m  = att_for("scm_gap", windows_for_table$w6m),
      aug_w6m  = att_for("augmented_gap", windows_for_table$w6m),
      scm_w12m  = att_for("scm_gap", windows_for_table$w12m),
      aug_w12m  = att_for("augmented_gap", windows_for_table$w12m)
    )
  })
})

table_out <- rows |>
  dplyr::transmute(
    Event = .data$event_id, Outcome = .data$short,
    `SCM puro (w6m)`  = fmt_effect(.data$scm_w6m,  .data$transform),
    `AugSCM (w6m)`    = fmt_effect(.data$aug_w6m,  .data$transform),
    `SCM puro (w12m)` = fmt_effect(.data$scm_w12m, .data$transform),
    `AugSCM (w12m)`   = fmt_effect(.data$aug_w12m, .data$transform),
    `Mesmo sinal (w6m)`  = ifelse(sign(.data$scm_w6m)  == sign(.data$aug_w6m),  "sim", "nao"),
    `Mesmo sinal (w12m)` = ifelse(sign(.data$scm_w12m) == sign(.data$aug_w12m), "sim", "nao")
  )

readr::write_csv(table_out, file.path(summary_dir, "scm_puro_vs_augscm.csv"), na = "")

n_total <- nrow(table_out)
n_same_w6m  <- sum(table_out$`Mesmo sinal (w6m)`  == "sim", na.rm = TRUE)
n_same_w12m <- sum(table_out$`Mesmo sinal (w12m)` == "sim", na.rm = TRUE)
message("SCM puro vs AugSCM: ", n_total, " event-outcomes. Mesmo sinal w6m: ", n_same_w6m,
        "/", n_total, "; w12m: ", n_same_w12m, "/", n_total, ".")
print(as.data.frame(table_out), row.names = FALSE)
