import 'frequency.dart';

/// Categorias da "tabela periódica da economia".
enum Category {
  politicaMonetaria('Monetary policy'),
  inflacao('Inflation'),
  atividade('Economic activity'),
  cambio('FX'),
  juros('Market rates'),
  commodities('Commodities'),
  acoes('Equity indices'),
  cripto('Crypto');

  const Category(this.label);
  final String label;
}

/// Camadas de confiança da fonte.
///
/// A = bancos centrais, institutos oficiais de estatística.
/// B = bolsas e mercados (preços negociados).
/// O nível C (interpretativo: notícias, opiniões) não existe neste sistema
/// por decisão de arquitetura.
enum SourceTier { a, b }

/// De onde vem a série. [provider] é a chave do adaptador de infraestrutura
/// ('bcb_sgs', 'yahoo'); [code] é o código da série naquele provedor.
class DataSource {
  const DataSource({
    required this.provider,
    required this.code,
    required this.tier,
  });

  final String provider;
  final String code;
  final SourceTier tier;
}

/// Um indicador da tabela periódica: universal, objetivo, mensurável e com
/// fonte oficial. Teste de admissão: "se a internet cair por um mês, esse
/// dado continua existindo oficialmente?"
class Indicator {
  const Indicator({
    required this.id,
    required this.nome,
    required this.unidade,
    required this.frequency,
    required this.category,
    required this.source,
    this.negociavel = false,
  });

  final String id;
  final String nome;
  final String unidade;
  final Frequency frequency;
  final Category category;
  final DataSource source;

  /// `true` quando a série é o preço de algo negociável (índice, commodity,
  /// moeda, cripto) — só esses viram oportunidades. Indicadores macro
  /// (Selic, IPCA...) alimentam regime e hipóteses, nunca "compra/venda".
  final bool negociavel;
}
