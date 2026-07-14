import 'dart:io';

import 'package:quant_engine/quant_engine.dart';

import 'firestore_rest.dart';

/// Camada de aplicação do Motor de Track Record: liga o domínio
/// ([TrackRecordScorer]) à persistência (Firestore). Grava o snapshot do dia
/// (idempotente por data — o CI roda de 2 em 2h, então a última execução do
/// dia vence) e devolve o LOG completo para o domínio consolidar.
///
/// Degrada em SILÊNCIO se não houver cofre da service account (ex.: rodando
/// local sem GOOGLE_APPLICATION_CREDENTIALS): devolve só os sinais de hoje,
/// para o placar ao menos mostrar as posições em aberto.
class TrackRecordStore {
  const TrackRecordStore();

  static const _colecao = 'track_record';

  Future<List<SinalRegistrado>> registrarEObterLog(
    Map<String, Object?> dashboard, {
    DateTime? hoje,
  }) async {
    final data = _soData(hoje ?? DateTime.now());
    final doHoje = extrairSinaisDoDia(dashboard, data);

    final fs = await FirestoreRest.abrir();
    if (fs == null) {
      stdout.writeln('Track record: Firestore indisponível (sem cofre) — '
          'placar só com os sinais de hoje (${doHoje.length}).');
      return doHoje;
    }
    try {
      final docId = SinalRegistrado(
              data: data,
              horizonte: 'curto',
              ativoId: '',
              direcao: 'compra',
              precoEntrada: 0,
              assertividadePrevista: 0,
              alavancagem: 1,
              janelaMeses: 3)
          .toJson()['data'] as String; // yyyy-MM-dd
      final status = await fs.patch('$_colecao/$docId', {
        'geradoEm': DateTime.now().toUtc().toIso8601String(),
        'sinais': [for (final s in doHoje) s.toJson()],
      });
      if (status >= 300) {
        stdout.writeln('Track record: gravação HTTP $status — '
            'placar só com hoje.');
        return doHoje;
      }
      final docs = await fs.listar(_colecao);
      final log = <SinalRegistrado>[];
      for (final (_, campos) in docs) {
        final sinais = (campos['sinais'] as List?) ?? const [];
        for (final s in sinais) {
          if (s is Map) {
            log.add(SinalRegistrado.fromJson(s.cast<String, Object?>()));
          }
        }
      }
      stdout.writeln('Track record: snapshot de $docId gravado; log com '
          '${log.length} sinais em ${docs.length} dias.');
      return log;
    } catch (e) {
      stdout.writeln('Track record: falha (${e.runtimeType}) — placar só '
          'com hoje.');
      return doHoje;
    } finally {
      fs.close();
    }
  }

  /// Extrai do dashboard os sinais EMITIDOS (ação comprar/vender) de cada
  /// horizonte, com o preço e a assertividade registrados AO VIVO hoje.
  List<SinalRegistrado> extrairSinaisDoDia(
      Map<String, Object?> dashboard, DateTime data) {
    final out = <SinalRegistrado>[];
    final horizontes = (dashboard['horizontes'] as Map?) ?? const {};
    for (final h in const ['curto', 'medio', 'longo']) {
      final bloco = horizontes[h] as Map?;
      final ops = (bloco?['oportunidades'] as List?) ?? const [];
      for (final o in ops) {
        if (o is! Map) continue;
        final rec = (o['recomendacao'] as Map?)?.cast<String, Object?>();
        final acao = rec?['acao'];
        if (acao != 'comprar' && acao != 'vender') continue;
        final preco = (o['preco'] as num?)?.toDouble();
        final ass = (rec?['assertividade'] as num?)?.toDouble();
        final id = o['id'] as String?;
        if (preco == null || preco <= 0 || ass == null || id == null) {
          continue;
        }
        out.add(SinalRegistrado(
          data: data,
          horizonte: h,
          ativoId: id,
          direcao: acao == 'comprar' ? 'compra' : 'venda',
          precoEntrada: preco,
          assertividadePrevista: ass,
          alavancagem: (rec?['alavancagemRecomendada'] as num?)?.toInt() ?? 1,
          // ordens do radar têm janela própria (~21 pregões → 1 mês)
          janelaMeses:
              rec?['janelaRetorno'] == '1m' ? 1 : janelaMesesDe(h),
        ));
      }
    }
    return out;
  }

  static DateTime _soData(DateTime d) => DateTime(d.year, d.month, d.day);
}
