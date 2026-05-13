# Caged Data Strategy

This note records the current strategy for the formal-employment series.

## Core decision

- Formal employment is a central outcome in the project.
- The collection strategy may combine `Old Caged` and `Novo Caged`.
- The original source distinction must be preserved in the raw-data layer.

## Current operational strategy

### Old Caged

- Download official consolidated files from the MTE `CAGED` page.
- Keep the original workbooks in `data/raw/mte/`.
- Use these files as the primary source for the pre-2020 period.

### Novo Caged

- Track official MTE `Novo Caged` pages and the linked official tables folders.
- Preserve page-level provenance because the public links are routed through gov.br and Google Drive folders.
- Keep a download registry before building the cleaned series.

## Methodological break

- January 2020 marks the break between the legacy and new production regimes.
- The final analytical series should include a break indicator such as `post_2020_caged_dummy`.
- Results should distinguish between:
  - mixed legacy plus new series
  - purely post-2020 specifications

## Why the current script is hybrid

- Old Caged exposes direct official workbook links on gov.br.
- Novo Caged is currently disseminated through monthly gov.br pages that route users to tables folders.
- Because of this asymmetry, the project first automates:
  - direct download of legacy files
  - structured registry of official Novo Caged tables links

## Next step after this script

- Inspect the saved legacy workbooks.
- Decide whether the state-level monthly balance will be parsed from the old consolidated workbook or from adjusted municipal balance files.
- Expand automation for Novo Caged folder contents after validating the folder structure across reference months.
