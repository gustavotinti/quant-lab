import 'package:quant_engine/quant_engine.dart';

/// Formatação pt-BR para números, percentuais e tabelas de console.

String pct(double? v, {int dec = 1, bool comSinal = true}) {
  if (v == null || v.isNaN) return '—';
  final s = (v * 100).toStringAsFixed(dec).replaceAll('.', ',');
  return '${comSinal && v > 0 ? '+' : ''}$s%';
}

String numBr(double? v, {int dec = 2}) {
  if (v == null || v.isNaN) return '—';
  return v.toStringAsFixed(dec).replaceAll('.', ',');
}

String dataBr(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String tabela(List<String> header, List<List<String>> rows) {
  final all = [header, ...rows];
  final widths = List<int>.filled(header.length, 0);
  for (final row in all) {
    for (var c = 0; c < row.length; c++) {
      if (row[c].length > widths[c]) widths[c] = row[c].length;
    }
  }
  String line(List<String> row) => [
        for (var c = 0; c < row.length; c++) row[c].padRight(widths[c]),
      ].join('  ');
  final sep = widths.map((w) => '-' * w).join('  ');
  return [line(header), sep, ...rows.map(line)].join('\n');
}

String direcaoLabel(DirecaoOportunidade d) => switch (d) {
      DirecaoOportunidade.compra => 'COMPRA',
      DirecaoOportunidade.venda => 'VENDA',
      DirecaoOportunidade.neutro => 'NEUTRO',
    };

String direcaoMacro(Direcao d) => switch (d) {
      Direcao.subindo => 'subindo',
      Direcao.caindo => 'caindo',
      Direcao.estavel => 'estável',
    };

const disclaimer = '''
─────────────────────────────────────────────────────────────────────────
AVISO: saída gerada automaticamente a partir de dados públicos e métodos
estatísticos descritos em docs/METODOLOGIA.md. NÃO é recomendação de
investimento. Rentabilidade passada não garante resultado futuro.
Alavancagem pode gerar perdas superiores ao capital investido.
─────────────────────────────────────────────────────────────────────────''';
