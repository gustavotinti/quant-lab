import 'package:flutter/material.dart';

import 'auth.dart';
import 'data.dart';
import 'oraculo.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initFirebase();
  } catch (_) {/* sem Google Services: app segue só-leitura */}
  runApp(const QuantLabApp());
}

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
  Map<String, dynamic>? _portfolio;
  bool _logando = false;
  String _horizonte = 'curto';
  Perfil _perfil = Perfil.moderado;

  static const _horizontes = [
    ('curto', 'Short'),
    ('medio', 'Medium'),
    ('longo', 'Long'),
  ];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _entrar() async {
    setState(() => _logando = true);
    try {
      await entrarComGoogle();
      _portfolio = await lerPortfolioEtoro();
    } catch (_) {/* cancelado/offline */}
    if (mounted) setState(() => _logando = false);
  }

  Future<void> _carregar() async {
    if (usuario != null) _portfolio = await lerPortfolioEtoro();
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
                    'Could not load the dashboard.\nPull down to try again.',
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
        SecTitle('What to do now',
            sub:
                '${d.horizonteLabel(_horizonte).toLowerCase()} · ${_perfil.nome.toLowerCase()}'),
        const SizedBox(height: 8),
        if (r.ordens.isEmpty)
          const VazioBox(
              'No order clears this profile accuracy cutoff on this horizon — the lab would rather stay out than guess.')
        else
          ...r.ordens.asMap().entries.map(
              (e) => OrdemCard(pos: e.key + 1, ordem: e.value)),
        if (r.ordens.isNotEmpty)
          CaixaBox(caixaPct: r.caixaPct, macro: d.macro),
        if (oraculoDisponivel && r.ordens.isNotEmpty) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _abrirOraculo(d),
            icon: const Icon(Icons.auto_awesome, size: 17),
            label: const Text('Oracle — execution plan'),
          ),
        ],
        const SizedBox(height: 24),
        const SecTitle('Peak Radar',
            sub:
                'probability of a reversal in ~1 month, calibrated on identical episodes'),
        const SizedBox(height: 8),
        if (d.radarPicos.isEmpty)
          const VazioBox('No asset in a stretched state today.')
        else
          ...d.radarPicos
              .take(12)
              .map((r) => RadarRow(r: (r as Map).cast<String, dynamic>())),
        const SizedBox(height: 24),
        SecTitle(
            usuario == null
                ? 'Copilot — your eToro account'
                : 'Copilot — eToro · live account',
            sub: usuario == null
                ? 'sign in with Google to see your real positions'
                : (usuario!.email ?? '')),
        const SizedBox(height: 8),
        if (usuario == null)
          FilledButton.icon(
            onPressed: _logando ? null : _entrar,
            icon: const Icon(Icons.login, size: 18),
            label: Text(_logando ? 'Signing in…' : 'Sign in with Google'),
          )
        else if (_portfolio == null)
          const VazioBox(
              'No portfolio access on this account (the Copilot is private '
              'to the lab owner).')
        else
          PortfolioBox(portfolio: _portfolio!, onSair: () async {
            await sair();
            if (mounted) setState(() => _portfolio = null);
          }),
        const SizedBox(height: 24),
        const SecTitle('System scoreboard',
            sub: 'REAL hit rate of live-issued orders — no hindsight'),
        const SizedBox(height: 8),
        if (d.placar != null) PlacarBox(placar: d.placar!),
        const SizedBox(height: 20),
        const Disclaimer(),
      ],
    );
  }

  Future<void> _abrirOraculo(Dashboard d) async {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => FutureBuilder<String>(
        future: gerarPlano(d, _horizonte, _perfil),
        builder: (ctx, snap) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: snap.connectionState != ConnectionState.done
              ? const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()))
              : SingleChildScrollView(
                  child: SelectableText(
                      snap.hasError
                          ? 'Could not reach the Oracle: '
                              '${snap.error}'
                          : (snap.data ?? ''),
                      style: const TextStyle(fontSize: 13.5, height: 1.5)),
                ),
        ),
      ),
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
              text: '   data through ${fmtData(d.ultimaObservacao)}',
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
