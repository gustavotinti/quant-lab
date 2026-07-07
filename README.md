# QuantLab — Laboratório de Descoberta Econômica

Motor de análise de investimentos construído sobre uma regra única:

> **Toda hipótese deve ser derivada exclusivamente de dados objetivos,
> públicos e historicamente verificáveis.** Nada de notícias, opiniões,
> influenciadores ou "especialistas". Se a internet cair por um mês e o
> dado deixar de existir oficialmente, ele não entra no sistema.

O sistema nunca "adivinha". Ele **mede, testa hipóteses e calcula
probabilidades** baseadas em evidência histórica — e nenhum resultado chega
ao usuário sem antes **tentar ser destruído** (validação fora da amostra).

## O que já funciona (v0.2)

- **40 indicadores oficiais** baixados de fontes públicas e gratuitas, sem
  chave de API: Banco Central do Brasil (Selic, CDI, IPCA, IGP-M, INPC,
  PTAX, desemprego, IBC-Br, reservas, base monetária, M2, IC-Br) e bolsas
  via Yahoo Finance — índices (S&P 500, Nasdaq, Dow Jones, Ibovespa, DAX,
  FTSE, CAC, Euro Stoxx 50, Nikkei), metais (ouro, prata, cobre, platina,
  paládio), energia/grãos (petróleo, gás, milho, soja), cripto (BTC, ETH,
  XRP, SOL, ADA), FX majors (EUR/USD, GBP/USD, USD/JPY), DXY e Treasury
  10a — priorizando ativos **negociáveis no eToro**.
- **Regime macro** calculado só com aritmética: direção da Selic, IPCA 12m
  vs 3m anualizado, juro real, dólar global.
- **Oportunidades por horizonte** (curto/médio/longo) com direção
  (compra/venda/neutro), convicção 0–100 e **evidências numéricas
  explícitas** para cada nota — cenários análogos e **confluência de
  sinais** dentro do score.
- **Ranking acionável** (`lab recommend` e topo do dashboard): o que
  COMPRAR ou VENDER (short) agora, com **assertividade %** (eficácia
  direcional + cenários análogos, com suavização estatística),
  **retorno esperado** (mediana dos análogos — o ranking ordena por ele),
  payoff, stop estimado, gatilho de saída e **ticker do eToro**. Sinais
  abaixo do corte do perfil são segurados.
- **Dimensionamento de posição**: informe seu capital no dashboard e cada
  ordem vira **R$ X com risco fixo por trade** (0,5%/1%/2% conforme o
  perfil), com **preços de Stop Loss e alvo**, teto de concentração por
  classe de ativo, filtro "🎯 só eToro" e o % em caixa.
- **Consultor IA com plano de execução literal**: "Abra o eToro e busque
  NSDQ100 → COMPRAR → valor R$ 451 → alavancagem X1 → Stop Loss em
  23.479 → Take Profit em 30.354 → confirme", seguido da rotina de
  acompanhamento e do Plano B se o mercado virar — sempre com os valores
  calculados pelo laboratório.
- **`lab go`**: rotina diária completa em um comando (atualiza dados →
  recalcula tudo → publica o site).
- **Alavancagem máxima sugerida** por dois freios independentes
  (meio-Kelly e alvo de volatilidade de 15% a.a., teto 3x) — o menor vence.
- **Backtest de tendência** (SMA-200) por ativo com validação nos 30%
  finais da amostra (out-of-sample).
- **Laboratório de hipóteses**: cruza todos os pares de indicadores com
  defasagens de 1–6 meses (Spearman + significância t), aplica correção de
  **Benjamini-Hochberg** sobre o universo inteiro de testes (controle de
  falsos positivos), treina em 70% do histórico e só guarda o que sobrevive
  nos 30% restantes.
- **Incerteza quantificada**: IC 90% do Sharpe via bootstrap de blocos
  móveis; **walk-forward em 3 janelas** independentes no backtest.
- **3 estratégias medidas por ativo** (tendência SMA-200, momentum 12-1,
  reversão z-60 com filtro de tendência) — cada horizonte usa o edge da
  estratégia compatível.
- **Cenários análogos** (`lab scenarios <id>`): quantas vezes o ativo já
  esteve numa situação parecida com hoje e a distribuição do que aconteceu
  nos 3/12 meses seguintes (mediana, quartis, % positivos).
- **Relatório diário em markdown** com tudo acima.
- **Consultor IA (Gemini, grátis)** no dashboard: escolha **nível de
  risco** (conservador/moderado/agressivo) e **tempo de retorno**
  (≤3m / 3–18m / 18m+) em botões e o Gemini gera alocação sugerida em %
  (com ticker eToro e caixa/renda fixa), o que evitar e gatilhos de
  saída — usando SOMENTE os números do painel (proibido inventar dados).
- **Dashboard web** (https://quantlab-lde.web.app): login Google,
  oportunidades LONG e SHORT por horizonte com **% de eficácia histórica**
  (trades da estratégia + cenários análogos a favor), anel de convicção,
  alavancagem sugerida e hipóteses vivas — responsivo e atualizado via
  `lab publish`. **Sparkline de 1 ano em cada card**, **raio-X por ativo**
  (modal com gráfico de 3 anos + SMA-200, backtest completo, cenários
  3m/12m, deep link `#a=<id>`), resumo do dia, guia "como ler" e **PWA
  instalável com modo offline** (service worker).

## Quickstart

```bash
# da raiz do repositório (Dart SDK ≥ 3.11; no Windows: C:\flutter\bin\dart.bat)
dart pub get
dart run lab_cli:lab update           # baixa/atualiza as 20 séries
dart run lab_cli:lab macro            # regime macroeconômico
dart run lab_cli:lab recommend        # RANKING ACIONÁVEL c/ assertividade %
dart run lab_cli:lab opportunities    # oportunidades nos 3 horizontes
dart run lab_cli:lab hypotheses discover
dart run lab_cli:lab report           # gera reports/relatorio_AAAA-MM-DD.md
dart run lab_cli:lab analyze ibovespa # raio-X de um ativo
dart run lab_cli:lab scenarios bitcoin # cenários análogos históricos
```

Testes: `dart test` dentro de `packages/stats` e `packages/engine`.

## Estrutura (monorepo, pub workspace)

```
packages/
  core/          Domínio puro: TimeSeries, Indicator, portas, Result.
                 Não conhece Flutter, Firebase, HTTP — nada.
  stats/         Matemática: correlação (Pearson/Spearman + p-valor),
                 regressão OLS, drawdown, Sharpe/Sortino, médias móveis.
                 Cada fórmula existe em UM lugar, testada.
  market_data/   Infraestrutura: adaptadores BCB SGS e Yahoo, catálogo,
                 persistência em arquivo (amanhã: Firestore, sem tocar
                 no domínio).
  engine/        Sinais por ativo, regime macro, backtest, oportunidades,
                 alavancagem, laboratório de hipóteses.
apps/
  lab_cli/       CLI — primeira interface. O Flutter será só mais um
                 cliente do mesmo domínio.
docs/            Arquitetura, metodologia e roadmap.
```

## Stack

- **Dart puro** no núcleo (pronto) · **Firebase** projeto `quantlab-lde`
  com Hosting no ar (**https://quantlab-lde.web.app**) e Firestore criado
  (docs/FIREBASE.md) · **GitHub** `gustavotinti/quant-lab` (privado).
- Próximos: Functions com cron diário (precisa Blaze), Flutter
  mobile/web como cliente, Auth Google.

## Aviso legal

Este software produz estatísticas derivadas de dados públicos. **Não é
recomendação de investimento.** Rentabilidade passada não garante
resultado futuro. Alavancagem pode gerar perdas superiores ao capital
investido. Uso pessoal e por conta e risco do usuário.
