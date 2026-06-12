source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

extra_packages <- c("ggplot2", "tidyr")
missing_extra <- extra_packages[!vapply(extra_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_extra) > 0) stop("Missing packages: ", paste(missing_extra, collapse = ", "))
invisible(lapply(extra_packages, library, character.only = TRUE))

pilot_id      <- "rr_2018_01_v6"
treated_state <- "RR"

pilot_root   <- file.path(root_dir, "archive", "pilots", pilot_id)
data_dir     <- file.path(pilot_root, "data")
output_root  <- file.path(pilot_root, "output")
figure_dir   <- file.path(pilot_root, "report", "figures")
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

event <- readr::read_csv(
  file.path(data_dir, "rr_2018_01_v6_event_metadata.csv"), show_col_types = FALSE
) |> dplyr::slice(1) |>
  dplyr::mutate(
    removal_date           = as.Date(.data$removal_date),
    instability_start_date = as.Date(.data$instability_start_date)
  )

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

make_slug <- function(x) {
  x |>
    stringr::str_replace_all("[^A-Za-z0-9]+", "_") |>
    stringr::str_replace_all("_+$", "") |>
    tolower()
}

# ── 3 main outcomes only ──────────────────────────────────────────────────────
outcome_meta <- tibble::tribble(
  ~outcome,                  ~short_label,                  ~etime_col,
  "retail_ma6_log",          "Varejo MA6 (log)",            "event_time",
  "formal_hiring_6m_per1k",  "Emprego formal 6m (per 1k)",  "event_time",
  "icms_conf6m_pc_log",      "ICMS CONFAZ pc 6m (log)",     "event_time"
)

# ── Theme ─────────────────────────────────────────────────────────────────────
base_theme <- function() {
  ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      legend.position     = "bottom",
      plot.title.position = "plot",
      panel.grid.minor    = ggplot2::element_blank(),
      strip.text          = ggplot2::element_text(size = 11)
    )
}

save_plot <- function(plot, filename, width = 12, height = 7) {
  ggplot2::ggsave(
    file.path(figure_dir, filename),
    plot = plot, width = width, height = height, dpi = 300, bg = "white"
  )
}

load_path <- function(outcome) {
  slug <- make_slug(outcome)
  f    <- file.path(output_root, "monthly", paste0(slug, "_path.csv"))
  if (!file.exists(f)) return(NULL)
  lbl  <- outcome_meta$short_label[outcome_meta$outcome == outcome][[1]]
  readr::read_csv(f, show_col_types = FALSE) |>
    dplyr::mutate(period_date = as.Date(.data$period_date), short_label = lbl)
}

load_weight <- function(outcome) {
  slug <- make_slug(outcome)
  f    <- file.path(output_root, "monthly", paste0(slug, "_weights.csv"))
  if (!file.exists(f)) return(NULL)
  lbl  <- outcome_meta$short_label[outcome_meta$outcome == outcome][[1]]
  readr::read_csv(f, show_col_types = FALSE) |>
    dplyr::mutate(short_label = lbl)
}

removal_dt    <- event$removal_date[[1]]
instab_dt     <- event$instability_start_date[[1]]

# ── Preliminary raw series ────────────────────────────────────────────────────
build_preliminary_plot <- function() {
  plot_data <- purrr::map_dfr(seq_len(nrow(outcome_meta)), function(i) {
    row <- outcome_meta[i, ]
    monthly_panel |>
      dplyr::filter(.data$state_abbrev %in% c(treated_state, main_donor_states)) |>
      dplyr::transmute(
        period_date  = .data$period_date,
        state_abbrev = .data$state_abbrev,
        value        = .data[[row$outcome]],
        short_label  = row$short_label,
        treated      = .data$state_abbrev == treated_state
      )
  })

  donor_mean <- plot_data |>
    dplyr::filter(!.data$treated) |>
    dplyr::group_by(.data$period_date, .data$short_label) |>
    dplyr::summarise(value = mean(.data$value, na.rm = TRUE), .groups = "drop")

  ggplot2::ggplot() +
    ggplot2::geom_line(
      data = plot_data |> dplyr::filter(!.data$treated),
      ggplot2::aes(x = .data$period_date, y = .data$value, group = .data$state_abbrev),
      color = "gray70", alpha = 0.3, linewidth = 0.4
    ) +
    ggplot2::geom_line(data = donor_mean,
      ggplot2::aes(x = .data$period_date, y = .data$value, color = "Media doadores"),
      linewidth = 0.9) +
    ggplot2::geom_line(
      data = plot_data |> dplyr::filter(.data$treated),
      ggplot2::aes(x = .data$period_date, y = .data$value, color = "Roraima"),
      linewidth = 1.1) +
    ggplot2::geom_vline(xintercept = removal_dt, linetype = "dashed", color = "gray20") +
    ggplot2::geom_vline(xintercept = instab_dt,  linetype = "dotted", color = "gray40") +
    ggplot2::scale_color_manual(
      values = c("Media doadores" = "#333333", "Roraima" = "#1f6f8b")) +
    ggplot2::facet_wrap(~short_label, scales = "free_y", ncol = 2) +
    ggplot2::labs(
      title    = "Serie bruta — outcomes principais (k=6)",
      subtitle = "Tracejada = remocao; pontilhada = inicio instabilidade",
      x = NULL, y = NULL, color = NULL
    ) +
    base_theme()
}

# ── AugSCM paths ─────────────────────────────────────────────────────────────
build_paths_plot <- function() {
  path_data <- purrr::map_dfr(outcome_meta$outcome, load_path)
  if (is.null(path_data) || nrow(path_data) == 0) return(NULL)

  path_data |>
    tidyr::pivot_longer(
      cols      = c("treated_value", "augmented_synthetic_value"),
      names_to  = "series", values_to = "value"
    ) |>
    dplyr::mutate(series = dplyr::recode(.data$series,
      treated_value             = "Roraima",
      augmented_synthetic_value = "Sintetico aug."
    )) |>
    (\(d) ggplot2::ggplot(d, ggplot2::aes(x = .data$period_date, y = .data$value,
                                           color = .data$series)) +
      ggplot2::geom_line(linewidth = 1) +
      ggplot2::geom_vline(xintercept = removal_dt, linetype = "dashed", color = "gray20") +
      ggplot2::geom_vline(xintercept = instab_dt,  linetype = "dotted", color = "gray40") +
      ggplot2::scale_color_manual(values = c("Roraima" = "#1f6f8b", "Sintetico aug." = "#6a3d9a")) +
      ggplot2::facet_wrap(~short_label, scales = "free_y", ncol = 2) +
      ggplot2::labs(title = "AugSCM — trajetorias (k=6)", x = NULL, y = NULL, color = NULL) +
      base_theme()
    )()
}

# ── AugSCM gaps ──────────────────────────────────────────────────────────────
build_gaps_plot <- function() {
  gap_data <- purrr::map_dfr(outcome_meta$outcome, load_path)
  if (is.null(gap_data) || nrow(gap_data) == 0) return(NULL)

  gap_data <- gap_data |> dplyr::filter(is.finite(.data$augmented_gap))

  ggplot2::ggplot(gap_data,
    ggplot2::aes(x = .data$period_date, y = .data$augmented_gap)) +
    ggplot2::geom_hline(yintercept = 0, color = "gray60", linewidth = 0.4) +
    ggplot2::geom_line(color = "#6a3d9a", linewidth = 1) +
    ggplot2::geom_vline(xintercept = removal_dt, linetype = "dashed", color = "gray20") +
    ggplot2::geom_vline(xintercept = instab_dt,  linetype = "dotted", color = "gray40") +
    ggplot2::facet_wrap(~short_label, scales = "free_y", ncol = 2) +
    ggplot2::labs(
      title    = "AugSCM — gaps (k=6)",
      subtitle = "Post limpo a partir de event_time = +5 (Opcao B, k=6)",
      x = NULL, y = NULL
    ) +
    base_theme()
}

# ── Donor weights ─────────────────────────────────────────────────────────────
build_weights_plot <- function() {
  w_data <- purrr::map_dfr(outcome_meta$outcome, load_weight)
  if (is.null(w_data) || nrow(w_data) == 0) return(NULL)

  w_data |>
    dplyr::filter(.data$scm_weight > 0.001) |>
    dplyr::group_by(.data$short_label) |>
    dplyr::slice_max(.data$scm_weight, n = 6, with_ties = FALSE) |>
    dplyr::ungroup() |>
    dplyr::mutate(donor_state = stats::reorder(.data$donor_state, .data$scm_weight)) |>
    (\(d) ggplot2::ggplot(d, ggplot2::aes(x = .data$scm_weight, y = .data$donor_state)) +
      ggplot2::geom_col(fill = "#7a52aa", alpha = 0.9) +
      ggplot2::facet_wrap(~short_label, scales = "free_y", ncol = 2) +
      ggplot2::scale_x_continuous(labels = function(x) paste0(round(100 * x), "%")) +
      ggplot2::labs(title = "Pesos SCM — outcomes principais", x = "Peso", y = NULL) +
      base_theme()
    )()
}

# ── ATT summary ───────────────────────────────────────────────────────────────
build_att_summary_plot <- function() {
  stbl <- readr::read_csv(
    file.path(output_root, "rr_2018_01_v6_scm_summary.csv"), show_col_types = FALSE
  )

  win_cols   <- c("att_mean_w6m", "att_mean_w12m", "att_mean_w3m")
  win_labels <- c(att_mean_w6m = "w6m [5,10]", att_mean_w12m = "w12m [5,16]",
                  att_mean_w3m = "w3m [5,7]")

  plot_data <- stbl |>
    dplyr::filter(.data$status == "estimated") |>
    dplyr::select("outcome", dplyr::any_of(win_cols)) |>
    tidyr::pivot_longer(-"outcome", names_to = "window", values_to = "att_mean") |>
    dplyr::filter(is.finite(.data$att_mean)) |>
    dplyr::mutate(
      window  = dplyr::recode(.data$window, !!!win_labels),
      outcome = dplyr::recode(.data$outcome,
        retail_ma6_log          = "Varejo MA6",
        icms_conf6m_pc_log      = "ICMS CONFAZ pc 6m",
        formal_hiring_6m_per1k  = "Emprego formal 6m (per 1k)"
      )
    )

  if (nrow(plot_data) == 0) return(NULL)

  ggplot2::ggplot(plot_data,
    ggplot2::aes(x = .data$window, y = .data$att_mean, fill = .data$outcome)) +
    ggplot2::geom_col(position = "dodge", alpha = 0.9) +
    ggplot2::geom_hline(yintercept = 0, color = "gray50") +
    ggplot2::scale_fill_brewer(palette = "Set2") +
    ggplot2::labs(
      title = "ATT medio por janela — outcomes principais (k=6)",
      x = "Janela pos-tratamento", y = "ATT medio (aug.)", fill = NULL
    ) +
    base_theme()
}

# ── Render ────────────────────────────────────────────────────────────────────
p <- build_preliminary_plot()
save_plot(p, "preliminary_main_outcomes.png")
message("Saved: preliminary_main_outcomes.png")

p <- build_paths_plot()
if (!is.null(p)) { save_plot(p, "paths_main_outcomes.png"); message("Saved: paths_main_outcomes.png") }

p <- build_gaps_plot()
if (!is.null(p)) { save_plot(p, "gaps_main_outcomes.png"); message("Saved: gaps_main_outcomes.png") }

p <- build_weights_plot()
if (!is.null(p)) { save_plot(p, "weights_main_outcomes.png"); message("Saved: weights_main_outcomes.png") }

p <- build_att_summary_plot()
if (!is.null(p)) { save_plot(p, "att_summary.png", width = 9, height = 5); message("Saved: att_summary.png") }

message("RR 2018-01 V6 figures complete (k=6, 3 main outcomes only).")
