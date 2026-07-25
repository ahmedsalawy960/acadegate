import '../../core/locale/app_translate.dart';

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

  String get label => switch (this) {
        ResearchJourneyStage.choosingTopic =>
          appTr('اختيار موضوع/فكرة', 'Choosing a topic/idea'),
        ResearchJourneyStage.findingSupervisor =>
          appTr('اختر مشرفاً', 'Choose a supervisor'),
        ResearchJourneyStage.methodology =>
          appTr('المنهجية والموافقات', 'Methodology & approvals'),
        ResearchJourneyStage.dataCollection =>
          appTr('جمع البيانات والتحليل', 'Data collection & analysis'),
        ResearchJourneyStage.writing =>
          appTr('كتابة الفصول', 'Writing chapters'),
        ResearchJourneyStage.defense =>
          appTr('التحضير للمناقشة', 'Preparing for defense'),
      };

  String get subtitle => switch (this) {
        ResearchJourneyStage.choosingTopic =>
          appTr('مسار ذكي + سوق أفكار', 'Smart path + ideas marketplace'),
        ResearchJourneyStage.findingSupervisor =>
          appTr(
            'المطابقة الذكية — ملفك + نسبة توافق %',
            'Smart matching — profile + match %',
          ),
        ResearchJourneyStage.methodology =>
          appTr('كاشف المنهجية + أخلاقيات', 'Methodology & ethics tools'),
        ResearchJourneyStage.dataCollection =>
          appTr('مختبرات وتحليل عينات', 'Labs & sample analysis'),
        ResearchJourneyStage.writing =>
          appTr('خدمات كتابة + مساعد ذكي', 'Writing services + AI advisor'),
        ResearchJourneyStage.defense =>
          appTr('محاكي المناقشة', 'Viva simulator'),
      };

  static ResearchJourneyStage? fromId(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final stage in ResearchJourneyStage.values) {
      if (stage.id == raw) return stage;
    }
    return null;
  }
}
