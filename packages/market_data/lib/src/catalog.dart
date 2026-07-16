import 'package:quant_core/quant_core.dart';

/// A "tabela periódica" inicial: poucos indicadores, todos universais,
/// objetivos, mensuráveis e com fonte oficial/gratuita, validados um a um
/// contra as APIs em 2026-07.
///
/// Nível A = Banco Central do Brasil (SGS). Nível B = preços de mercado
/// (Yahoo Finance como transporte; a fonte primária é a própria bolsa).
const _bcb = 'bcb_sgs';
const _yahoo = 'yahoo';
const _fred = 'fred';

final List<Indicator> catalogoInicial = List.unmodifiable(<Indicator>[
  // ── Política monetária e inflação (nível A) ────────────────────────────
  const Indicator(
    id: 'selic_meta',
    nome: 'Selic (meta)',
    unidade: '% a.a.',
    frequency: Frequency.daily,
    category: Category.politicaMonetaria,
    source: DataSource(provider: _bcb, code: '432', tier: SourceTier.a),
  ),
  const Indicator(
    id: 'cdi_anualizado',
    nome: 'CDI anualizado',
    unidade: '% a.a.',
    frequency: Frequency.daily,
    category: Category.politicaMonetaria,
    source: DataSource(provider: _bcb, code: '4389', tier: SourceTier.a),
  ),
  const Indicator(
    id: 'ipca_mensal',
    nome: 'IPCA (variação mensal)',
    unidade: '% a.m.',
    frequency: Frequency.monthly,
    category: Category.inflacao,
    source: DataSource(provider: _bcb, code: '433', tier: SourceTier.a),
  ),
  const Indicator(
    id: 'igpm_mensal',
    nome: 'IGP-M (variação mensal)',
    unidade: '% a.m.',
    frequency: Frequency.monthly,
    category: Category.inflacao,
    source: DataSource(provider: _bcb, code: '189', tier: SourceTier.a),
  ),
  const Indicator(
    id: 'inpc_mensal',
    nome: 'INPC (variação mensal)',
    unidade: '% a.m.',
    frequency: Frequency.monthly,
    category: Category.inflacao,
    source: DataSource(provider: _bcb, code: '188', tier: SourceTier.a),
  ),
  const Indicator(
    id: 'base_monetaria',
    nome: 'Base monetária (média nos dias úteis)',
    unidade: 'R\$ mil',
    frequency: Frequency.monthly,
    category: Category.politicaMonetaria,
    source: DataSource(provider: _bcb, code: '1788', tier: SourceTier.a),
  ),
  const Indicator(
    id: 'm2',
    nome: 'M2 (saldo em final de período)',
    unidade: 'R\$ mil',
    frequency: Frequency.monthly,
    category: Category.politicaMonetaria,
    source: DataSource(provider: _bcb, code: '27810', tier: SourceTier.a),
  ),
  const Indicator(
    id: 'icbr',
    nome: 'IC-Br (commodities em reais)',
    unidade: 'índice',
    frequency: Frequency.monthly,
    category: Category.commodities,
    source: DataSource(provider: _bcb, code: '27574', tier: SourceTier.a),
  ),

  // ── Atividade e setor externo (nível A) ────────────────────────────────
  const Indicator(
    id: 'desemprego_pnadc',
    nome: 'Taxa de desocupação (PNAD Contínua)',
    unidade: '%',
    frequency: Frequency.monthly,
    category: Category.atividade,
    source: DataSource(provider: _bcb, code: '24369', tier: SourceTier.a),
  ),
  const Indicator(
    id: 'ibc_br',
    nome: 'IBC-Br (proxy mensal do PIB)',
    unidade: 'índice',
    frequency: Frequency.monthly,
    category: Category.atividade,
    source: DataSource(provider: _bcb, code: '24363', tier: SourceTier.a),
  ),
  const Indicator(
    id: 'reservas_internacionais',
    nome: 'Reservas internacionais',
    unidade: 'US\$ milhões',
    frequency: Frequency.monthly,
    category: Category.atividade,
    source: DataSource(provider: _bcb, code: '3546', tier: SourceTier.a),
  ),

  // ── Câmbio ─────────────────────────────────────────────────────────────
  const Indicator(
    id: 'dolar_ptax',
    nome: 'Dólar PTAX (venda)',
    unidade: 'BRL',
    frequency: Frequency.daily,
    category: Category.cambio,
    source: DataSource(provider: _bcb, code: '1', tier: SourceTier.a),
    negociavel: true,
  ),
  const Indicator(
    id: 'dxy',
    nome: 'Índice do dólar (DXY)',
    unidade: 'índice',
    frequency: Frequency.daily,
    category: Category.cambio,
    source: DataSource(
        provider: _yahoo, code: 'DX-Y.NYB', tier: SourceTier.b),
    negociavel: true,
  ),

  // ── Juros de mercado ───────────────────────────────────────────────────
  const Indicator(
    id: 'us10y',
    nome: 'Treasury 10 anos (yield)',
    unidade: '% a.a.',
    frequency: Frequency.daily,
    category: Category.juros,
    source: DataSource(provider: _yahoo, code: '^TNX', tier: SourceTier.b),
  ),

  // ── EUA / internacional via FRED (nível A) ─────────────────────────────
  // Requer FRED_API_KEY (chave gratuita). Sem a chave, o update reporta o
  // erro nestes 4 e o resto do laboratório segue normal.
  const Indicator(
    id: 'fed_funds',
    nome: 'Fed Funds (taxa básica EUA)',
    unidade: '% a.a.',
    frequency: Frequency.monthly,
    category: Category.politicaMonetaria,
    source: DataSource(provider: _fred, code: 'FEDFUNDS', tier: SourceTier.a),
  ),
  const Indicator(
    id: 'us_cpi',
    nome: 'CPI EUA (índice de preços)',
    unidade: 'índice',
    frequency: Frequency.monthly,
    category: Category.inflacao,
    source: DataSource(provider: _fred, code: 'CPIAUCSL', tier: SourceTier.a),
  ),
  const Indicator(
    id: 'us2y',
    nome: 'Treasury 2 anos (yield)',
    unidade: '% a.a.',
    frequency: Frequency.daily,
    category: Category.juros,
    source: DataSource(provider: _fred, code: 'DGS2', tier: SourceTier.a),
  ),
  const Indicator(
    id: 'ecb_deposito',
    nome: 'BCE — taxa de depósito (zona do euro)',
    unidade: '% a.a.',
    frequency: Frequency.daily,
    category: Category.politicaMonetaria,
    source: DataSource(provider: _fred, code: 'ECBDFR', tier: SourceTier.a),
  ),

  // ── Índices amplos de ações ────────────────────────────────────────────
  const Indicator(
    id: 'sp500',
    nome: 'S&P 500',
    unidade: 'pontos',
    frequency: Frequency.daily,
    category: Category.acoes,
    source: DataSource(provider: _yahoo, code: '^GSPC', tier: SourceTier.b),
    negociavel: true,
  ),
  const Indicator(
    id: 'nasdaq',
    nome: 'Nasdaq Composite',
    unidade: 'pontos',
    frequency: Frequency.daily,
    category: Category.acoes,
    source: DataSource(provider: _yahoo, code: '^IXIC', tier: SourceTier.b),
    negociavel: true,
  ),
  const Indicator(
    id: 'ibovespa',
    nome: 'Ibovespa',
    unidade: 'pontos',
    frequency: Frequency.daily,
    category: Category.acoes,
    source: DataSource(provider: _yahoo, code: '^BVSP', tier: SourceTier.b),
    negociavel: true,
  ),

  const Indicator(
    id: 'dax',
    nome: 'DAX (Alemanha)',
    unidade: 'pontos',
    frequency: Frequency.daily,
    category: Category.acoes,
    source: DataSource(provider: _yahoo, code: '^GDAXI', tier: SourceTier.b),
    negociavel: true,
  ),
  const Indicator(
    id: 'nikkei',
    nome: 'Nikkei 225 (Japão)',
    unidade: 'pontos',
    frequency: Frequency.daily,
    category: Category.acoes,
    source: DataSource(provider: _yahoo, code: '^N225', tier: SourceTier.b),
    negociavel: true,
  ),
  const Indicator(
    id: 'dowjones',
    nome: 'Dow Jones Industrial',
    unidade: 'pontos',
    frequency: Frequency.daily,
    category: Category.acoes,
    source: DataSource(provider: _yahoo, code: '^DJI', tier: SourceTier.b),
    negociavel: true,
  ),
  const Indicator(
    id: 'ftse100',
    nome: 'FTSE 100 (Reino Unido)',
    unidade: 'pontos',
    frequency: Frequency.daily,
    category: Category.acoes,
    source: DataSource(provider: _yahoo, code: '^FTSE', tier: SourceTier.b),
    negociavel: true,
  ),
  const Indicator(
    id: 'cac40',
    nome: 'CAC 40 (França)',
    unidade: 'pontos',
    frequency: Frequency.daily,
    category: Category.acoes,
    source: DataSource(provider: _yahoo, code: '^FCHI', tier: SourceTier.b),
    negociavel: true,
  ),
  const Indicator(
    id: 'stoxx50',
    nome: 'Euro Stoxx 50',
    unidade: 'pontos',
    frequency: Frequency.daily,
    category: Category.acoes,
    source: DataSource(
        provider: _yahoo, code: '^STOXX50E', tier: SourceTier.b),
    negociavel: true,
  ),
  const Indicator(
    id: 'ibex35',
    nome: 'IBEX 35 (Espanha)',
    unidade: 'pontos',
    frequency: Frequency.daily,
    category: Category.acoes,
    source: DataSource(provider: _yahoo, code: '^IBEX', tier: SourceTier.b),
    negociavel: true,
  ),
  const Indicator(
    id: 'ftsemib',
    nome: 'FTSE MIB (Itália)',
    unidade: 'pontos',
    frequency: Frequency.daily,
    category: Category.acoes,
    source: DataSource(
        provider: _yahoo, code: 'FTSEMIB.MI', tier: SourceTier.b),
    negociavel: true,
  ),
  const Indicator(
    id: 'smi',
    nome: 'SMI (Suíça)',
    unidade: 'pontos',
    frequency: Frequency.daily,
    category: Category.acoes,
    source: DataSource(provider: _yahoo, code: '^SSMI', tier: SourceTier.b),
    negociavel: true,
  ),
  const Indicator(
    id: 'asx200',
    nome: 'ASX 200 (Austrália)',
    unidade: 'pontos',
    frequency: Frequency.daily,
    category: Category.acoes,
    source: DataSource(provider: _yahoo, code: '^AXJO', tier: SourceTier.b),
    negociavel: true,
  ),
  const Indicator(
    id: 'hangseng',
    nome: 'Hang Seng (Hong Kong)',
    unidade: 'pontos',
    frequency: Frequency.daily,
    category: Category.acoes,
    source: DataSource(provider: _yahoo, code: '^HSI', tier: SourceTier.b),
    negociavel: true,
  ),

  // ── Commodities ────────────────────────────────────────────────────────
  const Indicator(
    id: 'ouro',
    nome: 'Ouro (futuro COMEX)',
    unidade: 'US\$/oz',
    frequency: Frequency.daily,
    category: Category.commodities,
    source: DataSource(provider: _yahoo, code: 'GC=F', tier: SourceTier.b),
    negociavel: true,
  ),
  const Indicator(
    id: 'prata',
    nome: 'Prata (futuro COMEX)',
    unidade: 'US\$/oz',
    frequency: Frequency.daily,
    category: Category.commodities,
    source: DataSource(provider: _yahoo, code: 'SI=F', tier: SourceTier.b),
    negociavel: true,
  ),
  const Indicator(
    id: 'platina',
    nome: 'Platina (futuro NYMEX)',
    unidade: 'US\$/oz',
    frequency: Frequency.daily,
    category: Category.commodities,
    source: DataSource(provider: _yahoo, code: 'PL=F', tier: SourceTier.b),
    negociavel: true,
  ),
  const Indicator(
    id: 'paladio',
    nome: 'Paládio (futuro NYMEX)',
    unidade: 'US\$/oz',
    frequency: Frequency.daily,
    category: Category.commodities,
    source: DataSource(provider: _yahoo, code: 'PA=F', tier: SourceTier.b),
    negociavel: true,
  ),
  const Indicator(
    id: 'petroleo_wti',
    nome: 'Petróleo WTI (futuro NYMEX)',
    unidade: 'US\$/barril',
    frequency: Frequency.daily,
    category: Category.commodities,
    source: DataSource(provider: _yahoo, code: 'CL=F', tier: SourceTier.b),
    negociavel: true,
  ),
  const Indicator(
    id: 'gas_natural',
    nome: 'Gás natural (futuro NYMEX)',
    unidade: 'US\$/MMBtu',
    frequency: Frequency.daily,
    category: Category.commodities,
    source: DataSource(provider: _yahoo, code: 'NG=F', tier: SourceTier.b),
    negociavel: true,
  ),
  const Indicator(
    id: 'milho',
    nome: 'Milho (futuro CBOT)',
    unidade: 'cents/bushel',
    frequency: Frequency.daily,
    category: Category.commodities,
    source: DataSource(provider: _yahoo, code: 'ZC=F', tier: SourceTier.b),
    negociavel: true,
  ),
  const Indicator(
    id: 'soja',
    nome: 'Soja (futuro CBOT)',
    unidade: 'cents/bushel',
    frequency: Frequency.daily,
    category: Category.commodities,
    source: DataSource(provider: _yahoo, code: 'ZS=F', tier: SourceTier.b),
    negociavel: true,
  ),
  const Indicator(
    id: 'cobre',
    nome: 'Cobre (futuro COMEX)',
    unidade: 'US\$/lb',
    frequency: Frequency.daily,
    category: Category.commodities,
    source: DataSource(provider: _yahoo, code: 'HG=F', tier: SourceTier.b),
    negociavel: true,
  ),

  // ── Cripto ─────────────────────────────────────────────────────────────
  const Indicator(
    id: 'bitcoin',
    nome: 'Bitcoin',
    unidade: 'US\$',
    frequency: Frequency.daily,
    category: Category.cripto,
    source: DataSource(
        provider: _yahoo, code: 'BTC-USD', tier: SourceTier.b),
    negociavel: true,
  ),
  const Indicator(
    id: 'ethereum',
    nome: 'Ethereum',
    unidade: 'US\$',
    frequency: Frequency.daily,
    category: Category.cripto,
    source: DataSource(
        provider: _yahoo, code: 'ETH-USD', tier: SourceTier.b),
    negociavel: true,
  ),
  const Indicator(
    id: 'xrp',
    nome: 'XRP',
    unidade: 'US\$',
    frequency: Frequency.daily,
    category: Category.cripto,
    source: DataSource(
        provider: _yahoo, code: 'XRP-USD', tier: SourceTier.b),
    negociavel: true,
  ),
  const Indicator(
    id: 'solana',
    nome: 'Solana',
    unidade: 'US\$',
    frequency: Frequency.daily,
    category: Category.cripto,
    source: DataSource(
        provider: _yahoo, code: 'SOL-USD', tier: SourceTier.b),
    negociavel: true,
  ),
  const Indicator(
    id: 'cardano',
    nome: 'Cardano',
    unidade: 'US\$',
    frequency: Frequency.daily,
    category: Category.cripto,
    source: DataSource(
        provider: _yahoo, code: 'ADA-USD', tier: SourceTier.b),
    negociavel: true,
  ),

  // ── FX majors (negociáveis no eToro) ───────────────────────────────────
  const Indicator(
    id: 'eurusd',
    nome: 'Euro/Dólar (EUR/USD)',
    unidade: 'US\$',
    frequency: Frequency.daily,
    category: Category.cambio,
    source: DataSource(
        provider: _yahoo, code: 'EURUSD=X', tier: SourceTier.b),
    negociavel: true,
  ),
  const Indicator(
    id: 'gbpusd',
    nome: 'Libra/Dólar (GBP/USD)',
    unidade: 'US\$',
    frequency: Frequency.daily,
    category: Category.cambio,
    source: DataSource(
        provider: _yahoo, code: 'GBPUSD=X', tier: SourceTier.b),
    negociavel: true,
  ),
  const Indicator(
    id: 'usdjpy',
    nome: 'Dólar/Iene (USD/JPY)',
    unidade: 'JPY',
    frequency: Frequency.daily,
    category: Category.cambio,
    source: DataSource(provider: _yahoo, code: 'JPY=X', tier: SourceTier.b),
    negociavel: true,
  ),
  const Indicator(
    id: 'usdcad',
    nome: 'Dólar/Dólar Canadense (USD/CAD)',
    unidade: 'CAD',
    frequency: Frequency.daily,
    category: Category.cambio,
    source: DataSource(provider: _yahoo, code: 'CAD=X', tier: SourceTier.b),
    negociavel: true,
  ),
  const Indicator(
    id: 'audusd',
    nome: 'Dólar Australiano (AUD/USD)',
    unidade: 'US\$',
    frequency: Frequency.daily,
    category: Category.cambio,
    source: DataSource(
        provider: _yahoo, code: 'AUDUSD=X', tier: SourceTier.b),
    negociavel: true,
  ),
  const Indicator(
    id: 'usdchf',
    nome: 'Dólar/Franco Suíço (USD/CHF)',
    unidade: 'CHF',
    frequency: Frequency.daily,
    category: Category.cambio,
    source: DataSource(provider: _yahoo, code: 'CHF=X', tier: SourceTier.b),
    negociavel: true,
  ),
  const Indicator(
    id: 'nzdusd',
    nome: 'Dólar Neozelandês (NZD/USD)',
    unidade: 'US\$',
    frequency: Frequency.daily,
    category: Category.cambio,
    source: DataSource(
        provider: _yahoo, code: 'NZDUSD=X', tier: SourceTier.b),
    negociavel: true,
  ),
  const Indicator(
    id: 'eurgbp',
    nome: 'Euro/Libra (EUR/GBP)',
    unidade: 'GBP',
    frequency: Frequency.daily,
    category: Category.cambio,
    source: DataSource(
        provider: _yahoo, code: 'EURGBP=X', tier: SourceTier.b),
    negociavel: true,
  ),
  const Indicator(
    id: 'litecoin',
    nome: 'Litecoin',
    unidade: 'US\$',
    frequency: Frequency.daily,
    category: Category.cripto,
    source: DataSource(
        provider: _yahoo, code: 'LTC-USD', tier: SourceTier.b),
    negociavel: true,
  ),
  const Indicator(
    id: 'bitcoincash',
    nome: 'Bitcoin Cash',
    unidade: 'US\$',
    frequency: Frequency.daily,
    category: Category.cripto,
    source: DataSource(
        provider: _yahoo, code: 'BCH-USD', tier: SourceTier.b),
    negociavel: true,
  ),
  const Indicator(
    id: 'chainlink',
    nome: 'Chainlink',
    unidade: 'US\$',
    frequency: Frequency.daily,
    category: Category.cripto,
    source: DataSource(
        provider: _yahoo, code: 'LINK-USD', tier: SourceTier.b),
    negociavel: true,
  ),
  const Indicator(
    id: 'dogecoin',
    nome: 'Dogecoin',
    unidade: 'US\$',
    frequency: Frequency.daily,
    category: Category.cripto,
    source: DataSource(
        provider: _yahoo, code: 'DOGE-USD', tier: SourceTier.b),
    negociavel: true,
  ),
  const Indicator(
    id: 'polkadot',
    nome: 'Polkadot',
    unidade: 'US\$',
    frequency: Frequency.daily,
    category: Category.cripto,
    source: DataSource(
        provider: _yahoo, code: 'DOT-USD', tier: SourceTier.b),
    negociavel: true,
  ),
]);

Indicator? indicadorPorId(String id) {
  for (final i in catalogoInicial) {
    if (i.id == id) return i;
  }
  return null;
}
