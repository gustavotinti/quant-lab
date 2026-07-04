import 'package:quant_core/quant_core.dart';

/// A "tabela periódica" inicial: poucos indicadores, todos universais,
/// objetivos, mensuráveis e com fonte oficial/gratuita, validados um a um
/// contra as APIs em 2026-07.
///
/// Nível A = Banco Central do Brasil (SGS). Nível B = preços de mercado
/// (Yahoo Finance como transporte; a fonte primária é a própria bolsa).
const _bcb = 'bcb_sgs';
const _yahoo = 'yahoo';

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
]);

Indicator? indicadorPorId(String id) {
  for (final i in catalogoInicial) {
    if (i.id == id) return i;
  }
  return null;
}
