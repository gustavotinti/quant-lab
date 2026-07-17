# QuantLab — Economic Discovery Engine

An investment-research engine built in **pure Dart** on a single rule:

> Every hypothesis must be derived **only** from objective, public, and
> historically verifiable data. No news, opinions, influencers, or "experts."
> If the internet went dark for a month and the datapoint stopped being
> published officially, it doesn't enter the system.

The engine never "guesses." It **measures, tests hypotheses, and computes
probabilities** from historical evidence — and no result reaches the user
before the system **tries to destroy it** through out-of-sample validation.

🌐 **Live dashboard:** https://quantlab-lde.web.app

---

## Highlights

- **Fully automated, zero-cost cloud pipeline** — GitHub Actions runs
  `update → publish → deploy` every 2 hours; the dashboard is a PWA that
  refreshes itself in the browser. No always-on server, no paid infra.
- **55 official indicators**, no API keys required: Brazil Central Bank
  (Selic, CDI, IPCA, IGP-M, PTAX, unemployment, reserves, monetary base…)
  and global markets via Yahoo Finance — equity indices, metals,
  energy/grains, crypto, FX majors, DXY, and the US 10y Treasury.
- **Statistically honest by design** — hypotheses are mined across every
  indicator pair with 1–6 month lags (Spearman + t-significance), then
  filtered with a **Benjamini-Hochberg** false-discovery-rate correction
  over the entire test universe, trained on 70% of history and kept only
  if they survive the remaining 30%.
- **Quantified uncertainty** — 90% confidence intervals for the Sharpe
  ratio via moving-block bootstrap; **walk-forward validation across 3
  independent windows** in every backtest.
- **Actionable ranking** — what to buy or short now, with historical
  directional accuracy, expected return (median of analog scenarios),
  estimated stop, exit trigger, and position sizing at a fixed risk per
  trade. Predictive leverage (half-Kelly ∧ 15%-vol target, capped) only
  when out-of-sample evidence authorizes it.
- **AI advisor (Gemini)** on the dashboard, constrained to use **only**
  the numbers the engine computed — it is forbidden from inventing data.

## Architecture — monorepo (Dart pub workspace)

```
packages/
  core/         Pure domain: TimeSeries, Indicator, ports, Result.
                Knows nothing about Flutter, Firebase, or HTTP.
  stats/        Math, each formula in ONE tested place: correlation
                (Pearson/Spearman + p-value), OLS, drawdown, Sharpe/Sortino.
  market_data/  Infrastructure: BCB SGS + Yahoo adapters, catalog,
                persistence — swappable without touching the domain.
  engine/       Signals, macro regime, backtest, opportunities, leverage,
                and the hypothesis laboratory.
apps/
  lab_cli/      CLI — the first client of the domain; the web/mobile UI
                is just another client of the same core.
```

The dependency rule points inward: `core` has no outward dependencies, and
infrastructure adapters implement ports defined in the domain (hexagonal /
clean architecture). Every statistical formula lives in exactly one place
and is unit-tested.

## Quickstart

```bash
# Dart SDK >= 3.11
dart pub get
dart run lab_cli:lab update        # fetch/update the official series
dart run lab_cli:lab macro         # macroeconomic regime
dart run lab_cli:lab recommend     # actionable ranking with accuracy %
dart run lab_cli:lab opportunities # opportunities across 3 horizons
dart run lab_cli:lab hypotheses discover
dart run lab_cli:lab analyze ibovespa   # per-asset deep dive
dart run lab_cli:lab scenarios bitcoin  # historical analog scenarios

# tests
dart test  # inside packages/stats and packages/engine
```

## Stack

Pure-Dart core · Firebase Hosting + Firestore (`quantlab-lde`) · GitHub
Actions (scheduled pipeline) · Gemini API (advisor) · installable PWA with
offline service worker.

## Disclaimer

This software produces statistics derived from public data. **It is not
investment advice.** Past performance does not guarantee future results.
Leverage can produce losses exceeding invested capital. Personal use, at
the user's own risk.
