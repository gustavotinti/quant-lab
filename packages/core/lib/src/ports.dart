import 'indicator.dart';
import 'result.dart';
import 'time_series.dart';

/// Porta de persistência de séries. Hoje a implementação é em arquivo
/// (infraestrutura local); amanhã pode ser Firestore — o domínio não muda.
abstract interface class SeriesRepository {
  Future<Result<TimeSeries>> load(String id);
  Future<Result<void>> save(TimeSeries series, {Map<String, Object?>? meta});
  Future<List<String>> listIds();
}

/// Porta de obtenção de dados externos (BCB, Yahoo...). Cada provedor é um
/// adaptador de infraestrutura registrado pelo nome ([Indicator.source]).
abstract interface class MarketDataProvider {
  String get providerKey;
  Future<Result<TimeSeries>> fetch(Indicator indicator);
}
