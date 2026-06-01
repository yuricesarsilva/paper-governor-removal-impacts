# Channels and Instability Timing Design

This note records two design extensions motivated by the political instability literature.

## Motivation

The project should distinguish two treatment moments:

- `removal_date`: the date when the governor effectively loses office.
- `instability_start_date`: the date when a formal, public, and procedurally relevant process begins to threaten the governor's tenure.

The first date remains the main treatment date. The second date allows tests for anticipatory or crisis-period effects before the actual removal.

## Literature Alignment

This design is consistent with two pieces of the current literature folder.

Dirks and Schmidt (2024) explicitly frame the effect of political instability on economic growth through demand-side transmission channels. Their empirical design decomposes economic growth into investment, private consumption, and government consumption, and their results point to negative responses in all three components after political instability shocks. This supports using separate outcome families for:

- private-sector uncertainty and investment behavior;
- household precaution and consumption;
- public-sector adjustment and spending behavior.

The mapping is not one-to-one in the Brazilian state setting because the project does not observe state-level private investment or household savings directly at high frequency. Still, the existing data can proxy the same conceptual channels: CAGED and activity indices for private-sector adjustment, PMC/PMS and PNADc income/formalization for household-side adjustment, and Siconfi/RREO for public-sector adjustment.

Gibilisco and Helmke (2013) support a second key design choice: treating the beginning of a removal challenge as analytically meaningful, not only the moment of successful removal. Their measure is coded at the onset of a legislative challenge to the executive and includes both successful and unsuccessful attempts. They also emphasize timing, including lagged attacks and expectations of future attacks. This supports adding an `instability_start_date` to the event inventory and treating the crisis interval as potentially contaminated pre-treatment.

The closest analogue in this project is not always a legislative attack. Brazilian gubernatorial removals include electoral cassation, judicial suspension, impeachment, and federal intervention. Therefore the coding rule must be broader than "legislative challenge" but still formal and source-based.

## Economic Channels

The preferred interpretation should separate three channels.

### 1. Firm uncertainty and private investment channel

Concept:

- Political instability increases uncertainty for firms.
- Firms delay hiring, expansion, purchases, or investment.

Available proxies in the current project:

- `formal_hiring_balance` from CAGED as the high-frequency labor demand proxy.
- `retail_volume_index` from PMC as a broad local demand/activity proxy.
- `services_volume_index` from PMS as a broad service-sector activity proxy.

Candidate extension:

- Mapa de Empresas/Redesim, with monthly counts of opened and closed firms by location and economic activity, is a promising firm-entry proxy for the private-investment/uncertainty channel.
- The directly scriptable Redesim opening-time endpoint can provide monthly successful opening requests by UF from 2019 onward, documented in `notes/mapa_empresas_source_investigation.md`.

Current limitation:

- The project does not yet have a direct private investment measure at state-month frequency.
- Firm entry is not private investment itself, but lower openings or higher closures during instability would be consistent with delayed entrepreneurial or investment decisions.
- A future extension could evaluate sources for construction permits, credit, firm entry, or state-level investment proxies.

### 2. Household precaution and consumption channel

Concept:

- Political instability can increase precautionary behavior among households.
- Households may postpone durable and non-durable consumption or increase savings.

Available proxies in the current project:

- `retail_volume_index` from PMC as the preferred consumption-side outcome.
- `services_volume_index` from PMS as a complementary household and business services activity proxy.
- `labor_income_real_pnadc` from PNADc as an income-side mechanism.
- `unemployment_rate_pnadc` and `formalization_rate_pnadc` as labor-market conditions shaping household behavior.

Current limitation:

- The project does not directly observe household savings.
- Consumption should therefore be interpreted through activity proxies, especially retail.

### 3. Incoming-governor adjustment and public-sector channel

Concept:

- Removal can paralyze the outgoing administration and force reallocation or adjustment by the incoming administration.
- Effects may appear in public spending, investment execution, and revenue/fiscal ratios.

Available proxies in the current project:

- `public_investment_liquidated_real` from Siconfi/RREO.
- `liquidated_expenditure_total_real`.
- `liquidated_expenditure_health_real`.
- `liquidated_expenditure_education_real`.
- `liquidated_expenditure_public_security_real`.
- `total_revenue_real`.
- `state_tax_revenue_real`.
- `federal_transfers_real`.
- `transfer_dependency_ratio`.
- `own_revenue_ratio`.

Current limitation:

- Siconfi/RREO is available through the current route from 2015 onward.
- Early 2009/2010 cases need either non-Siconfi fiscal sources or economic-only specifications.

## Instability Timing Variables

The event inventory now includes columns for the crisis/process phase:

- `instability_start_date`: first formal date of the pre-removal process.
- `instability_start_type`: operational timing marker used to define the start.
- `instability_process_type`: legal or political process category.
- `instability_initiating_actor`: actor or institution that initiated the process.
- `instability_start_source_id`: source id supporting the start date.
- `instability_start_confidence`: confidence in the timing code.
- `instability_duration_days`: days from `instability_start_date` to `removal_date`.
- `instability_coding_notes`: short caveats and coding explanation.

Recommended values for `instability_start_type`:

- `petition_filed`
- `complaint_filed`
- `impeachment_request_filed`
- `impeachment_request_accepted`
- `investigation_public_operation`
- `judicial_inquiry_opened`
- `court_trial_started`
- `presidential_decree_or_public_announcement`
- `source_audit_pending`

Recommended values for `instability_process_type`:

- `electoral_judicial_process`
- `state_impeachment_process`
- `criminal_judicial_investigation`
- `federal_intervention_process`
- `mixed_judicial_political_process`
- `source_audit_pending`

Recommended values for `instability_start_confidence`:

- `high_official_date`
- `medium_official_context`
- `medium_press_chronology`
- `low_ambiguous_start`
- `source_audit_pending`

## Coding Rule

The project should not code `instability_start_date` from memory. Each date should be supported by a row in `references/source_inventory.csv`, preferably from an official court, legislative, or executive source.

If multiple dates are plausible, use the earliest date that satisfies all three conditions:

1. the process is formal rather than rumor or generic criticism;
2. the process is public or institutionally observable;
3. the process can plausibly threaten removal, suspension, cassation, resignation, or intervention.

When a later date marks a stronger escalation, record that in `instability_coding_notes` and consider creating secondary episode-level files later.

## Empirical Use

The main treatment remains `removal_date`.

The crisis-period timing can support:

- an anticipatory-treatment specification starting at `instability_start_date`;
- an event-study style plot separating crisis period and post-removal period;
- robustness checks excluding the crisis period from the pre-treatment window;
- separate "crisis effect" and "removal effect" windows.

For synthetic control, the conservative default is:

- estimate the donor weights using only observations before `instability_start_date`;
- treat the interval from `instability_start_date` to `removal_date` as a crisis window, not as clean pre-treatment;
- estimate post-removal effects from `removal_date` onward.
