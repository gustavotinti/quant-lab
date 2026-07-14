import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

/// Cliente somente-leitura da API pública do eToro.
///
/// As credenciais vêm SEMPRE do ambiente (segredos do pipeline) — nunca
/// ficam no código nem no repositório. Mapeamento de cabeçalhos validado
/// empiricamente contra a API: `x-api-key` = chave pública,
/// `x-user-key` = chave privada.
class EtoroClient {
  EtoroClient({http.Client? client, this.timeout = const Duration(seconds: 20)})
      : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  static const _host = 'public-api.etoro.com';

  String? get _api => Platform.environment['ETORO_KEY_PUBLICA'];
  String? get _user => Platform.environment['ETORO_KEY_PRIVADA'];
  String get ambiente =>
      Platform.environment['ETORO_ENVIRONMENT'] ?? 'não definido';

  /// `true` quando as duas chaves estão presentes no ambiente.
  bool get configurado =>
      (_api?.isNotEmpty ?? false) && (_user?.isNotEmpty ?? false);

  Map<String, String> _headers() => {
        'x-api-key': _api ?? '',
        'x-user-key': _user ?? '',
        'x-request-id': _uuid(),
        'Accept': 'application/json',
      };

  Future<EtoroResponse> _get(String path) async {
    try {
      // separa path de query — senão o `?` é codificado e vira rota inválida
      final parts = path.split('?');
      final query = parts.length > 1
          ? Uri.splitQueryString(parts[1])
          : const <String, String>{};
      final uri = Uri.https(
          _host, '/api/v1${parts[0]}', query.isEmpty ? null : query);
      final r =
          await _client.get(uri, headers: _headers()).timeout(timeout);
      return EtoroResponse(r.statusCode, r.body);
    } catch (e) {
      return EtoroResponse(-1, e.toString());
    }
  }

  /// Chamada barata de dados de mercado — serve para checar autenticação.
  Future<EtoroResponse> ping() => _get('/market-data/search?query=AAPL');

  /// Catálogo paginado de instrumentos. A busca por texto (`query`) é
  /// ignorada pela API — ela devolve o catálogo inteiro, ordenado; então
  /// paginamos para montar o mapa `internalSymbolFull` → `instrumentId`.
  Future<EtoroResponse> catalog({int page = 1, int pageSize = 2000}) =>
      _get('/market-data/search?page=$page&pageSize=$pageSize');

  /// Portfólio (posições abertas + P&L) do usuário da chave.
  Future<EtoroResponse> portfolio() => _get('/trading/info/portfolio');

  /// Metadados de instrumentos (id → nome). [ids] = lista de instrumentID.
  Future<EtoroResponse> instruments(Iterable<int> ids) =>
      _get('/market-data/instruments?instrumentIds=${ids.join(',')}');

  /// Cotações atuais (ask/bid) dos instrumentos.
  Future<EtoroResponse> rates(Iterable<int> ids) =>
      _get('/market-data/instruments/rates?instrumentIds=${ids.join(',')}');

  static String _uuid() {
    final r = Random();
    String hx(int n) =>
        List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
    return '${hx(8)}-${hx(4)}-4${hx(3)}-8${hx(3)}-${hx(12)}';
  }
}

class EtoroResponse {
  const EtoroResponse(this.status, this.body);
  final int status;
  final String body;
  bool get ok => status == 200;
}
