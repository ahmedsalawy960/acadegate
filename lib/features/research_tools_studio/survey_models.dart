import 'dart:convert';

/// نوع مقياس البند.
enum SurveyScaleType { likert5, likert7, yesNo, openText }

extension SurveyScaleTypeX on SurveyScaleType {
  String get id => name;

  static SurveyScaleType fromId(String? raw) {
    for (final v in SurveyScaleType.values) {
      if (v.name == raw) return v;
    }
    return SurveyScaleType.likert5;
  }

  String labelAr() => switch (this) {
        SurveyScaleType.likert5 => 'ليكرت خماسي',
        SurveyScaleType.likert7 => 'ليكرت سباعي',
        SurveyScaleType.yesNo => 'نعم / لا',
        SurveyScaleType.openText => 'مفتوح',
      };

  String labelEn() => switch (this) {
        SurveyScaleType.likert5 => '5-point Likert',
        SurveyScaleType.likert7 => '7-point Likert',
        SurveyScaleType.yesNo => 'Yes / No',
        SurveyScaleType.openText => 'Open text',
      };
}

class SurveyItem {
  final String id;
  String textAr;
  String textEn;
  SurveyScaleType scale;
  bool reversed;

  SurveyItem({
    required this.id,
    this.textAr = '',
    this.textEn = '',
    this.scale = SurveyScaleType.likert5,
    this.reversed = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'textAr': textAr,
        'textEn': textEn,
        'scale': scale.id,
        'reversed': reversed,
      };

  factory SurveyItem.fromJson(Map<String, dynamic> m) => SurveyItem(
        id: (m['id'] ?? '').toString(),
        textAr: (m['textAr'] ?? '').toString(),
        textEn: (m['textEn'] ?? '').toString(),
        scale: SurveyScaleTypeX.fromId(m['scale']?.toString()),
        reversed: m['reversed'] == true,
      );
}

class SurveyDimension {
  final String id;
  String titleAr;
  String titleEn;
  final List<SurveyItem> items;

  SurveyDimension({
    required this.id,
    this.titleAr = '',
    this.titleEn = '',
    List<SurveyItem>? items,
  }) : items = items ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'titleAr': titleAr,
        'titleEn': titleEn,
        'items': items.map((e) => e.toJson()).toList(),
      };

  factory SurveyDimension.fromJson(Map<String, dynamic> m) => SurveyDimension(
        id: (m['id'] ?? '').toString(),
        titleAr: (m['titleAr'] ?? '').toString(),
        titleEn: (m['titleEn'] ?? '').toString(),
        items: (m['items'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => SurveyItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class SurveyInstrument {
  final String id;
  String titleAr;
  String titleEn;
  String researchQuestion;
  String trackId;
  final List<SurveyDimension> dimensions;
  DateTime updatedAt;

  SurveyInstrument({
    required this.id,
    this.titleAr = '',
    this.titleEn = '',
    this.researchQuestion = '',
    this.trackId = 'education',
    List<SurveyDimension>? dimensions,
    DateTime? updatedAt,
  })  : dimensions = dimensions ?? [],
        updatedAt = updatedAt ?? DateTime.now();

  int get itemCount =>
      dimensions.fold<int>(0, (a, d) => a + d.items.length);

  String summaryForMethodology() {
    final buf = StringBuffer();
    buf.writeln('أداة جمع البيانات: استبانة «$titleAr».');
    if (researchQuestion.trim().isNotEmpty) {
      buf.writeln('سؤال البحث المرتبط: $researchQuestion');
    }
    buf.writeln('عدد الأبعاد: ${dimensions.length} · عدد البنود: $itemCount');
    for (final d in dimensions) {
      buf.writeln('- بُعد: ${d.titleAr} (${d.items.length} بنداً)');
      for (var i = 0; i < d.items.length; i++) {
        final it = d.items[i];
        buf.writeln(
          '  ${i + 1}) ${it.textAr}'
          '${it.reversed ? ' [عكسي]' : ''} — ${it.scale.labelAr()}',
        );
      }
    }
    return buf.toString().trim();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'titleAr': titleAr,
        'titleEn': titleEn,
        'researchQuestion': researchQuestion,
        'trackId': trackId,
        'dimensions': dimensions.map((e) => e.toJson()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory SurveyInstrument.fromJson(Map<String, dynamic> m) => SurveyInstrument(
        id: (m['id'] ?? '').toString(),
        titleAr: (m['titleAr'] ?? '').toString(),
        titleEn: (m['titleEn'] ?? '').toString(),
        researchQuestion: (m['researchQuestion'] ?? '').toString(),
        trackId: (m['trackId'] ?? 'education').toString(),
        dimensions: (m['dimensions'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => SurveyDimension.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        updatedAt: DateTime.tryParse((m['updatedAt'] ?? '').toString()) ??
            DateTime.now(),
      );

  String encode() => jsonEncode(toJson());

  static SurveyInstrument? tryDecode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return SurveyInstrument.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// قالب جاهز حسب مسار إنساني.
  static SurveyInstrument templateForTrack(String trackId) {
    final id = 'inst_${DateTime.now().millisecondsSinceEpoch}';
    switch (trackId) {
      case 'law':
        return SurveyInstrument(
          id: id,
          trackId: trackId,
          titleAr: 'استطلاع وعي قانوني (مسودة)',
          titleEn: 'Legal awareness survey (draft)',
          researchQuestion: 'ما مستوى وعي العينة بالجوانب القانونية ذات الصلة؟',
          dimensions: [
            SurveyDimension(
              id: 'd1',
              titleAr: 'المعرفة القانونية',
              titleEn: 'Legal knowledge',
              items: [
                SurveyItem(
                  id: 'i1',
                  textAr: 'أعرف الحقوق الأساسية المرتبطة بموضوع الدراسة.',
                  textEn: 'I know the basic rights related to the study topic.',
                ),
                SurveyItem(
                  id: 'i2',
                  textAr: 'يمكنني التمييز بين النص القانوني والتطبيق العملي.',
                  textEn: 'I can distinguish statute from practice.',
                ),
              ],
            ),
          ],
        );
      case 'arts':
      case 'media':
        return SurveyInstrument(
          id: id,
          trackId: trackId,
          titleAr: 'استبانة ممارسة قرائية/إعلامية (مسودة)',
          titleEn: 'Reading/media practice survey (draft)',
          researchQuestion: 'كيف توصف ممارسات العينة تجاه النصوص/الوسائط؟',
          dimensions: [
            SurveyDimension(
              id: 'd1',
              titleAr: 'الممارسة',
              titleEn: 'Practice',
              items: [
                SurveyItem(
                  id: 'i1',
                  textAr: 'أقرأ/أتابع محتوى المجال بانتظام.',
                  textEn: 'I regularly read/follow content in this field.',
                ),
                SurveyItem(
                  id: 'i2',
                  textAr: 'أناقش المحتوى مع زملاء أو في سياقات أكاديمية.',
                  textEn: 'I discuss the content with peers or in academic settings.',
                ),
              ],
            ),
          ],
        );
      case 'business':
        return SurveyInstrument(
          id: id,
          trackId: trackId,
          titleAr: 'استبانة رضا/أداء إداري (مسودة)',
          titleEn: 'Managerial satisfaction/performance survey (draft)',
          researchQuestion: 'ما تصور العينة لمستوى الرضا أو الأداء؟',
          dimensions: [
            SurveyDimension(
              id: 'd1',
              titleAr: 'الرضا',
              titleEn: 'Satisfaction',
              items: [
                SurveyItem(
                  id: 'i1',
                  textAr: 'أشعر بالرضا عن الإجراءات الإدارية الحالية.',
                  textEn: 'I am satisfied with current administrative procedures.',
                ),
                SurveyItem(
                  id: 'i2',
                  textAr: 'تُنفَّذ القرارات الإدارية بشفافية.',
                  textEn: 'Administrative decisions are implemented transparently.',
                ),
                SurveyItem(
                  id: 'i3',
                  textAr: 'قنوات التواصل داخل المؤسسة فعّالة.',
                  textEn: 'Internal communication channels are effective.',
                ),
              ],
            ),
          ],
        );
      default: // education + other
        return SurveyInstrument(
          id: id,
          trackId: trackId,
          titleAr: 'استبانة اتجاهات تربوية (مسودة)',
          titleEn: 'Educational attitudes survey (draft)',
          researchQuestion: 'ما اتجاهات العينة نحو الظاهرة التربوية المدروسة؟',
          dimensions: [
            SurveyDimension(
              id: 'd1',
              titleAr: 'الاتجاه المعرفي',
              titleEn: 'Cognitive attitude',
              items: [
                SurveyItem(
                  id: 'i1',
                  textAr: 'أرى أن الظاهرة المدروسة مهمة لتحسين التعلم.',
                  textEn: 'I see the studied phenomenon as important for learning.',
                ),
                SurveyItem(
                  id: 'i2',
                  textAr: 'أمتلك معرفة كافية بمفاهيم الظاهرة.',
                  textEn: 'I have adequate knowledge of the phenomenon’s concepts.',
                ),
              ],
            ),
            SurveyDimension(
              id: 'd2',
              titleAr: 'الاتجاه السلوكي',
              titleEn: 'Behavioral attitude',
              items: [
                SurveyItem(
                  id: 'i3',
                  textAr: 'أطبق ممارسات مرتبطة بالظاهرة في عملي/دراستي.',
                  textEn: 'I apply related practices in my work/study.',
                ),
                SurveyItem(
                  id: 'i4',
                  textAr: 'أوصي زملائي بتبني هذه الممارسات.',
                  textEn: 'I recommend these practices to peers.',
                  reversed: false,
                ),
              ],
            ),
          ],
        );
    }
  }
}

class FaceValidityCheck {
  final String id;
  final String titleAr;
  final String titleEn;
  bool done;
  String note;

  FaceValidityCheck({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    this.done = false,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'titleAr': titleAr,
        'titleEn': titleEn,
        'done': done,
        'note': note,
      };

  factory FaceValidityCheck.fromJson(Map<String, dynamic> m) =>
      FaceValidityCheck(
        id: (m['id'] ?? '').toString(),
        titleAr: (m['titleAr'] ?? '').toString(),
        titleEn: (m['titleEn'] ?? '').toString(),
        done: m['done'] == true,
        note: (m['note'] ?? '').toString(),
      );

  static List<FaceValidityCheck> defaults() => [
        FaceValidityCheck(
          id: 'rq_align',
          titleAr: 'كل بُعد/بند يرتبط بسؤال بحث واضح',
          titleEn: 'Each dimension/item maps to a clear research question',
        ),
        FaceValidityCheck(
          id: 'wording',
          titleAr: 'الصياغة واضحة وغير مزدوجة المعنى',
          titleEn: 'Wording is clear and not double-barreled',
        ),
        FaceValidityCheck(
          id: 'bias',
          titleAr: 'لا توجد أسئلة إيحائية أو متحيزة',
          titleEn: 'No leading or biased items',
        ),
        FaceValidityCheck(
          id: 'scale',
          titleAr: 'نوع المقياس مناسب لمستوى القياس المطلوب',
          titleEn: 'Scale type fits the intended measurement level',
        ),
        FaceValidityCheck(
          id: 'experts',
          titleAr: 'عُرضت الأداة على محكّمين (≥2) وسُجّلت ملاحظاتهم',
          titleEn: 'Instrument reviewed by ≥2 experts; feedback logged',
        ),
        FaceValidityCheck(
          id: 'pilot',
          titleAr: 'طُبّقت عينة استطلاعية صغيرة ورُوجعت البنود',
          titleEn: 'Small pilot administered and items revised',
        ),
        FaceValidityCheck(
          id: 'ethics',
          titleAr: 'موافقة أخلاقية/مشرف قبل التطبيق الميداني',
          titleEn: 'Ethics/supervisor approval before fieldwork',
        ),
      ];
}
