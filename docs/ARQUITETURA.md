# Arquitetura

## Princípios inegociáveis

1. **O domínio não conhece infraestrutura.** `quant_core`, `quant_stats` e
   `quant_engine` não importam HTTP, Firebase, arquivos nem Flutter.
   Toda entrada/saída passa pelas portas (`SeriesRepository`,
   `MarketDataProvider`) definidas em `quant_core`.
2. **Nenhuma fórmula estatística fora de `quant_stats`.** Um cálculo, um
   lugar, testes de valores conhecidos.
3. **Nenhum resultado sem tentativa de destruição.** Backtests reportam o
   trecho final (30%) separadamente; hipóteses só são salvas se o sinal
   persistir no conjunto de teste.
4. **Nível C não existe.** O sistema não tem campo para notícia, opinião ou
   análise de terceiros. Só nível A (fontes oficiais) e B (preços de bolsa).

## Camadas

```
apps/lab_cli (Presentation + Application)
      │  Lab (fachada): liga portas a engines; zero regra de negócio
      ▼
packages/engine (Domain services)   packages/stats (Domain: matemática)
      │                                   ▲
      ▼                                   │
packages/core (Domain: entidades, VOs, portas, Result)
      ▲
      │ implementa as portas
packages/market_data (Infrastructure: BCB, Yahoo, arquivos)
```

Dependências apontam sempre "para dentro" (Clean Architecture): a
infraestrutura conhece o domínio; o domínio não conhece ninguém.

## Bounded contexts atuais → mapeamento futuro

| Contexto | Hoje | Futuro |
|---|---|---|
| Economy (indicadores/séries) | `core` + `market_data` | + adaptadores FRED, World Bank, INMET |
| Statistics | `stats` | cresce com bootstrap, testes de estacionariedade |
| Causality (hipóteses) | `engine/hypothesis.dart` | pacote próprio + banco de conhecimento versionado |
| Opportunity | `engine/opportunity.dart` | pacote próprio + motor de convicção (Fase 8) |
| Simulation | — | Fase 7 (cenários "e se") |
| Authentication / App | — | Flutter + Firebase Auth (login Google) |

## Decisões registradas (ADR resumido)

- **Dart puro no núcleo, CLI antes de Flutter.** Interface é fácil de
  evoluir; o patrimônio é o motor. O Flutter consumirá exatamente estes
  pacotes (são Dart sem dependência de plataforma).
- **Arquivos JSON antes de Firestore.** `FileSeriesStore` implementa a
  mesma porta que a futura versão Firestore. Trocar o backend de dados não
  toca uma linha de domínio.
- **Yahoo Finance é transporte, não fonte.** Os preços têm origem nas
  bolsas (nível B). Se o Yahoo sumir, escreve-se outro adaptador
  (`MarketDataProvider`) e nada mais muda. O mesmo vale para o BCB — mas o
  BCB *é* a fonte primária (nível A).
- **BCB SGS em janelas de 5 anos.** A API falha em consultas longas para
  algumas séries diárias (verificado empiricamente na série 432).
- **Variações, não níveis, no minerador de hipóteses.** Correlacionar
  níveis de séries com tendência produz correlações espúrias; o laboratório
  transforma tudo em variação mensal (retorno log para preços, diferença
  para taxas) antes de cruzar.
- **Sem custos de transação no backtest de tendência.** O objetivo é medir
  se a tendência tem poder preditivo no ativo, não simular uma corretora.
  Custos entram quando houver simulação de carteira (Fase 7).

## Dimensionamento de carteira: fonte única no domínio

A política de alocação (corte de assertividade por perfil, risco fixo por
trade, teto por ativo, teto global, teto por classe, caixa e limite de
alavancagem) vive **apenas** em `quant_engine/PortfolioSizer`
(`PerfilRisco` é o Value Object da política). O pipeline publica as
carteiras prontas no `dashboard.json` (`horizontes.*.carteiras.{perfil}.
{etoro|todos}` → pesos, alavancagem, caixa, segurados) e os clientes
(painel web e app Flutter) **apenas exibem** — multiplicam peso × capital
e formatam. Antes essa regra estava triplicada em `publish.dart`,
`app.js` e `data.dart`; a duplicação foi eliminada em 13/07/2026.

## Regras para novos indicadores

Todo candidato responde ao teste: *"se eu desligar a internet por um mês,
esse dado continuará existindo oficialmente?"* Além disso: fonte pública e
gratuita, série longa (>10 anos de preferência), atualização automática
possível, zero interpretação humana.
