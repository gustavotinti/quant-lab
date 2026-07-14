/// Perfil de risco — Value Object com a política de dimensionamento.
class PerfilRisco {
  const PerfilRisco({
    required this.nome,
    required this.corteAssertividade,
    required this.riscoPorTrade,
    required this.maxPesoAtivo,
    required this.tetoInvestido,
    required this.alavancagemMax,
  });

  final String nome;

  /// Assertividade mínima para uma ordem ser emitida (ex.: 0,55).
  final double corteAssertividade;

  /// Risco máximo por trade como fração do capital (ex.: 0,01 = 1%).
  final double riscoPorTrade;

  /// Peso máximo de um único ativo (ex.: 0,25 = 25%).
  final double maxPesoAtivo;

  /// Fração máxima do capital investida (o resto é caixa).
  final double tetoInvestido;

  /// Teto de alavancagem que o perfil aceita (limita a recomendada).
  final int alavancagemMax;

  static const conservador = PerfilRisco(
      nome: 'conservador',
      corteAssertividade: 0.65,
      riscoPorTrade: 0.005,
      maxPesoAtivo: 0.15,
      tetoInvestido: 0.40,
      alavancagemMax: 1);
  static const moderado = PerfilRisco(
      nome: 'moderado',
      corteAssertividade: 0.55,
      riscoPorTrade: 0.01,
      maxPesoAtivo: 0.25,
      tetoInvestido: 0.70,
      alavancagemMax: 2);
  static const agressivo = PerfilRisco(
      nome: 'agressivo',
      corteAssertividade: 0.55,
      riscoPorTrade: 0.02,
      maxPesoAtivo: 0.35,
      tetoInvestido: 1.00,
      alavancagemMax: 5);
  static const todos = [conservador, moderado, agressivo];
}

/// Candidato a ordem — entrada do sizer, em primitivos (não acopla ao
/// formato do JSON nem ao domínio rico; a política só precisa disto).
class CandidatoOrdem {
  const CandidatoOrdem({
    required this.id,
    required this.categoria,
    required this.assertividade,
    required this.stopEstimado,
    required this.alavancagemRecomendada,
    required this.retornoEsperado,
  });

  final String id;
  final String categoria;
  final double assertividade;
  final double stopEstimado;
  final int alavancagemRecomendada;
  final double retornoEsperado;
}

/// Ordem já dimensionada. [peso] é a fração de EXPOSIÇÃO do capital; o valor
/// em dinheiro (peso × capital) é responsabilidade da apresentação.
class OrdemDimensionada {
  const OrdemDimensionada(this.id, this.peso, this.alavancagem);
  final String id;
  final double peso;
  final int alavancagem;
}

class Carteira {
  const Carteira(this.ordens, this.caixaPct);
  final List<OrdemDimensionada> ordens;
  final double caixaPct;
}

/// Política de dimensionamento de carteira — ÚNICA fonte da verdade das
/// regras de alocação (risco fixo por trade → teto do perfil → teto por
/// classe de ativo → caixa). Domínio puro: sem I/O, sem capital, sem
/// conhecer JSON, HTTP, Flutter ou eToro.
class PortfolioSizer {
  const PortfolioSizer();

  Carteira dimensionar(List<CandidatoOrdem> candidatos, PerfilRisco p) {
    final aprovados = candidatos
        .where((c) => c.assertividade >= p.corteAssertividade)
        .toList()
      ..sort((a, b) => b.retornoEsperado.compareTo(a.retornoEsperado));
    if (aprovados.isEmpty) return const Carteira([], 1);

    // 1. risco fixo por trade → peso = risco / stop, limitado por ativo
    var pesos = [
      for (final c in aprovados)
        _min(p.riscoPorTrade / (c.stopEstimado <= 0 ? 0.05 : c.stopEstimado),
            p.maxPesoAtivo),
    ];

    // 2. teto global investido do perfil (renormaliza)
    final soma = pesos.fold<double>(0, (a, b) => a + b);
    if (soma > p.tetoInvestido) {
      pesos = [for (final w in pesos) w * p.tetoInvestido / soma];
    }

    // 3. teto por CLASSE de ativo = metade do teto investido
    final catCap = p.tetoInvestido / 2;
    final porCat = <String, double>{};
    for (var i = 0; i < aprovados.length; i++) {
      porCat[aprovados[i].categoria] =
          (porCat[aprovados[i].categoria] ?? 0) + pesos[i];
    }
    for (var i = 0; i < aprovados.length; i++) {
      final cat = aprovados[i].categoria;
      final total = porCat[cat] ?? 0;
      if (total > catCap) pesos[i] *= catCap / total;
    }

    final ordens = [
      for (var i = 0; i < aprovados.length; i++)
        OrdemDimensionada(aprovados[i].id, pesos[i],
            _minInt(aprovados[i].alavancagemRecomendada, p.alavancagemMax)),
    ];
    final investido = pesos.fold<double>(0, (a, b) => a + b);
    return Carteira(ordens, (1 - investido).clamp(0.0, 1.0).toDouble());
  }

  static double _min(double a, double b) => a < b ? a : b;
  static int _minInt(int a, int b) => a < b ? a : b;
}
