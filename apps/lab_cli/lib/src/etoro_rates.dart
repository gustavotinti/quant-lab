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
    final faltantes = tickers.where((t) => !cache.containsKey(t)).toList();

    // DIAGNÓSTICO temporário: imprime o FORMATO da resposta da busca (nomes
    // de campos + símbolos — dados públicos de mercado, sem PII) para acertar
    // o parser de ticker→instrumentID.
    if (Platform.environment['ETORO_DEBUG'] == '1' && faltantes.isNotEmpty) {
      final t = faltantes.first;
      final r = await c.search(t);
      stdout.writeln('DEBUG search("$t") HTTP ${r.status}');
      final corpo = r.body;
      stdout.writeln('DEBUG body[0..800]: '
          '${corpo.substring(0, corpo.length.clamp(0, 800))}');
    }

    // resolve só um lote por execução (evita martelar a busca); o cache
    // completa em poucas rodadas e depois é só cotação.
    var resolvidos = 0;
    for (final t in faltantes.take(18)) {
      final id = await _resolverId(c, t);
      if (id != null) {
        cache[t] = id;
        resolvidos++;
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
      final list =
          (json.decode(rr.body) as Map<String, Object?>)['rates'] as List?;
      for (final r in list ?? const []) {
        final m = r as Map;
        final id = (m['instrumentID'] as num?)?.toInt();
        if (id == null) continue;
        if (m['ask'] is num) ask[id] = (m['ask'] as num).toDouble();
        if (m['bid'] is num) bid[id] = (m['bid'] as num).toDouble();
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
    stdout.writeln('Cotações eToro: ${ratesByOurId.length} preços ao vivo '
        'gravados (HTTP $status; +$resolvidos IDs resolvidos, '
        '${cache.length}/${tickers.length} no cache).');
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

/// Resolve um ticker do eToro (ex.: 'NATGAS') no seu instrumentID via a
/// busca da API. Só aceita correspondência EXATA de símbolo — nada de chute.
Future<int?> _resolverId(EtoroClient c, String ticker) async {
  final r = await c.search(ticker);
  if (!r.ok) return null;
  Object? j;
  try {
    j = json.decode(r.body);
  } catch (_) {
    return null;
  }
  final candidatos = <Map<Object?, Object?>>[];
  void varrer(Object? x) {
    if (x is Map) {
      if (x['instrumentID'] is num || x['instrumentId'] is num) {
        candidatos.add(x);
      }
      x.values.forEach(varrer);
    } else if (x is List) {
      x.forEach(varrer);
    }
  }

  varrer(j);
  final alvo = ticker.toUpperCase();
  for (final m in candidatos) {
    final simbolos = [
      m['symbolFull'],
      m['symbol'],
      m['ticker'],
      m['instrumentDisplayName'],
    ].whereType<String>().map((s) => s.toUpperCase());
    if (simbolos.contains(alvo)) {
      final id = (m['instrumentID'] ?? m['instrumentId']) as num?;
      if (id != null) return id.toInt();
    }
  }
  return null;
}
