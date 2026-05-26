Ideias a serem implementadas

1) população deve ser a mesma usada para repartição do FPE

2) no lugar de PIB per capita, seria melhor usar renda domiciliar per capita da PNAD contínua.

3) Já que vai usar PNADc, talvez, considerar taxa de desocupação seja importante como co-variável.

Atualizacao de 2026-05-26:

- A renda domiciliar per capita da PNADc foi incorporada ao escopo como `household_income_per_capita_pnadc`.
- A populacao da PNADc foi incorporada ao escopo como `pnadc_population`, usando o mesmo conceito/fonte das demais variaveis PNADc.
- A taxa de desocupacao da PNADc foi incorporada ao escopo como `unemployment_rate_pnadc`.
- A taxa de formalizacao da PNADc foi incorporada ao escopo como `formalization_rate_pnadc`, usando objetos de desenho amostral do PNADcIBGE e a classificacao formal/informal documentada em `notes/pnadc_processing_note.md`.
- Essas variaveis devem ser construidas junto com o bloco Siconfi/RREO antes da montagem final dos modelos.
