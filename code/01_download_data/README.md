# Download Scripts

This folder contains the scripts used to collect the raw series for the project.

## Current order

1. `01_download_ibge_sidra.R`
2. `02_download_caged.R`
3. `03_download_siconfi.R`
4. `04_download_structural_covariates.R`

## Current status

- The IBGE/SIDRA script is already scaffolded for:
  - `PMC` table `8880`
  - `PMS` table `5906`
  - `IPCA` table `1737`
- The remaining scripts are listed in `data/raw/download_manifest.csv` and should be created next.
