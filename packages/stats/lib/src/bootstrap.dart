import 'dart:math' as math;

import 'descriptive.dart';
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
  final alpha = (1 - confidence) / 2;
  return (
    point: point,
    lower: quantile(sims, alpha),
    upper: quantile(sims, 1 - alpha),
  );
}
