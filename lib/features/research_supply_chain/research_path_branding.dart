import '../../core/locale/app_translate.dart';

/// Smart Research Path branding — clearer than "supply chain".
class ResearchPathBranding {
  ResearchPathBranding._();

  static String get title => appTr('مسار البحث الذكي', 'Smart Research Path');
  static String get shortTitle => appTr('مسار البحث الذكي', 'Smart Research Path');
  static String get tagline => appTr(
        'حزمة بحثية واحدة مدعومة بالذكاء الاصطناعي',
        'One AI-powered research bundle',
      );
  static String get description => appTr(
        'فكرة → مشرف → مختبر → متجر → كتابة\n'
        'نربط ما تحتاجه لبحثك من بيانات المنصة ونشرح لك الخطة بالذكاء الاصطناعي.',
        'Idea → supervisor → lab → store → writing\n'
        'We connect what you need for your research from platform data and explain the plan with AI.',
      );
  static String get buildButton => appTr(
        'ابنِ حزمة البحث بالذكاء الاصطناعي',
        'Build research bundle with AI',
      );
  static String get timelineTitle => appTr('مسار الحزمة', 'Bundle timeline');
  static String get aiSectionTitle => appTr(
        'تحليل الذكاء الاصطناعي',
        'AI analysis',
      );
  static String get aiPlanTitle => appTr(
        'خطة البحث المقترحة',
        'Suggested research plan',
      );
}
