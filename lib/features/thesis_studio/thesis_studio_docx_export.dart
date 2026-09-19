import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../ai_advisor/grounded_work.dart';
import '../acadegate_publish/docx_share.dart';
import '../profile/academic_profile.dart';
import 'thesis_studio_citations.dart';
import 'thesis_studio_models.dart';

class ThesisStudioDocxExport {
  ThesisStudioDocxExport._();

  static final ThesisStudioDocxExport instance = ThesisStudioDocxExport._();

  Future<void> share(ThesisDraft draft, {AcademicProfile? profile}) async {
    final bytes = build(draft, profile: profile);
    await shareDocxBytes(bytes: bytes, name: _fileName(draft));
  }

  Future<void> shareExcerpt({
    required ThesisDraft draft,
    required String heading,
    required String body,
    List<GroundedWork> works = const [],
  }) async {
    final bytes = buildExcerpt(
      draft: draft,
      heading: heading,
      body: body,
      works: works,
    );
    await shareDocxBytes(bytes: bytes, name: _excerptFileName(heading));
  }

  /// Word file with every prior-study paragraph in the literature chapter.
  Future<void> sharePriorStudiesChapter(ThesisDraft draft) async {
    final bytes = buildPriorStudiesChapter(draft);
    final name = draft.arabic
        ? 'الدراسات_السابقة.docx'
        : 'Prior_Studies.docx';
    await shareDocxBytes(bytes: bytes, name: name);
  }

  Uint8List buildPriorStudiesChapter(ThesisDraft draft) {
    final arabic = draft.arabic;
    final chapterIndex =
        draft.chapters.indexWhere((c) => c.id == 'literature');
    final chapter =
        chapterIndex >= 0 ? draft.chapters[chapterIndex] : null;
    final studies = (chapter?.paragraphs ?? const <ThesisParagraph>[])
        .where(
          (p) =>
              p.body.trim().isNotEmpty &&
              (p.id.startsWith('lit_study_') || p.id == 'lit_abstracts_all'),
        )
        .toList();
    if (studies.isEmpty) {
      throw StateError(
        arabic
            ? 'لا فقرات دراسات سابقة جاهزة للتصدير.'
            : 'No prior-study paragraphs ready to export.',
      );
    }

    final xml = StringBuffer();
    void title(String text, {int size = 32}) {
      xml.write(
        '<w:p><w:pPr><w:jc w:val="${arabic ? 'right' : 'both'}"/>'
        '${arabic ? '<w:bidi/>' : ''}'
        '<w:rPr><w:b/><w:sz w:val="$size"/><w:szCs w:val="$size"/></w:rPr>'
        '</w:pPr>${_run(text, bold: true, arabic: arabic)}</w:p>',
      );
    }

    void para(String text) {
      if (text.trim().isEmpty) return;
      for (final part in text.split(RegExp(r'\n{2,}'))) {
        final chunk = part.trim();
        if (chunk.isEmpty) continue;
        xml.write(
          '<w:p><w:pPr><w:jc w:val="${arabic ? 'right' : 'both'}"/>'
          '${arabic ? '<w:bidi/>' : ''}'
          '<w:spacing w:after="200" w:line="360" w:lineRule="auto"/>'
          '</w:pPr>${_run(chunk, arabic: arabic)}</w:p>',
        );
      }
    }

    title(
      arabic ? 'الدراسات السابقة' : 'Previous studies',
      size: 36,
    );
    final allWorks = <GroundedWork>[];
    final seen = <String>{};
    for (final study in studies) {
      // Body already contains Author (Year) / Arabic narrative — no extra heading.
      para(
        ThesisStudioCitations.styledProse(
          study.body,
          draft,
          works: study.references.isNotEmpty ? study.references : null,
        ),
      );
      for (final w in study.references) {
        final key = w.doi.trim().toLowerCase();
        if (key.isEmpty || !seen.add(key)) continue;
        allWorks.add(w);
      }
    }
    if (allWorks.isNotEmpty) {
      title(arabic ? 'المراجع' : 'References', size: 28);
      para(
        ThesisStudioCitations.bibliography(
          allWorks,
          style: draft.plan.citationStyle,
        ),
      );
    }
    return _pack(xml.toString());
  }

  Uint8List buildExcerpt({
    required ThesisDraft draft,
    required String heading,
    required String body,
    List<GroundedWork> works = const [],
  }) {
    final arabic = draft.arabic;
    final xml = StringBuffer();
    void title(String text, {int size = 32}) {
      xml.write(
        '<w:p><w:pPr><w:jc w:val="${arabic ? 'right' : 'left'}"/>'
        '<w:rPr><w:b/><w:sz w:val="$size"/><w:szCs w:val="$size"/></w:rPr>'
        '</w:pPr>${_run(text, bold: true, arabic: arabic)}</w:p>',
      );
    }

    void para(String text) {
      if (text.trim().isEmpty) return;
      for (final part in text.split(RegExp(r'\n{2,}'))) {
        xml.write(
          '<w:p><w:pPr><w:jc w:val="${arabic ? 'right' : 'left'}"/>'
          '${arabic ? '<w:bidi/>' : ''}</w:pPr>${_run(part, arabic: arabic)}</w:p>',
        );
      }
    }

    title(heading, size: 36);
    para(
      ThesisStudioCitations.styledProse(
        body,
        draft,
        works: works.isNotEmpty ? works : null,
      ),
    );
    if (works.isNotEmpty) {
      title(arabic ? 'المراجع' : 'References', size: 28);
      para(
        ThesisStudioCitations.bibliography(
          works,
          style: draft.plan.citationStyle,
        ),
      );
    }
    return _pack(xml.toString());
  }

  Uint8List build(ThesisDraft draft, {AcademicProfile? profile}) {
    final arabic = draft.arabic;
    final body = StringBuffer();
    void heading(String text, {int size = 32}) {
      body.write(
        '<w:p><w:pPr><w:jc w:val="${arabic ? 'right' : 'left'}"/>'
        '<w:rPr><w:b/><w:sz w:val="$size"/><w:szCs w:val="$size"/></w:rPr>'
        '</w:pPr>${_run(text, bold: true, arabic: arabic)}</w:p>',
      );
    }

    void para(String text) {
      if (text.trim().isEmpty) return;
      for (final part in text.split(RegExp(r'\n{2,}'))) {
        body.write(
          '<w:p><w:pPr><w:jc w:val="${arabic ? 'right' : 'left'}"/>'
          '${arabic ? '<w:bidi/>' : ''}</w:pPr>${_run(part, arabic: arabic)}</w:p>',
        );
      }
    }

    heading(
      draft.proposedTitle.isNotEmpty ? draft.proposedTitle : draft.goal.raw,
      size: 40,
    );
    if (profile?.fullName.trim().isNotEmpty == true) {
      para(profile!.fullName.trim());
    }
    para(
      '${draft.goal.degreeLabel} · ${draft.plan.kindLabel} · ${draft.plan.shapeLabel}',
    );
    heading(arabic ? 'الملخص' : 'Abstract', size: 28);
    para(ThesisStudioCitations.styledProse(draft.abstractText, draft));
    if (draft.researchQuestions.isNotEmpty) {
      heading(arabic ? 'أسئلة البحث' : 'Research questions', size: 28);
      for (final q in draft.researchQuestions) {
        para('• $q');
      }
    }
    for (final ch in draft.chapters) {
      heading(ch.title(arabic), size: 32);
      para(ThesisStudioCitations.styledProse(ch.body, draft));
    }
    if (draft.literature.works.isNotEmpty) {
      heading(arabic ? 'المراجع' : 'References', size: 28);
      para(
        ThesisStudioCitations.bibliography(
          draft.literature.works,
          style: draft.plan.citationStyle,
        ),
      );
    }

    return _pack(body.toString());
  }

  static Uint8List _pack(String bodyXml) {
    final documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    $bodyXml
    <w:sectPr>
      <w:pgSz w:w="11906" w:h="16838"/>
      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/>
    </w:sectPr>
  </w:body>
</w:document>''';

    const contentTypes = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>''';

    const rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

    const docRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';

    const styles = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/>
    <w:rPr><w:sz w:val="24"/><w:szCs w:val="24"/></w:rPr>
  </w:style>
</w:styles>''';

    final archive = Archive()
      ..addFile(_xml('[Content_Types].xml', contentTypes))
      ..addFile(_xml('_rels/.rels', rels))
      ..addFile(_xml('word/document.xml', documentXml))
      ..addFile(_xml('word/styles.xml', styles))
      ..addFile(_xml('word/_rels/document.xml.rels', docRels));
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static ArchiveFile _xml(String name, String xml) {
    final bytes = utf8.encode(xml);
    return ArchiveFile(name, bytes.length, bytes);
  }

  static String _run(String text, {required bool arabic, bool bold = false}) {
    final t = _xmlEscape(text.replaceAll('\r\n', '\n'));
    return '<w:r><w:rPr>${bold ? '<w:b/>' : ''}'
        '${arabic ? '<w:rtl/>' : ''}</w:rPr>'
        '<w:t xml:space="preserve">$t</w:t></w:r>';
  }

  static String _xmlEscape(String t) {
    return t
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  static String _fileName(ThesisDraft draft) {
    final base = draft.proposedTitle.trim().isNotEmpty
        ? draft.proposedTitle.trim()
        : 'AcadeGate_Thesis';
    final safe =
        base.replaceAll(RegExp(r'[^\w\u0600-\u06FF\s-]'), '').replaceAll(' ', '_');
    return '${safe.length > 40 ? safe.substring(0, 40) : safe}.docx';
  }

  static String _excerptFileName(String heading) {
    final base = heading.trim().isNotEmpty ? heading.trim() : 'paragraph';
    final safe =
        base.replaceAll(RegExp(r'[^\w\u0600-\u06FF\s-]'), '').replaceAll(' ', '_');
    final stem = safe.isEmpty
        ? 'paragraph'
        : (safe.length > 40 ? safe.substring(0, 40) : safe);
    return '$stem.docx';
  }
}
