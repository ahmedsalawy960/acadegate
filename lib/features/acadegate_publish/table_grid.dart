/// Rectangular table grid that preserves Word/HTML merges.
///
/// [colSpans] 0 = covered by a cell to the left (do not emit a Word `tc`).
/// [rowSpans] 0 = vertical merge continuation (emit `w:vMerge` without restart).
class TableGridData {
  final List<List<String>> rows;
  final List<List<String>> rowCellImages;
  final List<List<int>> colSpans;
  final List<List<int>> rowSpans;
  /// Column widths in fiftieths of a percent (sum ≈ 5000). Empty = unknown.
  final List<int> columnWidthsPct;

  const TableGridData({
    required this.rows,
    required this.rowCellImages,
    required this.colSpans,
    required this.rowSpans,
    this.columnWidthsPct = const [],
  });

  bool get isEmpty => rows.isEmpty;
}

class WordTableCell {
  final String text;
  final String imageUrl;
  final int colSpan;
  final bool vMergeContinue;
  final int gridBefore;
  final int gridAfter;

  const WordTableCell({
    required this.text,
    this.imageUrl = '',
    this.colSpan = 1,
    this.vMergeContinue = false,
    this.gridBefore = 0,
    this.gridAfter = 0,
  });
}

class HtmlTableCell {
  final String text;
  final String imageUrl;
  final int colSpan;
  final int rowSpan;

  const HtmlTableCell({
    required this.text,
    this.imageUrl = '',
    this.colSpan = 1,
    this.rowSpan = 1,
  });
}

class TableGrid {
  TableGrid._();

  static List<int> widthsToPct(List<int> twips) {
    final positive = twips.map((w) => w <= 0 ? 1 : w).toList();
    if (positive.isEmpty) return const [];
    final total = positive.fold<int>(0, (a, b) => a + b);
    if (total <= 0) return const [];
    final pct = positive.map((w) => (w * 5000 / total).round()).toList();
    final sum = pct.fold<int>(0, (a, b) => a + b);
    if (sum != 5000 && pct.isNotEmpty) {
      pct[pct.length - 1] = (pct.last + (5000 - sum)).clamp(1, 5000);
    }
    return pct;
  }

  static TableGridData fromWordRows(
    List<List<WordTableCell>> sourceRows, {
    int gridColumnCount = 0,
    List<int> gridColTwips = const [],
  }) {
    final rows = <List<String>>[];
    final images = <List<String>>[];
    final colSpans = <List<int>>[];
    final rowSpans = <List<int>>[];

    void ensureRow(int r) {
      while (rows.length <= r) {
        rows.add([]);
        images.add([]);
        colSpans.add([]);
        rowSpans.add([]);
      }
    }

    void ensureCols(int r, int cols) {
      ensureRow(r);
      while (rows[r].length < cols) {
        rows[r].add('');
        images[r].add('');
        colSpans[r].add(1);
        rowSpans[r].add(1);
      }
    }

    for (var r = 0; r < sourceRows.length; r++) {
      ensureRow(r);
      var col = 0;
      for (final cell in sourceRows[r]) {
        if (cell.gridBefore > 0) {
          ensureCols(r, col + cell.gridBefore);
          col += cell.gridBefore;
        }
        final span = cell.colSpan < 1 ? 1 : cell.colSpan;
        ensureCols(r, col + span);

        var text = cell.text;
        var img = cell.imageUrl;
        if (cell.vMergeContinue) {
          // Continuation cells are real Word `tc`s but must not duplicate text.
          text = '';
          img = '';
          rowSpans[r][col] = 0;
        } else {
          rowSpans[r][col] = 1;
        }
        rows[r][col] = text;
        images[r][col] = img;
        colSpans[r][col] = span;
        for (var i = 1; i < span; i++) {
          rows[r][col + i] = '';
          images[r][col + i] = '';
          colSpans[r][col + i] = 0;
          rowSpans[r][col + i] = 0;
        }
        col += span;
        if (cell.gridAfter > 0) {
          ensureCols(r, col + cell.gridAfter);
          col += cell.gridAfter;
        }
      }
    }

    var maxCols = gridColumnCount;
    for (final row in rows) {
      if (row.length > maxCols) maxCols = row.length;
    }
    if (gridColTwips.length > maxCols) maxCols = gridColTwips.length;
    if (maxCols == 0) {
      return const TableGridData(
        rows: [],
        rowCellImages: [],
        colSpans: [],
        rowSpans: [],
      );
    }

    for (var r = 0; r < rows.length; r++) {
      ensureCols(r, maxCols);
    }

    _computeRowSpans(colSpans, rowSpans);
    return TableGridData(
      rows: rows,
      rowCellImages: images,
      colSpans: colSpans,
      rowSpans: rowSpans,
      columnWidthsPct: widthsToPct(
        gridColTwips.length == maxCols
            ? gridColTwips
            : _padTwips(gridColTwips, maxCols),
      ),
    );
  }

  static TableGridData fromHtmlRows(List<List<HtmlTableCell>> sourceRows) {
    if (sourceRows.isEmpty) {
      return const TableGridData(
        rows: [],
        rowCellImages: [],
        colSpans: [],
        rowSpans: [],
      );
    }

    final rows = <List<String>>[];
    final images = <List<String>>[];
    final colSpans = <List<int>>[];
    final rowSpans = <List<int>>[];

    void ensure(int r, int c) {
      while (rows.length <= r) {
        rows.add([]);
        images.add([]);
        colSpans.add([]);
        rowSpans.add([]);
      }
      while (rows[r].length <= c) {
        rows[r].add('');
        images[r].add('');
        colSpans[r].add(1);
        rowSpans[r].add(1);
      }
    }

    bool covered(int r, int c) {
      if (r >= colSpans.length || c >= colSpans[r].length) return false;
      return colSpans[r][c] == 0 ||
          (colSpans[r][c] > 0 && rowSpans[r][c] == 0 && rows[r][c].isEmpty);
    }

    for (var r = 0; r < sourceRows.length; r++) {
      var col = 0;
      for (final cell in sourceRows[r]) {
        while (covered(r, col)) {
          col++;
        }
        final cs = cell.colSpan < 1 ? 1 : cell.colSpan;
        final rs = cell.rowSpan < 1 ? 1 : cell.rowSpan;
        for (var dr = 0; dr < rs; dr++) {
          for (var dc = 0; dc < cs; dc++) {
            ensure(r + dr, col + dc);
            if (dr == 0 && dc == 0) {
              rows[r][col] = cell.text;
              images[r][col] = cell.imageUrl;
              colSpans[r][col] = cs;
              rowSpans[r][col] = rs;
            } else if (dr == 0) {
              colSpans[r][col + dc] = 0;
              rowSpans[r][col + dc] = 0;
            } else if (dc == 0) {
              colSpans[r + dr][col] = cs;
              rowSpans[r + dr][col] = 0;
            } else {
              colSpans[r + dr][col + dc] = 0;
              rowSpans[r + dr][col + dc] = 0;
            }
          }
        }
        col += cs;
      }
    }

    var maxCols = 0;
    for (final row in rows) {
      if (row.length > maxCols) maxCols = row.length;
    }
    for (var r = 0; r < rows.length; r++) {
      while (rows[r].length < maxCols) {
        rows[r].add('');
        images[r].add('');
        colSpans[r].add(1);
        rowSpans[r].add(1);
      }
    }

    return TableGridData(
      rows: rows,
      rowCellImages: images,
      colSpans: colSpans,
      rowSpans: rowSpans,
    );
  }

  static List<int> _padTwips(List<int> twips, int cols) {
    if (cols <= 0) return const [];
    if (twips.isEmpty) return List<int>.filled(cols, 1);
    if (twips.length == cols) return twips;
    if (twips.length > cols) return twips.sublist(0, cols);
    final avg =
        (twips.fold<int>(0, (a, b) => a + b) / twips.length).round().clamp(1, 5000);
    return [...twips, ...List<int>.filled(cols - twips.length, avg)];
  }

  static void _computeRowSpans(
    List<List<int>> colSpans,
    List<List<int>> rowSpans,
  ) {
    for (var r = 0; r < rowSpans.length; r++) {
      for (var c = 0; c < rowSpans[r].length; c++) {
        if (colSpans[r][c] <= 0) continue;
        if (rowSpans[r][c] == 0) continue;
        var span = 1;
        for (var rr = r + 1; rr < rowSpans.length; rr++) {
          if (c >= colSpans[rr].length) break;
          if (colSpans[rr][c] > 0 && rowSpans[rr][c] == 0) {
            span++;
          } else {
            break;
          }
        }
        rowSpans[r][c] = span;
      }
    }
  }
}
