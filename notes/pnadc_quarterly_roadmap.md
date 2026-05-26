# PNADc Quarterly Roadmap

This note opens the quarterly PNADc block after the CAGED block was closed.

## Objective

Build quarterly state-level PNADc covariates for use in event-specific synthetic-control designs.

## Variables to construct

- `household_income_per_capita_pnadc`
- `labor_income_real_pnadc`
- `pnadc_population`
- `unemployment_rate_pnadc`
- `formalization_rate_pnadc`

Supporting validation variables should also be kept:

- `formal_occupied_pnadc`
- `informal_occupied_pnadc`
- `classified_occupied_pnadc`
- `unemployed_pnadc`
- `labor_force_pnadc`
- standard errors for estimated totals, rates, and means when available

## Source and frequency

- Source: PNAD Continua quarterly microdata through `PNADcIBGE`.
- Frequency: quarterly.
- Unit: UF.
- Survey design: all estimates must use the survey design object returned by `PNADcIBGE::get_pnadc()` or created by `PNADcIBGE::pnadc_design()`.

## Initial script

The initial script is:

- `code/01_download_data/04_download_pnadc_quarterly.R`

It is designed to run one or multiple quarters using environment variables:

- `PNADC_START_YEAR`
- `PNADC_START_QUARTER`
- `PNADC_END_YEAR`
- `PNADC_END_QUARTER`
- `PNADC_RELOAD`

The first recommended smoke test is `2025` quarter `4`.

## Expected outputs

Raw/cache directory:

- `data/raw/ibge/pnadc/`

Processed outputs:

- `data/processed/pnadc_quarterly_state_covariates_processed.csv`
- `data/processed/pnadc_quarterly_state_covariates_panel_ready.csv`

Download/process registry:

- `data/raw/ibge/pnadc_quarterly_download_registry.csv`

## Implementation notes

- `formalization_rate_pnadc` follows the rule documented in `notes/pnadc_processing_note.md`.
- `unemployment_rate_pnadc` is computed as unemployed divided by labor force, with both totals estimated from the survey design.
- `pnadc_population` is computed as the state-level total person count from the PNADc survey design.
- `labor_income_real_pnadc` is constructed as `VD4020 * Efetivo` after downloading with `deflator = TRUE`.
- `household_income_per_capita_pnadc` uses the first available variable among the income-per-capita candidate variables defined in the processing script. The chosen source variable is saved in `income_variable_used`.
