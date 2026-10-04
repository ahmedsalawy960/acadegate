import 'dart:convert';

import 'humanities_journal_catalog.dart';

class HumanitiesPublishDraft {
  String facultyId;
  String outletId;
  String articleTitleAr;
  String articleTitleEn;
  String authorName;
  String affiliation;
  String abstractAr;
  String notesForEditor;
  String letterType; // submission | acceptance_ack | promotion_note
  DateTime updatedAt;

  HumanitiesPublishDraft({
    this.facultyId = 'Education',
    this.outletId = '',
    this.articleTitleAr = '',
    this.articleTitleEn = '',
    this.authorName = '',
    this.affiliation = '',
    this.abstractAr = '',
    this.notesForEditor = '',
    this.letterType = 'submission',
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  HumanitiesPublishOutlet? get outlet =>
      outletId.isEmpty ? null : humanitiesOutletById(outletId);

  Map<String, dynamic> toJson() => {
        'facultyId': facultyId,
        'outletId': outletId,
        'articleTitleAr': articleTitleAr,
        'articleTitleEn': articleTitleEn,
        'authorName': authorName,
        'affiliation': affiliation,
        'abstractAr': abstractAr,
        'notesForEditor': notesForEditor,
        'letterType': letterType,
        'updatedAt': updatedAt.toIso8601String(),
      };

  String encode() => jsonEncode(toJson());

  static HumanitiesPublishDraft? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return HumanitiesPublishDraft(
        facultyId: map['facultyId']?.toString() ?? 'Education',
        outletId: map['outletId']?.toString() ?? '',
        articleTitleAr: map['articleTitleAr']?.toString() ?? '',
        articleTitleEn: map['articleTitleEn']?.toString() ?? '',
        authorName: map['authorName']?.toString() ?? '',
        affiliation: map['affiliation']?.toString() ?? '',
        abstractAr: map['abstractAr']?.toString() ?? '',
        notesForEditor: map['notesForEditor']?.toString() ?? '',
        letterType: map['letterType']?.toString() ?? 'submission',
        updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? '') ??
            DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// يولّد خطاب تقديم / إقرار قبول / مذكرة ترقية قابلة للنسخ.
abstract class HumanitiesPublishLetterBuilder {
  static String build(HumanitiesPublishDraft draft) {
    final outlet = draft.outlet;
    final journal = outlet?.nameAr ?? 'المجلة / الحولية المختارة';
    final title = draft.articleTitleAr.trim().isNotEmpty
        ? draft.articleTitleAr.trim()
        : 'عنوان البحث';
    final author = draft.authorName.trim().isNotEmpty
        ? draft.authorName.trim()
        : 'اسم الباحث';
    final aff = draft.affiliation.trim().isNotEmpty
        ? draft.affiliation.trim()
        : 'الكلية / الجامعة';

    switch (draft.letterType) {
      case 'acceptance_ack':
        return '''
السادة هيئة تحرير «$journal»
تحية طيبة وبعد،

أتشرّف بالإفادة بأنني استلمت إشعار قبول بحثي المعنون:
«$title»
للنشر في مجلتكم المحكّمة، وأتعهد بالالتزام بأي تعديلات نهائية تطلبها الهيئة،
وبعدم نشر البحث في منفذ آخر حتى صدوره.

وتفضلوا بقبول فائق الاحترام.
$author
$aff
''';
      case 'promotion_note':
        return '''
مذكرة مرفقات ملف الترقية / اللجنة العلمية

عنوان البحث: $title
المنفذ: $journal
نوع المنفذ: ${outlet?.kindLabelAr() ?? 'مجلة/حولية محكمة'}
المؤلف: $author
الجهة: $aff

المرفقات المقترحة:
1) خطاب قبول النشر (النسخة الرسمية من المجلة)
2) نسخة المخطوطة النهائية / مستلة العدد إن صدر
3) ما يفيد فهرسة/تحكيم المنفذ إن طُلب (مثل ظهور في دار المنظومة)
4) إقرار عدم النشر المزدوج

تنبيه: طابق المنفذ مع قائمة التخصص المعتمدة لدى لجنتك قبل الاعتماد.
''';
      case 'submission':
      default:
        final notes = draft.notesForEditor.trim();
        final abs = draft.abstractAr.trim();
        return '''
السادة رئيس / هيئة تحرير «$journal»
تحية طيبة وبعد،

أتقدم إليكم ببحثي المعنون:
«$title»
${draft.articleTitleEn.trim().isNotEmpty ? 'Title: ${draft.articleTitleEn.trim()}\n' : ''}
للنظر في إمكانية نشره في مجلتكم المحكّمة، وهو عمل أصيل لم يُنشر من قبل ولم يُقدَّم حالياً إلى مجلة أخرى.

الباحث: $author
الجهة: $aff
${abs.isNotEmpty ? '\nملخص موجز:\n$abs\n' : ''}
${notes.isNotEmpty ? '\nملاحظات للتحرير:\n$notes\n' : ''}
${outlet != null ? 'أتعهد بالالتزام بشرط التوثيق (${outlet.citationLabelAr()}) ومتطلبات دليل المؤلفين.\n' : ''}
وتفضلوا بقبول فائق الاحترام والتقدير.
$author
''';
    }
  }
}
