import '../../core/locale/app_translate.dart';

/// Smart Research Path branding — clearer than "supply chain".
class ResearchPathBranding {
  ResearchPathBranding._();

  static String get title => appTr('مسار البحث', 'Research Path');
  static String get shortTitle => appTr('مسار البحث', 'Research Path');
  static String get tagline => appTr(
        'اكتب هدفك: ماجستير أو دكتوراه في مجال محدد',
        'Write your goal: a master’s or PhD in a specific field',
      );
  static String get description => appTr(
        'مشرفون من شبكة AcadeGate الأكاديمية ومواقع الجامعات، مع خطة ودراسات DOI مؤكدة.',
        'Supervisors from the AcadeGate academic network and university sites, plus a plan and DOI-confirmed studies.',
      );
  static String get buildButton => appTr(
        'ابنِ خطة الماجستير/الدكتوراه',
        'Build the master’s / PhD plan',
      );
  static String get timelineTitle => appTr('مسار الحزمة', 'Bundle timeline');
  static String get aiSectionTitle => appTr(
        'ملاحظات على الخطة',
        'Notes on the plan',
      );
  static String get aiPlanTitle => appTr(
        'خطة البحث المقترحة',
        'Suggested research plan',
      );
}
