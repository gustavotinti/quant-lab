/// Horizontes de análise das oportunidades.
enum Horizon {
  curto('Curto prazo', 'até ~3 meses'),
  medio('Médio prazo', '3 a 18 meses'),
  longo('Longo prazo', 'acima de 18 meses');

  const Horizon(this.label, this.janela);
  final String label;
  final String janela;
}
