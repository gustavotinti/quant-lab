import 'dart:math' as math;

import 'descriptive.dart';

/// Retornos simples entre observações consecutivas: r_i = p_i/p_{i-1} - 1.
List<double> simpleReturns(List<double> prices) {
  final out = <double>[];
  for (var i = 1; i < prices.length; i++) {
    if (prices[i - 1] != 0) out.add(prices[i] / prices[i - 1] - 1);
  }
  return out;
}

/// Retornos logarítmicos: ln(p_i / p_{i-1}). Ignora preços não positivos.
List<double> logReturns(List<double> prices) {
  final out = <double>[];
  for (var i = 1; i < prices.length; i++) {
    if (prices[i] > 0 && prices[i - 1] > 0) {
      out.add(math.log(prices[i] / prices[i - 1]));
    }
  }
  return out;
}

/// Retorno acumulado entre o primeiro e o último preço.
double cumulativeReturn(List<double> prices) {
  if (prices.length < 2 || prices.first == 0) return 0;
  return prices.last / prices.first - 1;
}

/// Retorno anualizado composto dado o retorno total e o número de anos.
double cagr(double totalReturn, double years) {
  if (years <= 0) throw ArgumentError('cagr: years deve ser > 0');
  final base = 1 + totalReturn;
  if (base <= 0) return -1;
  return math.pow(base, 1 / years).toDouble() - 1;
}

/// Volatilidade anualizada a partir de retornos por período:
/// desvio padrão amostral × √(períodos por ano).
double annualizedVol(List<double> returns, int periodsPerYear) {
  if (returns.length < 2) return double.nan;
  return sampleStd(returns) * math.sqrt(periodsPerYear);
}

/// Média de retorno anualizada (aritmética × períodos por ano).
double annualizedMeanReturn(List<double> returns, int periodsPerYear) {
  if (returns.isEmpty) return double.nan;
  return mean(returns) * periodsPerYear;
}

/// Composição de variações percentuais mensais (em %, ex.: IPCA 0.5 = 0,5%)
/// em um acumulado no período (fração, ex.: 0.045 = 4,5%).
double compoundPercentSeries(List<double> monthlyPercents) {
  var acc = 1.0;
  for (final p in monthlyPercents) {
    acc *= 1 + p / 100;
  }
  return acc - 1;
}
