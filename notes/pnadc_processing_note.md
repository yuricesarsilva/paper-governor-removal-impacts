# PNADc Processing Note

This note records the active construction of PNADc covariates for the project.

## Active source

The active PNADc route is now SIDRA/PNADCT, not PNADc microdata.

The microdata route through `PNADcIBGE` is suspended for now because the required state-quarter covariates are available directly from official SIDRA tables. This keeps the collection lighter, easier to reproduce, and closer to the published IBGE estimates.

For cases before PNADc quarterly coverage, use the separate annual PNAD legacy block documented in:

```text
notes/pnad_legacy_processing_note.md
```

The two sources should not be merged into one continuous series.

Active script:

```text
code/01_download_data/04_download_pnadc_sidra_quarterly.R
```

Suspended microdata script:

```text
code/01_download_data/04_download_pnadc_quarterly.R
```

## SIDRA tables and variables

| Project variable | SIDRA table | SIDRA variable | SIDRA concept | Transformation |
| --- | ---: | ---: | --- | --- |
| `pnadc_population` | `6463` | `1641` | Pessoas de 14 anos ou mais de idade - Total | SIDRA value is in thousand persons; multiply by 1000 |
| `unemployment_rate_pnadc` | `6468` | `4099` | Taxa de desocupacao das pessoas de 14 anos ou mais | Divide by 100 |
| `labor_income_real_pnadc` | `6469` | `5935` | Rendimento medio mensal real efetivamente recebido em todos os trabalhos | Keep in Reais |
| `informality_rate_pnadc` | `8529` | `12466` | Taxa de informalidade das pessoas ocupadas de 14 anos ou mais | Divide by 100 |
| `formalization_rate_pnadc` | `8529` | `12466` | Complement of the official informality rate | `1 - informality_rate_pnadc` |

The source page for the selected family of tables is:

```text
https://sidra.ibge.gov.br/pesquisa/pnadct/tabelas
```

## Income variable

The income variable for the project is:

```text
labor_income_real_pnadc
```

It comes from SIDRA table `6469`, variable `5935`: real monthly average labor income effectively received in all jobs by occupied people aged 14 or more with labor income.

This is the SIDRA equivalent of the previously discussed microdata construction using `VD4020` and the PNADc deflator. For the current project pipeline, the SIDRA estimate replaces the direct microdata calculation.

Earlier discussion of household income per capita is retained only as historical context in older notes and dictionaries. It should not be used as the PNADc income measure for current specifications.

## Population concept

The project variable `pnadc_population` now uses SIDRA table `6463`, variable `1641`, category `32385` in the labor-force/occupation classification:

```text
Pessoas de 14 anos ou mais de idade - Total
```

This is not total resident population. It is the PNADc labor-market reference population used to keep the PNADc covariate block internally consistent.

## Formalization rate

The active formalization measure is derived from the official SIDRA informality rate:

```text
formalization_rate_pnadc = 1 - informality_rate_pnadc
```

where `informality_rate_pnadc` is SIDRA table `8529`, variable `12466`, divided by 100.

The earlier microdata rule based on `VD4002`, `VD4009`, and `V4019` is suspended for now. It may be revisited only if the project later needs a custom formal/informal definition not available from SIDRA.

## Frequency and unit

- Frequency: quarterly.
- Unit: UF.
- Geography: all 27 Brazilian federative units.
- Collection rule: preserve quarterly frequency at collection. Harmonization to monthly, bimonthly, or event-specific analytical windows should happen later, after coverage and timing are checked.

## Expected outputs

Raw SIDRA tables:

- `data/raw/ibge/pnadc_sidra_population_14_plus_quarterly.csv`
- `data/raw/ibge/pnadc_sidra_unemployment_rate_quarterly.csv`
- `data/raw/ibge/pnadc_sidra_labor_income_real_quarterly.csv`
- `data/raw/ibge/pnadc_sidra_informality_rate_quarterly.csv`

Registry:

- `data/raw/ibge/pnadc_sidra_quarterly_download_registry.csv`

Processed outputs:

- `data/processed/pnadc_sidra_quarterly_state_covariates_processed.csv`
- `data/processed/pnadc_sidra_quarterly_state_covariates_panel_ready.csv`

## Validation notes

- The SIDRA income value for Roraima in 2026Q1 is consistent with the earlier microdata smoke test based on `VD4020` and the PNADc deflator.
- The SIDRA formalization rate may differ from the earlier custom microdata classification. The SIDRA definition is now preferred because it is the official published IBGE indicator.
- In the downloaded SIDRA panel, population, unemployment, and real labor income cover 2012Q1 to 2026Q1 for all 27 UFs.
- Informality/formalization from table `8529` covers 2015Q4 to 2026Q1 for all 27 UFs. Earlier quarters remain missing for these two variables.
