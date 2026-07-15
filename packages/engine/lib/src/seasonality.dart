import 'package:quant_core/quant_core.dart';
import 'package:quant_stats/quant_stats.dart' as st;

/// Sazonalidade de calendário — o retorno de um mês específico do ano,
/// medido em TODOS os anos da série. Commodities e índices têm ciclos
/// físicos reais (estoque de inverno no gás, safra na soja, fluxo de fim
/// de ano em ações); isto os transforma em evidência mensurável.
///
/// Disciplina anti-mineração (mesma do resto do laboratório):
/// 1. Significância: t-teste da média do mês vs zero (p ≤ 0,05).
/// 2. Validação 70/30: o SINAL da média nos primeiros 70% dos anos precisa
///    se repetir nos 30% finais — sazonalidade que sumiu não conta.
/// 3. Magnitude mínima: média < 0,8% ao mês é ruído de execução, não edge.
/// 4. Amostra mínima: 10 ocorrências do mês.
class SazonalidadeMes {
  const SazonalidadeMes({
    required this.mes,
    required this.media,
    required this.mediaTreino,
    required this.mediaTeste,
    required this.n,
    required this.pValor,
  });

  /// Mês do calendário avaliado (1 = janeiro … 12 = dezembro).
  final int mes;

  /// Média do retorno desse mês em todos os anos.
  final double media;
  final double mediaTreino;
  final double mediaTeste;

  /// Número de anos com esse mês na série.
  final int n;

  /// p-valor bicaudal do t-teste (média vs zero).
  final double pValor;

  bool get confirmadaForaDaAmostra =>
      mediaTreino != 0 && mediaTeste != 0 &&
      mediaTreino.sign == mediaTeste.sign;

  /// Só vira evidência quando sobrevive às 4 exigências.
  bool get relevante =>
      n >= 10 &&
      !pValor.isNaN &&
      pValor <= 0.05 &&
      media.abs() >= 0.008 &&
      confirmadaForaDaAmostra;

  static const nomes = [
    'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
    'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
  ];

  String get nomeMes => nomes[mes - 1];
}

/// Mede a sazonalidade do [mes] (1..12) numa série diária. Retorna null
/// quando não há retornos mensais suficientes para medir com honestidade.
SazonalidadeMes? sazonalidadeDoMes(TimeSeries daily, int mes) {
  final mensal = daily.resampleMonthly();
  if (mensal.length < 60) return null; // ~5 anos de meses

  // retornos mensais: fechamento do mês m vs fechamento do mês anterior
  final obs = mensal.observations;
  final doMes = <double>[]; // em ordem cronológica
  for (var i = 1; i < obs.length; i++) {
    if (obs[i].date.month != mes) continue;
    final prev = obs[i - 1];
    // só aceita quando o mês anterior é realmente o mês-calendário anterior
    final esperado = DateTime(obs[i].date.year, obs[i].date.month - 1);
    if (prev.date.year != esperado.year || prev.date.month != esperado.month) {
      continue;
    }
    if (prev.value <= 0) continue;
    doMes.add(obs[i].value / prev.value - 1);
  }
  if (doMes.length < 10) return null;

  final corte = (doMes.length * 0.7).floor().clamp(1, doMes.length - 1);
  final treino = doMes.sublist(0, corte);
  final teste = doMes.sublist(corte);
  final tt = st.meanTTest(doMes);

  return SazonalidadeMes(
    mes: mes,
    media: st.mean(doMes),
    mediaTreino: st.mean(treino),
    mediaTeste: teste.isEmpty ? 0 : st.mean(teste),
    n: doMes.length,
    pValor: tt.pValue,
  );
}

/// Mês do calendário que a análise de sazonalidade deve olhar a partir de
/// [hoje]: o próximo mês inteiro (as recomendações olham ~1-3 meses à
/// frente; o mês corrente já está parcialmente realizado).
int mesSazonalAlvo(DateTime hoje) => hoje.month == 12 ? 1 : hoje.month + 1;
