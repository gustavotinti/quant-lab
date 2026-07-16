import 'package:quant_core/quant_core.dart';
import 'package:quant_stats/quant_stats.dart' as st;

/// Momentum cross-sectional (força relativa) — o fator clássico das
/// gestoras quant: em vez de perguntar "este ativo subiu?" (time-series),
/// pergunta "este ativo subiu MAIS QUE OS OUTROS?". Os dois efeitos são
/// ortogonais e documentados há décadas (Jegadeesh-Titman).
///
/// Disciplina do laboratório — o fator NÃO é aceito por fé na literatura:
/// ele é re-testado NO NOSSO universo. O backtest mensal mede o spread
/// tercil de cima − tercil de baixo (comprar os mais fortes, vender os mais
/// fracos) e o fator só vira evidência quando o spread é significativo
/// (t-teste) E positivo também nos 30% finais (fora da amostra).
///
/// Comparação justa entre classes: o ranking usa momentum 12-1 AJUSTADO
/// pela volatilidade (mom/vol) — senão cripto ocupa os extremos por ser
/// volátil, não por ser forte.

/// Força relativa de um ativo HOJE dentro do universo.
class ForcaRelativa {
  const ForcaRelativa({
    required this.id,
    required this.momentum,
    required this.score,
    required this.percentil,
  });

  final String id;

  /// Momentum 12-1 cru (12 meses excluindo o último).
  final double momentum;

  /// Momentum ajustado pela vol (critério do ranking).
  final double score;

  /// Posição no universo hoje: 0 = o mais fraco, 1 = o mais forte.
  final double percentil;
}

class CrossSectionalReport {
  const CrossSectionalReport({
    required this.porAtivo,
    required this.spreadMedioMensal,
    required this.spreadTreino,
    required this.spreadTeste,
    required this.nMeses,
    required this.pValor,
    required this.nAtivosHoje,
  });

  final Map<String, ForcaRelativa> porAtivo;

  /// Spread médio mensal do backtest (tercil forte − tercil fraco).
  final double spreadMedioMensal;
  final double spreadTreino;
  final double spreadTeste;

  /// Meses avaliados no backtest.
  final int nMeses;

  /// t-teste do spread mensal vs zero (bicaudal).
  final double pValor;
  final int nAtivosHoje;

  /// O fator só vira evidência quando sobreviveu no NOSSO universo:
  /// amostra decente, significância, spread positivo dentro E fora da
  /// amostra (70/30) e MAGNITUDE que pague o trade — spread < 0,3%/mês é
  /// significância estatística sem relevância econômica (falsos positivos
  /// de ruído chegam a p<0,05 com spread de ~0,1%/mês; um edge real rende
  /// muito mais).
  bool get validado =>
      nMeses >= 36 &&
      !pValor.isNaN &&
      pValor <= 0.05 &&
      spreadMedioMensal >= 0.003 &&
      spreadTreino > 0 &&
      spreadTeste > 0;
}

/// Mede o fator no universo [series] (id → série diária). Retorna null
/// quando não há meses/ativos suficientes para medir com honestidade.
CrossSectionalReport? crossSectionalMomentum(
  Map<String, TimeSeries> series, {
  int minAtivosPorMes = 8,
}) {
  // fechamentos mensais por ativo, indexados por (ano*12 + mês)
  final fechado = <String, Map<int, double>>{};
  var primeiroMes = 1 << 30, ultimoMes = 0;
  for (final e in series.entries) {
    final mensal = e.value.resampleMonthly();
    if (mensal.length < 14) continue;
    final m = <int, double>{};
    for (final o in mensal.observations) {
      final k = o.date.year * 12 + (o.date.month - 1);
      m[k] = o.value;
      if (k < primeiroMes) primeiroMes = k;
      if (k > ultimoMes) ultimoMes = k;
    }
    fechado[e.key] = m;
  }
  if (fechado.length < minAtivosPorMes) return null;

  // score 12-1 ajustado por vol no mês t (decisão no fim do mês t):
  // mom = close[t-1]/close[t-13] − 1; vol = σ dos 12 retornos mensais.
  ({double mom, double score})? scoreEm(Map<int, double> m, int t) {
    final rets = <double>[];
    for (var k = t - 12; k <= t - 1; k++) {
      final a = m[k - 1], b = m[k];
      if (a == null || b == null || a <= 0) return null;
      rets.add(b / a - 1);
    }
    final pIni = m[t - 13], pFim = m[t - 1];
    if (pIni == null || pFim == null || pIni <= 0) return null;
    final mom = pFim / pIni - 1;
    final vol = st.sampleStd(rets);
    return (mom: mom, score: vol > 0 ? mom / vol : mom);
  }

  // backtest: spread mensal tercil forte − tercil fraco
  final spreads = <double>[];
  for (var t = primeiroMes + 13; t < ultimoMes; t++) {
    final ranking = <(String, double)>[];
    final proxRet = <String, double>{};
    for (final e in fechado.entries) {
      final s = scoreEm(e.value, t);
      final p0 = e.value[t], p1 = e.value[t + 1];
      if (s == null || p0 == null || p1 == null || p0 <= 0) continue;
      ranking.add((e.key, s.score));
      proxRet[e.key] = p1 / p0 - 1;
    }
    if (ranking.length < minAtivosPorMes) continue;
    ranking.sort((a, b) => a.$2.compareTo(b.$2));
    final n3 = ranking.length ~/ 3;
    if (n3 < 2) continue;
    final fracos = ranking.take(n3);
    final fortes = ranking.skip(ranking.length - n3);
    final rFortes =
        st.mean([for (final (id, _) in fortes) proxRet[id]!]);
    final rFracos =
        st.mean([for (final (id, _) in fracos) proxRet[id]!]);
    spreads.add(rFortes - rFracos);
  }
  if (spreads.length < 36) return null;

  final corte = (spreads.length * 0.7).floor().clamp(1, spreads.length - 1);
  final tt = st.meanTTest(spreads);

  // força relativa HOJE: score no último mês disponível de cada ativo
  final hoje = <(String, double, double)>[];
  for (final e in fechado.entries) {
    final t = e.value.keys.reduce((a, b) => a > b ? a : b);
    final s = scoreEm(e.value, t);
    if (s != null) hoje.add((e.key, s.mom, s.score));
  }
  if (hoje.length < minAtivosPorMes) return null;
  hoje.sort((a, b) => a.$3.compareTo(b.$3));
  final porAtivo = <String, ForcaRelativa>{
    for (var i = 0; i < hoje.length; i++)
      hoje[i].$1: ForcaRelativa(
        id: hoje[i].$1,
        momentum: hoje[i].$2,
        score: hoje[i].$3,
        percentil: hoje.length == 1 ? 0.5 : i / (hoje.length - 1),
      ),
  };

  return CrossSectionalReport(
    porAtivo: porAtivo,
    spreadMedioMensal: st.mean(spreads),
    spreadTreino: st.mean(spreads.sublist(0, corte)),
    spreadTeste: st.mean(spreads.sublist(corte)),
    nMeses: spreads.length,
    pValor: tt.pValue,
    nAtivosHoje: hoje.length,
  );
}
