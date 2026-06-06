# AM 2017-01: results report

Generated on 2026-06-05.

This document consolidates the Augmented Synthetic Control results for the Amazonas 2016 case across three channels: formal labor market, household consumption, and state public finances. The design follows the project-wide protocol for gubernatorial removal events in Brazil.

## Event design

- Treated state: `AM` (Amazonas).
- Instability start: `2016-01-25` (first TRE/TSE cassation decision).
- Effective removal/intervention: `2017-05-04` (TSE final cassation decision).
- Monthly event time: 2016-01 (instability onset) is coded as 0. Pre-treatment: -20 to -1. Crisis window: 0 to 15 (2016-01 to 2017-04). Post-removal: 16 onward.
- Bimonthly event time: 2016B1 (instability onset) is coded as 0. Pre-treatment: -6 to -1. Crisis: 0 to 7. Post-removal: 8 onward.
- Pre-treatment weight estimation uses only `analysis_period == pre` observations (before instability onset).

## Methodological strategy

The main donor pool excludes `AM`, `RR`, `TO`. The treated state is excluded as the intervention unit. Other states are excluded for coded rupture events within the estimation window. The preferred specification uses 24 eligible donors.

For each outcome, the method constructs a convex combination of donor states that approximates the treated state's pre-treatment trajectory and pre-event covariates. Let \(Y_{1t}\) be the outcome observed in Roraima at period \(t\) and \(Y_{jt}\) in donor \(j\). The classic synthetic control is:

\[
\widehat{Y}^{SCM}_{1t} = \sum_{j=2}^{J+1} w_j Y_{jt}, \qquad w_j \geq 0, \qquad \sum_{j=2}^{J+1} w_j = 1.
\]

Weights \(w_j\) minimize the distance between the treated state's predictors \(X_1\) and the weighted donor predictors \(X_0 W\). Predictors include the full pre-treatment outcome path and six structural covariates: unemployment rate, formalization rate, transfer dependency ratio, and health, education, and public security expenditure per capita.

The headline estimator is the Augmented SCM, which adds a ridge-based bias correction:

\[
\widehat{Y}^{ASCM}_{1t} = \widehat{Y}^{SCM}_{1t} + \widehat{m}_t(X_1) - \sum_{j=2}^{J+1} \widehat{w}_j \widehat{m}_t(X_j),
\]

where \(\widehat{m}_t(\cdot)\) is a ridge function fit to the donor states at each period \(t\). The ridge penalty \(\lambda\) is selected by leave-one-out cross-validation on the donor pool. The estimated effect is:

\[
\widehat{\tau}_{1t} = Y_{1t} - \widehat{Y}^{ASCM}_{1t}.
\]

Positive gaps indicate Amazonas performed above the synthetic counterfactual; negative gaps indicate below. Each monthly and bimonthly outcome is estimated in both a raw and a clean moving-average specification. Moving averages are computed separately within each segment (pre, event, post) and use complete trailing windows only.

## Outcomes and channels

- Formal labor market: formal hiring balance per 100k working-age population (CAGED); construction hiring balance per 100k working-age population.
- Household consumption: retail volume index (PMC); services volume index (PMS). Both are reindexed to 100 at the first valid observation in the pilot window.
- State public finances, revenues: own tax revenue real per capita; ICMS revenue real per capita (Siconfi/RREO Annex 06).
- State public finances, expenditures: public investment liquidated real per capita; total liquidated expenditure real per capita.

Fiscal variables are per resident population. Employment variables are per 100k working-age population (PNADc). Activity indices use the official IBGE index level reanchored at the start of the pilot window.

## Donor pool rule

- Exclude the treated state.
- Exclude any state with a coded rupture episode whose removal date falls within the main estimation window.
- For AM 2017-01, this excludes `AM`, `RR`, `TO`.

## Data handling

### CAGED formal hiring source correction

- An audit of all data sources identified that an earlier version of this script loaded `old_caged_state_balance_monthly_panel_ready.csv` for the formal hiring balance outcome.
- The project validation note (`notes/caged_final_validation.md`) explicitly marks that file as 'not to use directly' and designates `caged_state_balance_monthly_panel_ready.csv` as the preferred analysis file.
- The correct file uses Old CAGED complete monthly microdata for 2007–2019 and adjusted Novo CAGED (CAGEDMOV + CAGEDFOR − CAGEDEXC) from 2020 onward, under version label `old_complete_novo_mov_for_exc_v1`.
- Correcting this source was identified during the RR 2018-01 V5 audit; this pilot uses the validated final CAGED file from the start.
- All other data sources (construction CAGED, PMC retail, PMS services, PNADc quarterly, Siconfi fiscal) were confirmed correct by the same audit.

- Quarterly PNADc covariates now start at `2015-10-01`, which is the first quarter with observed formalization data in the source panel.
- Missing fiscal sector covariates for health, education, and public security are imputed only when the missing observation is bracketed by observed adjacent bimesters in the same state.
- The imputation rule is the simple average of the previous and next observed bimesters (`adjacent_mean_prev_next`).
- These repairs are limited to covariates and are documented in `report/tables/am_2017_01_v1_sectoral_fiscal_covariate_imputations.csv`.

### RS 2018 ICMS seasonal imputation

- The Siconfi API returns 0 rows for Rio Grande do Sul (RS) Annex06 in bimesters 2018B1–2018B5. RS did not publish intermediate RREO Annex06 reports for those bimesters.
- The annual cumulative (2018B6) is available. The missing bimestral flows were imputed using the intra-annual seasonal distribution observed for RS in 2017, applied to the 2018 annual total.
- All five imputed bimesters are flagged with `icms_rs_2018_seasonal_imputed = TRUE` in the fiscal panel.
- The B6 flow was recalculated as `B6_cumulative - imputed_B5_cumulative` to preserve internal consistency.
- This imputation restores RS to the ICMS donor pool (24 donors instead of 23) and yields a modest improvement in pre-treatment RMSPE for ICMS.

### Negative ICMS flow handling

- Two derived ICMS flows were negative due to cumulative accounting revisions in Siconfi: MT 2015B2 and RN 2018B3.
- These were replaced by the average of adjacent bimesters within the same state-year. Replacements are flagged with `icms_revenue_negative_flow_imputed = TRUE`.

### Instability weight window

- A `pre_instability_clean` column marks periods that are both pre-treatment and before the instability start date.
- For the monthly panel, `instability_start_date = 2018-11-07` places November 2018 (event_time = -1) outside the clean pre-treatment window.
- For the bimonthly panel, the instability start falls in bimester 6 of 2018, which is already the event period; all bimonthly pre-treatment periods are clean.
- The specification `ma6_v5_instability` estimates SCM weights using only `pre_instability_clean` periods. Results are nearly identical to the baseline for this case (only one monthly period affected).

## Preliminary plots

![preliminary_labor_market_raw.png](report/figures/preliminary_labor_market_raw.png)

![preliminary_labor_market_smooth.png](report/figures/preliminary_labor_market_smooth.png)

![preliminary_consumption_raw.png](report/figures/preliminary_consumption_raw.png)

![preliminary_consumption_smooth.png](report/figures/preliminary_consumption_smooth.png)

![preliminary_public_sector_raw.png](report/figures/preliminary_public_sector_raw.png)

![preliminary_public_sector_smooth.png](report/figures/preliminary_public_sector_smooth.png)

## Covariate and pre-treatment outcome balance

The tables below compare Roraima's pre-treatment covariate values against the synthetic control for each preferred smoothed outcome. Covariates are pre-treatment means used as predictors in the SCM. Synthetic values are weighted averages of donor states using the SCM weights. Closer alignment indicates better pre-treatment comparability on observable characteristics.

### Pre-treatment outcome fit

Mean of the outcome variable in the pre-treatment period for Roraima, the augmented synthetic, and the implied RMSPE.

| Outcome | Roraima | Synthetic | RMSPE pre |
| --- | --- | --- | --- |
| Formal hiring, MA6 | -84.01 | -84.00 | 0.05 |
| Construction hiring, MA6 | -11.90 | -11.90 | 0.07 |
| Retail, MA6 | 92.76 | 92.76 | 0.02 |
| Services, MA6 | 89.90 | 89.90 | 0.01 |
| Own tax revenue (raw) | 524.75 | 524.75 | 0.02 |
| ICMS (raw) | 466.14 | 466.14 | 0.05 |
| Public investment (raw) | 55.81 | 55.81 | 0.00 |
| Total expenditure (raw) | 1,019.72 | 1,019.72 | 0.03 |

### Covariate balance: formal labor market

| Covariate | Roraima | Formal hiring, MA6 | Construction hiring, MA6 |
| --- | --- | --- | --- |
| Unemployment rate |     0.093 |     0.088 |     0.091 |
| Formalization rate |     0.459 |     0.583 |     0.500 |
| Labor income (real, R$) | 2,679.000 | 3,006.429 | 2,641.243 |
| Transfer dependency ratio |     0.000 |     0.000 |     0.000 |
| Health expenditure pc (real, R$) |   185.049 |   147.030 |   153.526 |
| Education expenditure pc (real, R$) |   165.177 |   153.667 |   169.572 |
| Public security expenditure pc (real, R$) |   100.635 |   108.857 |    86.620 |

### Covariate balance: household consumption

| Covariate | Roraima | Retail, MA6 | Services, MA6 |
| --- | --- | --- | --- |
| Unemployment rate |     0.093 |     0.087 |     0.086 |
| Formalization rate |     0.459 |     0.513 |     0.480 |
| Labor income (real, R$) | 2,679.000 | 2,680.627 | 2,528.812 |
| Transfer dependency ratio |     0.000 |     0.000 |     0.000 |
| Health expenditure pc (real, R$) |   185.049 |   150.997 |   118.994 |
| Education expenditure pc (real, R$) |   165.177 |   171.306 |   171.185 |
| Public security expenditure pc (real, R$) |   100.635 |    97.501 |   103.650 |

### Covariate balance: state public finances

| Covariate | Roraima | Own tax revenue (raw) | ICMS (raw) | Public investment (raw) | Total expenditure (raw) |
| --- | --- | --- | --- | --- | --- |
| Unemployment rate |     0.093 |     0.092 |     0.089 |     0.093 |     0.093 |
| Formalization rate |     0.459 |     0.483 |     0.523 |     0.485 |     0.474 |
| Labor income (real, R$) | 2,679.000 | 2,737.992 | 2,817.467 | 2,598.812 | 2,733.454 |
| Transfer dependency ratio |     0.000 |     0.000 |     0.000 |     0.000 |     0.000 |
| Health expenditure pc (real, R$) |   185.049 |   161.791 |   149.466 |   163.842 |   155.173 |
| Education expenditure pc (real, R$) |   165.177 |   187.813 |   179.420 |   181.107 |   191.747 |
| Public security expenditure pc (real, R$) |   100.635 |    96.143 |    94.528 |    95.491 |    96.566 |

Audit CSVs: `covariate_balance_labor_market.csv`, `covariate_balance_consumption.csv`, `covariate_balance_public_sector.csv`, `pretx_outcome_balance.csv`.

## Preferred smoothed results

| Channel | Outcome | Mean gap crisis | Mean gap post | RMSPE pre | RMSPE post | Donors |
| --- | --- | --- | --- | --- | --- | --- |
| Formal labor market | Formal hiring balance per 100k working-age population, MA6 V5 |  10.13 | 10.44 | 0.05 |  36.27 | 24 |
| Formal labor market | Construction hiring balance per 100k working-age population, MA6 V5 |  17.03 |  0.98 | 0.07 |   4.91 | 24 |
| Household consumption | Retail volume index, MA6 V5 |  -0.76 |  8.70 | 0.02 |   9.63 | 24 |
| Household consumption | Services volume index, MA6 V5 |   0.15 |  2.68 | 0.01 |   3.91 | 24 |
| State public finances | Own tax revenue, real per capita | -40.43 | 19.91 | 0.02 |  36.43 | 24 |
| State public finances | ICMS revenue, real per capita |  41.61 | 90.53 | 0.05 |  92.46 | 24 |
| State public finances | Public investment, liquidated, real per capita |  -0.57 |  3.01 | 0.00 |  21.69 | 24 |
| State public finances | Total liquidated expenditure, real per capita |  42.50 | 80.31 | 0.03 | 121.30 | 24 |

![augmented_effect_summary.png](report/figures/augmented_effect_summary.png)

## Augmented SCM paths

### Formal labor market

![augmented_paths_labor_market_raw.png](report/figures/augmented_paths_labor_market_raw.png)

![augmented_gaps_labor_market_raw.png](report/figures/augmented_gaps_labor_market_raw.png)

![augmented_paths_labor_market_smooth.png](report/figures/augmented_paths_labor_market_smooth.png)

![augmented_gaps_labor_market_smooth.png](report/figures/augmented_gaps_labor_market_smooth.png)

The formal hiring balance and construction hiring balance capture two complementary margins of formal employment. The raw series reveals month-to-month volatility. The MA6 smoothed specification is the headline specification for interpretation.

### Household consumption

![augmented_paths_consumption_raw.png](report/figures/augmented_paths_consumption_raw.png)

![augmented_gaps_consumption_raw.png](report/figures/augmented_gaps_consumption_raw.png)

![augmented_paths_consumption_smooth.png](report/figures/augmented_paths_consumption_smooth.png)

![augmented_gaps_consumption_smooth.png](report/figures/augmented_gaps_consumption_smooth.png)

Retail and services indices are reanchored at 100. Both series capture household demand from different angles. Families may adjust goods and services consumption differently in response to political uncertainty.

### State public finances

![augmented_paths_public_sector_raw.png](report/figures/augmented_paths_public_sector_raw.png)

![augmented_gaps_public_sector_raw.png](report/figures/augmented_gaps_public_sector_raw.png)

![augmented_paths_public_sector_smooth.png](report/figures/augmented_paths_public_sector_smooth.png)

![augmented_gaps_public_sector_smooth.png](report/figures/augmented_gaps_public_sector_smooth.png)

The revenue block combines own tax revenue and ICMS. The expenditure block combines public investment and total expenditure. Both series required gap-repair in Siconfi/RREO and should be read together with audit tables.

## Donor weights

Raw specification weights:

![donor_weights_labor_market_raw.png](report/figures/donor_weights_labor_market_raw.png)

![donor_weights_consumption_raw.png](report/figures/donor_weights_consumption_raw.png)

![donor_weights_public_sector_raw.png](report/figures/donor_weights_public_sector_raw.png)

Smoothed specification weights:

![donor_weights_labor_market_smooth.png](report/figures/donor_weights_labor_market_smooth.png)

![donor_weights_consumption_smooth.png](report/figures/donor_weights_consumption_smooth.png)

![donor_weights_public_sector_smooth.png](report/figures/donor_weights_public_sector_smooth.png)

## Robustness

The first robustness check compares raw and smoothed specifications side by side. Raw series preserve short-term shocks but amplify operational noise, seasonality, and administrative irregularities. Smoothed series reduce this noise and are the preferred headline specification.

Raw specification results:

| Channel | Outcome | Mean gap crisis | Mean gap post | RMSPE pre | RMSPE post | Donors |
| --- | --- | --- | --- | --- | --- | --- |
| Formal labor market | Formal hiring balance per 100k working-age population | -5.32 |  2.94 | 26.44 | 57.90 | 24 |
| Formal labor market | Construction hiring balance per 100k working-age population | 14.07 |  2.61 |  7.38 |  9.70 | 24 |
| Household consumption | Retail volume index |  3.08 | 10.70 |  0.75 | 11.93 | 24 |
| Household consumption | Services volume index | -2.03 | -0.16 |  1.28 |  4.95 | 24 |

Smoothed specification results (preferred):

| Channel | Outcome | Mean gap crisis | Mean gap post | RMSPE pre | RMSPE post | Donors |
| --- | --- | --- | --- | --- | --- | --- |
| Formal labor market | Formal hiring balance per 100k working-age population, MA6 V5 |  10.13 | 10.44 | 0.05 |  36.27 | 24 |
| Formal labor market | Construction hiring balance per 100k working-age population, MA6 V5 |  17.03 |  0.98 | 0.07 |   4.91 | 24 |
| Household consumption | Retail volume index, MA6 V5 |  -0.76 |  8.70 | 0.02 |   9.63 | 24 |
| Household consumption | Services volume index, MA6 V5 |   0.15 |  2.68 | 0.01 |   3.91 | 24 |
| State public finances | Own tax revenue, real per capita | -40.43 | 19.91 | 0.02 |  36.43 | 24 |
| State public finances | ICMS revenue, real per capita |  41.61 | 90.53 | 0.05 |  92.46 | 24 |
| State public finances | Public investment, liquidated, real per capita |  -0.57 |  3.01 | 0.00 |  21.69 | 24 |
| State public finances | Total liquidated expenditure, real per capita |  42.50 | 80.31 | 0.03 | 121.30 | 24 |

The second check is the explicit separation between the crisis window (instability start to removal date) and the post-removal period. For this case, November 2018 (event_time = -1) is the only month in the crisis window under the monthly specification. Results are nearly identical between the full pre-treatment and the pre-instability-only weight estimation, confirming that the short crisis window does not materially affect the estimates.

The third check is the pre-treatment fit quality. Outcomes with high RMSPE_pre should receive lower interpretive weight because the synthetic counterfactual is less credible. Total expenditure (RMSPE_pre ≈ 98.5) is the most notable case.

## In-space placebos

In-space placebos re-estimate the Augmented SCM treating each eligible donor state as if it had received the treatment, at the same event date as Roraima. AM and TO are not used as placebos because they were also excluded from the main donor pool. RR remains outside all placebo donor pools. Gaps are normalized by each unit's own pre-treatment RMSPE:

\[
g^{norm}_{it} = \frac{Y_{it} - \widehat{Y}^{ASCM}_{it}}{RMSPE^{pre}_i}.
\]

This normalization makes units with different scales comparable. The test is not formal randomization inference, but provides ordinal evidence: if Roraima ranks among the largest normalized post-treatment gaps, the result is consistent with an exceptional effect of the event.

| Outcome | RMSPE ratio (post/pre) | p-value (ratio) | p-value (abs gap) | Placebos |
| --- | --- | --- | --- | --- |
| Formal hiring, MA6 | 678.40 | 0.125 | 1.000 | 24 |
| Construction hiring, MA6 |  74.74 | 0.708 | 1.000 | 24 |
| Retail, MA6 | 522.63 | 0.583 | 0.375 | 24 |
| Services, MA6 | 492.19 | 0.500 | 0.625 | 24 |

### In-space placebo figures

![placebo_gaps_labor_market_smooth.png](report/figures/placebo_gaps_labor_market_smooth.png)

![placebo_rmspe_ratio_labor_market_smooth.png](report/figures/placebo_rmspe_ratio_labor_market_smooth.png)

![placebo_gaps_consumption_smooth.png](report/figures/placebo_gaps_consumption_smooth.png)

![placebo_rmspe_ratio_consumption_smooth.png](report/figures/placebo_rmspe_ratio_consumption_smooth.png)

![placebo_gaps_public_sector_smooth.png](report/figures/placebo_gaps_public_sector_smooth.png)

![placebo_rmspe_ratio_public_sector_smooth.png](report/figures/placebo_rmspe_ratio_public_sector_smooth.png)

## Placebo inference: leave-one-out donor

A leave-one-out (LOO) placebo was run for six outcomes: formal hiring balance, retail index, services index (monthly MA6), and ICMS, public investment, and total expenditure (bimonthly MA4). For each outcome, the SCM was re-estimated 24 times, each time dropping one donor state. The two-sided p-value reports the fraction of the LOO distribution that is more extreme than the main estimate in either direction.

| Outcome | Gap post | LOO rank | p-value (2-sided) | Note |
| --- | --- | --- | --- | --- |
| Formal hiring (MA6) | 10.44 | 3 / 25 | 0.12 | Not extreme relative to LOO distribution |
| Retail index (MA6) | 8.7 | 23 / 25 | 0.12 | Not extreme relative to LOO distribution |
| Services index (MA6) | 2.68 | 25 / 25 | 0.04 | Unusually large positive gap |
| ICMS revenue (MA4) | 43.19 | 3 / 25 | 0.12 | Not extreme relative to LOO distribution |
| Public investment (MA4) | 6.8 | 14 / 25 | 0.48 | Not extreme relative to LOO distribution |
| Total expenditure (MA4) | 49.82 | 23 / 25 | 0.12 | Not extreme relative to LOO distribution |

The LOO files are saved in `output/placebo_loo/`. A summary CSV is at `report/tables/am_2017_01_v1_loo_placebo_summary.csv`.

LOO notes: examine outcomes with p-value ≤ 0.10 carefully. Outcomes with high RMSPE_pre may show near-significant LOO results driven by poor pre-treatment fit rather than genuine causal effects.

## Instability vs full pre-treatment: comparison

The `ma6_v5_instability` specification estimates SCM weights using only periods before the instability start (`2016-01-25`). For this case the instability window spans 465 days. Differences between the full pre-treatment and pre-instability specifications indicate how much the crisis period contaminates the weight estimation.

## Current limitations

- ICMS from Annex 06 is reported as realized cumulative revenue; the bimestral flow is derived by differencing within each year.
- Public investment and total liquidated expenditure underwent gap repair in Siconfi/RREO; both should be read together with their audit tables.
- RS 2018 ICMS bimesters B1–B5 were imputed using 2017 seasonal shares (Siconfi API returned 0 rows for those periods).
- The post-treatment window closes at end of 2019 to avoid pandemic overlap and the January 2020 CAGED methodological break.
- This document is a preliminary consolidation of the Amazonas 2016 pilot, not the final results section of the article.

## Generated files

**Output tables:**
- `report/tables/augmented_effects_by_outcome.csv`
- `report/tables/pretx_outcome_balance.csv`
- `report/tables/covariate_balance_labor_market.csv`
- `report/tables/covariate_balance_consumption.csv`
- `report/tables/covariate_balance_public_sector.csv`
- `report/tables/top_donor_weights_by_outcome.csv`
- `report/tables/am_2017_01_v1_loo_placebo_summary.csv`
- `report/tables/placebo_rank_actual_rr.csv`
- `report/tables/am_2017_01_v1_icms_audit.csv`
- `report/tables/am_2017_01_v1_total_expenditure_audit.csv`
- `report/tables/am_2017_01_v1_sectoral_fiscal_covariate_imputations.csv`
- `report/tables/am_2017_01_v1_quarterly_covariate_coverage.csv`

**Output figures:** `report/figures/` (preliminary, paths, gaps, weights, placebo)

**Placebo data:** `output/placebo_inspace/`
- `placebo_paths_preferred_smooth.csv`
- `placebo_summary_preferred_smooth.csv`

**LOO placebo data:** `output/placebo_loo/` (6 leave-one-out placebo CSVs)
