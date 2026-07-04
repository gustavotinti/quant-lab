import 'dart:math' as math;

import 'package:quant_stats/quant_stats.dart';
import 'package:test/test.dart';

void main() {
  group('descritiva', () {
    test('média e desvio padrão amostral', () {
      final xs = [1.0, 2.0, 3.0, 4.0, 5.0];
      expect(mean(xs), 3.0);
      expect(sampleVariance(xs), closeTo(2.5, 1e-12));
      expect(sampleStd(xs), closeTo(1.5811388300841898, 1e-12));
    });

    test('z-score do último valor', () {
      // média 3, std ~1.58 → z de 5 = (5-3)/1.5811 ≈ 1.2649
      expect(zScoreLast([1.0, 2.0, 3.0, 4.0, 5.0]), closeTo(1.2649, 1e-4));
    });
  });

  group('retornos', () {
    test('retornos simples', () {
      expect(simpleReturns([100.0, 110.0, 99.0]),
          [closeTo(0.10, 1e-12), closeTo(-0.10, 1e-12)]);
    });

    test('cagr de dobrar em 2 anos = √2 - 1', () {
      expect(cagr(1.0, 2), closeTo(0.41421356, 1e-8));
    });

    test('volatilidade de retornos constantes é zero', () {
      expect(annualizedVol([0.01, 0.01, 0.01, 0.01], 252), 0);
    });

    test('composição de percentuais mensais', () {
      // 1% em 12 meses ≈ 12,6825%
      expect(compoundPercentSeries(List.filled(12, 1.0)),
          closeTo(0.12682503, 1e-8));
    });
  });

  group('médias móveis', () {
    test('sma última', () {
      expect(smaLast([1.0, 2.0, 3.0, 4.0], 2), 3.5);
      expect(smaLast([1.0, 2.0], 3), isNull);
    });

    test('série sma com janela deslizante', () {
      expect(sma([1.0, 2.0, 3.0, 4.0], 2),
          [null, 1.5, 2.5, 3.5]);
    });
  });

  group('drawdown', () {
    test('máximo drawdown', () {
      // topo 120 → fundo 60 = -50%
      expect(maxDrawdown([100.0, 120.0, 60.0, 90.0]), closeTo(-0.5, 1e-12));
    });

    test('drawdown atual', () {
      expect(currentDrawdown([100.0, 120.0, 90.0]), closeTo(-0.25, 1e-12));
      expect(currentDrawdown([100.0, 120.0]), 0);
    });
  });

  group('correlação', () {
    test('pearson perfeita e conhecida', () {
      expect(pearson([1, 2, 3], [2, 4, 6]), closeTo(1.0, 1e-12));
      expect(pearson([1, 2, 3], [6, 4, 2]), closeTo(-1.0, 1e-12));
      // caso calculado à mão: r = 8/10 = 0.8
      expect(pearson([1, 2, 3, 4, 5], [2, 1, 4, 3, 5]), closeTo(0.8, 1e-12));
    });

    test('spearman é 1 para relação monotônica não linear', () {
      expect(spearman([1, 2, 3, 4], [1, 8, 27, 64]), closeTo(1.0, 1e-12));
    });

    test('postos com empates usam mid-rank', () {
      expect(ranks([10.0, 20.0, 20.0, 30.0]), [1.0, 2.5, 2.5, 4.0]);
    });

    test('correlação defasada encontra o lag verdadeiro', () {
      // efeito[t] = causa[t-2] com ruído zero
      final causa = List.generate(50, (i) => (i * 7 % 13).toDouble());
      final efeito = List<double>.filled(50, 0);
      for (var t = 2; t < 50; t++) {
        efeito[t] = causa[t - 2];
      }
      final lags = laggedSpearman(causa, efeito, maxLag: 4, minN: 20);
      final best = lags.reduce((a, b) => a.rho.abs() >= b.rho.abs() ? a : b);
      expect(best.lag, 2);
      expect(best.rho, closeTo(1.0, 1e-9));
      expect(best.pValue, lessThan(1e-6));
    });
  });

  group('funções especiais', () {
    test('logGamma em valores conhecidos', () {
      expect(logGamma(1), closeTo(0, 1e-10)); // Γ(1)=1
      expect(logGamma(5), closeTo(3.1780538303479458, 1e-10)); // Γ(5)=24
    });

    test('CDF da t de Student', () {
      expect(studentTCdf(0, 10), closeTo(0.5, 1e-10));
      // valor de referência: P(T<=2.228, df=10) ≈ 0.975
      expect(studentTCdf(2.228, 10), closeTo(0.975, 1e-3));
    });

    test('p-valor bicaudal', () {
      expect(pValueTwoTailed(2.228, 10), closeTo(0.05, 2e-3));
    });
  });

  group('regressão', () {
    test('reta exata y = 2x + 1', () {
      final r = ols([1, 2, 3, 4], [3, 5, 7, 9]);
      expect(r.slope, closeTo(2, 1e-12));
      expect(r.intercept, closeTo(1, 1e-12));
      expect(r.r2, closeTo(1, 1e-12));
      expect(r.pValueSlope, closeTo(0, 1e-9));
    });

    test('com ruído mantém coeficiente próximo', () {
      final x = List.generate(100, (i) => i.toDouble());
      final y = [
        for (var i = 0; i < 100; i++) 2.0 * i + 1 + (i % 5 - 2) * 0.5,
      ];
      final r = ols(x, y);
      expect(r.slope, closeTo(2, 0.01));
      expect(r.pValueSlope, lessThan(1e-10));
    });
  });

  group('múltiplas comparações', () {
    test('exemplo clássico de Benjamini-Hochberg (1995), q=0.05', () {
      // 15 p-valores do artigo original; a correção rejeita exatamente 4.
      final p = [
        0.0001, 0.0004, 0.0019, 0.0095, 0.0201, 0.0278, 0.0298, 0.0344,
        0.0459, 0.3240, 0.4262, 0.4929, 0.5719, 0.7095, 1.0000,
      ];
      final mask = benjaminiHochberg(p, q: 0.05);
      expect(mask.where((r) => r).length, 4);
      expect(mask.sublist(0, 4), everyElement(isTrue));
    });

    test('NaN nunca é significativo e lista vazia não quebra', () {
      expect(benjaminiHochberg([double.nan, 0.0001], q: 0.05),
          [false, true]);
      expect(benjaminiHochberg([]), isEmpty);
    });
  });

  group('bootstrap', () {
    final rng = math.Random(7);
    final rets = List.generate(
        1000, (_) => 0.0008 + (rng.nextDouble() - 0.5) * 0.02);

    test('IC de blocos contém a estimativa pontual e é reproduzível', () {
      final a = sharpeBlockBootstrapCI(rets, 252);
      final b = sharpeBlockBootstrapCI(rets, 252);
      expect(a.lower, lessThan(a.point));
      expect(a.upper, greaterThan(a.point));
      expect(a.lower, b.lower); // mesmo seed → mesmo resultado
      expect(a.upper, b.upper);
    });

    test('amostra curta demais devolve NaN nos limites', () {
      final r = sharpeBlockBootstrapCI(rets.sublist(0, 30), 252);
      expect(r.lower.isNaN, isTrue);
    });
  });

  group('performance', () {
    test('sharpe de retornos idênticos é NaN (sem risco)', () {
      expect(sharpe([0.01, 0.01, 0.01], 252).isNaN, isTrue);
    });

    test('sharpe positivo para retornos positivos com ruído', () {
      final s = sharpe([0.01, 0.02, 0.015, 0.005, 0.02], 252);
      expect(s, greaterThan(0));
    });

    test('calmar', () {
      expect(calmar(0.20, -0.10), closeTo(2.0, 1e-12));
    });
  });
}
