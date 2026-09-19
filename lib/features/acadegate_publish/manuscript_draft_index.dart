import '../../core/locale/app_translate.dart';
import 'academic_text.dart';
import 'publish_models.dart';
import 'scholarly_layout.dart';

class DraftSection {
  final String key;
  final String heading;
  final int headingBlockIndex;
  final String text;
  final bool fromAbstractField;

  const DraftSection({
    required this.key,
    required this.heading,
    required this.headingBlockIndex,
    required this.text,
    this.fromAbstractField = false,
  });

  int get wordCount {
    final parts = text.trim().split(RegExp(r'\s+'));
    return text.trim().isEmpty ? 0 : parts.length;
  }

  String excerpt([int max = 420]) {
    final t = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.length <= max) return t;
    return '${t.substring(0, max).trim()}…';
  }
}

class DraftFloat {
  final String kind;
  final int? number;
  final String caption;
  final int blockIndex;
  final String sectionHeading;
  final List<List<String>> rows;

  const DraftFloat({
    required this.kind,
    required this.blockIndex,
    this.number,
    this.caption = '',
    this.sectionHeading = '',
    this.rows = const [],
  });

  bool get isTable => kind == 'table';

  String get label {
    if (number != null) {
      return isTable
          ? appTr('جدول $number', 'Table $number')
          : appTr('شكل $number', 'Figure $number');
    }
    return isTable
        ? appTr('جدول بلا رقم', 'Unnumbered table')
        : appTr('شكل بلا رقم', 'Unnumbered figure');
  }

  String locationLabel(int totalBlocks) {
    final n = blockIndex + 1;
    final after = sectionHeading.trim().isEmpty
        ? ''
        : appTr(' بعد «$sectionHeading»', ' after "$sectionHeading"');
    return appTr(
      'العنصر $n من $totalBlocks$after',
      'item $n of $totalBlocks$after',
    );
  }

  String get preview {
    if (caption.trim().isNotEmpty) {
      final cap = caption.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (rows.isEmpty) return cap;
      return '$cap\n$gridPreview';
    }
    return gridPreview;
  }

  String get gridPreview {
    if (rows.isEmpty) return '';
    return rows.take(3).map((r) {
      return r.take(6).map((c) {
        final t = c.trim().replaceAll(RegExp(r'\s+'), ' ');
        return t.length > 36 ? '${t.substring(0, 36)}…' : t;
      }).join(' | ');
    }).join('\n');
  }
}

class ManuscriptDraftIndex {
  final String title;
  final List<DraftSection> sections;
  final List<DraftFloat> tables;
  final List<DraftFloat> figures;
  final int blockCount;
  final int referenceCount;
  final bool hasUploadedFile;

  const ManuscriptDraftIndex({
    required this.title,
    required this.sections,
    required this.tables,
    required this.figures,
    required this.blockCount,
    required this.referenceCount,
    required this.hasUploadedFile,
  });

  bool get isEmpty =>
      title.trim().isEmpty &&
      sections.every((s) => s.text.trim().isEmpty) &&
      tables.isEmpty &&
      figures.isEmpty;

  DraftSection? sectionByKey(String key) {
    for (final s in sections) {
      if (s.key == key && s.text.trim().isNotEmpty) return s;
    }
    return null;
  }

  DraftSection? get abstractSection => sectionByKey('abstract');
  DraftSection? get resultsSection => sectionByKey('results');
  DraftSection? get discussionSection => sectionByKey('discussion');

  String get inventoryLine {
    final abs = abstractSection == null
        ? appTr('الملخص: غير موجود', 'Abstract: missing')
        : appTr(
            'الملخص: ${abstractSection!.wordCount} كلمة',
            'Abstract: ${abstractSection!.wordCount} words',
          );
    final res = resultsSection == null
        ? appTr('النتائج: غير موجودة', 'Results: missing')
        : appTr('النتائج: موجودة', 'Results: present');
    return appTr(
      '$abs · $res · ${tables.length} جداول · ${figures.length} أشكال · $blockCount عنصراً',
      '$abs · $res · ${tables.length} tables · ${figures.length} figures · $blockCount items',
    );
  }

  DraftFloat? tableByNumber(int n) {
    for (final t in tables) {
      if (t.number == n) return t;
    }
    return null;
  }

  DraftFloat? figureByNumber(int n) {
    for (final t in figures) {
      if (t.number == n) return t;
    }
    return null;
  }

  static ManuscriptDraftIndex fromManuscript(PublishManuscript m) {
    final blocks = m.bodyBlocks;
    final sections = <DraftSection>[];
    final tables = <DraftFloat>[];
    final figures = <DraftFloat>[];

    var heading = '';
    var headingIndex = -1;
    var key = 'body';
    final buffers = <String, StringBuffer>{};
    final meta = <String, (String, int)>{};

    void touch(String k, String h, int i) {
      buffers.putIfAbsent(k, StringBuffer.new);
      meta.putIfAbsent(k, () => (h, i));
    }

    void append(String k, String text) {
      if (text.trim().isEmpty) return;
      final buf = buffers[k];
      if (buf == null) return;
      if (buf.isNotEmpty) buf.write('\n');
      buf.write(text.trim());
    }

    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      if (_isHeading(block)) {
        heading = block.text.trim();
        headingIndex = i;
        key = _classifyHeading(heading) ?? 'h_$i';
        touch(key, heading, i);
        continue;
      }

      touch(key, heading, headingIndex);
      final caption = (block.caption ?? '').trim();

      if (block.type == ManuscriptBlockType.table) {
        final number = _floatNumber(caption.isEmpty ? block.text : caption, table: true) ??
            _floatNumber(block.text, table: true);
        tables.add(DraftFloat(
          kind: 'table',
          number: number,
          caption: caption.isNotEmpty ? caption : block.text.trim(),
          blockIndex: i,
          sectionHeading: heading,
          rows: block.rows,
        ));
        append(key, caption);
        append(key, _rowsPlain(block.rows));
        continue;
      }

      if (block.type == ManuscriptBlockType.image) {
        final number = _floatNumber(caption.isEmpty ? block.text : caption, table: false);
        figures.add(DraftFloat(
          kind: 'figure',
          number: number,
          caption: caption.isNotEmpty ? caption : block.text.trim(),
          blockIndex: i,
          sectionHeading: heading,
          rows: const [],
        ));
        append(key, caption.isNotEmpty ? caption : block.text);
        continue;
      }

      final text = block.text.trim();
      if (text.isEmpty) continue;

      if (ScholarlyLayout.isTableCaption(text)) {
        final nextTable = i + 1 < blocks.length &&
            blocks[i + 1].type == ManuscriptBlockType.table;
        if (!nextTable) {
          tables.add(DraftFloat(
            kind: 'table',
            number: _floatNumber(text, table: true),
            caption: text,
            blockIndex: i,
            sectionHeading: heading,
          ));
        }
      } else if (ScholarlyLayout.isFigureCaption(text)) {
        final nextFig = i + 1 < blocks.length &&
            blocks[i + 1].type == ManuscriptBlockType.image;
        if (!nextFig) {
          figures.add(DraftFloat(
            kind: 'figure',
            number: _floatNumber(text, table: false),
            caption: text,
            blockIndex: i,
            sectionHeading: heading,
          ));
        }
      }

      append(key, text);
    }

    for (final entry in buffers.entries) {
      final text = entry.value.toString().trim();
      if (text.isEmpty) continue;
      final info = meta[entry.key] ?? ('', -1);
      sections.add(DraftSection(
        key: entry.key,
        heading: info.$1.isEmpty ? entry.key : info.$1,
        headingBlockIndex: info.$2,
        text: text.length > 24000 ? text.substring(0, 24000) : text,
      ));
    }

    final fieldAbstract = m.abstractText.trim();
    if (fieldAbstract.isNotEmpty) {
      final field = DraftSection(
        key: 'abstract',
        heading: appTr('الملخص', 'Abstract'),
        headingBlockIndex: -1,
        text: fieldAbstract,
        fromAbstractField: true,
      );
      final existing = sections.indexWhere((s) => s.key == 'abstract');
      if (existing < 0) {
        sections.insert(0, field);
      } else {
        sections[existing] = field;
      }
    }

    return ManuscriptDraftIndex(
      title: m.title.trim(),
      sections: sections,
      tables: tables,
      figures: figures,
      blockCount: blocks.length,
      referenceCount: m.references.length,
      hasUploadedFile: m.attachments.isNotEmpty,
    );
  }

  static bool _isHeading(ManuscriptBlock block) {
    if (block.type == ManuscriptBlockType.heading) return true;
    if (block.type != ManuscriptBlockType.paragraph) return false;
    final t = AcademicText.stripBidi(block.text).trim();
    if (t.isEmpty || t.length > 90) return false;
    if (ScholarlyLayout.isFloatCaption(t)) return false;
    return _classifyHeading(t) != null;
  }

  static String? _classifyHeading(String heading) {
    var t = AcademicText.westernDigits(AcademicText.stripBidi(heading))
        .trim()
        .toLowerCase();
    t = t.replaceFirst(RegExp(r'^\d+\.?\s*'), '');
    t = t.replaceAll(RegExp(r'[:：]+$'), '').trim();
    if (t.isEmpty || t.length > 80) return null;
    if (t == 'abstract' || t == 'الملخص') return 'abstract';
    if (t == 'introduction' || t == 'المقدمة') return 'introduction';
    if (t == 'background' || t == 'الخلفية') return 'background';
    if (t == 'experimental' ||
        t == 'materials and methods' ||
        t == 'materials' ||
        t == 'methods' ||
        t == 'method' ||
        t == 'التجريبي' ||
        t == 'المواد والطرق' ||
        t == 'المنهجية' ||
        t == 'المنهج') {
      return 'methods';
    }
    if (t == 'results' || t == 'result' || t == 'النتائج') return 'results';
    if (t == 'discussion' || t == 'المناقشة') return 'discussion';
    if (t == 'conclusion' ||
        t == 'conclusions' ||
        t == 'الخاتمة' ||
        t == 'الاستنتاج' ||
        t == 'الاستنتاجات') {
      return 'conclusion';
    }
    if (t == 'references' || t == 'المراجع') return 'references';
    if (t == 'keywords' ||
        t == 'الكلمات المفتاحية' ||
        t == 'كلمات مفتاحية' ||
        t == 'الكلمات الدالة') {
      return 'keywords';
    }
    return null;
  }

  static int? _floatNumber(String text, {required bool table}) {
    final t = AcademicText.westernDigits(AcademicText.stripBidi(text));
    final re = table
        ? RegExp(r'(?:Table|جدول)\.?\s*(\d+)', caseSensitive: false)
        : RegExp(
            r'(?:Fig(?:ure)?|شكل|Scheme|Chart|Plate)\.?\s*(\d+)',
            caseSensitive: false,
          );
    return int.tryParse(re.firstMatch(t)?.group(1) ?? '');
  }

  static String _rowsPlain(List<List<String>> rows) {
    return rows.take(8).map((r) => r.take(8).join(' ')).join('\n');
  }
}
