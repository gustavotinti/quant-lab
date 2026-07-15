import 'dart:convert';
import 'dart:io';

import 'package:quant_core/quant_core.dart';
import 'package:quant_engine/quant_engine.dart';
import 'package:quant_market_data/quant_market_data.dart';

/// Tudo que os comandos precisam, calculado uma única vez por execução.
class LabContext {
  const LabContext({
    required this.series,
    required this.sinais,
    required this.backtests,
    required this.cenarios,
    required this.macro,
    required this.sazonalidades,
  });

  final Map<String, TimeSeries> series;
  final Map<String, AssetSignals> sinais;
  final Map<String, BacktestPack> backtests;
  final Map<String, ScenarioReport> cenarios;
  final MacroRegime? macro;

  /// Sazonalidade do PRÓXIMO mês do calendário, por ativo (quando medível).
  final Map<String, SazonalidadeMes> sazonalidades;
}

/// Fachada da aplicação (camada Application no DDD): liga infraestrutura
/// (store/providers) ao domínio (engines). Nenhuma regra de negócio aqui.
class Lab {
  Lab(this.root)
      : store = FileSeriesStore(
            Directory('${root.path}${Platform.pathSeparator}data'
                '${Platform.pathSeparator}series'));

  final Directory root;
  final FileSeriesStore store;

  File get _hypothesesFile =>
      File('${root.path}${Platform.pathSeparator}data'
          '${Platform.pathSeparator}hypotheses.json');

  Future<List<UpdateOutcome>> update() {
    final updater = DataUpdater(
      providers: [BcbSgsProvider(), YahooProvider()],
      store: store,
    );
    return updater.update(catalogoInicial);
  }

  Future<LabContext> carregar() async {
    final series = <String, TimeSeries>{};
    for (final ind in catalogoInicial) {
      final r = await store.load(ind.id);
      if (r case Ok(:final value)) series[ind.id] = value;
    }

    final sinais = <String, AssetSignals>{};
    final backtests = <String, BacktestPack>{};
    final cenarios = <String, ScenarioReport>{};
    final sazonalidades = <String, SazonalidadeMes>{};
    final mesAlvo = mesSazonalAlvo(DateTime.now());
    for (final ind in catalogoInicial.where((i) => i.negociavel)) {
      final s = series[ind.id];
      if (s == null || s.length < 60) continue;
      sinais[ind.id] = AssetSignals.fromDaily(s);
      backtests[ind.id] = BacktestPack.fromDaily(s);
      final cen = analogousScenarios(s);
      if (cen != null) cenarios[ind.id] = cen;
      final saz = sazonalidadeDoMes(s, mesAlvo);
      if (saz != null) sazonalidades[ind.id] = saz;
    }

    MacroRegime? macro;
    final selic = series['selic_meta'];
    final ipca = series['ipca_mensal'];
    if (selic != null && ipca != null) {
      macro = MacroRegime.compute(
        selic: selic,
        ipcaMensal: ipca,
        dolar: series['dolar_ptax'],
        us10y: series['us10y'],
        dxy: series['dxy'],
      );
    }

    return LabContext(
        series: series,
        sinais: sinais,
        backtests: backtests,
        cenarios: cenarios,
        macro: macro,
        sazonalidades: sazonalidades);
  }

  List<Oportunidade> oportunidades(LabContext ctx, Horizon h) =>
      const OpportunityEngine().avaliar(
        ativos: catalogoInicial,
        sinais: ctx.sinais,
        backtests: ctx.backtests,
        macro: ctx.macro,
        horizon: h,
        cenarios: ctx.cenarios,
        sazonalidades: ctx.sazonalidades,
      );

  List<Hypothesis> descobrirHipoteses(LabContext ctx) {
    final porIndicador = <Indicator, TimeSeries>{
      for (final ind in catalogoInicial)
        if (ctx.series[ind.id] != null) ind: ctx.series[ind.id]!,
    };
    return const HypothesisLab().minerar(porIndicador);
  }

  Future<void> salvarHipoteses(List<Hypothesis> hs) async {
    await _hypothesesFile.parent.create(recursive: true);
    await _hypothesesFile.writeAsString(const JsonEncoder.withIndent(' ')
        .convert(hs.map((h) => h.toJson()).toList()));
  }

  Future<List<Hypothesis>> lerHipoteses() async {
    if (!await _hypothesesFile.exists()) return const [];
    final raw = json.decode(await _hypothesesFile.readAsString()) as List;
    return [
      for (final j in raw) Hypothesis.fromJson((j as Map).cast()),
    ];
  }
}
