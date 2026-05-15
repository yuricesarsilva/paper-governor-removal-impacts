# Old Caged Processing Note

## Scope

- This note documents the treatment of the adjusted legacy `Caged` microdata files.
- The raw adjusted archives are stored in `data/raw/mte/`.
- The parsed state-month balance file is:
  - `data/raw/mte/old_caged_state_balance_monthly.csv`

## Important caveat

- The `.7z` files under `CAGED_AJUSTES` should not yet be treated as the full Old Caged monthly employment-balance series.
- A diagnostic comparison with the legacy consolidated workbook suggests that the parsed `.7z` files capture an adjustments/extemporaneous component, not the total employment balance.
- Example for Roraima:
  - consolidated workbook, `jan a set 2019`: `1604`
  - current parsed `CAGED_AJUSTES` microdata, 2019 available months: `428`
- Therefore, the processed files created from these `.7z` archives are useful for source inspection, but should not be used as the final pre-2020 employment outcome.
- The next Old Caged task is to parse the consolidated legacy workbook or identify/download the complete monthly legacy movement files.

## Aggregation rule

- The adjusted legacy files contain both declared competence and movement competence.
- The project aggregates by `Competencia Movimentacao`, not by declared competence.
- This is why the parsed series can start before the nominal archive year.

## Download and parsing notes

- The useful official FTP path is `ftp://ftp.mtps.gov.br/pdet/microdados/CAGED_AJUSTES/`.
- The observed structure is:
  - annual archives under `2002a2009/`
  - monthly archives under year folders from `2010/` to `2019/`
- The parser restricts inputs to the expected official archive names, so local retry or backup files are not double-counted.
- One legacy local copy of `CAGEDEST_AJUSTES_012019.7z` was unreadable and was preserved as `CAGEDEST_AJUSTES_012019_corrupt_legacy.7z`.
- The refreshed official January 2019 archive opens successfully even though its internal text filename is labeled `022019`; aggregation still uses the movement-competence field inside the file.

## Output files

- `data/processed/old_caged_state_balance_monthly_processed.csv`
- `data/processed/old_caged_state_balance_monthly_panel_ready.csv`

## Relationship to Novo Caged

- This is the pre-2020 legacy employment-flow source.
- Combined employment specifications should preserve the source distinction and include an explicit January 2020 methodological-break indicator.
- Do not combine the current `CAGED_AJUSTES` microdata output with Novo Caged as if both were total monthly balances.
