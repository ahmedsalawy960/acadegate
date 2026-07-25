import 'package:flutter/material.dart';

import '../../core/locale/app_translate.dart';
import '../../core/locale/l10n_lookup.dart';

extension WritingCategoryL10n on WritingCategory {
  String get localizedTitle => L10nLookup.writingTitle(id);
  String get localizedSubtitle => L10nLookup.writingSubtitle(id);
}

class WritingCategory {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String imageUrl;

  const WritingCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.imageUrl,
  });
}

/// أقسام خدمات الكتابة — يجب أن يطابق حقل `category` في Firebase.
const List<WritingCategory> writingCategories = [
  WritingCategory(
    id: 'research_paper',
    title: 'أوراق بحثية',
    subtitle: 'مقالات، أوراق مؤتمرات، نشر علمي',
    icon: Icons.article_outlined,
    color: Color(0xFF1565C0),
    imageUrl:
        'https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?auto=format&fit=crop&w=600&h=360&q=80',
  ),
  WritingCategory(
    id: 'thesis',
    title: 'رسائل علمية',
    subtitle: 'ماجستير، دكتوراه، مشروع تخرج',
    icon: Icons.menu_book_outlined,
    color: Color(0xFF6A1B9A),
    imageUrl:
        'https://images.unsplash.com/photo-1524995997942-a1c2e315a42f?auto=format&fit=crop&w=600&h=360&q=80',
  ),
  WritingCategory(
    id: 'statistics',
    title: 'إحصاء وتحليل',
    subtitle: 'SPSS، R، Excel، تفسير النتائج',
    icon: Icons.bar_chart_rounded,
    color: Color(0xFF00838F),
    imageUrl:
        'https://images.unsplash.com/photo-1551288049-bebda4e38f71?auto=format&fit=crop&w=600&h=360&q=80',
  ),
  WritingCategory(
    id: 'literature_review',
    title: 'مراجعة أدبيات',
    subtitle: 'نقد، تلخيص، خريطة مفاهيمية',
    icon: Icons.library_books_outlined,
    color: Color(0xFFEF6C00),
    imageUrl:
        'https://images.unsplash.com/photo-1481627834876-b7833e8f5570?auto=format&fit=crop&w=600&h=360&q=80',
  ),
  WritingCategory(
    id: 'proposal',
    title: 'مقترحات بحث',
    subtitle: 'خطة بحث، أهداف، منهجية',
    icon: Icons.lightbulb_outline,
    color: Color(0xFF558B2F),
    imageUrl:
        'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?auto=format&fit=crop&w=600&h=360&q=80',
  ),
  WritingCategory(
    id: 'editing',
    title: 'تحرير وتدقيق',
    subtitle: 'لغة، أسلوب، إعادة صياغة',
    icon: Icons.spellcheck_outlined,
    color: Color(0xFFAD1457),
    imageUrl:
        'https://images.unsplash.com/photo-1455397842260-daaac442a9d0?auto=format&fit=crop&w=600&h=360&q=80',
  ),
  WritingCategory(
    id: 'formatting',
    title: 'تنسيق وتوثيق',
    subtitle: 'APA، MLA، Harvard، IEEE',
    icon: Icons.format_align_right,
    color: Color(0xFF4527A0),
    imageUrl:
        'https://images.unsplash.com/photo-1507842217343-583bb7270b66?auto=format&fit=crop&w=600&h=360&q=80',
  ),
  WritingCategory(
    id: 'translation',
    title: 'ترجمة علمية',
    subtitle: 'عربي ↔ إنجليزي، مصطلحات دقيقة',
    icon: Icons.translate,
    color: Color(0xFF283593),
    imageUrl:
        'https://images.unsplash.com/photo-1526628953301-3e589a6a8b74?auto=format&fit=crop&w=600&h=360&q=80',
  ),
];

WritingCategory? writingCategoryById(String id) {
  for (final category in writingCategories) {
    if (category.id == id) return category;
  }
  return null;
}

WritingCategory? writingCategoryByTitle(String title) {
  for (final category in writingCategories) {
    if (category.title == title) return category;
  }
  return null;
}

/// مستوى أكاديمي للطلب.
const List<String> academicLevels = [
  'مشروع تخرج (بكالوريوس)',
  'ماجستير',
  'دكتوراه',
  'ورقة مؤتمر',
  'ورقة مجلة (Q1–Q4)',
  'تقرير أكاديمي',
];

/// أنماط التوثيق.
const List<String> citationStyles = [
  'APA (7th)',
  'MLA',
  'Harvard',
  'Chicago',
  'IEEE',
  'Vancouver',
  'ISO 690',
  'حسب دليل الجامعة',
];

/// لغة الكتابة.
const List<String> writingLanguages = [
  'العربية',
  'الإنجليزية',
  'ثنائي اللغة (عربي + إنجليزي)',
];

/// مستوى الاستعجال.
const List<String> urgencyLevels = [
  'عادي (7–14 يوم)',
  'مستعجل (3–6 أيام)',
  'فائق (24–48 ساعة)',
];

/// برامج الإحصاء.
const List<String> statisticsTools = [
  'SPSS',
  'R / RStudio',
  'Excel',
  'STATA',
  'AMOS',
  'SmartPLS',
  'Python (pandas)',
  'لا ينطبق',
];

/// خدمات إضافية للباحث.
const List<String> writingAddons = [
  'تقرير أصالة (Plagiarism)',
  'ملخص تنفيذي',
  'عروض PowerPoint',
  'ملحق جداول ورسوم',
  'جلسة شرح النتائج',
  'مراجع إضافية',
  'تعديل بعد المناقشة',
];

/// مراحل باقة الرسالة (دفع/تسليم مرحلي).
const List<String> thesisMilestones = [
  'المقدمة والإطار النظري',
  'مراجعة الأدبيات',
  'المنهجية',
  'النتائج والتحليل',
  'المناقشة والخاتمة',
];

String localizedThesisMilestone(String value) {
  switch (value) {
    case 'المقدمة والإطار النظري':
      return appTr(value, 'Introduction & theoretical framework');
    case 'مراجعة الأدبيات':
      return appTr(value, 'Literature review');
    case 'المنهجية':
      return appTr(value, 'Methodology');
    case 'النتائج والتحليل':
      return appTr(value, 'Results & analysis');
    case 'المناقشة والخاتمة':
      return appTr(value, 'Discussion & conclusion');
    default:
      return value;
  }
}

String localizedAcademicLevel(String value) {
  switch (value) {
    case 'مشروع تخرج (بكالوريوس)':
      return appTr(value, 'Undergraduate project');
    case 'ماجستير':
      return appTr(value, "Master's");
    case 'دكتوراه':
      return appTr(value, 'PhD');
    case 'ورقة مؤتمر':
      return appTr(value, 'Conference paper');
    case 'ورقة مجلة (Q1–Q4)':
      return appTr(value, 'Journal paper (Q1–Q4)');
    case 'تقرير أكاديمي':
      return appTr(value, 'Academic report');
    default:
      return value;
  }
}

String localizedCitationStyle(String value) {
  if (value == 'حسب دليل الجامعة') {
    return appTr(value, 'Per university guide');
  }
  return value;
}

String localizedWritingLanguage(String value) {
  switch (value) {
    case 'العربية':
      return appTr(value, 'Arabic');
    case 'الإنجليزية':
      return appTr(value, 'English');
    case 'ثنائي اللغة (عربي + إنجليزي)':
      return appTr(value, 'Bilingual (Arabic + English)');
    default:
      return value;
  }
}

String localizedUrgencyLevel(String value) {
  switch (value) {
    case 'عادي (7–14 يوم)':
      return appTr(value, 'Standard (7–14 days)');
    case 'مستعجل (3–6 أيام)':
      return appTr(value, 'Urgent (3–6 days)');
    case 'فائق (24–48 ساعة)':
      return appTr(value, 'Express (24–48 hours)');
    default:
      return value;
  }
}

String localizedStatisticsTool(String value) {
  if (value == 'لا ينطبق') {
    return appTr(value, 'Not applicable');
  }
  return value;
}

String localizedWritingAddon(String value) {
  switch (value) {
    case 'تقرير أصالة (Plagiarism)':
      return appTr(value, 'Plagiarism report');
    case 'ملخص تنفيذي':
      return appTr(value, 'Executive summary');
    case 'عروض PowerPoint':
      return appTr(value, 'PowerPoint slides');
    case 'ملحق جداول ورسوم':
      return appTr(value, 'Tables & figures appendix');
    case 'جلسة شرح النتائج':
      return appTr(value, 'Results walkthrough session');
    case 'مراجع إضافية':
      return appTr(value, 'Extra references');
    case 'تعديل بعد المناقشة':
      return appTr(value, 'Post-defense revisions');
    default:
      return value;
  }
}
