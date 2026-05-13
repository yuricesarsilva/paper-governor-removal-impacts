# Novo Caged Processing Note

## UF code mapping

- The raw `Novo Caged` state-balance file uses the two-digit IBGE `UF` code.
- A lookup table was created to map the codes to:
  - `state_abbrev`
  - `state_name`
  - `macroregion`

## Treatment of UF code 99

- The raw file contains records with `uf = 99`.
- For this project, `uf = 99` is coded as `Nao identificado`.
- This interpretation is consistent with official public dissemination material of the Novo Caged, in which the geographic breakdown includes a category labeled `Não identificado`.
- Therefore:
  - the processed full file preserves `uf = 99`
  - the panel-ready file excludes it from the state panel

## Output files

- `data/processed/uf_code_lookup.csv`
- `data/processed/novo_caged_state_balance_monthly_processed.csv`
- `data/processed/novo_caged_state_balance_monthly_panel_ready.csv`

## Rationale

- Keeping `uf = 99` in the full processed layer preserves fidelity to the original administrative source.
- Excluding `uf = 99` from the panel-ready file avoids contaminating state-level SCM inputs with observations that are not attributable to a specific federative unit.
