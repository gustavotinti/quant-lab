import 'dart:math' as math;

/// Funções especiais usadas para significância estatística.
/// Implementações numéricas clássicas (Lanczos; Lentz para a fração
/// continuada da beta incompleta) — mesmas usadas por bibliotecas
/// científicas consagradas.

/// ln Γ(x) via aproximação de Lanczos (g=7, n=9). Válida para x > 0.
double logGamma(double x) {
  const coef = <double>[
    0.99999999999980993,
    676.5203681218851,
    -1259.1392167224028,
    771.32342877765313,
    -176.61502916214059,
    12.507343278686905,
    -0.13857109526572012,
    9.9843695780195716e-6,
    1.5056327351493116e-7,
  ];
  if (x < 0.5) {
    // Reflexão: Γ(x)Γ(1-x) = π / sin(πx)
    return math.log(math.pi / math.sin(math.pi * x)) - logGamma(1 - x);
  }
  final z = x - 1;
  var sum = coef[0];
  for (var i = 1; i < coef.length; i++) {
    sum += coef[i] / (z + i);
  }
  final t = z + 7.5;
  return 0.5 * math.log(2 * math.pi) +
      (z + 0.5) * math.log(t) -
      t +
      math.log(sum);
}

/// Beta incompleta regularizada I_x(a, b), via fração continuada (Lentz).
double incompleteBeta(double a, double b, double x) {
  if (x <= 0) return 0;
  if (x >= 1) return 1;
  final lnBeta = logGamma(a + b) - logGamma(a) - logGamma(b);
  final front =
      math.exp(lnBeta + a * math.log(x) + b * math.log(1 - x)) / a;

  // Convergência é melhor quando x < (a+1)/(a+b+2); senão usa simetria.
  if (x > (a + 1) / (a + b + 2)) {
    return 1 - incompleteBeta(b, a, 1 - x);
  }

  const tiny = 1e-30;
  var f = 1.0, c = 1.0, d = 0.0;
  for (var i = 0; i <= 300; i++) {
    final m = i ~/ 2;
    double numerator;
    if (i == 0) {
      numerator = 1;
    } else if (i.isEven) {
      numerator = m * (b - m) * x / ((a + 2 * m - 1) * (a + 2 * m));
    } else {
      numerator = -((a + m) * (a + b + m) * x) /
          ((a + 2 * m) * (a + 2 * m + 1));
    }
    d = 1 + numerator * d;
    if (d.abs() < tiny) d = tiny;
    d = 1 / d;
    c = 1 + numerator / c;
    if (c.abs() < tiny) c = tiny;
    final delta = c * d;
    f *= delta;
    if ((delta - 1).abs() < 1e-12) break;
  }
  return front * (f - 1);
}

/// CDF da distribuição t de Student com [df] graus de liberdade.
double studentTCdf(double t, double df) {
  if (df <= 0) throw ArgumentError('studentTCdf: df deve ser > 0');
  final x = df / (df + t * t);
  final p = 0.5 * incompleteBeta(df / 2, 0.5, x);
  return t >= 0 ? 1 - p : p;
}

/// p-valor bicaudal para uma estatística t.
double pValueTwoTailed(double t, double df) {
  final p = 2 * (1 - studentTCdf(t.abs(), df));
  return p.clamp(0.0, 1.0);
}
