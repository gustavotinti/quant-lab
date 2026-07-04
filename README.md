# QuantLab — Laboratório de Descoberta Econômica

Motor de análise de investimentos construído sobre uma regra única:

> **Toda hipótese deve ser derivada exclusivamente de dados objetivos,
> públicos e historicamente verificáveis.** Nada de notícias, opiniões,
> influenciadores ou "especialistas". Se a internet cair por um mês e o
> dado deixar de existir oficialmente, ele não entra no sistema.

O sistema nunca "adivinha". Ele **mede, testa hipóteses e calcula
probabilidades** baseadas em evidência histórica — e nenhum resultado chega
ao usuário sem antes **tentar ser destruído** (validação fora da amostra).

## O que já funciona (v0.1)

- **20 indicadores oficiais** baixados de fontes públicas e gratuitas, sem
  chave de API: Banco Central do Brasil (Selic, CDI, IPCA, IGP-M, PTAX,
  desemprego, IBC-Br, reservas) e bolsas via Yahoo Finance (S&P 500,
  Nasdaq, Ibovespa, ouro, prata, petróleo, gás, milho, soja, Bitcoin, DXY,
  Treasury 10a) — até 26 anos de histórico por série.
- **Regime macro** calculado só com aritmética: direção da Selic, IPCA 12m
  vs 3m anualizado, juro real, dólar global.
- **Oportunidades por horizonte** (curto/médio/longo) com direção
  (compra/venda/neutro), convicção 0–100 e **evidências numéricas
  explícitas** para cada nota.
- **Alavancagem máxima sugerida** por dois freios independentes
  (meio-Kelly e alvo de volatilidade de 15% a.a., teto 3x) — o menor vence.
- **Backtest de tendência** (SMA-200) por ativo com validação nos 30%
  finais da amostra (out-of-sample).
- **Laboratório de hipóteses**: cruza todos os pares de indicadores com
  defasagens de 1–6 meses (Spearman + significância t), treina em 70% do
  histórico e só guarda o que sobrevive nos 30% restantes.
- **Relatório diário em markdown** com tudo acima.

## Quickstart

```bash
# da raiz do repositório (Dart SDK ≥ 3.11; no Windows: C:\flutter\bin\dart.bat)
dart pub get
dart run lab_cli:lab update           # baixa/atualiza as 20 séries
dart run lab_cli:lab macro            # regime macroeconômico
dart run lab_cli:lab opportunities    # oportunidades nos 3 horizontes
dart run lab_cli:lab hypotheses discover
dart run lab_cli:lab report           # gera reports/relatorio_AAAA-MM-DD.md
dart run lab_cli:lab analyze ibovespa # raio-X de um ativo
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

## Stack planejada

- **Dart puro** no núcleo (já) → **Flutter** mobile/web como cliente (fase
  futura) → **Firebase** (Auth Google, Firestore, Functions com cron
  diário) → **GitHub** para versão e CI.

## Aviso legal

Este software produz estatísticas derivadas de dados públicos. **Não é
recomendação de investimento.** Rentabilidade passada não garante
resultado futuro. Alavancagem pode gerar perdas superiores ao capital
investido. Uso pessoal e por conta e risco do usuário.
