import 'dart:math' as math;

import 'descriptive.dart';
import 'special.dart';

/// Resultado de uma regressão linear simples (mínimos quadrados ordinários).
class OlsResult {
  const OlsResult({
    required this.slope,
    required this.intercept,
    required this.r2,
    required this.tStatSlope,
    required this.pValueSlope,
    required this.n,
  });

  final double slope;
  final double intercept;
  final double r2;
  final double tStatSlope;
  final double pValueSlope;
  final int n;
}

/// OLS simples y = a + b·x com significância do coeficiente angular.
OlsResult ols(List<double> x, List<double> y) {
  if (x.length != y.length || x.length < 3) {
    throw ArgumentError('ols: precisa de n >= 3 e tamanhos iguais');
  }
  final n = x.length;
  final mx = mean(x), my = mean(y);
  var sxx = 0.0, sxy = 0.0, syy = 0.0;
  for (var i = 0; i < n; i++) {
    final dx = x[i] - mx, dy = y[i] - my;
    sxx += dx * dx;
    sxy += dx * dy;
    syy += dy * dy;
  }
  if (sxx == 0) throw ArgumentError('ols: x constante');
  final slope = sxy / sxx;
  final intercept = my - slope * mx;

  var ssRes = 0.0;
  for (var i = 0; i < n; i++) {
    final e = y[i] - (intercept + slope * x[i]);
    ssRes += e * e;
  }
  final r2 = syy == 0 ? 1.0 : 1 - ssRes / syy;

  double tStat, pValue;
  if (n > 2 && ssRes > 0) {
    final se = math.sqrt(ssRes / (n - 2)) / math.sqrt(sxx);
    tStat = slope / se;
    pValue = pValueTwoTailed(tStat, (n - 2).toDouble());
  } else {
    tStat = double.infinity;
    pValue = 0;
  }

  return OlsResult(
    slope: slope,
    intercept: intercept,
    r2: r2,
    tStatSlope: tStat,
    pValueSlope: pValue,
    n: n,
  );
}
