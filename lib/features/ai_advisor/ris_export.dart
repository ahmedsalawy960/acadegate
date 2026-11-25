import 'grounded_work.dart';

/// RIS export — the format Zotero, Mendeley and EndNote import directly.
class RisExport {
  RisExport._();

  static String forWorks(List<GroundedWork> works) {
    final buf = StringBuffer();
    for (final w in works) {
      buf.writeln('TY  - JOUR');
      buf.writeln('TI  - ${_oneLine(w.title)}');
      for (final author in _authors(w.authors)) {
        buf.writeln('AU  - $author');
      }
      if (w.year != null) buf.writeln('PY  - ${w.year}');
      final journal = (w.journal ?? '').trim();
      if (journal.isNotEmpty) buf.writeln('JO  - ${_oneLine(journal)}');
      final abstract = _oneLine(w.abstractText);
      if (abstract.isNotEmpty) buf.writeln('AB  - $abstract');
      if (w.hasDoi) buf.writeln('DO  - ${w.doi.trim()}');
      final url = w.primaryUrl;
      if (url.isNotEmpty) buf.writeln('UR  - $url');
      buf.writeln('ER  - ');
      buf.writeln();
    }
    return buf.toString();
  }

  static String _oneLine(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  static List<String> _authors(String authors) => authors
      .split(RegExp(r',| and |؛'))
      .map((a) => a.trim())
      .where((a) => a.isNotEmpty)
      .toList();
}
