# Roadmap

## ✅ Fase 0 — Motor matemático (concluída em 04/07/2026)

Monorepo Dart (pub workspace) com DDD/Clean Architecture:

- `quant_core` (domínio puro), `quant_stats` (31 testes de matemática),
  `quant_market_data` (BCB SGS + Yahoo + persistência em arquivo),
  `quant_engine` (sinais, macro, backtest OOS, oportunidades, alavancagem,
  hipóteses), `lab_cli` (7 comandos).
- 20 indicadores oficiais, até 26 anos de histórico, sem chave de API.
- Pipeline validado com dados reais: o minerador redescobriu sozinho a
  relação Selic↔CDI e destruiu correlações espúrias de ruído sintético.

## 🔄 Fase 1 — Robustez estatística (parcial em 04/07/2026)

- ✅ Correção de Benjamini-Hochberg no minerador (FDR ≤ 5% sobre TODOS os
  testes — na prática eliminou a relação espúria Bitcoin→Gás natural que o
  funil simples deixava passar).
- ✅ Bootstrap de blocos móveis para IC 90% do Sharpe (exibido no
  `lab analyze`).
- ✅ Walk-forward em 3 janelas no backtest de tendência.
- ⬜ Benchmark de performance por módulo (ex.: lag analysis de 100k pontos
  < 250 ms).
- ⬜ Estratégias adicionais no backtest: momentum 12-1 cross-asset,
  reversão z-score, carry (juro real).

## 🔄 Fase 2 — Mais tabela periódica (parcial)

- ✅ +6 indicadores validados (04/07/2026): INPC (188), base monetária
  (1788), M2 (27810), IC-Br (27574), cobre (HG=F), Ethereum (ETH-USD) —
  total 26.
- ⬜ FRED (Fed St. Louis): CPI/PIB/desemprego EUA, M2, curva de juros
  (precisa de chave gratuita).
- ⬜ World Bank/FMI: PIB e demografia por país.
- ⬜ Clima (INMET/NOAA): temperatura, precipitação, El Niño/La Niña (ONI).
- Meta: 50–100 variáveis fundamentais, todas nível A/B.

## Fase 3 — Firebase (espelho, não dono)

- Cloud Function agendada (cron diário): roda update + engines e grava
  resultados no Firestore (`indicators`, `historical_data`, `opportunities`,
  `hypotheses`, `reports`).
- Auth Google + regras de segurança.
- O arquivo local continua funcionando — Firestore é só mais um
  `SeriesRepository`.

## Fase 4 — App Flutter

- Login Google, dashboard "hoje encontrei N oportunidades", tela de
  indicadores, detalhe do ativo (sinais + backtest), banco de hipóteses.
- Flutter **não conhece regra de negócio**: consome os mesmos pacotes
  Dart e/ou o Firestore preenchido pela Fase 3.

## Fase 5 — Simulador de cenários

- "Se Selic subir 0,75% e petróleo cair 10%": busca histórica de cenários
  análogos + distribuição do que aconteceu depois (n, mediana, quartis).

## Fase 6 — Descoberta científica noturna

- Rotina automática (Claude Code / Function): gerar novas hipóteses,
  re-testar as existentes contra dados novos, rebaixar/aposentar as que
  falharem, produzir relatório da madrugada.
- Banco de conhecimento versionado (cada hipótese com histórico de
  validações e falhas).

## Fase 7 — Carteira e risco

- Simulação de carteira multi-ativo com custos, rebalanceamento e
  correlações; VaR/CVaR; stress tests; dimensionamento por risco total
  (não por ativo isolado).

## Regra permanente

Nenhuma fase adiciona: notícias, opiniões, chatbots, recomendações de
compra automatizadas ou dados que não passem no teste "a internet caiu por
um mês e o dado continua existindo oficialmente?".
