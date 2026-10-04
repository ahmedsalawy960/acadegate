import 'dart:convert';

/// بروتوكول مقابلة شبه مقنّنة — أساسي لآداب/تربية نوعية/إعلام.
class InterviewProtocol {
  final String id;
  String titleAr;
  String researchQuestion;
  String participantProfile;
  String durationMinutes;
  String ethicsNote;
  final List<InterviewQuestion> questions;
  DateTime updatedAt;

  InterviewProtocol({
    required this.id,
    this.titleAr = '',
    this.researchQuestion = '',
    this.participantProfile = '',
    this.durationMinutes = '45–60',
    this.ethicsNote = '',
    List<InterviewQuestion>? questions,
    DateTime? updatedAt,
  })  : questions = questions ?? [],
        updatedAt = updatedAt ?? DateTime.now();

  String summary() {
    final b = StringBuffer();
    b.writeln('بروتوكول مقابلة: $titleAr');
    if (researchQuestion.isNotEmpty) b.writeln('سؤال البحث: $researchQuestion');
    if (participantProfile.isNotEmpty) {
      b.writeln('المشاركون: $participantProfile');
    }
    b.writeln('المدة التقريبية: $durationMinutes دقيقة');
    if (ethicsNote.isNotEmpty) b.writeln('أخلاقيات: $ethicsNote');
    b.writeln('الأسئلة (${questions.length}):');
    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      b.writeln('${i + 1}) [${q.probeTypeAr}] ${q.text}');
      if (q.followUp.trim().isNotEmpty) {
        b.writeln('   متابعة: ${q.followUp}');
      }
    }
    return b.toString().trim();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'titleAr': titleAr,
        'researchQuestion': researchQuestion,
        'participantProfile': participantProfile,
        'durationMinutes': durationMinutes,
        'ethicsNote': ethicsNote,
        'questions': questions.map((e) => e.toJson()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory InterviewProtocol.fromJson(Map<String, dynamic> m) =>
      InterviewProtocol(
        id: (m['id'] ?? '').toString(),
        titleAr: (m['titleAr'] ?? '').toString(),
        researchQuestion: (m['researchQuestion'] ?? '').toString(),
        participantProfile: (m['participantProfile'] ?? '').toString(),
        durationMinutes: (m['durationMinutes'] ?? '45–60').toString(),
        ethicsNote: (m['ethicsNote'] ?? '').toString(),
        questions: (m['questions'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => InterviewQuestion.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        updatedAt: DateTime.tryParse((m['updatedAt'] ?? '').toString()) ??
            DateTime.now(),
      );

  String encode() => jsonEncode(toJson());

  static InterviewProtocol? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return InterviewProtocol.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  static InterviewProtocol template() => InterviewProtocol(
        id: 'iv_${DateTime.now().millisecondsSinceEpoch}',
        titleAr: 'مقابلة شبه مقنّنة (مسودة)',
        researchQuestion: 'كيف يختبر المشاركون الظاهرة المدروسة في سياقهم؟',
        participantProfile: 'باحثون/معلمون/قرّاء — حسب مجتمع الدراسة',
        ethicsNote: 'موافقة مستنيرة · سرية · حق الانسحاب',
        questions: [
          InterviewQuestion(
            id: 'q1',
            text: 'حدّثني عن تجربتك مع الظاهرة موضع البحث.',
            probeType: 'opening',
          ),
          InterviewQuestion(
            id: 'q2',
            text: 'ما المواقف التي شكّلت فهمك لهذا الموضوع؟',
            probeType: 'core',
            followUp: 'هل يمكنك إعطاء مثالاً ملموساً؟',
          ),
          InterviewQuestion(
            id: 'q3',
            text: 'كيف تفسّر الصعوبات أو التناقضات التي واجهتها؟',
            probeType: 'probe',
          ),
          InterviewQuestion(
            id: 'q4',
            text: 'هل هناك شيء مهم لم أسألك عنه؟',
            probeType: 'closing',
          ),
        ],
      );
}

class InterviewQuestion {
  final String id;
  String text;
  String followUp;
  /// opening | core | probe | closing
  String probeType;

  InterviewQuestion({
    required this.id,
    this.text = '',
    this.followUp = '',
    this.probeType = 'core',
  });

  String get probeTypeAr => switch (probeType) {
        'opening' => 'افتتاح',
        'probe' => 'تعمّق',
        'closing' => 'ختام',
        _ => 'محوري',
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'followUp': followUp,
        'probeType': probeType,
      };

  factory InterviewQuestion.fromJson(Map<String, dynamic> m) =>
      InterviewQuestion(
        id: (m['id'] ?? '').toString(),
        text: (m['text'] ?? '').toString(),
        followUp: (m['followUp'] ?? '').toString(),
        probeType: (m['probeType'] ?? 'core').toString(),
      );
}

/// بطاقة ترميز تحليل مضمون — للإعلام والآداب.
class ContentAnalysisSheet {
  final String id;
  String titleAr;
  String researchQuestion;
  String unitOfAnalysis;
  String corpusDescription;
  final List<ContentCode> codes;
  DateTime updatedAt;

  ContentAnalysisSheet({
    required this.id,
    this.titleAr = '',
    this.researchQuestion = '',
    this.unitOfAnalysis = 'فقرة / مشهد / خبر',
    this.corpusDescription = '',
    List<ContentCode>? codes,
    DateTime? updatedAt,
  })  : codes = codes ?? [],
        updatedAt = updatedAt ?? DateTime.now();

  String summary() {
    final b = StringBuffer();
    b.writeln('ورقة تحليل مضمون: $titleAr');
    if (researchQuestion.isNotEmpty) b.writeln('سؤال البحث: $researchQuestion');
    b.writeln('وحدة التحليل: $unitOfAnalysis');
    if (corpusDescription.isNotEmpty) b.writeln('المدونة: $corpusDescription');
    b.writeln('رموز الترميز (${codes.length}):');
    for (final c in codes) {
      b.writeln('- ${c.label}: ${c.definition}');
      if (c.example.trim().isNotEmpty) b.writeln('  مثال: ${c.example}');
    }
    return b.toString().trim();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'titleAr': titleAr,
        'researchQuestion': researchQuestion,
        'unitOfAnalysis': unitOfAnalysis,
        'corpusDescription': corpusDescription,
        'codes': codes.map((e) => e.toJson()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ContentAnalysisSheet.fromJson(Map<String, dynamic> m) =>
      ContentAnalysisSheet(
        id: (m['id'] ?? '').toString(),
        titleAr: (m['titleAr'] ?? '').toString(),
        researchQuestion: (m['researchQuestion'] ?? '').toString(),
        unitOfAnalysis: (m['unitOfAnalysis'] ?? '').toString(),
        corpusDescription: (m['corpusDescription'] ?? '').toString(),
        codes: (m['codes'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => ContentCode.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        updatedAt: DateTime.tryParse((m['updatedAt'] ?? '').toString()) ??
            DateTime.now(),
      );

  String encode() => jsonEncode(toJson());

  static ContentAnalysisSheet? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return ContentAnalysisSheet.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  static ContentAnalysisSheet template() => ContentAnalysisSheet(
        id: 'ca_${DateTime.now().millisecondsSinceEpoch}',
        titleAr: 'ورقة ترميز تحليل مضمون (مسودة)',
        researchQuestion: 'ما أنماط الخطاب/التمثيل الظاهرة في المدونة؟',
        unitOfAnalysis: 'فقرة أو وحدة خبرية',
        corpusDescription: 'حدد المصدر، الفترة، ومعايير الإدراج/الاستبعاد',
        codes: [
          ContentCode(
            id: 'c1',
            label: 'موضوع مركزي',
            definition: 'الفكرة الغالبة في وحدة التحليل',
          ),
          ContentCode(
            id: 'c2',
            label: 'إطار قيمي / أيديولوجي',
            definition: 'القيم أو المواقف الضمنية في النص',
          ),
          ContentCode(
            id: 'c3',
            label: 'أسلوب بلاغي',
            definition: 'استعارة، تكرار، سرد، حجاج…',
            example: 'مثال: تشبيه المدينة بالكائن الحي',
          ),
        ],
      );
}

class ContentCode {
  final String id;
  String label;
  String definition;
  String example;

  ContentCode({
    required this.id,
    this.label = '',
    this.definition = '',
    this.example = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'definition': definition,
        'example': example,
      };

  factory ContentCode.fromJson(Map<String, dynamic> m) => ContentCode(
        id: (m['id'] ?? '').toString(),
        label: (m['label'] ?? '').toString(),
        definition: (m['definition'] ?? '').toString(),
        example: (m['example'] ?? '').toString(),
      );
}

/// بطاقة مدونة نصوص/وثائق/أرشيف — لآداب وحقوق.
class CorpusDocumentCard {
  final String id;
  String titleAr;
  String researchQuestion;
  String selectionCriteria;
  String ethicsCopyright;
  final List<CorpusItem> items;
  DateTime updatedAt;

  CorpusDocumentCard({
    required this.id,
    this.titleAr = '',
    this.researchQuestion = '',
    this.selectionCriteria = '',
    this.ethicsCopyright = '',
    List<CorpusItem>? items,
    DateTime? updatedAt,
  })  : items = items ?? [],
        updatedAt = updatedAt ?? DateTime.now();

  String summary() {
    final b = StringBuffer();
    b.writeln('بطاقة مدونة نصوص/وثائق: $titleAr');
    if (researchQuestion.isNotEmpty) b.writeln('سؤال البحث: $researchQuestion');
    if (selectionCriteria.isNotEmpty) {
      b.writeln('معايير الاختيار: $selectionCriteria');
    }
    if (ethicsCopyright.isNotEmpty) {
      b.writeln('حقوق/أخلاقيات: $ethicsCopyright');
    }
    b.writeln('العناصر (${items.length}):');
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      b.writeln(
        '${i + 1}) ${it.title} — ${it.source} (${it.year})'
        '${it.notes.isNotEmpty ? ' · ${it.notes}' : ''}',
      );
    }
    return b.toString().trim();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'titleAr': titleAr,
        'researchQuestion': researchQuestion,
        'selectionCriteria': selectionCriteria,
        'ethicsCopyright': ethicsCopyright,
        'items': items.map((e) => e.toJson()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory CorpusDocumentCard.fromJson(Map<String, dynamic> m) =>
      CorpusDocumentCard(
        id: (m['id'] ?? '').toString(),
        titleAr: (m['titleAr'] ?? '').toString(),
        researchQuestion: (m['researchQuestion'] ?? '').toString(),
        selectionCriteria: (m['selectionCriteria'] ?? '').toString(),
        ethicsCopyright: (m['ethicsCopyright'] ?? '').toString(),
        items: (m['items'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => CorpusItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        updatedAt: DateTime.tryParse((m['updatedAt'] ?? '').toString()) ??
            DateTime.now(),
      );

  String encode() => jsonEncode(toJson());

  static CorpusDocumentCard? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return CorpusDocumentCard.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  static CorpusDocumentCard templateArts() => CorpusDocumentCard(
        id: 'corp_${DateTime.now().millisecondsSinceEpoch}',
        titleAr: 'مدونة نصوص أدبية (مسودة)',
        researchQuestion: 'كيف تُبنى الظاهرة السردية/اللغوية في المدونة المختارة؟',
        selectionCriteria:
            'نوع أدبي · فترة زمنية · توافر نص موثوق · تنوع تمثيلي كافٍ لسؤال البحث',
        ethicsCopyright: 'استشهاد كامل · احترام حقوق النشر للنصوص الحديثة',
        items: [
          CorpusItem(
            id: 't1',
            title: 'نص / عمل أول',
            source: 'طبعة محققة أو مصدر موثّق',
            year: '',
            notes: 'لماذا أُدرج في المدونة؟',
          ),
        ],
      );

  static CorpusDocumentCard templateLaw() => CorpusDocumentCard(
        id: 'corp_${DateTime.now().millisecondsSinceEpoch}',
        titleAr: 'بطاقة وثائق وأحكام قانونية (مسودة)',
        researchQuestion: 'ما القواعد/الأحكام الحاكمة للمسألة القانونية المدروسة؟',
        selectionCriteria:
            'نص تشريعي نافذ · أحكام ذات صلة · فقه/شروح معتمدة · تاريخ السريان',
        ethicsCopyright: 'توثيق رسمي للمصادر · عدم اجتزاء مخلّ بالمعنى',
        items: [
          CorpusItem(
            id: 't1',
            title: 'نص تشريعي / حكم',
            source: 'الجريدة الرسمية / مجموعة أحكام',
            year: '',
            notes: 'المادة/الفقرة ذات الصلة',
          ),
        ],
      );
}

class CorpusItem {
  final String id;
  String title;
  String source;
  String year;
  String notes;

  CorpusItem({
    required this.id,
    this.title = '',
    this.source = '',
    this.year = '',
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'source': source,
        'year': year,
        'notes': notes,
      };

  factory CorpusItem.fromJson(Map<String, dynamic> m) => CorpusItem(
        id: (m['id'] ?? '').toString(),
        title: (m['title'] ?? '').toString(),
        source: (m['source'] ?? '').toString(),
        year: (m['year'] ?? '').toString(),
        notes: (m['notes'] ?? '').toString(),
      );
}
