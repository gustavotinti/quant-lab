# Roadmap

## ✅ Motor de Track Record + Radar-emissor + correlação (14/07/2026)

- **Track record NO AR**: cada publish do pipeline registra as ordens do
  dia no Firestore (`track_record/{yyyy-MM-dd}`, idempotente por data), o
  `TrackRecordScorer` (domínio puro, testado) mede o retorno REALIZADO
  quando cada janela se cumpre (curto 3m; médio/longo 12m; radar 1m) e o
  dashboard ganhou o "Placar do sistema": hit-rate real, retorno médio,
  curva de capital e calibração previsto×realizado. Ciclo quant fechado:
  prever → emitir → MEDIR → afinar.
- **Radar de Picos virou EMISSOR** no curto prazo: quando as estratégias
  clássicas não têm sinal mas a probabilidade empírica de virada passa no
  corte de 55% com Laplace k=10 E a mediana dos análogos é favorável →
  ordem (janela 1m, SEMPRE X1, tag "radar" na UI). Era a lacuna do
  "fundo 81% mas AGUARDAR" apontada no Gás Natural.
- **Penalidade de correlação** no PortfolioSizer (construção de carteira
  das grandes gestoras — diversificação real, não nominal): posições
  correlacionadas na mesma direção dividem o peso por (1 + Σ corr⁺);
  long+short correlacionados = hedge, sem corte.

## ✅ Sazonalidade + preço ao vivo (14/07/2026, segunda leva)

- **Sazonalidade de calendário** (engine/seasonality.dart): retorno médio
  do PRÓXIMO mês com t-teste (meanTTest no quant_stats), validação 70/30,
  magnitude ≥0,8% e n≥10 anos → evidência do curto prazo no
  OpportunityEngine. Estreia real: soja agosto -2,7% em 20 anos (p=0,049)
  — ciclo de safra detectado; o resto do catálogo foi corretamente segurado.
- **Preço ao vivo no painel**: `lab rates` grava cotações eToro de todos os
  negociáveis em private/rates (34 ativos; resolve ticker→id paginando o
  catálogo — o `query` da busca é ignorado pela API; vírgulas de
  instrumentIds não podem ser %2C-codificadas). Front: listener em tempo
  real + CoinGecko 60s para as 10 criptos; stop/alvo recalculados no preço
  de agora com selo da fonte.

## ✅ Momentum cross-sectional + Oráculo com placar (15/07/2026)

- **Força relativa** (engine/cross_sectional.dart): ranking 12-1 ajustado
  por vol entre os ~43 ativos, com o fator RE-VALIDADO no nosso universo
  (backtest mensal do spread tercil forte−fraco, t-teste, 70/30 e piso de
  relevância econômica 0,3%/mês). Resultado HONESTO da estreia: spread
  +0,39%/mês em 227 meses mas p=0,46 → fator medido e NÃO validado num
  universo de só 43 ativos — nenhuma evidência emitida. Re-mede a cada
  publish; liga sozinho se firmar. Evidência (quando ativa) entra no
  MÉDIO prazo.
- **Oráculo conhece o placar real**: plano de execução e mentor recebem o
  track record medido (acerto real × previsto por horizonte) — a IA
  calibra expectativa pelo realizado e é instruída a nunca prometer mais.

## ▶ PRÓXIMO PASSO — mais edge mensurável (em ordem de valor)

1. **Carry** (juro real cross-asset): moedas/índices com carry positivo.
2. App v2 (login+portfólio eToro+Oráculo nativos+ícone — SHA-1 no Firebase
   + chave Gemini Android); FRED (chave grátis, cadastro do Gustavo).

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
- ✅ Automação na nuvem SEM Blaze (11/07/2026): GitHub Actions a cada 2h
  (update+publish+deploy c/ service account) + auto-refresh do painel a
  cada 5 min. Dados nunca mais dependem do PC.
- ⬜ Plano Blaze (opcional agora — só se quisermos Functions/Firestore).
- ⬜ Cloud Function agendada (cron diário): roda update + engines e grava
  resultados no Firestore (`indicators`, `opportunities`, `hypotheses`) e
  publica o relatório no Hosting.
- ⬜ Auth Google + espelho público com regras.
- O arquivo local continua funcionando — Firestore é só mais um
  `SeriesRepository`.

## 🔄 Fase 4 — App Flutter (v1 no ar em 12/07/2026)

- ✅ App Android nativo (`apps/mobile`): consome o mesmo `dashboard.json`
  da nuvem. Telas: seletor de horizonte + perfil de risco, faixa macro,
  ranking "o que fazer agora" (cards expansíveis), Radar de Picos com
  medidor, pull-to-refresh; tema dark idêntico ao web. `flutter analyze`
  limpo, verificado por build web + screenshot.
- ✅ APK release (44 MB) para download direto no celular:
  **https://quantlab-lde.web.app/QuantLab-v1.zip** (servido como
  `QuantLab.apk` via Content-Disposition — Hosting free proíbe `.apk`).
- ⬜ v2: login Google + portfólio real do eToro (precisa registrar o
  SHA-1 do app no Firebase) + Oráculo (chave Gemini restrita ao app
  Android) + ícone de app próprio.
- Flutter **não conhece regra de negócio**: o motor roda no pipeline; o
  app é cliente de apresentação (consome o JSON publicado).

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
- ✅ Catálogo eToro-first (07/07/2026): +12 ativos negociáveis (Dow,
  FTSE, CAC, Euro Stoxx, XRP, SOL, ADA, platina, paládio, EUR/USD,
  GBP/USD, USD/JPY) — 40 indicadores; filtro "só eToro" no ranking.
- ✅ Execução literal (07/07/2026): SL/alvo em preço no ranking; teto de
  concentração por classe; Consultor IA gera plano passo a passo
  numerado com os valores exatos calculados (R$, SL, TP, alavancagem),
  rotina pós-execução e Plano B.
- ✅ Copiloto (07/07/2026): journal de posições (✔ Executei / manual),
  monitor com veredito MANTER/ATENÇÃO/FECHAR (stop, alvo, sinal
  invertido), P&L com alavancagem, histórico com taxa de acerto real
  (início do tracking) e Oráculo por posição. Persistência: localStorage.
- ✅ Alavancagem preditiva (07/07/2026): degraus X1/X2/X5 condicionados a
  robustez OOS + assertividade + meio-Kelly + vol; IA renomeada Oráculo.
- ✅ 📡 Radar de Picos (10/07/2026): estado técnico de 7 medidas (RSI,
  z20, canal de regressão, squeeze, topo/fundo 52s, streak) + kNN de 16
  análogos → probabilidade de virada em 21 pregões; validado em onda
  sintética (>85% nas cristas/vales, mudo em ruído); UI com medidor,
  `lab radar` e integração no Oráculo (ordens e posições).
- ✅ Redesign profissional v3 (11/07/2026): zero emojis (ícones SVG
  temáticos), divulgação progressiva (ranking/radar/posições viram
  acordeões — detalhes só ao expandir; cards minimalistas; "todos os
  ativos" e hipóteses dobrados), controles unificados numa única barra
  (horizonte + perfil de risco global + capital + filtros) e Oráculo
  sincronizado com o estado da plataforma (segue as abas/perfil/capital
  e marca o plano como desatualizado quando a seleção muda).
- ✅ Mentor ao vivo (11/07/2026): chat flutuante do Oráculo com memória
  de conversa e contexto completo do painel (ordens dimensionadas, radar,
  posições com status, macro, seleção); persona professor+operador com
  "Ação:" e veredito por posição; atalhos no Raio-X e no Copiloto;
  honestidade de cotação (fechamento diário + conferir preço no eToro).
- ✅ Integração eToro (12/07/2026): API pública lê o portfólio real;
  pipeline sincroniza para `private/portfolio` no Firestore (privado, só
  o dono lê logado); Copiloto mostra "eToro · conta real" e o Oráculo
  orienta sobre as posições reais. Só-leitura; execução continua manual.
- ⬜ P&L/status ao vivo das posições eToro (falta o current rate da API).
- ⬜ Posições do Copiloto (manuais) no Firestore p/ sincronizar aparelhos.
- ✅ Retorno esperado + payoff por recomendação (07/07/2026): ranking
  ordena por retorno esperado; stop estimado por estratégia;
  dimensionamento de posição por risco fixo por trade com capital do
  usuário (dashboard) e caixa explícito; comando `lab go` (update +
  publish + deploy em um passo).
- ⬜ Tracking de acerto das recomendações emitidas (curva de assertividade
  real do sistema ao longo do tempo).
- ⬜ Automação diária sem PC ligado (GitHub Actions com service account
  ou Function no Blaze).

## Regra permanente

Nenhuma fase adiciona: notícias, opiniões, chatbots, recomendações de
compra automatizadas ou dados que não passem no teste "a internet caiu por
um mês e o dado continua existindo oficialmente?".
