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
  'ibex35': EtoroInstrument('ESP35'),
  'ftsemib': EtoroInstrument('ITA40'),
  'smi': EtoroInstrument('SWI20'),
  'asx200': EtoroInstrument('AUS200'),
  'hangseng': EtoroInstrument('HK50',
      'confirme o nome exato do instrumento na busca do eToro'),
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
  'usdcad': EtoroInstrument('USDCAD'),
  'audusd': EtoroInstrument('AUDUSD'),
  'usdchf': EtoroInstrument('USDCHF'),
  'nzdusd': EtoroInstrument('NZDUSD'),
  'eurgbp': EtoroInstrument('EURGBP'),
  'litecoin': EtoroInstrument('LTC'),
  'bitcoincash': EtoroInstrument('BCH'),
  'chainlink': EtoroInstrument('LINK'),
  'dogecoin': EtoroInstrument('DOGE'),
  'polkadot': EtoroInstrument('DOT'),
  'dolar_ptax': EtoroInstrument(null, 'não há par USD/BRL no eToro'),
  'dxy': EtoroInstrument(null, 'o índice DXY não é negociável no eToro'),
  'milho': EtoroInstrument(null, 'sem milho no eToro'),
  'soja': EtoroInstrument(null, 'sem soja no eToro'),
};
