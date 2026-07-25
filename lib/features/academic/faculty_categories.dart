import 'package:flutter/material.dart';

import '../../core/locale/l10n_lookup.dart';

class FacultyCategory {
  final String id;
  final String titleAr;
  final IconData icon;
  final Color color;

  const FacultyCategory({
    required this.id,
    required this.titleAr,
    required this.icon,
    required this.color,
  });
}

const facultyCategories = <FacultyCategory>[
  FacultyCategory(
    id: 'Engineering',
    titleAr: 'كلية الهندسة',
    icon: Icons.engineering,
    color: Colors.orange,
  ),
  FacultyCategory(
    id: 'Science',
    titleAr: 'كلية العلوم',
    icon: Icons.science,
    color: Colors.green,
  ),
  FacultyCategory(
    id: 'Medicine',
    titleAr: 'كلية الطب',
    icon: Icons.medical_services,
    color: Colors.red,
  ),
  FacultyCategory(
    id: 'Dentistry',
    titleAr: 'كلية طب الأسنان',
    icon: Icons.medication_liquid,
    color: Color(0xFF00838F),
  ),
  FacultyCategory(
    id: 'Pharmacy',
    titleAr: 'كلية الصيدلة',
    icon: Icons.local_pharmacy,
    color: Color(0xFF6A1B9A),
  ),
  FacultyCategory(
    id: 'Nursing',
    titleAr: 'كلية التمريض',
    icon: Icons.health_and_safety,
    color: Color(0xFFC2185B),
  ),
  FacultyCategory(
    id: 'Veterinary',
    titleAr: 'كلية الطب البيطري',
    icon: Icons.pets,
    color: Color(0xFF558B2F),
  ),
  FacultyCategory(
    id: 'Law',
    titleAr: 'كلية الحقوق',
    icon: Icons.gavel,
    color: Colors.brown,
  ),
  FacultyCategory(
    id: 'CS',
    titleAr: 'كلية الحاسبات',
    icon: Icons.computer,
    color: Colors.blue,
  ),
  FacultyCategory(
    id: 'Agriculture',
    titleAr: 'كلية الزراعة',
    icon: Icons.agriculture,
    color: Color(0xFF33691E),
  ),
  FacultyCategory(
    id: 'Business',
    titleAr: 'كلية التجارة',
    icon: Icons.business_center,
    color: Color(0xFF4527A0),
  ),
  FacultyCategory(
    id: 'Education',
    titleAr: 'كلية التربية',
    icon: Icons.school,
    color: Color(0xFF1565C0),
  ),
  FacultyCategory(
    id: 'Arts',
    titleAr: 'كلية الآداب',
    icon: Icons.menu_book,
    color: Color(0xFF795548),
  ),
  FacultyCategory(
    id: 'Architecture',
    titleAr: 'كلية العمارة',
    icon: Icons.account_balance,
    color: Color(0xFF37474F),
  ),
  FacultyCategory(
    id: 'MassCommunication',
    titleAr: 'كلية الإعلام',
    icon: Icons.campaign,
    color: Color(0xFFEF6C00),
  ),
  FacultyCategory(
    id: 'Tourism',
    titleAr: 'كلية السياحة والفنادق',
    icon: Icons.travel_explore,
    color: Color(0xFF00796B),
  ),
  FacultyCategory(
    id: 'PhysicalEducation',
    titleAr: 'كلية التربية الرياضية',
    icon: Icons.sports_soccer,
    color: Color(0xFF2E7D32),
  ),
  FacultyCategory(
    id: 'FineArts',
    titleAr: 'كلية الفنون الجميلة',
    icon: Icons.palette,
    color: Color(0xFFAD1457),
  ),
];

FacultyCategory? facultyById(String id) {
  for (final faculty in facultyCategories) {
    if (faculty.id == id) return faculty;
  }
  return null;
}

String facultyTitleForCategory(String id) {
  return L10nLookup.facultyTitleStatic(id);
}

String supervisorsTitleForCategory(String id) {
  return L10nLookup.supervisorsTitleForCategory(id);
}

List<String> facultyCategoryIds() =>
    facultyCategories.map((f) => f.id).toList();

/// يربط اسم أو معرّف الكلية بمعرّف موحّد (Science, Medicine...).
String? resolveFacultyId(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  for (final faculty in facultyCategories) {
    if (faculty.id.toLowerCase() == trimmed.toLowerCase()) {
      return faculty.id;
    }
    if (faculty.titleAr == trimmed) return faculty.id;
  }

  final lower = trimmed.toLowerCase();
  for (final faculty in facultyCategories) {
    final title = faculty.titleAr.toLowerCase();
    final shortTitle = title.replaceAll('كلية ', '').trim();
    if (title.contains(lower) || lower.contains(title)) return faculty.id;
    if (shortTitle.isNotEmpty &&
        (lower.contains(shortTitle) || shortTitle.contains(lower))) {
      return faculty.id;
    }
  }

  return null;
}

String facultyNameForStorage(String facultyId) {
  return facultyTitleForCategory(facultyId);
}

/// يستنتج معرّف الكلية من نص التخصص أو الاهتمام (مثل: كيمياء → Science).
String? inferFacultyCategoryFromText(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;

  final resolved = resolveFacultyId(trimmed);
  if (resolved != null) return resolved;

  final lower = trimmed.toLowerCase();
  const hints = <String, List<String>>{
    'Science': [
      'كيمياء',
      'chemistry',
      'chem',
      'فيزياء',
      'physics',
      'أحياء',
      'biology',
      'biol',
      'رياضيات',
      'math',
      'علوم',
      'biochem',
      'كيمياء حيوية',
      'جيولوج',
      'geolog',
    ],
    'Engineering': [
      'هندسة',
      'engineering',
      'مدني',
      'civil',
      'ميكانيك',
      'mechan',
      'كهرب',
      'electr',
      'معماري',
      'architect',
    ],
    'Medicine': ['طب', 'medicine', 'medical', 'سريري', 'clinical'],
    'Dentistry': ['أسنان', 'dentist', 'dental'],
    'Pharmacy': ['صيدلة', 'pharmacy', 'pharm'],
    'Nursing': ['تمريض', 'nursing'],
    'Veterinary': ['بيطر', 'veterinar'],
    'Law': ['قانون', 'law', 'legal'],
    'CS': [
      'حاسب',
      'computer',
      'برمج',
      'program',
      'ذكاء اصطناعي',
      'artificial intelligence',
      'ai',
      'data science',
    ],
    'Agriculture': ['زراع', 'agricult', 'food science', 'nutrition', 'food'],
    'Business': ['تجار', 'business', 'إدارة أعمال', 'accounting', 'محاسب'],
    'Education': ['تربية', 'education', 'تعليم'],
    'Arts': ['آداب', 'أدب', 'literature', 'تاريخ', 'history'],
    'Architecture': ['عمارة', 'architecture'],
    'MassCommunication': ['إعلام', 'media', 'journalism'],
    'Tourism': ['سياح', 'tourism', 'فنادق', 'hospitality'],
    'PhysicalEducation': ['رياضة', 'sport', 'physical educ'],
    'FineArts': ['فنون', 'fine art', 'تصميم', 'design'],
  };

  for (final entry in hints.entries) {
    for (final hint in entry.value) {
      if (lower.contains(hint)) return entry.key;
    }
  }

  return null;
}
