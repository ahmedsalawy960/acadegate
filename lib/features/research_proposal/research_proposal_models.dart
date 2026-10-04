import 'dart:convert';

import 'research_proposal_templates.dart';

class ProposalDraft {
  String templateId;
  String facultyId;
  String degreeLevel; // masters | phd | both
  /// فقرات مفعّلة من الكتالوج العام (إن فُرغت يُستنتج من الاختصار).
  List<String> selectedSections;
  final Map<String, String> sections;
  final Map<String, bool> workshopChecks;
  String expertNotes;
  String preferredExpertTrack; // education | law | arts | any
  DateTime updatedAt;

  ProposalDraft({
    this.templateId = 'catalog_all',
    this.facultyId = 'General',
    this.degreeLevel = 'masters',
    List<String>? selectedSections,
    Map<String, String>? sections,
    Map<String, bool>? workshopChecks,
    this.expertNotes = '',
    this.preferredExpertTrack = 'any',
    DateTime? updatedAt,
  })  : selectedSections =
            List<String>.from(selectedSections ?? allProposalSectionKeys),
        sections = sections ?? {},
        workshopChecks = workshopChecks ?? {},
        updatedAt = updatedAt ?? DateTime.now();

  String get titleAr => sections[ProposalSectionKeys.titleAr] ?? '';
  String get titleEn => sections[ProposalSectionKeys.titleEn] ?? '';

  String section(String key) => sections[key]?.trim() ?? '';

  void setSection(String key, String value) {
    sections[key] = value;
  }

  List<String> get activeSections => resolveActiveSections(
        selectedSections: selectedSections,
        templateId: templateId,
        facultyId: facultyId,
      );

  void applySectionSelection({
    required List<String> keys,
    String? templateId,
    String? facultyId,
  }) {
    selectedSections = List<String>.from(
      resolveActiveSections(
        selectedSections: keys,
        templateId: templateId ?? this.templateId,
        facultyId: facultyId ?? this.facultyId,
      ),
    );
    if (templateId != null) this.templateId = templateId;
    if (facultyId != null) this.facultyId = facultyId;
  }

  int filledCount(List<String> keys) {
    var n = 0;
    for (final k in keys) {
      if (section(k).length >= 12) n++;
    }
    return n;
  }

  double completionRatio(List<String> keys) {
    if (keys.isEmpty) return 0;
    return filledCount(keys) / keys.length;
  }

  String exportText({required bool arabic}) {
    final b = StringBuffer();
    b.writeln(arabic
        ? 'خطة بحث — مسودة AcadeGate'
        : 'Research proposal — AcadeGate draft');
    final tpl = proposalTemplateById(templateId);
    if (tpl != null && tpl.id != 'catalog_all') {
      b.writeln(arabic
          ? 'اختصار: ${tpl.titleAr}'
          : 'Shortcut: ${tpl.titleEn}');
    } else {
      b.writeln(arabic
          ? 'فقرات مختارة من الكتالوج العام'
          : 'Sections selected from the shared catalog');
    }
    b.writeln(arabic
        ? 'الدرجة: ${degreeLevel == 'phd' ? 'دكتوراه' : degreeLevel == 'masters' ? 'ماجستير' : 'ماجستير/دكتوراه'}'
        : 'Degree: $degreeLevel');
    b.writeln('');
    for (final k in activeSections) {
      final body = section(k);
      if (body.isEmpty) continue;
      b.writeln(arabic
          ? ProposalSectionKeys.labelAr(k)
          : ProposalSectionKeys.labelEn(k));
      b.writeln(body);
      b.writeln('');
    }
    if (expertNotes.trim().isNotEmpty) {
      b.writeln(arabic ? 'ملاحظات للمراجع البشري:' : 'Notes for human reviewer:');
      b.writeln(expertNotes.trim());
    }
    b.writeln('');
    b.writeln(
      arabic
          ? 'تنبيه: مسودة إرشادية — راجع نموذج ولوائح كليتك قبل العرض على القسم.'
          : 'Note: guidance draft — check your faculty’s official form before the department review.',
    );
    return b.toString().trim();
  }

  String summaryForMethodology() {
    final b = StringBuffer();
    b.writeln('من مسودة الخطة البحثية:');
    if (titleAr.isNotEmpty) b.writeln('العنوان: $titleAr');
    if (section(ProposalSectionKeys.problem).isNotEmpty) {
      b.writeln('المشكلة: ${section(ProposalSectionKeys.problem)}');
    }
    if (section(ProposalSectionKeys.questions).isNotEmpty) {
      b.writeln('الأسئلة: ${section(ProposalSectionKeys.questions)}');
    }
    if (section(ProposalSectionKeys.methodology).isNotEmpty) {
      b.writeln('المنهج: ${section(ProposalSectionKeys.methodology)}');
    }
    if (section(ProposalSectionKeys.instruments).isNotEmpty) {
      b.writeln('الأدوات: ${section(ProposalSectionKeys.instruments)}');
    }
    if (section(ProposalSectionKeys.analysis).isNotEmpty) {
      b.writeln('التحليل: ${section(ProposalSectionKeys.analysis)}');
    }
    return b.toString().trim();
  }

  Map<String, dynamic> toJson() => {
        'templateId': templateId,
        'facultyId': facultyId,
        'degreeLevel': degreeLevel,
        'selectedSections': selectedSections,
        'sections': sections,
        'workshopChecks': workshopChecks,
        'expertNotes': expertNotes,
        'preferredExpertTrack': preferredExpertTrack,
        'updatedAt': updatedAt.toIso8601String(),
      };

  String encode() => jsonEncode(toJson());

  static ProposalDraft? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final sectionsRaw = map['sections'];
      final sections = <String, String>{};
      if (sectionsRaw is Map) {
        sectionsRaw.forEach((k, v) {
          sections['$k'] = '$v';
        });
      }
      final checksRaw = map['workshopChecks'];
      final checks = <String, bool>{};
      if (checksRaw is Map) {
        checksRaw.forEach((k, v) {
          checks['$k'] = v == true;
        });
      }
      final selectedRaw = map['selectedSections'];
      List<String>? selected;
      if (selectedRaw is List) {
        selected = selectedRaw.map((e) => '$e').where((e) => e.isNotEmpty).toList();
      }
      final templateId = map['templateId']?.toString() ?? 'catalog_all';
      final facultyId = map['facultyId']?.toString() ?? 'General';
      // Migrate old drafts that only had a faculty template id.
      if (selected == null || selected.isEmpty) {
        final tpl = proposalTemplateById(templateId) ??
            proposalTemplateForFaculty(facultyId);
        selected = List.of(tpl?.requiredSections ?? allProposalSectionKeys);
      }
      return ProposalDraft(
        templateId: templateId,
        facultyId: facultyId,
        degreeLevel: map['degreeLevel']?.toString() ?? 'masters',
        selectedSections: selected,
        sections: sections,
        workshopChecks: checks,
        expertNotes: map['expertNotes']?.toString() ?? '',
        preferredExpertTrack:
            map['preferredExpertTrack']?.toString() ?? 'any',
        updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? '') ??
            DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  factory ProposalDraft.emptyFor(ProposalFacultyTemplate template) {
    return ProposalDraft(
      templateId: template.id,
      facultyId: template.facultyId,
      selectedSections: List.of(template.requiredSections),
    );
  }
}

class ProposalConsistencyIssue {
  final String id;
  final String titleAr;
  final String titleEn;
  final String detailAr;
  final String detailEn;
  final String severity; // high | medium | low

  const ProposalConsistencyIssue({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.detailAr,
    required this.detailEn,
    required this.severity,
  });
}

class ProposalConsistencyReport {
  final List<ProposalConsistencyIssue> issues;
  final int score; // 0-100

  const ProposalConsistencyReport({
    required this.issues,
    required this.score,
  });
}
