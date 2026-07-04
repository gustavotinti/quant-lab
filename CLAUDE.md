# QuantLab — Contexto do Projeto

## O que é
Laboratório de Descoberta Econômica: motor de análise de investimentos
100% baseado em dados objetivos, públicos e verificáveis (nunca notícias/
opiniões). Mede, testa hipóteses com validação fora da amostra e classifica
oportunidades por horizonte (curto/médio/longo) com sugestão de alavancagem.

## Regras de ouro (inegociáveis)
- Toda hipótese deriva só de dados oficiais (nível A: BCB/institutos;
  nível B: preços de bolsa). Nível C (interpretativo) NÃO existe no sistema.
- Nenhum resultado é mostrado sem tentar ser destruído (treino 70% /
  teste 30%; backtest reporta os 30% finais como OOS).
- Nenhuma fórmula estatística fora de `packages/stats` (um cálculo, um
  lugar, com teste de valor conhecido).
- Domínio não importa HTTP/Firebase/Flutter/arquivos — só as portas de
  `quant_core` (`SeriesRepository`, `MarketDataProvider`).
- Saídas de oportunidade SEMPRE com disclaimer (não é recomendação).

## Stack
- Dart 3.11 puro (pub workspace). Dart/Flutter em `C:\flutter\bin`
  (fora do PATH — usar `C:\flutter\bin\dart.bat`).
- Futuro: Flutter (cliente), Firebase (Auth Google/Firestore/Functions),
  GitHub. Ver docs/ROADMAP.md.

## Estrutura
- `packages/core` — domínio puro (TimeSeries, Indicator, portas, Result)
- `packages/stats` — matemática (correlação+p-valor, OLS, Sharpe, DD...)
- `packages/market_data` — adaptadores BCB SGS (janelas de 5 anos!) e
  Yahoo (precisa de User-Agent), catálogo de 20 indicadores validados,
  FileSeriesStore em `data/series/`
- `packages/engine` — AssetSignals, MacroRegime, trendBacktest (SMA-200),
  OpportunityEngine (tanh + pesos, ver docs/METODOLOGIA.md),
  leverageAdvice (meio-Kelly ∧ vol-target 15%, teto 3x), HypothesisLab
- `apps/lab_cli` — comandos: update, list, macro, analyze, opportunities,
  hypotheses discover|list, report

## Comandos (da raiz do repo)
- `C:\flutter\bin\dart.bat pub get`
- `C:\flutter\bin\dart.bat run lab_cli:lab <comando>`
- Testes: `dart test` em packages/stats e packages/engine
- `data/series/` e `reports/` estão no .gitignore (regeneráveis)

## Fontes de dados (validadas 2026-07, sem chave)
- BCB SGS: Selic 432, CDI 4389, IPCA 433, IGP-M 189, INPC 188, PTAX 1,
  desemprego 24369, IBC-Br 24363, reservas 3546, base monetária 1788,
  M2 27810, IC-Br 27574.
  `https://api.bcb.gov.br/dados/serie/bcdata.sgs.{cod}/dados?formato=json`
  (consultas longas falham — buscar em janelas de 5 anos)
- Yahoo chart API: ^GSPC ^IXIC ^BVSP GC=F SI=F HG=F CL=F NG=F ZC=F ZS=F
  BTC-USD ETH-USD DX-Y.NYB ^TNX (header User-Agent obrigatório)

## Git
- origin: https://github.com/gustavotinti/quant-lab (privado, branch master)
- Sem gh CLI — GitHub via API REST com token do `git credential fill`
