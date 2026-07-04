/// Uma observação pontual de uma série histórica.
class Observation {
  const Observation(this.date, this.value);

  final DateTime date;
  final double value;

  Map<String, Object?> toJson() => {
        'd': '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}',
        'v': value,
      };

  factory Observation.fromJson(Map<String, Object?> json) =>
      Observation(DateTime.parse(json['d']! as String), (json['v']! as num).toDouble());
}

/// Par de séries alinhadas pela mesma data — insumo de correlações e
/// regressões. `a[i]` e `b[i]` referem-se sempre a `dates[i]`.
class AlignedSeries {
  const AlignedSeries(this.dates, this.a, this.b);
  final List<DateTime> dates;
  final List<double> a;
  final List<double> b;
  int get length => dates.length;
}

/// Série histórica imutável, ordenada por data crescente e sem datas
/// duplicadas (a última observação de uma data vence).
class TimeSeries {
  TimeSeries(this.id, Iterable<Observation> observations)
      : observations = _normalize(observations);

  final String id;
  final List<Observation> observations;

  static List<Observation> _normalize(Iterable<Observation> raw) {
    final byDate = <int, Observation>{};
    for (final o in raw) {
      if (o.value.isFinite) {
        byDate[DateTime(o.date.year, o.date.month, o.date.day)
            .millisecondsSinceEpoch] = o;
      }
    }
    final sorted = byDate.entries.toList()
      ..sort((x, y) => x.key.compareTo(y.key));
    return List.unmodifiable(sorted.map((e) => e.value));
  }

  int get length => observations.length;
  bool get isEmpty => observations.isEmpty;
  Observation get first => observations.first;
  Observation get last => observations.last;
  List<double> get values =>
      List.unmodifiable(observations.map((o) => o.value));
  List<DateTime> get dates =>
      List.unmodifiable(observations.map((o) => o.date));

  /// Recorte da série entre [from] e [to] (inclusivos; nulos = sem limite).
  TimeSeries window({DateTime? from, DateTime? to}) => TimeSeries(
        id,
        observations.where((o) =>
            (from == null || !o.date.isBefore(from)) &&
            (to == null || !o.date.isAfter(to))),
      );

  /// Últimas [n] observações.
  TimeSeries tail(int n) => TimeSeries(
      id, observations.sublist(length <= n ? 0 : length - n));

  /// Reamostra para mensal usando a última observação de cada mês,
  /// normalizando a data para o dia 1 (permite alinhar séries de
  /// frequências diferentes).
  TimeSeries resampleMonthly() {
    final byMonth = <int, Observation>{};
    for (final o in observations) {
      byMonth[o.date.year * 12 + o.date.month] =
          Observation(DateTime(o.date.year, o.date.month), o.value);
    }
    return TimeSeries(id, byMonth.values);
  }

  /// Alinha duas séries pelas datas em comum (interseção exata).
  AlignedSeries alignWith(TimeSeries other) {
    final otherByDate = {
      for (final o in other.observations) o.date.millisecondsSinceEpoch: o.value,
    };
    final dates = <DateTime>[];
    final a = <double>[];
    final b = <double>[];
    for (final o in observations) {
      final v = otherByDate[o.date.millisecondsSinceEpoch];
      if (v != null) {
        dates.add(o.date);
        a.add(o.value);
        b.add(v);
      }
    }
    return AlignedSeries(dates, a, b);
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'observations': observations.map((o) => o.toJson()).toList(),
      };

  factory TimeSeries.fromJson(Map<String, Object?> json) => TimeSeries(
        json['id']! as String,
        (json['observations']! as List)
            .map((o) => Observation.fromJson((o as Map).cast())),
      );
}
