/// Máximo drawdown de uma série de preços: a pior queda do topo até o fundo,
/// como fração negativa (ex.: -0.35 = queda de 35%).
double maxDrawdown(List<double> prices) {
  var peak = double.negativeInfinity;
  var worst = 0.0;
  for (final p in prices) {
    if (p > peak) peak = p;
    if (peak > 0) {
      final dd = p / peak - 1;
      if (dd < worst) worst = dd;
    }
  }
  return worst;
}

/// Drawdown atual: distância do último preço até o topo histórico da janela
/// (0 quando está no topo).
double currentDrawdown(List<double> prices) {
  if (prices.isEmpty) return 0;
  var peak = double.negativeInfinity;
  for (final p in prices) {
    if (p > peak) peak = p;
  }
  if (peak <= 0) return 0;
  return prices.last / peak - 1;
}
