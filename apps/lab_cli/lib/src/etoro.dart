/// Mapeamento indicador → instrumento no eToro.
///
/// Camada de apresentação/execução: o domínio nunca conhece corretora.
/// Tickers conferidos manualmente na plataforma; proxies marcados com nota.
class EtoroInstrument {
  const EtoroInstrument(this.ticker, [this.nota]);
  final String? ticker;
  final String? nota;
}

const Map<String, EtoroInstrument> etoroPorIndicador = {
  'sp500': EtoroInstrument('SPX500'),
  'nasdaq': EtoroInstrument(
      'NSDQ100', 'proxy: Nasdaq-100 (o indicador é o Composite)'),
  'ibovespa': EtoroInstrument('EWZ',
      'proxy: ETF iShares MSCI Brazil em USD — embute o efeito do câmbio'),
  'dax': EtoroInstrument('GER40'),
  'nikkei': EtoroInstrument('JPN225'),
  'dowjones': EtoroInstrument('DJ30'),
  'ftse100': EtoroInstrument('UK100'),
  'cac40': EtoroInstrument('FRA40'),
  'stoxx50': EtoroInstrument('EUSTX50'),
  'ouro': EtoroInstrument('GOLD'),
  'prata': EtoroInstrument('SILVER'),
  'cobre': EtoroInstrument('COPPER'),
  'petroleo_wti': EtoroInstrument('OIL'),
  'gas_natural': EtoroInstrument('NATGAS'),
  'bitcoin': EtoroInstrument('BTC'),
  'ethereum': EtoroInstrument('ETH'),
  'xrp': EtoroInstrument('XRP'),
  'solana': EtoroInstrument('SOL'),
  'cardano': EtoroInstrument('ADA'),
  'platina': EtoroInstrument('PLATINUM'),
  'paladio': EtoroInstrument('PALLADIUM',
      'confirme o nome exato do instrumento na busca do eToro'),
  'eurusd': EtoroInstrument('EURUSD'),
  'gbpusd': EtoroInstrument('GBPUSD'),
  'usdjpy': EtoroInstrument('USDJPY'),
  'dolar_ptax': EtoroInstrument(null, 'não há par USD/BRL no eToro'),
  'dxy': EtoroInstrument(null, 'o índice DXY não é negociável no eToro'),
  'milho': EtoroInstrument(null, 'sem milho no eToro'),
  'soja': EtoroInstrument(null, 'sem soja no eToro'),
};
