# Data Architecture

This project uses a modular data structure designed for case-specific synthetic control analysis of gubernatorial removals in Brazil.

## Folders

- `raw/`: manually collected or downloaded original files.
- `external/`: third-party datasets kept in their original format.
- `processed/`: cleaned panels and analysis-ready files.

## Core Files

- `raw/governor_removal_events.csv`: event-level file with all institutional ruptures.
- `processed/state_year_panel_template.csv`: annual state panel template.
- `processed/data_dictionary.csv`: variable dictionary for the state-year panel.
- `processed/caged_state_balance_monthly_panel_ready.csv`: final monthly CAGED panel for the 27 identified UFs.

## Unit of Analysis

The project now supports multiple state-time panels. Annual structural covariates remain in `state-year` format, while economic and labor-market outcomes may be monthly, bimonthly, quarterly, or annual depending on the source. Event-level information should be stored separately and merged into the relevant panel when needed.

The final CAGED monthly file is documented in:

- `notes/caged_final_validation.md`

## Data Workflow

1. Register all gubernatorial removals in `raw/governor_removal_events.csv`.
2. Build source-specific state-time outcome and predictor series at their original frequencies.
3. Run scripts in `code/01_build_panel/` to validate and assemble analysis-ready panels.
