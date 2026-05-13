# paper-governor-removal-impacts

Research repository for a paper on the impacts of governor removal in Brazil, with a focus on synthetic control designs and institutional ruptures before the legal end of term.

## Initial Scope

- Map post-1988 gubernatorial removals in Brazil.
- Define institutional rupture typologies.
- Review Brazilian and international literature.
- Build a state-level panel for outcome analysis.
- Estimate case-specific synthetic control models.

## Suggested Next Steps

1. Define case selection criteria.
2. Build a timeline of gubernatorial removals.
3. Choose outcome variables and donor pool rules.
4. Organize data, code, notes, and drafts.

## Data Foundation

The project already includes an initial data architecture:

- `data/raw/governor_removal_events.csv`: event-level register of gubernatorial removals.
- `data/processed/state_year_panel_template.csv`: annual panel template for state-level outcomes.
- `data/processed/data_dictionary.csv`: variable dictionary with candidate outcomes and predictors.
- `code/01_build_panel/01_validate_inputs.R`: basic script to validate file structure.

## Current Methodological Note

- The project now prioritizes monthly and bimonthly outcomes over annual GDP.
- Formal employment analysis may combine `Old Caged` and `Novo Caged` when needed for pre-treatment length, with an explicit control for the 2020 methodological break.
- A consolidated log of methodological choices is stored in `notes/methodological_decisions.md`.

## Software Choice

- The project uses `R` as the main language for collection, cleaning, analysis, and visualization.
- The current download workflow begins with `PMC`, `PMS`, and `IPCA` through `SIDRA`.
