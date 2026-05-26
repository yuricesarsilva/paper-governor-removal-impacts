# CAGED Final Validation

This note closes the current CAGED data-construction block.

## Final files to use

Use these files for analysis:

- `data/processed/caged_state_balance_monthly_processed.csv`
- `data/processed/caged_state_balance_monthly_panel_ready.csv`

The preferred analysis file is:

- `data/processed/caged_state_balance_monthly_panel_ready.csv`

This file keeps only the 27 identified UFs and is the correct CAGED input for event-specific panels.

## Files not to use directly

The following files are intermediate or diagnostic and should not be used as the final CAGED outcome:

- `data/processed/old_caged_state_balance_monthly_processed.csv`
- `data/processed/old_caged_state_balance_monthly_panel_ready.csv`
- `data/processed/novo_caged_state_balance_monthly_processed.csv`
- `data/processed/novo_caged_state_balance_monthly_panel_ready.csv`
- raw files based only on `CAGED_AJUSTES`
- raw files based only on `CAGEDMOV`

They remain useful for diagnostics and audit trails, but the combined final CAGED series supersedes them.

## Construction rule

Final series version:

- `old_complete_novo_mov_for_exc_v1`

Rule:

- `2007-01` to `2019-12`: Old CAGED complete monthly microdata;
- official FTP files are used when the `.7z` archives pass integrity checks;
- Base dos Dados is used as a patch only for months whose official FTP archives remain corrupted;
- `2020-01` onward: adjusted Novo CAGED using `CAGEDMOV + CAGEDFOR - CAGEDEXC`.

The final panel includes:

- `post_2020_caged_dummy`
- `caged_method_break_dummy`

These indicators should be retained in models that combine Old CAGED and Novo CAGED across the January 2020 break.

## Validation script

Validation script:

- `code/01_build_panel/06_validate_caged_final.R`

Validation outputs:

- `output/validation/caged_final_validation_summary.csv`
- `output/validation/caged_final_monthly_coverage.csv`
- `output/validation/caged_final_uf_pre_post_2020_summary.csv`
- `output/validation/caged_final_source_composition.csv`

## Validation results

The validation passed on 2026-05-26.

Main results from `caged_final_validation_summary.csv`:

- panel-ready rows: `6237`
- months: `231`
- first competence: `200701`
- last competence: `202603`
- minimum states per month: `27`
- maximum states per month: `27`
- Old CAGED rows in panel-ready file: `4212`
- Novo CAGED rows in panel-ready file: `2025`
- full processed rows: `6312`
- full processed non-panel rows: `75`
- duplicated `competencia x state_abbrev` keys: `0`
- missing competences: `0`
- extra competences: `0`
- break dummy errors: `0`

The full processed file has `75` additional non-panel rows because the raw Novo CAGED adjusted file includes the non-identified UF category, which is excluded from the panel-ready file.

## Methodological status

CAGED is now operationally closed for the next project step.

The series is suitable for exploratory analysis and event-specific model assembly, with the methodological caveat that combined Old/Novo CAGED specifications must explicitly account for the 2020 break.

The next planned data block is quarterly PNADc.
