# Siconfi/RREO Processing Note

This note records the initial investigation of the Siconfi/RREO block before implementing the downloader.

## Source

The active source candidate is the Tesouro Nacional/Siconfi open-data API for RREO:

```text
https://apidatalake.tesouro.gov.br/ords/siconfi/tt/rreo
```

Official documentation and metadata:

- `https://www.tesourotransparente.gov.br/consultas/consultas-siconfi/siconfi-api-de-dados-abertos`
- `http://apidatalake.tesouro.gov.br/docs/siconfi/#/RREO/get_rreo`
- `https://www.tesourotransparente.gov.br/ckan/dataset/api-rreo-entes/resource/42631872-e20e-4c91-b010-9e9ca54a851b`

The API returns JSON. The official Tesouro page says the API does not require user identification and returns 5,000 items per page by default, so the final downloader must handle pagination.

## Initial API pattern

Example query used in investigation:

```text
https://apidatalake.tesouro.gov.br/ords/siconfi/tt/rreo?an_exercicio=2024&nr_periodo=1&co_tipo_demonstrativo=RREO&no_anexo=RREO-Anexo%2001&id_ente=14
```

Key parameters:

- `an_exercicio`: fiscal year
- `nr_periodo`: RREO bimester, usually `1` to `6`
- `co_tipo_demonstrativo`: `RREO`
- `no_anexo`: RREO annex name, for example `RREO-Anexo 01`
- `id_ente`: IBGE UF code for state-level queries

Core columns observed:

- `exercicio`
- `periodo`
- `periodicidade`
- `instituicao`
- `cod_ibge`
- `uf`
- `populacao`
- `anexo`
- `esfera`
- `rotulo`
- `coluna`
- `cod_conta`
- `conta`
- `valor`

## Coverage

Smoke test for Roraima, RREO Anexo 01, first bimester:

- `2009-2014`: no rows returned
- `2015`: rows returned
- `2024`: rows returned
- `2026`: rows returned

Working assumption for the first downloader:

- Start with `2015` through the latest available year.
- Query six bimesters per year.
- Keep a registry of missing `year x bimester x UF x annex` combinations.

This means Siconfi/RREO will not solve fiscal pre-treatment covariates for the 2009/2010 cases through this API route. Those early cases will need either other fiscal sources or specifications without Siconfi dynamic fiscal predictors.

## Candidate annexes

The investigation used Roraima, 2024, first bimester. Available annexes included:

- `RREO-Anexo 01`
- `RREO-Anexo 02`
- `RREO-Anexo 03`
- `RREO-Anexo 04`
- `RREO-Anexo 06`
- `RREO-Anexo 07`
- `RREO-Anexo 14`

Recommended initial extraction:

- `RREO-Anexo 01`: budget balance, revenue and expenditure totals.
- `RREO-Anexo 02`: expenditure by function/subfunction.
- `RREO-Anexo 06`: primary result, with investment account available.

Hold for later:

- `RREO-Anexo 03`: Receita Corrente Liquida and adjustments, useful for debt/personnel denominator checks.
- `RREO-Anexo 04`: RPPS details, not needed for the first fiscal block.
- `RREO-Anexo 07`: restos a pagar, useful for robustness but not first pass.
- `RREO-Anexo 14`: simplified report, useful for cross-checking totals but not preferred as the primary source.

## Candidate variables

### Revenue variables

Use `RREO-Anexo 01`, column:

```text
No Bimestre (b)
```

Candidate mappings:

| Project variable | Annex | `cod_conta` | Notes |
| --- | --- | --- | --- |
| `total_revenue_nominal` | `RREO-Anexo 01` | `ReceitasExcetoIntraOrcamentarias` | Total revenue excluding intra-budgetary revenue |
| `state_tax_revenue_nominal` | `RREO-Anexo 01` | `ReceitaTributaria` | Taxes, fees, and improvement contributions |
| `federal_current_transfers_nominal` | `RREO-Anexo 01` | `TransferenciasCorrentesDaUniaoEDeSuasEntidades` | Current transfers from the Union and its entities |
| `federal_capital_transfers_nominal` | `RREO-Anexo 01` | `TransferenciasDeCapitalDaUniaoEDeSuasEntidades` | Capital transfers from the Union and its entities |
| `federal_transfers_nominal` | derived | current + capital Union transfers | Preferred transfer-dependency numerator |

Derived ratios:

```text
transfer_dependency_ratio = federal_transfers_nominal / total_revenue_nominal
own_revenue_ratio = state_tax_revenue_nominal / total_revenue_nominal
```

### Expenditure variables

Use `RREO-Anexo 02`, column:

```text
DESPESAS LIQUIDADAS NO BIMESTRE
```

Candidate mappings:

| Project variable | Annex | `conta` | `cod_conta` | Notes |
| --- | --- | --- | --- | --- |
| `liquidated_expenditure_total_nominal` | `RREO-Anexo 02` | `DESPESAS (EXCETO INTRA-ORCAMENTARIAS) (I)` | `RREO2TotalDespesas` | Total expenditure excluding intra-budgetary expenditure |
| `liquidated_expenditure_health_nominal` | `RREO-Anexo 02` | `Saude` | `RREO2TotalDespesas` | Function-level row |
| `liquidated_expenditure_education_nominal` | `RREO-Anexo 02` | `Educacao` | `RREO2TotalDespesas` | Function-level row |
| `liquidated_expenditure_public_security_nominal` | `RREO-Anexo 02` | `Seguranca Publica` | `RREO2TotalDespesas` | Function-level row |

The final script should match function rows carefully. The API text may arrive with encoding artifacts in console display, so matching should use exact raw strings from the downloaded JSON/CSV after confirming encoding with `readr`.

### Investment variable

Use `RREO-Anexo 06`, account:

```text
cod_conta = RREO6Investimentos
conta = Investimentos
```

Candidate column:

```text
DESPESAS LIQUIDADAS
```

Project variable:

```text
public_investment_liquidated_nominal
```

Open check:

- Resolved: `DESPESAS LIQUIDADAS` in Anexo 06 is year-to-date cumulative in the tested layouts.
- The bimonthly investment flow should be computed by differencing within each `UF x year`.
- Keep the original cumulative value as an audit column.

Investigation sample:

- UFs tested: `RR`, `RJ`, `SC`, and `TO`.
- Years tested: `2018`, `2020`, and `2024`.
- Pattern: cumulative values for `RREO6Investimentos` generally increase across bimesters within the same year.
- Differenced values produce plausible bimonthly flows.
- Some bimesters have zero derived flow when the cumulative value is unchanged from the previous bimester.

## Flow versus cumulative rule

Preferred collection target:

```text
bimonthly flow
```

Rationale:

- The empirical design prioritizes monthly or bimonthly dynamics.
- RREO tables often include both "No Bimestre" and "Ate o Bimestre" style columns.
- For Anexo 01 and Anexo 02, the preferred columns are explicitly bimonthly.

Rule:

- Use "No Bimestre" columns when available.
- If only cumulative columns are available for a selected variable, create both:
  - cumulative original value
  - derived bimonthly flow by within-year differencing
- Flag derived values.

For investment specifically:

```text
public_investment_liquidated_cumulative_nominal =
  RREO-Anexo 06 / RREO6Investimentos / DESPESAS LIQUIDADAS

public_investment_liquidated_nominal =
  cumulative_value - lag(cumulative_value) within UF x year
```

For the first bimester of each year:

```text
public_investment_liquidated_nominal =
  public_investment_liquidated_cumulative_nominal
```

## Deflation

Nominal Siconfi/RREO values should be deflated using the project IPCA series from SIDRA table `1737`.

Initial rule:

- Use the second month of each bimester as the price reference:
  - bimester 1: February
  - bimester 2: April
  - bimester 3: June
  - bimester 4: August
  - bimester 5: October
  - bimester 6: December
- Deflate to the latest available IPCA month used elsewhere in the project.

Real output names should use the existing project convention:

- `public_investment_liquidated_real`
- `liquidated_expenditure_total_real`
- `liquidated_expenditure_health_real`
- `liquidated_expenditure_education_real`
- `liquidated_expenditure_public_security_real`
- `state_tax_revenue_real`
- `total_revenue_real`
- `federal_transfers_real`

Ratios remain nominal-ratio variables and should not be deflated.

## Expected output design

Raw directory:

```text
data/raw/siconfi/
```

Expected raw files:

- `rreo_state_annex01_raw.csv`
- `rreo_state_annex02_raw.csv`
- `rreo_state_annex06_raw.csv`
- `rreo_download_registry.csv`

Expected processed files:

- `data/processed/siconfi_rreo_state_fiscal_bimonthly_processed.csv`
- `data/processed/siconfi_rreo_state_fiscal_bimonthly_panel_ready.csv`

Expected key:

```text
year x bimester x state_abbrev
```

Recommended date variable:

```text
period_date = first day of the second month in the bimester
```

Examples:

- `2024B1`: `2024-02-01`
- `2024B2`: `2024-04-01`
- `2024B6`: `2024-12-01`

## Validation plan before use

Minimum validation checks:

- 27 UFs per available `year x bimester`, or explicit missing registry.
- No duplicated `year x bimester x state_abbrev` rows in panel-ready output.
- For Anexo 01 and Anexo 02, verify that selected bimonthly values are not cumulative.
- For Anexo 06 investment, verify that the first-difference rule creates no unexpected negative flows; any negative flows should be retained but flagged for inspection rather than silently truncated.
- Check that ratios stay in plausible ranges.
- Compare `liquidated_expenditure_total_nominal` from Anexo 02 with a compatible total in Anexo 14 for a sample of years/UFs.
- Check negative values and missing values by account, state, and year.

## Open decisions

1. Whether to include intra-budgetary expenditure/revenue in any robustness variant.
2. Whether `state_tax_revenue_nominal` should use the broad `ReceitaTributaria` account from Anexo 01 or a narrower own-revenue construction from another Siconfi table.
3. Whether federal transfers should include only Union current transfers or current plus capital transfers. Initial recommendation: current plus capital.
4. Whether the main fiscal outcome should use bimonthly flow only, or also keep year-to-date values as robustness predictors. Initial recommendation: use bimonthly flow as the main series and keep cumulative values for audit only.
5. How to handle the lack of RREO API coverage before 2015 for the early 2009/2010 cases.

## Status

The downloader has been implemented in:

```text
code/01_download_data/03_download_siconfi.R
```

Smoke test:

- UF: `RR`
- period: `2024B1`
- annexes: `01`, `02`, and `06`
- output prefix: `siconfi_rreo_smoke_test`

The smoke test confirmed:

- API calls work for the three selected annexes.
- Revenue, expenditure, and investment mappings produce one panel row.
- Numeric parsing handles Siconfi JSON values with decimal points correctly.
- First-bimester investment flow equals cumulative liquidated investment.

The next step is to run the full downloader for all 27 UFs, all six bimesters, from 2015 through the latest available year.

## Full collection result

Full collection was executed in annual chunks and then combined with:

```text
code/01_download_data/03a_combine_siconfi_chunks.R
```

Final combined outputs:

- `data/processed/siconfi_rreo_state_fiscal_bimonthly_processed.csv`
- `data/processed/siconfi_rreo_state_fiscal_bimonthly_panel_ready.csv`
- `data/raw/siconfi/siconfi_rreo_state_fiscal_bimonthly_download_registry.csv`

The raw annex extracts are large local cache files and are intentionally ignored by Git. Annual processed chunk files are also treated as intermediates; the combined panel-ready file is the analysis input.

Validation script:

```text
code/01_build_panel/07_validate_siconfi_final.R
```

Validation outputs:

- `output/validation/siconfi_rreo_validation_summary.csv`
- `output/validation/siconfi_rreo_period_coverage.csv`
- `output/validation/siconfi_rreo_incomplete_periods.csv`
- `output/validation/siconfi_rreo_missing_value_summary.csv`
- `output/validation/siconfi_rreo_missing_investment_by_year.csv`
- `output/validation/siconfi_rreo_negative_investment_flows.csv`
- `output/validation/siconfi_rreo_registry_status.csv`
- `output/validation/siconfi_rreo_failed_registry.csv`

Current validation result:

- Final panel rows: 1,811.
- Coverage: 2015B1 through 2026B2.
- Complete coverage for 2015-2025: 27 UFs in every bimester.
- 2026B1 has 27 UFs; 2026B2 has only 2 UFs as of the collection date, so the current-year endpoint is incomplete and should be filtered or refreshed before final estimation.
- Duplicate `year x bimester x state_abbrev` keys: 0.
- Download registry: 5,832 successful requests and 0 failed requests.
- Total revenue is complete in the panel.
- Total liquidated expenditure is missing in 5 UF-bimesters.
- Investment is unavailable for all UF-bimesters in 2015-2017 under the current Anexo 06 mapping, and has a few later gaps. The validation found 493 missing investment rows. This should be treated as source coverage rather than imputed mechanically.
- One negative derived investment flow is flagged: Mato Grosso do Sul in 2020B6. It is retained and flagged because the flow is computed from a cumulative accounting series and can reflect revisions or reversals.

Practical use rule:

- Use the combined panel-ready file for analysis.
- For final models, prefer the balanced 2015B1-2025B6 window unless the current-year endpoint is refreshed after all 2026 bimesters become available.
