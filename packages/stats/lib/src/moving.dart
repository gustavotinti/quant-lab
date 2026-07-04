import 'descriptive.dart';

/// Média móvel simples dos últimos [window] valores. `null` se não há dados
/// suficientes.
double? smaLast(List<double> xs, int window) {
  if (xs.length < window || window < 1) return null;
  return mean(xs.sublist(xs.length - window));
}

/// Série completa da média móvel simples (índices sem janela cheia = null).
List<double?> sma(List<double> xs, int window) {
  final out = List<double?>.filled(xs.length, null);
  if (window < 1 || xs.length < window) return out;
  var acc = 0.0;
  for (var i = 0; i < xs.length; i++) {
    acc += xs[i];
    if (i >= window) acc -= xs[i - window];
    if (i >= window - 1) out[i] = acc / window;
  }
  return out;
}

/// Média móvel exponencial (fator 2/(window+1)), último valor.
double? emaLast(List<double> xs, int window) {
  if (xs.length < window || window < 1) return null;
  final alpha = 2 / (window + 1);
  var e = mean(xs.sublist(0, window));
  for (var i = window; i < xs.length; i++) {
    e = alpha * xs[i] + (1 - alpha) * e;
  }
  return e;
}

/// Desvio padrão da janela final de tamanho [window].
double? rollingStdLast(List<double> xs, int window) {
  if (xs.length < window || window < 2) return null;
  return sampleStd(xs.sublist(xs.length - window));
}
