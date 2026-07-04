import 'dart:math' as math;

import 'performance.dart';

/// Intervalo de confiança para o Sharpe anualizado via bootstrap de blocos
/// móveis (preserva a autocorrelação de curto prazo dos retornos, que o
/// bootstrap i.i.d. destruiria).
///
/// Determinístico para um mesmo [seed] — resultados reproduzíveis fazem
/// parte da metodologia do laboratório.
({double point, double lower, double upper}) sharpeBlockBootstrapCI(
  List<double> returns,
  int periodsPerYear, {
  int blockLen = 21,
  int iterations = 500,
  double confidence = 0.90,
  int seed = 20260704,
}) {
  final point = sharpe(returns, periodsPerYear);
  final n = returns.length;
  if (n < blockLen * 3 || point.isNaN) {
    return (point: point, lower: double.nan, upper: double.nan);
  }

  final rng = math.Random(seed);
  final sims = <double>[];
  for (var it = 0; it < iterations; it++) {
    final sample = <double>[];
    while (sample.length < n) {
      final start = rng.nextInt(n - blockLen + 1);
      sample.addAll(returns.sublist(start, start + blockLen));
    }
    final s = sharpe(sample.sublist(0, n), periodsPerYear);
    if (!s.isNaN) sims.add(s);
  }
  if (sims.length < iterations ~/ 2) {
    return (point: point, lower: double.nan, upper: double.nan);
  }
  sims.sort();
  final alpha = (1 - confidence) / 2;
  return (
    point: point,
    lower: _percentile(sims, alpha),
    upper: _percentile(sims, 1 - alpha),
  );
}

/// Percentil com interpolação linear em lista JÁ ordenada.
double _percentile(List<double> sorted, double p) {
  if (sorted.isEmpty) return double.nan;
  final pos = p * (sorted.length - 1);
  final lo = pos.floor();
  final hi = pos.ceil();
  if (lo == hi) return sorted[lo];
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo);
}
