# Model Specification Recommendation

This note records the recommended standard outcome and covariate strategy for the synthetic-control models. The goal is to avoid case-by-case variable selection while still respecting differences in scale across Brazilian states.

## Design Principle

The project should use a fixed conceptual specification across cases:

1. economic activity and household demand;
2. labor-market adjustment;
3. public-sector execution and fiscal adjustment.

Variables should be normalized before estimation whenever their raw level mechanically reflects state size. The preferred normalization is:

- index variables: keep the official index, preferably transformed to log index when estimating effects;
- count or flow variables: divide by working-age population or a relevant stock and express as rates;
- fiscal monetary variables: deflate and divide by population;
- fiscal composition variables: use ratios to total revenue or total expenditure.

The donor pool should be matched on pre-treatment paths and pre-treatment covariates only. The interval between `instability_start_date` and `removal_date` should not be used as clean pre-treatment in the preferred specification.

## Main Treatment Dates

The preferred model should estimate two related designs:

- `removal_date` as the main treatment date;
- `instability_start_date` as an anticipatory or crisis-period robustness design.

The preferred synthetic-control weights should be estimated using only observations before `instability_start_date` when the instability window is source-supported.

## Recommended Dependent Variables

The preferred outcome set should have two variables for each theoretical channel. This creates a pre-specified structure that is easy to defend: the paper does not choose one outcome per case, but repeatedly asks whether the same channel-specific outcomes respond to gubernatorial removal.

The recommended six-outcome block is:

### Channel 1: firm uncertainty and private-sector adjustment

1. `formal_hiring_balance_per_100k_wap`
   - Type: economic.
   - Construction: `formal_hiring_balance` divided by working-age population, multiplied by 100,000.
   - Justification: firms facing uncertainty can delay hiring or reduce labor demand. The normalized hiring balance is the cleanest high-frequency proxy for this channel in the current project.
   - Scale rule: never use the raw hiring balance in cross-state SCM because it mechanically reflects state size.

2. `icms_revenue_real_pc` or current proxy `state_tax_revenue_real_pc`
   - Type: public finance with economic-content interpretation.
   - Construction: real ICMS revenue divided by resident population. Until an ICMS-specific source is materialized, use `state_tax_revenue_real_pc` from Siconfi/RREO as the operational proxy.
   - Justification: ICMS is closely tied to taxable circulation of goods and services and therefore offers a fiscal high-frequency proxy for private economic activity. It is not investment itself, but a fall in the tax base is consistent with reduced activity, delayed transactions, or weaker firm-side dynamics.
   - Source caveat: the current processed Siconfi/RREO panel has broad state tax revenue, not ICMS isolated. A future data step should evaluate an ICMS-specific series.

### Channel 2: household precaution and consumption

3. `retail_volume_index`
   - Type: economic.
   - Justification: this is the closest high-frequency state-level proxy for household consumption. It maps directly onto the household precaution channel: political instability may lead households to postpone purchases.
   - Scale rule: use the official index, preferably in log form or as percentage deviation from the synthetic control.

4. `services_volume_index`
   - Type: economic.
   - Justification: services activity captures household and local demand beyond retail. It is not pure consumption, but it is a high-frequency state-level proxy for service-sector activity affected by precautionary behavior and local uncertainty.
   - Scale rule: use the official index, preferably in log form or as percentage deviation from the synthetic control.

### Channel 3: public-sector paralysis and incoming-government adjustment

5. `public_investment_liquidated_real_pc`
   - Type: public finance.
   - Construction: real liquidated investment divided by resident population.
   - Justification: public investment is the most direct fiscal proxy for administrative stoppage, project interruption, reprogramming, or incoming-government adjustment.
   - Coverage caveat: this variable has known missingness and possible reporting problems in some Siconfi/RREO periods. It remains theoretically central, but its coverage must be audited before final estimation.

6. `liquidated_expenditure_total_real_pc`
   - Type: public finance.
   - Construction: real total liquidated expenditure divided by resident population.
   - Justification: this separates investment-specific effects from broad expenditure execution. If investment falls but total expenditure does not, the effect is likely reallocation or project-specific paralysis; if both fall, the shock may be broader fiscal execution disruption.

### Secondary mechanism outcomes

These variables should be kept for robustness and mechanism interpretation, not as the headline six-outcome block:

- `liquidated_expenditure_health_real_pc`;
- `liquidated_expenditure_education_real_pc`;
- `liquidated_expenditure_public_security_real_pc`;
- `labor_income_real_pnadc`;
- `labor_income_real_pnad_legacy`;
- `total_revenue_real_pc`;
- `own_revenue_ratio`;
- `transfer_dependency_ratio`;
- `firm_openings_per_100k_wap`, if the Mapa de Empresas/Redesim series is adopted;
- `business_opening_requests_per_100k_wap`, if the Redesim endpoint is adopted.

## Recommended Covariate Block

The covariate block should be fixed conceptually across all cases. When source regimes differ, the same concept should be used with the appropriate source and flagged.

### Dynamic pre-treatment predictors

Use pre-treatment averages and selected lags of the dependent variable itself. This is essential for synthetic-control credibility and usually more important than a long list of controls.

For every outcome model:

- outcome mean over the full clean pre-treatment window;
- outcome mean over the last 12 months, or last 6 bimesters for fiscal outcomes;
- outcome value or average in the final clean pre-treatment period before `instability_start_date`.

This rule is fixed across cases and avoids selecting lags opportunistically.

### Core structural covariates

Population should not enter the covariate block as a matching variable. It should be used only as a denominator to construct rates and per-capita outcomes. This avoids building a donor pool that is driven by state size rather than economic and institutional comparability.

1. `unemployment_rate_pnadc` or PNAD legacy unemployment rate
   - Captures labor-market slack before treatment.
   - Important because employment and consumption responses depend on initial conditions.

2. `formalization_rate_pnadc` or PNAD legacy formalization proxy
   - Captures exposure to formal labor-market adjustment.
   - Important for interpreting CAGED because states differ in the size of their formal sector.

Real labor income is no longer part of the preferred six-outcome block because its quarterly or annual frequency makes it less aligned with the preferred high-frequency case design. It may remain a secondary mechanism outcome or structural covariate in robustness exercises.

### Fiscal covariates

Use these when the treatment case has sufficient clean pre-treatment Siconfi/RREO coverage:

1. `own_revenue_ratio`
   - Captures fiscal autonomy.
   - Important because states dependent on transfers may react differently to political disruption.

2. `transfer_dependency_ratio`
   - Captures dependence on federal transfers.
   - Technically useful because it compares fiscal structure without scale problems.

3. `liquidated_expenditure_health_real_pc`
   - Captures baseline social-service spending capacity in a major mandatory/politically salient function.

4. `liquidated_expenditure_education_real_pc`
   - Captures baseline education spending capacity and service-delivery commitment.

5. `liquidated_expenditure_public_security_real_pc`
   - Captures baseline security spending, relevant for institutional crises and public-order concerns without tailoring the model to any single case.

For early 2009/2010 cases without Siconfi coverage, the fiscal covariate block should be omitted for every early-case model by a pre-specified availability rule, not by outcome results.

## Normalized Variables To Build

The analysis scripts should construct these normalized variables:

- `formal_hiring_balance_per_100k_wap`;
- `state_tax_revenue_real_pc`;
- `public_investment_liquidated_real_pc`;
- `liquidated_expenditure_total_real_pc`;
- `liquidated_expenditure_health_real_pc`;
- `liquidated_expenditure_education_real_pc`;
- `liquidated_expenditure_public_security_real_pc`;
- `state_tax_revenue_real_pc`;
- `total_revenue_real_pc`;
- `firm_openings_per_100k_wap`, if the Mapa de Empresas/Redesim series is adopted;
- `business_opening_requests_per_100k_wap`, if the Redesim endpoint is adopted.

## Preferred Baseline Model

For each case and outcome, the preferred SCM specification should use:

- the normalized or indexed dependent variable;
- pre-treatment outcome path predictors using the fixed lag rule;
- unemployment rate;
- formalization rate;
- transfer dependency;
- health expenditure per capita;
- education expenditure per capita;
- public-security expenditure per capita;
- fiscal predictors only when covered by the pre-specified availability rule.

This gives the same conceptual model across cases while respecting source availability.

Population and working-age population enter only indirectly as denominators in normalized outcomes and fiscal predictors. They should not be used as standalone covariates in the baseline SCM.

When one of these variables is itself the dependent variable, it should be removed from the covariate block for that outcome model to avoid mechanically matching on the target variable twice. The pre-treatment trajectory of the dependent variable remains the main dynamic predictor.

## Estimator Rule

The preferred estimator is Augmented Synthetic Control. Classic Synthetic Control should still be estimated for every outcome as an initial visual comparison and diagnostic benchmark, but the headline estimates should come from the augmented SCM specification.

The rationale is:

- Classic SCM is transparent and useful for showing the raw treated-versus-synthetic trajectory;
- Augmented SCM is preferred for estimation because it can reduce bias when exact pre-treatment fit is difficult, which is likely in a setting with heterogeneous Brazilian states;
- reporting both avoids making the result look dependent on a single estimator choice.

## Raw And Smoothed Outcome Rule

For each dependent variable, the project should estimate the model on the raw series and, when the frequency allows, on a clean moving-average version.

### Monthly outcomes

Monthly dependent variables should have two specifications:

1. raw monthly series;
2. clean 6-month moving-average series.

The clean moving average must be computed separately within the pre-treatment and post-treatment segments. No moving-average window should cross from the clean pre-treatment period into the crisis or post-removal period.

For post-removal effects, the first smoothed post-treatment observation should be the first complete 6-month post-treatment moving average. If treatment begins in month `t`, the first smoothed post-treatment point is the average over `t` through `t+5`, dated at `t+5`.

For visualization, also create a partial-window version:

- `*_ma6_visual`

This visual series resets within pre/crisis/post segments and uses available observations at the beginning of each segment until the full 6-month window is available. It must not be used for headline RMSPE or effect summaries, but it should be used in plots to avoid hiding the immediate transition period.

### Bimonthly outcomes

Bimonthly dependent variables should also have two specifications:

1. raw bimonthly series;
2. clean moving-average series.

Operationally, the current rule is a 4-period bimonthly moving average, computed separately within pre-treatment and post-treatment segments. If the intended substantive window is exactly one year, this should be revised to 6 bimesters before final estimation.

For post-removal effects, the first smoothed post-treatment observation should be the first complete post-treatment moving-average window. Under the 4-bimester rule, if treatment begins in bimester `b`, the first smoothed post-treatment point is the average over `b` through `b+3`, dated at `b+3`.

For visualization, also create:

- `*_ma4_visual`

This visual series resets within pre/crisis/post segments and uses partial windows at the beginning of each segment. It should be plotted, while `*_ma4_clean` remains the preferred smoothed estimation series.

### Quarterly and annual outcomes

Quarterly and annual dependent variables should not receive an additional moving-average specification by default. Their lower frequency already smooths short-run noise, and extra smoothing would quickly consume too much pre-treatment information.

## Investment Data Audit

The public-investment variable is theoretically central, but the current Siconfi/RREO processing note already flags missing investment observations in some periods. Before final models use `public_investment_liquidated_real_pc`, the project should run a targeted audit to classify each missing or anomalous observation as:

- download failure;
- parsing or mapping problem;
- true non-reporting in the official source;
- accounting revision or negative flow generated by cumulative-to-flow differencing.

Until that audit is complete, public investment should remain in the recommended model list but carry an explicit coverage flag in estimation outputs.

## Interpretation

The headline results should not claim that each outcome identifies one channel perfectly. Instead:

- retail is the clearest consumption-side proxy;
- services combine household demand and local business activity;
- formal hiring balance is the clearest firm-side labor-demand proxy;
- state tax revenue per capita is the current fiscal proxy for ICMS-linked taxable activity until an ICMS-specific series is built;
- public investment and total liquidated expenditure identify the public-sector execution channel.

This structure follows the channel logic in Dirks and Schmidt (2024), adapted to Brazilian state-level high-frequency data. The separate crisis window follows Gibilisco and Helmke (2013), which motivates treating the beginning of removal challenges as analytically meaningful rather than focusing only on successful removal dates.
