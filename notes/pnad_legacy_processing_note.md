# PNAD Legacy Processing Note

This note records the active construction of annual legacy PNAD covariates for early removal cases.

## Scope

The legacy PNAD block is used only for removal cases whose pre-treatment period falls before the PNADc quarterly series starts.

Cases covered by this rule:

- `PB_2009_01`
- `MA_2009_01`
- `TO_2009_01`
- `DF_2010_01`

For these cases, the project should use the annual PNAD legacy block as a separate pre-treatment covariate source. For all later cases, the project should use the PNADc/SIDRA quarterly block documented in `notes/pnadc_processing_note.md`.

## Active script

```text
code/01_download_data/04a_download_pnad_legacy_sidra_annual.R
```

## Source

The active source is SIDRA/Pesquisa Nacional por Amostra de Domicilios - Pesquisa Basica.

Source page:

```text
https://sidra.ibge.gov.br/pesquisa/pnad/geral/pesquisa-basica
```

Available years in the downloaded block:

- Observed: `2001-2009` and `2011-2015`
- Imputed: `2010`

The official PNAD legacy tables do not provide 2010 because of the 2010 Census.

## SIDRA tables and variables

| Project variable | SIDRA table | SIDRA variable | SIDRA categories | Transformation |
| --- | ---: | ---: | --- | --- |
| `pnad_legacy_population_10_plus` | `1864` | `140` | condition `95355`; sex total; household situation total; age total | SIDRA value is in thousand persons; multiply by 1000 |
| `labor_force_pnad_legacy` | `1864` | `140` | condition `3287`; sex total; household situation total; age total | SIDRA value is in thousand persons; multiply by 1000 |
| `unemployed_pnad_legacy` | `1868` | `777` | occupation condition `98626`; sex total; age total | SIDRA value is in thousand persons; multiply by 1000 |
| `unemployment_rate_pnad_legacy` | derived | derived | unemployed divided by labor force | `unemployed_pnad_legacy / labor_force_pnad_legacy` |
| `labor_income_nominal_pnad_legacy` | `1871` | `778` | sex total; income class total | Keep in nominal Reais |
| `labor_income_real_pnad_legacy` | `1871` + IPCA `1737` | derived | September IPCA for PNAD year | Deflate to latest available IPCA month |
| `formalization_proxy_pnad_legacy` | `1901` | `696` | any-work social-security contributors `99325` over occupied total `0` | Contributors divided by occupied total |

## Conceptual cautions

The legacy PNAD block is not directly comparable to the PNADc quarterly block.

Key differences:

- Frequency is annual, not quarterly.
- Reference period is centered on the PNAD annual reference month, generally September.
- Main labor-market population concept is people aged 10 or more, not people aged 14 or more.
- Formalization is a proxy based on contribution to social security in any work, not the official PNADc informality indicator.

Therefore, legacy PNAD covariates should not be appended to PNADc as one continuous series.

## 2010 rule

Because PNAD legacy has no observed 2010, the script creates a 2010 row for every UF by linear interpolation between 2009 and 2011.

The imputed rows are marked with:

```text
is_observed_pnad_legacy_year = FALSE
imputation_method = linear_interpolation_2009_2011
```

Best-use rule:

- For descriptive balanced panels, the imputed 2010 values may be used with the flag retained.
- For synthetic-control pre-treatment predictors, avoid using post-treatment information. In particular, for `DF_2010_01`, the default pre-treatment PNAD legacy value should be the last observed pre-treatment year, `2009`, rather than the 2010 interpolation that uses 2011.
- If a specification uses the imputed 2010 value, it should be reported as a robustness/descriptive choice, not as the default clean pre-treatment design.

## Expected outputs

Raw SIDRA files:

- `data/raw/ibge/pnad_legacy_activity_10_plus_annual.csv`
- `data/raw/ibge/pnad_legacy_unemployed_10_plus_annual.csv`
- `data/raw/ibge/pnad_legacy_labor_income_nominal_annual.csv`
- `data/raw/ibge/pnad_legacy_previd_contribution_annual.csv`

Registry:

- `data/raw/ibge/pnad_legacy_sidra_annual_download_registry.csv`

Processed outputs:

- `data/processed/pnad_legacy_sidra_annual_state_covariates_processed.csv`
- `data/processed/pnad_legacy_sidra_annual_state_covariates_panel_ready.csv`

## Validation notes

- The processed file has 405 rows: 15 years times 27 UFs.
- The observed SIDRA years are `2001-2009` and `2011-2015`.
- The 27 rows for 2010 are imputed and explicitly flagged.
- There are no duplicated `year x state_abbrev` keys.
