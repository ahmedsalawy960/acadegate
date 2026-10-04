import 'dart:convert';

/// مشروع تحليل نوعي محلي — مسار 3.
class QualProject {
  String researchQuestion;
  /// reflexive_ta | codebook_ta | content_analysis
  String approachId;
  final List<QualTranscript> transcripts;
  final List<QualCode> codes;
  final List<QualExcerpt> excerpts;
  final List<QualTheme> themes;
  final List<QualMemo> memos;
  DateTime updatedAt;

  QualProject({
    this.researchQuestion = '',
    this.approachId = 'reflexive_ta',
    List<QualTranscript>? transcripts,
    List<QualCode>? codes,
    List<QualExcerpt>? excerpts,
    List<QualTheme>? themes,
    List<QualMemo>? memos,
    DateTime? updatedAt,
  })  : transcripts = transcripts ?? [],
        codes = codes ?? [],
        excerpts = excerpts ?? [],
        themes = themes ?? [],
        memos = memos ?? [],
        updatedAt = updatedAt ?? DateTime.now();

  String approachAr() => switch (approachId) {
        'codebook_ta' => 'تحليل موضوعي بدفتر رموز (Codebook TA)',
        'content_analysis' => 'تحليل مضمون نوعي',
        _ => 'تحليل موضوعي انعكاسي (Reflexive TA)',
      };

  String approachEn() => switch (approachId) {
        'codebook_ta' => 'Codebook thematic analysis',
        'content_analysis' => 'Qualitative content analysis',
        _ => 'Reflexive thematic analysis',
      };

  int excerptsForCode(String codeId) =>
      excerpts.where((e) => e.codeIds.contains(codeId)).length;

  QualCode? codeById(String id) {
    for (final c in codes) {
      if (c.id == id) return c;
    }
    return null;
  }

  QualTranscript? transcriptById(String id) {
    for (final t in transcripts) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// ملخص جاهز للصقه في فصل المنهجية / النتائج.
  String summaryForMethodology() {
    final b = StringBuffer();
    b.writeln('تحليل نوعي: ${approachAr()}');
    if (researchQuestion.trim().isNotEmpty) {
      b.writeln('سؤال البحث: $researchQuestion');
    }
    b.writeln(
      'البيانات: ${transcripts.length} نصاً · '
      '${codes.length} رمزاً · '
      '${excerpts.length} مقتطفاً مرمّزاً · '
      '${themes.length} موضوعاً · '
      '${memos.length} مذكرة.',
    );
    if (codes.isNotEmpty) {
      b.writeln('دفتر الرموز:');
      for (final c in codes) {
        final n = excerptsForCode(c.id);
        b.writeln('- ${c.label} ($n مقتطف): ${c.definition}');
      }
    }
    if (themes.isNotEmpty) {
      b.writeln('الموضوعات:');
      for (final t in themes) {
        b.writeln('- ${t.title}: ${t.centralConcept}');
        if (t.writeup.trim().isNotEmpty) {
          b.writeln('  ${t.writeup}');
        }
      }
    }
    return b.toString().trim();
  }

  Map<String, dynamic> toJson() => {
        'researchQuestion': researchQuestion,
        'approachId': approachId,
        'transcripts': transcripts.map((e) => e.toJson()).toList(),
        'codes': codes.map((e) => e.toJson()).toList(),
        'excerpts': excerpts.map((e) => e.toJson()).toList(),
        'themes': themes.map((e) => e.toJson()).toList(),
        'memos': memos.map((e) => e.toJson()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory QualProject.fromJson(Map<String, dynamic> m) => QualProject(
        researchQuestion: (m['researchQuestion'] ?? '').toString(),
        approachId: (m['approachId'] ?? 'reflexive_ta').toString(),
        transcripts: (m['transcripts'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => QualTranscript.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        codes: (m['codes'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => QualCode.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        excerpts: (m['excerpts'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => QualExcerpt.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        themes: (m['themes'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => QualTheme.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        memos: (m['memos'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => QualMemo.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        updatedAt: DateTime.tryParse((m['updatedAt'] ?? '').toString()) ??
            DateTime.now(),
      );

  String encode() => jsonEncode(toJson());

  static QualProject? tryDecode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return QualProject.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static QualProject template() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return QualProject(
      researchQuestion: 'كيف يختبر المشاركون الظاهرة موضع البحث في سياقهم؟',
      approachId: 'reflexive_ta',
      transcripts: [
        QualTranscript(
          id: 'tr_$now',
          title: 'مقابلة ١ (مسودة)',
          participantLabel: 'مشارك أ',
          body:
              'الصق هنا نص المقابلة كاملاً بعد التفريغ.\n\n'
              'مثال: «شعرت أن المدينة تضيق عليّ كلما اقتربت من وسطها…»',
          familiarizationNotes:
              'اقرأ النص مرتين قبل الترميز. سجّل انطباعاتك الأولية هنا.',
        ),
      ],
      codes: [
        QualCode(
          id: 'c_${now}_1',
          label: 'فضاء ضاغط',
          definition: 'وصف المكان كضيق أو خانق يؤثر على التجربة.',
        ),
        QualCode(
          id: 'c_${now}_2',
          label: 'توتر الهوية',
          definition: 'تعارض بين صورة الذات المتوقعة والواقع المعاش.',
        ),
      ],
    );
  }
}

class QualTranscript {
  final String id;
  String title;
  String participantLabel;
  String body;
  String familiarizationNotes;

  QualTranscript({
    required this.id,
    this.title = '',
    this.participantLabel = '',
    this.body = '',
    this.familiarizationNotes = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'participantLabel': participantLabel,
        'body': body,
        'familiarizationNotes': familiarizationNotes,
      };

  factory QualTranscript.fromJson(Map<String, dynamic> m) => QualTranscript(
        id: (m['id'] ?? '').toString(),
        title: (m['title'] ?? '').toString(),
        participantLabel: (m['participantLabel'] ?? '').toString(),
        body: (m['body'] ?? '').toString(),
        familiarizationNotes: (m['familiarizationNotes'] ?? '').toString(),
      );
}

class QualCode {
  final String id;
  String label;
  String definition;
  String inclusionNotes;

  QualCode({
    required this.id,
    this.label = '',
    this.definition = '',
    this.inclusionNotes = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'definition': definition,
        'inclusionNotes': inclusionNotes,
      };

  factory QualCode.fromJson(Map<String, dynamic> m) => QualCode(
        id: (m['id'] ?? '').toString(),
        label: (m['label'] ?? '').toString(),
        definition: (m['definition'] ?? '').toString(),
        inclusionNotes: (m['inclusionNotes'] ?? '').toString(),
      );
}

class QualExcerpt {
  final String id;
  String transcriptId;
  String quote;
  final List<String> codeIds;
  String note;

  QualExcerpt({
    required this.id,
    required this.transcriptId,
    this.quote = '',
    List<String>? codeIds,
    this.note = '',
  }) : codeIds = codeIds ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'transcriptId': transcriptId,
        'quote': quote,
        'codeIds': codeIds,
        'note': note,
      };

  factory QualExcerpt.fromJson(Map<String, dynamic> m) => QualExcerpt(
        id: (m['id'] ?? '').toString(),
        transcriptId: (m['transcriptId'] ?? '').toString(),
        quote: (m['quote'] ?? '').toString(),
        codeIds: (m['codeIds'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
        note: (m['note'] ?? '').toString(),
      );
}

class QualTheme {
  final String id;
  String title;
  /// المفهوم المنظّم المركزي — ليس مجرد عنوان موضوعي.
  String centralConcept;
  final List<String> codeIds;
  String writeup;

  QualTheme({
    required this.id,
    this.title = '',
    this.centralConcept = '',
    List<String>? codeIds,
    this.writeup = '',
  }) : codeIds = codeIds ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'centralConcept': centralConcept,
        'codeIds': codeIds,
        'writeup': writeup,
      };

  factory QualTheme.fromJson(Map<String, dynamic> m) => QualTheme(
        id: (m['id'] ?? '').toString(),
        title: (m['title'] ?? '').toString(),
        centralConcept: (m['centralConcept'] ?? '').toString(),
        codeIds: (m['codeIds'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
        writeup: (m['writeup'] ?? '').toString(),
      );
}

class QualMemo {
  final String id;
  String title;
  String body;
  String? linkedCodeId;
  String? linkedThemeId;
  DateTime updatedAt;

  QualMemo({
    required this.id,
    this.title = '',
    this.body = '',
    this.linkedCodeId,
    this.linkedThemeId,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'linkedCodeId': linkedCodeId,
        'linkedThemeId': linkedThemeId,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory QualMemo.fromJson(Map<String, dynamic> m) => QualMemo(
        id: (m['id'] ?? '').toString(),
        title: (m['title'] ?? '').toString(),
        body: (m['body'] ?? '').toString(),
        linkedCodeId: m['linkedCodeId']?.toString(),
        linkedThemeId: m['linkedThemeId']?.toString(),
        updatedAt: DateTime.tryParse((m['updatedAt'] ?? '').toString()) ??
            DateTime.now(),
      );
}

/// مراحل Braun & Clarke الست — للواجهة التعليمية.
class QualPhase {
  final int number;
  final String titleAr;
  final String titleEn;
  final String hintAr;
  final String hintEn;

  const QualPhase({
    required this.number,
    required this.titleAr,
    required this.titleEn,
    required this.hintAr,
    required this.hintEn,
  });

  static const all = <QualPhase>[
    QualPhase(
      number: 1,
      titleAr: 'الألفة مع البيانات',
      titleEn: 'Familiarisation',
      hintAr: 'اقرأ النصوص وأضف ملاحظات الألفة لكل مقابلة.',
      hintEn: 'Read transcripts and add familiarisation notes per interview.',
    ),
    QualPhase(
      number: 2,
      titleAr: 'توليد الرموز',
      titleEn: 'Generating codes',
      hintAr: 'ابنِ دفتر رموز وطبّقها على مقتطفات من النصوص.',
      hintEn: 'Build a codebook and apply codes to excerpts.',
    ),
    QualPhase(
      number: 3,
      titleAr: 'بناء موضوعات مرشّحة',
      titleEn: 'Generating themes',
      hintAr: 'اجمع الرموز المترابطة في موضوعات ذات مفهوم مركزي.',
      hintEn: 'Cluster related codes into themes with a central concept.',
    ),
    QualPhase(
      number: 4,
      titleAr: 'مراجعة الموضوعات',
      titleEn: 'Reviewing themes',
      hintAr: 'تحقق أن كل موضوع متماسك ومتميّز عن غيره.',
      hintEn: 'Check each theme is coherent and distinct.',
    ),
    QualPhase(
      number: 5,
      titleAr: 'تعريف الموضوعات',
      titleEn: 'Defining themes',
      hintAr: 'اكتب المفهوم المنظّم والصياغة التحليلية لكل موضوع.',
      hintEn: 'Write the central organising concept and analytic write-up.',
    ),
    QualPhase(
      number: 6,
      titleAr: 'الكتابة',
      titleEn: 'Writing up',
      hintAr: 'صدّر الملخص للمنهجية/النتائج والصقه في الرسالة.',
      hintEn: 'Export the methods/results summary into your thesis.',
    ),
  ];
}
