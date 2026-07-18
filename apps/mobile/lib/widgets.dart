import 'package:flutter/material.dart';

import 'data.dart';
import 'theme.dart';

BoxDecoration _cardDeco() => BoxDecoration(
      color: Ql.card.withValues(alpha: .72),
      border: Border.all(color: Ql.border),
      borderRadius: BorderRadius.circular(16),
    );

/// Título de seção com subtítulo.
class SecTitle extends StatelessWidget {
  const SecTitle(this.titulo, {super.key, this.sub});
  final String titulo;
  final String? sub;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: Ql.text)),
          if (sub != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(sub!,
                  style: const TextStyle(color: Ql.dimmer, fontSize: 12)),
            ),
        ],
      );
}

/// Faixa de indicadores macro.
class MacroStrip extends StatelessWidget {
  const MacroStrip({super.key, required this.macro});
  final Map<String, dynamic>? macro;

  @override
  Widget build(BuildContext context) {
    final m = macro;
    if (m == null) return const SizedBox.shrink();
    String dir(String? k) => switch (k) {
          'subindo' => '▲ rising',
          'caindo' => '▼ falling',
          'estavel' => '◆ stable',
          _ => '',
        };
    final itens = <(String, String, String)>[
      ('Selic', '${fmtNum(m['selic'])}%', dir(m['selicDirecao'] as String?)),
      ('CPI (BR) 12m', fmtPct(m['ipca12m'] as num?, sign: false),
          dir(m['inflacaoTendencia'] as String?)),
      ('Real rate', '${fmtPct(m['juroReal'] as num?, sign: false)}/yr', ''),
      ('USD/BRL', fmtNum(m['dolar']), ''),
      ('10y Treasury', '${fmtNum(m['us10y'])}%', dir(m['us10yDirecao'] as String?)),
      ('Global USD', (m['dxyForte'] as bool?) == null
          ? '—'
          : ((m['dxyForte'] as bool) ? 'strong' : 'weak'), ''),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final it in itens)
          SizedBox(
            width: (MediaQuery.of(context).size.width - 32 - 10) / 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: _cardDeco(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(it.$1.toUpperCase(),
                      style: const TextStyle(
                          color: Ql.dimmer, fontSize: 10, letterSpacing: .8)),
                  const SizedBox(height: 3),
                  Text(it.$2,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Ql.text)),
                  if (it.$3.isNotEmpty)
                    Text(it.$3,
                        style: TextStyle(
                            fontSize: 11,
                            color: it.$3.startsWith('▲')
                                ? Ql.accent
                                : it.$3.startsWith('▼')
                                    ? Ql.red
                                    : Ql.amber)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Cartão de ordem do ranking (expansível).
class OrdemCard extends StatelessWidget {
  const OrdemCard({super.key, required this.pos, required this.ordem});
  final int pos;
  final Ordem ordem;

  @override
  Widget build(BuildContext context) {
    final o = ordem;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _cardDeco(),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          iconColor: Ql.dimmer,
          collapsedIconColor: Ql.dimmer,
          title: Row(
            children: [
              SizedBox(
                width: 22,
                child: Text('$pos',
                    style: const TextStyle(
                        color: Ql.dimmer,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
              ),
              Badge(compra: o.compra),
              const SizedBox(width: 10),
              Expanded(
                child: Text('${o.nome}${o.ticker != null ? '  ${o.ticker}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: Ql.text)),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(fmtPct(o.assertividade, dec: 0, sign: false),
                      style: const TextStyle(
                          color: Ql.accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 15)),
                  const Text('assertividade',
                      style: TextStyle(color: Ql.dimmer, fontSize: 9)),
                ],
              ),
            ],
          ),
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _kv('Exp. return (${o.janela})', fmtPct(o.retornoEsperado)),
                _kv('Base', 'n=${o.base}'),
                _kv('Conviction', '${o.score}/100'),
                _kv('Leverage', 'X${o.lev}'),
              ],
            ),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.flag_outlined, size: 15, color: Ql.dim),
              const SizedBox(width: 6),
              Expanded(
                child: Text(o.gatilho,
                    style: const TextStyle(color: Ql.dim, fontSize: 13)),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0x0F789AD2),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(k.toUpperCase(),
                style: const TextStyle(
                    color: Ql.dimmer, fontSize: 9, letterSpacing: .4)),
            const SizedBox(height: 2),
            Text(v,
                style: const TextStyle(
                    color: Ql.text,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ],
        ),
      );
}

/// Selo COMPRAR / VENDER.
class Badge extends StatelessWidget {
  const Badge({super.key, required this.compra});
  final bool compra;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: compra
                  ? const [Ql.accent, Color(0xFF2BB787)]
                  : const [Ql.red, Color(0xFFE0385D)]),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(compra ? '▲ BUY' : '▼ SELL',
            style: TextStyle(
                color: compra ? const Color(0xFF05261A) : const Color(0xFF2B060D),
                fontWeight: FontWeight.w800,
                fontSize: 11)),
      );
}

/// Linha do Radar de Picos com medidor de probabilidade.
class RadarRow extends StatelessWidget {
  const RadarRow({super.key, required this.r});
  final Map<String, dynamic> r;

  @override
  Widget build(BuildContext context) {
    final topo = r['tipo'] == 'topo';
    final prob = (r['prob'] as num?)?.toDouble() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: _cardDeco(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(
                  color: topo ? const Color(0x66FF5D73) : const Color(0x6638E0A2)),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(topo ? '▼ TOP' : '▲ BOTTOM',
                style: TextStyle(
                    color: topo ? Ql.red : Ql.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 11)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text('${r['nome']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: Ql.text)),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: Stack(alignment: Alignment.centerLeft, children: [
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0x1F789AD2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              FractionallySizedBox(
                widthFactor: prob.clamp(0, 1),
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: topo
                            ? const [Color(0xFF7A2C3C), Ql.red]
                            : const [Color(0xFF1D6B4F), Ql.accent]),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Positioned(
                right: 8,
                child: Text(fmtPct(prob, dec: 0, sign: false),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

/// Segmented control (horizonte).
class SegBar extends StatelessWidget {
  const SegBar(
      {super.key,
      required this.itens,
      required this.selecionado,
      required this.onTap});
  final List<String> itens;
  final int selecionado;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Ql.card.withValues(alpha: .72),
          border: Border.all(color: Ql.border),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(children: [
          for (var i = 0; i < itens.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    gradient: i == selecionado
                        ? const LinearGradient(colors: [
                            Color(0x2E38E0A2),
                            Color(0x2E4F9CFF)
                          ])
                        : null,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(itens[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: i == selecionado ? Ql.text : Ql.dim,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                ),
              ),
            ),
        ]),
      );
}

/// Chip de perfil de risco.
class ChipToggle extends StatelessWidget {
  const ChipToggle(
      {super.key,
      required this.label,
      required this.ativo,
      required this.onTap});
  final String label;
  final bool ativo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          decoration: BoxDecoration(
            color: ativo ? Ql.card : Colors.transparent,
            border: Border.all(
                color: ativo ? const Color(0x66789AD2) : Ql.border),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(label,
              style: TextStyle(
                  color: ativo ? Ql.text : Ql.dim,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ),
      );
}

/// Bloco de caixa/renda fixa.
class CaixaBox extends StatelessWidget {
  const CaixaBox({super.key, required this.caixaPct, required this.macro});
  final double caixaPct;
  final Map<String, dynamic>? macro;
  @override
  Widget build(BuildContext context) {
    final jr = macro?['juroReal'] as num?;
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: _cardDeco(),
      child: Text(
        'Cash/fixed income: ${fmtPct(caixaPct, dec: 0, sign: false)} — '
        'with a ${fmtPct(jr, sign: false)}/yr real rate, cash is a position too.',
        style: const TextStyle(color: Ql.dim, fontSize: 13),
      ),
    );
  }
}

class VazioBox extends StatelessWidget {
  const VazioBox(this.texto, {super.key});
  final String texto;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDeco(),
        child: Text(texto,
            style: const TextStyle(color: Ql.dim, fontSize: 13)),
      );
}

class Disclaimer extends StatelessWidget {
  const Disclaimer({super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: Ql.amber, width: 3)),
        ),
        child: const Text(
          'Statistics derived from public data (central banks, exchanges). '
          'Not investment advice. Historical accuracy does not '
          'garante resultado futuro. Alavancagem pode gerar perdas superiores '
          'ao capital.',
          style: TextStyle(color: Ql.dim, fontSize: 12),
        ),
      );
}

/// Placar do sistema — o acerto REAL das ordens emitidas ao vivo, medido
/// quando cada janela se cumpre (mesmos dados do painel web).
class PlacarBox extends StatelessWidget {
  const PlacarBox({super.key, required this.placar});
  final Map<String, dynamic> placar;

  @override
  Widget build(BuildContext context) {
    final total = (placar['totalSinais'] as num?)?.toInt() ?? 0;
    final fechados = (placar['totalFechados'] as num?)?.toInt() ?? 0;
    final porH =
        (placar['porHorizonte'] as Map?)?.cast<String, dynamic>() ?? {};
    if (total == 0) {
      return const VazioBox('Recommendation tracking has started — the real '
          'hit rate appears as each window completes.');
    }
    String pct(num? v) => v == null ? '—' : '${(v * 100).round()}%';
    final linhas = <Widget>[];
    for (final k in const ['curto', 'medio', 'longo']) {
      final h = (porH[k] as Map?)?.cast<String, dynamic>();
      if (h == null) continue;
      final nF = (h['nFechados'] as num?)?.toInt() ?? 0;
      final nA = (h['nAbertos'] as num?)?.toInt() ?? 0;
      final hit = h['hitRate'] as num?;
      linhas.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(
              width: 64,
              child: Text(h['label'] as String? ?? k,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF8AA0B8)))),
          Text(nF > 0 ? pct(hit) : '—',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: nF == 0
                      ? const Color(0xFF8AA0B8)
                      : ((hit ?? 0) >= 0.5
                          ? const Color(0xFF38E0A2)
                          : const Color(0xFFFF5D73)))),
          const SizedBox(width: 6),
          Expanded(
              child: Text(
                  nF > 0
                      ? 'real hit rate in $nF closed · $nA open'
                      : '$nA open — measuring',
                  style: const TextStyle(
                      fontSize: 11.5, color: Color(0xFF5C7189)))),
        ]),
      ));
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xB812361B).withAlpha(40),
        border: Border.all(color: const Color(0x33405A78)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...linhas,
          const SizedBox(height: 4),
          Text(
              '$fechados of $total signals have completed their window. Closed = '
              'real results; open = marked to market.',
              style:
                  const TextStyle(fontSize: 11, color: Color(0xFF5C7189))),
        ],
      ),
    );
  }
}

/// Portfólio REAL do eToro (Firestore private/portfolio — só o dono lê).
class PortfolioBox extends StatelessWidget {
  const PortfolioBox(
      {super.key, required this.portfolio, required this.onSair});
  final Map<String, dynamic> portfolio;
  final VoidCallback onSair;

  @override
  Widget build(BuildContext context) {
    final pos = (portfolio['posicoes'] as List?) ?? const [];
    final rows = <Widget>[];
    for (final raw in pos) {
      final m = (raw as Map).cast<String, dynamic>();
      final isBuy = m['isBuy'] == true;
      final open = (m['openRate'] as num?)?.toDouble();
      final cur = (m['currentRate'] as num?)?.toDouble();
      final lev = (m['leverage'] as num?)?.toInt() ?? 1;
      double? pl;
      if (open != null && cur != null && open != 0) {
        final varr = isBuy ? cur / open - 1 : 1 - cur / open;
        pl = varr * lev;
      }
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Text(isBuy ? '▲' : '▼',
              style: TextStyle(
                  fontSize: 13,
                  color: isBuy
                      ? const Color(0xFF38E0A2)
                      : const Color(0xFFFF5D73))),
          const SizedBox(width: 8),
          Expanded(
              child: Text('${m['nome'] ?? '—'} · X$lev',
                  style: const TextStyle(fontSize: 13))),
          Text(
              pl == null
                  ? '—'
                  : '${pl >= 0 ? '+' : ''}${(pl * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: pl == null
                      ? const Color(0xFF8AA0B8)
                      : (pl >= 0
                          ? const Color(0xFF38E0A2)
                          : const Color(0xFFFF5D73)))),
        ]),
      ));
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x33405A78)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rows.isEmpty)
            const Text('No open positions on eToro.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF8AA0B8)))
          else
            ...rows,
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
                child: Text(
                    'P&L with leverage · pipeline quotes (~2h)',
                    style: const TextStyle(
                        fontSize: 10.5, color: Color(0xFF5C7189)))),
            TextButton(onPressed: onSair, child: const Text('sign out')),
          ]),
        ],
      ),
    );
  }
}
