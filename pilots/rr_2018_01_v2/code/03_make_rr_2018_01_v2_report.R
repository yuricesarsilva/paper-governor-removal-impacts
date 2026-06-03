source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))

extra_packages <- c("tidyr", "quadprog", "ggplot2")
missing_extra <- extra_packages[!vapply(extra_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_extra) > 0) {
  stop("Missing required packages: ", paste(missing_extra, collapse = ", "))
}
invisible(lapply(extra_packages, library, character.only = TRUE))

pilot_id <- "rr_2018_01_v2"
treated_state <- "RR"
excluded_donor_states <- c("RR", "AM", "TO")
pilot_root <- file.path(root_dir, "pilots", pilot_id)
data_dir <- file.path(pilot_root, "data")
output_root <- file.path(pilot_root, "output")
report_dir <- file.path(pilot_root, "report")
figure_dir <- file.path(report_dir, "figures")
table_dir <- file.path(report_dir, "tables")
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)

make_slug <- function(x) {
  x |>
    stringr::str_replace_all("[^A-Za-z0-9]+", "_") |>
    stringr::str_replace_all("_+$", "") |>
    tolower()
}

event <- readr::read_csv(
  file.path(data_dir, "rr_2018_01_v2_event_metadata.csv"),
  show_col_types = FALSE
) |>
  dplyr::slice(1) |>
  dplyr::mutate(
    instability_start_date = as.Date(instability_start_date),
    removal_date = as.Date(removal_date)
  )

covariates_raw <- readr::read_csv(
  file.path(data_dir, "rr_2018_01_v2_covariates.csv"),
  show_col_types = FALSE
)

donor_pool <- covariates_raw |>
  dplyr::select(
    state_abbrev,
    donor_pool_main,
    excluded_from_main_donor_pool,
    donor_pool_exclusion_reason
  )

main_donor_states <- donor_pool |>
  dplyr::filter(donor_pool_main) |>
  dplyr::pull(state_abbrev) |>
  sort()

covariates <- covariates_raw |>
  dplyr::select(
    -dplyr::any_of(c(
      "donor_pool_main",
      "excluded_from_main_donor_pool",
      "donor_pool_exclusion_reason"
    ))
  )

monthly_panel <- readr::read_csv(
  file.path(data_dir, "rr_2018_01_v2_monthly_panel.csv"),
  show_col_types = FALSE
) |>
  dplyr::mutate(period_date = as.Date(period_date))

fiscal_panel <- readr::read_csv(
  file.path(data_dir, "rr_2018_01_v2_bimonthly_fiscal_panel.csv"),
  show_col_types = FALSE
) |>
  dplyr::mutate(period_date = as.Date(period_date))

summary_tbl <- readr::read_csv(
  file.path(output_root, "rr_2018_01_v2_scm_summary.csv"),
  show_col_types = FALSE
)

outcome_meta <- tibble::tribble(
  ~outcome, ~label, ~short_label, ~channel, ~family, ~specification, ~panel, ~preferred_smooth,
  "formal_hiring_balance_per_100k_wap", "Saldo de emprego formal por 100 mil pessoas em idade ativa", "Emprego formal", "Mercado de trabalho e investimento privado", "monthly", "raw", "monthly", FALSE,
  "icms_revenue_real_pc", "Receita de ICMS real per capita", "ICMS", "Mercado de trabalho e investimento privado", "bimonthly_fiscal", "raw", "fiscal", FALSE,
  "retail_volume_index", "Índice de volume do comércio varejista", "Comércio", "Consumo das famílias", "monthly", "raw", "monthly", FALSE,
  "services_volume_index", "Índice de volume de serviços", "Serviços", "Consumo das famílias", "monthly", "raw", "monthly", FALSE,
  "public_investment_share_total", "Investimento público liquidado como proporção da despesa total liquidada", "Investimento/despesa total", "Setor público estadual", "bimonthly_fiscal", "raw", "fiscal", FALSE,
  "priority_expenditure_share_total", "Saúde, educação e segurança pública como proporção da despesa total liquidada", "Áreas prioritárias/despesa total", "Setor público estadual", "bimonthly_fiscal", "raw", "fiscal", FALSE,
  "formal_hiring_balance_per_100k_wap_ma6_clean", "Saldo de emprego formal por 100 mil pessoas em idade ativa, média móvel limpa de 6 meses", "Emprego formal, MM6", "Mercado de trabalho e investimento privado", "monthly", "ma6_clean", "monthly", TRUE,
  "icms_revenue_real_pc_ma4_clean", "Receita de ICMS real per capita, média móvel limpa de 4 bimestres", "ICMS, MM4", "Mercado de trabalho e investimento privado", "bimonthly_fiscal", "ma4_clean", "fiscal", TRUE,
  "retail_volume_index_ma6_clean", "Índice de volume do comércio varejista, média móvel limpa de 6 meses", "Comércio, MM6", "Consumo das famílias", "monthly", "ma6_clean", "monthly", TRUE,
  "services_volume_index_ma6_clean", "Índice de volume de serviços, média móvel limpa de 6 meses", "Serviços, MM6", "Consumo das famílias", "monthly", "ma6_clean", "monthly", TRUE,
  "public_investment_share_total_ma4_clean", "Investimento público liquidado como proporção da despesa total liquidada, média móvel limpa de 4 bimestres", "Investimento/despesa total, MM4", "Setor público estadual", "bimonthly_fiscal", "ma4_clean", "fiscal", TRUE,
  "priority_expenditure_share_total_ma4_clean", "Saúde, educação e segurança pública como proporção da despesa total liquidada, média móvel limpa de 4 bimestres", "Áreas prioritárias/despesa total, MM4", "Setor público estadual", "bimonthly_fiscal", "ma4_clean", "fiscal", TRUE
)

channel_slugs <- tibble::tribble(
  ~channel, ~channel_slug,
  "Mercado de trabalho e investimento privado", "labor_investment",
  "Consumo das famílias", "consumption",
  "Setor público estadual", "public_sector"
)

outcome_meta <- outcome_meta |>
  dplyr::left_join(channel_slugs, by = "channel") |>
  dplyr::mutate(
    preliminary_outcome = dplyr::case_when(
      .data$outcome == "formal_hiring_balance_per_100k_wap_ma6_clean" ~ "formal_hiring_balance_per_100k_wap_ma6_visual",
      .data$outcome == "retail_volume_index_ma6_clean" ~ "retail_volume_index_ma6_visual",
      .data$outcome == "services_volume_index_ma6_clean" ~ "services_volume_index_ma6_visual",
      .data$outcome == "icms_revenue_real_pc_ma4_clean" ~ "icms_revenue_real_pc_ma4_visual",
      .data$outcome == "public_investment_share_total_ma4_clean" ~ "public_investment_share_total_ma4_visual",
      .data$outcome == "priority_expenditure_share_total_ma4_clean" ~ "priority_expenditure_share_total_ma4_visual",
      TRUE ~ .data$outcome
    )
  )

rr_icms_2018_audit <- fiscal_panel |>
  dplyr::filter(.data$state_abbrev == "RR", .data$year == 2018) |>
  dplyr::arrange(.data$bimester) |>
  dplyr::select(
    .data$period,
    .data$period_date,
    .data$icms_revenue_cumulative_nominal,
    .data$icms_revenue_nominal,
    .data$icms_revenue_real,
    .data$pnadc_population,
    .data$icms_revenue_real_pc,
    .data$icms_revenue_flow_is_derived,
    .data$icms_revenue_negative_flow_flag,
    .data$analysis_period
  )

readr::write_csv(
  rr_icms_2018_audit,
  file.path(table_dir, "rr_2018_icms_revenue_audit.csv"),
  na = ""
)

read_path <- function(family, specification, outcome) {
  path_file <- file.path(output_root, family, specification, paste0(make_slug(outcome), "_path.csv"))
  readr::read_csv(path_file, show_col_types = FALSE) |>
    dplyr::mutate(
      period_date = as.Date(period_date),
      outcome = outcome
    )
}

read_weights <- function(family, specification, outcome) {
  weights_file <- file.path(output_root, family, specification, paste0(make_slug(outcome), "_weights.csv"))
  readr::read_csv(weights_file, show_col_types = FALSE) |>
    dplyr::mutate(outcome = outcome)
}

path_tbl <- purrr::pmap_dfr(
  outcome_meta |>
    dplyr::select(family, specification, outcome),
  read_path
) |>
  dplyr::left_join(outcome_meta, by = "outcome")

weights_tbl <- purrr::pmap_dfr(
  outcome_meta |>
    dplyr::select(family, specification, outcome),
  read_weights
) |>
  dplyr::left_join(outcome_meta, by = "outcome")

effects_tbl <- path_tbl |>
  dplyr::group_by(
    outcome,
    label,
    short_label,
    channel,
    family,
    specification,
    preferred_smooth,
    analysis_period
  ) |>
  dplyr::summarise(
    n_periods = dplyr::n(),
    mean_gap = mean(augmented_gap, na.rm = TRUE),
    median_gap = stats::median(augmented_gap, na.rm = TRUE),
    cumulative_gap = sum(augmented_gap, na.rm = TRUE),
    rmspe = sqrt(mean(augmented_gap^2, na.rm = TRUE)),
    .groups = "drop"
  ) |>
  tidyr::pivot_wider(
    names_from = analysis_period,
    values_from = c(n_periods, mean_gap, median_gap, cumulative_gap, rmspe)
  ) |>
  dplyr::left_join(
    summary_tbl |>
      dplyr::filter(status == "estimated") |>
      dplyr::select(
        outcome,
        donor_count,
        augmented_rmspe_pre,
        augmented_rmspe_crisis,
        augmented_rmspe_post
      ),
    by = "outcome"
  )

readr::write_csv(effects_tbl, file.path(table_dir, "augmented_effects_by_outcome.csv"), na = "")

top_weights_tbl <- weights_tbl |>
  dplyr::filter(scm_weight > 0.001) |>
  dplyr::arrange(outcome, dplyr::desc(scm_weight), donor_state)

readr::write_csv(top_weights_tbl, file.path(table_dir, "top_donor_weights_by_outcome.csv"), na = "")

plot_event_layers <- function() {
  list(
    ggplot2::annotate(
      "rect",
      xmin = event$instability_start_date,
      xmax = event$removal_date,
      ymin = -Inf,
      ymax = Inf,
      fill = "gray85",
      alpha = 0.55
    ),
    ggplot2::geom_vline(
      xintercept = event$instability_start_date,
      linetype = "dotted",
      color = "gray25",
      linewidth = 0.45
    ),
    ggplot2::geom_vline(
      xintercept = event$removal_date,
      linetype = "dashed",
      color = "gray10",
      linewidth = 0.45
    )
  )
}

save_plot <- function(plot, filename, width = 9.5, height = 5.4) {
  ggplot2::ggsave(
    file.path(figure_dir, filename),
    plot,
    width = width,
    height = height,
    dpi = 300,
    bg = "white"
  )
}

make_preliminary_plot <- function(channel_name, smooth_flag) {
  selected <- outcome_meta |>
    dplyr::filter(channel == channel_name, preferred_smooth == smooth_flag)

  monthly_outcomes <- selected |>
    dplyr::filter(panel == "monthly") |>
    dplyr::pull(preliminary_outcome)
  fiscal_outcomes <- selected |>
    dplyr::filter(panel == "fiscal") |>
    dplyr::pull(preliminary_outcome)

  prep_panel <- function(data, outcomes) {
    if (length(outcomes) == 0) {
      return(list(state_data = tibble::tibble(), mean_data = tibble::tibble()))
    }

    state_data <- data |>
      dplyr::filter(.data$state_abbrev %in% c(treated_state, main_donor_states)) |>
      dplyr::select(
        .data$state_abbrev,
        .data$period_date,
        .data$analysis_period,
        dplyr::all_of(outcomes)
      ) |>
      tidyr::pivot_longer(
        dplyr::all_of(outcomes),
        names_to = "preliminary_outcome",
        values_to = "value"
      )

    mean_data <- state_data |>
      dplyr::filter(.data$state_abbrev %in% main_donor_states) |>
      dplyr::group_by(.data$period_date, .data$analysis_period, .data$preliminary_outcome) |>
      dplyr::summarise(
        value = mean(.data$value, na.rm = TRUE),
        .groups = "drop"
      ) |>
      dplyr::mutate(state_abbrev = "donor_mean")

    list(state_data = state_data, mean_data = mean_data)
  }

  prepared <- list(
    prep_panel(monthly_panel, monthly_outcomes),
    prep_panel(fiscal_panel, fiscal_outcomes)
  )

  state_plot_data <- purrr::map_dfr(prepared, "state_data") |>
    dplyr::left_join(
      selected |> dplyr::select(.data$preliminary_outcome, .data$short_label),
      by = "preliminary_outcome"
    ) |>
    dplyr::mutate(short_label = factor(.data$short_label, levels = selected$short_label))

  donor_plot_data <- state_plot_data |>
    dplyr::filter(.data$state_abbrev %in% main_donor_states)

  rr_plot_data <- state_plot_data |>
    dplyr::filter(.data$state_abbrev == treated_state)

  mean_plot_data <- purrr::map_dfr(prepared, "mean_data") |>
    dplyr::left_join(
      selected |> dplyr::select(.data$preliminary_outcome, .data$short_label),
      by = "preliminary_outcome"
    ) |>
    dplyr::mutate(
      short_label = factor(.data$short_label, levels = selected$short_label),
      series = "Média dos doadores"
    )

  rr_plot_data <- rr_plot_data |>
    dplyr::mutate(series = "Roraima")

  ggplot2::ggplot() +
    plot_event_layers() +
    ggplot2::geom_line(
      data = donor_plot_data,
      ggplot2::aes(
        x = .data$period_date,
        y = .data$value,
        group = interaction(.data$state_abbrev, .data$preliminary_outcome)
      ),
      color = "gray70",
      linewidth = 0.32,
      alpha = 0.45,
      na.rm = TRUE
    ) +
    ggplot2::geom_line(
      data = mean_plot_data,
      ggplot2::aes(x = .data$period_date, y = .data$value, color = .data$series),
      linewidth = 0.95,
      na.rm = TRUE
    ) +
    ggplot2::geom_line(
      data = rr_plot_data,
      ggplot2::aes(x = .data$period_date, y = .data$value, color = .data$series),
      linewidth = 1.05,
      na.rm = TRUE
    ) +
    ggplot2::facet_wrap(~short_label, ncol = 2, scales = "free_y") +
    ggplot2::scale_color_manual(values = c("Roraima" = "#0f5f78", "Média dos doadores" = "#222222")) +
    ggplot2::labs(
      title = paste0("Visualização preliminar: ", channel_name),
      subtitle = ifelse(
        smooth_flag,
        "Linhas cinza = doadores elegíveis; médias móveis visuais usam janelas parciais no início de cada segmento",
        "Linhas cinza = doadores elegíveis; área cinza = janela de instabilidade política"
      ),
      x = NULL,
      y = NULL,
      color = NULL
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "bottom")
}

make_scm_path_plot <- function(channel_name, smooth_flag) {
  selected <- outcome_meta |>
    dplyr::filter(channel == channel_name, preferred_smooth == smooth_flag)

  plot_data <- path_tbl |>
    dplyr::filter(outcome %in% selected$outcome) |>
    dplyr::select(period_date, outcome, treated_value, augmented_synthetic_value) |>
    dplyr::left_join(outcome_meta |> dplyr::select(outcome, short_label), by = "outcome") |>
    tidyr::pivot_longer(
      c(treated_value, augmented_synthetic_value),
      names_to = "series",
      values_to = "value"
    ) |>
    dplyr::mutate(
      series = dplyr::recode(
        series,
        treated_value = "Roraima",
        augmented_synthetic_value = "Roraima sintético aumentado"
      ),
      short_label = factor(short_label, levels = selected$short_label)
    )

  ggplot2::ggplot(plot_data, ggplot2::aes(x = period_date, y = value, color = series)) +
    plot_event_layers() +
    ggplot2::geom_line(linewidth = 0.8, na.rm = TRUE) +
    ggplot2::facet_wrap(~short_label, ncol = 2, scales = "free_y") +
    ggplot2::scale_color_manual(values = c("Roraima" = "#1f6f8b", "Roraima sintético aumentado" = "#6a3d9a")) +
    ggplot2::labs(
      title = paste0("Augmented SCM: trajetórias - ", channel_name),
      subtitle = "Apenas Augmented SCM; Classic SCM fica fora deste relatório preliminar",
      x = NULL,
      y = NULL,
      color = NULL
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "bottom")
}

make_gap_plot <- function(channel_name, smooth_flag) {
  selected <- outcome_meta |>
    dplyr::filter(channel == channel_name, preferred_smooth == smooth_flag)

  plot_data <- path_tbl |>
    dplyr::filter(outcome %in% selected$outcome) |>
    dplyr::select(period_date, outcome, short_label, augmented_gap) |>
    dplyr::mutate(short_label = factor(short_label, levels = selected$short_label))

  ggplot2::ggplot(plot_data, ggplot2::aes(x = period_date, y = augmented_gap)) +
    plot_event_layers() +
    ggplot2::geom_hline(yintercept = 0, color = "gray70", linewidth = 0.35) +
    ggplot2::geom_line(color = "#6a3d9a", linewidth = 0.8, na.rm = TRUE) +
    ggplot2::facet_wrap(~short_label, ncol = 2, scales = "free_y") +
    ggplot2::labs(
      title = paste0("Augmented SCM: efeitos estimados - ", channel_name),
      subtitle = "Efeito = valor observado em Roraima menos valor sintético aumentado",
      x = NULL,
      y = "Gap aumentado",
      color = NULL
    ) +
    ggplot2::theme_minimal(base_size = 11)
}

make_weights_plot <- function(channel_name, smooth_flag) {
  selected <- outcome_meta |>
    dplyr::filter(channel == channel_name, preferred_smooth == smooth_flag)

  plot_data <- weights_tbl |>
    dplyr::filter(outcome %in% selected$outcome, scm_weight > 0.001) |>
    dplyr::select(outcome, short_label, donor_state, scm_weight) |>
    dplyr::mutate(
      short_label = factor(short_label, levels = selected$short_label),
      donor_state = stats::reorder(donor_state, scm_weight)
    )

  ggplot2::ggplot(plot_data, ggplot2::aes(x = scm_weight, y = donor_state)) +
    ggplot2::geom_col(fill = "#6a3d9a", alpha = 0.85) +
    ggplot2::facet_wrap(~short_label, ncol = 2, scales = "free_y") +
    ggplot2::scale_x_continuous(labels = scales::percent_format(accuracy = 1)) +
    ggplot2::labs(
      title = paste0("Pesos positivos dos doadores - ", channel_name),
      subtitle = "Pesos do SCM clássico usados como base para a correção aumentada",
      x = "Peso",
      y = NULL
    ) +
    ggplot2::theme_minimal(base_size = 11)
}

channels <- unique(outcome_meta$channel)
for (channel_name in channels) {
  channel_slug <- channel_slugs$channel_slug[channel_slugs$channel == channel_name]
  for (smooth_flag in c(FALSE, TRUE)) {
    spec_slug <- ifelse(smooth_flag, "smooth", "raw")
    save_plot(
      make_preliminary_plot(channel_name, smooth_flag),
      paste0("preliminary_", channel_slug, "_", spec_slug, ".png")
    )
    save_plot(
      make_scm_path_plot(channel_name, smooth_flag),
      paste0("augmented_paths_", channel_slug, "_", spec_slug, ".png")
    )
    save_plot(
      make_gap_plot(channel_name, smooth_flag),
      paste0("augmented_gaps_", channel_slug, "_", spec_slug, ".png")
    )
    save_plot(
      make_weights_plot(channel_name, smooth_flag),
      paste0("donor_weights_", channel_slug, "_", spec_slug, ".png")
    )
  }
}

effects_plot_data <- effects_tbl |>
  dplyr::filter(!is.na(mean_gap_post)) |>
  dplyr::mutate(
    spec_label = ifelse(preferred_smooth, "Suavizado", "Bruto"),
    short_label = factor(short_label, levels = outcome_meta$short_label)
  ) |>
  dplyr::select(short_label, channel, spec_label, mean_gap_crisis, mean_gap_post) |>
  tidyr::pivot_longer(
    c(mean_gap_crisis, mean_gap_post),
    names_to = "window",
    values_to = "mean_gap"
  ) |>
  dplyr::mutate(
    window = dplyr::recode(
      window,
      mean_gap_crisis = "Crise política",
      mean_gap_post = "Pós-queda"
    )
  )

effects_plot <- ggplot2::ggplot(
  effects_plot_data,
  ggplot2::aes(x = mean_gap, y = short_label, color = window, shape = spec_label)
) +
  ggplot2::geom_vline(xintercept = 0, color = "gray70", linewidth = 0.35) +
  ggplot2::geom_point(size = 2.4, alpha = 0.9) +
  ggplot2::facet_wrap(~channel, ncol = 1, scales = "free_y") +
  ggplot2::scale_color_manual(values = c("Crise política" = "#c65a2e", "Pós-queda" = "#6a3d9a")) +
  ggplot2::labs(
    title = "Resumo dos efeitos médios por janela",
    subtitle = "Gap aumentado médio: Roraima observado menos Roraima sintético aumentado",
    x = "Gap médio",
    y = NULL,
    color = NULL,
    shape = NULL
  ) +
  ggplot2::theme_minimal(base_size = 11) +
  ggplot2::theme(legend.position = "bottom")
save_plot(effects_plot, "augmented_effect_summary.png", width = 9.5, height = 7.2)

standardize_predictors_by_row <- function(x) {
  row_means <- rowMeans(x, na.rm = TRUE)
  row_sds <- apply(x, 1, stats::sd, na.rm = TRUE)
  keep_rows <- is.finite(row_sds) & row_sds > 0
  x_standardized <- sweep(x[keep_rows, , drop = FALSE], 1, row_means[keep_rows], "-")
  x_standardized <- sweep(x_standardized, 1, row_sds[keep_rows], "/")
  list(x = x_standardized, keep_rows = keep_rows)
}

solve_scm_weights <- function(x1, x0) {
  dmat <- 2 * crossprod(x0) + diag(1e-8, ncol(x0))
  dvec <- 2 * as.numeric(crossprod(x0, x1))
  amat <- cbind(rep(1, ncol(x0)), diag(ncol(x0)))
  bvec <- c(1, rep(0, ncol(x0)))
  solution <- quadprog::solve.QP(Dmat = dmat, dvec = dvec, Amat = amat, bvec = bvec, meq = 1)
  weights <- pmax(solution$solution, 0)
  weights / sum(weights)
}

standardize_unit_predictors <- function(x_train, x_all) {
  col_means <- colMeans(x_train, na.rm = TRUE)
  col_sds <- apply(x_train, 2, stats::sd, na.rm = TRUE)
  col_sds[!is.finite(col_sds) | col_sds == 0] <- 1
  list(x_all = sweep(sweep(x_all, 2, col_means, "-"), 2, col_sds, "/"))
}

fit_ridge <- function(x, y, lambda) {
  design <- cbind(intercept = 1, x)
  penalty <- diag(ncol(design))
  penalty[1, 1] <- 0
  as.numeric(solve(crossprod(design) + lambda * penalty, crossprod(design, y)))
}

predict_ridge <- function(x, coef) {
  as.numeric(cbind(intercept = 1, x) %*% coef)
}

lambda_grid <- 10^seq(-4, 5, length.out = 30)

loocv_lambda <- function(x_train, y_train, lambdas) {
  if (nrow(x_train) < 5) {
    return(tibble::tibble(lambda = 1, cv_rmse = NA_real_))
  }
  purrr::map_dfr(
    lambdas,
    function(lambda) {
      errors <- purrr::map_dbl(
        seq_along(y_train),
        function(i) {
          coef <- fit_ridge(x_train[-i, , drop = FALSE], y_train[-i], lambda)
          y_hat <- predict_ridge(x_train[i, , drop = FALSE], coef)
          y_train[i] - y_hat
        }
      )
      tibble::tibble(lambda = lambda, cv_rmse = sqrt(mean(errors^2, na.rm = TRUE)))
    }
  ) |>
    dplyr::arrange(cv_rmse, lambda) |>
    dplyr::slice(1)
}

get_complete_states <- function(data, outcome, covariate_data) {
  outcome_states <- data |>
    dplyr::filter(analysis_period == "pre") |>
    dplyr::group_by(state_abbrev) |>
    dplyr::summarise(
      complete_pre_periods = sum(is.finite(.data[[outcome]])),
      .groups = "drop"
    ) |>
    dplyr::filter(complete_pre_periods >= 6) |>
    dplyr::pull(state_abbrev)

  covariate_states <- covariate_data |>
    dplyr::filter(stats::complete.cases(dplyr::across(-state_abbrev))) |>
    dplyr::pull(state_abbrev)

  intersect(outcome_states, covariate_states)
}

build_predictor_matrix <- function(data, outcome, states, covariate_data) {
  outcome_predictors <- data |>
    dplyr::filter(analysis_period == "pre", state_abbrev %in% states) |>
    dplyr::select(state_abbrev, period_date, value = dplyr::all_of(outcome)) |>
    tidyr::pivot_wider(names_from = state_abbrev, values_from = value) |>
    dplyr::arrange(period_date) |>
    dplyr::filter(stats::complete.cases(dplyr::across(dplyr::all_of(states))))

  outcome_matrix <- outcome_predictors |>
    dplyr::select(dplyr::all_of(states)) |>
    as.matrix()
  rownames(outcome_matrix) <- paste0("pré_", format(outcome_predictors$period_date, "%Y_%m_%d"))

  covariate_matrix <- covariate_data |>
    dplyr::filter(state_abbrev %in% states) |>
    dplyr::select(state_abbrev, dplyr::everything()) |>
    tidyr::pivot_longer(-state_abbrev, names_to = "predictor", values_to = "value") |>
    tidyr::pivot_wider(names_from = state_abbrev, values_from = value) |>
    dplyr::arrange(predictor)

  covariate_values <- covariate_matrix |>
    dplyr::select(dplyr::all_of(states)) |>
    as.matrix()
  rownames(covariate_values) <- paste0("cov_", covariate_matrix$predictor)

  predictor_matrix <- rbind(outcome_matrix, covariate_values)
  if (nrow(outcome_matrix) < 6) {
    stop("Too few complete pré-treatment periods for outcome: ", outcome)
  }
  if (anyNA(predictor_matrix)) {
    stop("Missing values in predictor matrix for outcome: ", outcome)
  }
  predictor_matrix
}

fit_augmented_scm_for_unit <- function(data, outcome, pseudo_treated_state, covariate_data) {
  complete_states <- get_complete_states(data, outcome, covariate_data)
  if (!(pseudo_treated_state %in% complete_states)) {
    stop("Pseudo-treated state has incomplete data: ", pseudo_treated_state)
  }

  donor_states <- intersect(sort(complete_states), main_donor_states)
  donor_states <- setdiff(donor_states, pseudo_treated_state)
  if (length(donor_states) < 2) {
    stop("Fewer than two donors for pseudo-treated state: ", pseudo_treated_state)
  }

  states <- c(pseudo_treated_state, donor_states)
  predictor_matrix <- build_predictor_matrix(data, outcome, states, covariate_data)
  scaled <- standardize_predictors_by_row(predictor_matrix)
  predictor_matrix_scaled <- scaled$x
  x1 <- predictor_matrix_scaled[, pseudo_treated_state, drop = FALSE]
  x0 <- predictor_matrix_scaled[, donor_states, drop = FALSE]

  scm_weights <- solve_scm_weights(x1, x0)
  names(scm_weights) <- donor_states

  unit_predictors <- t(predictor_matrix)
  donor_predictors <- unit_predictors[donor_states, , drop = FALSE]
  all_predictors <- unit_predictors[states, , drop = FALSE]
  standardized_units <- standardize_unit_predictors(donor_predictors, all_predictors)

  treated_predictor <- standardized_units$x_all[pseudo_treated_state, , drop = FALSE]
  donor_predictors_scaled <- standardized_units$x_all[donor_states, , drop = FALSE]
  weighted_donor_predictor <- matrix(as.numeric(t(scm_weights) %*% donor_predictors_scaled), nrow = 1)
  predictor_imbalance <- treated_predictor - weighted_donor_predictor

  wide <- data |>
    dplyr::filter(state_abbrev %in% states) |>
    dplyr::select(period_date, analysis_period, state_abbrev, value = dplyr::all_of(outcome)) |>
    tidyr::pivot_wider(names_from = state_abbrev, values_from = value) |>
    dplyr::arrange(period_date) |>
    dplyr::filter(stats::complete.cases(dplyr::across(dplyr::all_of(states))))

  correction_rows <- purrr::map_dfr(
    seq_len(nrow(wide)),
    function(i) {
      y_donor <- as.numeric(wide[i, donor_states, drop = TRUE])
      y_center <- mean(y_donor, na.rm = TRUE)
      y_scale <- stats::sd(y_donor, na.rm = TRUE)
      if (!is.finite(y_scale) || y_scale == 0) {
        y_scale <- 1
      }
      y_donor_scaled <- (y_donor - y_center) / y_scale
      best_lambda <- loocv_lambda(donor_predictors_scaled, y_donor_scaled, lambda_grid)
      coef <- fit_ridge(donor_predictors_scaled, y_donor_scaled, best_lambda$lambda)
      correction <- as.numeric(predictor_imbalance %*% coef[-1]) * y_scale
      tibble::tibble(period_date = wide$period_date[i], augmentation_correction = correction)
    }
  )

  scm_synthetic <- as.matrix(wide[, donor_states, drop = FALSE]) %*% scm_weights

  wide |>
    dplyr::transmute(
      period_date = period_date,
      analysis_period = analysis_period,
      treated_value = .data[[pseudo_treated_state]],
      scm_synthetic_value = as.numeric(scm_synthetic)
    ) |>
    dplyr::left_join(correction_rows, by = "period_date") |>
    dplyr::mutate(
      augmented_synthetic_value = scm_synthetic_value + augmentation_correction,
      augmented_gap = treated_value - augmented_synthetic_value,
      pseudo_treated_state = pseudo_treated_state,
      outcome = outcome
    )
}

make_placebo_for_outcome <- function(outcome, family) {
  data <- if (family == "monthly") monthly_panel else fiscal_panel
  complete_states <- get_complete_states(data, outcome, covariates)
  pseudo_states <- sort(intersect(complete_states, c(treated_state, main_donor_states)))

  purrr::map_dfr(
    pseudo_states,
    function(state) {
      tryCatch(
        fit_augmented_scm_for_unit(data, outcome, state, covariates),
        error = function(e) {
          tibble::tibble(
            period_date = as.Date(NA),
            analysis_period = NA_character_,
            treated_value = NA_real_,
            scm_synthetic_value = NA_real_,
            augmentation_correction = NA_real_,
            augmented_synthetic_value = NA_real_,
            augmented_gap = NA_real_,
            pseudo_treated_state = state,
            outcome = outcome,
            skip_reason = conditionMessage(e)
          )
        }
      )
    }
  )
}

preferred_outcomes <- outcome_meta |>
  dplyr::filter(preferred_smooth) |>
  dplyr::select(outcome, family, channel, short_label, channel_slug)

placebo_paths <- purrr::pmap_dfr(
  preferred_outcomes |> dplyr::select(outcome, family),
  make_placebo_for_outcome
) |>
  dplyr::filter(!is.na(period_date)) |>
  dplyr::left_join(outcome_meta |> dplyr::select(outcome, short_label, channel, channel_slug), by = "outcome")

placebo_summary <- placebo_paths |>
  dplyr::group_by(outcome, short_label, channel, channel_slug, pseudo_treated_state) |>
  dplyr::summarise(
    pre_rmspe = sqrt(mean(augmented_gap[analysis_period == "pre"]^2, na.rm = TRUE)),
    crisis_rmspe = sqrt(mean(augmented_gap[analysis_period == "crisis"]^2, na.rm = TRUE)),
    post_rmspe = sqrt(mean(augmented_gap[analysis_period == "post"]^2, na.rm = TRUE)),
    mean_gap_crisis = mean(augmented_gap[analysis_period == "crisis"], na.rm = TRUE),
    mean_gap_post = mean(augmented_gap[analysis_period == "post"], na.rm = TRUE),
    .groups = "drop"
  ) |>
  dplyr::mutate(
    post_pre_rmspe_ratio = post_rmspe / pre_rmspe,
    abs_post_mean_gap = abs(mean_gap_post)
  )

actual_placebo_rank <- placebo_summary |>
  dplyr::group_by(outcome) |>
  dplyr::mutate(
    ratio_rank_desc = rank(-post_pre_rmspe_ratio, ties.method = "min"),
    abs_gap_rank_desc = rank(-abs_post_mean_gap, ties.method = "min"),
    donor_placebo_count = sum(pseudo_treated_state != treated_state),
    ratio_p_value = (
      sum(
        post_pre_rmspe_ratio[pseudo_treated_state != treated_state] >=
          post_pre_rmspe_ratio[pseudo_treated_state == treated_state],
        na.rm = TRUE
      ) + 1
    ) / (donor_placebo_count + 1),
    abs_gap_p_value = (
      sum(
        abs_post_mean_gap[pseudo_treated_state != treated_state] >=
          abs_post_mean_gap[pseudo_treated_state == treated_state],
        na.rm = TRUE
      ) + 1
    ) / (donor_placebo_count + 1)
  ) |>
  dplyr::ungroup() |>
  dplyr::filter(pseudo_treated_state == treated_state)

readr::write_csv(placebo_paths, file.path(table_dir, "placebo_paths_preferred_smooth_augmented.csv"), na = "")
readr::write_csv(placebo_summary, file.path(table_dir, "placebo_summary_preferred_smooth_augmented.csv"), na = "")
readr::write_csv(actual_placebo_rank, file.path(table_dir, "placebo_rank_actual_rr.csv"), na = "")

placebo_paths_normalized <- placebo_paths |>
  dplyr::left_join(
    placebo_summary |> dplyr::select(outcome, pseudo_treated_state, pre_rmspe),
    by = c("outcome", "pseudo_treated_state")
  ) |>
  dplyr::mutate(
    normalized_gap = augmented_gap / pre_rmspe,
    unit_type = ifelse(pseudo_treated_state == treated_state, "Roraima", "Placebos")
  )

for (channel_name in channels) {
  channel_slug <- channel_slugs$channel_slug[channel_slugs$channel == channel_name]
  selected <- preferred_outcomes |> dplyr::filter(channel == channel_name)

  placebo_plot_data <- placebo_paths_normalized |>
    dplyr::filter(outcome %in% selected$outcome) |>
    dplyr::mutate(short_label = factor(short_label, levels = selected$short_label))

  placebo_plot <- ggplot2::ggplot(
    placebo_plot_data,
    ggplot2::aes(x = period_date, y = normalized_gap, group = pseudo_treated_state)
  ) +
    plot_event_layers() +
    ggplot2::geom_hline(yintercept = 0, color = "gray70", linewidth = 0.35) +
    ggplot2::geom_line(
      data = placebo_plot_data |> dplyr::filter(unit_type == "Placebos"),
      color = "gray70",
      linewidth = 0.35,
      alpha = 0.55,
      na.rm = TRUE
    ) +
    ggplot2::geom_line(
      data = placebo_plot_data |> dplyr::filter(unit_type == "Roraima"),
      color = "#6a3d9a",
      linewidth = 1.05,
      na.rm = TRUE
    ) +
    ggplot2::facet_wrap(~short_label, ncol = 2, scales = "free_y") +
    ggplot2::labs(
      title = paste0("Placebos in-space: ", channel_name),
      subtitle = "Gaps aumentados normalizados pelo RMSPE pré-tratamento de cada unidade",
      x = NULL,
      y = "Gap / RMSPE pré"
    ) +
    ggplot2::theme_minimal(base_size = 11)
  save_plot(placebo_plot, paste0("placebo_gaps_", channel_slug, "_smooth.png"))

  rank_plot_data <- placebo_summary |>
    dplyr::filter(outcome %in% selected$outcome) |>
    dplyr::mutate(
      short_label = factor(short_label, levels = selected$short_label),
      unit_type = ifelse(pseudo_treated_state == treated_state, "Roraima", "Placebo")
    )

  rank_plot <- ggplot2::ggplot(
    rank_plot_data,
    ggplot2::aes(x = post_pre_rmspe_ratio, y = short_label, color = unit_type)
  ) +
    ggplot2::geom_point(
      data = rank_plot_data |> dplyr::filter(unit_type == "Placebo"),
      alpha = 0.45,
      size = 2
    ) +
    ggplot2::geom_point(
      data = rank_plot_data |> dplyr::filter(unit_type == "Roraima"),
      size = 3.2
    ) +
    ggplot2::scale_color_manual(values = c("Roraima" = "#6a3d9a", "Placebo" = "gray65")) +
    ggplot2::labs(
      title = paste0("Razão RMSPE pós/pré dos placebos: ", channel_name),
      subtitle = "Quanto maior a razão, maior a deterioração relativa do ajuste depois da queda",
      x = "RMSPE pós / RMSPE pré",
      y = NULL,
      color = NULL
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "bottom")
  save_plot(rank_plot, paste0("placebo_rmspe_ratio_", channel_slug, "_smooth.png"))
}

format_num <- function(x, digits = 2) {
  ifelse(is.na(x), "", format(round(x, digits), nsmall = digits, big.mark = ","))
}

make_markdown_table <- function(data) {
  if (nrow(data) == 0) {
    return(character(0))
  }
  header <- paste0("| ", paste(names(data), collapse = " | "), " |")
  separator <- paste0("| ", paste(rep("---", ncol(data)), collapse = " | "), " |")
  rows <- apply(data, 1, function(row) paste0("| ", paste(row, collapse = " | "), " |"))
  c(header, separator, rows)
}

preferred_effects_md <- effects_tbl |>
  dplyr::filter(preferred_smooth) |>
  dplyr::transmute(
    Canal = channel,
    `Variável` = short_label,
    `Gap médio crise` = format_num(mean_gap_crisis),
    `Gap médio pós` = format_num(mean_gap_post),
    `RMSPE pré` = format_num(augmented_rmspe_pre),
    `RMSPE pós` = format_num(augmented_rmspe_post),
    Doadores = as.character(donor_count)
  )

raw_effects_md <- effects_tbl |>
  dplyr::filter(!preferred_smooth) |>
  dplyr::transmute(
    Canal = channel,
    `Variável` = short_label,
    `Gap médio crise` = format_num(mean_gap_crisis),
    `Gap médio pós` = format_num(mean_gap_post),
    `RMSPE pré` = format_num(augmented_rmspe_pre),
    `RMSPE pós` = format_num(augmented_rmspe_post),
    Doadores = as.character(donor_count)
  )

placebo_md <- actual_placebo_rank |>
  dplyr::transmute(
    Canal = channel,
    `Variável` = short_label,
    `Razão RMSPE pós/pré` = format_num(post_pre_rmspe_ratio),
    `p RMSPE` = format_num(ratio_p_value, 3),
    `p gap absoluto` = format_num(abs_gap_p_value, 3),
    Placebos = as.character(donor_placebo_count)
  )

figure_link <- function(filename) {
  paste0("![", filename, "](report/figures/", filename, ")")
}

report_lines <- c(
  "# RR 2018-01: Resultados preliminares do piloto V2",
  "",
  paste0("Documento gerado em ", format(Sys.Date(), "%Y-%m-%d"), "."),
  "",
  "Este documento consolida a primeira rodada de resultados para o caso de Roraima em 2018. O objetivo é organizar, em formato próximo ao de uma seção empírica de artigo, os resultados do Augmented Synthetic Control Method (Augmented SCM) para os três canais discutidos no desenho do projeto: investimento privado/mercado de trabalho, consumo das famílias e setor público estadual.",
  "",
  "## Desenho do evento",
  "",
  paste0("- Unidade tratada: `", treated_state, "`."),
  paste0("- Início da instabilidade política: `", event$instability_start_date, "`."),
  paste0("- Queda/intervenção efetiva: `", event$removal_date, "`."),
  "",
  "As observações anteriores ao início da instabilidade são tratadas como pré-tratamento limpo. A janela entre o início da instabilidade e a queda efetiva é mantida como período de crise política. As observações posteriores à queda/intervenção são tratadas como pós-tratamento.",
  "",
  "## Estratégia metodológica",
  "",
  "O pool principal de doadores exclui `RR`, `AM` e `TO`. Roraima é excluída por ser a unidade tratada. Amazonas é excluído por ter o evento `AM_2017_01` próximo ao período pré-tratamento de Roraima. Tocantins é excluído por ter eventos múltiplos e próximos ao caso de Roraima, em especial `TO_2018_01`. Assim, a especificação principal utiliza 24 UFs elegíveis como doadores.",
  "",
  "A unidade tratada é Roraima. Para cada desfecho, o método construiu uma combinação convexa de estados doadores capaz de aproximar a trajetória pré-tratamento e as covariáveis pré-evento de Roraima. Seja \\(Y_{1t}\\) o resultado observado em Roraima no período \\(t\\), e seja \\(Y_{jt}\\) o resultado observado no estado doador \\(j = 2, \\ldots, J+1\\). O sintético clássico é definido por:",
  "",
  "\\[",
  "\\widehat{Y}^{SCM}_{1t} = \\sum_{j=2}^{J+1} w_j Y_{jt}, \\qquad w_j \\geq 0, \\qquad \\sum_{j=2}^{J+1} w_j = 1.",
  "\\]",
  "",
  "Os pesos \\(w_j\\) minimizam a distância entre os preditores da unidade tratada, \\(X_1\\), e os preditores ponderados dos doadores, \\(X_0 W\\):",
  "",
  "\\[",
  "\\widehat{W} = \\arg\\min_W (X_1 - X_0 W)' V (X_1 - X_0 W),",
  "\\]",
  "",
  "sujeito às restrições de não negatividade e soma unitária. Na implementação atual, os preditores incluem a trajetória pré-tratamento completa disponível da própria variável dependente e covariáveis estaduais pré-evento: taxa de desemprego, taxa de formalização, dependência de transferências, despesa em saúde per capita, despesa em educação per capita e despesa em segurança pública per capita.",
  "",
  "O estimador principal neste relatório é o Augmented SCM. Ele preserva a estrutura de pesos do SCM e adiciona uma correção de viés estimada por regressão ridge nos doadores. De forma compacta:",
  "",
  "\\[",
  "\\widehat{Y}^{ASCM}_{1t} = \\widehat{Y}^{SCM}_{1t} + \\widehat{m}_t(X_1) - \\sum_{j=2}^{J+1} \\widehat{w}_j \\widehat{m}_t(X_j),",
  "\\]",
  "",
  "em que \\(\\widehat{m}_t(\\cdot)\\) é uma função ridge ajustada entre os estados doadores para cada período. O efeito estimado em Roraima é:",
  "",
  "\\[",
  "\\widehat{\\tau}_{1t} = Y_{1t} - \\widehat{Y}^{ASCM}_{1t}.",
  "\\]",
  "",
  "Valores positivos indicam que Roraima ficou acima do contrafactual sintético; valores negativos indicam desempenho abaixo do contrafactual. Para as variáveis mensais, o relatório mostra resultados brutos e médias móveis limpas de 6 meses. Para as variáveis bimestrais, mostra resultados brutos e médias móveis limpas de 4 bimestres. As médias móveis limpas são calculadas separadamente dentro dos segmentos pré, crise e pós, evitando que observações pré-tratamento contaminem a janela posterior.",
  "",
  "## Variáveis e canais",
  "",
  "- Mercado de trabalho e investimento privado: saldo de emprego formal por 100 mil pessoas em idade ativa e receita de ICMS real per capita.",
  "- Consumo das famílias: índice de volume do comércio varejista e índice de volume de serviços.",
  "- Setor público estadual: investimento público liquidado como proporção da despesa total e despesa em saúde, educação e segurança pública como proporção da despesa total.",
  "",
  "A normalização por população ou por escala de mercado é importante porque os estados brasileiros diferem muito em tamanho. Por isso, as variáveis fiscais são per capita, o saldo formal é expresso por 100 mil pessoas em idade ativa e as séries de comércio/serviços entram como índices de volume reancorados em 100 na primeira observação válida da janela do piloto para cada estado.",
  "",
  "## Visualização preliminar dos dados",
  "",
  "As figuras abaixo comparam Roraima com a média simples dos doadores elegíveis antes de aplicar o controle sintético. Elas não devem ser interpretadas como efeito causal; servem para expor escala, volatilidade, quebras e diferenças iniciais entre Roraima e o conjunto de comparação.",
  "",
  "Para facilitar a inspeção, as linhas cinza mostram os estados doadores elegíveis em traço fino e transparente; Roraima e a média simples dos doadores aparecem em tons mais escuros. Nas figuras suavizadas, a visualização usa médias móveis com janela parcial no começo de cada segmento: o primeiro período pós-instabilidade ou pós-queda aparece com a primeira observação disponível, e os períodos seguintes incorporam progressivamente as observações novas até completar a janela definida. A estimativa principal do SCM continua usando as séries limpas, sem misturar períodos de tratamento.",
  "",
  "A receita de ICMS foi extraída do arquivo bruto local do Siconfi/RREO, Anexo 06, conta `RREO6ICMS`. Como a fonte reporta a receita realizada acumulada até o bimestre, o fluxo bimestral usado no painel é derivado por diferença dentro de cada ano. A tabela de auditoria para Roraima em 2018 está em `report/tables/rr_2018_icms_revenue_audit.csv`.",
  "",
  "### Mercado de trabalho e investimento privado",
  "",
  figure_link("preliminary_labor_investment_raw.png"),
  "",
  figure_link("preliminary_labor_investment_smooth.png"),
  "",
  "### Consumo das famílias",
  "",
  figure_link("preliminary_consumption_raw.png"),
  "",
  figure_link("preliminary_consumption_smooth.png"),
  "",
  "### Setor público estadual",
  "",
  figure_link("preliminary_public_sector_raw.png"),
  "",
  figure_link("preliminary_public_sector_smooth.png"),
  "",
  "## Resultados principais: Augmented SCM",
  "",
  "A tabela resume os resultados para as especificações suavizadas, que são as mais informativas para leitura substantiva porque reduzem volatilidade mensal/bimestral sem misturar os segmentos de tratamento.",
  "",
  "Nas especificações suavizadas, a coluna de crise política pode ficar vazia porque a janela entre instabilidade e queda efetiva é curta demais para formar uma média móvel limpa completa dentro do próprio segmento. Nesses casos, a inferência visual da transição imediata deve usar os gráficos brutos e as figuras de média móvel visual com janela parcial; a estimativa principal suavizada permanece concentrada no período pós-queda.",
  "",
  make_markdown_table(preferred_effects_md),
  "",
  "Como leitura preliminar, a interpretação deve privilegiar três elementos: a qualidade do ajuste pré-tratamento, medida pelo RMSPE pré; o sinal e tamanho do gap durante a crise política; e a persistência do gap no período posterior à queda/intervenção.",
  "",
  "### Mercado de trabalho e investimento privado",
  "",
  figure_link("augmented_paths_labor_investment_raw.png"),
  "",
  figure_link("augmented_gaps_labor_investment_raw.png"),
  "",
  figure_link("augmented_paths_labor_investment_smooth.png"),
  "",
  figure_link("augmented_gaps_labor_investment_smooth.png"),
  "",
  "No canal de mercado de trabalho e investimento privado, o saldo formal e o ICMS real per capita capturam margens complementares. O emprego formal responde a decisões de contratação e desligamento das firmas. O ICMS é uma proxy fiscal de alta frequência para circulação tributável de bens e serviços, aproximando variações na base econômica estadual. A especificação suavizada é especialmente relevante porque ambas as séries podem ter alta volatilidade de curto prazo.",
  "",
  "### Consumo das famílias",
  "",
  figure_link("augmented_paths_consumption_raw.png"),
  "",
  figure_link("augmented_gaps_consumption_raw.png"),
  "",
  figure_link("augmented_paths_consumption_smooth.png"),
  "",
  figure_link("augmented_gaps_consumption_smooth.png"),
  "",
  "O canal de consumo é observado por comércio varejista e serviços, ambos reancorados em 100 no início da janela do piloto. A leitura conjunta é importante porque famílias podem ajustar consumo de bens e serviços de forma diferente em resposta a incerteza política, perda de renda esperada ou mudanças no funcionamento do setor público local.",
  "",
  "### Setor público estadual",
  "",
  figure_link("augmented_paths_public_sector_raw.png"),
  "",
  figure_link("augmented_gaps_public_sector_raw.png"),
  "",
  figure_link("augmented_paths_public_sector_smooth.png"),
  "",
  figure_link("augmented_gaps_public_sector_smooth.png"),
  "",
  "No canal do setor público, investimento liquidado como proporção da despesa total mede a margem de paralisação, reprogramação ou ajuste de projetos sem confundir o resultado com o tamanho absoluto do estado. A segunda variável é a proporção da despesa total direcionada a saúde, educação e segurança pública, capturando se a crise desloca ou preserva áreas centrais da prestação estatal. A série de investimento exige cautela adicional porque houve reparo de lacunas no Siconfi/RREO; por isso ela deve ser lida junto da auditoria de dados e dos resultados de robustez.",
  "",
  "### Resumo gráfico dos efeitos",
  "",
  figure_link("augmented_effect_summary.png"),
  "",
  "## Pesos dos doadores",
  "",
  "As figuras de pesos ajudam a avaliar a plausibilidade do contrafactual. Pesos muito concentrados podem indicar que poucos estados são responsáveis pela aproximação de Roraima; pesos mais dispersos sugerem uma composição mais diversificada, embora a qualidade substantiva dependa também do ajuste pré-tratamento.",
  "",
  figure_link("donor_weights_labor_investment_smooth.png"),
  "",
  figure_link("donor_weights_consumption_smooth.png"),
  "",
  figure_link("donor_weights_public_sector_smooth.png"),
  "",
  "## Robustez",
  "",
  "A primeira checagem de robustez compara especificações brutas e suavizadas. As séries brutas preservam choques de curtíssimo prazo, mas podem exagerar ruído operacional, sazonalidade residual e irregularidades administrativas. As séries suavizadas reduzem esse ruído e são, por ora, a especificação preferida para leitura substantiva.",
  "",
  "Resultados brutos:",
  "",
  make_markdown_table(raw_effects_md),
  "",
  "Resultados suavizados:",
  "",
  make_markdown_table(preferred_effects_md),
  "",
  "A segunda checagem é a separação explícita entre janela de crise política e período pós-queda. Isso evita tratar o evento como um único ponto instantâneo e permite avaliar se efeitos aparecem durante a instabilidade, depois da remoção efetiva, ou em ambos os momentos. Essa distinção é substantivamente importante porque processos legislativos ou judiciais podem afetar expectativas antes da troca formal de comando.",
  "",
  "A terceira checagem é a leitura do ajuste pré-tratamento. Resultados com RMSPE pré muito alto devem receber menor peso interpretativo, pois o contrafactual é menos crível. Nos próximos ciclos, também faz sentido acrescentar janelas alternativas de pré-tratamento e excluir doadores de alta influência para checar sensibilidade dos pesos.",
  "",
  "## Placebos in-space",
  "",
  "Os placebos in-space reestimam o Augmented SCM tratando cada estado elegível do pool principal como se tivesse recebido o tratamento, mantendo Roraima como a unidade efetivamente tratada. `AM` e `TO` não entram como placebos porque também foram excluídos do pool principal. Para os estados placebo, Roraima permanece fora do conjunto de doadores. Os gaps são normalizados pelo RMSPE pré-tratamento da própria unidade placebo:",
  "",
  "\\[",
  "g^{norm}_{it} = \\frac{Y_{it} - \\widehat{Y}^{ASCM}_{it}}{RMSPE^{pré}_i}.",
  "\\]",
  "",
  "Essa normalização torna comparáveis unidades com escalas diferentes. O teste não é uma inferência randomizada formal, mas fornece uma avaliação visual e ordinal: se Roraima estiver entre os maiores desvios pós-tratamento em relação aos placebos, o resultado é mais consistente com um efeito excepcional do evento.",
  "",
  make_markdown_table(placebo_md),
  "",
  "### Placebos por canal",
  "",
  figure_link("placebo_gaps_labor_investment_smooth.png"),
  "",
  figure_link("placebo_rmspe_ratio_labor_investment_smooth.png"),
  "",
  figure_link("placebo_gaps_consumption_smooth.png"),
  "",
  figure_link("placebo_rmspe_ratio_consumption_smooth.png"),
  "",
  figure_link("placebo_gaps_public_sector_smooth.png"),
  "",
  figure_link("placebo_rmspe_ratio_public_sector_smooth.png"),
  "",
  "## Limitações atuais",
  "",
  "- O ICMS do Anexo 06 é reportado como receita realizada acumulada; o fluxo bimestral usado no piloto é derivado por diferença dentro de cada ano.",
  "- O investimento público liquidado passou por reparo de lacunas e deve ser acompanhado por uma tabela de auditoria no apêndice.",
  "- Os placebos foram gerados para as especificações suavizadas preferidas; o mesmo procedimento pode ser estendido às séries brutas se a versão final do artigo exigir.",
  "- Este documento é uma consolidação preliminar do piloto de Roraima, não a versão final da seção de resultados do artigo.",
  "",
  "## Arquivos gerados",
  "",
  "- `report/tables/augmented_effects_by_outcome.csv`",
  "- `report/tables/top_donor_weights_by_outcome.csv`",
  "- `report/tables/placebo_paths_preferred_smooth_augmented.csv`",
  "- `report/tables/placebo_summary_preferred_smooth_augmented.csv`",
  "- `report/tables/placebo_rank_actual_rr.csv`",
  "- `report/tables/rr_2018_icms_revenue_audit.csv`",
  "- `report/figures/`"
)

readr::write_lines(report_lines, file.path(pilot_root, "rr_2018_01_v2_results_report.md"))

message("RR 2018-01 V2 report completed.")
message("Saved report to: ", file.path(pilot_root, "rr_2018_01_v2_results_report.md"))



