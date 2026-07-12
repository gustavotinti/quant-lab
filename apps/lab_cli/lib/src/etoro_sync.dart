import 'dart:convert';
import 'dart:io';

import 'package:googleapis_auth/auth_io.dart';
import 'package:quant_market_data/quant_market_data.dart';

/// Lê o portfólio real do eToro e grava num documento PRIVADO do Firestore
/// (`private/portfolio`), que só o dono lê logado (ver firestore.rules).
///
/// Roda no pipeline (GitHub Actions), onde existem as chaves do eToro e a
/// credencial da service account (GOOGLE_APPLICATION_CREDENTIALS). Não faz
/// nada — silenciosamente — se algo não estiver configurado, para nunca
/// derrubar a atualização normal do painel.
Future<void> syncEtoroPortfolio() async {
  final c = EtoroClient();
  if (!c.configurado) {
    stdout.writeln('eToro: chaves ausentes — pulando sincronização.');
    return;
  }
  final saPath = Platform.environment['GOOGLE_APPLICATION_CREDENTIALS'];
  if (saPath == null || !File(saPath).existsSync()) {
    stdout.writeln('eToro: credencial da service account ausente — pulando.');
    return;
  }

  final pr = await c.portfolio();
  if (!pr.ok) {
    stdout.writeln('eToro: portfólio HTTP ${pr.status} — pulando.');
    return;
  }

  final root = json.decode(pr.body) as Map<String, Object?>;
  final cp = root['clientPortfolio'] as Map<String, Object?>?;
  final rawPos = (cp?['positions'] as List?) ?? const [];

  // resolve os nomes dos instrumentos (id → nome)
  final ids = <int>{
    for (final p in rawPos)
      if ((p as Map)['instrumentID'] is num) (p['instrumentID'] as num).toInt(),
  };
  final nomes = <int, String>{};
  if (ids.isNotEmpty) {
    final ir = await c.instruments(ids);
    if (ir.ok) {
      final list = (json.decode(ir.body)
          as Map<String, Object?>)['instrumentDisplayDatas'] as List?;
      for (final d in list ?? const []) {
        final m = d as Map;
        if (m['instrumentID'] is num) {
          nomes[(m['instrumentID'] as num).toInt()] =
              (m['instrumentDisplayName'] as String?) ?? '';
        }
      }
    }
  }

  double? num2(Object? v) => v is num ? v.toDouble() : null;
  final posicoes = <Map<String, Object?>>[
    for (final p in rawPos)
      if (p is Map)
        {
          'instrumentID': (p['instrumentID'] as num?)?.toInt(),
          'nome': nomes[(p['instrumentID'] as num?)?.toInt()] ??
              'Instrumento ${p['instrumentID']}',
          'isBuy': p['isBuy'] == true,
          'openRate': num2(p['openRate']),
          'stopLoss': num2(p['stopLossRate']),
          'takeProfit': num2(p['takeProfitRate']),
          'amount': num2(p['amount']),
          'leverage': (p['leverage'] as num?)?.toInt() ?? 1,
          'units': num2(p['units']),
          'openDate': p['openDateTime']?.toString(),
        },
  ];

  final doc = {
    'atualizadoEm': DateTime.now().toUtc().toIso8601String(),
    'credit': num2(cp?['credit']),
    'nPosicoes': posicoes.length,
    'posicoes': posicoes,
  };

  await _gravarFirestore(saPath, doc);
  stdout.writeln('eToro: ${posicoes.length} posições sincronizadas '
      '(privado, Firestore).');
}

/// Grava [doc] em `private/portfolio` via REST do Firestore, autenticando
/// com a service account.
Future<void> _gravarFirestore(
    String saPath, Map<String, Object?> doc) async {
  final creds = ServiceAccountCredentials.fromJson(
      json.decode(File(saPath).readAsStringSync()));
  final client = await clientViaServiceAccount(
      creds, const ['https://www.googleapis.com/auth/datastore']);
  try {
    const project = 'quantlab-lde';
    final uri = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$project/databases/'
        '(default)/documents/private/portfolio');
    final res = await client.patch(uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'fields': _toFields(doc)}));
    if (res.statusCode >= 300) {
      stdout.writeln('Firestore write HTTP ${res.statusCode}: '
          '${res.body.replaceAll(RegExp(r"\s+"), " ").substring(0, res.body.length.clamp(0, 200))}');
    }
  } finally {
    client.close();
  }
}

/// Converte um valor Dart no formato tipado de documento do Firestore REST.
Object _toValue(Object? v) {
  if (v == null) return {'nullValue': null};
  if (v is bool) return {'booleanValue': v};
  if (v is int) return {'integerValue': v.toString()};
  if (v is double) return {'doubleValue': v};
  if (v is String) return {'stringValue': v};
  if (v is List) {
    return {
      'arrayValue': {'values': [for (final e in v) _toValue(e)]}
    };
  }
  if (v is Map) {
    return {
      'mapValue': {'fields': _toFields(v.cast<String, Object?>())}
    };
  }
  return {'stringValue': v.toString()};
}

Map<String, Object?> _toFields(Map<String, Object?> m) =>
    {for (final e in m.entries) e.key: _toValue(e.value)};
