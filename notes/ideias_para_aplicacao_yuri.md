Ideias a serem implementadas

1) população deve ser a mesma usada para repartição do FPE

2) no lugar de PIB per capita, seria melhor usar renda domiciliar per capita da PNAD contínua.

3) Já que vai usar PNADc, talvez, considerar taxa de desocupação seja importante como co-variável.

Atualizacao de 2026-05-26:

- A renda PNADc ativa foi redefinida como `labor_income_real_pnadc`, obtida do SIDRA/PNADCT.
- A populacao da PNADc foi incorporada ao escopo como `pnadc_population`, usando pessoas de 14 anos ou mais no SIDRA/PNADCT.
- A taxa de desocupacao da PNADc foi incorporada ao escopo como `unemployment_rate_pnadc`.
- A taxa de formalizacao da PNADc foi incorporada ao escopo como `formalization_rate_pnadc`, calculada como complemento da taxa oficial de informalidade do SIDRA.
- Essas variaveis devem ser construidas junto com o bloco Siconfi/RREO antes da montagem final dos modelos.
