import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:quant_core/quant_core.dart';

/// Adaptador para o FRED (Federal Reserve Bank of St. Louis) — dados
/// oficiais dos EUA e internacionais (nível A): Fed Funds, CPI, Treasuries,
/// taxa do BCE etc.
///
/// Requer chave GRATUITA (cadastro em https://fred.stlouisfed.org — menu
/// My Account → API Keys), lida do ambiente FRED_API_KEY. Sem a chave, os
/// indicadores 'fred' do catálogo falham com mensagem clara e o resto do
/// pipeline segue normal (mesmo padrão de degradação do eToro).
class FredProvider implements MarketDataProvider {
  FredProvider({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _apiKey = apiKey ?? Platform.environment['FRED_API_KEY'];

  final http.Client _client;
  final String? _apiKey;

  @override
  String get providerKey => 'fred';

  bool get configurado => _apiKey != null && _apiKey.isNotEmpty;

  @override
  Future<Result<TimeSeries>> fetch(Indicator indicator) async {
    if (!configurado) {
      return const Err(Failure(
          'FRED sem chave — crie grátis em fred.stlouisfed.org e defina '
          'FRED_API_KEY'));
    }
    try {
      final uri = Uri.parse(
        'https://api.stlouisfed.org/fred/series/observations'
        '?series_id=${indicator.source.code}'
        '&api_key=$_apiKey&file_type=json'
        '&observation_start=2000-01-01',
      );
      final res =
          await _client.get(uri).timeout(const Duration(seconds: 60));
      if (res.statusCode != 200) {
        return Err(Failure(
            'FRED ${indicator.source.code}: HTTP ${res.statusCode}'));
      }
      final body =
          json.decode(utf8.decode(res.bodyBytes)) as Map<String, Object?>;
      final rows = (body['observations'] as List?) ?? const [];
      final obs = <Observation>[];
      for (final r in rows) {
        final m = r as Map;
        // valores ausentes vêm como "." — pular, nunca inventar
        final v = double.tryParse('${m['value']}');
        final d = DateTime.tryParse('${m['date']}');
        if (v == null || d == null) continue;
        obs.add(Observation(d, v));
      }
      if (obs.isEmpty) {
        return Err(Failure(
            'FRED ${indicator.source.code}: nenhuma observação válida'));
      }
      return Ok(TimeSeries(indicator.id, obs));
    } catch (e) {
      return Err(Failure('Falha ao buscar ${indicator.id} no FRED', cause: e));
    }
  }
}
