# Siconfi/RREO Public Investment Audit

This note documents the investigation and repair of `public_investment_liquidated_real`.

## Problem

The first Siconfi/RREO validation reported 493 missing public-investment rows, concentrated in 2015-2017. This affected the `RR_2018_01` pilot because Roraima only had public-investment values from 2018 onward in the processed panel, making the pre-treatment window too short for the investment outcome.

## Diagnosis

The raw Anexo 06 files did contain `RREO6Investimentos` rows in 2015-2017. The problem was the column parser.

The original mapping searched for:

```text
column_norm == "despesas liquidadas"
```

In 2015-2017, the current-year liquidated investment column is usually labeled like:

```text
DESPESAS LIQUIDADAS ATE O BIMESTRE / 2015
DESPESAS LIQUIDADAS ATE O BIMESTRE / 2016
DESPESAS LIQUIDADAS ATE O BIMESTRE / 2017
```

So the account was present, but the parser was too narrow.

## Repair

The downloader mapping was broadened to accept both:

- `DESPESAS LIQUIDADAS`
- `DESPESAS LIQUIDADAS ATE O BIMESTRE / current_year`

The repair was applied to existing raw files with:

```text
code/01_build_panel/08_repair_siconfi_investment_from_raw.R
```

The script:

- reads the combined raw Anexo 06 file;
- extracts current-year `RREO6Investimentos` cumulative liquidated investment;
- recomputes bimonthly flows by differencing within `UF x year`;
- recomputes real values using each row's existing Siconfi deflator factor;
- writes the repaired combined processed and panel-ready files;
- records `investment_recovered_from_raw` and `original_public_investment_missing` flags.

## Adjacent-Period Imputation

Remaining internal gaps are imputed using adjacent observed bimesters. For isolated gaps, this is the mean of the previous and following observed values. For consecutive gaps, the implementation uses linear interpolation between the last observed value before the gap and the first observed value after the gap, which is the multi-period generalization of the adjacent-period mean rule.

The imputation is implemented in:

```text
code/01_build_panel/08_repair_siconfi_investment_from_raw.R
```

Imputed rows are flagged with:

- `public_investment_imputed_adjacent_mean`
- `public_investment_imputation_method`

## Result

Missing investment rows:

- before repair: 493
- after raw repair, before imputation: 10
- after adjacent-period imputation: 1

Recovered rows:

- 2015: 161
- 2016: 161
- 2017: 161

Imputed rows:

- `RN/2015B6`
- `BA/2016B6`
- `SC/2017B1`
- `RS/2018B1-B5`
- `RR/2019B1`

Remaining gap:

- `RR/2026B1`

`RR/2026B1` remains missing because the current 2026 endpoint is incomplete and there is no following observed Roraima bimester in the panel. The adjacent-period rule cannot be applied without a posterior value.

Negative derived flows after repair:

- `CE/2015B1`
- `MT/2015B2`
- `CE/2015B5`
- `MS/2020B6`

These are retained with `public_investment_negative_flow_flag` because the bimonthly flow is derived from a cumulative accounting series. Negative values may reflect revisions, reversals, or reporting corrections.

## RR 2018 Pilot Implication

After repair, Roraima has public-investment values from `2015B1` through `2018B6`. The `RR_2018_01_v2` pilot now estimates both:

- `public_investment_liquidated_real_pc`
- `public_investment_liquidated_real_pc_ma4_clean`

No outcome is skipped in the current V2 pilot run.
