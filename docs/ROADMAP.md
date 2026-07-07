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
- ✅ Estratégias adicionais no backtest: momentum 12-1 e reversão z-60 com
  filtro de tendência (cada horizonte usa o edge da estratégia compatível).
- ⬜ Benchmark de performance por módulo (ex.: lag analysis de 100k pontos
  < 250 ms).
- ⬜ Estratégia de carry (juro real) cross-asset.

## 🔄 Fase 2 — Mais tabela periódica (parcial)

- ✅ +6 indicadores validados (04/07/2026): INPC (188), base monetária
  (1788), M2 (27810), IC-Br (27574), cobre (HG=F), Ethereum (ETH-USD).
- ✅ +2 índices globais (04/07/2026): DAX (^GDAXI) e Nikkei 225 (^N225) —
  total 28.
- ⬜ FRED (Fed St. Louis): CPI/PIB/desemprego EUA, M2, curva de juros
  (precisa de chave gratuita).
- ⬜ World Bank/FMI: PIB e demografia por país.
- ⬜ Clima (INMET/NOAA): temperatura, precipitação, El Niño/La Niña (ONI).
- Meta: 50–100 variáveis fundamentais, todas nível A/B.

## 🔄 Fase 3 — Firebase (espelho, não dono) — parcial

- ✅ Projeto `quantlab-lde` criado (04/07/2026), separado do Desafio Pago.
- ✅ Hosting no ar: https://quantlab-lde.web.app (landing + relatório do
  dia em /relatorio.txt).
- ✅ Firestore `(default)` criado com regras fechadas; app Web registrado
  (config em docs/FIREBASE.md).
- ✅ Dashboard web moderno (04/07/2026): SPA responsiva com login Google,
  oportunidades LONG/SHORT por horizonte, % de eficácia (trades + cenários
  análogos), anel de convicção, alavancagem e hipóteses. Publicação via
  `lab publish` + deploy do Hosting.
- ✅ Dashboard v2 (04/07/2026): sparkline por card, modal raio-X (gráfico
  3 anos + SMA-200, backtest, cenários 3m/12m, deep link `#a=<id>`),
  resumo do dia, guia "como ler", **PWA** (manifest + service worker
  network-first + ícones) e payload deduplicado (490→190 KB).
- ⬜ Ativar provedor Google no console (1 min, manual — docs/FIREBASE.md).
- ⬜ Plano Blaze (cartão no console — ação manual) para liberar Functions.
- ⬜ Cloud Function agendada (cron diário): roda update + engines e grava
  resultados no Firestore (`indicators`, `opportunities`, `hypotheses`) e
  publica o relatório no Hosting.
- ⬜ Auth Google + espelho público com regras.
- O arquivo local continua funcionando — Firestore é só mais um
  `SeriesRepository`.

## Fase 4 — App Flutter

- Login Google, dashboard "hoje encontrei N oportunidades", tela de
  indicadores, detalhe do ativo (sinais + backtest), banco de hipóteses.
- Flutter **não conhece regra de negócio**: consome os mesmos pacotes
  Dart e/ou o Firestore preenchido pela Fase 3.

## 🔄 Fase 5 — Simulador de cenários (parcial)

- ✅ Cenários análogos v1 (04/07/2026): `lab scenarios <id>` acha episódios
  históricos parecidos com hoje (momentum/SMA-200/z-60 normalizados) e
  mostra a distribuição dos retornos 3m/12m seguintes; também entra no
  relatório para os destaques do médio prazo.
- ⬜ "Se Selic subir 0,75% e petróleo cair 10%": cenários definidos pelo
  usuário sobre variáveis macro (não só o estado atual do ativo).

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

## 🔄 Fase 6b — Uso pessoal / execução (parcial, 06/07/2026)

- ✅ Ranking acionável com assertividade % (winRate direcional + cenários
  análogos, Laplace k=10), política de emissão ≥55%, gatilhos de saída e
  mapa de tickers do eToro (`lab recommend` + topo do dashboard).
- ✅ Score com cenários análogos + confluência de sinais.
- ✅ Consultor IA (06/07/2026): Gemini 2.5 Flash (Developer API, free
  tier, chave restrita por domínio) integrado ao dashboard — seletores
  responsivos de risco e horizonte, resposta baseada só nos dados do
  painel (alocação %, o que evitar, gatilhos).
- ⬜ Integração com a API pública do eToro (portfólio/posições): requer as
  chaves do Gustavo (eToro → Settings → API; conta verificada).
- ⬜ Tracking de acerto das recomendações emitidas (curva de assertividade
  real do sistema ao longo do tempo).

## Regra permanente

Nenhuma fase adiciona: notícias, opiniões, chatbots, recomendações de
compra automatizadas ou dados que não passem no teste "a internet caiu por
um mês e o dado continua existindo oficialmente?".
