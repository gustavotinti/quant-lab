/// Assertividade de uma recomendação: uma única porcentagem honesta que
/// combina as evidências de eficácia disponíveis, ponderadas pelo tamanho
/// de cada amostra, com suavização de Laplace centrada em 50%.
///
///   assertividade = (wr·nT + fav·nA + 0,5·k) / (nT + nA + k),  k = 10
///
/// A suavização impede que amostras minúsculas produzam números
/// espetaculares: 6 acertos em 6 trades vira ~69%, não 100%.
class Assertividade {
  const Assertividade(this.valor, this.base);

  /// Fração em [0, 1].
  final double valor;

  /// Tamanho total da amostra por trás do número (trades + análogos).
  final int base;
}

Assertividade? assertividadeCombinada({
  double? winRate,
  int nTrades = 0,
  double? favoravel,
  int nAnalogos = 0,
  int pseudoAmostra = 10,
}) {
  final temWr = winRate != null && !winRate.isNaN && nTrades > 0;
  final temFav = favoravel != null && !favoravel.isNaN && nAnalogos > 0;
  if (!temWr && !temFav) return null;

  var acertos = 0.5 * pseudoAmostra;
  var total = pseudoAmostra.toDouble();
  if (temWr) {
    acertos += winRate * nTrades;
    total += nTrades;
  }
  if (temFav) {
    acertos += favoravel * nAnalogos;
    total += nAnalogos;
  }
  return Assertividade(
      acertos / total, (temWr ? nTrades : 0) + (temFav ? nAnalogos : 0));
}

/// Política de emissão: só vira ordem quando a evidência histórica está a
/// favor. Abaixo do corte, o sistema tem a humildade de ficar de fora.
enum Acao { comprar, vender, ficarDeFora, observar }

/// Ordem emitida a partir do Radar de Picos — usada quando as estratégias
/// clássicas NÃO têm sinal, mas o estado técnico esticado tem probabilidade
/// empírica de virada que passa no MESMO corte de assertividade do sistema.
///
/// Honestidade preservada: a probabilidade do radar já é empírica (fração
/// dos episódios históricos idênticos em que a virada veio); aqui ela só
/// ganha a mesma suavização de Laplace do resto do sistema (amostra de 16
/// nunca vira "81% de certeza") e precisa de mediana favorável (virada com
/// magnitude, não só contagem). Sem backtest fora da amostra → alavancagem
/// SEMPRE X1.
class EmissaoRadar {
  const EmissaoRadar({
    required this.compra,
    required this.assertividade,
    required this.retornoEsperado,
  });

  /// true = fundo detectado → COMPRA; false = topo → VENDA (short).
  final bool compra;
  final Assertividade assertividade;

  /// Mediana do retorno dos análogos NA DIREÇÃO apontada (~21 pregões).
  final double retornoEsperado;
}

EmissaoRadar? emissaoDoRadar({
  required String tipo,
  required double prob,
  required int n,
  required double medianaFwd21,
  double corte = 0.55,
  int nMin = 12,
}) {
  if (tipo != 'topo' && tipo != 'fundo') return null;
  if (n < nMin || prob.isNaN || medianaFwd21.isNaN) return null;
  final compra = tipo == 'fundo';
  // retorno na direção: num topo (venda), análogos caindo = retorno positivo
  final retDir = compra ? medianaFwd21 : -medianaFwd21;
  if (retDir <= 0) return null; // virada sem magnitude não paga o trade
  final ass = assertividadeCombinada(winRate: prob, nTrades: n);
  if (ass == null || ass.valor < corte) return null;
  return EmissaoRadar(
      compra: compra, assertividade: ass, retornoEsperado: retDir);
}

Acao decidirAcao({
  required bool compra,
  required bool venda,
  required Assertividade? assertividade,
  double corte = 0.55,
}) {
  if (!compra && !venda) return Acao.ficarDeFora;
  if (assertividade == null) return Acao.observar;
  if (assertividade.valor < corte) return Acao.ficarDeFora;
  return compra ? Acao.comprar : Acao.vender;
}
