import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:quant_core/quant_core.dart';

/// Adaptador para a API de gráficos do Yahoo Finance (pública, sem chave).
///
/// O Yahoo aqui é só transporte: os preços têm origem nas próprias bolsas
/// (nível B). Se o provedor sumir, troca-se o adaptador — o domínio não muda.
class YahooProvider implements MarketDataProvider {
  YahooProvider({http.Client? client, this.range = '20y'})
      : _client = client ?? http.Client();

  final http.Client _client;
  final String range;

  @override
  String get providerKey => 'yahoo';

  @override
  Future<Result<TimeSeries>> fetch(Indicator indicator) async {
    try {
      final uri = Uri.https(
        'query1.finance.yahoo.com',
        '/v8/finance/chart/${indicator.source.code}',
        {'range': range, 'interval': '1d', 'events': 'history'},
      );
      final res = await _client.get(uri, headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) QuantLab/0.1',
      }).timeout(const Duration(seconds: 60));
      if (res.statusCode != 200) {
        return Err(Failure(
            'Yahoo ${indicator.source.code}: HTTP ${res.statusCode}'));
      }

      final root = json.decode(res.body) as Map<String, Object?>;
      final chart = root['chart'] as Map<String, Object?>?;
      final results = chart?['result'] as List?;
      if (results == null || results.isEmpty) {
        return Err(Failure('Yahoo ${indicator.source.code}: resposta vazia',
            cause: chart?['error']));
      }
      final r0 = results.first as Map<String, Object?>;
      final timestamps = (r0['timestamp'] as List?)?.cast<num>();
      final indicators = r0['indicators'] as Map<String, Object?>;

      // Preferimos adjclose (ajustado por dividendos/splits); fallback close.
      List<num?>? closes;
      final adj = indicators['adjclose'] as List?;
      if (adj != null && adj.isNotEmpty) {
        closes = ((adj.first as Map)['adjclose'] as List?)?.cast<num?>();
      }
      if (closes == null) {
        final quote = indicators['quote'] as List?;
        if (quote != null && quote.isNotEmpty) {
          closes = ((quote.first as Map)['close'] as List?)?.cast<num?>();
        }
      }
      if (timestamps == null || closes == null) {
        return Err(
            Failure('Yahoo ${indicator.source.code}: payload sem preços'));
      }

      final obs = <Observation>[];
      for (var i = 0; i < timestamps.length && i < closes.length; i++) {
        final v = closes[i];
        if (v == null) continue;
        final dt = DateTime.fromMillisecondsSinceEpoch(
            timestamps[i].toInt() * 1000,
            isUtc: true);
        obs.add(Observation(DateTime(dt.year, dt.month, dt.day), v.toDouble()));
      }
      if (obs.isEmpty) {
        return Err(Failure('Yahoo ${indicator.source.code}: só nulos'));
      }
      return Ok(TimeSeries(indicator.id, obs));
    } catch (e) {
      return Err(Failure('Falha ao buscar ${indicator.id} no Yahoo', cause: e));
    }
  }
}
