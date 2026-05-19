# Download Scripts

This folder contains the scripts used to collect the raw series for the project.

## Current order

1. `01_download_ibge_sidra.R`
2. `02_download_caged.R`
3. `02a_inspect_novo_caged_archive.R`
4. `02b_parse_novo_caged_mov.R`
5. `02c_download_novo_caged_archives.R`
6. `02d_download_old_caged_adjusted_archives.R`
7. `02e_parse_old_caged_adjusted.R`
8. `02f_download_old_caged_complete_archives.R`
9. `02g_parse_old_caged_complete.R`
10. `02h_download_novo_caged_adjusted_archives.R`
11. `02i_parse_novo_caged_adjusted.R`
12. `02j_check_old_caged_complete_integrity.R`
13. `02k_parse_old_caged_official_aggregate_workbook.R`
14. `02l_salvage_old_caged_complete_corrupt_archives.R`
15. `02m_query_old_caged_basedosdados_state_balance.R`
16. `02n_build_old_caged_complete_with_bd_patch.R`
17. `03_download_siconfi.R`
18. `04_download_structural_covariates.R`

## Current status

- The IBGE/SIDRA script is already scaffolded for:
  - `PMC` table `8880`
  - `PMS` table `5906`
  - `IPCA` table `1737`
- The Caged script is scaffolded to:
  - download official legacy workbooks from gov.br
  - register official Novo Caged movement archives directly from the official MTE FTP
- The Novo Caged inspection script can:
  - download one sample movement archive
  - save a listing of its internal files for parser design
- The Novo Caged parsing script can:
  - extract downloaded movement archives
  - aggregate `formal_hiring_balance` by `UF` and `competencia`
- The Novo Caged bulk-download script can:
  - download all monthly movement archives listed in the registry
  - skip archives that already exist locally
- The old adjusted Caged bulk-download script can:
  - download the pre-2020 adjusted archives from the official MTE FTP
  - cover annual archives for `2007-2009` and monthly archives for `2010-2019`
- The old adjusted Caged parsing script can:
  - extract the raw txt files
  - aggregate `formal_hiring_balance` by `UF` and `competencia`
- The complete Old Caged integrity script can:
  - test local `CAGEDEST_MMYYYY.7z` archives with `7z.exe`
  - save a reproducible integrity inventory
- The Base dos Dados Old Caged script can:
  - query `basedosdados.br_me_caged.microdados_antigos`
  - aggregate `saldo_movimentacao` by `ano`, `mes`, and `sigla_uf`
  - default to the months whose official FTP archives still fail integrity checks
- The Old Caged final builder can:
  - parse only integrity-ok official `CAGEDEST_MMYYYY.7z` archives
  - patch remaining failed months with the Base dos Dados aggregate
  - validate monthly coverage for all 27 UFs from `2007-01` through `2019-12`
- The old adjusted Caged block has produced:
  - `data/raw/mte/old_caged_state_balance_monthly.csv`
  - `data/processed/old_caged_state_balance_monthly_processed.csv`
  - `data/processed/old_caged_state_balance_monthly_panel_ready.csv`
- The remaining scripts are listed in `data/raw/download_manifest.csv` and should be created next.
