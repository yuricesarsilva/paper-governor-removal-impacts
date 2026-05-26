# Methodological Decisions

This file records the main methodological decisions adopted for the project so far.

## Research object

- The project studies the impacts of gubernatorial removal in Brazil after 1988.
- The substantive focus is on institutional ruptures that removed the governor from power before the legal end of the term.
- The preferred substantive framing is economic and public-finance oriented.

## Core concept

- `Institutional rupture` means an event that removed the sitting governor from the exercise of power before the legal end of the mandate.
- The concept includes electoral cassation, impeachment, federal intervention, and judicial suspension.
- The treatment date is the date on which the governor effectively left power.

## Event inventory

- The master event file is `data/raw/governor_removal_events.csv`.
- The event file is an inventory of rupture episodes, not yet the final estimation sample.
- The Federal District is included in the broad inventory.
- Wilson Witzel is treated as a single interruption sequence beginning on `2020-08-28` and culminating in definitive loss of office.
- Cláudio Castro is tracked in the source inventory as a borderline case, but is not currently coded as a completed removal event in the master file.
- Edilson Damião is included because he was the sitting governor when the TSE decision was executed and Soldado Sampaio assumed the office.

## Sample design

- Each rupture event is analyzed individually rather than pooling all cases into a single treatment.
- The variable `sample_class` separates the event inventory into:
  - `main`
  - `extended`
  - `borderline`
- `main` is reserved for the most comparable events for synthetic control estimation.
- `extended` contains real rupture episodes that are substantively relevant but less clean analytically.
- `borderline` contains events that are real but unusually difficult to interpret in a comparable causal design.

## Empirical focus

- The preferred paper design is economic and public-finance oriented.
- Annual GDP is not the main outcome because it is too low-frequency for the expected timing of the effects.
- The project prioritizes monthly or bimonthly outcomes whenever feasible.

## Preferred outcomes

- Main economic outcomes:
  - retail activity from `PMC`
  - services activity from `PMS`
  - net formal employment flows from `Caged` and `Novo Caged`
- Main public-finance outcomes:
  - liquidated public investment
  - total liquidated expenditure
  - liquidated expenditure in health
  - liquidated expenditure in education
  - liquidated expenditure in public security

## Employment data rule

- Formal employment is considered a central outcome for the project.
- The project may use `Old Caged` before 2020 and `Novo Caged` from 2020 onward when longer pre-treatment windows are necessary.
- This implies an explicit methodological break in January 2020.
- When the combined series is used, the empirical design should include a methodological-break control such as a `post_2020_caged_dummy`.
- Employment results based on mixed `Old Caged` plus `Novo Caged` should be interpreted with caution and clearly distinguished from specifications that use only post-2020 data.
- For some recent cases, a pure `Novo Caged` specification may still be estimated as a robustness exercise.
- After reconstructing the final monthly CAGED series with Old CAGED plus adjusted Novo CAGED, the project will not adopt a normalization rule for formal employment at this stage.
- The higher variance observed in some states after incorporating the corrected series reinforces the decision to keep explicit break indicators in models that require the combined Old/Novo CAGED series.
- Models that use the combined employment series should retain the available break controls, especially `post_2020_caged_dummy` and `caged_method_break_dummy`, whenever the estimation window crosses January 2020 or otherwise depends on comparability between the two CAGED regimes.

## Frequency of analysis

- `PMC`, `PMS`, `Caged`, and `Novo Caged` will be treated as monthly series.
- `RREO/Siconfi` fiscal variables will be treated as bimonthly series when needed.
- Mixed-frequency designs are acceptable if handled case by case.

## Covariates for synthetic control

- The project will distinguish between `dynamic covariates` and `slow-moving structural covariates`.
- Dynamic covariates are preferred when the outcome is monthly or bimonthly.
- Slow-moving structural covariates may be included as pre-treatment comparability markers rather than as the core dynamic matching block.

### Dynamic covariates currently prioritized

- `formal_hiring_balance`
- `retail_volume_index`
- `services_volume_index`
- `unemployment_rate_pnadc`
- `formalization_rate_pnadc`
- `liquidated_expenditure_total_real`
- `public_investment_liquidated_real`
- `liquidated_expenditure_health_real`
- `liquidated_expenditure_education_real`
- `liquidated_expenditure_public_security_real`
- `state_tax_revenue_real`
- `total_revenue_real`
- `federal_transfers_real`
- `transfer_dependency_ratio`
- `own_revenue_ratio`

### Structural covariates currently retained

- `pnadc_population`
- `household_income_per_capita_pnadc`
- `gdp_per_capita_real`

### Annual structural covariates rule

- Annual variables may be used even when the main SCM design is monthly or bimonthly.
- They should not be treated as the primary dynamic predictors of the path of the outcome.
- The preferred income covariate candidate is now `household_income_per_capita_pnadc`, rather than GDP per capita, when PNADc coverage and frequency are adequate for the case.
- The preferred population concept for new covariate construction is `pnadc_population`, using the same PNADc source/concept as the selected PNADc income and labor-market variables.
- `gdp_per_capita_real` may be used with the latest available pre-treatment value when the treatment occurs after the last available annual release.
- When useful, structural annual covariates may also be averaged over the last few available pre-treatment years.

### PNADc covariates rule

- The project will add a PNADc block of candidate covariates to be built alongside the Siconfi/RREO block.
- The PNADc block should include household income per capita, PNADc population, unemployment rate, and formalization rate.
- These variables should preserve the source frequency at the collection stage and only be harmonized to the analytical design after coverage and case-specific timing are evaluated.
- The formalization rate will be constructed from PNADcIBGE/survey design objects, using occupied people as the denominator and the formal/informal classification documented in `notes/pnadc_processing_note.md`.

## Preferred time windows

- For monthly outcomes:
  - preferred pre-treatment window: `24 to 36 months`
  - preferred post-treatment window: `12 to 24 months`
- For bimonthly fiscal outcomes:
  - preferred pre-treatment window: `12 to 18 bimesters`
  - preferred post-treatment window: `6 to 12 bimesters`
- These windows may be adjusted case by case depending on data availability and institutional timing.

## Data architecture

- Event-level information remains separate from state-time outcome panels.
- The main analytical structure is a state-time panel linked to specific events.
- Sources must be saved in `references/source_inventory.csv`.
- Source coding conventions are documented in:
  - `references/source_research_dictionary.csv`
  - `references/source_research_protocol.md`

## Current implication for case selection

- Cases before 2020 remain relevant to the broader event inventory and to non-employment outcomes.
- Employment-based specifications can also be estimated for pre-2020 and early post-2020 cases by combining `Old Caged` and `Novo Caged`.
- This does not remove the need for caution around the 2020 methodological break.
- Fiscal and other outcome families with longer historical coverage remain important for broad comparability across cases.

## Pending decisions

- Whether the main article will center on all `main` cases or only on post-2020 cases with richer monthly data.
- Whether `RR_2018_01` should remain in `extended` or move to `borderline`.
- Whether some temporary-removal cases should be estimated only in robustness exercises.
