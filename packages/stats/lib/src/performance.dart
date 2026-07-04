import 'dart:math' as math;

import 'descriptive.dart';

/// Índice de Sharpe anualizado a partir de retornos por período.
/// [rfPerPeriod] é a taxa livre de risco no MESMO período dos retornos.
double sharpe(List<double> returns, int periodsPerYear,
    {double rfPerPeriod = 0}) {
  if (returns.length < 2) return double.nan;
  final excess = returns.map((r) => r - rfPerPeriod).toList();
  final sd = sampleStd(excess);
  if (sd == 0) return double.nan;
  return mean(excess) / sd * math.sqrt(periodsPerYear);
}

/// Índice de Sortino anualizado (penaliza apenas volatilidade negativa).
double sortino(List<double> returns, int periodsPerYear,
    {double rfPerPeriod = 0}) {
  if (returns.length < 2) return double.nan;
  final excess = returns.map((r) => r - rfPerPeriod).toList();
  final downside = excess.where((r) => r < 0).toList();
  if (downside.length < 2) return double.nan;
  var s = 0.0;
  for (final r in downside) {
    s += r * r;
  }
  final downsideDev = math.sqrt(s / excess.length);
  if (downsideDev == 0) return double.nan;
  return mean(excess) / downsideDev * math.sqrt(periodsPerYear);
}

/// Calmar: retorno anualizado sobre o módulo do máximo drawdown.
double calmar(double cagr, double maxDrawdown) {
  if (maxDrawdown == 0) return double.nan;
  return cagr / maxDrawdown.abs();
}
