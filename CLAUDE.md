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
- Firebase: projeto `quantlab-lde` (SEPARADO do desafio-app-b8665).
  Hosting no ar: https://quantlab-lde.web.app — dashboard SPA (public/:
  index.html + styles.css + app.js + sw.js/manifest = PWA) com login
  Google (provedor precisa ser ativado no console — docs/FIREBASE.md),
  LONG/SHORT + % eficácia, sparklines, modal raio-X (deep link #a=id).
  Ícones: public/icons (regenerar 192px: `dart run
  apps/lab_cli/tool/make_icons.dart` após recapturar o 512 do SVG).
- IA = "Oráculo": Gemini 2.5 Flash via generativelanguage (REST direto no
  app.js; free tier; chave restrita a domínio+serviço — detalhes e
  rotação em docs/FIREBASE.md). SDK firebase no CDN: v12.4.0. TRÊS
  systems: plano (AI_SYSTEM), posições (ORACULO_POS_SYSTEM) e mentor
  chat (ORACULO_MENTOR_SYSTEM — multi-turn: contents = contexto fresco +
  chatHist máx 12 + pergunta; contextoMentor() injeta ordens/radar/
  posições/seleção). Chat: fab + #chat-panel; atalhos data-mentor
  (modal) e data-mentor-pos (Copiloto).
- Design v3 (11/07/2026): SEM emojis — ícones SVG no mapa ICONS/icon()
  do app.js (+ inline nos títulos do index.html). Acordeões
  (details/summary) no ranking/radar/posições; seções "Todos os ativos"
  e "Hipóteses" dobradas (.sec-fold). Estado global único: horizonte
  (abas) + riscoSel + capital + soEtoro alimentam ranking, sizing E
  Oráculo (sincronizarOraculo() marca plano desatualizado ao mudar). Dois
  systems: plano de execução (AI_SYSTEM) e veredito de posições
  (ORACULO_POS_SYSTEM). Copiloto: posições em localStorage (ql_pos/
  ql_hist); alavancagem preditiva X1/X2/X5 em recomendacao.
  alavancagemRecomendada (publish.dart; margem = exposição ÷ X).
  Fluxo de publicação: `lab update` → `lab publish` (gera
  public/data/dashboard.json + relatorio.txt) → `firebase deploy --only
  hosting -P quantlab-lde`. Firestore (default) criado c/ regras
  fechadas. Functions pendem de Blaze (ação manual).
- Futuro: Flutter (cliente) + Auth Google. Ver docs/ROADMAP.md.

## Estrutura
- `packages/core` — domínio puro (TimeSeries, Indicator, portas, Result)
- `packages/stats` — matemática (correlação+p-valor, OLS, Sharpe, DD...)
- `packages/market_data` — adaptadores BCB SGS (janelas de 5 anos!) e
  Yahoo (precisa de User-Agent), catálogo de 20 indicadores validados,
  FileSeriesStore em `data/series/`
- `packages/engine` — AssetSignals, MacroRegime, strategyBacktest (3
  estratégias: tendência/momentum/reversão c/ filtro de tendência;
  BacktestPack mapeia estratégia↔horizonte), OpportunityEngine (tanh +
  pesos, ver docs/METODOLOGIA.md), leverageAdvice (meio-Kelly ∧ vol-target
  15%, teto 3x), HypothesisLab (c/ Benjamini-Hochberg), analogousScenarios
- `apps/lab_cli` — comandos: update, list, macro, analyze, opportunities,
  recommend (ranking acionável ordenado por retorno esperado; corte de
  emissão 55%; ticker eToro; payoff/stop), radar (📡 picos:
  engine/radar.dart — kNN 16 análogos sobre estado técnico de 7 medidas
  → prob de virada em 21d), scenarios, hypotheses
  discover|list, report, publish, **go** (update+publish+deploy — rotina
  diária de 1 comando).
  Mapa eToro em lib/src/etoro.dart (apresentação — domínio não conhece
  corretora). eToro tem API pública oficial (api-portal.etoro.com; chave
  em Settings→API com conta verificada) — integração pendente das chaves.

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
- Yahoo chart API: ^GSPC ^IXIC ^DJI ^BVSP ^GDAXI ^FTSE ^FCHI ^STOXX50E
  ^N225 GC=F SI=F HG=F PL=F PA=F CL=F NG=F ZC=F ZS=F BTC-USD ETH-USD
  XRP-USD SOL-USD ADA-USD EURUSD=X GBPUSD=X JPY=X DX-Y.NYB ^TNX
  (User-Agent obrigatório) — total 40 indicadores, priorizando eToro

## Git
- origin: https://github.com/gustavotinti/quant-lab (privado, branch master)
- Sem gh CLI — GitHub via API REST com token do `git credential fill`
