import 'package:quant_core/quant_core.dart';
import 'package:quant_engine/quant_engine.dart';
import 'package:quant_market_data/quant_market_data.dart';
import 'package:quant_stats/quant_stats.dart' as st;

import 'lab.dart';

/// Monta o JSON consumido pelo dashboard web (public/data/dashboard.json).
/// JSON não aceita NaN/Infinity — tudo passa por [_n].
Object? _n(double? v) =>
    v == null || !v.isFinite ? null : double.parse(v.toStringAsFixed(6));

String _iso(DateTime d) => d.toIso8601String().substring(0, 10);

Map<String, Object?> dashboardJson(
    Lab lab, LabContext ctx, List<Hypothesis> hs) {
  // cenários calculados uma vez por ativo (independem do horizonte)
  final cenarios = <String, ScenarioReport?>{
    for (final id in ctx.sinais.keys)
      id: ctx.series[id] == null ? null : analogousScenarios(ctx.series[id]!),
  };

  Map<String, Object?> cenStats(ScenarioStats s, String direcao) => {
        'n': s.n,
        'mediana': _n(s.mediana),
        'q1': _n(s.q1),
        'q3': _n(s.q3),
        'pior': _n(s.pior),
        'melhor': _n(s.melhor),
        'pctPositivo': _n(s.pctPositivo),
        // eficácia NA DIREÇÃO apontada: numa VENDA, cenário favorável é o
        // que caiu depois
        'pctFavoravel': _n(direcao == 'venda'
            ? (s.pctPositivo.isNaN ? double.nan : 1 - s.pctPositivo)
            : s.pctPositivo),
      };

  // ~3 anos amostrados a cada 5 pregões (preço + SMA-200 + datas) para o
  // gráfico do modal; o sparkline do card usa a cauda do mesmo vetor.
  Map<String, Object?>? chartData(String id) {
    final serie = ctx.series[id];
    if (serie == null || serie.length < 60) return null;
    final v = serie.values;
    final d = serie.dates;
    final smaFull = st.sma(v, 200);
    final idx = <int>[];
    for (var i = v.length - 1; i >= 0 && idx.length < 156; i -= 5) {
      idx.add(i);
    }
    final ordem = idx.reversed.toList();
    return {
      'd': [for (final i in ordem) _iso(d[i])],
      'v': [for (final i in ordem) _n(v[i])],
      's': [for (final i in ordem) _n(smaFull[i] ?? double.nan)],
    };
  }

  final charts = <String, Map<String, Object?>?>{
    for (final id in ctx.sinais.keys) id: chartData(id),
  };

  Map<String, Object?> oportunidadeJson(Oportunidade o, Horizon h) {
    final bt = ctx.backtests[o.indicator.id]?.porHorizonte(h);
    final cen = cenarios[o.indicator.id];
    final s = o.sinais;
    return {
      'id': o.indicator.id,
      'nome': o.indicator.nome,
      'categoria': o.indicator.category.label,
      'unidade': o.indicator.unidade,
      'direcao': o.direcao.name,
      'score': o.score,
      'preco': _n(s.lastPrice),
      'dataPreco': _iso(s.lastDate),
      'alavancagem': o.alavancagem == null
          ? null
          : {
              'sugerida': _n(o.alavancagem!.sugerida),
              'kellyMeio': _n(o.alavancagem!.kellyMeio),
              'tetoVol': _n(o.alavancagem!.tetoPorVolatilidade),
            },
      'evidencias': [for (final e in o.evidencias) e.texto],
      'estrategia': bt == null
          ? null
          : {
              'nome': bt.kind.label,
              'winRate': _n(bt.winRate),
              'trades': bt.nTrades,
              'cagr': _n(bt.estrategia.cagr),
              'cagrBuyHold': _n(bt.buyHold.cagr),
              'maxDd': _n(bt.estrategia.maxDd),
              'sharpeOos': _n(bt.estrategiaOos.sharpe),
              'walkForward': '${bt.segmentosPositivos}/3',
              'sobreviveuOos': bt.sobreviveuForaDaAmostra,
            },
      'sinais': {
        'ret1m': _n(s.ret1m),
        'ret3m': _n(s.ret3m),
        'ret12m': _n(s.ret12m),
        'mom12x1': _n(s.momentum12x1),
        'distSma200': _n(s.distSma200),
        'z60': _n(s.zScore60d),
        'vol1y': _n(s.vol1yAnn),
        'ddTopo': _n(s.ddDoTopo),
      },
      'cenarios': cen == null
          ? null
          : {
              'n': cen.nAnalogos,
              'desde': _iso(cen.datas.first),
              'fwd3m': cen.fwd3m == null
                  ? null
                  : cenStats(cen.fwd3m!, o.direcao.name),
              'fwd12m': cen.fwd12m == null
                  ? null
                  : cenStats(cen.fwd12m!, o.direcao.name),
            },
    };
  }

  final m = ctx.macro;
  String nome(String id) => indicadorPorId(id)?.nome ?? id;
  DateTime? ultima;
  for (final s in ctx.series.values) {
    if (s.isEmpty) continue;
    if (ultima == null || s.last.date.isAfter(ultima)) ultima = s.last.date;
  }

  return {
    'geradoEm': DateTime.now().toIso8601String(),
    'ultimaObservacao': ultima == null ? null : _iso(ultima),
    'nIndicadores': catalogoInicial.length,
    'nSeries': ctx.series.length,
    'macro': m == null
        ? null
        : {
            'selic': _n(m.selicAtual),
            'selicDirecao': m.selicDirecao.name,
            'ipca12m': _n(m.ipca12m),
            'ipca3mAnualizado': _n(m.ipca3mAnualizado),
            'inflacaoTendencia': m.inflacaoTendencia.name,
            'juroReal': _n(m.juroRealAa),
            'dolar': _n(m.dolarAtual),
            'us10y': _n(m.us10yAtual),
            'us10yDirecao': m.us10yDirecao?.name,
            'dxyForte': m.dxyAcimaSma200,
          },
    'horizontes': {
      for (final h in Horizon.values)
        h.name: {
          'label': h.label,
          'janela': h.janela,
          'oportunidades': [
            for (final o in lab.oportunidades(ctx, h)) oportunidadeJson(o, h),
          ],
        },
    },
    // um gráfico por ativo (não por horizonte — evita triplicar o payload)
    'charts': {
      for (final e in charts.entries)
        if (e.value != null) e.key: e.value,
    },
    'hipoteses': [
      for (final h in hs.take(12))
        {
          'causa': nome(h.causaId),
          'efeito': nome(h.efeitoId),
          'lagMeses': h.lagMeses,
          'rhoTreino': _n(h.rhoTreino),
          'rhoTeste': _n(h.rhoTeste),
          'status': h.status,
        },
    ],
  };
}
