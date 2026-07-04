import 'dart:math' as math;

import 'descriptive.dart';
import 'special.dart';

/// Correlação de Pearson entre duas listas do mesmo tamanho.
double pearson(List<double> a, List<double> b) {
  if (a.length != b.length) {
    throw ArgumentError('pearson: tamanhos diferentes (${a.length} vs ${b.length})');
  }
  if (a.length < 3) return double.nan;
  final ma = mean(a), mb = mean(b);
  var cov = 0.0, va = 0.0, vb = 0.0;
  for (var i = 0; i < a.length; i++) {
    final da = a[i] - ma, db = b[i] - mb;
    cov += da * db;
    va += da * da;
    vb += db * db;
  }
  if (va == 0 || vb == 0) return double.nan;
  return cov / math.sqrt(va * vb);
}

/// Postos com empates recebendo a média dos postos (mid-rank).
List<double> ranks(List<double> xs) {
  final indexed = List.generate(xs.length, (i) => i)
    ..sort((i, j) => xs[i].compareTo(xs[j]));
  final out = List<double>.filled(xs.length, 0);
  var i = 0;
  while (i < indexed.length) {
    var j = i;
    while (j + 1 < indexed.length && xs[indexed[j + 1]] == xs[indexed[i]]) {
      j++;
    }
    final avgRank = (i + j) / 2 + 1;
    for (var k = i; k <= j; k++) {
      out[indexed[k]] = avgRank;
    }
    i = j + 1;
  }
  return out;
}

/// Correlação de Spearman (Pearson sobre os postos) — robusta a outliers e
/// a relações monotônicas não lineares. Preferida no minerador de hipóteses.
double spearman(List<double> a, List<double> b) =>
    pearson(ranks(a), ranks(b));

/// Significância de uma correlação: estatística t e p-valor bicaudal.
({double t, double pValue}) correlationSignificance(double r, int n) {
  if (n < 4 || r.isNaN) {
    return (t: double.nan, pValue: double.nan);
  }
  if (r.abs() >= 1) {
    // correlação perfeita: evidência máxima
    return (t: r.sign * double.infinity, pValue: 0);
  }
  final t = r * math.sqrt((n - 2) / (1 - r * r));
  return (t: t, pValue: pValueTwoTailed(t, (n - 2).toDouble()));
}

/// Resultado de correlação defasada: [lag] períodos em que a série "causa"
/// antecede a série "efeito".
class LaggedCorrelation {
  const LaggedCorrelation(this.lag, this.rho, this.n, this.pValue);
  final int lag;
  final double rho;
  final int n;
  final double pValue;
}

/// Correlações de Spearman para defasagens 1..[maxLag]:
/// compara causa[t] com efeito[t + lag].
List<LaggedCorrelation> laggedSpearman(
  List<double> causa,
  List<double> efeito, {
  int maxLag = 6,
  int minN = 24,
}) {
  assert(causa.length == efeito.length);
  final out = <LaggedCorrelation>[];
  for (var lag = 1; lag <= maxLag; lag++) {
    final n = causa.length - lag;
    if (n < minN) break;
    final a = causa.sublist(0, n);
    final b = efeito.sublist(lag);
    final rho = spearman(a, b);
    if (rho.isNaN) continue;
    final sig = correlationSignificance(rho, n);
    out.add(LaggedCorrelation(lag, rho, n, sig.pValue));
  }
  return out;
}
