import 'package:quant_core/quant_core.dart';
import 'package:quant_engine/quant_engine.dart';
import 'package:test/test.dart';

/// Série diária a partir de uma data-base, um valor por dia corrido.
TimeSeries _serie(String id, DateTime inicio, List<double> vals) => TimeSeries(
      id,
      [
        for (var i = 0; i < vals.length; i++)
          Observation(inicio.add(Duration(days: i)), vals[i]),
      ],
    );

SinalRegistrado _sinal({
  required DateTime data,
  String horizonte = 'curto',
  String ativoId = 'ativo',
  String direcao = 'compra',
  double precoEntrada = 100,
  double assertividade = 0.60,
  int alavancagem = 1,
}) =>
    SinalRegistrado(
      data: data,
      horizonte: horizonte,
      ativoId: ativoId,
      direcao: direcao,
      precoEntrada: precoEntrada,
      assertividadePrevista: assertividade,
      alavancagem: alavancagem,
      janelaMeses: janelaMesesDe(horizonte),
    );

void main() {
  const scorer = TrackRecordScorer();
  final base = DateTime(2026, 1, 1);

  group('pontuar — retorno realizado close-to-close', () {
    test('compra que subiu 20% em 3m conta como ACERTO fechado', () {
      // 130 dias de preço 100→120 (linear); janela curta = 3 meses.
      final serie = _serie('ativo', base,
          [for (var i = 0; i < 130; i++) 100 + 20 * (i / 129)]);
      final log = [_sinal(data: base, precoEntrada: 100)];
      final hoje = base.add(const Duration(days: 130));

      final p = scorer.pontuar(log, {'ativo': serie}, hoje: hoje).single;
      expect(p.fechado, isTrue);
      expect(p.acerto, isTrue);
      // saída ~ preço no dia >= base+3 meses (2026-04-01 = dia 90)
      expect(p.retornoDirecional, greaterThan(0));
      expect(p.dataSaida.isBefore(base.add(const Duration(days: 130))), isTrue);
    });

    test('venda inverte o sinal: queda vira acerto', () {
      final serie =
          _serie('ativo', base, [for (var i = 0; i < 130; i++) 100 - 0.1 * i]);
      final log = [_sinal(data: base, direcao: 'venda', precoEntrada: 100)];
      final hoje = base.add(const Duration(days: 130));

      final p = scorer.pontuar(log, {'ativo': serie}, hoje: hoje).single;
      expect(p.fechado, isTrue);
      expect(p.acerto, isTrue,
          reason: 'preço caiu; numa VENDA isso é acerto');
      expect(p.retornoDirecional, greaterThan(0));
    });

    test('janela ainda não cumprida → EM ABERTO (mark-to-market)', () {
      // só 30 dias de dados após a emissão; janela curta precisa de 3 meses.
      final serie =
          _serie('ativo', base, [for (var i = 0; i < 30; i++) 100.0 + i]);
      final log = [_sinal(data: base, precoEntrada: 100)];
      final hoje = base.add(const Duration(days: 30));

      final p = scorer.pontuar(log, {'ativo': serie}, hoje: hoje).single;
      expect(p.fechado, isFalse);
      expect(p.precoSaida, closeTo(129, 1e-9)); // último preço
    });

    test('nunca fecha no futuro mesmo se houver preço na data-alvo', () {
      // temos a série inteira, mas HOJE ainda é o dia da emissão.
      final serie =
          _serie('ativo', base, [for (var i = 0; i < 200; i++) 100.0 + i]);
      final log = [_sinal(data: base, precoEntrada: 100)];

      final p = scorer.pontuar(log, {'ativo': serie}, hoje: base).single;
      expect(p.fechado, isFalse,
          reason: 'a data-alvo (base+3m) é futura em relação a hoje');
    });

    test('alavancagem multiplica e tem piso de liquidação em -100%', () {
      // cai 40% numa compra alavancada 5x → -200% sem piso; piso corta a -100%.
      final serie = _serie(
          'ativo', base, [for (var i = 0; i < 130; i++) 100 - 40 * (i / 129)]);
      final log = [_sinal(data: base, precoEntrada: 100, alavancagem: 5)];
      final hoje = base.add(const Duration(days: 130));

      final p = scorer.pontuar(log, {'ativo': serie}, hoje: hoje).single;
      expect(p.retornoDirecional, lessThan(0));
      expect(p.retornoAlavancado, closeTo(-1.0, 1e-9));
    });

    test('sem série ou preço inválido → sinal ignorado', () {
      final log = [
        _sinal(data: base, ativoId: 'sem_serie'),
        _sinal(data: base, precoEntrada: 0),
      ];
      expect(scorer.pontuar(log, const {}), isEmpty);
    });
  });

  group('consolidar — placar, hit-rate e calibração', () {
    test('hit-rate real separa fechados de abertos', () {
      // série sobe monotonicamente 200 dias.
      final serie =
          _serie('ativo', base, [for (var i = 0; i < 200; i++) 100.0 + i]);
      // 3 compras fechadas (subiram) + 1 emitida hoje (aberta).
      final hoje = base.add(const Duration(days: 200));
      final log = [
        _sinal(data: base, precoEntrada: 100),
        _sinal(data: base.add(const Duration(days: 10)), precoEntrada: 110),
        _sinal(data: base.add(const Duration(days: 20)), precoEntrada: 120),
        _sinal(data: hoje, precoEntrada: 300), // aberta
      ];

      final placar = scorer.consolidar(log, {'ativo': serie}, hoje: hoje);
      final curto = placar.porHorizonte['curto']!;
      expect(curto.nFechados, 3);
      expect(curto.nAbertos, 1);
      expect(curto.hitRate, 1.0);
      expect(curto.retornoAcum, greaterThan(0));
      expect(curto.equity.first, 1.0);
      expect(curto.equity.length, 4); // 1 + 3 fechados
      expect(placar.totalSinais, 4);
      expect(placar.totalFechados, 3);
      expect(placar.desde, base);
    });

    test('calibração: acerto real por faixa de assertividade prevista', () {
      // ativo que SEMPRE sobe → toda compra fechada é acerto (100% real).
      final serie =
          _serie('ativo', base, [for (var i = 0; i < 200; i++) 100.0 + i]);
      final hoje = base.add(const Duration(days: 200));
      final log = [
        _sinal(data: base, precoEntrada: 100, assertividade: 0.58),
        _sinal(
            data: base.add(const Duration(days: 5)),
            precoEntrada: 105,
            assertividade: 0.72),
      ];

      final placar = scorer.consolidar(log, {'ativo': serie}, hoje: hoje);
      expect(placar.calibracao, isNotEmpty);
      // toda faixa presente deve ter hit-rate real 1,0 aqui
      for (final f in placar.calibracao) {
        expect(f.hitRateReal, 1.0);
        expect(f.n, greaterThanOrEqualTo(1));
      }
      // a faixa 0.55–0.60 e a 0.70–0.80 devem existir
      expect(placar.calibracao.any((f) => f.de == 0.55), isTrue);
      expect(placar.calibracao.any((f) => f.de == 0.70), isTrue);
    });

    test('log vazio → placar vazio sem quebrar', () {
      final placar = scorer.consolidar(const [], const {});
      expect(placar.porHorizonte, isEmpty);
      expect(placar.totalSinais, 0);
      expect(placar.desde, isNull);
    });
  });

  group('SinalRegistrado round-trip JSON', () {
    test('toJson/fromJson preserva os campos', () {
      final s = _sinal(
          data: DateTime(2026, 7, 14),
          horizonte: 'medio',
          direcao: 'venda',
          precoEntrada: 42.5,
          assertividade: 0.63,
          alavancagem: 2);
      final r = SinalRegistrado.fromJson(s.toJson());
      expect(r.data, s.data);
      expect(r.horizonte, 'medio');
      expect(r.direcao, 'venda');
      expect(r.precoEntrada, 42.5);
      expect(r.assertividadePrevista, closeTo(0.63, 1e-12));
      expect(r.alavancagem, 2);
      expect(r.janelaMeses, 12);
    });
  });
}
