# Source Research Protocol

This file standardizes how sources should be searched, saved, and used in this project.

## Priority order

1. Official institutional sources: TSE, TREs, STJ, STF, Senado, Assembleias Legislativas, governos estaduais.
2. Public broadcasters and major wires: Agencia Brasil, EBC.
3. Established local press when the event is very recent or institutionally undercovered.
4. Reference pages only for cross-checking chronology, never as sole support for coding.

## Search rules

- Always search using absolute dates when the case is recent.
- Save one row per source in `references/source_inventory.csv`.
- Prefer at least one primary source for each event.
- For recent cases, save one local implementation source when the official decision and the actual transfer of power happened on different dates.

## Coding rules

- `removal_date` should reflect the date the officeholder actually left power.
- `return_date` should be filled only when the same officeholder returned.
- Voluntary resignation should not automatically count as an institutional rupture.
- If a resignation occurred under imminent judicial or electoral threat, record the evidence and decide later whether the case belongs in the analytical sample.

## Outcome-data rule currently adopted

- Formal employment analysis may combine `Old Caged` and `Novo Caged` when the case requires a longer pre-treatment window.
- Whenever the combined employment series is used, record the methodological break explicitly and include a control such as `post_2020_caged_dummy`.
- If both a mixed-series specification and a pure `Novo Caged` specification are feasible, keep both and treat the latter as a robustness exercise.

## Open classification issue

The event file currently mixes:

- definitive removals, such as final cassation or impeachment with loss of office
- temporary removals, such as precautionary judicial suspension or impeachment suspension later reversed

This is not a data error. It means the file is an inventory of rupture events, not yet a final estimation sample. The final article can later filter this inventory into:

- `main sample`: more comparable definitive removals
- `extended sample`: temporary or borderline episodes
