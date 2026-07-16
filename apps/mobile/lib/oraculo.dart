import 'dart:convert';

import 'package:http/http.dart' as http;

import 'data.dart';

/// Oráculo nativo — plano de execução via Gemini (REST), com os MESMOS
/// dados do painel. A chave abaixo deve ser uma chave NOVA restrita ao
/// Android (pacote com.quantlab.quantlab_app + SHA-1) e à API
/// generativelanguage — a chave do site é restrita por referrer e NÃO
/// funciona no app. Vazia = botão do Oráculo fica oculto.
const geminiAndroidKey = '';

bool get oraculoDisponivel => geminiAndroidKey.isNotEmpty;

const _sys =
    'Você é o ORÁCULO do QuantLab dando instruções de execução no eToro. '
    'Responda em português do Brasil, texto corrido enxuto (sem markdown '
    'pesado), imperativo: para cada ordem fornecida, um passo numerado '
    '"Busque {ticker} → COMPRAR/VENDER → valor R\$ → alavancagem → SL → '
    'TP". Use SOMENTE os números fornecidos; nunca invente preços ou '
    'notícias. Os sinais são de fechamento diário — sem promessas '
    'intradiárias. Cite o placar real quando relevante e nunca prometa '
    'acima dele. Termine com 1 linha de aviso de risco. ~250 palavras.';

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
  final prompt = 'HORIZONTE: ${d.horizonteLabel(horizonte)} · PERFIL: '
      '${perfil.nome}.\nCAIXA SUGERIDO: ${(r.caixaPct * 100).round()}%.\n'
      'MACRO: ${json.encode(d.macro)}\n'
      'ORDENS APROVADAS: ${json.encode(ordens)}\n'
      'PLACAR REAL: ${json.encode(d.placar)}\n'
      'Monte o plano de execução agora.';

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
  if (texto.isEmpty) throw Exception('resposta vazia do modelo');
  return texto;
}
