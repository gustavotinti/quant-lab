import 'package:quant_core/quant_core.dart';
import 'package:quant_stats/quant_stats.dart' as st;

/// Cenários análogos históricos: em vez de prever, o sistema pergunta
/// "quantas vezes este ativo já esteve em uma situação parecida com a de
/// hoje — e o que aconteceu depois?".
///
/// "Parecida" = distância normalizada pequena no espaço de 3 sinais
/// objetivos: momentum 12-1, distância da SMA-200 e z-score de 60 pregões.

/// Distribuição dos retornos que se seguiram aos cenários análogos.
class ScenarioStats {
  const ScenarioStats({
    required this.n,
    required this.mediana,
    required this.q1,
    required this.q3,
    required this.pior,
    required this.melhor,
    required this.pctPositivo,
  });

  final int n;
  final double mediana;
  final double q1;
  final double q3;
  final double pior;
  final double melhor;
  final double pctPositivo;

  factory ScenarioStats.fromReturns(List<double> rets) => ScenarioStats(
        n: rets.length,
        mediana: st.quantile(rets, 0.5),
        q1: st.quantile(rets, 0.25),
        q3: st.quantile(rets, 0.75),
        pior: st.quantile(rets, 0),
        melhor: st.quantile(rets, 1),
        pctPositivo:
            rets.isEmpty ? double.nan : rets.where((r) => r > 0).length / rets.length,
      );
}

class ScenarioReport {
  const ScenarioReport({
    required this.assetId,
    required this.momAtual,
    required this.dist200Atual,
    required this.zAtual,
    required this.datas,
    required this.fwd3m,
    required this.fwd12m,
  });

  final String assetId;
  final double momAtual;
  final double dist200Atual;
  final double zAtual;

  /// Datas históricas em que o ativo esteve em situação análoga à atual
  /// (espaçadas ≥ 1 mês para não contar o mesmo episódio duas vezes).
  final List<DateTime> datas;
  final ScenarioStats? fwd3m;
  final ScenarioStats? fwd12m;

  int get nAnalogos => datas.length;
}

/// Busca cenários análogos ao momento atual do ativo.
///
/// [maxDist] é a soma das distâncias em unidades de desvio padrão dos 3
/// sinais (1,5 ≈ "bem parecido"); [minAnalogos] evita conclusões com
/// amostra ridícula.
ScenarioReport? analogousScenarios(
  TimeSeries daily, {
  double maxDist = 1.5,
  int espacamento = 21,
  int minAnalogos = 5,
}) {
  final v = daily.values;
  final d = daily.dates;
  final n = v.length;
  if (n < 400) return null;

  // Sinais em cada data histórica (null onde a janela não está completa).
  final smaSeries = st.sma(v, 200);
  final mom = List<double?>.filled(n, null);
  final dist = List<double?>.filled(n, null);
  final z = List<double?>.filled(n, null);
  for (var i = 252; i < n; i++) {
    if (v[i - 252] > 0) mom[i] = v[i - 21] / v[i - 252] - 1;
    final s = smaSeries[i];
    if (s != null && s != 0) dist[i] = v[i] / s - 1;
    final janela = v.sublist(i - 59, i + 1);
    final sd = st.sampleStd(janela);
    z[i] = sd == 0 ? 0.0 : (v[i] - st.mean(janela)) / sd;
  }

  final hoje = n - 1;
  if (mom[hoje] == null || dist[hoje] == null || z[hoje] == null) return null;

  final validos = [
    for (var i = 252; i < n; i++)
      if (mom[i] != null && dist[i] != null && z[i] != null) i,
  ];
  if (validos.length < 300) return null;

  double sigma(List<double?> xs) =>
      st.sampleStd([for (final i in validos) xs[i]!]);
  final sMom = sigma(mom), sDist = sigma(dist), sZ = sigma(z);

  double distancia(int i) {
    var total = 0.0;
    if (sMom > 0) total += (mom[i]! - mom[hoje]!).abs() / sMom;
    if (sDist > 0) total += (dist[i]! - dist[hoje]!).abs() / sDist;
    if (sZ > 0) total += (z[i]! - z[hoje]!).abs() / sZ;
    return total;
  }

  // Seleção gulosa em ordem cronológica com espaçamento mínimo (um
  // "episódio" análogo não deve ser contado a cada pregão).
  final selecionados = <int>[];
  for (final i in validos) {
    if (i > n - 1 - 63) break; // precisa de pelo menos 3 meses à frente
    if (distancia(i) > maxDist) continue;
    if (selecionados.isNotEmpty && i - selecionados.last < espacamento) {
      continue;
    }
    selecionados.add(i);
  }
  if (selecionados.length < minAnalogos) return null;

  final fwd3 = <double>[];
  final fwd12 = <double>[];
  for (final i in selecionados) {
    if (v[i] > 0) {
      fwd3.add(v[i + 63] / v[i] - 1);
      if (i + 252 < n) fwd12.add(v[i + 252] / v[i] - 1);
    }
  }

  return ScenarioReport(
    assetId: daily.id,
    momAtual: mom[hoje]!,
    dist200Atual: dist[hoje]!,
    zAtual: z[hoje]!,
    datas: [for (final i in selecionados) d[i]],
    fwd3m: fwd3.isEmpty ? null : ScenarioStats.fromReturns(fwd3),
    fwd12m:
        fwd12.length < minAnalogos ? null : ScenarioStats.fromReturns(fwd12),
  );
}
