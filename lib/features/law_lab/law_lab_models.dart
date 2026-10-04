import 'dart:convert';

/// مشروع مختبر القانون — مسار 4.
class LawProject {
  String researchQuestion;
  String fieldAr;
  final List<LawIssue> issues;
  final List<LawAuthority> authorities;
  final List<LawCaseBrief> briefs;
  final List<LawCompareRow> comparisons;
  final List<LawArgumentLink> links;
  DateTime updatedAt;

  LawProject({
    this.researchQuestion = '',
    this.fieldAr = 'قانون عام',
    List<LawIssue>? issues,
    List<LawAuthority>? authorities,
    List<LawCaseBrief>? briefs,
    List<LawCompareRow>? comparisons,
    List<LawArgumentLink>? links,
    DateTime? updatedAt,
  })  : issues = issues ?? [],
        authorities = authorities ?? [],
        briefs = briefs ?? [],
        comparisons = comparisons ?? [],
        links = links ?? [],
        updatedAt = updatedAt ?? DateTime.now();

  LawAuthority? authorityById(String id) {
    for (final a in authorities) {
      if (a.id == id) return a;
    }
    return null;
  }

  LawIssue? issueById(String id) {
    for (final i in issues) {
      if (i.id == id) return i;
    }
    return null;
  }

  int linksForIssue(String issueId) =>
      links.where((l) => l.issueId == issueId).length;

  int linksForAuthority(String authorityId) =>
      links.where((l) => l.authorityId == authorityId).length;

  String summaryForMethodology() {
    final b = StringBuffer();
    b.writeln('منهج مختبر الأسانيد القانونية');
    if (researchQuestion.trim().isNotEmpty) {
      b.writeln('سؤال البحث: $researchQuestion');
    }
    if (fieldAr.trim().isNotEmpty) b.writeln('الحقل: $fieldAr');
    b.writeln(
      'الفروع: ${issues.length} · الأسانيد: ${authorities.length} · '
      'بطاقات أحكام: ${briefs.length} · روابط استدلال: ${links.length} · '
      'صفوف مقارنة: ${comparisons.length}.',
    );
    if (issues.isNotEmpty) {
      b.writeln('خريطة المسألة:');
      for (final i in issues) {
        b.writeln('- ${i.title}');
      }
    }
    if (authorities.isNotEmpty) {
      b.writeln('الأسانيد:');
      for (final a in authorities) {
        b.writeln(
          '- [${a.kindAr}] ${a.title}'
          '${a.citation.isEmpty ? '' : ' — ${a.citation}'}'
          '${a.year.isEmpty ? '' : ' (${a.year})'}'
          ' · ${a.statusAr}',
        );
      }
    }
    if (briefs.isNotEmpty) {
      b.writeln('أحكام موجزة:');
      for (final c in briefs) {
        b.writeln('- ${c.court} ${c.caseRef}: ${c.holding}');
      }
    }
    if (comparisons.isNotEmpty) {
      b.writeln('مقارنة تشريعية:');
      for (final r in comparisons) {
        b.writeln(
          '- ${r.issueLabel}: مصر «${r.egyptRule}» ↔ '
          '${r.foreignSystem} «${r.foreignRule}»',
        );
      }
    }
    if (links.isNotEmpty) {
      b.writeln('سلسلة الاستدلال:');
      for (final link in links) {
        final iss = issueById(link.issueId)?.title ?? link.issueId;
        final au = authorityById(link.authorityId);
        final auLabel =
            au == null ? link.authorityId : '[${au.kindAr}] ${au.title}';
        b.writeln('- $iss ← ${link.roleAr} — $auLabel');
      }
    }
    return b.toString().trim();
  }

  /// نص أطول للصقه في فصل الأسانيد داخل استوديو الرسالة.
  String summaryForThesisChapter() {
    final b = StringBuffer();
    b.writeln(summaryForMethodology());
    if (briefs.isNotEmpty) {
      b.writeln('');
      b.writeln('تفاصيل بطاقات الأحكام:');
      for (final c in briefs) {
        b.writeln('• ${c.court} ${c.caseRef} (${c.year})');
        if (c.facts.isNotEmpty) b.writeln('  وقائع: ${c.facts}');
        if (c.issue.isNotEmpty) b.writeln('  مسألة: ${c.issue}');
        if (c.holding.isNotEmpty) b.writeln('  منطوق: ${c.holding}');
        if (c.ratio.isNotEmpty) b.writeln('  علة: ${c.ratio}');
        if (c.relevance.isNotEmpty) b.writeln('  صلة: ${c.relevance}');
      }
    }
    b.writeln('');
    b.writeln(
      'ملاحظة: تحقّق من سريان النصوص والأسانيد من مصادرها الرسمية قبل الاعتماد.',
    );
    return b.toString().trim();
  }

  Map<String, dynamic> toJson() => {
        'researchQuestion': researchQuestion,
        'fieldAr': fieldAr,
        'issues': issues.map((e) => e.toJson()).toList(),
        'authorities': authorities.map((e) => e.toJson()).toList(),
        'briefs': briefs.map((e) => e.toJson()).toList(),
        'comparisons': comparisons.map((e) => e.toJson()).toList(),
        'links': links.map((e) => e.toJson()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory LawProject.fromJson(Map<String, dynamic> m) => LawProject(
        researchQuestion: (m['researchQuestion'] ?? '').toString(),
        fieldAr: (m['fieldAr'] ?? '').toString(),
        issues: (m['issues'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => LawIssue.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        authorities: (m['authorities'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => LawAuthority.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        briefs: (m['briefs'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => LawCaseBrief.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        comparisons: (m['comparisons'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => LawCompareRow.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        links: (m['links'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => LawArgumentLink.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        updatedAt: DateTime.tryParse((m['updatedAt'] ?? '').toString()) ??
            DateTime.now(),
      );

  String encode() => jsonEncode(toJson());

  static LawProject? tryDecode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return LawProject.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static LawProject template() {
    final n = DateTime.now().millisecondsSinceEpoch;
    return LawProject(
      researchQuestion:
          'ما الضمانات القانونية الحاكمة للمسألة موضع البحث في التشريع المصري؟',
      fieldAr: 'إجراءات جنائية / قانون عام',
      issues: [
        LawIssue(
          id: 'iss_${n}_1',
          title: 'الإطار الدستوري والقانوني للمسألة',
        ),
        LawIssue(
          id: 'iss_${n}_2',
          title: 'الموقف القضائي (نقض / دستورية / إدارية)',
        ),
        LawIssue(
          id: 'iss_${n}_3',
          title: 'الفجوة أو التعارض المحتمل مع الممارسة',
        ),
      ],
      authorities: [
        LawAuthority(
          id: 'au_${n}_1',
          kind: 'constitution',
          title: 'دستور جمهورية مصر العربية',
          citation: 'المادة …',
          year: '2014',
          status: 'in_force',
          keyProvision: 'النص أو المبدأ الدستوري ذي الصلة',
        ),
        LawAuthority(
          id: 'au_${n}_2',
          kind: 'statute',
          title: 'قانون … لسنة …',
          citation: 'المادة …',
          year: '',
          status: 'in_force',
          keyProvision: 'نص المادة الحاكمة',
        ),
      ],
    );
  }
}

class LawIssue {
  final String id;
  String title;
  String notes;

  LawIssue({
    required this.id,
    this.title = '',
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'notes': notes,
      };

  factory LawIssue.fromJson(Map<String, dynamic> m) => LawIssue(
        id: (m['id'] ?? '').toString(),
        title: (m['title'] ?? '').toString(),
        notes: (m['notes'] ?? '').toString(),
      );
}

class LawAuthority {
  final String id;
  /// constitution | statute | regulation | judgment | doctrine | treaty | soft
  String kind;
  String title;
  String citation;
  String year;
  /// in_force | amended | repealed | unknown
  String status;
  String keyProvision;
  String notes;

  LawAuthority({
    required this.id,
    this.kind = 'statute',
    this.title = '',
    this.citation = '',
    this.year = '',
    this.status = 'in_force',
    this.keyProvision = '',
    this.notes = '',
  });

  String get kindAr => switch (kind) {
        'constitution' => 'دستور',
        'regulation' => 'لائحة/قرار',
        'judgment' => 'حكم',
        'doctrine' => 'فقه/شرح',
        'treaty' => 'معاهدة',
        'soft' => 'مصدر إرشادي',
        _ => 'تشريع',
      };

  String get kindEn => switch (kind) {
        'constitution' => 'Constitution',
        'regulation' => 'Regulation',
        'judgment' => 'Judgment',
        'doctrine' => 'Doctrine',
        'treaty' => 'Treaty',
        'soft' => 'Soft law',
        _ => 'Statute',
      };

  String get statusAr => switch (status) {
        'amended' => 'معدَّل',
        'repealed' => 'ملغى/مستبدل',
        'unknown' => 'غير مؤكد',
        _ => 'نافذ',
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'title': title,
        'citation': citation,
        'year': year,
        'status': status,
        'keyProvision': keyProvision,
        'notes': notes,
      };

  factory LawAuthority.fromJson(Map<String, dynamic> m) => LawAuthority(
        id: (m['id'] ?? '').toString(),
        kind: (m['kind'] ?? 'statute').toString(),
        title: (m['title'] ?? '').toString(),
        citation: (m['citation'] ?? '').toString(),
        year: (m['year'] ?? '').toString(),
        status: (m['status'] ?? 'in_force').toString(),
        keyProvision: (m['keyProvision'] ?? '').toString(),
        notes: (m['notes'] ?? '').toString(),
      );
}

class LawCaseBrief {
  final String id;
  String court;
  String caseRef;
  String year;
  String facts;
  String issue;
  String holding;
  String ratio;
  String relevance;

  LawCaseBrief({
    required this.id,
    this.court = 'محكمة النقض',
    this.caseRef = '',
    this.year = '',
    this.facts = '',
    this.issue = '',
    this.holding = '',
    this.ratio = '',
    this.relevance = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'court': court,
        'caseRef': caseRef,
        'year': year,
        'facts': facts,
        'issue': issue,
        'holding': holding,
        'ratio': ratio,
        'relevance': relevance,
      };

  factory LawCaseBrief.fromJson(Map<String, dynamic> m) => LawCaseBrief(
        id: (m['id'] ?? '').toString(),
        court: (m['court'] ?? '').toString(),
        caseRef: (m['caseRef'] ?? '').toString(),
        year: (m['year'] ?? '').toString(),
        facts: (m['facts'] ?? '').toString(),
        issue: (m['issue'] ?? '').toString(),
        holding: (m['holding'] ?? '').toString(),
        ratio: (m['ratio'] ?? '').toString(),
        relevance: (m['relevance'] ?? '').toString(),
      );
}

class LawCompareRow {
  final String id;
  String issueLabel;
  String egyptRule;
  String foreignSystem;
  String foreignRule;
  String note;

  LawCompareRow({
    required this.id,
    this.issueLabel = '',
    this.egyptRule = '',
    this.foreignSystem = '',
    this.foreignRule = '',
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'issueLabel': issueLabel,
        'egyptRule': egyptRule,
        'foreignSystem': foreignSystem,
        'foreignRule': foreignRule,
        'note': note,
      };

  factory LawCompareRow.fromJson(Map<String, dynamic> m) => LawCompareRow(
        id: (m['id'] ?? '').toString(),
        issueLabel: (m['issueLabel'] ?? '').toString(),
        egyptRule: (m['egyptRule'] ?? '').toString(),
        foreignSystem: (m['foreignSystem'] ?? '').toString(),
        foreignRule: (m['foreignRule'] ?? '').toString(),
        note: (m['note'] ?? '').toString(),
      );
}

class LawArgumentLink {
  final String id;
  String issueId;
  String authorityId;
  /// supports | limits | distinguishes | against
  String role;
  String note;

  LawArgumentLink({
    required this.id,
    required this.issueId,
    required this.authorityId,
    this.role = 'supports',
    this.note = '',
  });

  String get roleAr => switch (role) {
        'limits' => 'يقيّد',
        'distinguishes' => 'يميّز',
        'against' => 'يعارض',
        _ => 'يؤيّد',
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'issueId': issueId,
        'authorityId': authorityId,
        'role': role,
        'note': note,
      };

  factory LawArgumentLink.fromJson(Map<String, dynamic> m) => LawArgumentLink(
        id: (m['id'] ?? '').toString(),
        issueId: (m['issueId'] ?? '').toString(),
        authorityId: (m['authorityId'] ?? '').toString(),
        role: (m['role'] ?? 'supports').toString(),
        note: (m['note'] ?? '').toString(),
      );
}
