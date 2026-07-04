import 'dart:math' as math;

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
