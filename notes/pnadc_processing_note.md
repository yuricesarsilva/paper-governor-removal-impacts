# PNADc Processing Note

This note records the planned construction of PNADc covariates for the project.

## Planned PNADc variables

- `household_income_per_capita_pnadc`
- `labor_income_real_pnadc`
- `pnadc_population`
- `unemployment_rate_pnadc`
- `formalization_rate_pnadc`

The PNADc variables should preserve the source frequency at collection. Harmonization to monthly, bimonthly, or event-specific analytical windows should happen only after coverage and timing are checked.

## Real income

For real PNADc labor income, use the deflator returned by `PNADcIBGE::get_pnadc()`:

```r
dadosPNADc <- PNADcIBGE::get_pnadc(year = 2026, quarter = 1, deflator = TRUE)
dadosPNADc <- update(dadosPNADc, VD4020_real = VD4020 * Efetivo)
```

The project variable constructed from this rule is:

```text
labor_income_real_pnadc
```

This variable is estimated by UF with the PNADc survey design, not by unweighted microdata means.

## Formalization rate

The formalization rate can be constructed from PNADcIBGE output saved as a survey design object, for example:

```r
dadosPNADc <- readRDS("dadosPNADc_2025.4.rds")
```

Operational definition:

```text
formalization_rate_pnadc = formal_occupied / occupied_total
```

where:

```text
occupied_total = formal_occupied + informal_occupied
```

The calculation should use `survey::svytotal()` or equivalent survey-design functions, not unweighted row counts.

## Formal occupied workers

Classify as formal among `VD4002 == "Pessoas ocupadas"`:

- `VD4009 == "Empregado no setor privado com carteira de trabalho assinada"`
- `VD4009 == "Trabalhador doméstico com carteira de trabalho assinada"`
- `VD4009 == "Empregado no setor público com carteira de trabalho assinada"`
- `VD4009 == "Militar e servidor estatutário"`
- `VD4009 == "Empregador" & V4019 == "Sim"`
- `VD4009 == "Conta-própria" & V4019 == "Sim"`

Template:

```r
formal_expr <- quote(
  VD4002 == "Pessoas ocupadas" &
    (
      VD4009 == "Empregado no setor privado com carteira de trabalho assinada" |
        VD4009 == "Trabalhador doméstico com carteira de trabalho assinada" |
        VD4009 == "Empregado no setor público com carteira de trabalho assinada" |
        VD4009 == "Militar e servidor estatutário" |
        (VD4009 == "Empregador" & V4019 == "Sim") |
        (VD4009 == "Conta-própria" & V4019 == "Sim")
    )
)
```

## Informal occupied workers

Classify as informal among `VD4002 == "Pessoas ocupadas"`:

- `VD4009 == "Empregado no setor privado sem carteira de trabalho assinada"`
- `VD4009 == "Trabalhador doméstico sem carteira de trabalho assinada"`
- `VD4009 == "Empregado no setor público sem carteira de trabalho assinada"`
- `VD4009 == "Trabalhador familiar auxiliar"`
- `VD4009 == "Empregador" & V4019 == "Não"`
- `VD4009 == "Conta-própria" & V4019 == "Não"`

Template:

```r
informal_expr <- quote(
  VD4002 == "Pessoas ocupadas" &
    (
      VD4009 == "Empregado no setor privado sem carteira de trabalho assinada" |
        VD4009 == "Trabalhador doméstico sem carteira de trabalho assinada" |
        VD4009 == "Empregado no setor público sem carteira de trabalho assinada" |
        VD4009 == "Trabalhador familiar auxiliar" |
        (VD4009 == "Empregador" & V4019 == "Não") |
        (VD4009 == "Conta-própria" & V4019 == "Não")
    )
)
```

## Implementation cautions

- Keep the occupation filter outside the category disjunction: `VD4002 == "Pessoas ocupadas" & (...)`.
- Use explicit parentheses around employer and self-employed CNPJ conditions.
- Confirm whether the PNADcIBGE object labels `V4019` as `Sim`/`Não` or uses another encoding in the selected files.
- The final script should compute the rate for every available UF and period, not only for Roraima.
- Store the formal and informal totals alongside the rate to make validation easier.
