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
          'subindo' => '▲ subindo',
          'caindo' => '▼ caindo',
          'estavel' => '◆ estável',
          _ => '',
        };
    final itens = <(String, String, String)>[
      ('Selic', '${fmtNum(m['selic'])}%', dir(m['selicDirecao'] as String?)),
      ('IPCA 12m', fmtPct(m['ipca12m'] as num?, sign: false),
          dir(m['inflacaoTendencia'] as String?)),
      ('Juro real', '${fmtPct(m['juroReal'] as num?, sign: false)} a.a.', ''),
      ('Dólar', 'R\$ ${fmtNum(m['dolar'])}', ''),
      ('Treasury 10a', '${fmtNum(m['us10y'])}%', dir(m['us10yDirecao'] as String?)),
      ('Dólar global', (m['dxyForte'] as bool?) == null
          ? '—'
          : ((m['dxyForte'] as bool) ? 'forte' : 'fraco'), ''),
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
                _kv('Retorno esp. (${o.janela})', fmtPct(o.retornoEsperado)),
                _kv('Base', 'n=${o.base}'),
                _kv('Convicção', '${o.score}/100'),
                _kv('Alavancagem', 'X${o.lev}'),
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
        child: Text(compra ? '▲ COMPRAR' : '▼ VENDER',
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
            child: Text(topo ? '▼ TOPO' : '▲ FUNDO',
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
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0x1F789AD2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              FractionallySizedBox(
                widthFactor: prob.clamp(0, 1),
                child: Container(
                  height: 18,
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
        'Caixa/renda fixa: ${fmtPct(caixaPct, dec: 0, sign: false)} — '
        'com juro real de ${fmtPct(jr, sign: false)} a.a., caixa também é posição.',
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
          'Estatística derivada de dados públicos (BCB, bolsas). '
          'Não é recomendação de investimento. Assertividade histórica não '
          'garante resultado futuro. Alavancagem pode gerar perdas superiores '
          'ao capital.',
          style: TextStyle(color: Ql.dim, fontSize: 12),
        ),
      );
}
