import '../../core/locale/app_translate.dart';
import 'thesis_progress.dart';
import 'thesis_progress_activity.dart';

class ThesisProgressTemplates {
  ThesisProgressTemplates._();

  static const masterStandard = 'master_standard';
  static const phdStandard = 'phd_standard';
  static const custom = 'custom';

  static List<({String id, String labelAr, String labelEn})> get choices => [
        (
          id: masterStandard,
          labelAr: 'ماجستير — مسار قياسي',
          labelEn: "Master's — standard path",
        ),
        (
          id: phdStandard,
          labelAr: 'دكتوراه — مسار موسّع',
          labelEn: 'PhD — extended path',
        ),
      ];

  static String label(String templateId, bool isEnglish) {
    for (final c in choices) {
      if (c.id == templateId) {
        return isEnglish ? c.labelEn : c.labelAr;
      }
    }
    return isEnglish ? 'Custom plan' : 'خطة مخصصة';
  }

  static List<ThesisProgressItem> build(String templateId) {
    return switch (templateId) {
      phdStandard => _phdItems(),
      masterStandard => _masterItems(),
      _ => _masterItems(),
    };
  }

  static List<ThesisProgressItem> _masterItems() {
    return [
      _auto(
        id: 'profile',
        activity: ThesisActivityId.profileComplete,
        titleAr: 'الملف الأكاديمي',
        titleEn: 'Academic profile',
      ),
      _auto(
        id: 'topic',
        activity: ThesisActivityId.topicIdea,
        titleAr: 'موضوع/فكرة البحث',
        titleEn: 'Research topic/idea',
      ),
      _auto(
        id: 'supervisor',
        activity: ThesisActivityId.supervisorMatch,
        titleAr: 'اختيار المشرف',
        titleEn: 'Choose supervisor',
      ),
      _auto(
        id: 'proposal',
        activity: ThesisActivityId.methodologyEthics,
        titleAr: 'مقترح + المنهجية والموافقات',
        titleEn: 'Proposal + methodology & ethics',
      ),
      _auto(
        id: 'references',
        activity: ThesisActivityId.citationCheck,
        titleAr: 'فحص المراجع',
        titleEn: 'Reference check',
      ),
      _auto(
        id: 'originality',
        activity: ThesisActivityId.originalityCheck,
        titleAr: 'فحص التشابه',
        titleEn: 'Similarity check',
      ),
      _auto(
        id: 'data',
        activity: ThesisActivityId.dataCollection,
        titleAr: 'جمع البيانات / المختبر',
        titleEn: 'Data collection / lab',
      ),
      _auto(
        id: 'ch1',
        activity: ThesisActivityId.chapterWriting,
        titleAr: 'كتابة الفصول',
        titleEn: 'Writing chapters',
        kind: ThesisItemKind.chapter,
      ),
      _auto(
        id: 'publish',
        activity: ThesisActivityId.publishManuscript,
        titleAr: 'مسودة للنشر',
        titleEn: 'Publication draft',
      ),
      _auto(
        id: 'viva',
        activity: ThesisActivityId.vivaPractice,
        titleAr: 'تدريب المناقشة',
        titleEn: 'Viva practice',
      ),
      _manualDeadline(
        id: 'defense',
        activity: ThesisActivityId.defenseDeadline,
        titleAr: 'موعد المناقشة',
        titleEn: 'Defense date',
      ),
    ];
  }

  static List<ThesisProgressItem> _phdItems() {
    return [
      ..._masterItems().take(3),
      ThesisProgressItem(
        id: 'comprehensive',
        title: appTr('امتحان شامل / تأهيل', 'Comprehensive / qualifying exam'),
        kind: ThesisItemKind.approval,
        isCustom: true,
      ),
      ..._masterItems().skip(3),
      ThesisProgressItem(
        id: 'ch_lit',
        title: appTr('فصل المراجعة الأدبية', 'Literature review chapter'),
        kind: ThesisItemKind.chapter,
        isCustom: true,
      ),
    ];
  }

  static ThesisProgressItem _auto({
    required String id,
    required ThesisActivityId activity,
    required String titleAr,
    required String titleEn,
    ThesisItemKind kind = ThesisItemKind.approval,
  }) {
    return ThesisProgressItem(
      id: id,
      title: appTr(titleAr, titleEn),
      kind: kind,
      activityId: activity.name,
      autoTracked: true,
    );
  }

  static ThesisProgressItem _manualDeadline({
    required String id,
    required ThesisActivityId activity,
    required String titleAr,
    required String titleEn,
  }) {
    return ThesisProgressItem(
      id: id,
      title: appTr(titleAr, titleEn),
      kind: ThesisItemKind.deadline,
      activityId: activity.name,
      autoTracked: false,
    );
  }

  static List<ThesisProgressItem> mergeSavedState({
    required List<ThesisProgressItem> template,
    required List<ThesisProgressItem> saved,
    required List<ThesisProgressItem> customOnly,
  }) {
    final savedById = {for (final i in saved) i.id: i};
    final merged = template.map((item) {
      final prev = savedById[item.id];
      if (prev == null) return item;
      return item.copyWith(
        done: prev.done,
        dueDate: prev.dueDate,
        autoTracked: prev.autoTracked && prev.done,
      );
    }).toList();
    return [...merged, ...customOnly];
  }

  static List<ThesisProgressItem> customItemsFrom(List<ThesisProgressItem> all) {
    return all.where((i) => i.isCustom).toList();
  }
}
