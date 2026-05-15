# Caged Source Investigation - 2026-05-15

This note records the source investigation prompted by the scale mismatch between the parsed `CAGED_AJUSTES` files and the Novo Caged series.

## Official access point

- MTE official microdata page:
  - `https://www.gov.br/trabalho-e-emprego/pt-br/assuntos/estatisticas-trabalho/microdados-rais-e-caged`
- Official FTP root:
  - `ftp://ftp.mtps.gov.br/pdet/microdados/`

The MTE page states that the FTP contains non-identified microdata for CAGED, RAIS, and Novo Caged in delimited text format.

## Old Caged complete microdata

The complete old Caged microdata are under:

- `ftp://ftp.mtps.gov.br/pdet/microdados/CAGED/`

Observed structure:

- year folders from `2007/` to `2019/`
- monthly files named:
  - `CAGEDEST_MMYYYY.7z`

Examples:

- `ftp://ftp.mtps.gov.br/pdet/microdados/CAGED/2007/CAGEDEST_012007.7z`
- `ftp://ftp.mtps.gov.br/pdet/microdados/CAGED/2019/CAGEDEST_122019.7z`

The layout file is available at:

- `ftp://ftp.mtps.gov.br/pdet/microdados/CAGED/CAGEDEST_layout_Atualizado.xls`

Inspection of `CAGEDEST_122019.7z` confirmed fields including:

- `Competencia Declarada`
- `UF`
- `Saldo Mov`

For RR in December 2019, this complete file gives a state balance of `-171`, while the parsed `CAGED_AJUSTES` file for the closest currently available month is a small adjustment component, not the complete series.

## Old Caged adjustment files

The previously parsed files are under:

- `ftp://ftp.mtps.gov.br/pdet/microdados/CAGED_AJUSTES/`

These files are named:

- `CAGEDEST_AJUSTES_YYYY.7z` for annual legacy files in `2002a2009/`
- `CAGEDEST_AJUSTES_MMYYYY.7z` for monthly files from `2010/` to `2019/`

Important correction:

- These files should not be treated as the full old Caged employment-balance series.
- They appear to capture adjustments or extemporaneous movement components.
- They should be combined with the complete old Caged files only after the official adjustment logic is understood.

## Novo Caged files

The Novo Caged microdata are under:

- `ftp://ftp.mtps.gov.br/pdet/microdados/NOVO%20CAGED/`

Observed structure:

- year folders from `2020/` onward
- month folders such as `2026/202603/`

Recent month folders contain:

- `CAGEDMOVAAAAMM.7z`
- `CAGEDFORAAAAMM.7z`
- `CAGEDEXCAAAAMM.7z`

The official `Leia-me.txt` in the Novo Caged FTP states:

- `CAGEDMOV` contains movements declared within the deadline.
- `CAGEDFOR` contains movements declared outside the deadline.
- `CAGEDEXC` contains excluded movements.

Implication:

- The current project series based only on `CAGEDMOV` is not the final adjusted Novo Caged series.
- A final Novo Caged state-month balance should incorporate `CAGEDMOV`, `CAGEDFOR`, and `CAGEDEXC`, applying the inverse sign logic for exclusions described in the official readme.

## Pipeline implication

Before using formal employment as an outcome:

1. Build a complete Old Caged parser from `CAGED/CAGEDEST_MMYYYY.7z`.
2. Decide how to incorporate `CAGED_AJUSTES` with the complete Old Caged files.
3. Rebuild Novo Caged to include `CAGEDMOV`, `CAGEDFOR`, and `CAGEDEXC`.
4. Only then compare the pre-2020 and post-2020 series and assess the remaining methodological break.
