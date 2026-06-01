# First Validation Note: Gubernatorial Ruptures

This note documents the first pass used to populate `data/raw/governor_removal_events.csv`.

## Inclusion rule in this first pass

- Post-1988 cases in which a sitting governor of a Brazilian federative unit was removed from power before the legal end of the term.
- Includes both definitive and temporary removals.
- Includes electoral cassation, federal intervention, impeachment suspension, and judicial suspension.
- Includes the Federal District in the broad version of the inventory.
- Excludes cases in which removal was only requested or under judgment but had not yet occurred as of 2026-05-13.

## Cases entered

1. `PB_2009_01` - Cássio Cunha Lima
2. `MA_2009_01` - Jackson Lago
3. `TO_2009_01` - Marcelo Miranda
4. `DF_2010_01` - José Roberto Arruda
5. `AM_2017_01` - José Melo
6. `TO_2018_01` - Marcelo Miranda
7. `RR_2018_01` - Suely Campos
8. `RR_2026_01` - Edilson Damião
9. `RJ_2020_01` - Wilson Witzel
10. `SC_2020_01` - Carlos Moisés
11. `SC_2021_01` - Carlos Moisés
12. `TO_2021_01` - Mauro Carlesse
13. `TO_2025_01` - Wanderlei Barbosa

## Important scope notes

- The Federal District remains included in the broad inventory, per project choice.
- Antonio Denarium was not coded as the removed governor in 2026 because he renounced on 2026-03-27 to run for the Senate. The rupture event coded is the later cassation of Edilson Damião, who was the sitting governor when the TSE decision was executed on 2026-04-30.
- Cláudio Castro was rechecked. On 2026-03-23 he renounced the governorship, and on 2026-03-24 the TSE declared him ineligible. Because he had already left office voluntarily, I did not code this as a completed removal event in `governor_removal_events.csv`. It is, however, saved in the source inventory as a borderline case (`RJ_2026_01`) for later analytical choice.
- Carlos Moisés appears twice because there were two distinct temporary removals with separate return dates.
- Wilson Witzel appears once because the file treats the removal episode starting on 2020-08-28 as a single interruption sequence that later culminated in impeachment on 2021-04-30.
- The event file intentionally mixes temporary and definitive removals because it is an event inventory. Later we can filter it into a stricter estimation sample.

## Main sources used

- TSE on José Melo (Amazonas): <https://www.tse.jus.br/comunicacao/noticias/2017/Maio/tse-cassa-governador-do-amazonas-e-determina-nova-eleicao-para-o-cargo>
- TSE on Jackson Lago (Maranhão): <https://www.tse.jus.br/comunicacao/radio/2009/Abril/1176042-tse-confirma-cassacao-do-governador-do-maranhao-jackson-lago-e-seu-vice>
- TSE on Marcelo Miranda 2018 (Tocantins): <https://www.tse.jus.br/comunicacao/noticias/2018/Marco/tse-cassa-mandatos-do-governador-do-tocantins-e-de-sua-vice>
- Senado on federal intervention in Roraima: <https://www12.senado.leg.br/noticias/materias/2018/12/12/senado-aprova-intervencao-federal-em-roraima>
- STJ on Wilson Witzel suspension: <https://www.stj.jus.br/sites/portalp/Paginas/Comunicacao/Noticias/28082020-STJ-afasta-o-governador-Witzel-do-cargo-e-prende-seis-investigados-por-irregularidades-na-Saude-do-Rio.aspx>
- TJRJ on Witzel impeachment judgment: <https://www-hml.tjrj.jus.br/noticias/noticia/-/visualizar-conteudo/5111210/8115573>
- ALESC on Carlos Moisés first removal: <https://alesc.sc.gov.br/radioal/noticia/tribunal-especial-determina-afastamento-provisorio-do-governador/>
- ALESC on Carlos Moisés return in 2020: <https://www.alesc.sc.gov.br/agenciaal/noticia/por-6-votos-a-3-moises-e-absolvido-e-retorna-ao-cargo/>
- ALESC on Carlos Moisés second removal: <https://www.alesc.sc.gov.br/radioal/noticia/tribunal-especial-determina-afastamento-provisorio-do-governador1/>
- ALESC on Carlos Moisés return in 2021: <https://www.alesc.sc.gov.br/agenciaal/noticia/moises-e-inocentado-no-caso-dos-respiradores-e-retornara-ao-comando-do-esta/>
- STJ on Mauro Carlesse suspension: <https://www.stj.jus.br/sites/portalp/Paginas/Comunicacao/Noticias/20102021-STJ-afasta-governador-do-Tocantins-por-180-dias-em-investigacao-sobre-desvios-no-plano-de-saude-dos-servidores.aspx>
- STJ on Mauro Carlesse after resignation: <https://www.stj.jus.br/sites/portalp/Paginas/Comunicacao/Noticias/28032022-STJ-envia-processos-contra-ex-governador-do-Tocantins-para-o-primeiro-grau-apos-a-renuncia-do-mandato.aspx>
- STJ on Wanderlei Barbosa suspension: <https://www.stj.jus.br/sites/portalp/Paginas/Comunicacao/Noticias/2025/03092025-Corte-Especial-confirma-afastamento-do-governador-de-Tocantins-por-180-dias.aspx>
- FolhaBV on Edilson Damião and Sampaio: <https://www.folhabv.com.br/politica/posse-de-sampaio-como-governador-sera-as-16h30/>
- TSE on Cláudio Castro after resignation: <https://www.tse.jus.br/comunicacao/noticias/2026/Marco/tse-torna-inelegivel-ex-governador-do-rio-claudio-castro>

## Cases that deserve special scrutiny in the next pass

- Whether the Federal District should stay in the final article sample or remain only in the broad inventory.
- Whether Suely Campos should be analytically treated as a removal case or as a special end-of-term federal intervention episode.
- Whether the temporary removals should remain in the main dataset or migrate to an extended sample only.
- Whether the file should split some sequences into two events, especially when a temporary suspension later became a definitive loss of office.

## Instability onset coding pass

The event file now includes onset fields for the pre-removal instability window. The rule used in this pass is intentionally conservative and source-driven:

- Electoral cassations: code the first public adverse collegial decision that materially threatened the mandate, usually a TRE or TSE cassation decision.
- Impeachment cases: code the formal public start inside the legislature, such as reading, receipt, or notification of the impeachment request.
- Judicial/criminal suspensions: code the first public operation or judicial measure that made the sitting governor a target, unless the first observable measure was already the removal.
- Federal intervention: code the presidential decree/signature or official announcement because there is no case process against the governor in the same sense as impeachment or electoral cassation.

Two cases need extra caution in downstream designs:

- `RR_2018_01`: the coded onset is the PGR's public request for federal intervention on 2018-11-07, not the decree date. The decree was signed on 2018-12-08 and took effect with removal on 2018-12-10, but a two-day window would miss the observable pre-removal crisis.
- `RR_2026_01`: the coded onset is the TSE merits-stage judgment of the Denarium-Damiao ticket on 2025-08-26. Damião was not yet governor then; he became governor on 2026-03-27 and was cassed on 2026-04-30. This is suitable for a broad political-instability window but should be flagged in designs centered on sitting-governor exposure.
- `TO_2021_01`: the investigations were not coded before the public STJ/PF operation. For observability, the instability start equals the removal date.

All onset source ids are recorded in `references/source_inventory.csv` with `used_for = instability_start`.
