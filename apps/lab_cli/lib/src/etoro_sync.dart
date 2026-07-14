import 'dart:convert';
import 'dart:io';

import 'package:quant_market_data/quant_market_data.dart';

import 'firestore_rest.dart';

/// Lê o portfólio real do eToro e grava num documento PRIVADO do Firestore
/// (`private/portfolio`), que só o dono lê logado (ver firestore.rules).
///
/// Roda no pipeline (GitHub Actions), onde existem as chaves do eToro e a
/// credencial da service account (GOOGLE_APPLICATION_CREDENTIALS). Não faz
/// nada — silenciosamente — se algo não estiver configurado, para nunca
/// derrubar a atualização normal do painel.
Future<void> syncEtoroPortfolio() async {
  try {
    await _syncEtoroPortfolio();
  } catch (e) {
    // qualquer imprevisto (rede, JSON inesperado, auth) não pode derrubar
    // o pipeline — apenas registra e segue.
    stdout.writeln('eToro: sincronização falhou (${e.runtimeType}) — '
        'painel segue normal.');
  }
}

Future<void> _syncEtoroPortfolio() async {
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

  // cotações atuais (ask/bid) para P&L e status ao vivo
  final ask = <int, double>{};
  final bid = <int, double>{};
  if (ids.isNotEmpty) {
    final rr = await c.rates(ids);
    if (rr.ok) {
      final list =
          (json.decode(rr.body) as Map<String, Object?>)['rates'] as List?;
      for (final r in list ?? const []) {
        final m = r as Map;
        final id = (m['instrumentID'] as num?)?.toInt();
        if (id != null) {
          if (m['ask'] is num) ask[id] = (m['ask'] as num).toDouble();
          if (m['bid'] is num) bid[id] = (m['bid'] as num).toDouble();
        }
      }
    }
  }

  double? num2(Object? v) => v is num ? v.toDouble() : null;
  final posicoes = <Map<String, Object?>>[
    for (final p in rawPos)
      if (p is Map)
        () {
          final id = (p['instrumentID'] as num?)?.toInt();
          final isBuy = p['isBuy'] == true;
          // long fecha no bid (venda); short fecha no ask (recompra)
          final atual = id == null ? null : (isBuy ? bid[id] : ask[id]);
          return {
            'instrumentID': id,
            'nome': nomes[id] ?? 'Instrumento ${p['instrumentID']}',
            'isBuy': isBuy,
            'openRate': num2(p['openRate']),
            'currentRate': atual,
            'stopLoss': num2(p['stopLossRate']),
            'takeProfit': num2(p['takeProfitRate']),
            'amount': num2(p['amount']),
            'leverage': (p['leverage'] as num?)?.toInt() ?? 1,
            'units': num2(p['units']),
            'openDate': p['openDateTime']?.toString(),
          };
        }(),
  ];

  final doc = {
    'atualizadoEm': DateTime.now().toUtc().toIso8601String(),
    'credit': num2(cp?['credit']),
    'nPosicoes': posicoes.length,
    'posicoes': posicoes,
  };

  final fs = await FirestoreRest.abrir(saPath: saPath);
  if (fs == null) {
    stdout.writeln('eToro: Firestore indisponível — pulando gravação.');
    return;
  }
  try {
    final status = await fs.patch('private/portfolio', doc);
    if (status >= 300) {
      stdout.writeln('eToro: Firestore write HTTP $status.');
      return;
    }
  } finally {
    fs.close();
  }
  stdout.writeln('eToro: ${posicoes.length} posições sincronizadas '
      '(privado, Firestore).');
}
