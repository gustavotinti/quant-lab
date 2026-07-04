import 'dart:math' as math;

import 'package:quant_core/quant_core.dart';
import 'package:quant_stats/quant_stats.dart';

enum Direcao { subindo, estavel, caindo }

/// Regime macroeconômico derivado exclusivamente de séries oficiais
/// (Selic, IPCA) e de preços de mercado (Treasury 10a, DXY, PTAX).
/// Sem opinião: só aritmética sobre dados nível A/B.
class MacroRegime {
  const MacroRegime({
    required this.selicAtual,
    required this.selicDirecao,
    required this.ipca12m,
    required this.ipca3mAnualizado,
    required this.inflacaoTendencia,
    required this.juroRealAa,
    this.dolarAtual,
    this.dolarAcimaDaMedia3m,
    this.us10yAtual,
    this.us10yDirecao,
    this.dxyAcimaSma200,
  });

  /// Selic meta, em % a.a. (ex.: 14.25).
  final double selicAtual;
  final Direcao selicDirecao;

  /// Inflação acumulada 12 meses, como fração (0.05 = 5%).
  final double ipca12m;
  final double ipca3mAnualizado;
  final Direcao inflacaoTendencia;

  /// Juro real ex-post: (1+Selic)/(1+IPCA12m) - 1, como fração.
  final double juroRealAa;

  final double? dolarAtual;
  final bool? dolarAcimaDaMedia3m;
  final double? us10yAtual;
  final Direcao? us10yDirecao;
  final bool? dxyAcimaSma200;

  factory MacroRegime.compute({
    required TimeSeries selic,
    required TimeSeries ipcaMensal,
    TimeSeries? dolar,
    TimeSeries? us10y,
    TimeSeries? dxy,
  }) {
    final selicNow = selic.last.value;
    final selicDir = _direcao(
        selic.values, 63, threshold: 0.01); // série diária, 63 pregões ≈ 3m

    final ipcaVals = ipcaMensal.values;
    final ipca12 = ipcaVals.length >= 12
        ? compoundPercentSeries(ipcaVals.sublist(ipcaVals.length - 12))
        : double.nan;
    // trimestre composto elevado à 4ª potência = taxa anualizada
    final ipca3 = ipcaVals.length >= 3
        ? math
                .pow(
                    1 +
                        compoundPercentSeries(
                            ipcaVals.sublist(ipcaVals.length - 3)),
                    4)
                .toDouble() -
            1
        : double.nan;
    final inflTend = ipca3.isNaN || ipca12.isNaN
        ? Direcao.estavel
        : (ipca3 > ipca12 + 0.005
            ? Direcao.subindo
            : (ipca3 < ipca12 - 0.005 ? Direcao.caindo : Direcao.estavel));

    final juroReal =
        ipca12.isNaN ? double.nan : (1 + selicNow / 100) / (1 + ipca12) - 1;

    bool? dolarAcima;
    if (dolar != null && dolar.length >= 63) {
      final m = smaLast(dolar.values, 63);
      if (m != null && m != 0) dolarAcima = dolar.last.value > m;
    }

    bool? dxyAcima;
    if (dxy != null && dxy.length >= 200) {
      final m = smaLast(dxy.values, 200);
      if (m != null && m != 0) dxyAcima = dxy.last.value > m;
    }

    return MacroRegime(
      selicAtual: selicNow,
      selicDirecao: selicDir,
      ipca12m: ipca12,
      ipca3mAnualizado: ipca3,
      inflacaoTendencia: inflTend,
      juroRealAa: juroReal,
      dolarAtual: dolar?.last.value,
      dolarAcimaDaMedia3m: dolarAcima,
      us10yAtual: us10y?.last.value,
      us10yDirecao:
          us10y != null ? _direcao(us10y.values, 63, threshold: 0.10) : null,
      dxyAcimaSma200: dxyAcima,
    );
  }

  static Direcao _direcao(List<double> vals, int lookback,
      {required double threshold}) {
    if (vals.length <= lookback) return Direcao.estavel;
    final diff = vals.last - vals[vals.length - 1 - lookback];
    if (diff > threshold) return Direcao.subindo;
    if (diff < -threshold) return Direcao.caindo;
    return Direcao.estavel;
  }
}
