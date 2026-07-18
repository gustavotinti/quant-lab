import 'dart:convert';

import 'package:http/http.dart' as http;

import 'data.dart';

/// Oráculo nativo — plano de execução via Gemini (REST), com os MESMOS
/// dados do painel. A chave abaixo deve ser uma chave NOVA restrita ao
/// Android (pacote com.quantlab.quantlab_app + SHA-1) e à API
/// generativelanguage — a chave do site é restrita por referrer e NÃO
/// funciona no app. Vazia = botão do Oráculo fica oculto.
const geminiAndroidKey = 'AIzaSyByQsEliRIyecrB0yKkaiTVTQP86Ng8CQw';

bool get oraculoDisponivel => geminiAndroidKey.isNotEmpty;

const _sys =
    'You are the QuantLab ORACLE giving execution instructions for '
    'eToro. Answer in English, lean plain text (no heavy markdown), '
    'imperative: for each order provided, one numbered step '
    '"Search {ticker} -> BUY/SELL -> amount -> leverage -> SL -> TP". '
    'Use ONLY the numbers provided; never invent prices or news. '
    'Signals are from daily closes - no intraday promises. Cite the '
    'real scoreboard when relevant and never promise above it. End '
    'with 1 risk-warning line. ~250 words.';

Future<String> gerarPlano(
    Dashboard d, String horizonte, Perfil perfil) async {
  final r = ranking(d, horizonte, perfil);
  final ordens = [
    for (final o in r.ordens.take(6))
      {
        'ativo': o.nome,
        'ticker': o.ticker,
        'acao': o.compra ? 'comprar' : 'vender',
        'assertividadePct': (o.assertividade * 100).round(),
        'pesoPct': (o.peso * 100).toStringAsFixed(1),
        'alavancagem': 'X${o.lev}',
        'retornoEsperadoPct':
            ((o.retornoEsperado ?? 0) * 100).toStringAsFixed(1),
        'janela': o.janela,
        'gatilhoSaida': o.gatilho,
      },
  ];
  final prompt = 'HORIZON: ${d.horizonteLabel(horizonte)} · PROFILE: '
      '${perfil.nome}.\nSUGGESTED CASH: ${(r.caixaPct * 100).round()}%.\n'
      'MACRO: ${json.encode(d.macro)}\n'
      'APPROVED ORDERS: ${json.encode(ordens)}\n'
      'REAL SCOREBOARD: ${json.encode(d.placar)}\n'
      'Build the execution plan now.';

  final res = await http
      .post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/'
            'gemini-2.5-flash:generateContent?key=$geminiAndroidKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'system_instruction': {
            'parts': [{'text': _sys}]
          },
          'contents': [
            {
              'role': 'user',
              'parts': [{'text': prompt}]
            }
          ],
          'generationConfig': {
            'temperature': 0.3,
            'maxOutputTokens': 1600,
            'thinkingConfig': {'thinkingBudget': 0},
          },
        }),
      )
      .timeout(const Duration(seconds: 45));
  final j = json.decode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    throw Exception(
        (j['error'] as Map?)?['message'] ?? 'HTTP ${res.statusCode}');
  }
  final parts =
      (((j['candidates'] as List?)?.first as Map?)?['content']
              as Map?)?['parts'] as List? ??
          const [];
  final texto =
      parts.map((p) => (p as Map)['text'] ?? '').join().trim();
  if (texto.isEmpty) throw Exception('empty model response');
  return texto;
}
