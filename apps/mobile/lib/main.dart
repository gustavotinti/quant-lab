import 'package:flutter/material.dart';

import 'data.dart';
import 'theme.dart';
import 'widgets.dart';

void main() => runApp(const QuantLabApp());

class QuantLabApp extends StatelessWidget {
  const QuantLabApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'QuantLab',
        debugShowCheckedModeBanner: false,
        theme: Ql.theme(),
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Dashboard? _d;
  Object? _erro;
  String _horizonte = 'curto';
  Perfil _perfil = Perfil.moderado;

  static const _horizontes = [
    ('curto', 'Curto'),
    ('medio', 'Médio'),
    ('longo', 'Longo'),
  ];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final d = await Dashboard.carregar();
      if (mounted) {
        setState(() {
          _d = d;
          _erro = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _erro = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: Ql.accent,
          backgroundColor: Ql.card,
          onRefresh: _carregar,
          child: _d == null ? _placeholder() : _conteudo(_d!),
        ),
      ),
    );
  }

  Widget _placeholder() => ListView(
        children: [
          const SizedBox(height: 120),
          if (_erro == null)
            const Center(child: CircularProgressIndicator(color: Ql.accent))
          else
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(children: const [
                Icon(Icons.cloud_off, color: Ql.dimmer, size: 42),
                SizedBox(height: 12),
                Text(
                    'Não consegui carregar o painel.\nPuxe para baixo para tentar de novo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Ql.dim)),
              ]),
            ),
        ],
      );

  Widget _conteudo(Dashboard d) {
    final r = ranking(d, _horizonte, _perfil);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        _header(d),
        const SizedBox(height: 16),
        _seletorHorizonte(),
        const SizedBox(height: 10),
        _seletorPerfil(),
        const SizedBox(height: 20),
        MacroStrip(macro: d.macro),
        const SizedBox(height: 24),
        SecTitle('O que fazer agora',
            sub:
                '${d.horizonteLabel(_horizonte).toLowerCase()} · ${_perfil.nome.toLowerCase()}'),
        const SizedBox(height: 8),
        if (r.ordens.isEmpty)
          const VazioBox(
              'Nenhuma ordem passa no corte de assertividade deste perfil neste horizonte — o laboratório prefere ficar de fora a chutar.')
        else
          ...r.ordens.asMap().entries.map(
              (e) => OrdemCard(pos: e.key + 1, ordem: e.value)),
        if (r.ordens.isNotEmpty)
          CaixaBox(caixaPct: r.caixaPct, macro: d.macro),
        const SizedBox(height: 24),
        const SecTitle('Radar de Picos',
            sub:
                'probabilidade de virada em ~1 mês, calibrada em episódios idênticos'),
        const SizedBox(height: 8),
        if (d.radarPicos.isEmpty)
          const VazioBox('Nenhum ativo em estado esticado hoje.')
        else
          ...d.radarPicos
              .take(12)
              .map((r) => RadarRow(r: (r as Map).cast<String, dynamic>())),
        const SizedBox(height: 24),
        const SecTitle('Placar do sistema',
            sub: 'acerto REAL das ordens emitidas ao vivo — sem hindsight'),
        const SizedBox(height: 8),
        if (d.placar != null) PlacarBox(placar: d.placar!),
        const SizedBox(height: 20),
        const Disclaimer(),
      ],
    );
  }

  Widget _header(Dashboard d) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
            fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -.5),
        children: [
          const TextSpan(text: 'Quant', style: TextStyle(color: Ql.text)),
          const TextSpan(text: 'Lab', style: TextStyle(color: Ql.accent)),
          TextSpan(
              text: '   dados até ${fmtData(d.ultimaObservacao)}',
              style: const TextStyle(
                  color: Ql.dimmer,
                  fontSize: 12,
                  fontWeight: FontWeight.w400)),
        ],
      ),
    );
  }

  Widget _seletorHorizonte() => SegBar(
        itens: [for (final h in _horizontes) h.$2],
        selecionado: _horizontes.indexWhere((h) => h.$1 == _horizonte),
        onTap: (i) => setState(() => _horizonte = _horizontes[i].$1),
      );

  Widget _seletorPerfil() => Row(
        children: [
          for (final p in Perfil.todos)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChipToggle(
                label: p.nome,
                ativo: p == _perfil,
                onTap: () => setState(() => _perfil = p),
              ),
            ),
        ],
      );
}
