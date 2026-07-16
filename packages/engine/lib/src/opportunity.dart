import 'dart:math' as math;

import 'package:quant_core/quant_core.dart';

import 'asset_signals.dart';
import 'backtest.dart';
import 'carry.dart';
import 'cross_sectional.dart';
import 'leverage.dart';
import 'macro_regime.dart';
import 'scenarios.dart';
import 'seasonality.dart';

/// Uma evidência objetiva que contribuiu para a nota da oportunidade.
/// [contribuicao] em [-1, 1]: positivo empurra para COMPRA, negativo para VENDA.
class Evidencia {
  const Evidencia(this.texto, this.contribuicao);
  final String texto;
  final double contribuicao;
}

enum DirecaoOportunidade { compra, venda, neutro }

/// Oportunidade classificada — nunca uma "recomendação". O engine mede,
/// pontua e explica; a decisão é humana.
class Oportunidade {
  const Oportunidade({
    required this.indicator,
    required this.horizon,
    required this.direcao,
    required this.score,
    required this.evidencias,
    required this.sinais,
    this.alavancagem,
    this.backtest,
  });

  final Indicator indicator;
  final Horizon horizon;
  final DirecaoOportunidade direcao;

  /// Convicção 0–100 na direção apontada (0 = nada a fazer).
  final double score;
  final List<Evidencia> evidencias;
  final AssetSignals sinais;
  final LeverageAdvice? alavancagem;
  final BacktestResult? backtest;
}

/// Combina sinais do ativo + regime macro + robustez do backtest em uma
/// nota por horizonte. Todos os componentes são funções `tanh` de razões
/// mensuráveis — sem parâmetro subjetivo escondido.
class OpportunityEngine {
  const OpportunityEngine();

  List<Oportunidade> avaliar({
    required List<Indicator> ativos,
    required Map<String, AssetSignals> sinais,
    required Map<String, BacktestPack> backtests,
    required MacroRegime? macro,
    required Horizon horizon,
    Map<String, ScenarioReport>? cenarios,
    Map<String, SazonalidadeMes>? sazonalidades,
    CrossSectionalReport? forcaRelativa,
    Map<String, CarryPar>? carries,
  }) {
    final out = <Oportunidade>[];
    for (final ind in ativos.where((a) => a.negociavel)) {
      final s = sinais[ind.id];
      if (s == null) continue;
      // o edge e o freio de robustez vêm da estratégia compatível com o
      // horizonte (reversão p/ curto, momentum p/ médio, tendência p/ longo)
      out.add(_avaliarAtivo(ind, s, backtests[ind.id]?.porHorizonte(horizon),
          macro, horizon, cenarios?[ind.id], sazonalidades?[ind.id],
          forcaRelativa, carries?[ind.id]));
    }
    out.sort((a, b) => b.score.compareTo(a.score));
    return out;
  }

  Oportunidade _avaliarAtivo(
    Indicator ind,
    AssetSignals s,
    BacktestResult? bt,
    MacroRegime? macro,
    Horizon horizon,
    ScenarioReport? cen,
    SazonalidadeMes? saz,
    CrossSectionalReport? fr,
    CarryPar? carry,
  ) {
    final ev = <Evidencia>[];
    void add(String texto, double c) => ev.add(Evidencia(texto, c));

    var raw = 0.0;
    switch (horizon) {
      case Horizon.curto:
        if (s.zScore60d != null) {
          final c = -_tanh(s.zScore60d! / 2) * 0.45;
          add(
              'Preço a ${s.zScore60d!.toStringAsFixed(1)}σ da média de 60 '
              'pregões (${s.zScore60d! > 0 ? "esticado" : "comprimido"})',
              c);
          raw += c;
        }
        if (s.ret1m != null) {
          final c = _tanh(s.ret1m! / 0.05) * 0.25;
          add('Retorno de 1 mês: ${_pct(s.ret1m!)}', c);
          raw += c;
        }
        if (s.distSma200 != null) {
          final c = _tanh(s.distSma200! / 0.10) * 0.20;
          add(
              'Preço ${_pct(s.distSma200!.abs())} '
              '${s.distSma200! >= 0 ? "acima" : "abaixo"} da SMA-200', c);
          raw += c;
        }
        // Sazonalidade de calendário (ciclos físicos: estoque, safra,
        // fluxo de fim de ano) — só entra quando passou no t-teste E se
        // confirmou fora da amostra (ver seasonality.dart).
        if (saz != null && saz.relevante) {
          final c = _tanh(saz.media / 0.03) * 0.30;
          add(
              'Sazonalidade: ${saz.nomeMes} rendeu em média '
              '${_pct(saz.media)} em ${saz.n} anos '
              '(p=${saz.pValor.toStringAsFixed(3)}, confirmada fora da '
              'amostra)',
              c);
          raw += c;
        }

      case Horizon.medio:
        if (s.momentum12x1 != null) {
          final c = _tanh(s.momentum12x1! / 0.20) * 0.45;
          add('Momentum 12-1: ${_pct(s.momentum12x1!)}', c);
          raw += c;
        }
        if (s.distSma200 != null) {
          final c = _tanh(s.distSma200! / 0.10) * 0.30;
          add(
              'Tendência: preço ${_pct(s.distSma200!.abs())} '
              '${s.distSma200! >= 0 ? "acima" : "abaixo"} da SMA-200', c);
          raw += c;
        }
        if (s.zScore60d != null) {
          final c = -_tanh(s.zScore60d! / 2) * 0.10;
          raw += c;
        }
        // Força relativa (momentum cross-sectional): só entra quando o
        // fator foi re-validado no NOSSO universo (spread significativo
        // dentro E fora da amostra) e o ativo está num extremo do ranking.
        if (fr != null && fr.validado) {
          final f = fr.porAtivo[ind.id];
          if (f != null && (f.percentil >= 0.8 || f.percentil <= 0.2)) {
            final c = (f.percentil - 0.5) * 2 * 0.30;
            final forte = f.percentil >= 0.8;
            final pos = forte
                ? fr.nAtivosHoje - (f.percentil * (fr.nAtivosHoje - 1)).round()
                : (f.percentil * (fr.nAtivosHoje - 1)).round() + 1;
            add(
                'Força relativa: ${pos}º mais ${forte ? "forte" : "fraco"} '
                'de ${fr.nAtivosHoje} ativos (momentum 12-1 ajustado por '
                'vol) — fator validado no universo: spread '
                '${_pct(fr.spreadMedioMensal)}/mês em ${fr.nMeses} meses '
                '(p=${fr.pValor.toStringAsFixed(3)})',
                c);
            raw += c;
          }
        }
        final m = _macroAjuste(ind.id, macro);
        if (m != null) {
          add(m.texto, m.contribuicao);
          raw += m.contribuicao;
        }
        final cc = _carryEvidencia(carry);
        if (cc != null) {
          add(cc.texto, cc.contribuicao);
          raw += cc.contribuicao;
        }

      case Horizon.longo:
        if (s.cagr3y != null) {
          final c = _tanh(s.cagr3y! / 0.10) * 0.45;
          add('Tendência secular (CAGR 3 anos): ${_pct(s.cagr3y!)}', c);
          raw += c;
        }
        if (s.ddDoTopo != null && s.cagr3y != null && s.cagr3y! > 0) {
          // Ativo com tendência secular positiva negociando longe do topo:
          // historicamente, ponto de entrada — não de fuga.
          final c = _tanh(-s.ddDoTopo! / 0.35) * 0.30;
          add('Distância do topo histórico: ${_pct(s.ddDoTopo!)}', c);
          raw += c;
        }
        if (s.distSma200 != null) {
          final c = _tanh(s.distSma200! / 0.15) * 0.15;
          raw += c;
        }
        final m = _macroAjuste(ind.id, macro);
        if (m != null) {
          add(m.texto, m.contribuicao * 0.7);
          raw += m.contribuicao * 0.7;
        }
        final cc = _carryEvidencia(carry);
        if (cc != null) {
          add(cc.texto, cc.contribuicao);
          raw += cc.contribuicao;
        }
    }

    // O que a história condicional diz: cenários análogos ao estado atual
    // entram no score (mediana e % de altas do período à frente).
    final st = horizon == Horizon.curto
        ? cen?.fwd3m
        : (cen?.fwd12m ?? cen?.fwd3m);
    if (st != null && !st.mediana.isNaN && !st.pctPositivo.isNaN) {
      final escala = horizon == Horizon.curto ? 0.05 : 0.15;
      final c = _tanh(st.mediana / escala) * 0.15 +
          (st.pctPositivo - 0.5) * 2 * 0.10;
      add(
          'Cenários análogos (n=${st.n}): mediana '
          '${horizon == Horizon.curto ? "3m" : "12m"} de '
          '${_pct(st.mediana)}, ${_pct(st.pctPositivo)} subiram',
          c);
      raw += c;
    }

    // Confluência: sinais independentes concordando valem mais do que um
    // sinal isolado gritando. Discordância derruba a convicção.
    if (raw != 0) {
      var aFavor = 0, contra = 0;
      for (final e in ev) {
        if (e.contribuicao.abs() < 0.02) continue;
        if (e.contribuicao.sign == raw.sign) {
          aFavor++;
        } else {
          contra++;
        }
      }
      if (aFavor + contra >= 2) {
        final conf = aFavor / (aFavor + contra);
        raw *= 0.7 + 0.3 * conf;
        add('Confluência: $aFavor de ${aFavor + contra} sinais apontam na '
            'mesma direção', 0);
      }
    }

    // Freio de robustez: se a estratégia compatível com o horizonte não
    // sobreviveu fora da amostra neste ativo, a convicção cai 30%.
    if (bt != null && !bt.sobreviveuForaDaAmostra) {
      add('${bt.kind.label} NÃO sobreviveu fora da amostra neste ativo '
          '(Sharpe OOS ${bt.estrategiaOos.sharpe.toStringAsFixed(2)})', 0);
      raw *= 0.7;
    }
    // Vol extrema no curto prazo derruba convicção (ruído >> sinal).
    if (horizon == Horizon.curto &&
        s.vol30dAnn != null &&
        s.vol30dAnn! > 0.60) {
      raw *= 0.7;
      add('Volatilidade 30d anualizada de ${_pct(s.vol30dAnn!)} — '
          'sinal de curto prazo pouco confiável', 0);
    }

    final direcao = raw.abs() < 0.15
        ? DirecaoOportunidade.neutro
        : (raw > 0 ? DirecaoOportunidade.compra : DirecaoOportunidade.venda);
    final score = (raw.abs().clamp(0.0, 1.0) * 100).roundToDouble();

    LeverageAdvice? lev;
    if (direcao != DirecaoOportunidade.neutro &&
        bt != null &&
        s.vol1yAnn != null) {
      // μ estimado da estratégia compatível com o horizonte (não do
      // buy & hold): é o edge mensurável que temos, com validação OOS.
      lev = leverageAdvice(
        retornoExcedenteAnual: bt.estrategia.cagr.isNaN ? 0 : bt.estrategia.cagr,
        volAnual: s.vol1yAnn!,
      );
    }

    return Oportunidade(
      indicator: ind,
      horizon: horizon,
      direcao: direcao,
      score: score,
      evidencias: ev,
      sinais: s,
      alavancagem: lev,
      backtest: bt,
    );
  }

  /// Carry cambial como evidência — só quando o fator foi re-validado no
  /// próprio par (backtest mensal 70/30 + t-teste) e o diferencial atual é
  /// relevante. A direção é a do juro maior.
  Evidencia? _carryEvidencia(CarryPar? c) {
    if (c == null || !c.validado) return null;
    final contrib = _tanh(c.difJurosAa / 0.05) * 0.20;
    return Evidencia(
        'Carry validado: diferencial de juros de ${_pct(c.difJurosAa)} a.a. '
        'a favor de ${c.compra ? "comprar" : "vender"} o par; seguir o lado '
        'do carry rendeu ${_pct(c.retornoMedioMensal)}/mês em ${c.nMeses} '
        'meses (p=${c.pValor.toStringAsFixed(3)})',
        contrib);
  }

  /// Ajuste macro por classe de ativo: relações econômicas clássicas e
  /// mensuráveis (juro real, direção da Selic, dólar global, Treasury).
  Evidencia? _macroAjuste(String id, MacroRegime? m) {
    if (m == null) return null;
    switch (id) {
      case 'ibovespa':
        if (m.selicDirecao == Direcao.caindo) {
          return const Evidencia(
              'Selic em ciclo de queda — historicamente favorável a ações '
              'brasileiras com defasagem', 0.15);
        }
        if (m.selicDirecao == Direcao.subindo) {
          return const Evidencia(
              'Selic em ciclo de alta — concorrência da renda fixa pesa '
              'sobre ações brasileiras', -0.15);
        }
        if (!m.juroRealAa.isNaN && m.juroRealAa > 0.07) {
          return Evidencia(
              'Juro real de ${_pct(m.juroRealAa)} a.a. — renda fixa muito '
              'competitiva contra bolsa', -0.10);
        }
      case 'dolar_ptax':
        if (!m.juroRealAa.isNaN && m.juroRealAa > 0.06) {
          return Evidencia(
              'Juro real de ${_pct(m.juroRealAa)} a.a. atrai carry trade — '
              'pressão vendedora estrutural no dólar/real', -0.15);
        }
      case 'ouro':
      case 'prata':
        if (m.us10yDirecao == Direcao.caindo) {
          return const Evidencia(
              'Treasury 10a em queda reduz o custo de oportunidade de '
              'metais sem yield', 0.15);
        }
        if (m.dxyAcimaSma200 == false) {
          return const Evidencia(
              'Dólar global (DXY) abaixo da SMA-200 — vento a favor de '
              'metais preciosos', 0.10);
        }
      case 'sp500':
      case 'nasdaq':
        if (m.us10yDirecao == Direcao.caindo) {
          return const Evidencia(
              'Treasury 10a em queda — suporte a múltiplos de ações '
              'americanas', 0.10);
        }
        if (m.us10yDirecao == Direcao.subindo) {
          return const Evidencia(
              'Treasury 10a em alta — pressão sobre múltiplos de ações '
              'americanas', -0.10);
        }
      case 'bitcoin':
        if (m.dxyAcimaSma200 == false) {
          return const Evidencia(
              'Dólar global fraco (DXY < SMA-200) — historicamente '
              'correlacionado a apetite por risco/cripto', 0.10);
        }
      case 'petroleo_wti':
      case 'gas_natural':
      case 'milho':
      case 'soja':
        if (m.dxyAcimaSma200 == true) {
          return const Evidencia(
              'Dólar global forte (DXY > SMA-200) — vento contra '
              'commodities precificadas em US\$', -0.10);
        }
        if (m.dxyAcimaSma200 == false) {
          return const Evidencia(
              'Dólar global fraco (DXY < SMA-200) — vento a favor de '
              'commodities precificadas em US\$', 0.10);
        }
    }
    return null;
  }

  static double _tanh(double x) {
    final e2 = math.exp(2 * x.clamp(-20.0, 20.0));
    return (e2 - 1) / (e2 + 1);
  }

  static String _pct(double v) =>
      '${(v * 100).toStringAsFixed(1).replaceAll('.', ',')}%';
}
