# Current Data Inventory

This note summarizes the project data currently available for the next empirical phase.

## Event inventory

Source file:

- `data/raw/governor_removal_events.csv`

Coverage:

- 13 rupture events.
- Event dates from `2009-02-17` to `2026-04-30`.
- Analytical classes: `main`, `extended`, and `borderline`.

Main-sample events currently coded:

- `PB_2009_01`: Cassio Cunha Lima, electoral cassation, `2009-02-17`.
- `MA_2009_01`: Jackson Lago, electoral cassation, `2009-04-17`.
- `TO_2009_01`: Marcelo Miranda, electoral cassation, `2009-09-08`.
- `AM_2017_01`: Jose Melo, electoral cassation, `2017-05-04`.
- `TO_2018_01`: Marcelo Miranda, electoral cassation, `2018-03-22`.
- `RJ_2020_01`: Wilson Witzel, judicial suspension and impeachment sequence, `2020-08-28`.
- `TO_2021_01`: Mauro Carlesse, judicial suspension followed by resignation, `2021-10-20`.

Extended or borderline events remain available for robustness or secondary analyses.

## Processed state-time panels

| Block | Final file | Frequency | Rows | UFs | Available period | Main variables |
| --- | --- | --- | ---: | ---: | --- | --- |
| CAGED final | `data/processed/caged_state_balance_monthly_panel_ready.csv` | monthly | 6,237 | 27 | `2007-01` to `2026-03` | `formal_hiring_balance`, `post_2020_caged_dummy`, `caged_method_break_dummy` |
| PMC retail | `data/processed/pmc_retail_monthly_panel_ready.csv` | monthly | 8,505 | 27 | `2000-01` to `2026-03` | `retail_volume_index`, `retail_nominal_revenue_index` |
| PMS services | `data/processed/pms_services_monthly_panel_ready.csv` | monthly | 4,914 | 27 | `2011-01` to `2026-02` | `services_volume_index`, `services_nominal_revenue_index` |
| PNADc SIDRA | `data/processed/pnadc_sidra_quarterly_state_covariates_panel_ready.csv` | quarterly | 1,539 | 27 | `2012Q1` to `2026Q1` | `pnadc_population`, `unemployment_rate_pnadc`, `labor_income_real_pnadc`, `informality_rate_pnadc`, `formalization_rate_pnadc` |
| PNAD legacy | `data/processed/pnad_legacy_sidra_annual_state_covariates_panel_ready.csv` | annual | 405 | 27 | `2001` to `2015` | `pnad_legacy_population_10_plus`, `labor_force_pnad_legacy`, `unemployment_rate_pnad_legacy`, `formalization_proxy_pnad_legacy`, `labor_income_real_pnad_legacy` |
| Siconfi/RREO | `data/processed/siconfi_rreo_state_fiscal_bimonthly_panel_ready.csv` | bimonthly | 1,811 | 27 | `2015B1` to `2026B2` | revenue, expenditure, investment, federal transfers, fiscal ratios |

## CAGED final

Use the final combined file:

- `data/processed/caged_state_balance_monthly_panel_ready.csv`

Do not use the intermediate Old CAGED or Novo CAGED files as the final outcome unless the goal is source diagnostics or a robustness exercise.

Main analytical variable:

- `formal_hiring_balance`

Controls to retain when the window crosses the January 2020 break:

- `post_2020_caged_dummy`
- `caged_method_break_dummy`

Coverage:

- Monthly state panel from `2007-01` to `2026-03`.
- 27 UFs in every month.

Main caveat:

- The series combines Old CAGED before `2020-01` and adjusted Novo CAGED from `2020-01` onward. Specifications crossing the break should explicitly include the break controls.

## PMC retail

Final file:

- `data/processed/pmc_retail_monthly_panel_ready.csv`

Frequency and coverage:

- Monthly.
- `2000-01` to `2026-03`.
- 27 UFs.

Main variables:

- `retail_volume_index`
- `retail_nominal_revenue_index`

Recommended use:

- `retail_volume_index` as the main real retail activity outcome.

## PMS services

Final file:

- `data/processed/pms_services_monthly_panel_ready.csv`

Frequency and coverage:

- Monthly.
- `2011-01` to `2026-02`.
- 27 UFs.

Main variables:

- `services_volume_index`
- `services_nominal_revenue_index`

Recommended use:

- `services_volume_index` as the main real services activity outcome.

## PNADc quarterly covariates

Final file:

- `data/processed/pnadc_sidra_quarterly_state_covariates_panel_ready.csv`

Frequency and coverage:

- Quarterly.
- `2012Q1` to `2026Q1`.
- 27 UFs.

Main variables:

- `pnadc_population`
- `unemployment_rate_pnadc`
- `labor_income_real_pnadc`
- `informality_rate_pnadc`
- `formalization_rate_pnadc`

Current source rule:

- Active route is SIDRA/PNADCT, not PNADc microdata.
- `formalization_rate_pnadc` is computed as `1 - informality_rate_pnadc`.

Recommended use:

- Dynamic or slow-moving covariates depending on each case window.
- Especially useful for events from `2012` onward.

## PNAD legacy annual covariates

Final file:

- `data/processed/pnad_legacy_sidra_annual_state_covariates_panel_ready.csv`

Frequency and coverage:

- Annual.
- `2001` to `2015`.
- 27 UFs.

Main variables:

- `pnad_legacy_population_10_plus`
- `labor_force_pnad_legacy`
- `unemployment_rate_pnad_legacy`
- `formalization_proxy_pnad_legacy`
- `labor_income_real_pnad_legacy`

Recommended use:

- Pre-PNADc cases, especially `PB_2009_01`, `MA_2009_01`, `TO_2009_01`, and `DF_2010_01`.

Caveat:

- Legacy PNAD is annual and should not be appended to PNADc as a fully comparable continuous series.
- The `2010` PNAD legacy rows are interpolated from 2009 and 2011. For `DF_2010_01`, the default clean pre-treatment value should be the latest observed pre-treatment year, `2009`.

## Siconfi/RREO fiscal panel

Final file:

- `data/processed/siconfi_rreo_state_fiscal_bimonthly_panel_ready.csv`

Frequency and coverage:

- Bimonthly.
- `2015B1` to `2026B2`.
- 27 UFs overall.

Preferred balanced window:

- `2015B1` to `2025B6`.

Main variables:

- `total_revenue_real`
- `state_tax_revenue_real`
- `federal_current_transfers_nominal`
- `federal_capital_transfers_nominal`
- `federal_transfers_real`
- `transfer_dependency_ratio`
- `own_revenue_ratio`
- `liquidated_expenditure_total_real`
- `liquidated_expenditure_health_real`
- `liquidated_expenditure_education_real`
- `liquidated_expenditure_public_security_real`
- `public_investment_liquidated_cumulative_nominal`
- `public_investment_liquidated_real`
- `public_investment_flow_is_derived`
- `public_investment_negative_flow_flag`

Caveats:

- `2026B2` is incomplete in the current extraction and should be excluded unless refreshed later.
- Siconfi/RREO does not cover dynamic fiscal covariates before `2015` through the current API route.
- Public investment is missing for all UF-bimesters in `2015-2017` under the current Anexo 06 mapping, and has 493 missing rows overall.
- Total and function-level liquidated expenditure has 5 missing UF-bimesters: `RN/2015B6`, `RR/2016B2`, `BA/2016B6`, `SC/2017B1`, and `RR/2019B1`.
- One negative derived investment flow is flagged: `MS/2020B6`.

## Practical implication for the next phase

The core data collection phase is closed for the first round of empirical work.

The natural next step is to build event-specific analytical panels. For each event, define:

- treated UF and donor pool;
- treatment date and first treated period at each frequency;
- pre-treatment and post-treatment windows;
- outcome family: employment, retail, services, or fiscal;
- admissible covariates given frequency and pre-treatment coverage;
- exclusions driven by data availability, especially for Siconfi pre-2015 and incomplete 2026 observations.
