import 'dart:math' as math;

/// Sugestão de alavancagem baseada em dois freios independentes:
///
/// 1. **Kelly fracionado**: f* = μ/σ² (média de excesso de retorno anual
///    sobre a variância anual). Usamos MEIO Kelly — o Kelly cheio maximiza
///    crescimento teórico mas produz drawdowns intoleráveis na prática.
/// 2. **Alvo de volatilidade**: alavancagem = vol-alvo / vol-realizada
///    (com 15% a.a. de alvo, um ativo com 30% de vol permite no máx. 0,5x).
///
/// A sugestão final é o MENOR dos dois freios, com teto absoluto [cap].
/// Estimativas de μ vêm de backtest histórico — o futuro pode ser pior.
class LeverageAdvice {
  const LeverageAdvice({
    required this.kellyCheio,
    required this.kellyMeio,
    required this.tetoPorVolatilidade,
    required this.sugerida,
    required this.avisos,
  });

  final double kellyCheio;
  final double kellyMeio;
  final double tetoPorVolatilidade;

  /// Alavancagem máxima sugerida (1.0 = sem alavancagem; 0 = não alavancar).
  final double sugerida;
  final List<String> avisos;
}

LeverageAdvice leverageAdvice({
  required double retornoExcedenteAnual,
  required double volAnual,
  double volAlvo = 0.15,
  double cap = 3.0,
}) {
  final avisos = <String>[
    'Alavancagem multiplica perdas na mesma proporção dos ganhos.',
    'Em derivativos/perpétuos existe preço de liquidação: quedas rápidas '
        'podem zerar a posição antes de qualquer recuperação.',
    'μ estimado de dados históricos; regimes mudam sem avisar.',
  ];

  if (volAnual <= 0 || volAnual.isNaN) {
    return LeverageAdvice(
      kellyCheio: 0,
      kellyMeio: 0,
      tetoPorVolatilidade: 0,
      sugerida: 0,
      avisos: [...avisos, 'Volatilidade indisponível — sem sugestão.'],
    );
  }

  final kelly = retornoExcedenteAnual / (volAnual * volAnual);
  final kellyMeio = math.max(0.0, kelly / 2);
  final tetoVol = volAlvo / volAnual;

  var sugerida = math.min(kellyMeio, tetoVol);
  var teto = cap;
  if (volAnual > 0.40) {
    teto = 1.0;
    avisos.add('Volatilidade anual acima de 40% — alavancagem acima de 1x '
        'é desaconselhada neste ativo.');
  }
  sugerida = sugerida.clamp(0.0, teto);

  if (kelly <= 0) {
    avisos.add('Kelly negativo: a expectativa histórica de excesso de '
        'retorno é ≤ 0 — matematicamente NÃO alavancar.');
  }

  return LeverageAdvice(
    kellyCheio: kelly,
    kellyMeio: kellyMeio,
    tetoPorVolatilidade: tetoVol,
    sugerida: double.parse(sugerida.toStringAsFixed(2)),
    avisos: avisos,
  );
}
