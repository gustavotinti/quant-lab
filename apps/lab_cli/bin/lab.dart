import 'dart:convert';
import 'dart:io';

import 'package:lab_cli/src/etoro.dart';
import 'package:lab_cli/src/etoro_sync.dart';
import 'package:lab_cli/src/format.dart';
import 'package:lab_cli/src/lab.dart';
import 'package:lab_cli/src/publish.dart';
import 'package:lab_cli/src/track_record_store.dart';
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
    case 'recommend':
      await _recommend(lab, rest);
    case 'radar':
      await _radar(lab);
    case 'etoro-check':
      await _etoroCheck();
    case 'etoro-sync':
      await syncEtoroPortfolio();
    case 'scenarios':
      await _scenarios(lab, rest);
    case 'hypotheses':
      await _hypotheses(lab, rest);
    case 'report':
      await _report(lab);
    case 'publish':
      await _publish(lab);
    case 'go':
      await _go(lab);
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
  lab recommend [horizonte]        RANKING ACIONÁVEL: o que fazer, com
                                   assertividade % e ticker do eToro
  lab radar                        📡 Radar de Picos (prob. de virada ~21d)
  lab etoro-check                  Diagnóstico das chaves eToro (status only)
  lab scenarios <id>               Cenários análogos históricos do ativo
  lab hypotheses discover|list     Minera/lista hipóteses defasadas
  lab report                       Gera relatório markdown em reports/
  lab publish                      Gera dashboard.json + relatório p/ o site
  lab go                           TUDO de uma vez: update + publish + deploy

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

/// Rotina diária completa: dados frescos → recalcular → site atualizado.
Future<void> _go(Lab lab) async {
  await _update(lab);
  await _publish(lab);
  stdout.writeln('\nPublicando no Firebase Hosting...');
  final r = await Process.run(
      'firebase', ['deploy', '--only', 'hosting', '-P', 'quantlab-lde'],
      runInShell: true);
  if (r.exitCode == 0) {
    stdout.writeln('No ar: https://quantlab-lde.web.app');
  } else {
    stdout.writeln('Deploy falhou (rode `firebase deploy --only hosting '
        '-P quantlab-lde` manualmente):\n${r.stderr}');
  }
}

Future<void> _recommend(Lab lab, List<String> args) async {
  final ctx = await lab.carregar();
  if (ctx.sinais.isEmpty) {
    stdout.writeln('Sem dados — rode `lab update` primeiro.');
    return;
  }
  final data = dashboardJson(lab, ctx, await lab.lerHipoteses());
  final horizontes = switch (args.isEmpty ? null : args.first) {
    'curto' => [Horizon.curto],
    'medio' => [Horizon.medio],
    'longo' => [Horizon.longo],
    _ => Horizon.values,
  };

  for (final h in horizontes) {
    final bloco = (data['horizontes'] as Map)[h.name] as Map;
    final ops = (bloco['oportunidades'] as List).cast<Map<String, Object?>>();
    Map<String, Object?> rec(Map<String, Object?> o) =>
        (o['recomendacao'] as Map).cast<String, Object?>();
    double ass(Map<String, Object?> o) =>
        (rec(o)['assertividade'] as num?)?.toDouble() ?? 0;
    double ret(Map<String, Object?> o) =>
        (rec(o)['retornoEsperado'] as num?)?.toDouble() ?? -999;

    final ordens = ops
        .where((o) => const {'comprar', 'vender'}.contains(rec(o)['acao']))
        .toList()
      // dinheiro primeiro: ordena pelo retorno esperado na direção
      ..sort((a, b) => ret(b).compareTo(ret(a)));
    final segurados = ops
        .where((o) =>
            rec(o)['acao'] == 'ficarDeFora' && o['direcao'] != 'neutro')
        .toList();

    stdout.writeln('\n═══ ${h.label.toUpperCase()} (${h.janela}) — '
        'RANKING ACIONÁVEL ═══\n');
    if (ordens.isEmpty) {
      stdout.writeln('Nenhuma ordem com assertividade ≥ 55% — o laboratório '
          'prefere ficar de fora a chutar.');
    } else {
      var i = 0;
      for (final o in ordens) {
        i++;
        final r = rec(o);
        final et = (o['etoro'] as Map?)?.cast<String, Object?>();
        final alav = (o['alavancagem'] as Map?)?.cast<String, Object?>();
        stdout.writeln(
            '$i. ${r['acao'] == 'comprar' ? 'COMPRAR' : 'VENDER (short)'}  '
            '${o['nome']}'
            '${et?['ticker'] != null ? '  [eToro: ${et!['ticker']}]' : ''}');
        stdout.writeln('   assertividade ${pct(ass(o), comSinal: false, dec: 0)} '
            '(n=${r['base']}) · convicção ${(o['score'] as num).round()}/100'
            '${alav?['sugerida'] != null ? ' · alavancagem ≤ ${numBr((alav!['sugerida'] as num).toDouble())}x' : ''}');
        final re = r['retornoEsperado'] as num?;
        final stop = r['stopEstimado'] as num?;
        final payoff = r['payoff'] as num?;
        if (re != null) {
          stdout.writeln('   retorno esperado (${r['janelaRetorno']}, mediana '
              'dos análogos): ${pct(re.toDouble())}'
              '${stop != null ? ' · stop estimado ~${pct(stop.toDouble(), comSinal: false)}' : ''}'
              '${payoff != null ? ' · payoff ${numBr(payoff.toDouble(), dec: 1)}:1' : ''}');
        }
        stdout.writeln('   quando sair: ${r['gatilho']}');
        if (et?['nota'] != null) stdout.writeln('   obs: ${et!['nota']}');
        stdout.writeln('');
      }
    }
    if (segurados.isNotEmpty) {
      stdout.writeln('Sinal presente mas SEGURADO pelo corte de 55%: '
          '${segurados.map((o) => o['nome']).join(', ')}.');
    }
  }
  stdout.writeln('\nSinais recalculados a cada `lab update` (ideal: diário). '
      'Validade: até a próxima atualização ou o gatilho de saída.');
  stdout.writeln(disclaimer);
}

/// Diagnóstico das chaves eToro. Só imprime STATUS e ESTRUTURA — nunca os
/// valores das posições (privacidade, mesmo em logs do pipeline).
Future<void> _etoroCheck() async {
  final c = EtoroClient();
  stdout.writeln('Ambiente eToro: ${c.ambiente}');
  if (!c.configurado) {
    stdout.writeln('ERRO: chaves eToro ausentes no ambiente '
        '(ETORO_KEY_PUBLICA / ETORO_KEY_PRIVADA).');
    return;
  }
  final ping = await c.ping();
  stdout.writeln('Autenticação (market-data): HTTP ${ping.status}'
      '${ping.ok ? ' — OK' : ''}');
  if (!ping.ok) {
    stdout.writeln('  detalhe: ${_curto(ping.body)}');
    stdout.writeln('Se 401: chave inválida/errada. Corrija no cofre.');
    return;
  }
  final port = await c.portfolio();
  stdout.writeln('Portfólio (/trading/info/portfolio): HTTP ${port.status}');
  if (port.ok) {
    stdout.writeln('  PORTFÓLIO ACESSÍVEL. Estrutura (só nomes/contagens, '
        'sem valores):');
    try {
      final j = json.decode(port.body);
      _descreverEstrutura(j, '   ');
    } catch (_) {
      stdout.writeln('   (corpo não-JSON, ${port.body.length} bytes)');
    }
    stdout.writeln('\n=> Pronto para ligar a sincronização de posições.');
  } else if (port.status == 403) {
    stdout.writeln('  detalhe: ${_curto(port.body)}');
    stdout.writeln('=> A chave AUTENTICA mas NÃO tem escopo de portfólio. '
        'Regenere a chave marcando a permissão de posições/trading.');
  } else {
    stdout.writeln('  detalhe: ${_curto(port.body)}');
  }
}

String _curto(String s) =>
    s.replaceAll(RegExp(r'\s+'), ' ').trim().substring(0, s.length.clamp(0, 200));

/// Imprime apenas a FORMA do JSON (chaves e tamanhos de listas), nunca os
/// valores escalares — evita vazar posições no log.
void _descreverEstrutura(Object? j, String ind, [int prof = 0]) {
  if (prof > 3) return;
  if (j is Map) {
    for (final e in j.entries) {
      final v = e.value;
      if (v is Map) {
        stdout.writeln('$ind${e.key}: {objeto}');
        _descreverEstrutura(v, '$ind  ', prof + 1);
      } else if (v is List) {
        stdout.writeln('$ind${e.key}: [lista com ${v.length} item(ns)]');
        if (v.isNotEmpty) _descreverEstrutura(v.first, '$ind  ', prof + 1);
      } else {
        stdout.writeln('$ind${e.key}: <${v.runtimeType}>');
      }
    }
  } else if (j is List) {
    stdout.writeln('${ind}lista com ${j.length} item(ns)');
    if (j.isNotEmpty) _descreverEstrutura(j.first, '$ind  ', prof + 1);
  }
}

Future<void> _radar(Lab lab) async {
  final ctx = await lab.carregar();
  if (ctx.sinais.isEmpty) {
    stdout.writeln('Sem dados — rode `lab update` primeiro.');
    return;
  }
  final resultados = <(Indicator, RadarPico)>[];
  for (final ind in catalogoInicial.where((i) => i.negociavel)) {
    final s = ctx.series[ind.id];
    if (s == null) continue;
    final r = radarPico(s);
    if (r != null) resultados.add((ind, r));
  }
  resultados.sort((a, b) => b.$2.prob.compareTo(a.$2.prob));

  stdout.writeln('📡 RADAR DE PICOS — probabilidade empírica de virada '
      'em ~21 pregões\n');
  if (resultados.isEmpty) {
    stdout.writeln('Nenhum ativo em estado esticado hoje — sem candidato '
        'a pico.');
  }
  for (final (ind, r) in resultados) {
    final tk = etoroPorIndicador[ind.id]?.ticker;
    stdout.writeln('${r.tipo == 'topo' ? '⛰ TOPO — pico p/ baixo ' : '🕳 FUNDO — virada p/ cima'}  '
        '${ind.nome}${tk != null ? '  [eToro: $tk]' : ''}');
    stdout.writeln('   virada: ${pct(r.prob, comSinal: false, dec: 0)} '
        '(n=${r.n}) · mediana dos 21d seguintes: ${pct(r.medianaFwd21)}');
    stdout.writeln('   ${r.leituras.join(' · ')}\n');
  }
  stdout.writeln('Leitura honesta: 99% não existe em mercado; acima de '
      '70% já é raro — trate como alerta forte, não como certeza.');
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
      final btOp = o.backtest;
      if (btOp != null && !btOp.winRate.isNaN) {
        stdout.writeln('    Eficácia histórica da ${btOp.kind.label}: '
            '${pct(btOp.winRate, comSinal: false, dec: 0)} em '
            '${btOp.nTrades} trades');
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

Future<void> _publish(Lab lab) async {
  final ctx = await lab.carregar();
  if (ctx.sinais.isEmpty) {
    stdout.writeln('Sem dados — rode `lab update` primeiro.');
    return;
  }
  final hs = await lab.lerHipoteses();

  final sep = Platform.pathSeparator;
  final dataDir = Directory('${lab.root.path}${sep}public${sep}data');
  await dataDir.create(recursive: true);

  final data = dashboardJson(lab, ctx, hs);
  // Motor de Track Record: registra os sinais de hoje (Firestore, idempotente
  // por data), lê o log completo e mede o desempenho REAL das recomendações.
  // Degrada em silêncio sem cofre (rodando local).
  try {
    final log = await const TrackRecordStore().registrarEObterLog(data);
    final placar = const TrackRecordScorer().consolidar(log, ctx.series);
    data['placar'] = placarJson(placar);
  } catch (e) {
    stdout.writeln('Track record: pulado (${e.runtimeType}).');
  }

  final json = const JsonEncoder.withIndent(' ').convert(data);
  await File('${dataDir.path}${sep}dashboard.json').writeAsString(json);
  stdout.writeln('public/data/dashboard.json gerado.');

  await _report(lab);
  final hoje = DateTime.now();
  final rel = File('${lab.root.path}${sep}reports${sep}relatorio_'
      '${hoje.year}-${hoje.month.toString().padLeft(2, '0')}-'
      '${hoje.day.toString().padLeft(2, '0')}.md');
  if (await rel.exists()) {
    await rel.copy('${lab.root.path}${sep}public${sep}relatorio.txt');
    stdout.writeln('public/relatorio.txt atualizado.');
  }
  stdout.writeln('\nPara publicar: firebase deploy --only hosting '
      '-P quantlab-lde');
}
