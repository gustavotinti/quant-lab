/// Motores de análise do QuantLab.
///
/// Princípio: o sistema nunca "adivinha". Ele mede, testa hipóteses e
/// calcula probabilidades baseadas em evidência histórica. Nenhum resultado
/// chega ao usuário sem antes tentar ser destruído (validação fora da
/// amostra).
library;

export 'src/asset_signals.dart';
export 'src/backtest.dart';
export 'src/cross_sectional.dart';
export 'src/hypothesis.dart';
export 'src/leverage.dart';
export 'src/macro_regime.dart';
export 'src/opportunity.dart';
export 'src/portfolio.dart';
export 'src/radar.dart';
export 'src/recommendation.dart';
export 'src/scenarios.dart';
export 'src/seasonality.dart';
export 'src/track_record.dart';
