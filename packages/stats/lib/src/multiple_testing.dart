/// Correção de múltiplas comparações.
///
/// Quando o minerador testa centenas de pares × defasagens, alguns p-valores
/// "significativos" aparecem por puro acaso. Benjamini-Hochberg controla a
/// taxa de descobertas falsas (FDR) no nível [q].
///
/// Retorna a máscara de rejeição (true = hipótese nula rejeitada, ou seja,
/// resultado considerado significativo APÓS a correção). p-valores NaN são
/// tratados como 1 (nunca significativos).
List<bool> benjaminiHochberg(List<double> pValues, {double q = 0.05}) {
  final n = pValues.length;
  if (n == 0) return const [];
  final p = [for (final v in pValues) v.isNaN ? 1.0 : v];
  final idx = List.generate(n, (i) => i)
    ..sort((a, b) => p[a].compareTo(p[b]));

  var kMax = -1;
  for (var k = 0; k < n; k++) {
    if (p[idx[k]] <= (k + 1) / n * q) kMax = k;
  }

  final rejected = List<bool>.filled(n, false);
  for (var k = 0; k <= kMax; k++) {
    rejected[idx[k]] = true;
  }
  return rejected;
}
