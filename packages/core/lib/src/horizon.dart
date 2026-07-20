/// Horizontes de análise das oportunidades.
enum Horizon {
  curto('Short term', 'up to ~3 months'),
  medio('Medium term', '3 to 18 months'),
  longo('Long term', 'over 18 months');

  const Horizon(this.label, this.janela);
  final String label;
  final String janela;
}
