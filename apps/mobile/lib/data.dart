import 'dart:convert';

import 'package:http/http.dart' as http;

/// Fonte de dados do app: o MESMO dashboard.json que a nuvem publica a cada
/// 2h. O app é um cliente de apresentação — o motor roda no pipeline.
const dashboardUrl = 'https://quantlab-lde.web.app/data/dashboard.json';

class Dashboard {
  Dashboard(this.raw);
  final Map<String, dynamic> raw;

  String? get ultimaObservacao => raw['ultimaObservacao'] as String?;
  String? get geradoEm => raw['geradoEm'] as String?;
  Map<String, dynamic>? get macro => raw['macro'] as Map<String, dynamic>?;
  Map<String, dynamic>? get placar => raw['placar'] as Map<String, dynamic>?;
  List<dynamic> get radarPicos => (raw['radarPicos'] as List?) ?? const [];

  List<Map<String, dynamic>> oportunidades(String horizonte) {
    final h = (raw['horizontes'] as Map?)?[horizonte] as Map?;
    return ((h?['oportunidades'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
  }

  String horizonteLabel(String horizonte) {
    final h = (raw['horizontes'] as Map?)?[horizonte] as Map?;
    return (h?['label'] as String?) ?? horizonte;
  }

  static Future<Dashboard> carregar() async {
    final r = await http
        .get(Uri.parse(dashboardUrl))
        .timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) {
      throw Exception('HTTP ${r.statusCode} ao carregar o painel');
    }
    return Dashboard(json.decode(r.body) as Map<String, dynamic>);
  }
}

/// Perfis de risco — apenas rótulo + chave; a política (cortes, tetos,
/// risco por trade) vive no DOMÍNIO (quant_engine/PortfolioSizer) e chega
/// pronta no JSON como `carteiras`.
class Perfil {
  const Perfil(this.nome, this.chave);
  final String nome;
  final String chave;

  static const conservador = Perfil('Conservador', 'conservador');
  static const moderado = Perfil('Moderado', 'moderado');
  static const agressivo = Perfil('Agressivo', 'agressivo');
  static const todos = [conservador, moderado, agressivo];
}

/// Ordem dimensionada pelo domínio (peso e alavancagem vêm da carteira).
class Ordem {
  Ordem(this.o, this.peso, this.lev);
  final Map<String, dynamic> o;
  final double peso;
  final int lev;

  Map<String, dynamic> get rec =>
      (o['recomendacao'] as Map).cast<String, dynamic>();
  String get nome => o['nome'] as String? ?? '—';
  String? get ticker => (o['etoro'] as Map?)?['ticker'] as String?;
  bool get compra => rec['acao'] == 'comprar';
  double get assertividade => (rec['assertividade'] as num?)?.toDouble() ?? 0;
  double? get retornoEsperado => (rec['retornoEsperado'] as num?)?.toDouble();
  String get janela => rec['janelaRetorno'] as String? ?? '';
  int get base => (rec['base'] as num?)?.toInt() ?? 0;
  int get score => (o['score'] as num?)?.toInt() ?? 0;
  String get gatilho => rec['gatilho'] as String? ?? '';
}

/// Lê a carteira PRONTA do JSON (variante eToro) — zero regra no app.
({List<Ordem> ordens, double caixaPct}) ranking(
    Dashboard d, String horizonte, Perfil p) {
  final h = (d.raw['horizontes'] as Map?)?[horizonte] as Map?;
  final cart =
      ((h?['carteiras'] as Map?)?[p.chave] as Map?)?['etoro'] as Map?;
  if (cart == null) return (ordens: <Ordem>[], caixaPct: 1.0);

  final porId = <String, Map<String, dynamic>>{
    for (final o in d.oportunidades(horizonte)) o['id'] as String: o,
  };
  final ordens = <Ordem>[
    for (final w in (cart['ordens'] as List?) ?? const [])
      if (porId[(w as Map)['id']] != null)
        Ordem(
          porId[w['id']]!,
          (w['peso'] as num?)?.toDouble() ?? 0,
          (w['alavancagem'] as num?)?.toInt() ?? 1,
        ),
  ];
  return (
    ordens: ordens,
    caixaPct: ((cart['caixaPct'] as num?)?.toDouble() ?? 1).clamp(0, 1),
  );
}
