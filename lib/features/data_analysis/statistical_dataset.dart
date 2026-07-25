class StatisticalDataset {
  final String fileName;
  final List<String> headers;
  final List<List<String>> rows;

  const StatisticalDataset({
    required this.fileName,
    required this.headers,
    required this.rows,
  });

  int get rowCount => rows.length;

  List<String> get numericColumnNames {
    return headers.where((h) => numericValues(h).length >= 3).toList();
  }

  List<String> get categoricalColumnNames {
    return headers
        .where((h) => !numericColumnNames.contains(h) && values(h).isNotEmpty)
        .toList();
  }

  List<String> values(String column) {
    final idx = headers.indexOf(column);
    if (idx < 0) return const [];
    return rows
        .map((row) => idx < row.length ? row[idx].trim() : '')
        .where((v) => v.isNotEmpty)
        .toList();
  }

  List<double> numericValues(String column) {
    return values(column)
        .map(_parseNum)
        .whereType<double>()
        .toList();
  }

  static double? _parseNum(String raw) {
    var t = raw.trim();
    if (t.isEmpty) return null;
    t = t.replaceAll(',', '.');
    return double.tryParse(t);
  }
}

class ColumnMapping {
  final String? dependentColumn;
  final String? groupColumn;
  final String? secondNumericColumn;

  const ColumnMapping({
    this.dependentColumn,
    this.groupColumn,
    this.secondNumericColumn,
  });
}
