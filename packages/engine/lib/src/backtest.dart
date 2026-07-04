import 'package:quant_core/quant_core.dart';
// prefixado: os campos `cagr`/`sharpe` das métricas colidem com as funções
import 'package:quant_stats/quant_stats.dart' as st;

/// Estratégias mensuráveis do laboratório — uma por "estilo" de sinal.
/// Cada horizonte de oportunidade usa o edge da estratégia compatível.
enum StrategyKind {
  tendencia('Tendência (SMA-200)'),
  momentum('Momentum 12-1'),
  reversao('Reversão à média (z-60)');

  const StrategyKind(this.label);
  final String label;
}

/// Métricas de um trecho de backtest.
class BacktestMetrics {
  const BacktestMetrics({
    required this.totalReturn,
    required this.cagr,
    required this.volAnn,
    required this.sharpe,
    required this.maxDd,
    required this.years,
  });

  final double totalReturn;
  final double cagr;
  final double volAnn;
  final double sharpe;
  final double maxDd;
  final double years;

  static BacktestMetrics fromReturns(
      List<double> returns, double years) {
    var equity = 1.0;
    final curve = <double>[1.0];
    for (final r in returns) {
      equity *= 1 + r;
      curve.add(equity);
    }
    final total = equity - 1;
    return BacktestMetrics(
      totalReturn: total,
      cagr: years > 0 ? st.cagr(total, years) : double.nan,
      volAnn: st.annualizedVol(returns, 252),
      sharpe: st.sharpe(returns, 252),
      maxDd: st.maxDrawdown(curve),
      years: years,
    );
  }
}

/// Resultado do backtest de uma estratégia.
///
/// Honestidade metodológica: fora do mercado rende 0 (não aplica caixa em
/// CDI), sem custos de transação — o objetivo é medir se o SINAL tem poder
/// preditivo no ativo, não simular uma corretora.
class BacktestResult {
  const BacktestResult({
    required this.assetId,
    required this.kind,
    required this.estrategia,
    required this.buyHold,
    required this.estrategiaOos,
    required this.buyHoldOos,
    required this.trocasDePosicao,
    required this.segmentos,
  });

  final String assetId;
  final StrategyKind kind;
  final BacktestMetrics estrategia;
  final BacktestMetrics buyHold;

  /// Últimos 30% da amostra, avaliados separadamente: o sinal precisa
  /// sobreviver fora do período em que "sempre funcionou".
  final BacktestMetrics estrategiaOos;
  final BacktestMetrics buyHoldOos;
  final int trocasDePosicao;

  /// Walk-forward: a estratégia avaliada em 3 janelas contíguas e
  /// independentes do histórico — um sinal robusto funciona na maioria
  /// delas, não só no agregado.
  final List<BacktestMetrics> segmentos;

  int get segmentosPositivos =>
      segmentos.where((s) => !s.sharpe.isNaN && s.sharpe > 0).length;

  /// A estratégia sobreviveu fora da amostra? (Sharpe positivo no trecho OOS)
  bool get sobreviveuForaDaAmostra =>
      !estrategiaOos.sharpe.isNaN && estrategiaOos.sharpe > 0;
}

/// Backtest genérico: posições +1 (comprado), 0 (fora) ou -1 (vendido),
/// SEMPRE decididas com dados até o fechamento de ontem e aplicadas ao
/// retorno de hoje (sem viés de antecipação).
BacktestResult? strategyBacktest(TimeSeries daily, StrategyKind kind) {
  final v = daily.values;
  final d = daily.dates;
  final built = _positions(kind, v);
  if (built == null) return null;
  final (positions, start) = built;

  final stratRets = <double>[];
  final bhRets = <double>[];
  var trocas = 0;
  double? prevPos;
  for (var i = start; i < v.length; i++) {
    if (v[i - 1] == 0) continue;
    final r = v[i] / v[i - 1] - 1;
    final pos = positions[i];
    stratRets.add(pos * r);
    bhRets.add(r);
    if (prevPos != null && pos != prevPos) trocas++;
    prevPos = pos;
  }
  if (stratRets.length < 60) return null;

  final years = d.last.difference(d[start]).inDays / 365.25;
  final cut = (stratRets.length * 0.7).floor();
  final oosYears = years * (stratRets.length - cut) / stratRets.length;

  final terco = stratRets.length ~/ 3;
  final segmentos = <BacktestMetrics>[
    for (var s = 0; s < 3; s++)
      BacktestMetrics.fromReturns(
        stratRets.sublist(
            s * terco, s == 2 ? stratRets.length : (s + 1) * terco),
        years / 3,
      ),
  ];

  return BacktestResult(
    assetId: daily.id,
    kind: kind,
    estrategia: BacktestMetrics.fromReturns(stratRets, years),
    buyHold: BacktestMetrics.fromReturns(bhRets, years),
    estrategiaOos:
        BacktestMetrics.fromReturns(stratRets.sublist(cut), oosYears),
    buyHoldOos: BacktestMetrics.fromReturns(bhRets.sublist(cut), oosYears),
    trocasDePosicao: trocas,
    segmentos: segmentos,
  );
}

/// Constrói o vetor de posições e o índice inicial válido de cada regra.
(List<double>, int)? _positions(StrategyKind kind, List<double> v) {
  final n = v.length;
  final p = List<double>.filled(n, 0);
  switch (kind) {
    case StrategyKind.tendencia:
      if (n < 260) return null;
      final smaSeries = st.sma(v, 200);
      for (var i = 200; i < n; i++) {
        final s = smaSeries[i - 1];
        p[i] = (s != null && v[i - 1] > s) ? 1 : 0;
      }
      return (p, 200);

    case StrategyKind.momentum:
      if (n < 320) return null;
      for (var i = 253; i < n; i++) {
        final j = i - 1;
        if (v[j - 252] > 0) {
          p[i] = v[j - 21] / v[j - 252] - 1 > 0 ? 1 : 0;
        }
      }
      return (p, 253);

    case StrategyKind.reversao:
      if (n < 320) return null;
      // Reversão A FAVOR da tendência primária: compra mergulhos (z < -1,5)
      // só acima da SMA-200 e vende repiques (z > +1,5) só abaixo dela;
      // zera ao cruzar a média (z = 0). Sem o filtro, a regra venderia
      // contra altas persistentes — numa tendência suave o preço fica
      // permanentemente ~1,7σ acima da média da própria janela.
      final smaSeries = st.sma(v, 200);
      var pos = 0.0;
      for (var i = 201; i < n; i++) {
        final j = i - 1; // decide com o fechamento de ontem
        final janela = v.sublist(j - 59, j + 1);
        final sd = st.sampleStd(janela);
        final z = sd == 0 ? 0.0 : (v[j] - st.mean(janela)) / sd;
        final s = smaSeries[j];
        if (pos == 0 && s != null) {
          if (z < -1.5 && v[j] > s) {
            pos = 1;
          } else if (z > 1.5 && v[j] < s) {
            pos = -1;
          }
        } else if (pos == 1 && z >= 0) {
          pos = 0;
        } else if (pos == -1 && z <= 0) {
          pos = 0;
        }
        p[i] = pos;
      }
      return (p, 201);
  }
}

/// Atalho para a estratégia clássica de tendência.
BacktestResult? trendBacktest(TimeSeries daily) =>
    strategyBacktest(daily, StrategyKind.tendencia);

/// As três estratégias de um ativo, com o mapeamento estratégia ↔ horizonte
/// usado pelo motor de oportunidades (o μ da alavancagem e o freio de
/// robustez vêm da estratégia compatível com o horizonte, não sempre da
/// tendência).
class BacktestPack {
  const BacktestPack({this.tendencia, this.momentum, this.reversao});

  final BacktestResult? tendencia;
  final BacktestResult? momentum;
  final BacktestResult? reversao;

  factory BacktestPack.fromDaily(TimeSeries daily) => BacktestPack(
        tendencia: strategyBacktest(daily, StrategyKind.tendencia),
        momentum: strategyBacktest(daily, StrategyKind.momentum),
        reversao: strategyBacktest(daily, StrategyKind.reversao),
      );

  BacktestResult? porHorizonte(Horizon h) => switch (h) {
        Horizon.curto => reversao ?? tendencia,
        Horizon.medio => momentum ?? tendencia,
        Horizon.longo => tendencia,
      };

  List<BacktestResult> get todos =>
      [tendencia, momentum, reversao].nonNulls.toList();
}
