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
  int get columnCount => headers.length;

  /// Rename blank / duplicate headers so wide tables stay usable.
  factory StatisticalDataset.sanitized({
    required String fileName,
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    final cleanedHeaders = <String>[];
    final seen = <String, int>{};
    for (var i = 0; i < headers.length; i++) {
      var h = headers[i].trim();
      if (h.isEmpty) h = 'Col${i + 1}';
      final base = h;
      final count = seen[base] ?? 0;
      seen[base] = count + 1;
      if (count > 0) h = '$base (${count + 1})';
      cleanedHeaders.add(h);
    }

    final width = cleanedHeaders.length;
    final cleanedRows = <List<String>>[];
    for (final row in rows) {
      final cells = List<String>.generate(
        width,
        (j) => j < row.length ? row[j].trim() : '',
      );
      if (cells.every((c) => c.isEmpty)) continue;
      cleanedRows.add(cells);
    }

    return StatisticalDataset(
      fileName: fileName,
      headers: cleanedHeaders,
      rows: cleanedRows,
    );
  }

  List<String> get numericColumnNames =>
      headers.where((h) => isMostlyNumeric(h)).toList();

  List<String> get categoricalColumnNames =>
      headers.where((h) => !isMostlyNumeric(h) && values(h).isNotEmpty).toList();

  /// Any non-empty column can be mapped (researchers choose).
  List<String> get mappableColumnNames =>
      headers.where((h) => values(h).isNotEmpty).toList();

  bool isMostlyNumeric(String column) {
    final vals = values(column);
    if (vals.isEmpty) return false;
    var ok = 0;
    for (final v in vals) {
      if (_parseNum(v) != null) ok++;
    }
    // ≥40% parseable OR at least 3 numeric values → treat as numeric candidate.
    return ok >= 3 && ok / vals.length >= 0.4;
  }

  int missingCount(String column) {
    final idx = headers.indexOf(column);
    if (idx < 0) return 0;
    var missing = 0;
    for (final row in rows) {
      if (idx >= row.length || row[idx].trim().isEmpty) missing++;
    }
    return missing;
  }

  int get totalMissingCells {
    var n = 0;
    for (final h in headers) {
      n += missingCount(h);
    }
    return n;
  }

  double get missingRate {
    final total = rows.length * headers.length;
    if (total == 0) return 0;
    return totalMissingCells / total;
  }

  int uniqueCount(String column) {
    return values(column).toSet().length;
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
    return values(column).map(_parseNum).whereType<double>().toList();
  }

  String columnTypeLabel(String column, {required bool isEnglish}) {
    if (isMostlyNumeric(column)) {
      return isEnglish ? 'numeric' : 'رقمي';
    }
    final u = uniqueCount(column);
    if (u <= 12) {
      return isEnglish ? 'categorical ($u levels)' : 'فئوي ($u مستويات)';
    }
    return isEnglish ? 'text / id' : 'نصي / معرف';
  }

  /// Suggest the most suitable test from the loaded table structure.
  SuggestedAnalysis? suggestAnalysis() {
    final numeric = numericColumnNames;
    final cats = categoricalColumnNames
        .where((c) => uniqueCount(c) >= 2 && uniqueCount(c) <= 20)
        .toList();

    if (numeric.isEmpty && cats.length >= 2) {
      return SuggestedAnalysis(
        testTypeName: 'chiSquare',
        dependent: cats.first,
        group: cats[1],
        reasonAr: 'عمودان فئويان — مناسب لمربع كاي',
        reasonEn: 'Two categorical columns — chi-square fits',
      );
    }

    if (numeric.length >= 2 && cats.isEmpty) {
      return SuggestedAnalysis(
        testTypeName: 'pearsonCorrelation',
        dependent: numeric[0],
        secondNumeric: numeric[1],
        reasonAr: 'عمودان رقميان — ارتباط / انحدار',
        reasonEn: 'Two numeric columns — correlation / regression',
      );
    }

    if (numeric.isNotEmpty && cats.isNotEmpty) {
      final g = cats.first;
      final levels = uniqueCount(g);
      if (levels == 2) {
        return SuggestedAnalysis(
          testTypeName: 'independentTTest',
          dependent: numeric.first,
          group: g,
          reasonAr: 'رقمي + مجموعتان — اختبار t',
          reasonEn: 'Numeric + 2 groups — t-test',
        );
      }
      return SuggestedAnalysis(
        testTypeName: 'oneWayAnova',
        dependent: numeric.first,
        group: g,
        reasonAr: 'رقمي + $levels مجموعات — ANOVA',
        reasonEn: 'Numeric + $levels groups — ANOVA',
      );
    }

    if (numeric.length >= 2) {
      return SuggestedAnalysis(
        testTypeName: 'pearsonCorrelation',
        dependent: numeric[0],
        secondNumeric: numeric[1],
        reasonAr: 'عدة أعمدة رقمية — ابدأ بالارتباط',
        reasonEn: 'Several numeric columns — start with correlation',
      );
    }

    return null;
  }

  static double? parseNumber(String raw) => _parseNum(raw);

  static double? _parseNum(String raw) {
    var t = raw.trim();
    if (t.isEmpty) return null;
    // Arabic-Indic digits → Western
    const eastern = '٠١٢٣٤٥٦٧٨٩';
    const western = '0123456789';
    for (var i = 0; i < eastern.length; i++) {
      t = t.replaceAll(eastern[i], western[i]);
    }
    t = t
        .replaceAll('%', '')
        .replaceAll('٫', '.')
        .replaceAll('٬', '')
        .replaceAll(',', '.')
        .replaceAll(RegExp(r'\s+'), '');
    return double.tryParse(t);
  }
}

class SuggestedAnalysis {
  final String testTypeName;
  final String? dependent;
  final String? group;
  final String? secondNumeric;
  final String reasonAr;
  final String reasonEn;

  const SuggestedAnalysis({
    required this.testTypeName,
    required this.reasonAr,
    required this.reasonEn,
    this.dependent,
    this.group,
    this.secondNumeric,
  });
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
