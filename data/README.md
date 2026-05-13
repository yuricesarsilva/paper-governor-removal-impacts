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

## Unit of Analysis

The main analytical dataset should be a `state-year` panel. Event-level information should be stored separately and merged into the panel when needed.

## Data Workflow

1. Register all gubernatorial removals in `raw/governor_removal_events.csv`.
2. Build annual outcome and predictor series in `processed/state_year_panel_template.csv`.
3. Run scripts in `code/01_build_panel/` to validate and assemble the analysis-ready panel.
