import 'package:quant_core/quant_core.dart';

/// Motor de Track Record — mede o desempenho REAL das recomendações que o
/// sistema emitiu AO VIVO, fechando o ciclo quant: prever → emitir → MEDIR →
/// afinar. Sem isto, tudo é backtest (o passado reencenado); com isto, temos
/// a prova de edge e a base honesta para calibrar cortes, pesos e alavancagem.
///
/// Domínio PURO: sem I/O, sem HTTP, sem Firestore. Recebe o log de sinais
/// registrados (gravados no dia da emissão) e as séries de preço já baixadas,
/// e devolve o placar. Quem persiste o log (Firestore) é a camada de
/// aplicação; quem exibe (web/app) só lê o resultado.

/// Janela de avaliação (em meses) por horizonte — casa com a `janelaRetorno`
/// publicada no dashboard (curto = 3m; médio/longo = 12m).
int janelaMesesDe(String horizonte) => horizonte == 'curto' ? 3 : 12;

/// Um sinal como foi EMITIDO num dia — o preço de entrada é gravado ao vivo
/// (não recalculado depois), para não haver look-ahead na entrada.
class SinalRegistrado {
  const SinalRegistrado({
    required this.data,
    required this.horizonte,
    required this.ativoId,
    required this.direcao,
    required this.precoEntrada,
    required this.assertividadePrevista,
    required this.alavancagem,
    required this.janelaMeses,
  });

  /// Dia em que o sinal foi emitido (o snapshot é idempotente por data).
  final DateTime data;

  /// 'curto' | 'medio' | 'longo'.
  final String horizonte;
  final String ativoId;

  /// 'compra' | 'venda'.
  final String direcao;

  /// Preço registrado no momento da emissão (fechamento do dia).
  final double precoEntrada;

  /// Assertividade PREVISTA no momento da emissão, em [0, 1].
  final double assertividadePrevista;

  /// Alavancagem recomendada na emissão.
  final int alavancagem;

  /// Janela de avaliação em meses (3 ou 12).
  final int janelaMeses;

  bool get compra => direcao == 'compra';

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Map<String, Object?> toJson() => {
        'data': _iso(data),
        'horizonte': horizonte,
        'ativoId': ativoId,
        'direcao': direcao,
        'precoEntrada': precoEntrada,
        'assertividade': assertividadePrevista,
        'alavancagem': alavancagem,
        'janelaMeses': janelaMeses,
      };

  factory SinalRegistrado.fromJson(Map<String, Object?> j) => SinalRegistrado(
        data: DateTime.parse(j['data']! as String),
        horizonte: j['horizonte'] as String? ?? 'curto',
        ativoId: j['ativoId']! as String,
        direcao: j['direcao'] as String? ?? 'compra',
        precoEntrada: (j['precoEntrada'] as num).toDouble(),
        assertividadePrevista: (j['assertividade'] as num?)?.toDouble() ?? 0,
        alavancagem: (j['alavancagem'] as num?)?.toInt() ?? 1,
        janelaMeses: (j['janelaMeses'] as num?)?.toInt() ?? 3,
      );
}

/// Um sinal já pontuado contra o que o mercado fez de fato.
class SinalPontuado {
  const SinalPontuado({
    required this.sinal,
    required this.precoSaida,
    required this.dataSaida,
    required this.fechado,
    required this.retornoDirecional,
    required this.retornoAlavancado,
  });

  final SinalRegistrado sinal;
  final double precoSaida;
  final DateTime dataSaida;

  /// true = a janela do horizonte já se cumpriu (resultado REAL, entra no
  /// hit-rate). false = ainda em aberto (marcado a mercado, exibido à parte).
  final bool fechado;

  /// Retorno na DIREÇÃO apontada (venda inverte o sinal do retorno bruto).
  final double retornoDirecional;

  /// Retorno com a alavancagem recomendada, com piso em -100% (liquidação:
  /// não se perde mais do que a margem).
  final double retornoAlavancado;

  bool get acerto => retornoDirecional > 0;
}

/// Placar consolidado de um horizonte (só dos sinais FECHADOS para as taxas;
/// os abertos entram apenas como mark-to-market médio).
class PlacarHorizonte {
  const PlacarHorizonte({
    required this.horizonte,
    required this.nFechados,
    required this.nAbertos,
    required this.hitRate,
    required this.retornoMedioDirecional,
    required this.assertividadePrevistaMedia,
    required this.retornoAcum,
    required this.retornoAcumAlav,
    required this.equity,
    required this.plAbertoMedio,
  });

  final String horizonte;
  final int nFechados;
  final int nAbertos;

  /// Fração de acertos entre os fechados; null se ainda não há fechados.
  final double? hitRate;
  final double? retornoMedioDirecional;

  /// Média das assertividades PREVISTAS dos fechados (para calibração).
  final double? assertividadePrevistaMedia;

  /// Retorno acumulado compondo os fechados em sequência de fechamento
  /// (equal-weight, 1 posição por vez). Ilustrativo.
  final double retornoAcum;
  final double retornoAcumAlav;

  /// Curva de capital (sem alavancagem), ponto a ponto na ordem de
  /// fechamento — começa em 1,0.
  final List<double> equity;

  /// P&L médio (mark-to-market) das posições ainda em aberto; null se nenhuma.
  final double? plAbertoMedio;
}

/// Faixa de calibração: entre os sinais fechados cuja assertividade prevista
/// caiu nesta faixa, qual foi a taxa de acerto REAL?
class FaixaCalibracao {
  const FaixaCalibracao({
    required this.de,
    required this.ate,
    required this.n,
    required this.hitRateReal,
    required this.previstoMedio,
  });

  final double de;
  final double ate;
  final int n;
  final double hitRateReal;
  final double previstoMedio;
}

/// Placar geral do sistema.
class Placar {
  const Placar({
    required this.porHorizonte,
    required this.calibracao,
    required this.totalSinais,
    required this.totalFechados,
    required this.desde,
  });

  final Map<String, PlacarHorizonte> porHorizonte;
  final List<FaixaCalibracao> calibracao;
  final int totalSinais;
  final int totalFechados;

  /// Data do primeiro sinal registrado (início do tracking); null se vazio.
  final DateTime? desde;
}

/// Serviço de domínio que pontua o log de sinais contra as séries realizadas.
class TrackRecordScorer {
  const TrackRecordScorer();

  /// Pontua cada sinal do [log] usando as [series] de preço. [hoje] permite
  /// testes determinísticos (default: agora).
  List<SinalPontuado> pontuar(
    List<SinalRegistrado> log,
    Map<String, TimeSeries> series, {
    DateTime? hoje,
  }) {
    final agora = hoje ?? DateTime.now();
    final out = <SinalPontuado>[];
    for (final s in log) {
      if (s.precoEntrada <= 0) continue;
      final serie = series[s.ativoId];
      if (serie == null || serie.isEmpty) continue;

      final alvo = _somaMeses(s.data, s.janelaMeses);
      final ultima = serie.last;
      // fechado só quando EXISTE um preço observado em ou após a data-alvo E
      // essa data-alvo já passou no calendário (nada de fechar no futuro).
      final saida = _primeiraEmOuApos(serie, alvo);
      final bool fechado = saida != null && !alvo.isAfter(agora);
      final ref = fechado ? saida : ultima;

      final bruto = ref.value / s.precoEntrada - 1;
      final dir = s.compra ? bruto : -bruto;
      final alav = _pisoLiquidacao(dir * s.alavancagem);
      out.add(SinalPontuado(
        sinal: s,
        precoSaida: ref.value,
        dataSaida: ref.date,
        fechado: fechado,
        retornoDirecional: dir,
        retornoAlavancado: alav,
      ));
    }
    return out;
  }

  /// Consolida o placar por horizonte + calibração previsto×realizado.
  Placar consolidar(
    List<SinalRegistrado> log,
    Map<String, TimeSeries> series, {
    DateTime? hoje,
  }) {
    final pontuados = pontuar(log, series, hoje: hoje);
    final porH = <String, PlacarHorizonte>{};
    for (final h in const ['curto', 'medio', 'longo']) {
      final doH = pontuados.where((p) => p.sinal.horizonte == h).toList();
      final fechados = doH.where((p) => p.fechado).toList()
        ..sort((a, b) => a.dataSaida.compareTo(b.dataSaida));
      final abertos = doH.where((p) => !p.fechado).toList();
      if (doH.isEmpty) continue;

      double? hit, retMedio, assMedia, plAberto;
      var acum = 1.0, acumAlav = 1.0;
      final equity = <double>[1.0];
      if (fechados.isNotEmpty) {
        hit = fechados.where((p) => p.acerto).length / fechados.length;
        retMedio = _media(fechados.map((p) => p.retornoDirecional));
        assMedia = _media(fechados.map((p) => p.sinal.assertividadePrevista));
        for (final p in fechados) {
          acum *= 1 + p.retornoDirecional;
          acumAlav *= 1 + p.retornoAlavancado;
          equity.add(acum);
        }
      }
      if (abertos.isNotEmpty) {
        plAberto = _media(abertos.map((p) => p.retornoDirecional));
      }
      porH[h] = PlacarHorizonte(
        horizonte: h,
        nFechados: fechados.length,
        nAbertos: abertos.length,
        hitRate: hit,
        retornoMedioDirecional: retMedio,
        assertividadePrevistaMedia: assMedia,
        retornoAcum: acum - 1,
        retornoAcumAlav: acumAlav - 1,
        equity: equity,
        plAbertoMedio: plAberto,
      );
    }

    DateTime? desde;
    for (final s in log) {
      if (desde == null || s.data.isBefore(desde)) desde = s.data;
    }

    return Placar(
      porHorizonte: porH,
      calibracao: _calibracao(pontuados.where((p) => p.fechado)),
      totalSinais: log.length,
      totalFechados: pontuados.where((p) => p.fechado).length,
      desde: desde,
    );
  }

  static const _faixas = [
    (0.55, 0.60),
    (0.60, 0.65),
    (0.65, 0.70),
    (0.70, 0.80),
    (0.80, 1.01),
  ];

  List<FaixaCalibracao> _calibracao(Iterable<SinalPontuado> fechados) {
    final out = <FaixaCalibracao>[];
    for (final (de, ate) in _faixas) {
      final naFaixa = fechados
          .where((p) =>
              p.sinal.assertividadePrevista >= de &&
              p.sinal.assertividadePrevista < ate)
          .toList();
      if (naFaixa.isEmpty) continue;
      out.add(FaixaCalibracao(
        de: de,
        ate: ate,
        n: naFaixa.length,
        hitRateReal: naFaixa.where((p) => p.acerto).length / naFaixa.length,
        previstoMedio:
            _media(naFaixa.map((p) => p.sinal.assertividadePrevista))!,
      ));
    }
    return out;
  }

  /// Primeira observação com data em ou após [alvo] (série é crescente).
  /// null = a janela ainda não se cumpriu nos dados que temos.
  static Observation? _primeiraEmOuApos(TimeSeries s, DateTime alvo) {
    for (final o in s.observations) {
      if (!o.date.isBefore(alvo)) return o;
    }
    return null;
  }

  static DateTime _somaMeses(DateTime d, int meses) =>
      DateTime(d.year, d.month + meses, d.day);

  /// Piso de liquidação: com margem, a perda não passa de -100%.
  static double _pisoLiquidacao(double r) => r < -1.0 ? -1.0 : r;

  static double? _media(Iterable<double> xs) {
    var soma = 0.0, n = 0;
    for (final x in xs) {
      if (x.isFinite) {
        soma += x;
        n++;
      }
    }
    return n == 0 ? null : soma / n;
  }
}
