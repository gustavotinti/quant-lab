import 'package:quant_core/quant_core.dart';

/// Resultado da atualização de um indicador.
class UpdateOutcome {
  const UpdateOutcome(this.indicator, {this.series, this.failure});
  final Indicator indicator;
  final TimeSeries? series;
  final Failure? failure;
  bool get ok => series != null;
}

/// Orquestra a atualização: para cada indicador do catálogo, escolhe o
/// provedor pelo nome e persiste no repositório.
class DataUpdater {
  DataUpdater({
    required List<MarketDataProvider> providers,
    required this.store,
  }) : _providers = {for (final p in providers) p.providerKey: p};

  final Map<String, MarketDataProvider> _providers;
  final SeriesRepository store;

  Future<List<UpdateOutcome>> update(List<Indicator> indicators) async {
    final outcomes = <UpdateOutcome>[];
    for (final ind in indicators) {
      final provider = _providers[ind.source.provider];
      if (provider == null) {
        outcomes.add(UpdateOutcome(ind,
            failure: Failure('Provedor "${ind.source.provider}" não registrado')));
        continue;
      }
      final result = await provider.fetch(ind);
      switch (result) {
        case Ok(:final value):
          final saved = await store.save(value, meta: {
            'nome': ind.nome,
            'unidade': ind.unidade,
            'fonte': '${ind.source.provider}:${ind.source.code}',
            'tier': ind.source.tier.name.toUpperCase(),
          });
          outcomes.add(saved.fold(
            (_) => UpdateOutcome(ind, series: value),
            (f) => UpdateOutcome(ind, failure: f),
          ));
        case Err(:final failure):
          outcomes.add(UpdateOutcome(ind, failure: failure));
      }
    }
    return outcomes;
  }
}
