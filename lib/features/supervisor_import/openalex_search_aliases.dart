/// ترجمة أسماء الجامعات العربية وتحويل نص البحث العربي لصيغ يفهمها OpenAlex.
class OpenAlexSearchAliases {
  OpenAlexSearchAliases._();

  static final RegExp _arabicScript = RegExp(r'[\u0600-\u06FF]');

  static bool containsArabic(String text) => _arabicScript.hasMatch(text);

  static List<String> institutionQueries(String query) {
    final trimmed = query.trim();
    if (trimmed.length < 2) return [];

    final queries = <String>{trimmed};
    final normalized = _normalizeArabic(trimmed);

    for (final entry in _egyptianUniversities) {
      final key = _normalizeArabic(entry.arabic);
      if (normalized.contains(key) ||
          key.contains(normalized) ||
          _tokensOverlap(normalized, key)) {
        queries.add(entry.english);
      }
    }

    if (containsArabic(trimmed)) {
      final withoutUniversity = normalized
          .replaceAll('جامعة', '')
          .replaceAll('الجامعة', '')
          .trim();
      if (withoutUniversity.isNotEmpty) {
        for (final entry in _egyptianUniversities) {
          final key = _normalizeArabic(entry.arabic)
              .replaceAll('جامعة', '')
              .replaceAll('الجامعة', '')
              .trim();
          if (key.contains(withoutUniversity) ||
              withoutUniversity.contains(key)) {
            queries.add(entry.english);
          }
        }
      }
    }

    return queries.toList();
  }

  static List<String> authorQueries(String query) {
    final trimmed = query.trim();
    if (trimmed.length < 2) return [];

    final queries = <String>{trimmed};

    if (containsArabic(trimmed)) {
      final transliterated = transliterateArabic(trimmed);
      if (transliterated.isNotEmpty) {
        queries.add(transliterated);
        queries.add(_titleCaseWords(transliterated));
      }

      for (final variant in _nameSpellingVariants(trimmed)) {
        queries.add(variant);
      }
    }

    return queries.toList();
  }

  /// يعرض للمستخدم الاسم الإنجليزي المقترح عند البحث بالعربية.
  static String? suggestedInstitutionEnglish(String query) {
    final englishQueries = institutionQueries(query)
        .where((item) => item != query.trim())
        .toList();
    return englishQueries.isEmpty ? null : englishQueries.first;
  }

  static String formatUniversityWithFaculty({
    required String faculty,
    required String institution,
  }) {
    final facultyLabel = faculty.trim();
    final institutionLabel = institution.trim();
    if (facultyLabel.isEmpty) return institutionLabel;
    if (institutionLabel.isEmpty) return facultyLabel;
    return '$facultyLabel — $institutionLabel';
  }

  static String transliterateArabic(String text) {
    final buffer = StringBuffer();
    var previousWasSpace = false;

    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      if (char == ' ' || char == '\u00A0') {
        if (!previousWasSpace) buffer.write(' ');
        previousWasSpace = true;
        continue;
      }
      previousWasSpace = false;

      final mapped = _arabicLetterMap[char];
      if (mapped != null) {
        buffer.write(mapped);
        continue;
      }

      if (RegExp(r'[A-Za-z0-9.\-]').hasMatch(char)) {
        buffer.write(char.toLowerCase());
      }
    }

    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _normalizeArabic(String text) {
    return text
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'[ـ\s]+'), ' ')
        .trim()
        .toLowerCase();
  }

  static bool _tokensOverlap(String a, String b) {
    final aTokens = a.split(' ').where((t) => t.length >= 3).toSet();
    final bTokens = b.split(' ').where((t) => t.length >= 3).toSet();
    return aTokens.intersection(bTokens).isNotEmpty;
  }

  static String _titleCaseWords(String value) {
    return value
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map(
          (part) => part.length == 1
              ? part.toUpperCase()
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  static List<String> _nameSpellingVariants(String arabicName) {
    final normalized = _normalizeArabic(arabicName);
    final variants = <String>{};

    const common = <String, List<String>>{
      'محمد': ['Mohamed', 'Mohammed', 'Muhammad', 'Mohammad'],
      'احمد': ['Ahmed', 'Ahmad'],
      'حسن': ['Hassan', 'Hasan'],
      'حسين': ['Hussein', 'Hussain', 'Husain'],
      'علي': ['Ali'],
      'محمود': ['Mahmoud', 'Mahmud', 'Mahmood'],
      'خالد': ['Khaled', 'Khalid'],
      'يوسف': ['Youssef', 'Yousef', 'Yusuf'],
      'عبد': ['Abd', 'Abdel', 'Abdul'],
      'الله': ['Allah', 'El'],
      'فاطمه': ['Fatma', 'Fatima', 'Fatema'],
      'نور': ['Nour', 'Noor', 'Nur'],
      'سارة': ['Sara', 'Sarah'],
      'كريم': ['Karim', 'Kareem'],
      'طارق': ['Tarek', 'Tariq', 'Tarik'],
      'عادل': ['Adel', 'Adil'],
      'سمير': ['Samir', 'Sameer'],
      'هشام': ['Hesham', 'Hisham'],
      'اشرف': ['Ashraf', 'Achraf'],
      'جمال': ['Gamal', 'Jamal'],
      'رمضان': ['Ramadan', 'Ramadhan'],
      'سعيد': ['Saeed', 'Said', 'Sayed'],
      'مصطفى': ['Mostafa', 'Mustafa', 'Moustafa'],
      'ابراهيم': ['Ibrahim', 'Ebrahim'],
      'عمر': ['Omar', 'Umar'],
      'زينب': ['Zainab', 'Zeinab'],
      'مريم': ['Mariam', 'Maryam', 'Miriam'],
    };

    final tokens = normalized.split(' ');
    if (tokens.length == 1) {
      final single = common[tokens.first];
      if (single != null) variants.addAll(single);
    } else if (tokens.length >= 2) {
      final first = common[tokens.first] ?? const <String>[];
      final last = common[tokens.last] ?? const <String>[];
      if (first.isNotEmpty && last.isNotEmpty) {
        for (final f in first) {
          for (final l in last) {
            variants.add('$f $l');
          }
        }
      } else if (first.isNotEmpty) {
        variants.addAll(first);
      } else if (last.isNotEmpty) {
        variants.addAll(last);
      }
    }

    return variants.toList();
  }

  static const _arabicLetterMap = <String, String>{
    'ا': 'a',
    'أ': 'a',
    'إ': 'i',
    'آ': 'a',
    'ب': 'b',
    'ت': 't',
    'ث': 'th',
    'ج': 'j',
    'ح': 'h',
    'خ': 'kh',
    'د': 'd',
    'ذ': 'th',
    'ر': 'r',
    'ز': 'z',
    'س': 's',
    'ش': 'sh',
    'ص': 's',
    'ض': 'd',
    'ط': 't',
    'ظ': 'z',
    'ع': 'a',
    'غ': 'gh',
    'ف': 'f',
    'ق': 'q',
    'ك': 'k',
    'ل': 'l',
    'م': 'm',
    'ن': 'n',
    'ه': 'h',
    'ة': 'a',
    'و': 'w',
    'ؤ': 'w',
    'ي': 'y',
    'ى': 'y',
    'ئ': 'y',
    'ء': '',
    'َ': 'a',
    'ُ': 'u',
    'ِ': 'i',
    'ً': 'an',
    'ٌ': 'un',
    'ٍ': 'in',
    'ْ': '',
    'ّ': '',
  };

  static const _egyptianUniversities = <_UniversityAlias>[
    _UniversityAlias('جامعة القاهرة', 'Cairo University'),
    _UniversityAlias('جامعة عين شمس', 'Ain Shams University'),
    _UniversityAlias('جامعة الإسكندرية', 'Alexandria University'),
    _UniversityAlias('جامعة الاسكندرية', 'Alexandria University'),
    _UniversityAlias('جامعة المنصورة', 'Mansoura University'),
    _UniversityAlias('جامعة أسيوط', 'Assiut University'),
    _UniversityAlias('جامعة اسيوط', 'Assiut University'),
    _UniversityAlias('جامعة الزقازيق', 'Zagazig University'),
    _UniversityAlias('جامعة طنطا', 'Tanta University'),
    _UniversityAlias('جامعة المنيا', 'Minia University'),
    _UniversityAlias('جامعة سوهاج', 'Sohag University'),
    _UniversityAlias('جامعة بني سويف', 'Beni Suef University'),
    _UniversityAlias('الجامعة الأمريكية بالقاهرة', 'American University in Cairo'),
    _UniversityAlias('جامعة النيل', 'Nile University'),
    _UniversityAlias('جامعة حلوان', 'Helwan University'),
    _UniversityAlias('جامعة قناة السويس', 'Suez Canal University'),
    _UniversityAlias('جامعة الفيوم', 'Fayoum University'),
    _UniversityAlias('جامعة كفر الشيخ', 'Kafrelsheikh University'),
    _UniversityAlias('جامعة دمياط', 'Damietta University'),
    _UniversityAlias('جامعة بورسعيد', 'Port Said University'),
    _UniversityAlias('جامعة جنوب الوادي', 'South Valley University'),
    _UniversityAlias('الجامعة الألمانية بالقاهرة', 'German University in Cairo'),
    _UniversityAlias('جامعة مصر للعلوم والتكنولوجيا', 'Egypt-Japan University of Science and Technology'),
    _UniversityAlias('جامعة عين شمس', 'Ain Shams University'),
    _UniversityAlias('جامعة القاهرة الأهلية', 'New Giza University'),
    _UniversityAlias('جامعة 6 أكتوبر', 'October 6 University'),
    _UniversityAlias('جامعة سته اكتوبر', 'October 6 University'),
    _UniversityAlias('جامعة مدينة السادات', 'Sadat City University'),
    _UniversityAlias('جامعة دمنهور', 'Damanhour University'),
    _UniversityAlias('جامعة الأقصر', 'Luxor University'),
    _UniversityAlias('جامعة العريش', 'Arish University'),
    _UniversityAlias('جامعة بنها', 'Benha University'),
    _UniversityAlias('جامعة الشرقية', 'Zagazig University'),
  ];
}

class _UniversityAlias {
  final String arabic;
  final String english;

  const _UniversityAlias(this.arabic, this.english);
}
