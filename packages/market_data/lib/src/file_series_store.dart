import 'dart:convert';
import 'dart:io';

import 'package:quant_core/quant_core.dart';

/// Persistência local de séries em JSON (`data/series/{id}.json`).
/// Implementa a porta [SeriesRepository]; a versão Firestore virá na fase
/// Firebase sem tocar no domínio.
class FileSeriesStore implements SeriesRepository {
  FileSeriesStore(this.rootDir);

  final Directory rootDir;

  File _fileFor(String id) =>
      File('${rootDir.path}${Platform.pathSeparator}$id.json');

  @override
  Future<Result<TimeSeries>> load(String id) async {
    final f = _fileFor(id);
    if (!await f.exists()) {
      return Err(Failure('Série "$id" não encontrada — rode `lab update`'));
    }
    try {
      final map =
          json.decode(await f.readAsString()) as Map<String, Object?>;
      return Ok(TimeSeries.fromJson(map));
    } catch (e) {
      return Err(Failure('Arquivo corrompido para "$id"', cause: e));
    }
  }

  @override
  Future<Result<void>> save(TimeSeries series,
      {Map<String, Object?>? meta}) async {
    try {
      await rootDir.create(recursive: true);
      final payload = series.toJson()
        ..['updatedAt'] = DateTime.now().toIso8601String()
        ..['meta'] = meta;
      await _fileFor(series.id)
          .writeAsString(const JsonEncoder.withIndent(' ').convert(payload));
      return const Ok(null);
    } catch (e) {
      return Err(Failure('Falha ao salvar "${series.id}"', cause: e));
    }
  }

  @override
  Future<List<String>> listIds() async {
    if (!await rootDir.exists()) return const [];
    return [
      await for (final e in rootDir.list())
        if (e is File && e.path.endsWith('.json'))
          e.uri.pathSegments.last.replaceAll('.json', ''),
    ]..sort();
  }
}
