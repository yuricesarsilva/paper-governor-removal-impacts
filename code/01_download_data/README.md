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
8. `03_download_siconfi.R`
9. `04_download_structural_covariates.R`

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
- The remaining scripts are listed in `data/raw/download_manifest.csv` and should be created next.
