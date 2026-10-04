import '../../core/locale/app_translate.dart';
import '../humanities/humanities_faculties.dart';

enum ResearchJourneyStage {
  choosingTopic,
  findingSupervisor,
  methodology,
  dataCollection,
  writing,
  defense,
}

extension ResearchJourneyStageX on ResearchJourneyStage {
  String get id => name;

  /// النص الافتراضي (محايد / علمي).
  String get label => labelFor(fieldMode: false);

  String get subtitle => subtitleFor(fieldMode: false);

  /// [fieldMode] = true للكليات الأدبية/التربوية: بلا لغة معامل أو عينات.
  String labelFor({required bool fieldMode}) => switch (this) {
        ResearchJourneyStage.choosingTopic =>
          appTr('اختيار موضوع/فكرة', 'Choosing a topic/idea'),
        ResearchJourneyStage.findingSupervisor =>
          appTr('اختر مشرفاً', 'Choose a supervisor'),
        ResearchJourneyStage.methodology =>
          appTr('المنهجية والموافقات', 'Methodology & approvals'),
        ResearchJourneyStage.dataCollection => fieldMode
            ? appTr(
                'جمع البيانات الميدانية',
                'Field data collection',
              )
            : appTr(
                'جمع البيانات (ميدان أو مختبر)',
                'Data collection (field or lab)',
              ),
        ResearchJourneyStage.writing =>
          appTr('كتابة الفصول', 'Writing chapters'),
        ResearchJourneyStage.defense =>
          appTr('التحضير للمناقشة', 'Preparing for defense'),
      };

  String subtitleFor({required bool fieldMode}) => switch (this) {
        ResearchJourneyStage.choosingTopic =>
          appTr('مسار ذكي + سوق أفكار', 'Smart path + ideas marketplace'),
        ResearchJourneyStage.findingSupervisor =>
          appTr(
            'المطابقة الذكية — ملفك + نسبة توافق %',
            'Smart matching — profile + match %',
          ),
        ResearchJourneyStage.methodology => fieldMode
            ? appTr(
                'خطة بحث · تحكيم أداة · أخلاقيات',
                'Proposal · instrument check · ethics',
              )
            : appTr('كاشف المنهجية + أخلاقيات', 'Methodology & ethics tools'),
        ResearchJourneyStage.dataCollection => fieldMode
            ? appTr(
                'استبانة · مقابلات · أرشيف ونصوص — بلا عينات معملية',
                'Survey · interviews · archive & texts — no lab samples',
              )
            : appTr(
                'استبانة · مقابلات · أرشيف — أو مختبرات',
                'Survey · interviews · archive — or labs',
              ),
        ResearchJourneyStage.writing =>
          appTr('خدمات كتابة + المساعد الأكاديمي', 'Writing services + Academic Assistant'),
        ResearchJourneyStage.defense =>
          appTr('محاكي المناقشة', 'Viva simulator'),
      };

  static bool fieldModeForFaculty(String? facultyId) =>
      HumanitiesFaculties.isHumanities(facultyId);

  static ResearchJourneyStage? fromId(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final stage in ResearchJourneyStage.values) {
      if (stage.id == raw) return stage;
    }
    return null;
  }
}
