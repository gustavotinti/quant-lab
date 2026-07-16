import 'package:quant_core/quant_core.dart';
import 'package:quant_stats/quant_stats.dart' as st;

/// Carry cambial — o retorno que existe SEM o preço se mover: quem fica
/// comprado na moeda de juro alto contra a de juro baixo embolsa o
/// diferencial de taxas. É um dos fatores mais antigos e documentados do
/// mercado; aqui ele é medido com dados de nível A (taxas de bancos
/// centrais: Fed, BCE, Selic).
///
/// Disciplina do laboratório — o fator é re-testado NO PAR, não aceito por
/// fé: o backtest mensal segue o lado do diferencial (dif > 0 → long o
/// par; dif < 0 → short) e o carry só vira evidência quando esse retorno é
/// significativo (t-teste) E positivo dentro e fora da amostra (70/30),
/// com diferencial atual relevante (≥ 0,5% a.a.).
class CarryPar {
  const CarryPar({
    required this.ativoId,
    required this.difJurosAa,
    required this.retornoMedioMensal,
    required this.mediaTreino,
    required this.mediaTeste,
    required this.nMeses,
    required this.pValor,
  });

  final String ativoId;

  /// Diferencial ATUAL de juros (fração a.a.): taxa da moeda-base − taxa
  /// da moeda-cotada. Positivo = carry a favor de COMPRAR o par.
  final double difJurosAa;

  /// Retorno médio mensal do backtest "seguir o lado do carry".
  final double retornoMedioMensal;
  final double mediaTreino;
  final double mediaTeste;
  final int nMeses;
  final double pValor;

  bool get validado =>
      nMeses >= 36 &&
      !pValor.isNaN &&
      pValor <= 0.05 &&
      retornoMedioMensal > 0 &&
      mediaTreino > 0 &&
      mediaTeste > 0 &&
      difJurosAa.abs() >= 0.005;

  /// Direção apontada pelo carry HOJE (só faz sentido quando [validado]).
  bool get compra => difJurosAa > 0;
}

/// Mede o carry do par [par] (preço base/cotada, ex.: EURUSD) usando as
/// séries de taxas anuais em % a.a. ([taxaBase] p/ a moeda-base, ex.: BCE;
/// [taxaCotada] p/ a cotada, ex.: Fed). Null quando não há meses alinhados
/// suficientes para medir com honestidade.
CarryPar? carryFx({
  required String ativoId,
  required TimeSeries par,
  required TimeSeries taxaBase,
  required TimeSeries taxaCotada,
}) {
  final pm = par.resampleMonthly();
  final bm = taxaBase.resampleMonthly();
  final cm = taxaCotada.resampleMonthly();
  if (pm.length < 14) return null;

  int chave(DateTime d) => d.year * 12 + (d.month - 1);
  final preco = {for (final o in pm.observations) chave(o.date): o.value};
  final base = {for (final o in bm.observations) chave(o.date): o.value};
  final cot = {for (final o in cm.observations) chave(o.date): o.value};

  // estratégia: no fim do mês t-1, olha o diferencial; opera o mês t
  final rets = <double>[];
  final meses = preco.keys.toList()..sort();
  for (final t in meses) {
    final p0 = preco[t - 1], p1 = preco[t];
    final b = base[t - 1], c = cot[t - 1];
    if (p0 == null || p1 == null || b == null || c == null || p0 <= 0) {
      continue;
    }
    final dif = (b - c) / 100;
    if (dif == 0) continue;
    final ret = p1 / p0 - 1;
    rets.add(dif > 0 ? ret : -ret);
  }
  if (rets.length < 36) return null;

  final corte = (rets.length * 0.7).floor().clamp(1, rets.length - 1);
  final tt = st.meanTTest(rets);

  // diferencial ATUAL: últimas observações disponíveis das duas taxas
  final difAtual =
      (taxaBase.last.value - taxaCotada.last.value) / 100;

  return CarryPar(
    ativoId: ativoId,
    difJurosAa: difAtual,
    retornoMedioMensal: st.mean(rets),
    mediaTreino: st.mean(rets.sublist(0, corte)),
    mediaTeste: st.mean(rets.sublist(corte)),
    nMeses: rets.length,
    pValor: tt.pValue,
  );
}
