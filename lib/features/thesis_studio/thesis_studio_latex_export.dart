import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../acadegate_publish/citation_formatter.dart';
import '../acadegate_publish/publish_models.dart';
import '../profile/academic_profile.dart';
import 'thesis_studio_citation_report.dart';
import 'thesis_studio_models.dart';

class ThesisStudioLatexExport {
  ThesisStudioLatexExport._();

  static final ThesisStudioLatexExport instance = ThesisStudioLatexExport._();

  String mainTex(ThesisDraft draft, {AcademicProfile? profile}) {
    final arabic = draft.arabic;
    final title = _escape(draft.proposedTitle.isNotEmpty
        ? draft.proposedTitle
        : draft.goal.raw);
    final author = _escape(
      profile?.fullName.trim().isNotEmpty == true
          ? profile!.fullName.trim()
          : 'AcadeGate Thesis Studio',
    );
    final style = _biblatexStyle(draft.plan.citationStyle);
    final buf = StringBuffer()
      ..writeln('% AcadeGate Thesis Studio — compile with ${arabic ? 'XeLaTeX' : 'pdfLaTeX'} + biber')
      ..writeln('\\documentclass[11pt,a4paper]{article}')
      ..writeln(arabic
          ? '''
\\usepackage{fontspec}
\\usepackage{polyglossia}
\\setmainlanguage{arabic}
\\setotherlanguage{english}
\\newfontfamily\\arabicfont[Script=Arabic]{Amiri}
'''
          : '''
\\usepackage[utf8]{inputenc}
\\usepackage[T1]{fontenc}
\\usepackage[english]{babel}
''')
      ..writeln('\\usepackage[margin=2.4cm]{geometry}')
      ..writeln('\\usepackage{csquotes}')
      ..writeln('\\usepackage[backend=biber, style=$style, sorting=none]{biblatex}')
      ..writeln('\\addbibresource{references.bib}')
      ..writeln('\\usepackage[colorlinks=true,allcolors=blue]{hyperref}')
      ..writeln('\\title{$title}')
      ..writeln('\\author{$author}')
      ..writeln('\\begin{document}')
      ..writeln('\\maketitle')
      ..writeln('\\begin{abstract}')
      ..writeln(_toLatexBody(draft.abstractText))
      ..writeln('\\end{abstract}')
      ..writeln('\\tableofcontents')
      ..writeln('\\newpage');
    if (draft.researchQuestions.isNotEmpty) {
      buf.writeln('\\section*{${arabic ? 'أسئلة البحث' : 'Research questions'}}');
      buf.writeln('\\begin{itemize}');
      for (final q in draft.researchQuestions) {
        buf.writeln('  \\item ${_toLatexBody(q)}');
      }
      buf.writeln('\\end{itemize}');
    }
    for (final ch in draft.chapters) {
      buf.writeln('\\section{${_escape(ch.title(arabic))}}');
      buf.writeln(_toLatexBody(ch.body));
      buf.writeln();
    }
    buf.writeln('\\printbibliography');
    buf.writeln('\\end{document}');
    return buf.toString();
  }

  String bibtex(ThesisDraft draft) {
    final buf = StringBuffer(
      '% AcadeGate — DOI-confirmed works only. Never invent entries.\n',
    );
    for (var i = 0; i < draft.literature.works.length; i++) {
      final w = draft.literature.works[i];
      buf.writeln('@article{ref${i + 1},');
      buf.writeln('  title = {${_bibField(w.title)}},');
      buf.writeln('  author = {${_bibField(_authorsBib(w.authors))}},');
      if (w.year != null) buf.writeln('  year = {${w.year}},');
      if (w.journal != null && w.journal!.trim().isNotEmpty) {
        buf.writeln('  journal = {${_bibField(w.journal!.trim())}},');
      }
      buf.writeln('  doi = {${_bibField(w.doi)}},');
      buf.writeln('  url = {https://doi.org/${w.doi}}');
      buf.writeln('}');
    }
    return buf.toString();
  }

  String citationReportTex(ThesisDraft draft) {
    final report = ThesisCitationReport.fromDraft(draft);
    final arabic = draft.arabic;
    final rows = [
      for (final row in report.rows(draft))
        '${row.index} & ${_escape(row.work.title)} \\newline {\\small https://doi.org/${row.work.doi}} & ${row.used ? 'yes' : 'no'} \\\\',
    ].join('\n');
    return '''
\\documentclass[11pt,a4paper]{article}
\\usepackage[utf8]{inputenc}
\\usepackage[margin=2.2cm]{geometry}
\\usepackage{longtable}
\\usepackage{hyperref}
\\title{${_escape(arabic ? 'تقرير تحقق الاستشهادات' : 'Citation verification report')}}
\\author{AcadeGate Thesis Studio}
\\begin{document}
\\maketitle
${_toLatexBody(report.asText(arabic: arabic))}

\\section*{${arabic ? 'المصادر' : 'Sources'}}
\\begin{longtable}{p{1.2cm}p{9cm}p{2.2cm}}
\\textbf{\\#} & \\textbf{${arabic ? 'العمل' : 'Work'}} & \\textbf{${arabic ? 'مستخدم' : 'Used'}} \\\\
$rows
\\end{longtable}
\\end{document}
''';
  }

  Uint8List overleafZip(ThesisDraft draft, {AcademicProfile? profile}) {
    final readme = draft.arabic
        ? 'أكاديجيت — استوديو الرسالة\n'
            'ارفع هذا الأرشيف إلى Overleaf. للإنجليزية: pdfLaTeX + biber.\n'
            'للعربية: XeLaTeX + biber وخط Amiri.\n'
            'الاستشهادات من دراسات DOI مؤكدة فقط.\n'
        : 'AcadeGate Thesis Studio\n'
            'Upload this archive to Overleaf. English: pdfLaTeX + biber.\n'
            'Arabic: XeLaTeX + biber with Amiri.\n'
            'Citations are DOI-confirmed only.\n';
    final files = <String, String>{
      'main.tex': mainTex(draft, profile: profile),
      'references.bib': bibtex(draft),
      'citation_report.tex': citationReportTex(draft),
      'README.txt': readme,
    };
    final archive = Archive();
    for (final e in files.entries) {
      final bytes = utf8.encode(e.value);
      archive.addFile(ArchiveFile(e.key, bytes.length, bytes));
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static String _biblatexStyle(PublishCitationStyle style) {
    return CitationFormatter.isNumberedStyle(style) ? 'numeric' : 'authoryear';
  }

  static String toLatexBody(String raw) => _toLatexBody(raw);

  static String _toLatexBody(String raw) {
    var t = raw.replaceAll('\r\n', '\n');
    t = t.replaceAllMapped(RegExp(r'\[(\d+)\]'), (m) => '\\cite{ref${m.group(1)}}');
    t = t.splitMapJoin(
      RegExp(r'\\cite\{ref\d+\}'),
      onMatch: (m) => m.group(0)!,
      onNonMatch: _escape,
    );
    t = t.replaceAll('\n\n', '\n\n\\par\n');
    return t;
  }

  static String _escape(String t) {
    return t
        .replaceAll('\\', '\\textbackslash{}')
        .replaceAll('&', '\\&')
        .replaceAll('%', '\\%')
        .replaceAll(r'$', r'\$')
        .replaceAll('#', '\\#')
        .replaceAll('_', '\\_')
        .replaceAll('{', '\\{')
        .replaceAll('}', '\\}');
  }

  static String _bibField(String t) {
    return t
        .replaceAll('\\', '')
        .replaceAll('{', '')
        .replaceAll('}', '')
        .replaceAll('"', '');
  }

  static String _authorsBib(String raw) {
    final names = raw
        .split(RegExp(r'\s*;\s*|\s+and\s+|\s+و\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (names.isEmpty) return 'Unknown';
    return names.join(' and ');
  }
}
