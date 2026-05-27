# PNAD/PNADc Final Validation

This note closes the PNAD/PNADc covariate block before the project moves to Siconfi/RREO.

## Active rule

The project uses two separate IBGE household-survey blocks:

- PNAD legacy annual for early cases:
  - `PB_2009_01`
  - `MA_2009_01`
  - `TO_2009_01`
  - `DF_2010_01`
- PNADc/SIDRA quarterly for all later cases.

These two blocks should not be appended as a single continuous series.

## PNADc/SIDRA quarterly block

Active script:

```text
code/01_download_data/04_download_pnadc_sidra_quarterly.R
```

Panel-ready output:

```text
data/processed/pnadc_sidra_quarterly_state_covariates_panel_ready.csv
```

Validation summary:

- rows: `1539`
- coverage: `2012Q1` to `2026Q1`
- states per quarter: `27`
- duplicated `period x state_abbrev` keys: `0`
- informality/formalization starts in `2015Q4`
- missing informality/formalization rows before `2015Q4`: `405`

Variables:

- `pnadc_population`
- `unemployment_rate_pnadc`
- `labor_income_real_pnadc`
- `informality_rate_pnadc`
- `formalization_rate_pnadc`

## PNAD legacy annual block

Active script:

```text
code/01_download_data/04a_download_pnad_legacy_sidra_annual.R
```

Panel-ready output:

```text
data/processed/pnad_legacy_sidra_annual_state_covariates_panel_ready.csv
```

Validation summary:

- rows: `405`
- coverage: `2001` to `2015`
- states per year: `27`
- duplicated `year x state_abbrev` keys: `0`
- 2010 imputed rows: `27`

Variables:

- `pnad_legacy_population_10_plus`
- `labor_force_pnad_legacy`
- `unemployment_rate_pnad_legacy`
- `labor_income_real_pnad_legacy`
- `formalization_proxy_pnad_legacy`

## 2010 handling

PNAD legacy has no observed 2010 because of the 2010 Census.

The processed panel includes one imputed 2010 row per UF using linear interpolation between 2009 and 2011. These rows are flagged with:

```text
is_observed_pnad_legacy_year = FALSE
imputation_method = linear_interpolation_2009_2011
```

For `DF_2010_01`, the default synthetic-control pre-treatment PNAD covariate should use observed 2009 values rather than the imputed 2010 values, because the interpolation uses post-treatment 2011 information.

## Status

The PNAD/PNADc block is closed for the next stage. The next planned data block is Siconfi/RREO.
