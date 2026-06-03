# RR 2018-01 V2 Run Summary

Run date: 2026-06-03

## Case Timing

- Instability start: `2018-11-07`
- Effective removal/intervention: `2018-12-10`
- Monthly coding:
  - clean pre-treatment: through `2018-10-01`
  - crisis: `2018-11-01` and `2018-12-01`
  - post-removal: from `2019-01-01`
- Bimonthly coding:
  - clean pre-treatment: through `2018B5`
  - crisis: `2018B6`
  - post-removal: from `2019B1`
- Quarterly coding:
  - clean pre-treatment: through `2018Q3`
  - crisis: `2018Q4`
  - post-removal: from `2019Q1`

## Built Panels

The script `code/01_build_rr_2018_01_v2_panels.R` created:

- `data/rr_2018_01_v2_monthly_panel.csv`
- `data/rr_2018_01_v2_bimonthly_fiscal_panel.csv`
- `data/rr_2018_01_v2_quarterly_pnadc_panel.csv`
- `data/rr_2018_01_v2_covariates.csv`
- `data/rr_2018_01_v2_event_metadata.csv`

Rows created:

- monthly panel: 1,674
- bimonthly fiscal panel: 972
- quarterly PNADc panel: 648
- covariate panel: 27

Donor-pool coding:

- main donor-pool UFs: 24
- excluded UFs: `RR`, `AM`, and `TO`
- `RR` is excluded because it is the treated unit.
- `AM` is excluded because of nearby treated event `AM_2017_01`.
- `TO` is excluded because of nearby/repeated treated events, especially `TO_2018_01`.

## SCM Outputs

The script `code/02_run_rr_2018_01_v2_scm.R` estimated Classic SCM and Augmented SCM together.

All estimated outcomes use 24 eligible donor states after excluding `RR`, `AM`, and `TO`.

Estimated successfully:

- `formal_hiring_balance_per_100k_wap`
- `formal_hiring_balance_per_100k_wap_ma6_clean`
- `retail_volume_index`
- `retail_volume_index_ma6_clean`
- `services_volume_index`
- `services_volume_index_ma6_clean`
- `state_tax_revenue_real_pc`
- `state_tax_revenue_real_pc_ma4_clean`
- `public_investment_liquidated_real_pc`
- `public_investment_liquidated_real_pc_ma4_clean`
- `liquidated_expenditure_total_real_pc`
- `liquidated_expenditure_total_real_pc_ma4_clean`

Skipped: none.

Investment status: after the Siconfi/RREO investment repair, RR has usable public-investment values from `2015B1` through `2018B6`. The raw outcome has 15 complete clean pre-treatment bimesters after donor/covariate filtering, and the clean MA4 outcome has 18 complete pre-treatment bimesters.

Main summary file:

- `output/rr_2018_01_v2_scm_summary.csv`

## Implementation Notes

- `state_tax_revenue_real_pc` replaces `labor_income_real_pnadc` in the main outcome block to avoid mixing a quarterly income outcome into the preferred high-frequency pilot. The current Siconfi/RREO panel does not isolate ICMS, so this is an operational proxy for ICMS-linked taxable activity until an ICMS-specific series is built.
- Augmented SCM is the preferred estimator.
- Classic SCM is saved in the same output files as the visual/diagnostic comparator.
- Monthly moving averages use clean 6-month windows separately inside pre/crisis/post segments.
- Bimonthly moving averages use clean 4-bimester windows separately inside pre/crisis/post segments.
- Visual moving-average figures use partial windows at the beginning of each pre/crisis/post segment to avoid hiding the immediate transition period. These visual series are saved as `*_ma6_visual` and `*_ma4_visual`; headline SCM estimates still use the complete-window `*_ma6_clean` and `*_ma4_clean` series.
- The crisis window is shaded in the generated plots; the dotted vertical line marks instability start and the dashed vertical line marks effective removal.
