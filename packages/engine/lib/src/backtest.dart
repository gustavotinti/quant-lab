import 'package:quant_core/quant_core.dart';
// prefixado: os campos `cagr`/`sharpe` das métricas colidem com as funções
import 'package:quant_stats/quant_stats.dart' as st;

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

/// Resultado do backtest da estratégia de tendência (comprado quando o
/// preço fecha acima da SMA-200; fora do mercado caso contrário).
///
/// Honestidade metodológica: fora do mercado rende 0 (não aplica caixa em
/// CDI), sem custos de transação — o objetivo é medir se a TENDÊNCIA tem
/// poder preditivo no ativo, não simular uma corretora.
class BacktestResult {
  const BacktestResult({
    required this.assetId,
    required this.estrategia,
    required this.buyHold,
    required this.estrategiaOos,
    required this.buyHoldOos,
    required this.trocasDePosicao,
    required this.segmentos,
  });

  final String assetId;
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

BacktestResult? trendBacktest(TimeSeries daily, {int smaWindow = 200}) {
  final v = daily.values;
  final d = daily.dates;
  if (v.length < smaWindow + 60) return null;

  final smaSeries = st.sma(v, smaWindow);
  final stratRets = <double>[];
  final bhRets = <double>[];
  var trocas = 0;
  bool? prevPos;

  for (var i = smaWindow; i < v.length; i++) {
    final s = smaSeries[i - 1];
    if (s == null || v[i - 1] == 0) continue;
    final pos = v[i - 1] > s; // decide com dados de ontem, opera hoje
    final r = v[i] / v[i - 1] - 1;
    stratRets.add(pos ? r : 0);
    bhRets.add(r);
    if (prevPos != null && pos != prevPos) trocas++;
    prevPos = pos;
  }
  if (stratRets.length < 60) return null;

  final years =
      d.last.difference(d[smaWindow]).inDays / 365.25;
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
    estrategia: BacktestMetrics.fromReturns(stratRets, years),
    buyHold: BacktestMetrics.fromReturns(bhRets, years),
    estrategiaOos:
        BacktestMetrics.fromReturns(stratRets.sublist(cut), oosYears),
    buyHoldOos: BacktestMetrics.fromReturns(bhRets.sublist(cut), oosYears),
    trocasDePosicao: trocas,
    segmentos: segmentos,
  );
}
