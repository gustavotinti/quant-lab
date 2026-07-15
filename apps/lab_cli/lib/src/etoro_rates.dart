import 'dart:convert';
import 'dart:io';

import 'package:quant_market_data/quant_market_data.dart';

import 'etoro.dart';
import 'firestore_rest.dart';

/// Cotações AO VIVO do eToro para TODOS os ativos negociáveis (não só as
/// posições abertas) → Firestore `private/rates`. O painel do dono lê num
/// listener em tempo real e recalcula entrada/stop/alvo no preço de agora,
/// em vez do fechamento do dia anterior.
///
/// Roda no pipeline (tem as chaves do eToro + a service account). O endpoint
/// de cotações usa instrumentID, não o ticker; a resolução ticker→ID é cara,
/// então fica CACHEADA em `private/etoro_ids` (resolve o que falta, aos
/// poucos, e reусa). Degrada em silêncio se algo faltar — nunca derruba o
/// pipeline.
Future<void> syncEtoroRates() async {
  try {
    await _syncEtoroRates();
  } catch (e) {
    stdout.writeln('Cotações eToro: falha (${e.runtimeType}) — painel segue.');
  }
}

Future<void> _syncEtoroRates() async {
  final c = EtoroClient();
  if (!c.configurado) {
    stdout.writeln('Cotações eToro: chaves ausentes — pulando.');
    return;
  }
  final fs = await FirestoreRest.abrir();
  if (fs == null) {
    stdout.writeln('Cotações eToro: Firestore indisponível — pulando.');
    return;
  }
  try {
    // ticker → instrumentID (cache). ourId conhece o ticker via etoroPorIndicador.
    final tickers = <String>{
      for (final e in etoroPorIndicador.entries)
        if (e.value.ticker != null) e.value.ticker!,
    };
    final cache = await _lerCacheIds(fs);
    // ticker do eToro é comparado em MAIÚSCULAS com internalSymbolFull
    final faltantes = tickers.where((t) => !cache.containsKey(t)).toList();

    // resolve ticker→instrumentID paginando o CATÁLOGO (a busca por texto é
    // ignorada pela API; ela devolve o catálogo inteiro ordenado). ~7 páginas
    // de 2000 cobrem os ~12k instrumentos. Só roda quando falta algo; o
    // resultado fica cacheado em private/etoro_ids.
    var resolvidos = 0;
    if (faltantes.isNotEmpty) {
      final pendentes = {for (final t in faltantes) t.toUpperCase(): t};
      for (var page = 1; page <= 8 && pendentes.isNotEmpty; page++) {
        final r = await c.catalog(page: page, pageSize: 2000);
        if (!r.ok) break;
        final items = (json.decode(r.body)
            as Map<String, Object?>)['items'] as List?;
        if (items == null || items.isEmpty) break;
        for (final it in items) {
          if (it is! Map) continue;
          final sym = it['internalSymbolFull']?.toString().toUpperCase();
          final id = (it['instrumentId'] as num?)?.toInt();
          if (sym != null && id != null && pendentes.containsKey(sym)) {
            cache[pendentes.remove(sym)!] = id;
            resolvidos++;
          }
        }
        if (items.length < 2000) break; // última página
      }
    }
    if (resolvidos > 0) {
      await fs.patch('private/etoro_ids', {
        'atualizadoEm': DateTime.now().toUtc().toIso8601String(),
        'map': {for (final e in cache.entries) e.key: e.value},
      });
    }

    if (cache.isEmpty) {
      stdout.writeln('Cotações eToro: nenhum instrumentID resolvido ainda.');
      return;
    }

    // cotações (ask/bid) de todos os IDs conhecidos, em lotes
    final ids = cache.values.toSet().toList();
    final ask = <int, double>{}, bid = <int, double>{};
    for (var i = 0; i < ids.length; i += 60) {
      final lote = ids.sublist(i, (i + 60).clamp(0, ids.length));
      final rr = await c.rates(lote);
      if (!rr.ok) continue;
      final decoded = json.decode(rr.body);
      final list = decoded is Map
          ? (decoded['rates'] ?? decoded['Rates']) as List?
          : decoded as List?;
      for (final r in list ?? const []) {
        final m = r as Map;
        final id = (m['instrumentID'] ?? m['instrumentId']) as num?;
        if (id == null) continue;
        final iid = id.toInt();
        if (m['ask'] is num) ask[iid] = (m['ask'] as num).toDouble();
        if (m['bid'] is num) bid[iid] = (m['bid'] as num).toDouble();
      }
    }

    // mapeia de volta para os NOSSOS ids (o painel conhece por eles)
    final ratesByOurId = <String, Object?>{};
    for (final e in etoroPorIndicador.entries) {
      final tk = e.value.ticker;
      final id = tk == null ? null : cache[tk];
      if (id == null) continue;
      final a = ask[id], b = bid[id];
      if (a == null && b == null) continue;
      final mid = (a != null && b != null)
          ? (a + b) / 2
          : (a ?? b);
      ratesByOurId[e.key] = {
        if (a != null) 'ask': a,
        if (b != null) 'bid': b,
        'preco': mid,
      };
    }

    final status = await fs.patch('private/rates', {
      'atualizadoEm': DateTime.now().toUtc().toIso8601String(),
      'rates': ratesByOurId,
    });
    final semId = tickers.where((t) => !cache.containsKey(t)).toList();
    stdout.writeln('Cotações eToro: ${ratesByOurId.length} preços ao vivo '
        'gravados (HTTP $status; +$resolvidos IDs resolvidos, '
        '${cache.length}/${tickers.length} no cache'
        '${semId.isEmpty ? '' : '; sem ID: ${semId.join(', ')}'}).');
  } finally {
    fs.close();
  }
}

/// Lê o cache ticker→instrumentID do Firestore (`private/etoro_ids`).
Future<Map<String, int>> _lerCacheIds(FirestoreRest fs) async {
  try {
    final docs = await fs.listar('private');
    for (final (id, campos) in docs) {
      if (id != 'etoro_ids') continue;
      final map = (campos['map'] as Map?)?.cast<String, Object?>() ?? {};
      return {
        for (final e in map.entries)
          if (e.value is int) e.key: e.value as int
          else if (e.value is num) e.key: (e.value as num).toInt(),
      };
    }
  } catch (_) {/* sem cache ainda */}
  return {};
}

