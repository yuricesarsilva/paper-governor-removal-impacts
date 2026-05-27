# PNADc Quarterly Roadmap

This note records the active quarterly PNADc block after the decision to migrate from microdata to SIDRA.

## Objective

Build quarterly state-level PNADc covariates for use in event-specific synthetic-control designs.

## Active variables

- `labor_income_real_pnadc`
- `pnadc_population`
- `unemployment_rate_pnadc`
- `informality_rate_pnadc`
- `formalization_rate_pnadc`

## Source and frequency

- Source: SIDRA/PNAD Continua Trimestral (`PNADCT`).
- Frequency: quarterly.
- Unit: UF.
- Geography: 27 Brazilian federative units.

The microdata path through `PNADcIBGE` is suspended for now. The project will use official published SIDRA estimates unless a later specification requires custom microdata definitions.

## SIDRA selection

| Variable | Table | Variable code | Notes |
| --- | ---: | ---: | --- |
| `pnadc_population` | `6463` | `1641` | Persons aged 14 or more, total; category `32385`; SIDRA unit is thousand persons |
| `unemployment_rate_pnadc` | `6468` | `4099` | Official unemployment rate; stored as proportion |
| `labor_income_real_pnadc` | `6469` | `5935` | Real average monthly labor income effectively received in all jobs; stored in Reais |
| `informality_rate_pnadc` | `8529` | `12466` | Official informality rate; stored as proportion |
| `formalization_rate_pnadc` | `8529` | `12466` | Computed as `1 - informality_rate_pnadc` |

## Active script

The active script is:

```text
code/01_download_data/04_download_pnadc_sidra_quarterly.R
```

The suspended microdata script is:

```text
code/01_download_data/04_download_pnadc_quarterly.R
```

## Expected outputs

Raw files:

- `data/raw/ibge/pnadc_sidra_population_14_plus_quarterly.csv`
- `data/raw/ibge/pnadc_sidra_unemployment_rate_quarterly.csv`
- `data/raw/ibge/pnadc_sidra_labor_income_real_quarterly.csv`
- `data/raw/ibge/pnadc_sidra_informality_rate_quarterly.csv`

Processed outputs:

- `data/processed/pnadc_sidra_quarterly_state_covariates_processed.csv`
- `data/processed/pnadc_sidra_quarterly_state_covariates_panel_ready.csv`

Download registry:

- `data/raw/ibge/pnadc_sidra_quarterly_download_registry.csv`

## Implementation notes

- SIDRA percentage variables are stored as proportions in processed files.
- `pnadc_population` is multiplied by 1000 because table `6463` reports values in thousand persons.
- `period_date` is the first day of the quarter.
- Raw SIDRA outputs are preserved before processing.
- The processed and panel-ready files are currently identical because the source is already state-quarter.
- Population, unemployment, and real labor income currently cover 2012Q1 to 2026Q1.
- Informality and formalization currently cover 2015Q4 to 2026Q1; values before 2015Q4 are intentionally missing because SIDRA table `8529` starts later.
