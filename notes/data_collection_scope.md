# Data Collection Scope

This note defines the current scope of data collection for the project.

## General rules

- Keep each series in its original frequency at the collection stage.
- Use `IPCA` as the standard deflator for nominal fiscal series.
- Store the original series first; do not impose transformations at the collection stage.
- Monthly series should remain monthly.
- Bimonthly series should remain bimonthly.
- Annual series should remain annual.

## Main outcomes to collect

### Monthly

- `formal_hiring_balance`
- `retail_volume_index`
- `services_volume_index`

### Bimonthly

- `public_investment_liquidated_real`
- `liquidated_expenditure_total_real`
- `liquidated_expenditure_health_real`
- `liquidated_expenditure_education_real`
- `liquidated_expenditure_public_security_real`

### PNADc frequency to preserve

- `labor_income_real_pnadc`
- `pnadc_population`
- `unemployment_rate_pnadc`
- `informality_rate_pnadc`
- `formalization_rate_pnadc`

These PNADc variables should be stored at the original frequency provided by the selected IBGE/PNADc tables. The project should not force them into monthly frequency at the collection stage.

## Covariates to collect

### Dynamic covariates

- `formal_hiring_balance`
- `retail_volume_index`
- `services_volume_index`
- `state_tax_revenue_real`
- `total_revenue_real`
- `federal_transfers_real`
- `transfer_dependency_ratio`
- `own_revenue_ratio`
- `unemployment_rate_pnadc`
- `informality_rate_pnadc`
- `formalization_rate_pnadc`

### Structural covariates

- `pnadc_population`
- `labor_income_real_pnadc`
- `gdp_per_capita_real`

## Special note on annual covariates

- `pnadc_population`, `labor_income_real_pnadc`, and `gdp_per_capita_real` may enter as lower-frequency covariates depending on source availability.
- They are retained because they help characterize states structurally.
- They should not dominate the dynamic matching block in monthly or bimonthly SCM designs.
- For post-2023 treatments, `gdp_per_capita_real` may use the last available pre-treatment value.
- The preferred population concept for new covariate construction is the population concept used in the PNADc tables selected for the project.

## Special note on PNADc variables

- `labor_income_real_pnadc` is now preferred over GDP per capita as the main PNADc income covariate candidate.
- The active PNADc source is SIDRA/PNADCT, collected with `code/01_download_data/04_download_pnadc_sidra_quarterly.R`.
- `pnadc_population` should use SIDRA table `6463`, variable `1641`, category `32385`, which is persons aged 14 or more.
- `unemployment_rate_pnadc` should use SIDRA table `6468`, variable `4099`.
- `labor_income_real_pnadc` should use SIDRA table `6469`, variable `5935`.
- `informality_rate_pnadc` should use SIDRA table `8529`, variable `12466`.
- `formalization_rate_pnadc` should be constructed as `1 - informality_rate_pnadc`.
- The PNADc microdata route is suspended for now.
- These variables should be developed alongside the Siconfi/RREO block before final model assembly.

## Special note on legacy PNAD variables

- Cases `PB_2009_01`, `MA_2009_01`, `TO_2009_01`, and `DF_2010_01` should use annual PNAD legacy covariates instead of PNADc covariates.
- The active legacy source is SIDRA/PNAD Pesquisa Basica.
- The active script is `code/01_download_data/04a_download_pnad_legacy_sidra_annual.R`.
- Legacy PNAD covariates should remain annual and separate from PNADc quarterly covariates.
- The 2010 values are imputed from 2009 and 2011 and must retain the imputation flag.
- For `DF_2010_01`, the default SCM pre-treatment PNAD legacy covariate should use observed 2009 values rather than the imputed 2010 row.

## Special note on employment data

- Formal employment is an important outcome and covariate family in the project.
- When necessary, the employment series may combine `Old Caged` and `Novo Caged`.
- In those cases, the final analytical files should include a methodological-break control such as `post_2020_caged_dummy`.
- The original collected series should still preserve the source distinction.
