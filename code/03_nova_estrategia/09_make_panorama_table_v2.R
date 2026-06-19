# ── Nova Estrategia v2 engine: panorama table (paper body, condensed) ────────
# Condensed view of the 15 events for the Results section body: one row per
# event, one column per outcome (effect + tier marker), plus Alcance/Duracao.
# Tier markers follow the in-space donor placebo test (the literature-standard
# significance criterion), now run for all 15 events (cross_event_results.csv).
# LOO donor-exclusion is reported separately, per event, as a robustness
# check -- it does not feed these tier markers.
#
# Usage: Rscript code/03_nova_estrategia/09_make_panorama_table_v2.R

source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))
source(file.path("code", "03_nova_estrategia", "00_nova_estrategia_config.R"))

summary_dir <- summary_root_v2()

cross <- readr::read_csv(file.path(summary_dir, "cross_event_results.csv"), show_col_types = FALSE)
class_tab <- readr::read_csv(file.path(summary_dir, "nova_estrategia_cross_event_summary.csv"),
                              show_col_types = FALSE,
                              col_types = readr::cols(Hiring = readr::col_character()))

inv <- readr::read_csv(file.path(root_dir, "data", "raw", "governor_removal_events.csv"), show_col_types = FALSE) |>
  dplyr::transmute(event_id = .data$event_id, sample_class = .data$sample_class,
                   removal_mechanism = .data$removal_mechanism)

tier_mark <- function(tier) dplyr::case_when(
  tier == "strong"     ~ "***",
  tier == "moderate"   ~ "**",
  tier == "suggestive" ~ "*",
  TRUE                 ~ ""
)

cell <- function(eid, outcome_key) {
  r <- cross[cross$event_id == eid & cross$outcome == outcome_key, ]
  if (nrow(r) == 0) return("--")
  paste0(r$effect_label[[1]], tier_mark(r$tier[[1]]))
}

panorama <- purrr::map_dfr(seq_len(nrow(nova_estrategia_events)), function(i) {
  eid <- nova_estrategia_events$event_id[i]
  cls <- class_tab[class_tab$Event == eid, ]
  invr <- inv[inv$event_id == eid, ]
  tibble::tibble(
    Evento    = eid,
    Amostra   = invr$sample_class[[1]],
    Mecanismo = invr$removal_mechanism[[1]],
    Varejo    = cell(eid, "retail_ma6_log"),
    ICMS      = cell(eid, "icms_conf6m_pc_log"),
    `Emp. formal` = cell(eid, "formal_hiring_6m_per1k"),
    Alcance   = cls$Alcance[[1]],
    Duracao   = cls$Duracao[[1]]
  )
})

readr::write_csv(panorama, file.path(summary_dir, "panorama_table.csv"), na = "")

mdtab <- function(df) c(paste0("| ", paste(names(df), collapse = " | "), " |"),
  paste0("| ", paste(rep("---", ncol(df)), collapse = " | "), " |"),
  apply(df, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |")))

lines <- c(
  "# Panorama dos 15 eventos (tabela condensada para o corpo do texto)", "",
  "Marcadores de tier seguem o placebo in-space (teste padrao da literatura, Abadie-Diamond-Hainmueller): ***forte p<=0.05, **moderado p<=0.10, *sugestivo p<=0.15. Rodado para os 15 eventos.", "",
  "O placebo LOO por exclusao de doador e reportado separadamente, por evento, como checagem de robustez (estabilidade ao doador) -- nao alimenta os marcadores abaixo. Ver `placebo_rank_inspace.csv` e a secao Robustez de cada evento para o detalhe por outcome.", "",
  mdtab(panorama)
)
readr::write_lines(lines, file.path(summary_dir, "panorama_table.md"))

message("Panorama table: ", nrow(panorama), " eventos.")
print(as.data.frame(panorama), row.names = FALSE)
