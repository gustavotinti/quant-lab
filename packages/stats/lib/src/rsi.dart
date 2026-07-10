/// RSI (Relative Strength Index) de Wilder — o oscilador clássico de
/// sobrecompra/sobrevenda, com a suavização exponencial original.
///
/// Série completa: `out[i]` é o RSI no fechamento `i` (null enquanto a
/// janela não está completa). 0–100; >70 esticado p/ cima, <30 p/ baixo.
List<double?> rsiSeries(List<double> prices, {int period = 14}) {
  final out = List<double?>.filled(prices.length, null);
  if (prices.length < period + 1) return out;

  var avgGain = 0.0;
  var avgLoss = 0.0;
  for (var i = 1; i <= period; i++) {
    final d = prices[i] - prices[i - 1];
    if (d > 0) {
      avgGain += d;
    } else {
      avgLoss -= d;
    }
  }
  avgGain /= period;
  avgLoss /= period;
  out[period] = _rsiDe(avgGain, avgLoss);

  for (var i = period + 1; i < prices.length; i++) {
    final d = prices[i] - prices[i - 1];
    avgGain = (avgGain * (period - 1) + (d > 0 ? d : 0)) / period;
    avgLoss = (avgLoss * (period - 1) + (d < 0 ? -d : 0)) / period;
    out[i] = _rsiDe(avgGain, avgLoss);
  }
  return out;
}

double _rsiDe(double avgGain, double avgLoss) {
  if (avgLoss == 0) return 100;
  return 100 - 100 / (1 + avgGain / avgLoss);
}
