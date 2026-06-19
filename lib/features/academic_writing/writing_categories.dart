import 'package:flutter/material.dart';

class WritingCategory {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const WritingCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
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
  ),
  WritingCategory(
    id: 'thesis',
    title: 'رسائل علمية',
    subtitle: 'ماجستير، دكتوراه، مشروع تخرج',
    icon: Icons.menu_book_outlined,
    color: Color(0xFF6A1B9A),
  ),
  WritingCategory(
    id: 'statistics',
    title: 'إحصاء وتحليل',
    subtitle: 'SPSS، R، Excel، تفسير النتائج',
    icon: Icons.bar_chart_rounded,
    color: Color(0xFF00838F),
  ),
  WritingCategory(
    id: 'literature_review',
    title: 'مراجعة أدبيات',
    subtitle: 'نقد، تلخيص، خريطة مفاهيمية',
    icon: Icons.library_books_outlined,
    color: Color(0xFFEF6C00),
  ),
  WritingCategory(
    id: 'proposal',
    title: 'مقترحات بحث',
    subtitle: 'خطة بحث، أهداف، منهجية',
    icon: Icons.lightbulb_outline,
    color: Color(0xFF558B2F),
  ),
  WritingCategory(
    id: 'editing',
    title: 'تحرير وتدقيق',
    subtitle: 'لغة، أسلوب، إعادة صياغة',
    icon: Icons.spellcheck_outlined,
    color: Color(0xFFAD1457),
  ),
  WritingCategory(
    id: 'formatting',
    title: 'تنسيق وتوثيق',
    subtitle: 'APA، MLA، Harvard، IEEE',
    icon: Icons.format_align_right,
    color: Color(0xFF4527A0),
  ),
  WritingCategory(
    id: 'translation',
    title: 'ترجمة علمية',
    subtitle: 'عربي ↔ إنجليزي، مصطلحات دقيقة',
    icon: Icons.translate,
    color: Color(0xFF283593),
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
