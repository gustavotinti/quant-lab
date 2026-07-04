import 'package:quant_core/quant_core.dart';
import 'package:quant_stats/quant_stats.dart';

/// Uma hipótese de relação defasada entre dois indicadores:
/// "variações de [causaId] antecedem variações de [efeitoId] em [lagMeses]".
///
/// Regra de ouro do projeto: nenhuma hipótese é aceita sem tentar ser
/// destruída. O período histórico é dividido em treino (70%) e teste (30%);
/// a relação precisa aparecer no treino COM significância E persistir no
/// teste com o mesmo sinal.
class Hypothesis {
  const Hypothesis({
    required this.causaId,
    required this.efeitoId,
    required this.lagMeses,
    required this.rhoTreino,
    required this.pTreino,
    required this.nTreino,
    required this.rhoTeste,
    required this.nTeste,
    required this.status,
    required this.testadaEm,
  });

  final String causaId;
  final String efeitoId;
  final int lagMeses;
  final double rhoTreino;
  final double pTreino;
  final int nTreino;
  final double rhoTeste;
  final int nTeste;

  /// 'validada' (sobreviveu ao teste) ou 'candidata' (sinal persistiu, mas
  /// fraco — precisa de mais dados). Hipóteses destruídas não são salvas.
  final String status;
  final DateTime testadaEm;

  String get id => '$causaId->$efeitoId@${lagMeses}m';

  Map<String, Object?> toJson() => {
        'causaId': causaId,
        'efeitoId': efeitoId,
        'lagMeses': lagMeses,
        'rhoTreino': rhoTreino,
        'pTreino': pTreino,
        'nTreino': nTreino,
        'rhoTeste': rhoTeste,
        'nTeste': nTeste,
        'status': status,
        'testadaEm': testadaEm.toIso8601String(),
      };

  factory Hypothesis.fromJson(Map<String, Object?> j) => Hypothesis(
        causaId: j['causaId']! as String,
        efeitoId: j['efeitoId']! as String,
        lagMeses: j['lagMeses']! as int,
        rhoTreino: (j['rhoTreino']! as num).toDouble(),
        pTreino: (j['pTreino']! as num).toDouble(),
        nTreino: j['nTreino']! as int,
        rhoTeste: (j['rhoTeste']! as num).toDouble(),
        nTeste: j['nTeste']! as int,
        status: j['status']! as String,
        testadaEm: DateTime.parse(j['testadaEm']! as String),
      );
}

/// Laboratório de hipóteses: transforma cada série em variações mensais
/// (estacionárias), cruza todos os pares ordenados com defasagens de 1 a
/// [maxLag] meses e aplica o funil treino → teste.
class HypothesisLab {
  const HypothesisLab({
    this.maxLag = 6,
    this.minRhoTreino = 0.25,
    this.maxPTreino = 0.05,
    this.minNTreino = 48,
    this.minNTeste = 18,
    this.minRhoTeste = 0.15,
  });

  final int maxLag;
  final double minRhoTreino;
  final double maxPTreino;
  final int minNTreino;
  final int minNTeste;
  final double minRhoTeste;

  List<Hypothesis> minerar(Map<Indicator, TimeSeries> series) {
    // 1. Transforma tudo em variação mensal (compara mudanças, não níveis —
    //    níveis de séries com tendência produzem correlações espúrias).
    final changes = <Indicator, TimeSeries>{};
    for (final e in series.entries) {
      final t = _variacaoMensal(e.key, e.value);
      if (t != null && t.length >= minNTreino + minNTeste) {
        changes[e.key] = t;
      }
    }

    final out = <Hypothesis>[];
    final agora = DateTime.now();
    for (final causa in changes.keys) {
      for (final efeito in changes.keys) {
        if (identical(causa, efeito)) continue;
        final aligned = changes[causa]!.alignWith(changes[efeito]!);
        final n = aligned.length;
        if (n < minNTreino + minNTeste) continue;

        final cut = (n * 0.7).floor();
        final treinoA = aligned.a.sublist(0, cut);
        final treinoB = aligned.b.sublist(0, cut);
        final testeA = aligned.a.sublist(cut);
        final testeB = aligned.b.sublist(cut);

        for (final lc in laggedSpearman(treinoA, treinoB,
            maxLag: maxLag, minN: minNTreino)) {
          if (lc.rho.abs() < minRhoTreino || lc.pValue > maxPTreino) continue;

          final nTeste = testeA.length - lc.lag;
          if (nTeste < minNTeste) continue;
          final rhoTeste = spearman(
              testeA.sublist(0, nTeste), testeB.sublist(lc.lag));
          if (rhoTeste.isNaN) continue;

          // Tentativa de destruição: o sinal precisa persistir no teste.
          final mesmoSinal = rhoTeste.sign == lc.rho.sign;
          if (!mesmoSinal) continue; // destruída — não entra no banco
          final status =
              rhoTeste.abs() >= minRhoTeste ? 'validada' : 'candidata';

          out.add(Hypothesis(
            causaId: causa.id,
            efeitoId: efeito.id,
            lagMeses: lc.lag,
            rhoTreino: lc.rho,
            pTreino: lc.pValue,
            nTreino: lc.n,
            rhoTeste: rhoTeste,
            nTeste: nTeste,
            status: status,
            testadaEm: agora,
          ));
        }
      }
    }
    out.sort((a, b) => b.rhoTeste.abs().compareTo(a.rhoTeste.abs()));
    return out;
  }

  /// Converte cada série para uma medida mensal estacionária:
  /// preços/índices → retorno log mensal; taxas em % → diferença mensal.
  TimeSeries? _variacaoMensal(Indicator ind, TimeSeries s) {
    final m = s.resampleMonthly();
    if (m.length < 24) return null;
    final obs = <Observation>[];
    final usaDiferenca = ind.unidade.contains('%');
    for (var i = 1; i < m.length; i++) {
      final prev = m.observations[i - 1].value;
      final cur = m.observations[i].value;
      double? v;
      if (usaDiferenca) {
        v = cur - prev;
      } else if (prev > 0 && cur > 0) {
        v = cur / prev - 1;
      }
      if (v != null && v.isFinite) {
        obs.add(Observation(m.observations[i].date, v));
      }
    }
    return obs.length >= 24 ? TimeSeries(ind.id, obs) : null;
  }
}
