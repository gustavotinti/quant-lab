import 'dart:math' as math;

import 'package:quant_core/quant_core.dart';
import 'package:quant_engine/quant_engine.dart';
import 'package:test/test.dart';

TimeSeries _serieDiaria(String id, double Function(int i) f, int n) =>
    TimeSeries(id, [
      for (var i = 0; i < n; i++)
        Observation(DateTime(2015, 1, 1).add(Duration(days: i)), f(i)),
    ]);

void main() {
  group('AssetSignals', () {
    test('tendência de alta produz momentum e distSma200 positivos', () {
      final s = AssetSignals.fromDaily(
          _serieDiaria('up', (i) => 100 * math.pow(1.0005, i).toDouble(), 800));
      expect(s.momentum12x1, isNotNull);
      expect(s.momentum12x1!, greaterThan(0));
      expect(s.distSma200!, greaterThan(0));
      expect(s.cagr3y!, greaterThan(0));
      expect(s.ddDoTopo, closeTo(0, 1e-9)); // sempre no topo
    });

    test('série curta não quebra — sinais longos ficam nulos', () {
      final s = AssetSignals.fromDaily(_serieDiaria('curta', (i) => 100.0 + i, 30));
      expect(s.momentum12x1, isNull);
      expect(s.distSma200, isNull);
      expect(s.ret1m, isNotNull);
    });
  });

  group('trendBacktest', () {
    test('em alta persistente, estratégia ≈ buy & hold e sobrevive OOS', () {
      final serie = _serieDiaria(
          'bull', (i) => 100 * math.pow(1.0006, i).toDouble(), 1500);
      final bt = trendBacktest(serie)!;
      expect(bt.estrategia.totalReturn, greaterThan(0));
      expect(bt.sobreviveuForaDaAmostra, isTrue);
      // sempre acima da SMA-200 → nenhuma troca de posição
      expect(bt.trocasDePosicao, 0);
      expect(bt.estrategia.totalReturn,
          closeTo(bt.buyHold.totalReturn, 1e-9));
      // walk-forward: todas as 3 janelas positivas em alta persistente
      expect(bt.segmentos, hasLength(3));
      expect(bt.segmentosPositivos, 3);
    });

    test('winRate conta trades fechados na direção da posição', () {
      // sobe 700 dias, cai 60% nos 700 seguintes → 1 trade comprado longo
      // (lucrativo, fechado quando o preço cruza a SMA-200 para baixo)
      final serie = _serieDiaria(
          'ciclo',
          (i) => i < 700
              ? 100 * math.pow(1.001, i).toDouble()
              : 100 *
                  math.pow(1.001, 700).toDouble() *
                  math.pow(0.9987, i - 700).toDouble(),
          1400);
      final bt = trendBacktest(serie)!;
      expect(bt.nTrades, greaterThanOrEqualTo(1));
      expect(bt.tradeReturns.first, greaterThan(0));
      // menos de 5 trades → eficácia vira NaN, nunca um número enganoso
      if (bt.nTrades < 5) expect(bt.winRate.isNaN, isTrue);
      // tendência é long-only: nenhum trade vendido
      expect(bt.nTradesDirecional(-1), 0);
      expect(bt.winRateDirecional(-1).isNaN, isTrue);
      // com <5 trades, expectância e payoff também viram NaN
      if (bt.nTrades < 5) {
        expect(bt.expectanciaDirecional(1).isNaN, isTrue);
        expect(bt.payoffDirecional(1).isNaN, isTrue);
      }
    });

    test('expectância e payoff em série ruidosa com trades suficientes', () {
      // ruído senoidal sobre tendência de alta → reversão gera vários trades
      final serie = _serieDiaria(
          'osc',
          (i) =>
              100 *
              math.pow(1.0004, i).toDouble() *
              (1 + 0.08 * math.sin(i / 9)),
          1600);
      final bt = strategyBacktest(serie, StrategyKind.reversao)!;
      if (bt.nTrades >= 5) {
        final e = bt.expectanciaDirecional(1);
        final p = bt.payoffDirecional(1);
        expect(e.isFinite, isTrue);
        if (!p.isNaN) expect(p, greaterThan(0));
      }
    });

    test('estratégia corta a perda em colapso prolongado', () {
      // sobe 700 dias, cai 60% nos 700 seguintes
      final serie = _serieDiaria(
          'crash',
          (i) => i < 700
              ? 100 * math.pow(1.001, i).toDouble()
              : 100 *
                  math.pow(1.001, 700).toDouble() *
                  math.pow(0.9987, i - 700).toDouble(),
          1400);
      final bt = trendBacktest(serie)!;
      expect(bt.estrategia.maxDd, greaterThan(bt.buyHold.maxDd));
      expect(bt.estrategia.totalReturn, greaterThan(bt.buyHold.totalReturn));
    });

    test('série insuficiente retorna null', () {
      expect(trendBacktest(_serieDiaria('mini', (i) => 100.0 + i, 100)), isNull);
    });
  });

  group('estratégias adicionais', () {
    final bull = _serieDiaria(
        'bull', (i) => 100 * math.pow(1.0006, i).toDouble(), 1500);

    test('momentum 12-1 fica comprado em alta persistente', () {
      final bt = strategyBacktest(bull, StrategyKind.momentum)!;
      expect(bt.kind, StrategyKind.momentum);
      expect(bt.estrategia.totalReturn, greaterThan(0));
      expect(bt.sobreviveuForaDaAmostra, isTrue);
    });

    test('reversão fica de fora em tendência limpa (z nunca extremo)', () {
      final bt = strategyBacktest(bull, StrategyKind.reversao)!;
      // sem entradas → retorno zero, mas nunca perde
      expect(bt.estrategia.totalReturn, greaterThanOrEqualTo(0));
      expect(bt.estrategia.maxDd, greaterThanOrEqualTo(-0.05));
    });

    test('pack mapeia estratégia por horizonte', () {
      final pack = BacktestPack.fromDaily(bull);
      expect(pack.porHorizonte(Horizon.curto)!.kind, StrategyKind.reversao);
      expect(pack.porHorizonte(Horizon.medio)!.kind, StrategyKind.momentum);
      expect(pack.porHorizonte(Horizon.longo)!.kind, StrategyKind.tendencia);
    });
  });

  group('assertividade e política de emissão', () {
    test('combinação ponderada com suavização (valores conhecidos)', () {
      // wr=0,6 (n=30) e fav=0,7 (n=70) → (18+49+5)/110
      final a = assertividadeCombinada(
          winRate: 0.6, nTrades: 30, favoravel: 0.7, nAnalogos: 70)!;
      expect(a.valor, closeTo(72 / 110, 1e-12));
      expect(a.base, 100);
    });

    test('amostra pequena encolhe para perto de 50%', () {
      // 6 acertos em 6 trades → 68,75%, nunca 100%
      final a = assertividadeCombinada(winRate: 1.0, nTrades: 6)!;
      expect(a.valor, closeTo(11 / 16, 1e-12));
    });

    test('sem evidência → null → ação OBSERVAR', () {
      expect(assertividadeCombinada(), isNull);
      expect(decidirAcao(compra: true, venda: false, assertividade: null),
          Acao.observar);
    });

    test('corte de 55% segura sinais historicamente fracos', () {
      expect(
          decidirAcao(
              compra: true,
              venda: false,
              assertividade: const Assertividade(0.52, 40)),
          Acao.ficarDeFora);
      expect(
          decidirAcao(
              compra: false,
              venda: true,
              assertividade: const Assertividade(0.61, 40)),
          Acao.vender);
      expect(decidirAcao(compra: false, venda: false, assertividade: null),
          Acao.ficarDeFora);
    });
  });

  group('sazonalidade de calendário', () {
    // 24 anos diários: dezembro sobe ~5% (drift diário), resto ~flat.
    TimeSeries comDezembro() {
      final obs = <Observation>[];
      var nivel = 100.0;
      final rng = math.Random(7);
      for (var d = DateTime(2000, 1, 3);
          d.isBefore(DateTime(2024, 1, 1));
          d = d.add(const Duration(days: 1))) {
        if (d.weekday >= 6) continue; // só pregões
        final drift = d.month == 12 ? 0.0023 : 0.0;
        nivel *= 1 + drift + (rng.nextDouble() - 0.5) * 0.002;
        obs.add(Observation(d, nivel));
      }
      return TimeSeries('sazonal', obs);
    }

    test('dezembro plantado é detectado, significativo e confirmado', () {
      final saz = sazonalidadeDoMes(comDezembro(), 12)!;
      expect(saz.n, greaterThanOrEqualTo(20));
      expect(saz.media, greaterThan(0.02));
      expect(saz.pValor, lessThan(0.05));
      expect(saz.confirmadaForaDaAmostra, isTrue);
      expect(saz.relevante, isTrue);
      expect(saz.nomeMes, 'dezembro');
    });

    test('mês sem efeito plantado não vira evidência', () {
      final saz = sazonalidadeDoMes(comDezembro(), 5);
      // maio é só ruído: ou nem mede, ou não é relevante
      expect(saz?.relevante ?? false, isFalse);
    });

    test('série curta → null (sem chute)', () {
      final curta = _serieDiaria('curta', (i) => 100.0 + i, 400);
      expect(sazonalidadeDoMes(curta, 12), isNull);
    });

    test('mesSazonalAlvo: próximo mês, com virada de ano', () {
      expect(mesSazonalAlvo(DateTime(2026, 7, 15)), 8);
      expect(mesSazonalAlvo(DateTime(2026, 12, 3)), 1);
    });

    test('entra como evidência do curto prazo no OpportunityEngine', () {
      final serie = comDezembro();
      Indicator ind(String id) => Indicator(
            id: id,
            nome: id,
            unidade: 'pontos',
            frequency: Frequency.daily,
            category: Category.commodities,
            source: DataSource(provider: 'x', code: id, tier: SourceTier.b),
            negociavel: true,
          );
      final saz = sazonalidadeDoMes(serie, 12)!;
      final ops = const OpportunityEngine().avaliar(
        ativos: [ind('sazonal')],
        sinais: {'sazonal': AssetSignals.fromDaily(serie)},
        backtests: {'sazonal': BacktestPack.fromDaily(serie)},
        macro: null,
        horizon: Horizon.curto,
        sazonalidades: {'sazonal': saz},
      );
      expect(
          ops.single.evidencias.any((e) => e.texto.contains('Sazonalidade')),
          isTrue);
    });
  });

  group('emissão pelo Radar de Picos', () {
    test('fundo 81% com 16 análogos → COMPRA com Laplace (69%)', () {
      // o caso real do Gás Natural: radar diz fundo 81% (n=16) mas as
      // estratégias clássicas não têm sinal → o radar emite a ordem
      final e = emissaoDoRadar(
          tipo: 'fundo', prob: 0.81, n: 16, medianaFwd21: 0.04)!;
      expect(e.compra, isTrue);
      // Laplace k=10: (0,81·16 + 5) / 26
      expect(e.assertividade.valor, closeTo((0.81 * 16 + 5) / 26, 1e-12));
      expect(e.assertividade.valor, greaterThan(0.65)); // passa até no conservador
      expect(e.retornoEsperado, closeTo(0.04, 1e-12));
    });

    test('topo vira VENDA e o retorno esperado inverte o sinal', () {
      final e = emissaoDoRadar(
          tipo: 'topo', prob: 0.80, n: 16, medianaFwd21: -0.03)!;
      expect(e.compra, isFalse);
      expect(e.retornoEsperado, closeTo(0.03, 1e-12));
    });

    test('probabilidade alta mas amostra pequena → suavização segura', () {
      // 75% em n=12 → (9+5)/22 = 63,6% ≥ 55% emite; mas 60% em n=12
      // → (7,2+5)/22 = 55,45% no limite; 58% em n=12 → 55,4%... e 55%
      // em n=12 → (6,6+5)/22 = 52,7% < 55% NÃO emite
      expect(emissaoDoRadar(
          tipo: 'fundo', prob: 0.55, n: 12, medianaFwd21: 0.02), isNull);
      expect(emissaoDoRadar(
          tipo: 'fundo', prob: 0.75, n: 12, medianaFwd21: 0.02), isNotNull);
    });

    test('mediana desfavorável ou nula segura a ordem (sem magnitude)', () {
      // 80% dos análogos viraram, mas a mediana é negativa na direção:
      // virada frequente e rasa não paga o trade
      expect(emissaoDoRadar(
          tipo: 'fundo', prob: 0.80, n: 16, medianaFwd21: -0.01), isNull);
      expect(emissaoDoRadar(
          tipo: 'topo', prob: 0.80, n: 16, medianaFwd21: 0.01), isNull);
      expect(emissaoDoRadar(
          tipo: 'fundo', prob: 0.80, n: 16, medianaFwd21: 0.0), isNull);
    });

    test('n abaixo do mínimo ou tipo inválido → null', () {
      expect(emissaoDoRadar(
          tipo: 'fundo', prob: 0.90, n: 11, medianaFwd21: 0.05), isNull);
      expect(emissaoDoRadar(
          tipo: 'lateral', prob: 0.90, n: 16, medianaFwd21: 0.05), isNull);
    });
  });

  group('PortfolioSizer (política de alocação — fonte única)', () {
    const sizer = PortfolioSizer();
    CandidatoOrdem cand(String id, String cat,
            {double ass = 0.60,
            double stop = 0.05,
            int lev = 1,
            double ret = 0.10}) =>
        CandidatoOrdem(
            id: id,
            categoria: cat,
            assertividade: ass,
            stopEstimado: stop,
            alavancagemRecomendada: lev,
            retornoEsperado: ret);

    test('risco fixo por trade: peso = risco/stop, limitado por ativo', () {
      // moderado: 1% de risco; stop 5% → peso 20%; stop 2% → 50%→cap 25%
      final c = sizer.dimensionar(
          [cand('a', 'x', stop: 0.05), cand('b', 'y', stop: 0.02)],
          PerfilRisco.moderado);
      final pesos = {for (final o in c.ordens) o.id: o.peso};
      expect(pesos['a'], closeTo(0.20, 1e-9));
      expect(pesos['b'], closeTo(0.25, 1e-9)); // maxPesoAtivo
      expect(c.caixaPct, closeTo(0.55, 1e-9));
    });

    test('corte de assertividade do perfil filtra candidatos', () {
      final c = sizer.dimensionar(
          [cand('fraco', 'x', ass: 0.60), cand('forte', 'x', ass: 0.70)],
          PerfilRisco.conservador); // corte 0,65
      expect(c.ordens.map((o) => o.id), ['forte']);
    });

    test('teto global renormaliza e teto por classe limita concentração',
        () {
      // 4 ordens de 25% (cap por ativo) = 100% > teto 70% → renormaliza
      // p/ 17,5% cada; classe 'acoes' com 3 delas = 52,5% > 35% (teto/2)
      // → escala as 3 para somarem 35%
      final c = sizer.dimensionar([
        cand('a1', 'acoes', stop: 0.01),
        cand('a2', 'acoes', stop: 0.01),
        cand('a3', 'acoes', stop: 0.01),
        cand('c1', 'cripto', stop: 0.01),
      ], PerfilRisco.moderado);
      final pesos = {for (final o in c.ordens) o.id: o.peso};
      final acoes = pesos['a1']! + pesos['a2']! + pesos['a3']!;
      expect(acoes, closeTo(0.35, 1e-9));
      expect(pesos['c1'], closeTo(0.175, 1e-9));
      expect(c.caixaPct, closeTo(1 - 0.35 - 0.175, 1e-9));
    });

    test('alavancagem recomendada é limitada pelo perfil', () {
      final c = sizer.dimensionar(
          [cand('a', 'x', lev: 5)], PerfilRisco.moderado); // máx X2
      expect(c.ordens.single.alavancagem, 2);
      final c2 =
          sizer.dimensionar([cand('a', 'x', lev: 5)], PerfilRisco.agressivo);
      expect(c2.ordens.single.alavancagem, 5);
    });

    test('ordena por retorno esperado; vazio → 100% caixa', () {
      final c = sizer.dimensionar(
          [cand('menor', 'x', ret: 0.05), cand('maior', 'x', ret: 0.20)],
          PerfilRisco.moderado);
      expect(c.ordens.first.id, 'maior');
      final vazio = sizer.dimensionar([], PerfilRisco.moderado);
      expect(vazio.ordens, isEmpty);
      expect(vazio.caixaPct, 1);
    });

    group('penalidade de correlação (diversificação real)', () {
      test('duas compras com corr=1 → a segunda vale metade', () {
        // moderado, stop 5% → peso base 20% cada; a 2ª (pior retorno
        // esperado) divide por (1+1) → 10%
        final c = sizer.dimensionar(
          [cand('a', 'x', ret: 0.20), cand('b', 'y', ret: 0.10)],
          PerfilRisco.moderado,
          correlacoes: {'a': {'b': 1.0}},
        );
        final pesos = {for (final o in c.ordens) o.id: o.peso};
        expect(pesos['a'], closeTo(0.20, 1e-9));
        expect(pesos['b'], closeTo(0.10, 1e-9));
      });

      test('compra + venda em ativos correlacionados se hedgeiam — sem corte',
          () {
        final c = sizer.dimensionar(
          [
            cand('a', 'x', ret: 0.20),
            const CandidatoOrdem(
                id: 'b',
                categoria: 'y',
                assertividade: 0.60,
                stopEstimado: 0.05,
                alavancagemRecomendada: 1,
                retornoEsperado: 0.10,
                compra: false),
          ],
          PerfilRisco.moderado,
          correlacoes: {'a': {'b': 0.9}},
        );
        final pesos = {for (final o in c.ordens) o.id: o.peso};
        expect(pesos['a'], closeTo(0.20, 1e-9));
        expect(pesos['b'], closeTo(0.20, 1e-9),
            reason: 'long A + short B correlacionados = hedge, não risco');
      });

      test('correlação acumula: a terceira compra paga pelas duas primeiras',
          () {
        final c = sizer.dimensionar(
          [
            cand('a', 'x', ret: 0.30),
            cand('b', 'y', ret: 0.20),
            cand('c', 'z', ret: 0.10),
          ],
          PerfilRisco.moderado,
          correlacoes: {
            'a': {'b': 1.0, 'c': 1.0},
            'b': {'c': 1.0},
          },
        );
        final pesos = {for (final o in c.ordens) o.id: o.peso};
        expect(pesos['a'], closeTo(0.20, 1e-9));
        expect(pesos['b'], closeTo(0.10, 1e-9)); // /(1+1)
        expect(pesos['c'], closeTo(0.20 / 3, 1e-9)); // /(1+2)
      });

      test('sem mapa de correlações → comportamento idêntico ao anterior', () {
        final c = sizer.dimensionar(
            [cand('a', 'x', stop: 0.05), cand('b', 'y', stop: 0.02)],
            PerfilRisco.moderado);
        final pesos = {for (final o in c.ordens) o.id: o.peso};
        expect(pesos['a'], closeTo(0.20, 1e-9));
        expect(pesos['b'], closeTo(0.25, 1e-9));
      });

      test('correlação negativa entre duas compras não penaliza', () {
        final c = sizer.dimensionar(
          [cand('a', 'x', ret: 0.20), cand('b', 'y', ret: 0.10)],
          PerfilRisco.moderado,
          correlacoes: {'a': {'b': -0.8}},
        );
        final pesos = {for (final o in c.ordens) o.id: o.peso};
        expect(pesos['b'], closeTo(0.20, 1e-9),
            reason: 'ativos que se movem em direções opostas diversificam');
      });
    });
  });

  group('radar de picos', () {
    // Onda senoidal: nos topos da onda, o radar deve apontar 'topo' com
    // probabilidade alta de virada (todos os análogos caíram depois).
    TimeSeries onda(int len) => _serieDiaria(
        'onda', (i) => 100 + 12 * math.sin(i / 20), len);

    test('na crista da onda: tipo topo e virada quase certa', () {
      // crista: i/20 ≈ π/2 + 2πk → i ≈ 31,4 + 125,7k → i=1916 (k=15)
      final r = radarPico(onda(1917))!;
      expect(r.tipo, 'topo');
      expect(r.prob, greaterThan(0.85));
      expect(r.medianaFwd21, lessThan(0));
      expect(r.n, greaterThanOrEqualTo(12));
    });

    test('no vale da onda: tipo fundo e virada quase certa', () {
      // vale: i ≈ 94,2 + 125,7k → i=1979 (k=15)
      final r = radarPico(onda(1980))!;
      expect(r.tipo, 'fundo');
      expect(r.prob, greaterThan(0.85));
      expect(r.medianaFwd21, greaterThan(0));
    });

    test('sem estado esticado ou série curta → null (sem chute)', () {
      expect(radarPico(_serieDiaria('curta', (i) => 100.0 + i, 300)),
          isNull);
    });
  });

  group('cenários análogos', () {
    test('em alta persistente, todos os análogos tiveram futuro positivo', () {
      final serie = _serieDiaria(
          'up', (i) => 100 * math.pow(1.0005, i).toDouble(), 1500);
      final cen = analogousScenarios(serie)!;
      expect(cen.nAnalogos, greaterThanOrEqualTo(5));
      expect(cen.fwd3m!.pctPositivo, 1.0);
      expect(cen.fwd3m!.mediana, greaterThan(0));
      // episódios espaçados: nunca dois análogos no mesmo mês
      for (var i = 1; i < cen.datas.length; i++) {
        expect(cen.datas[i].difference(cen.datas[i - 1]).inDays,
            greaterThanOrEqualTo(21));
      }
    });

    test('série curta não gera relatório', () {
      expect(
          analogousScenarios(_serieDiaria('mini', (i) => 100.0 + i, 300)),
          isNull);
    });
  });

  group('leverageAdvice', () {
    test('kelly e teto de vol calculados corretamente', () {
      // μ=10%, σ=20% → kelly = 0.10/0.04 = 2.5; meio = 1.25; teto vol = 0.75
      final a = leverageAdvice(retornoExcedenteAnual: 0.10, volAnual: 0.20);
      expect(a.kellyCheio, closeTo(2.5, 1e-9));
      expect(a.kellyMeio, closeTo(1.25, 1e-9));
      expect(a.tetoPorVolatilidade, closeTo(0.75, 1e-9));
      expect(a.sugerida, closeTo(0.75, 0.01)); // o menor dos freios
    });

    test('expectativa negativa → alavancagem zero', () {
      final a = leverageAdvice(retornoExcedenteAnual: -0.05, volAnual: 0.20);
      expect(a.sugerida, 0);
      expect(a.avisos.any((w) => w.contains('Kelly negativo')), isTrue);
    });

    test('vol acima de 40% limita a 1x', () {
      final a = leverageAdvice(retornoExcedenteAnual: 0.80, volAnual: 0.50);
      expect(a.sugerida, lessThanOrEqualTo(1.0));
    });
  });

  group('HypothesisLab', () {
    test('descobre relação defasada plantada e destrói ruído', () {
      const meses = 200;
      final rng = math.Random(42);
      final causaObs = <Observation>[];
      final efeitoObs = <Observation>[];
      final ruidoObs = <Observation>[];
      final causaVals = List.generate(meses, (_) => rng.nextDouble() * 4 - 2);
      var nivelCausa = 100.0, nivelEfeito = 100.0, nivelRuido = 100.0;
      for (var m = 0; m < meses; m++) {
        final data = DateTime(2005 + m ~/ 12, m % 12 + 1, 1);
        nivelCausa *= 1 + causaVals[m] / 100;
        // efeito segue a variação da causa de 2 meses atrás + ruído leve
        final drive = m >= 2 ? causaVals[m - 2] : 0.0;
        nivelEfeito *= 1 + (drive * 0.8 + rng.nextDouble() - 0.5) / 100;
        nivelRuido *= 1 + (rng.nextDouble() * 4 - 2) / 100;
        causaObs.add(Observation(data, nivelCausa));
        efeitoObs.add(Observation(data, nivelEfeito));
        ruidoObs.add(Observation(data, nivelRuido));
      }

      Indicator ind(String id) => Indicator(
            id: id,
            nome: id,
            unidade: 'pontos',
            frequency: Frequency.monthly,
            category: Category.acoes,
            source: DataSource(provider: 'x', code: id, tier: SourceTier.b),
            negociavel: true,
          );

      final hs = const HypothesisLab().minerar({
        ind('causa'): TimeSeries('causa', causaObs),
        ind('efeito'): TimeSeries('efeito', efeitoObs),
        ind('ruido'): TimeSeries('ruido', ruidoObs),
      });

      final plantada = hs.where((h) =>
          h.causaId == 'causa' && h.efeitoId == 'efeito' && h.lagMeses == 2);
      expect(plantada, isNotEmpty,
          reason: 'a relação plantada (lag 2) deve ser descoberta');
      expect(plantada.first.status, 'validada');
      expect(plantada.first.rhoTreino, greaterThan(0.4));

      final espuria = hs.where((h) =>
          (h.causaId == 'ruido' || h.efeitoId == 'ruido') &&
          h.status == 'validada');
      expect(espuria.length, lessThanOrEqualTo(1),
          reason: 'ruído não deve gerar enxame de hipóteses validadas');
    });
  });
}
