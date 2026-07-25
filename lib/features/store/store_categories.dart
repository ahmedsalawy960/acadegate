import 'package:flutter/material.dart';

import '../../core/locale/l10n_lookup.dart';

class StoreCategory {
  final String id;
  /// Firestore `category` value — keep stable; do not rename lightly.
  final String title;
  final IconData icon;
  final Color color;
  /// Who this section serves (researchers / faculties / suppliers).
  final String audienceAr;
  final String audienceEn;

  const StoreCategory({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.audienceAr,
    required this.audienceEn,
  });
}

/// أقسام المتجر الأكاديمي — أيقونات لجميع الباحثين والكليات والموردين.
/// يجب أن يطابق حقل `category` في Firebase قيمة [StoreCategory.title].
const List<StoreCategory> storeCategories = [
  StoreCategory(
    id: 'chemicals',
    title: 'كيميائيات وكواشف',
    icon: Icons.science_outlined,
    color: Color(0xFF2E7D32),
    audienceAr: 'علوم · صيدلة · هندسة كيميائية',
    audienceEn: 'Science · Pharmacy · ChemEng',
  ),
  StoreCategory(
    id: 'biology',
    title: 'بيولوجيا وتقنية حيوية',
    icon: Icons.biotech_outlined,
    color: Color(0xFF00897B),
    audienceAr: 'علوم · زراعة · طب بيطري',
    audienceEn: 'Science · Agriculture · Vet',
  ),
  StoreCategory(
    id: 'medical',
    title: 'طبي وصيدلي وسريري',
    icon: Icons.medical_services_outlined,
    color: Color(0xFFC62828),
    audienceAr: 'طب · أسنان · تمريض · علاج طبيعي',
    audienceEn: 'Medicine · Dentistry · Nursing',
  ),
  StoreCategory(
    id: 'engineering',
    title: 'هندسة وإلكترونيات',
    icon: Icons.precision_manufacturing_outlined,
    color: Color(0xFF1565C0),
    audienceAr: 'هندسة · حاسبات · تكنولوجيا',
    audienceEn: 'Engineering · Computing · Tech',
  ),
  StoreCategory(
    id: 'physics_materials',
    title: 'فيزياء ومواد',
    icon: Icons.bolt_outlined,
    color: Color(0xFF5E35B1),
    audienceAr: 'علوم · هندسة مواد · جيولوجيا',
    audienceEn: 'Physics · Materials · Geology',
  ),
  StoreCategory(
    id: 'agriculture',
    title: 'زراعة وبيطري',
    icon: Icons.agriculture_outlined,
    color: Color(0xFF558B2F),
    audienceAr: 'زراعة · بيطري · ثروة سمكية',
    audienceEn: 'Agriculture · Vet · Fisheries',
  ),
  StoreCategory(
    id: 'computing',
    title: 'حوسبة وبرمجيات بحثية',
    icon: Icons.computer_outlined,
    color: Color(0xFF0277BD),
    audienceAr: 'حاسبات · ذكاء اصطناعي · بيانات',
    audienceEn: 'CS · AI · Data science',
  ),
  StoreCategory(
    id: 'consumables',
    title: 'مستهلكات وأدوات مختبر',
    icon: Icons.inventory_2_outlined,
    color: Color(0xFF6D4C41),
    audienceAr: 'جميع المعامل والكليات العملية',
    audienceEn: 'All labs & practical faculties',
  ),
  StoreCategory(
    id: 'instruments',
    title: 'أجهزة وأدوات قياس',
    icon: Icons.devices_other_outlined,
    color: Color(0xFF455A64),
    audienceAr: 'باحثون يحتاجون أجهزة صغيرة / قطع غيار',
    audienceEn: 'Small instruments & spare parts',
  ),
  StoreCategory(
    id: 'safety',
    title: 'سلامة ومعدات وقاية',
    icon: Icons.health_and_safety_outlined,
    color: Color(0xFFE65100),
    audienceAr: 'كل المعامل — موردو PPE',
    audienceEn: 'All labs — PPE suppliers',
  ),
  StoreCategory(
    id: 'field',
    title: 'أدوات ميدانية ومسح',
    icon: Icons.explore_outlined,
    color: Color(0xFF00695C),
    audienceAr: 'جغرافيا · آثار · بيئة · مسح',
    audienceEn: 'Geography · Archaeology · Env',
  ),
  StoreCategory(
    id: 'books',
    title: 'كتب ومراجع علمية',
    icon: Icons.menu_book_outlined,
    color: Color(0xFF4E342E),
    audienceAr: 'جميع الكليات والتخصصات',
    audienceEn: 'All faculties & disciplines',
  ),
  StoreCategory(
    id: 'humanities',
    title: 'إنسانيات وتربية وبحث اجتماعي',
    icon: Icons.psychology_outlined,
    color: Color(0xFF7B1FA2),
    audienceAr: 'آداب · تربية · حقوق · إعلام · خدمة اجتماعية',
    audienceEn: 'Arts · Education · Law · Media',
  ),
  StoreCategory(
    id: 'office',
    title: 'مستلزمات كتابة وتوثيق البحث',
    icon: Icons.edit_note_outlined,
    color: Color(0xFF546E7A),
    audienceAr: 'دفاتر · ملفات · طباعة أطروحات · أرشفة',
    audienceEn: 'Notebooks · binders · thesis print · archive',
  ),
  StoreCategory(
    id: 'general',
    title: 'مستلزمات عامة',
    icon: Icons.storefront_outlined,
    color: Color(0xFF37474F),
    audienceAr: 'ما لا يندرج تحت قسم محدد',
    audienceEn: 'Anything not covered above',
  ),
];

/// Old Firestore category titles → current titles (for legacy products).
const Map<String, String> storeCategoryLegacyAliases = {
  'متجر كيميائي': 'كيميائيات وكواشف',
  'متجر هندسي': 'هندسة وإلكترونيات',
  'متجر طبي': 'طبي وصيدلي وسريري',
  'متجر زراعي': 'زراعة وبيطري',
  'متجر عام': 'مستلزمات عامة',
  'مكتبي وقرطاسية بحثية': 'مستلزمات كتابة وتوثيق البحث',
};

extension StoreCategoryL10n on StoreCategory {
  String get localizedTitle => L10nLookup.storeCategoryTitle(id);

  String audience(bool isArabic) => isArabic ? audienceAr : audienceEn;
}

StoreCategory? storeCategoryById(String id) {
  for (final category in storeCategories) {
    if (category.id == id) return category;
  }
  return null;
}

StoreCategory? storeCategoryByTitle(String title) {
  final normalized = storeCategoryLegacyAliases[title] ?? title;
  for (final category in storeCategories) {
    if (category.title == normalized || category.title == title) {
      return category;
    }
  }
  return null;
}

/// Titles to query in Firestore for a category (includes legacy alias if any).
List<String> storeCategoryQueryTitles(StoreCategory category) {
  final titles = <String>{category.title};
  for (final entry in storeCategoryLegacyAliases.entries) {
    if (entry.value == category.title) titles.add(entry.key);
  }
  return titles.toList();
}
