import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:quant_core/quant_core.dart';

/// Adaptador para a API SGS do Banco Central do Brasil.
///
/// Endpoint público, sem chave:
/// https://api.bcb.gov.br/dados/serie/bcdata.sgs.{codigo}/dados
///
/// A API limita o tamanho da consulta por chamada (na prática, algumas
/// séries diárias falham acima de ~8 anos), então o histórico completo é
/// baixado em janelas conservadoras de 5 anos.
class BcbSgsProvider implements MarketDataProvider {
  BcbSgsProvider({http.Client? client, DateTime? inicioHistorico})
      : _client = client ?? http.Client(),
        _inicio = inicioHistorico ?? DateTime(2000, 1, 1);

  final http.Client _client;
  final DateTime _inicio;

  @override
  String get providerKey => 'bcb_sgs';

  @override
  Future<Result<TimeSeries>> fetch(Indicator indicator) async {
    try {
      final obs = <Observation>[];
      var from = _inicio;
      final today = DateTime.now();
      while (from.isBefore(today)) {
        var to = DateTime(from.year + 5, from.month, from.day);
        if (to.isAfter(today)) to = today;
        obs.addAll(await _fetchWindow(indicator.source.code, from, to));
        from = to.add(const Duration(days: 1));
      }
      if (obs.isEmpty) {
        return Err(Failure(
            'BCB SGS ${indicator.source.code}: nenhuma observação retornada'));
      }
      return Ok(TimeSeries(indicator.id, obs));
    } catch (e) {
      return Err(Failure('Falha ao buscar ${indicator.id} no BCB', cause: e));
    }
  }

  Future<List<Observation>> _fetchWindow(
      String code, DateTime from, DateTime to) async {
    final uri = Uri.parse(
      'https://api.bcb.gov.br/dados/serie/bcdata.sgs.$code/dados'
      '?formato=json&dataInicial=${_fmt(from)}&dataFinal=${_fmt(to)}',
    );
    final res = await _client.get(uri).timeout(const Duration(seconds: 60));
    if (res.statusCode == 404) return const []; // janela sem dados
    if (res.statusCode != 200) {
      throw http.ClientException('HTTP ${res.statusCode} em $uri');
    }
    final text = utf8.decode(res.bodyBytes);
    if (text.trimLeft().startsWith('<')) {
      throw http.ClientException(
          'BCB devolveu página de erro (janela ${_fmt(from)}–${_fmt(to)})');
    }
    final body = json.decode(text);
    if (body is! List) return const [];
    return [
      for (final row in body.cast<Map<String, Object?>>())
        if (_parse(row) case final Observation o) o,
    ];
  }

  Observation? _parse(Map<String, Object?> row) {
    final data = row['data'] as String?;
    final valor = double.tryParse((row['valor'] as String? ?? '').trim());
    if (data == null || valor == null) return null;
    final parts = data.split('/'); // dd/MM/yyyy
    if (parts.length != 3) return null;
    return Observation(
      DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0])),
      valor,
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
