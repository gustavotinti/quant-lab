import 'package:quant_core/quant_core.dart';
import 'package:quant_stats/quant_stats.dart' as st;

/// 📡 Radar de Picos — leitura técnica do gráfico calibrada em história.
///
/// O "esquadro" dos gráficos tem matemática por trás: canal de regressão
/// (linhas de tendência), compressão de volatilidade (triângulos/cunhas),
/// RSI (exaustão) e proximidade de topos/fundos de 52 semanas. Este motor
/// mede o estado técnico ATUAL do ativo, encontra todos os momentos
/// historicamente parecidos e responde com a frequência REAL com que veio
/// uma virada nos ~21 pregões seguintes.
///
/// Honestidade: a saída é uma probabilidade empírica com n explícito —
/// "99% de certeza" não existe em mercado; acima de ~70% já é raro.

/// Estado técnico em uma data (todos os números são objetivos).
class EstadoTecnico {
  const EstadoTecnico({
    required this.rsi14,
    required this.z20,
    required this.distTopo252,
    required this.distFundo252,
    required this.streak,
    required this.squeeze,
    required this.canal63,
  });

  /// RSI de Wilder (14) — exaustão de movimento (0–100).
  final double rsi14;

  /// Z-score de 20 pregões (posição nas bandas de Bollinger, em σ).
  final double z20;

  /// Distância do topo de 252 pregões (fração ≤ 0; 0 = renovando topo).
  final double distTopo252;

  /// Distância do fundo de 252 pregões (fração ≥ 0; 0 = renovando fundo).
  final double distFundo252;

  /// Pregões consecutivos na mesma direção (+ altas / − quedas).
  final double streak;

  /// Compressão de volatilidade: vol(20)/vol(100). < 0,75 = triângulo/
  /// cunha se formando (energia acumulando para rompimento).
  final double squeeze;

  /// Posição no canal de regressão de 63 pregões, em σ do resíduo
  /// (as "linhas do esquadro": +2 = colado na linha de cima).
  final double canal63;

  List<double> get vetor =>
      [rsi14, z20, distTopo252, distFundo252, streak, squeeze, canal63];
}

class RadarPico {
  const RadarPico({
    required this.tipo,
    required this.prob,
    required this.n,
    required this.medianaFwd21,
    required this.estado,
    required this.leituras,
  });

  /// 'topo' (esticado para cima → pico para baixo) ou 'fundo'
  /// (esticado para baixo → virada para cima).
  final String tipo;

  /// Probabilidade empírica da virada nos próximos ~21 pregões
  /// (fração dos análogos históricos em que ela veio).
  final double prob;

  /// Número de episódios análogos que sustentam o número.
  final int n;

  /// Mediana do retorno dos 21 pregões seguintes nos análogos.
  final double medianaFwd21;

  final EstadoTecnico estado;

  /// Leituras em texto (para UI/Oráculo): só fatos, sem adjetivo.
  final List<String> leituras;
}

/// Calcula as séries técnicas completas de um ativo (O(n·janela)).
List<EstadoTecnico?> _estados(List<double> v) {
  final n = v.length;
  final rsi = st.rsiSeries(v);
  final out = List<EstadoTecnico?>.filled(n, null);

  var streak = 0.0;
  for (var i = 0; i < n; i++) {
    if (i > 0) {
      if (v[i] > v[i - 1]) {
        streak = streak >= 0 ? streak + 1 : 1;
      } else if (v[i] < v[i - 1]) {
        streak = streak <= 0 ? streak - 1 : -1;
      }
    }
    if (i < 300 || rsi[i] == null) continue;

    final win20 = v.sublist(i - 19, i + 1);
    final sd20 = st.sampleStd(win20);
    final z20 = sd20 == 0 ? 0.0 : (v[i] - st.mean(win20)) / sd20;

    var topo = v[i], fundo = v[i];
    for (var j = i - 251; j <= i; j++) {
      if (v[j] > topo) topo = v[j];
      if (v[j] < fundo) fundo = v[j];
    }

    final r20 = st.simpleReturns(v.sublist(i - 20, i + 1));
    final r100 = st.simpleReturns(v.sublist(i - 100, i + 1));
    final sdCurta = st.sampleStd(r20);
    final sdLonga = st.sampleStd(r100);
    final squeeze = sdLonga == 0 ? 1.0 : sdCurta / sdLonga;

    // canal de regressão de 63 pregões: reta OLS + σ do resíduo
    final xs = List.generate(63, (k) => k.toDouble());
    final ys = v.sublist(i - 62, i + 1);
    final reg = st.ols(xs, ys);
    final resid = <double>[
      for (var k = 0; k < 63; k++)
        ys[k] - (reg.intercept + reg.slope * k),
    ];
    final sdRes = st.sampleStd(resid);
    final canal = sdRes == 0 ? 0.0 : resid.last / sdRes;

    out[i] = EstadoTecnico(
      rsi14: rsi[i]!,
      z20: z20,
      distTopo252: topo == 0 ? 0 : v[i] / topo - 1,
      distFundo252: fundo == 0 ? 0 : v[i] / fundo - 1,
      streak: streak,
      squeeze: squeeze,
      canal63: canal,
    );
  }
  return out;
}

/// Radar do ativo: null quando o estado atual não está esticado (sem
/// candidato a pico) ou quando não há análogos suficientes para calibrar.
RadarPico? radarPico(
  TimeSeries daily, {
  /// Distância média máxima por feature, em σ, para contar como análogo.
  double maxDistMedia = 1.0,
  int espacamento = 10,
  int minAnalogos = 12,
  int fwd = 21,
}) {
  final v = daily.values;
  final n = v.length;
  if (n < 420) return null;

  final estados = _estados(v);
  final hoje = estados[n - 1];
  if (hoje == null) return null;

  // Está esticado? Contagem de sinais clássicos em cada direção.
  final cima = [
    hoje.z20 > 1.0,
    hoje.rsi14 > 65,
    hoje.canal63 > 1.2,
    hoje.distTopo252 > -0.02,
    hoje.streak >= 4,
  ].where((x) => x).length;
  final baixo = [
    hoje.z20 < -1.0,
    hoje.rsi14 < 35,
    hoje.canal63 < -1.2,
    hoje.distFundo252 < 0.02,
    hoje.streak <= -4,
  ].where((x) => x).length;
  if (cima < 2 && baixo < 2) return null;
  final tipo = cima >= baixo ? 'topo' : 'fundo';

  // Normalização das features pelos σ históricos.
  final validos = <int>[];
  for (var i = 300; i < n - fwd; i++) {
    if (estados[i] != null) validos.add(i);
  }
  if (validos.length < 200) return null;
  final dims = hoje.vetor.length;
  final sigmas = List<double>.filled(dims, 0);
  for (var d = 0; d < dims; d++) {
    sigmas[d] =
        st.sampleStd([for (final i in validos) estados[i]!.vetor[d]]);
  }

  double distancia(EstadoTecnico e) {
    var total = 0.0;
    for (var d = 0; d < dims; d++) {
      if (sigmas[d] > 0) {
        total += (e.vetor[d] - hoje.vetor[d]).abs() / sigmas[d];
      }
    }
    return total / dims; // distância média por feature, em σ
  }

  // k-vizinhos-mais-próximos: os episódios MAIS parecidos primeiro
  // (precisão automática), com espaçamento para não contar o mesmo
  // episódio duas vezes e teto de distância para não aceitar qualquer um.
  final ordenados = [...validos]
    ..sort((a, b) =>
        distancia(estados[a]!).compareTo(distancia(estados[b]!)));
  final escolhidos = <int>[];
  for (final i in ordenados) {
    if (distancia(estados[i]!) > maxDistMedia) break;
    if (escolhidos.any((j) => (i - j).abs() < espacamento)) continue;
    if (v[i] <= 0) continue;
    escolhidos.add(i);
    if (escolhidos.length >= 16) break; // pureza > volume
  }
  if (escolhidos.length < minAnalogos) return null;
  final fwds = [for (final i in escolhidos) v[i + fwd] / v[i] - 1];

  final virada = tipo == 'topo'
      ? fwds.where((r) => r < 0).length / fwds.length
      : fwds.where((r) => r > 0).length / fwds.length;

  final e = hoje;
  final leituras = <String>[
    'RSI(14) em ${e.rsi14.toStringAsFixed(0)}',
    'preço a ${e.z20.toStringAsFixed(1)}σ da média de 20 pregões',
    'canal de regressão (63): ${e.canal63.toStringAsFixed(1)}σ',
    if (e.distTopo252 > -0.02) 'a ${(-e.distTopo252 * 100).toStringAsFixed(1)}% do topo de 52 semanas',
    if (e.distFundo252 < 0.02) 'a ${(e.distFundo252 * 100).toStringAsFixed(1)}% do fundo de 52 semanas',
    if (e.streak.abs() >= 3) '${e.streak.abs().toStringAsFixed(0)} pregões seguidos de ${e.streak > 0 ? "alta" : "queda"}',
    if (e.squeeze < 0.75) 'compressão de volatilidade (squeeze ${e.squeeze.toStringAsFixed(2)}) — rompimento se armando',
  ];

  return RadarPico(
    tipo: tipo,
    prob: virada,
    n: fwds.length,
    medianaFwd21: st.quantile(fwds, 0.5),
    estado: hoje,
    leituras: leituras,
  );
}
