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
    return _cities.values.map(canonicalCity).toSet().toList()..sort();
  }

  static const _cityCanon = <String, String>{
    'الفيوم': 'الفيوم',
    'fayoum': 'الفيوم',
    'fayum': 'الفيوم',
    'al fayoum': 'الفيوم',
    'el fayoum': 'الفيوم',
    'القاهرة': 'القاهرة',
    'cairo': 'القاهرة',
    'الإسكندرية': 'الإسكندرية',
    'الاسكندرية': 'الإسكندرية',
    'alexandria': 'الإسكندرية',
    'alex': 'الإسكندرية',
    'أسيوط': 'أسيوط',
    'اسيوط': 'أسيوط',
    'assiut': 'أسيوط',
    'asyut': 'أسيوط',
    'طنطا': 'طنطا',
    'tanta': 'طنطا',
    'المنصورة': 'المنصورة',
    'mansoura': 'المنصورة',
    'المنيا': 'المنيا',
    'minia': 'المنيا',
    'menia': 'المنيا',
    'minya': 'المنيا',
    'شبين الكوم': 'شبين الكوم',
    'شبين القوم': 'شبين الكوم',
    'shebin el kom': 'شبين الكوم',
    'shibin el kom': 'شبين الكوم',
    'shibin el-kom': 'شبين الكوم',
    'قنا': 'قنا',
    'qena': 'قنا',
    'كفر الشيخ': 'كفر الشيخ',
    'kafr elsheikh': 'كفر الشيخ',
    'kafr el sheikh': 'كفر الشيخ',
    'سوهاج': 'سوهاج',
    'sohag': 'سوهاج',
    'أسوان': 'أسوان',
    'اسوان': 'أسوان',
    'aswan': 'أسوان',
    'بني سويف': 'بني سويف',
    'beni suef': 'بني سويف',
    'beni sueif': 'بني سويف',
    'بنها': 'بنها',
    'banha': 'بنها',
    'benha': 'بنها',
    'بورسعيد': 'بورسعيد',
    'port said': 'بورسعيد',
    'دمياط': 'دمياط',
    'damietta': 'دمياط',
    'السويس': 'السويس',
    'suez': 'السويس',
    'الإسماعيلية': 'الإسماعيلية',
    'الاسماعيلية': 'الإسماعيلية',
    'ismailia': 'الإسماعيلية',
    'دمنهور': 'دمنهور',
    'damanhour': 'دمنهور',
    'مطروح': 'مطروح',
    'matrouh': 'مطروح',
    'الأقصر': 'الأقصر',
    'الاقصر': 'الأقصر',
    'luxor': 'الأقصر',
    'الغردقة': 'الغردقة',
    'hurghada': 'الغردقة',
    'الجيزة': 'الجيزة',
    'giza': 'الجيزة',
    '6 أكتوبر': 'الجيزة',
    '6 october': 'الجيزة',
  };

  static const _cityQueryAliases = <String, List<String>>{
    'الفيوم': ['الفيوم', 'Fayoum', 'Fayum', 'Al Fayoum'],
    'القاهرة': ['القاهرة', 'Cairo'],
    'الإسكندرية': ['الإسكندرية', 'الاسكندرية', 'Alexandria', 'Alex'],
    'أسيوط': ['أسيوط', 'اسيوط', 'Assiut', 'Asyut'],
    'طنطا': ['طنطا', 'Tanta'],
    'المنصورة': ['المنصورة', 'Mansoura'],
    'المنيا': ['المنيا', 'Minia', 'Minya', 'Menia'],
    'شبين الكوم': ['شبين الكوم', 'Shibin El Kom', 'Shebin El Kom'],
    'قنا': ['قنا', 'Qena'],
    'كفر الشيخ': ['كفر الشيخ', 'Kafr El Sheikh'],
    'سوهاج': ['سوهاج', 'Sohag'],
    'أسوان': ['أسوان', 'اسوان', 'Aswan'],
    'بني سويف': ['بني سويف', 'Beni Suef'],
    'بنها': ['بنها', 'Benha', 'Banha'],
    'بورسعيد': ['بورسعيد', 'Port Said'],
    'دمياط': ['دمياط', 'Damietta'],
    'السويس': ['السويس', 'Suez'],
    'الإسماعيلية': ['الإسماعيلية', 'Ismailia'],
    'دمنهور': ['دمنهور', 'Damanhour'],
    'مطروح': ['مطروح', 'Matrouh'],
    'الأقصر': ['الأقصر', 'Luxor'],
    'الغردقة': ['الغردقة', 'Hurghada'],
    'الجيزة': ['الجيزة', 'Giza', '6 أكتوبر', '6 October'],
    'الشرقية': ['الشرقية', 'الزقازيق', 'Zagazig'],
  };

  /// الزقازيق عاصمة محافظة الشرقية — نفس منطقة جامعة الزقازيق.
  static String canonicalCity(String city) {
    final t = city.trim();
    if (t.isEmpty) return t;
    final lower = t.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    const sharqia = {
      'الزقازيق',
      'zagazig',
      'el zagazig',
      'sharkia',
      'sharqia',
      'al-sharqia',
      'al sharqia',
      'ash sharqia',
    };
    if (t == 'الشرقية' || sharqia.contains(t) || sharqia.contains(lower)) {
      return 'الشرقية';
    }
    return _cityCanon[t] ?? _cityCanon[lower] ?? t;
  }

  /// Arabic university names for filters.
  static List<String> get browseUniversities {
    final names = _arabic.values.toSet();
    names.add('مجلس المراكز والمعاهد والهيئات البحثية (CRCI)');
    return names.toList()..sort();
  }

  /// Firestore may still store older labels (e.g. الزقازيق) for the same area.
  static List<String> cityQueryValues(String selectedCity) {
    final city = canonicalCity(selectedCity);
    if (city.isEmpty) return const [];
    return _cityQueryAliases[city] ?? [city];
  }

  static bool cityMatches(String labCity, String selectedCity) {
    if (selectedCity.trim().isEmpty) return true;
    return isSameCity(labCity, selectedCity);
  }

  static bool isSameCity(String leftCity, String rightCity) {
    if (leftCity.trim().isEmpty || rightCity.trim().isEmpty) return false;
    final left = canonicalCity(leftCity);
    final right = canonicalCity(rightCity);
    if (left.isEmpty || right.isEmpty) return false;
    if (left == right) return true;
    final leftLower = left.toLowerCase();
    final rightLower = right.toLowerCase();
    return leftLower.contains(rightLower) || rightLower.contains(leftLower);
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
