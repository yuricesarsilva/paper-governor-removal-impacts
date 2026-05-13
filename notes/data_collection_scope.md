# Data Collection Scope

This note defines the current scope of data collection for the project.

## General rules

- Keep each series in its original frequency at the collection stage.
- Use `IPCA` as the standard deflator for nominal fiscal series.
- Store the original series first; do not impose transformations at the collection stage.
- Monthly series should remain monthly.
- Bimonthly series should remain bimonthly.
- Annual series should remain annual.

## Main outcomes to collect

### Monthly

- `formal_hiring_balance`
- `retail_volume_index`
- `services_volume_index`

### Bimonthly

- `public_investment_liquidated_real`
- `liquidated_expenditure_total_real`
- `liquidated_expenditure_health_real`
- `liquidated_expenditure_education_real`
- `liquidated_expenditure_public_security_real`

## Covariates to collect

### Dynamic covariates

- `formal_hiring_balance`
- `retail_volume_index`
- `services_volume_index`
- `state_tax_revenue_real`
- `total_revenue_real`
- `federal_transfers_real`
- `transfer_dependency_ratio`
- `own_revenue_ratio`

### Structural covariates

- `population`
- `gdp_per_capita_real`

## Special note on annual covariates

- `population` and `gdp_per_capita_real` are annual.
- They are retained because they help characterize states structurally.
- They should not dominate the dynamic matching block in monthly or bimonthly SCM designs.
- For post-2023 treatments, `gdp_per_capita_real` may use the last available pre-treatment value.

## Special note on employment data

- Formal employment is an important outcome and covariate family in the project.
- When necessary, the employment series may combine `Old Caged` and `Novo Caged`.
- In those cases, the final analytical files should include a methodological-break control such as `post_2020_caged_dummy`.
- The original collected series should still preserve the source distinction.
