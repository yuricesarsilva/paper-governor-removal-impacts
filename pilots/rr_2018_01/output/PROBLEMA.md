**Pergunta:**

Uma dúvida. O período pós-tratamento é limpo nas médias móveis? Ou seja, a primeira média móvel só está levando em consideração períodos pós tratamento?

**Resposta:**

Não. Do jeito que está implementado agora, o pós-tratamento das médias móveis **não é totalmente limpo nos primeiros meses**.

A média móvel é calculada como média móvel retrospectiva por estado, depois de remover dezembro de 2018 como mês de transição. Então:

- `MA3` de janeiro de 2019 usa outubro/novembro de 2018 + janeiro de 2019.
- `MA3` de fevereiro de 2019 usa novembro de 2018 + janeiro/fevereiro de 2019.
- A primeira `MA3` pós “limpa”, só com meses pós, é março de 2019.

Para `MA6`, o problema é maior:

- janeiro de 2019 mistura cinco meses pré + janeiro;
- fevereiro mistura quatro meses pré + dois pós;
- março mistura três pré + três pós;
- a primeira `MA6` totalmente pós é junho de 2019.

Então, para a nossa pergunta de curto prazo, isso é importante: as médias móveis suavizam justamente o início do efeito, misturando meses pré-tratamento com meses pós-tratamento. Isso tende a “amortecer” o choque inicial e pode reduzir a magnitude aparente do efeito nos primeiros meses.

O caminho mais correto agora seria criar uma versão “limpa” das médias móveis para análise pós-tratamento, reiniciando a janela em janeiro de 2019. Ou seja: a média móvel de janeiro usaria só janeiro; fevereiro usaria janeiro-fevereiro; março usaria janeiro-março; e assim por diante. Aí conseguimos interpretar o curto prazo sem carregar informação pré-tratamento para dentro do pós.

**ISSO É UM PROBLEMA!! TEMOS QUE RESOLVER!**