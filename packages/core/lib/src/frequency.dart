/// Frequência de uma série histórica.
///
/// [periodsPerYear] é a convenção usada para anualizar retornos e
/// volatilidade (252 pregões/ano para séries diárias de mercado).
enum Frequency {
  daily(252),
  weekly(52),
  monthly(12),
  quarterly(4),
  yearly(1);

  const Frequency(this.periodsPerYear);
  final int periodsPerYear;
}
