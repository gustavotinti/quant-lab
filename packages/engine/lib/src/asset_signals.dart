import 'package:quant_core/quant_core.dart';
import 'package:quant_stats/quant_stats.dart';

/// Fotografia quantitativa de um ativo negociável, calculada a partir da
/// série diária de preços. Janelas em pregões: 21 ≈ 1 mês, 63 ≈ 3 meses,
/// 126 ≈ 6 meses, 252 ≈ 1 ano.
class AssetSignals {
  const AssetSignals({
    required this.id,
    required this.lastPrice,
    required this.lastDate,
    required this.nObs,
    this.ret1m,
    this.ret3m,
    this.ret6m,
    this.ret12m,
    this.momentum12x1,
    this.distSma200,
    this.zScore60d,
    this.vol30dAnn,
    this.vol1yAnn,
    this.maxDd1y,
    this.ddDoTopo,
    this.cagr3y,
  });

  final String id;
  final double lastPrice;
  final DateTime lastDate;
  final int nObs;

  final double? ret1m;
  final double? ret3m;
  final double? ret6m;
  final double? ret12m;

  /// Momentum clássico 12-1: retorno dos últimos 12 meses EXCLUINDO o último
  /// mês (evita o efeito de reversão de curtíssimo prazo documentado na
  /// literatura).
  final double? momentum12x1;

  /// Distância do preço à média móvel de 200 pregões (fração; + = acima).
  final double? distSma200;

  /// Z-score do preço atual na janela de 60 pregões (esticado/comprimido).
  final double? zScore60d;

  final double? vol30dAnn;
  final double? vol1yAnn;
  final double? maxDd1y;

  /// Drawdown atual em relação ao topo de toda a janela disponível.
  final double? ddDoTopo;

  /// Retorno anualizado dos últimos ~3 anos (tendência secular).
  final double? cagr3y;

  factory AssetSignals.fromDaily(TimeSeries daily) {
    final v = daily.values;
    final n = v.length;

    double? retOver(int sessions) =>
        n > sessions && v[n - 1 - sessions] != 0
            ? v[n - 1] / v[n - 1 - sessions] - 1
            : null;

    double? mom12x1;
    if (n > 252 && v[n - 1 - 252] != 0) {
      mom12x1 = v[n - 1 - 21] / v[n - 1 - 252] - 1;
    }

    final sma200 = smaLast(v, 200);
    final tail60 = n >= 60 ? v.sublist(n - 60) : null;
    final tail31 = n >= 31 ? v.sublist(n - 31) : null;
    final tail253 = n >= 253 ? v.sublist(n - 253) : null;

    double? cagr3;
    if (n > 756 && v[n - 1 - 756] != 0) {
      cagr3 = cagr(v[n - 1] / v[n - 1 - 756] - 1, 3);
    }

    return AssetSignals(
      id: daily.id,
      lastPrice: daily.last.value,
      lastDate: daily.last.date,
      nObs: n,
      ret1m: retOver(21),
      ret3m: retOver(63),
      ret6m: retOver(126),
      ret12m: retOver(252),
      momentum12x1: mom12x1,
      distSma200:
          sma200 != null && sma200 != 0 ? v.last / sma200 - 1 : null,
      zScore60d: tail60 != null ? zScoreLast(tail60) : null,
      vol30dAnn:
          tail31 != null ? annualizedVol(simpleReturns(tail31), 252) : null,
      vol1yAnn:
          tail253 != null ? annualizedVol(simpleReturns(tail253), 252) : null,
      maxDd1y: tail253 != null ? maxDrawdown(tail253) : null,
      ddDoTopo: currentDrawdown(v),
      cagr3y: cagr3,
    );
  }
}
