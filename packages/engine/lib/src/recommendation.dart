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
