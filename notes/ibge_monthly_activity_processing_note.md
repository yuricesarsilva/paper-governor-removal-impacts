# IBGE Monthly Activity Processing Note

## Scope

- This note documents the treatment of the raw `PMC` and `PMS` files downloaded from SIDRA.

## PMC

- The raw file contains two index types for each `UF` and month:
  - nominal retail revenue index
  - retail sales volume index
- The processed file pivots these two measures into separate columns:
  - `retail_nominal_revenue_index`
  - `retail_volume_index`

## PMS

- The raw file contains two index types for each `UF` and month:
  - nominal services revenue index
  - services volume index
- The processed file pivots these two measures into separate columns:
  - `services_nominal_revenue_index`
  - `services_volume_index`

## Geographic mapping

- The raw SIDRA files already identify the 27 federative units directly.
- The processing step maps the two-digit IBGE `UF` code to:
  - `state_abbrev`
  - `state_name`
  - `macroregion`

## Output files

- `data/processed/pmc_retail_monthly_processed.csv`
- `data/processed/pmc_retail_monthly_panel_ready.csv`
- `data/processed/pms_services_monthly_processed.csv`
- `data/processed/pms_services_monthly_panel_ready.csv`

## Note on panel-ready outputs

- For `PMC` and `PMS`, the processed and panel-ready files are currently identical because the raw data already come at the state level with 27 UFs and no residual non-attributable geography like the `uf = 99` category seen in Novo Caged.
