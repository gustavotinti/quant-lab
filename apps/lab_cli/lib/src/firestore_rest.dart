import 'dart:convert';
import 'dart:io';

import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

/// Cliente REST mínimo do Firestore para o pipeline (camada de aplicação —
/// NÃO é domínio). Autentica com a service account
/// (GOOGLE_APPLICATION_CREDENTIALS) e faz apenas o que precisamos: gravar um
/// documento (PATCH, idempotente por caminho) e listar uma coleção.
///
/// O domínio nunca vê isto; ele recebe/entrega objetos Dart puros.
class FirestoreRest {
  FirestoreRest._(this._client, this.project);

  final http.Client _client;
  final String project;

  /// Abre um cliente autenticado a partir do arquivo da service account.
  /// Retorna null se o caminho não existir (ex.: rodando local sem cofre) —
  /// o chamador decide degradar em silêncio.
  static Future<FirestoreRest?> abrir({
    String project = 'quantlab-lde',
    String? saPath,
  }) async {
    final path = saPath ?? Platform.environment['GOOGLE_APPLICATION_CREDENTIALS'];
    if (path == null || !File(path).existsSync()) return null;
    final creds = ServiceAccountCredentials.fromJson(
        json.decode(File(path).readAsStringSync()));
    final client = await clientViaServiceAccount(
        creds, const ['https://www.googleapis.com/auth/datastore']);
    return FirestoreRest._(client, project);
  }

  Uri _uri(String docPath, [Map<String, String>? query]) => Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$project/databases/'
        '(default)/documents/$docPath',
      ).replace(queryParameters: query);

  /// Grava (cria/sobrescreve) o documento em [docPath] com [campos].
  Future<int> patch(String docPath, Map<String, Object?> campos) async {
    final res = await _client.patch(_uri(docPath),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'fields': firestoreFields(campos)}));
    return res.statusCode;
  }

  /// Lista todos os documentos de [colecao], paginando. Devolve, para cada
  /// documento, o par (id, campos-Dart já decodificados).
  Future<List<(String id, Map<String, Object?> campos)>> listar(
      String colecao) async {
    final out = <(String, Map<String, Object?>)>[];
    String? pageToken;
    do {
      final res = await _client.get(_uri(colecao, {
        'pageSize': '300',
        if (pageToken != null) 'pageToken': pageToken,
      }));
      if (res.statusCode >= 300) {
        throw HttpException('Firestore list HTTP ${res.statusCode}: '
            '${res.body.substring(0, res.body.length.clamp(0, 200))}');
      }
      final body = json.decode(res.body) as Map<String, Object?>;
      final docs = (body['documents'] as List?) ?? const [];
      for (final d in docs) {
        final m = d as Map<String, Object?>;
        final name = (m['name'] as String?) ?? '';
        final id = name.contains('/') ? name.split('/').last : name;
        final fields = (m['fields'] as Map?)?.cast<String, Object?>() ?? {};
        out.add((id, parseFirestoreFields(fields)));
      }
      pageToken = body['nextPageToken'] as String?;
    } while (pageToken != null && pageToken.isNotEmpty);
    return out;
  }

  void close() => _client.close();
}

// ── Codec do formato tipado de valores do Firestore REST ──────────────────

Object firestoreValue(Object? v) {
  if (v == null) return {'nullValue': null};
  if (v is bool) return {'booleanValue': v};
  if (v is int) return {'integerValue': v.toString()};
  if (v is double) return {'doubleValue': v};
  if (v is String) return {'stringValue': v};
  if (v is List) {
    return {
      'arrayValue': {'values': [for (final e in v) firestoreValue(e)]}
    };
  }
  if (v is Map) {
    return {
      'mapValue': {'fields': firestoreFields(v.cast<String, Object?>())}
    };
  }
  return {'stringValue': v.toString()};
}

Map<String, Object?> firestoreFields(Map<String, Object?> m) =>
    {for (final e in m.entries) e.key: firestoreValue(e.value)};

Object? parseFirestoreValue(Object? v) {
  if (v is! Map) return null;
  if (v.containsKey('nullValue')) return null;
  if (v.containsKey('booleanValue')) return v['booleanValue'] as bool;
  if (v.containsKey('integerValue')) {
    return int.tryParse('${v['integerValue']}');
  }
  if (v.containsKey('doubleValue')) return (v['doubleValue'] as num).toDouble();
  if (v.containsKey('stringValue')) return v['stringValue'] as String;
  if (v.containsKey('timestampValue')) return v['timestampValue'] as String;
  if (v.containsKey('arrayValue')) {
    final vals = ((v['arrayValue'] as Map?)?['values'] as List?) ?? const [];
    return [for (final e in vals) parseFirestoreValue(e)];
  }
  if (v.containsKey('mapValue')) {
    final f = ((v['mapValue'] as Map?)?['fields'] as Map?)
            ?.cast<String, Object?>() ??
        {};
    return parseFirestoreFields(f);
  }
  return null;
}

Map<String, Object?> parseFirestoreFields(Map<String, Object?> fields) =>
    {for (final e in fields.entries) e.key: parseFirestoreValue(e.value)};
