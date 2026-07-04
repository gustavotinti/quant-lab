import 'dart:convert';
import 'dart:io';

import 'package:lab_cli/src/format.dart';
import 'package:lab_cli/src/lab.dart';
import 'package:quant_core/quant_core.dart';
import 'package:quant_engine/quant_engine.dart';
import 'package:quant_market_data/quant_market_data.dart';
import 'package:quant_stats/quant_stats.dart';

Future<void> main(List<String> args) async {
  try {
    stdout.encoding = utf8;
  } catch (_) {}

  final lab = Lab(Directory.current);
  final cmd = args.isEmpty ? 'help' : args.first;
  final rest = args.skip(1).toList();

  switch (cmd) {
    case 'update':
      await _update(lab);
    case 'list':
      await _list(lab);
    case 'macro':
      await _macro(lab);
    case 'analyze':
      await _analyze(lab, rest);
    case 'opportunities':
      await _opportunities(lab, rest);
    case 'scenarios':
      await _scenarios(lab, rest);
    case 'hypotheses':
      await _hypotheses(lab, rest);
    case 'report':
      await _report(lab);
    default:
      _help();
  }
}

void _help() {
  stdout.writeln('''
QuantLab — Laboratório de Descoberta Econômica

Comandos:
  lab update                       Baixa/atualiza todas as séries oficiais
  lab list                         Catálogo de indicadores e estado local
  lab macro                        Regime macroeconômico atual
  lab analyze <id>                 Sinais + backtest de um ativo
  lab opportunities [horizonte]    Oportunidades (curto | medio | longo)
  lab scenarios <id>               Cenários análogos históricos do ativo
  lab hypotheses discover|list     Minera/lista hipóteses defasadas
  lab report                       Gera relatório markdown em reports/

Rodar sempre da raiz do repositório: dart run lab_cli:lab <comando>''');
}

Future<void> _update(Lab lab) async {
  stdout.writeln('Atualizando ${catalogoInicial.length} indicadores '
      '(BCB SGS + Yahoo Finance)...\n');
  final outcomes = await lab.update();
  for (final o in outcomes) {
    if (o.ok) {
      final s = o.series!;
      stdout.writeln('  ok  ${o.indicator.id.padRight(24)} '
          '${s.length.toString().padLeft(6)} obs  '
          '${dataBr(s.first.date)} → ${dataBr(s.last.date)}  '
          'último: ${numBr(s.last.value)}');
    } else {
      stdout.writeln('  ERRO ${o.indicator.id.padRight(23)} ${o.failure}');
    }
  }
  final ok = outcomes.where((o) => o.ok).length;
  stdout.writeln('\n$ok/${outcomes.length} séries atualizadas.');
}

Future<void> _list(Lab lab) async {
  final ctx = await lab.carregar();
  final rows = <List<String>>[];
  for (final ind in catalogoInicial) {
    final s = ctx.series[ind.id];
    rows.add([
      ind.id,
      ind.nome,
      ind.source.tier.name.toUpperCase(),
      ind.category.label,
      s == null ? '—' : '${s.length}',
      s == null ? 'rode `lab update`' : dataBr(s.last.date),
    ]);
  }
  stdout.writeln(tabela(
      ['id', 'nome', 'tier', 'categoria', 'obs', 'última'], rows));
}

Future<void> _macro(Lab lab) async {
  final ctx = await lab.carregar();
  final m = ctx.macro;
  if (m == null) {
    stdout.writeln('Sem dados de Selic/IPCA — rode `lab update` antes.');
    return;
  }
  stdout.writeln('REGIME MACRO — calculado só de dados oficiais (nível A/B)\n');
  stdout.writeln('  Selic meta      ${numBr(m.selicAtual)}% a.a. '
      '(${direcaoMacro(m.selicDirecao)} nos últimos 3 meses)');
  stdout.writeln('  IPCA 12m        ${pct(m.ipca12m, comSinal: false)}   '
      '· 3m anualizado: ${pct(m.ipca3mAnualizado, comSinal: false)} '
      '(inflação ${direcaoMacro(m.inflacaoTendencia)})');
  stdout.writeln('  Juro real       ${pct(m.juroRealAa, comSinal: false)} a.a. '
      '(ex-post: Selic vs IPCA 12m)');
  if (m.dolarAtual != null) {
    stdout.writeln('  Dólar PTAX      R\$ ${numBr(m.dolarAtual)} '
        '(${m.dolarAcimaDaMedia3m == true ? "acima" : "abaixo"} da média de 3 meses)');
  }
  if (m.us10yAtual != null) {
    stdout.writeln('  Treasury 10a    ${numBr(m.us10yAtual)}% '
        '(${direcaoMacro(m.us10yDirecao ?? Direcao.estavel)})');
  }
  if (m.dxyAcimaSma200 != null) {
    stdout.writeln('  DXY             '
        '${m.dxyAcimaSma200! ? "acima" : "abaixo"} da SMA-200 '
        '(dólar global ${m.dxyAcimaSma200! ? "forte" : "fraco"})');
  }
}

Future<void> _analyze(Lab lab, List<String> args) async {
  if (args.isEmpty) {
    stdout.writeln('Uso: lab analyze <id>  (veja ids com `lab list`)');
    return;
  }
  final id = args.first;
  final ind = indicadorPorId(id);
  if (ind == null) {
    stdout.writeln('Indicador "$id" não está no catálogo.');
    return;
  }
  final ctx = await lab.carregar();
  final serie = ctx.series[id];
  if (serie == null) {
    stdout.writeln('Sem dados locais para "$id" — rode `lab update`.');
    return;
  }

  stdout.writeln('${ind.nome} (${ind.unidade}) — fonte '
      '${ind.source.provider}:${ind.source.code} '
      '[nível ${ind.source.tier.name.toUpperCase()}]');
  stdout.writeln('${serie.length} observações, '
      '${dataBr(serie.first.date)} → ${dataBr(serie.last.date)}\n');

  final s = ctx.sinais[id];
  if (s == null) {
    stdout.writeln('Último valor: ${numBr(serie.last.value)}');
    return;
  }
  stdout.writeln(tabela([
    'sinal',
    'valor'
  ], [
    ['preço atual', numBr(s.lastPrice)],
    ['retorno 1m / 3m / 12m',
        '${pct(s.ret1m)} / ${pct(s.ret3m)} / ${pct(s.ret12m)}'],
    ['momentum 12-1', pct(s.momentum12x1)],
    ['distância da SMA-200', pct(s.distSma200)],
    ['z-score 60 pregões', numBr(s.zScore60d)],
    ['vol 30d / 1a (anualizada)',
        '${pct(s.vol30dAnn, comSinal: false)} / ${pct(s.vol1yAnn, comSinal: false)}'],
    ['máx. drawdown 1a', pct(s.maxDd1y)],
    ['distância do topo histórico', pct(s.ddDoTopo)],
    ['CAGR 3 anos', pct(s.cagr3y)],
  ]));

  final pack = ctx.backtests[id];
  if (pack != null && pack.todos.isNotEmpty) {
    final anos = pack.todos.first.estrategia.years.toStringAsFixed(1);
    stdout.writeln('\nBACKTEST por estratégia — $anos anos '
        '(sem custos; mede poder preditivo do sinal):');
    stdout.writeln(tabela([
      'estratégia',
      'CAGR',
      'vol',
      'Sharpe',
      'máx. DD',
      'Sharpe OOS',
      'walk-fwd'
    ], [
      for (final bt in pack.todos)
        [
          bt.kind.label,
          pct(bt.estrategia.cagr),
          pct(bt.estrategia.volAnn, comSinal: false),
          numBr(bt.estrategia.sharpe),
          pct(bt.estrategia.maxDd),
          numBr(bt.estrategiaOos.sharpe),
          '${bt.segmentosPositivos}/3',
        ],
      if (pack.tendencia != null)
        [
          'buy & hold',
          pct(pack.tendencia!.buyHold.cagr),
          pct(pack.tendencia!.buyHold.volAnn, comSinal: false),
          numBr(pack.tendencia!.buyHold.sharpe),
          pct(pack.tendencia!.buyHold.maxDd),
          numBr(pack.tendencia!.buyHoldOos.sharpe),
          '—',
        ],
    ]));

    final ci = sharpeBlockBootstrapCI(simpleReturns(serie.values), 252);
    if (!ci.lower.isNaN) {
      stdout.writeln('\nSharpe buy & hold com incerteza (bootstrap de '
          'blocos, IC 90%): ${numBr(ci.point)} [${numBr(ci.lower)} a '
          '${numBr(ci.upper)}]');
    }
  }

  final cen = analogousScenarios(serie);
  if (cen != null) {
    stdout.writeln('\nCENÁRIOS ANÁLOGOS — ${cen.nAnalogos} episódios '
        'históricos parecidos com hoje (desde ${dataBr(cen.datas.first)}):');
    _printScenarioStats('3 meses depois ', cen.fwd3m);
    _printScenarioStats('12 meses depois', cen.fwd12m);
  }
  stdout.writeln(disclaimer);
}

void _printScenarioStats(String rotulo, ScenarioStats? s) {
  if (s == null) return;
  stdout.writeln('  $rotulo: mediana ${pct(s.mediana)} '
      '[Q1 ${pct(s.q1)} | Q3 ${pct(s.q3)}] · '
      '${pct(s.pctPositivo, comSinal: false, dec: 0)} positivos · '
      'pior ${pct(s.pior)} · melhor ${pct(s.melhor)} (n=${s.n})');
}

Future<void> _scenarios(Lab lab, List<String> args) async {
  if (args.isEmpty) {
    stdout.writeln('Uso: lab scenarios <id>  (veja ids com `lab list`)');
    return;
  }
  final id = args.first;
  final ind = indicadorPorId(id);
  final ctx = await lab.carregar();
  final serie = ctx.series[id];
  if (ind == null || serie == null) {
    stdout.writeln('Sem dados para "$id" — veja `lab list`.');
    return;
  }
  final cen = analogousScenarios(serie);
  if (cen == null) {
    stdout.writeln('Histórico insuficiente ou nenhum episódio análogo '
        'encontrado para ${ind.nome}.');
    return;
  }
  stdout.writeln('CENÁRIOS ANÁLOGOS — ${ind.nome}\n');
  stdout.writeln('Hoje: momentum 12-1 ${pct(cen.momAtual)} · '
      'dist. SMA-200 ${pct(cen.dist200Atual)} · z-60 ${numBr(cen.zAtual)}');
  stdout.writeln('${cen.nAnalogos} episódios históricos parecidos '
      '(espaçados ≥ 1 mês), o primeiro em ${dataBr(cen.datas.first)} e o '
      'último em ${dataBr(cen.datas.last)}.\n');
  stdout.writeln('O que aconteceu depois desses episódios:');
  _printScenarioStats('3 meses depois ', cen.fwd3m);
  _printScenarioStats('12 meses depois', cen.fwd12m);
  stdout.writeln('\nLeitura: distribuição empírica, não previsão. '
      'Episódios análogos ≠ futuro garantido.');
  stdout.writeln(disclaimer);
}

Future<void> _opportunities(Lab lab, List<String> args) async {
  final ctx = await lab.carregar();
  if (ctx.sinais.isEmpty) {
    stdout.writeln('Sem dados — rode `lab update` primeiro.');
    return;
  }
  final horizontes = switch (args.isEmpty ? null : args.first) {
    'curto' => [Horizon.curto],
    'medio' => [Horizon.medio],
    'longo' => [Horizon.longo],
    _ => Horizon.values,
  };

  for (final h in horizontes) {
    final ops = lab.oportunidades(ctx, h);
    stdout.writeln('\n═══ ${h.label.toUpperCase()} (${h.janela}) ═══\n');
    stdout.writeln(tabela(
      ['ativo', 'direção', 'score', 'alav. máx.'],
      [
        for (final o in ops)
          [
            o.indicator.nome,
            direcaoLabel(o.direcao),
            o.direcao == DirecaoOportunidade.neutro
                ? '—'
                : o.score.toStringAsFixed(0),
            o.alavancagem == null
                ? '—'
                : '${numBr(o.alavancagem!.sugerida)}x',
          ],
      ],
    ));

    final destaques = ops
        .where((o) => o.direcao != DirecaoOportunidade.neutro)
        .take(3)
        .toList();
    for (final o in destaques) {
      stdout.writeln('\n  ${o.indicator.nome} — ${direcaoLabel(o.direcao)} '
          '(convicção ${o.score.toStringAsFixed(0)}/100)');
      for (final e in o.evidencias) {
        stdout.writeln('    · ${e.texto}');
      }
      if (o.alavancagem != null) {
        final a = o.alavancagem!;
        stdout.writeln('    Alavancagem: sugerida ≤ ${numBr(a.sugerida)}x '
            '(meio-Kelly ${numBr(a.kellyMeio)}x, teto por vol '
            '${numBr(a.tetoPorVolatilidade)}x)');
      }
    }
  }
  stdout.writeln('\n$disclaimer');
}

Future<void> _hypotheses(Lab lab, List<String> args) async {
  final sub = args.isEmpty ? 'list' : args.first;
  if (sub == 'discover') {
    final ctx = await lab.carregar();
    stdout.writeln('Minerando pares defasados (treino 70% / teste 30%)...');
    final hs = lab.descobrirHipoteses(ctx);
    await lab.salvarHipoteses(hs);
    stdout.writeln('${hs.length} hipóteses sobreviveram ao funil '
        '(${hs.where((h) => h.status == 'validada').length} validadas). '
        'Salvas em data/hypotheses.json\n');
    _printHipoteses(hs.take(15).toList());
  } else {
    final hs = await lab.lerHipoteses();
    if (hs.isEmpty) {
      stdout.writeln('Nenhuma hipótese salva — rode `lab hypotheses discover`.');
      return;
    }
    _printHipoteses(hs.take(30).toList());
  }
}

void _printHipoteses(List<Hypothesis> hs) {
  String nome(String id) => indicadorPorId(id)?.nome ?? id;
  stdout.writeln(tabela(
    ['hipótese', 'lag', 'ρ treino', 'ρ teste', 'p treino', 'status'],
    [
      for (final h in hs)
        [
          '${nome(h.causaId)} → ${nome(h.efeitoId)}',
          '${h.lagMeses}m',
          numBr(h.rhoTreino),
          numBr(h.rhoTeste),
          h.pTreino < 0.001 ? '<0,001' : numBr(h.pTreino, dec: 3),
          h.status,
        ],
    ],
  ));
  stdout.writeln('\nLeitura: variações mensais da CAUSA antecedem variações '
      'do EFEITO pelo lag indicado.\nCorrelação não é causalidade — cada '
      'hipótese precisa de explicação econômica antes de virar convicção.');
}

Future<void> _report(Lab lab) async {
  final ctx = await lab.carregar();
  if (ctx.sinais.isEmpty) {
    stdout.writeln('Sem dados — rode `lab update` primeiro.');
    return;
  }
  final hs = await lab.lerHipoteses();
  final hoje = DateTime.now();
  final buf = StringBuffer()
    ..writeln('# QuantLab — Relatório ${dataBr(hoje)}')
    ..writeln()
    ..writeln('> Gerado automaticamente de dados públicos (BCB SGS, bolsas '
        'via Yahoo Finance). Não é recomendação de investimento.')
    ..writeln();

  final m = ctx.macro;
  if (m != null) {
    buf
      ..writeln('## Regime macro')
      ..writeln()
      ..writeln('| Indicador | Valor |')
      ..writeln('|---|---|')
      ..writeln('| Selic meta | ${numBr(m.selicAtual)}% a.a. '
          '(${direcaoMacro(m.selicDirecao)}) |')
      ..writeln('| IPCA 12m | ${pct(m.ipca12m, comSinal: false)} |')
      ..writeln('| IPCA 3m anualizado | '
          '${pct(m.ipca3mAnualizado, comSinal: false)} '
          '(${direcaoMacro(m.inflacaoTendencia)}) |')
      ..writeln('| Juro real ex-post | ${pct(m.juroRealAa, comSinal: false)} '
          'a.a. |');
    if (m.dolarAtual != null) {
      buf.writeln('| Dólar PTAX | R\$ ${numBr(m.dolarAtual)} |');
    }
    if (m.us10yAtual != null) {
      buf.writeln('| Treasury 10a | ${numBr(m.us10yAtual)}% '
          '(${direcaoMacro(m.us10yDirecao ?? Direcao.estavel)}) |');
    }
    buf.writeln();
  }

  for (final h in Horizon.values) {
    final ops = lab.oportunidades(ctx, h);
    buf
      ..writeln('## ${h.label} (${h.janela})')
      ..writeln()
      ..writeln('| Ativo | Direção | Convicção | Alav. máx. sugerida |')
      ..writeln('|---|---|---|---|');
    for (final o in ops) {
      buf.writeln('| ${o.indicator.nome} | ${direcaoLabel(o.direcao)} | '
          '${o.direcao == DirecaoOportunidade.neutro ? "—" : o.score.toStringAsFixed(0)} | '
          '${o.alavancagem == null ? "—" : "${numBr(o.alavancagem!.sugerida)}x"} |');
    }
    buf.writeln();
    for (final o in ops
        .where((o) => o.direcao != DirecaoOportunidade.neutro)
        .take(3)) {
      buf.writeln('**${o.indicator.nome} — ${direcaoLabel(o.direcao)} '
          '(${o.score.toStringAsFixed(0)}/100)**');
      for (final e in o.evidencias) {
        buf.writeln('- ${e.texto}');
      }
      buf.writeln();
    }
  }

  final destaquesMedio = lab
      .oportunidades(ctx, Horizon.medio)
      .where((o) => o.direcao != DirecaoOportunidade.neutro)
      .take(3)
      .toList();
  if (destaquesMedio.isNotEmpty) {
    buf
      ..writeln('## Cenários análogos (destaques do médio prazo)')
      ..writeln();
    for (final o in destaquesMedio) {
      final serie = ctx.series[o.indicator.id];
      final cen = serie == null ? null : analogousScenarios(serie);
      if (cen == null) continue;
      String linha(String rotulo, ScenarioStats? s) => s == null
          ? ''
          : '- $rotulo: mediana ${pct(s.mediana)} [Q1 ${pct(s.q1)} | '
              'Q3 ${pct(s.q3)}], ${pct(s.pctPositivo, comSinal: false, dec: 0)} '
              'positivos (n=${s.n})\n';
      buf
        ..writeln('**${o.indicator.nome}** — ${cen.nAnalogos} episódios '
            'históricos parecidos com hoje:')
        ..write(linha('3 meses depois', cen.fwd3m))
        ..write(linha('12 meses depois', cen.fwd12m))
        ..writeln();
    }
  }

  if (hs.isNotEmpty) {
    String nome(String id) => indicadorPorId(id)?.nome ?? id;
    buf
      ..writeln('## Hipóteses vivas (top 10)')
      ..writeln()
      ..writeln('| Relação | Lag | ρ treino | ρ teste | Status |')
      ..writeln('|---|---|---|---|---|');
    for (final h in hs.take(10)) {
      buf.writeln('| ${nome(h.causaId)} → ${nome(h.efeitoId)} | '
          '${h.lagMeses}m | ${numBr(h.rhoTreino)} | ${numBr(h.rhoTeste)} | '
          '${h.status} |');
    }
    buf.writeln();
  }

  buf
    ..writeln('---')
    ..writeln('*Metodologia em `docs/METODOLOGIA.md`. Alavancagem = menor '
        'entre meio-Kelly e alvo de volatilidade de 15% a.a., teto 3x. '
        'Rentabilidade passada não garante resultado futuro.*');

  final dir = Directory('${lab.root.path}${Platform.pathSeparator}reports');
  await dir.create(recursive: true);
  final file = File('${dir.path}${Platform.pathSeparator}relatorio_'
      '${hoje.year}-${hoje.month.toString().padLeft(2, '0')}-'
      '${hoje.day.toString().padLeft(2, '0')}.md');
  await file.writeAsString(buf.toString());
  stdout.writeln('Relatório salvo em ${file.path}');
}
