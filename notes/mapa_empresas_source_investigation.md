# Mapa de Empresas Source Investigation

Investigation date: 2026-06-01.

## Motivation

The Mapa de Empresas is a candidate source for the firm-uncertainty/private-investment channel. It can potentially measure whether political instability reduces firm entry or increases firm exit.

## Official Source

Official page:

- `https://www.gov.br/empresas-e-negocios/pt-br/mapa-de-empresas/mapa-de-empresas`

The official page states that the tool provides monthly information on business registration procedures, including average opening time and the number of opened and closed firms, with details on location and economic activity.

Panel page:

- `https://www.gov.br/empresas-e-negocios/pt-br/mapa-de-empresas/painel-mapa-de-empresas`

The panel page embeds Qlik Sense dashboards hosted by Serpro:

- Registro de Empresas: `https://dd.serpro.gov.br/publico/sense/app/7979697b-ad3d-4b28-a5bf-9cd48ea9eae7/sheet/09f13ad4-bddd-42c7-a88b-ac7201783544/state/analysis`
- Socios: `https://dd.serpro.gov.br/publico/sense/app/2a7344b2-670f-46d4-8632-7d262923aee0/sheet/uJkjqm/state/analysis`
- Tempo de Abertura: `https://dd.serpro.gov.br/publico/sense/app/314cd578-2c59-45c4-894f-186422f7f5cd/sheet/fed74ebc-0972-4bd9-9855-8e16921ce752/state/analysis`
- Inova Simples: `https://dd.serpro.gov.br/publico/sense/app/0fcce21a-e0c1-4f4f-bceb-f520f45f75e2/sheet/a840ec0d-6d64-493f-8ab5-ee11a823e125/state/analysis`

Extraction guide:

- `https://www.gov.br/empresas-e-negocios/pt-br/mapa-de-empresas/arquivos/orientacoes-para-extracao-de-dados.pdf/@@download/file`

The extraction guide documents manual data download through the dashboard interface. It does not document a public bulk API.

## Direct JSON Endpoints Found

The older Redesim statistics application exposes JSON endpoints:

- Base: `https://estatistica.redesim.gov.br/`

Current stock by UF:

- `situacao-cadastral/api/dataultimacarga`
- `situacao-cadastral/api/qtdeestabelecimentouf`
- `situacao-cadastral/api/qtdeestabelecimentosituacao`
- `situacao-cadastral/api/qtdeestabelecimentomunicipios?uf=RR`

Opening-time monthly endpoints:

- `tempos-abertura-redesim/periodos-disponiveis`
- `tempos-abertura-redesim/tempos-abertura?ano=2026&mes=3`
- `tempos-abertura-redesim/tempo-medio-total-abertura?ano=2026&mes=3`
- `tempos-abertura-redesim/tempo-medio-total-abertura/RR?ano=2026&mes=3`
- `tempos-abertura-redesim/solicitacoes-abertura?ano=2026&mes=3`
- `tempos-abertura-redesim/solicitacoes-abertura/RR?ano=2026&mes=3`
- `tempos-abertura-redesim/percentual-viabilidade/RR?ano=2026&mes=3`
- `tempos-abertura-redesim/tempo-registro-inscricao/RR?ano=2026&mes=3`
- `tempos-abertura-redesim/percentual-solicitacoes-abertura/RR?ano=2026&mes=3`

The available-period endpoint returned months from 2019 through 2026 in the current check. Spot checks returned valid UF-level request counts for `RR/2019-01`, `RR/2020-01`, and `SP/2019-01`.

## Candidate Variables

Directly scriptable from Redesim endpoints:

- `business_opening_requests`: successful opening requests by UF-month.
- `business_opening_time_days`: average time to open a business by UF-month.
- `business_opening_time_hours`: residual hours in the average opening time by UF-month.
- `business_opening_share_under_3_days`: share of requests concluded within the shortest opening-time bracket.
- `business_opening_process_distribution`: distribution of requests by opening-time bracket.

Possible from Qlik manual extraction:

- `firm_openings`.
- `firm_closures`.
- `active_firms`.
- breakdowns by UF, municipality, legal nature, and economic activity.

## Assessment

The source is promising but has two layers.

The scriptable Redesim endpoint is useful immediately for a monthly proxy of firm-entry behavior. The best variable is `solicitacoes-abertura/{UF}`, described by the application as opening requests that resulted in a new business. This is not exactly the same as all firm openings in the Registro de Empresas panel, but it is a plausible high-frequency entrepreneurial-entry proxy.

The richer Registro de Empresas panel appears to be served through public Qlik Sense dashboards. The official guide documents manual extraction via the dashboard, but no documented bulk API was found. Unauthenticated Qlik QRS endpoints tested returned `401`, and generic Qlik cloud-style API endpoints did not return usable metadata.

## Recommended Decision

Use a two-step strategy:

1. Build a quick scripted panel from the Redesim `tempos-abertura-redesim` endpoints for `business_opening_requests` and opening-time variables, covering 2019 onward.
2. Later, evaluate whether manual Qlik extraction or Qlik Engine reverse engineering can recover the richer `firm_openings`, `firm_closures`, and sectoral detail from the Registro de Empresas panel.

For the current project, `business_opening_requests` can enter as a secondary firm-entry proxy for post-2019 cases. It will not help the early 2009/2010 cases and should not replace CAGED as the main high-frequency private-sector outcome.
