import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'publish_models.dart';
import 'table_grid.dart';

/// Converts mammoth HTML output into structured manuscript blocks.
class ManuscriptHtmlParser {
  ManuscriptHtmlParser._();

  static List<ManuscriptBlock> parse(String html, {String? stopBeforeText}) {
    if (html.trim().isEmpty) return [];

    final doc = html_parser.parse(html);
    final body = doc.body ?? doc;
    final blocks = <ManuscriptBlock>[];
    var idCounter = 0;

    String nextId() => 'import_${DateTime.now().millisecondsSinceEpoch}_${idCounter++}';

    void walk(dom.Node node) {
      if (node is dom.Element) {
        final tag = node.localName?.toLowerCase() ?? '';
        if (_isBibliographyHeading(node)) return;

        switch (tag) {
          case 'h1':
          case 'h2':
          case 'h3':
          case 'h4':
          case 'h5':
          case 'h6':
            _addTextBlock(blocks, nextId(), ManuscriptBlockType.heading, node.text);
          case 'p':
            final text = node.text.trim();
            if (text.isNotEmpty) {
              _addTextBlock(blocks, nextId(), ManuscriptBlockType.paragraph, text);
            }
          case 'table':
            final grid = _parseTable(node);
            if (grid.rows.isNotEmpty) {
              blocks.add(ManuscriptBlock(
                id: nextId(),
                type: ManuscriptBlockType.table,
                rows: grid.rows,
                rowCellImages: grid.rowCellImages,
                colSpans: grid.colSpans,
                rowSpans: grid.rowSpans,
              ));
            }
          case 'img':
            final src = node.attributes['src']?.trim() ?? '';
            if (src.isNotEmpty) {
              blocks.add(ManuscriptBlock(
                id: nextId(),
                type: ManuscriptBlockType.image,
                imageUrl: src,
                caption: node.attributes['alt']?.trim(),
              ));
            }
          case 'ol':
          case 'ul':
            for (final li in node.children.where((c) => c.localName == 'li')) {
              _addTextBlock(
                blocks,
                nextId(),
                ManuscriptBlockType.paragraph,
                li.text.trim(),
              );
            }
          default:
            if (tag == 'div' || tag == 'section' || tag == 'article') {
              for (final child in node.nodes) {
                walk(child);
              }
            }
        }
        return;
      }

      if (node is dom.Element == false && node.parent == body) {
        return;
      }
    }

    for (final child in body.nodes) {
      if (_shouldStop(child, stopBeforeText)) break;
      walk(child);
    }

    return blocks;
  }

  static bool _shouldStop(dom.Node node, String? stopBeforeText) {
    if (stopBeforeText == null || stopBeforeText.isEmpty) return false;
    if (node is! dom.Element) return false;
    if (_isBibliographyHeading(node)) return true;
    final text = node.text.trim().toLowerCase();
    return text == 'references' ||
        text == 'bibliography' ||
        text == 'works cited' ||
        text.contains('المراجع');
  }

  static bool _isBibliographyHeading(dom.Element el) {
    final tag = el.localName?.toLowerCase() ?? '';
    if (!tag.startsWith('h')) return false;
    final text = el.text.trim().toLowerCase();
    return text == 'references' ||
        text == 'bibliography' ||
        text == 'works cited' ||
        text.contains('المراجع') ||
        text.contains('قائمة المراجع');
  }

  static void _addTextBlock(
    List<ManuscriptBlock> blocks,
    String id,
    ManuscriptBlockType type,
    String text,
  ) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    blocks.add(ManuscriptBlock(id: id, type: type, text: trimmed));
  }

  static TableGridData _parseTable(dom.Element table) {
    final sourceRows = <List<HtmlTableCell>>[];
    for (final tr in table.querySelectorAll('tr')) {
      final cells = <HtmlTableCell>[];
      for (final c in tr.children) {
        final tag = c.localName?.toLowerCase() ?? '';
        if (tag != 'td' && tag != 'th') continue;
        final img = c.querySelector('img');
        cells.add(HtmlTableCell(
          text: c.text.trim(),
          imageUrl: img?.attributes['src']?.trim() ?? '',
          colSpan: int.tryParse(c.attributes['colspan'] ?? '') ?? 1,
          rowSpan: int.tryParse(c.attributes['rowspan'] ?? '') ?? 1,
        ));
      }
      if (cells.isNotEmpty) sourceRows.add(cells);
    }
    return TableGrid.fromHtmlRows(sourceRows);
  }
}
