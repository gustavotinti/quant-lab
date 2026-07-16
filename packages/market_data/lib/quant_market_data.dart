/// Infraestrutura de dados do QuantLab.
///
/// Somente aqui existem HTTP, arquivos e formatos de provedores externos.
/// O domínio enxerga apenas as portas de `quant_core`.
library;

export 'src/bcb_sgs_provider.dart';
export 'src/catalog.dart';
export 'src/etoro_client.dart';
export 'src/file_series_store.dart';
export 'src/fred_provider.dart';
export 'src/updater.dart';
export 'src/yahoo_provider.dart';
