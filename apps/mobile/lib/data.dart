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

/// Perfis de risco (espelham o painel web): corte de assertividade e teto.
class Perfil {
  const Perfil(this.nome, this.corte, this.risco, this.maxPeso, this.teto);
  final String nome;
  final double corte;
  final double risco;
  final double maxPeso;
  final double teto;

  static const conservador = Perfil('Conservador', 0.65, 0.005, 0.15, 0.40);
  static const moderado = Perfil('Moderado', 0.55, 0.01, 0.25, 0.70);
  static const agressivo = Perfil('Agressivo', 0.55, 0.02, 0.35, 1.00);
  static const todos = [conservador, moderado, agressivo];
}

/// Ordem dimensionada (mesma lógica do web: risco fixo por trade → teto).
class Ordem {
  Ordem(this.o, this.peso);
  final Map<String, dynamic> o;
  final double peso;

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
  int get lev => (rec['alavancagemRecomendada'] as num?)?.toInt() ?? 1;
  String get gatilho => rec['gatilho'] as String? ?? '';
}

/// Ranking acionável para um horizonte + perfil (só ativos com eToro).
({List<Ordem> ordens, double caixaPct}) ranking(
    Dashboard d, String horizonte, Perfil p) {
  final ops = d.oportunidades(horizonte);
  final aprovadas = ops.where((o) {
    final rec = (o['recomendacao'] as Map?)?.cast<String, dynamic>();
    final acao = rec?['acao'];
    final ass = (rec?['assertividade'] as num?)?.toDouble() ?? 0;
    return (acao == 'comprar' || acao == 'vender') &&
        ass >= p.corte &&
        (o['etoro'] as Map?)?['ticker'] != null;
  }).toList()
    ..sort((a, b) {
      final ra = ((a['recomendacao'] as Map)['retornoEsperado'] as num?) ?? -9;
      final rb = ((b['recomendacao'] as Map)['retornoEsperado'] as num?) ?? -9;
      return rb.compareTo(ra);
    });

  var pesos = aprovadas.map((o) {
    final stop =
        ((o['recomendacao'] as Map)['stopEstimado'] as num?)?.toDouble() ??
            0.05;
    final w = p.risco / stop;
    return w < p.maxPeso ? w : p.maxPeso;
  }).toList();
  final soma = pesos.fold<double>(0, (a, b) => a + b);
  if (soma > p.teto) pesos = pesos.map((w) => w * p.teto / soma).toList();

  final ordens = [
    for (var i = 0; i < aprovadas.length; i++) Ordem(aprovadas[i], pesos[i]),
  ];
  final investido = pesos.fold<double>(0, (a, b) => a + b);
  return (ordens: ordens, caixaPct: (1 - investido).clamp(0, 1).toDouble());
}
