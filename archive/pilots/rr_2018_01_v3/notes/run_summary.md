# RR 2018-01 V3 Run Summary

Run date: 2026-06-04

## Case Timing

- Instability start: `2018-11-07`
- Effective removal/intervention: `2018-12-10`
- Monthly coding:
  - clean pre-treatment: through `2018-10-01`
  - crisis: `2018-11-01` and `2018-12-01`
  - post-removal: from `2019-01-01`
  - main window end: `2019-12-01`
- Bimonthly coding:
  - clean pre-treatment: through `2018B5`
  - crisis: `2018B6`
  - post-removal: from `2019B1`
  - main window end: `2019B6`
- Quarterly coding:
  - clean pre-treatment: through `2018Q3`
  - crisis: `2018Q4`
  - post-removal: from `2019Q1`
  - main window end: `2019Q4`

The project default remains a two-year post-treatment window. This pilot truncates the main specification in `2019` because `2020` would overlap both the pandemic and the `Old CAGED`/`Novo CAGED` methodological break.

## Built Panels

The script `code/01_build_rr_2018_01_v3_panels.R` creates:

- `data/rr_2018_01_v3_monthly_panel.csv`
- `data/rr_2018_01_v3_bimonthly_fiscal_panel.csv`
- `data/rr_2018_01_v3_quarterly_pnadc_panel.csv`
- `data/rr_2018_01_v3_covariates.csv`
- `data/rr_2018_01_v3_event_metadata.csv`

Panel changes in the current specification:

- fiscal per-capita outcomes are wired to use resident population from the populated general `data/processed/state_year_panel_template.csv`;
- the formal labor-market block uses `formal_hiring_balance_per_100k_wap` and `formal_hiring_balance_construction_per_100k_wap`;
- the household-consumption block uses `retail_volume_index` and `services_volume_index`;
- the state-public-finance revenue block uses `state_tax_revenue_real_pc` and `icms_revenue_real_pc`;
- the state-public-finance expenditure block uses `public_investment_liquidated_real_pc` and `liquidated_expenditure_total_real_pc`.

## Donor-Pool Rule

Main donor-pool rule:

- exclude the treated state; and
- exclude any donor state with a coded rupture in `data/raw/governor_removal_events.csv` whose `removal_date` falls inside the pilot main estimation window.

Applied to `RR_2018_01`, this excludes:

- `RR`
- `AM` because of `AM_2017_01`
- `TO` because of `TO_2018_01`

This keeps the explicit pilot rule aligned with the event inventory instead of relying on a hardcoded state list only.

## SCM Outputs

The script `code/02_run_rr_2018_01_v3_scm.R` is configured to estimate Classic SCM and Augmented SCM together for:

- `formal_hiring_balance_per_100k_wap`
- `formal_hiring_balance_per_100k_wap_ma6_clean`
- `formal_hiring_balance_construction_per_100k_wap`
- `formal_hiring_balance_construction_per_100k_wap_ma6_clean`
- `retail_volume_index`
- `retail_volume_index_ma6_clean`
- `services_volume_index`
- `services_volume_index_ma6_clean`
- `state_tax_revenue_real_pc`
- `state_tax_revenue_real_pc_ma4_clean`
- `icms_revenue_real_pc`
- `icms_revenue_real_pc_ma4_clean`
- `public_investment_liquidated_real_pc`
- `public_investment_liquidated_real_pc_ma4_clean`
- `liquidated_expenditure_total_real_pc`
- `liquidated_expenditure_total_real_pc_ma4_clean`

## Implementation Notes

- Augmented SCM remains the preferred estimator.
- Classic SCM remains in the same output files as the visual and diagnostic comparator.
- Monthly moving averages follow the V3 rule: complete 6-month trailing windows in pre-treatment, then expanding windows from the first post-treatment month onward.
- Bimonthly moving averages follow the V3 rule: complete 4-bimester trailing windows in pre-treatment, then expanding windows from the first post-treatment bimester onward.
- Visual moving-average figures now mirror the same V3 smoothing rule used in estimation.
- The pilot now consumes the general project-wide construction-sector CAGED flow from `data/processed/caged_construction_state_balance_monthly_panel_ready.csv`.
- The resident-population annual panel is now materialized in the general project base and feeds the fiscal denominators directly through `data/processed/state_year_panel_template.csv`.
- The general Siconfi/RREO base now repairs `liquidated_expenditure_total_*` with the same rule already used for investment: reconstruct bimonthly flow from cumulative Annex 02 values when they are present in the raw file, then interpolate only the residual source gaps that remain empty after raw recovery.

