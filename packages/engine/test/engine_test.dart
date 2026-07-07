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
