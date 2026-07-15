import 'dart:math' as math;

import 'special.dart';

/// Média aritmética. Lança [ArgumentError] em lista vazia.
double mean(List<double> xs) {
  if (xs.isEmpty) throw ArgumentError('mean: lista vazia');
  var s = 0.0;
  for (final x in xs) {
    s += x;
  }
  return s / xs.length;
}

/// Variância amostral (divisor n-1).
double sampleVariance(List<double> xs) {
  if (xs.length < 2) throw ArgumentError('sampleVariance: precisa de n >= 2');
  final m = mean(xs);
  var s = 0.0;
  for (final x in xs) {
    s += (x - m) * (x - m);
  }
  return s / (xs.length - 1);
}

/// Desvio padrão amostral.
double sampleStd(List<double> xs) => math.sqrt(sampleVariance(xs));

/// Z-score do último valor em relação à janela inteira:
/// quantos desvios padrão o valor atual está da média histórica da janela.
double zScoreLast(List<double> xs) {
  final sd = sampleStd(xs);
  if (sd == 0) return 0;
  return (xs.last - mean(xs)) / sd;
}

/// Teste t de uma amostra (H0: média = 0): estatística t e p-valor
/// bicaudal. Usado p/ perguntar "essa média é distinguível de zero?" —
/// ex.: retorno médio de um mês do calendário (sazonalidade).
({double t, double pValue}) meanTTest(List<double> xs) {
  if (xs.length < 4) return (t: double.nan, pValue: double.nan);
  final sd = sampleStd(xs);
  if (sd == 0) {
    final m = mean(xs);
    if (m == 0) return (t: 0, pValue: 1);
    return (t: m.sign * double.infinity, pValue: 0);
  }
  final t = mean(xs) / (sd / math.sqrt(xs.length));
  return (t: t, pValue: pValueTwoTailed(t, (xs.length - 1).toDouble()));
}

/// Quantil [p] ∈ [0, 1] com interpolação linear (ordena uma cópia).
double quantile(List<double> xs, double p) {
  if (xs.isEmpty) return double.nan;
  final sorted = [...xs]..sort();
  final pos = p.clamp(0.0, 1.0) * (sorted.length - 1);
  final lo = pos.floor();
  final hi = pos.ceil();
  if (lo == hi) return sorted[lo];
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo);
}
