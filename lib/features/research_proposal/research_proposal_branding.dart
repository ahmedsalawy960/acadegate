import '../../core/locale/app_translate.dart';

class ResearchProposalBranding {
  ResearchProposalBranding._();

  static const brand = 0xFF558B2F;

  static String get title =>
      appTr('مسار الخطة البحثية', 'Research proposal path');

  static String get tagline => appTr(
        'ليس ملء نماذج: شخّص أخطاء خطتك، اقترح صياغة أفضل، واجلب دراسات سابقة نقدية، '
        'ثم راجع جاهزيتك قبل العرض على القسم.',
        'Not form-filling: diagnose proposal faults, get better wording, fetch critical prior studies, '
        'then check readiness before the department.',
      );

  static String get integrityNote => appTr(
        'الفقرات من كتالوج موحّد — اختر ما يخص كليتك. الاختصارات اختيارية وليست بديلاً '
        'عن نموذج الدراسات العليا المعتمد. راجع دائماً لائحة القسم قبل التسجيل.',
        'Sections come from one shared catalog — pick what your faculty needs. Shortcuts are optional '
        'and do not replace the official graduate form. Always check department bylaws before registration.',
      );
}
