/// City / Arabic name helpers for NBSLE English university labels.
class NbsleUniversityCities {
  NbsleUniversityCities._();

  static const _cities = <String, String>{
    'cairo university': 'القاهرة',
    'ain shams university': 'القاهرة',
    'helwan university': 'القاهرة',
    'al-azhar university': 'القاهرة',
    'capital university': 'القاهرة',
    'alexandria university': 'الإسكندرية',
    'assiut university': 'أسيوط',
    'tanta univeristy': 'طنطا',
    'tanta university': 'طنطا',
    'mansoura university': 'المنصورة',
    'new mansoura university': 'المنصورة',
    'zagazig university': 'الشرقية',
    'menia university': 'المنيا',
    'minia university': 'المنيا',
    'menofia university': 'شبين الكوم',
    'suez canal university': 'الإسماعيلية',
    'qena university': 'قنا',
    'south valley university': 'قنا',
    'beni swief university': 'بني سويف',
    'beni suef university': 'بني سويف',
    'nahda university in beni suef': 'بني سويف',
    'fayoum university': 'الفيوم',
    'benha university': 'بنها',
    'kafr elshiekh university': 'كفر الشيخ',
    'sohag university': 'سوهاج',
    'port said university': 'بورسعيد',
    'east port said university of technology': 'بورسعيد',
    'damanhour university': 'دمنهور',
    'aswan university': 'أسوان',
    'damietta university': 'دمياط',
    'suez university': 'السويس',
    'university of sadat city': 'مدينة السادات',
    'matrouh university': 'مطروح',
    'arish university': 'العريش',
    'new valley university': 'الوادي الجديد',
    'luxor university': 'الأقصر',
    'hurghada university': 'الغردقة',
    'e-just': 'الإسكندرية',
    'deraya university': 'المنيا',
  };

  static const _arabic = <String, String>{
    'cairo university': 'جامعة القاهرة',
    'ain shams university': 'جامعة عين شمس',
    'alexandria university': 'جامعة الإسكندرية',
    'assiut university': 'جامعة أسيوط',
    'tanta univeristy': 'جامعة طنطا',
    'tanta university': 'جامعة طنطا',
    'mansoura university': 'جامعة المنصورة',
    'new mansoura university': 'جامعة المنصورة الجديدة',
    'zagazig university': 'جامعة الزقازيق',
    'menia university': 'جامعة المنيا',
    'menofia university': 'جامعة المنوفية',
    'suez canal university': 'جامعة قناة السويس',
    'qena university': 'جامعة جنوب الوادي',
    'beni swief university': 'جامعة بني سويف',
    'fayoum university': 'جامعة الفيوم',
    'benha university': 'جامعة بنها',
    'kafr elshiekh university': 'جامعة كفر الشيخ',
    'sohag university': 'جامعة سوهاج',
    'port said university': 'جامعة بورسعيد',
    'damanhour university': 'جامعة دمنهور',
    'aswan university': 'جامعة أسوان',
    'damietta university': 'جامعة دمياط',
    'suez university': 'جامعة السويس',
    'university of sadat city': 'جامعة مدينة السادات',
    'matrouh university': 'جامعة مطروح',
    'arish university': 'جامعة العريش',
    'new valley university': 'جامعة الوادي الجديد',
    'luxor university': 'جامعة الأقصر',
    'hurghada university': 'جامعة الغردقة',
    'al-azhar university': 'جامعة الأزهر',
    'e-just': 'الجامعة المصرية اليابانية للعلوم والتكنولوجيا',
    'nahda university in beni suef': 'جامعة النهضة',
    'deraya university': 'جامعة دراية',
    'east port said university of technology':
        'جامعة شرق بورسعيد التكنولوجية',
    'capital university': 'جامعة العاصمة',
  };

  /// Cities shown in equipment booking filters (governorate-style labels).
  static List<String> get browseCities {
    final cities = _cities.values.toSet();
    // Legacy Firestore label for Zagazig University labs.
    cities.add('الزقازيق');
    return cities.toList()..sort();
  }

  /// Arabic university names for filters.
  static List<String> get browseUniversities {
    final names = _arabic.values.toSet();
    names.add('مجلس المراكز والمعاهد والهيئات البحثية (CRCI)');
    return names.toList()..sort();
  }

  /// Firestore may still store older labels (e.g. الزقازيق) for the same area.
  static List<String> cityQueryValues(String selectedCity) {
    final city = selectedCity.trim();
    if (city.isEmpty) return const [];
    const aliases = <String, List<String>>{
      'الشرقية': ['الشرقية', 'الزقازيق'],
      'الزقازيق': ['الزقازيق', 'الشرقية'],
    };
    return aliases[city] ?? [city];
  }

  static bool cityMatches(String labCity, String selectedCity) {
    if (selectedCity.trim().isEmpty) return true;
    final values = cityQueryValues(selectedCity);
    return values.contains(labCity.trim());
  }

  static bool universityMatches(String labUniversity, String selectedUniversity) {
    final selected = selectedUniversity.trim();
    if (selected.isEmpty) return true;
    final lab = labUniversity.trim();
    if (lab.isEmpty) return false;
    if (lab == selected) return true;
    final labLower = lab.toLowerCase();
    final selLower = selected.toLowerCase();
    return labLower.contains(selLower) || selLower.contains(labLower);
  }

  static String cityFor(String universityEn) {
    final key = universityEn.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (_cities.containsKey(key)) return _cities[key]!;
    for (final entry in _cities.entries) {
      if (key.contains(entry.key) || entry.key.contains(key)) {
        return entry.value;
      }
    }
    return '';
  }

  static String arabicName(String universityEn) {
    final key = universityEn.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (_arabic.containsKey(key)) return _arabic[key]!;
    for (final entry in _arabic.entries) {
      if (key.contains(entry.key) || entry.key.contains(key)) {
        return entry.value;
      }
    }
    return universityEn.trim();
  }
}
