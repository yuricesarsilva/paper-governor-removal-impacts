# ── Formal employment STOCK (monthly) from Novo CAGED anchors + flows ──────────
# CAGED gives flows (net balances); the level (stock) is what SCM should model
# for labor (Abadie-style level outcome). The Novo CAGED publishes the formal
# employment STOCK; we use the Jan/2020 stock per UF as an anchor and reconstruct
# the monthly stock backward and forward with the (stitched) monthly net balance:
#
#   stock[t] = estoque_jan2020 + ( C[t] - C[jan2020] ),   C[t] = cumsum(balance)
#
# Built for TWO series: total formal employment and the construction sector,
# each with its own Jan/2020 anchor and its own monthly balance series. Mirrors
# how the Ministry builds the Novo CAGED estoque (RAIS base + accumulated moves).
# Caveat: backward reconstruction crosses the old/novo CAGED break (2020-01), so
# pre-2020 levels inherit a roughly common drift; within-window dynamics use the
# period's own flows.

source(file.path("code", "00_setup", "00_project_paths.R"))
source(file.path("code", "00_setup", "01_required_packages.R"))
if (!requireNamespace("readxl", quietly = TRUE)) stop("Missing package: readxl")
library(readxl)

anchor_date <- as.Date("2020-01-01")
uf_map <- c(
  "Acre"="AC","Alagoas"="AL","Amapá"="AP","Amazonas"="AM","Bahia"="BA","Ceará"="CE",
  "Distrito Federal"="DF","Espírito Santo"="ES","Goiás"="GO","Maranhão"="MA","Mato Grosso"="MT",
  "Mato Grosso do Sul"="MS","Minas Gerais"="MG","Pará"="PA","Paraíba"="PB","Paraná"="PR",
  "Pernambuco"="PE","Piauí"="PI","Rio de Janeiro"="RJ","Rio Grande do Norte"="RN",
  "Rio Grande do Sul"="RS","Rondônia"="RO","Roraima"="RR","Santa Catarina"="SC",
  "São Paulo"="SP","Sergipe"="SE","Tocantins"="TO")

read_anchor <- function(path) {
  readxl::read_excel(path) |>
    dplyr::mutate(state_abbrev = uf_map[trimws(.data$UF)]) |>
    dplyr::transmute(state_abbrev,
                     estoque_anchor = as.numeric(.data$`Estoque Mensal`),
                     saldo_anchor_file = as.numeric(.data$Saldo))
}

build_stock <- function(anchor_path, flows_path, balance_col, stock_name) {
  anchor <- read_anchor(anchor_path)
  if (any(is.na(anchor$state_abbrev))) stop("Unmapped UF in anchor: ", anchor_path)
  flows <- readr::read_csv(flows_path, show_col_types = FALSE) |>
    dplyr::mutate(period_date = as.Date(.data$period_date)) |>
    dplyr::transmute(state_abbrev, period_date, balance = as.numeric(.data[[balance_col]]))

  rec <- flows |>
    dplyr::arrange(.data$state_abbrev, .data$period_date) |>
    dplyr::group_by(.data$state_abbrev) |>
    dplyr::mutate(C = cumsum(.data$balance)) |>
    dplyr::ungroup()
  Cref <- rec |> dplyr::filter(.data$period_date == anchor_date) |>
    dplyr::transmute(state_abbrev, Cref = .data$C)
  rec <- rec |>
    dplyr::left_join(Cref, by = "state_abbrev") |>
    dplyr::left_join(anchor |> dplyr::select(state_abbrev, estoque_anchor), by = "state_abbrev") |>
    dplyr::mutate(!!stock_name := .data$estoque_anchor + .data$C - .data$Cref) |>
    dplyr::filter(!is.na(.data[[stock_name]])) |>
    dplyr::select(state_abbrev, period_date, dplyr::all_of(stock_name))

  list(stock = rec, anchor = anchor, flows = flows)
}

tot <- build_stock(file.path(path_data_raw_mte, "caged_estoque_janeiro_2020.xlsx"),
                   file.path(path_data_processed, "caged_state_balance_monthly_panel_ready.csv"),
                   "formal_hiring_balance", "formal_employment_stock")
con <- build_stock(file.path(path_data_raw_mte, "caged_estoque_construcao_janeiro_2020.xlsx"),
                   file.path(path_data_processed, "caged_construction_state_balance_monthly_panel_ready.csv"),
                   "formal_hiring_balance_construction", "construction_employment_stock")

panel <- tot$stock |>
  dplyr::full_join(con$stock, by = c("state_abbrev", "period_date")) |>
  dplyr::arrange(.data$state_abbrev, .data$period_date) |>
  dplyr::mutate(year = lubridate::year(.data$period_date), month = lubridate::month(.data$period_date),
                stock_anchor_date = anchor_date,
                stock_source = "novo_caged_jan2020_anchor + stitched CAGED flows (back/forward)")

for (col in c("formal_employment_stock", "construction_employment_stock")) {
  np <- sum(panel[[col]] <= 0, na.rm = TRUE)
  if (np > 0) warning("Non-positive ", col, ": ", np, " rows")
}

out_path <- file.path(path_data_processed, "caged_formal_employment_stock_monthly_panel_ready.csv")
readr::write_csv(panel, out_path, na = "")

# Validation: anchor saldo (file) vs panel saldo for both series.
val <- dplyr::bind_rows(
  tot$anchor |> dplyr::left_join(tot$flows |> dplyr::filter(.data$period_date == anchor_date) |>
    dplyr::transmute(state_abbrev, saldo_panel = .data$balance), by = "state_abbrev") |>
    dplyr::mutate(series = "total"),
  con$anchor |> dplyr::left_join(con$flows |> dplyr::filter(.data$period_date == anchor_date) |>
    dplyr::transmute(state_abbrev, saldo_panel = .data$balance), by = "state_abbrev") |>
    dplyr::mutate(series = "construction")
) |> dplyr::mutate(saldo_abs_diff = abs(.data$saldo_anchor_file - .data$saldo_panel))
dir.create(path_output_validation, recursive = TRUE, showWarnings = FALSE)
readr::write_csv(val, file.path(path_output_validation, "caged_employment_stock_anchor_validation.csv"), na = "")

message("Employment stock built: ", nrow(panel), " rows, ", dplyr::n_distinct(panel$state_abbrev), " states, ",
        format(min(panel$period_date)), " .. ", format(max(panel$period_date)))
message("  total stock non-NA: ", sum(!is.na(panel$formal_employment_stock)),
        "; construction non-NA: ", sum(!is.na(panel$construction_employment_stock)))
message("  anchor saldo max |diff| (total): ", round(max(val$saldo_abs_diff[val$series=="total"], na.rm=TRUE)),
        "; (construction): ", round(max(val$saldo_abs_diff[val$series=="construction"], na.rm=TRUE)))
message("Saved: ", out_path)
