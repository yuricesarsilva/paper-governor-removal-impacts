# AM 2017-01 V4: results report (all bimonthly + STL)

Generated on 2026-06-05.

V4 standardizes the whole pilot to a single frequency. Starting from V2 (accountability frame), the four monthly outcomes are aggregated to bimonthly and seasonally adjusted with STL, exactly like the fiscal block. All eight outcomes now share one frequency, one SA method (STL), one window, and one estimation family. The electoral cassation is read as a corrective accountability act; the single treatment date is the effective removal, and the cassation-process months count as ordinary pre-treatment. Calendar time on the x-axis; no moving averages.

## Event design

- Treated state: `AM` (Amazonas).
- Treatment (single cut): effective removal `2017-05-04` (TSE final cassation decision for vote-buying).
- The cassation process began `2016-01-25` (first TRE/TSE decision), but this is treated as pre-treatment, not a separate crisis window.

## Window design

- All outcomes bimonthly: `2013-06-01` to `2018-10-01`. Target pre-treatment = 24 bimesters (2013B3-2017B2); post-removal = 9 bimesters.
- **Pre-window availability differs by outcome** and is handled per-outcome by the SCM (complete-case pre-window):
  - Labor (CAGED) and consumption (PMC/PMS): data from 2007, so the full **24-bimester** pre-window is used.
  - Fiscal (Siconfi/RREO) starts only at 2015B1, so the fiscal pre-window is the **maximum available = 14 bimesters** (2015B1-2017B2), not 24. It cannot be extended without pre-2015 fiscal data.
- Extending labor/consumption to 24 bimesters removes the overfitting seen at 14 bimesters: their pre-fit RMSPE is now honest (e.g. formal hiring ~45, retail ~1.1) rather than near-zero. The fiscal block still has the tight 14-period pre-fit; read it with the placebo inference.

## Bimonthly aggregation and seasonal adjustment

- **Formal hiring and construction hiring** are flows (net balances), so the two monthly balances are SUMMED to the bimester.
- **Retail and services volume indices** are index levels, so the two monthly indices are AVERAGED (the bimonthly index relative to the same monthly base is the mean of the two; summing would double the level).
- A bimester is kept only when both constituent months are present and finite.
- All eight bimonthly outcomes are then seasonally adjusted with STL (`stats::stl`, periodic, robust): SA series = observed minus STL seasonal component. Applied to each state's full series before windowing.
- Quarterly PNADc covariates remain X-13 seasonally adjusted.
- Volume indices are reindexed to 100 at the first valid observation in the pilot window after SA.
- No moving averages are computed.
- Robustness alternatives noted for the article: bimester fixed effects and MA(6).

## Methodological strategy

The main donor pool excludes `AM`, `RJ`, `TO`. The preferred specification uses 24 eligible donors. Augmented Synthetic Control is the headline estimator; SCM weights are estimated on the pre-treatment window (everything before the removal date). Predictors are the full pre-treatment outcome path plus six structural covariates (all seasonally adjusted): unemployment rate, formalization rate, transfer dependency ratio, and health, education, and public security expenditure per capita.

## Preliminary plots

![preliminary_labor_market.png](report/figures/preliminary_labor_market.png)

![preliminary_consumption.png](report/figures/preliminary_consumption.png)

![preliminary_public_sector.png](report/figures/preliminary_public_sector.png)

## Covariate and pre-treatment outcome balance

### Pre-treatment outcome fit

| Outcome | Treated | Synthetic | RMSPE pre |
| --- | --- | --- | --- |
| Formal hiring | -102.91 | -106.16 | 44.65 |
| Construction | -26.00 | -26.69 | 19.07 |
| Retail | 94.08 | 94.23 | 1.14 |
| Services | 90.93 | 90.82 | 1.01 |
| Own tax revenue | 491.63 | 491.63 | 0.08 |
| ICMS | 430.97 | 430.90 | 0.55 |
| Public investment | 50.22 | 50.22 | 0.01 |
| Total expenditure | 970.87 | 970.88 | 0.11 |

### Covariate balance: formal labor market

| Covariate | Treated | Formal hiring | Construction |
| --- | --- | --- | --- |
| Unemployment rate (SA) |     0.104 |     0.091 |     0.094 |
| Formalization rate (SA) |     0.434 |     0.588 |     0.526 |
| Labor income (SA, R$) | 2,711.134 | 2,981.909 | 2,797.837 |
| Transfer dependency ratio (SA) |    -0.002 |    -0.001 |    -0.001 |
| Health expenditure pc (SA, R$) |   175.427 |   117.392 |   139.163 |
| Education expenditure pc (SA, R$) |   153.268 |   130.298 |   149.886 |
| Public security expenditure pc (SA, R$) |    96.182 |   110.114 |    77.675 |

### Covariate balance: household consumption

| Covariate | Treated | Retail | Services |
| --- | --- | --- | --- |
| Unemployment rate (SA) |     0.104 |     0.089 |     0.104 |
| Formalization rate (SA) |     0.434 |     0.526 |     0.463 |
| Labor income (SA, R$) | 2,711.134 | 2,768.459 | 2,364.875 |
| Transfer dependency ratio (SA) |    -0.002 |    -0.001 |    -0.002 |
| Health expenditure pc (SA, R$) |   175.427 |   128.460 |   136.083 |
| Education expenditure pc (SA, R$) |   153.268 |   128.806 |   187.958 |
| Public security expenditure pc (SA, R$) |    96.182 |    89.946 |   100.872 |

### Covariate balance: state public finances

| Covariate | Treated | Own tax revenue | ICMS | Public investment | Total expenditure |
| --- | --- | --- | --- | --- | --- |
| Unemployment rate (SA) |     0.104 |     0.099 |     0.097 |     0.098 |     0.098 |
| Formalization rate (SA) |     0.434 |     0.482 |     0.521 |     0.476 |     0.463 |
| Labor income (SA, R$) | 2,711.134 | 2,704.581 | 2,866.460 | 2,622.891 | 2,525.141 |
| Transfer dependency ratio (SA) |    -0.002 |    -0.002 |    -0.001 |    -0.002 |    -0.002 |
| Health expenditure pc (SA, R$) |   175.427 |   161.985 |   143.592 |   154.001 |   138.867 |
| Education expenditure pc (SA, R$) |   153.268 |   183.201 |   179.931 |   169.246 |   173.171 |
| Public security expenditure pc (SA, R$) |    96.182 |    87.344 |    90.546 |    90.453 |    94.832 |

## Main results: Augmented SCM (SA)

| Channel | Outcome | Mean gap post | RMSPE pre | RMSPE post | Donors |
| --- | --- | --- | --- | --- | --- |
| Formal labor market | Formal hiring balance per 100k WAP |  -2.33 | 44.65 | 36.10 | 24 |
| Formal labor market | Construction hiring per 100k WAP |  -3.43 | 19.07 | 11.83 | 24 |
| Household consumption | Retail volume index |   5.15 |  1.14 |  6.58 | 24 |
| Household consumption | Services volume index |   5.68 |  1.01 |  6.47 | 24 |
| State public finances | Own tax revenue, real per capita |  46.95 |  0.08 | 50.43 | 24 |
| State public finances | ICMS revenue, real per capita |  47.98 |  0.55 | 52.16 | 24 |
| State public finances | Public investment, real per capita |  -4.83 |  0.01 | 18.27 | 24 |
| State public finances | Total liquidated expenditure, real pc | -22.08 |  0.11 | 85.47 | 24 |

![augmented_effect_summary.png](report/figures/augmented_effect_summary.png)

### Formal labor market

![augmented_paths_labor_market.png](report/figures/augmented_paths_labor_market.png)

![augmented_gaps_labor_market.png](report/figures/augmented_gaps_labor_market.png)

### Household consumption

![augmented_paths_consumption.png](report/figures/augmented_paths_consumption.png)

![augmented_gaps_consumption.png](report/figures/augmented_gaps_consumption.png)

### State public finances

![augmented_paths_public_sector.png](report/figures/augmented_paths_public_sector.png)

![augmented_gaps_public_sector.png](report/figures/augmented_gaps_public_sector.png)

## Donor weights

![donor_weights_labor_market.png](report/figures/donor_weights_labor_market.png)

![donor_weights_consumption.png](report/figures/donor_weights_consumption.png)

![donor_weights_public_sector.png](report/figures/donor_weights_public_sector.png)

## In-space placebos

Each eligible donor is treated as pseudo-treated at the same dates; gaps are normalized by each unit's pre-treatment RMSPE.

| Outcome | RMSPE ratio (post/pre) | p-value (ratio) | p-value (abs gap) | Placebos |
| --- | --- | --- | --- | --- |
| Formal hiring |     0.81 | 0.958 | 1.000 | 24 |
| Construction |     0.62 | 1.000 | 1.000 | 24 |
| Retail |     5.75 | 0.167 | 0.250 | 24 |
| Services |     6.40 | 0.042 | 0.208 | 24 |
| Own tax revenue |   603.26 | 0.125 | 0.458 | 24 |
| ICMS |    94.27 | 0.000 | 0.333 | 24 |
| Public investment | 1,300.69 | 0.250 | 1.000 | 24 |
| Total expenditure |   760.80 | 0.042 | 0.958 | 24 |

![placebo_gaps_labor_market.png](report/figures/placebo_gaps_labor_market.png)

![placebo_rmspe_ratio_labor_market.png](report/figures/placebo_rmspe_ratio_labor_market.png)

![placebo_gaps_consumption.png](report/figures/placebo_gaps_consumption.png)

![placebo_rmspe_ratio_consumption.png](report/figures/placebo_rmspe_ratio_consumption.png)

![placebo_gaps_public_sector.png](report/figures/placebo_gaps_public_sector.png)

![placebo_rmspe_ratio_public_sector.png](report/figures/placebo_rmspe_ratio_public_sector.png)

## Leave-one-out donor placebo

| Outcome | Gap post | LOO rank | p-value (2-sided) | Note |
| --- | --- | --- | --- | --- |
| Formal hiring | -2.33 | 24 / 25 | 0.08 | Unusually large negative gap |
| Retail | 5.15 | 20 / 25 | 0.24 | Not extreme vs LOO distribution |
| Services | 5.68 | 2 / 25 | 0.08 | Unusually small positive gap |
| ICMS | 47.98 | 2 / 25 | 0.08 | Unusually small positive gap |
| Public investment | -4.83 | 20 / 25 | 0.24 | Not extreme vs LOO distribution |
| Total expenditure | -22.08 | 23 / 25 | 0.12 | Not extreme vs LOO distribution |

## Current limitations

- Pre-window is 24 bimesters for labor/consumption but only 14 for fiscal, because Siconfi/RREO starts at 2015B1. The fiscal pre-fit is therefore tight (low RMSPE_pre) and prone to overfitting; rely on the placebo inference, not the raw gap. This asymmetry cannot be removed without a pre-2015 fiscal source.
- All seasonal adjustment is STL (freq 6). X-13 cannot process bimonthly (freq 6). Bimester fixed effects and MA(6) are reasonable robustness alternatives.
- Seasonal adjustment falls back to the raw series for states/variables with too few cycles; check build log.
- ICMS from Annex 06 is derived by within-year differencing; RS 2018 B1-B5 imputed with 2017 seasonal shares.
- The post-removal window ends 9 bimesters after removal, by design.

## Generated files

- `report/tables/augmented_effects_by_outcome.csv`
- `report/tables/pretx_outcome_balance.csv`
- `report/tables/covariate_balance_*.csv`
- `report/tables/top_donor_weights_by_outcome.csv`
- `report/tables/am_2017_01_v4_loo_placebo_summary.csv`
- `report/tables/placebo_rank_actual_rr.csv`
- `report/figures/` (preliminary, paths, gaps, weights, placebo)
- `output/placebo_inspace/`, `output/placebo_loo/`
