/// ترجمة أسماء الجامعات العربية وتحويل نص البحث (عربي/إنجليزي بأي حالة) لصيغ يفهمها OpenAlex.
class OpenAlexSearchAliases {
  OpenAlexSearchAliases._();

  static final RegExp _arabicScript = RegExp(r'[\u0600-\u06FF]');
  static final RegExp _tashkeel = RegExp(
    r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED]',
  );

  static bool containsArabic(String text) => _arabicScript.hasMatch(text);

  /// تطبيع موحّد: إنجليزي بدون حساسية لحالة الأحرف + عربي موحّد (أ/إ/آ، ة/ه، تشكيل).
  static String normalizeQuery(String text) {
    var value = text.trim().toLowerCase();
    value = value.replaceAll(_tashkeel, '');
    value = value
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ٱ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll('ء', '');
    // وحّد الشرطات وعلامات الترقيم إلى مسافات — al-azhar ≡ al azhar
    value = value.replaceAll(RegExp(r'[_\-–—/\\.,;:]+'), ' ');
    value = value.replaceAll(RegExp(r'[ـ\s]+'), ' ');
    return value.trim();
  }

  static List<String> institutionQueries(String query) {
    final trimmed = query.trim();
    if (trimmed.length < 2) return [];

    final cleaned = _stripFacultyNoise(trimmed);
    final best = _bestUniversityMatch(cleaned);

    final ordered = <String>{};
    if (best != null) {
      ordered.add(best.english);
      for (final alt in _englishAlternates(best.english)) {
        ordered.add(alt);
      }
    } else {
      // إنجليزي بأي حالة → صيغة Title Case لـ OpenAlex
      final asEnglish = cleaned.trim();
      if (asEnglish.isNotEmpty && !containsArabic(asEnglish)) {
        ordered.add(_titleCaseWords(normalizeQuery(asEnglish)));
        ordered.add(asEnglish);
      }
      if (cleaned.isNotEmpty && cleaned != trimmed) {
        ordered.add(cleaned);
      }
      ordered.add(trimmed);
    }
    return ordered.toList();
  }

  /// معرّف OpenAlex المعروف لأهم الجامعات المصرية (تجاوز فشل البحث النصي).
  static String? knownInstitutionOpenAlexId(String query) {
    return _bestUniversityMatch(_stripFacultyNoise(query.trim()))?.openAlexId;
  }

  /// هل يجب تفضيل نتائج مصر؟ (بحث عربي أو جامعة مصرية معروفة بالإنجليزية).
  static bool preferEgyptInstitutions(String query) {
    if (containsArabic(query)) return true;
    return _bestUniversityMatch(_stripFacultyNoise(query.trim())) != null;
  }

  static _UniversityAlias? _bestUniversityMatch(String cleanedQuery) {
    if (cleanedQuery.trim().length < 2) return null;

    final normalized = normalizeQuery(cleanedQuery);
    final core = _universityCoreName(normalized);
    if (normalized.length < 2 && core.length < 2) return null;

    // كلمات مفتاحية حاسمة (بعد التطبيع — azhar / AZHAR / الأزهر سواء).
    for (final rule in _keywordRules) {
      final needle = normalizeQuery(rule.needle);
      if (needle.isEmpty) continue;
      if (normalized.contains(needle) || core.contains(needle)) {
        for (final entry in _egyptianUniversities) {
          if (entry.english == rule.english) return entry;
        }
      }
    }

    _UniversityAlias? best;
    var bestScore = 0;
    for (final entry in _egyptianUniversities) {
      final arabicKey = normalizeQuery(entry.arabic);
      final englishKey = normalizeQuery(entry.english);
      final scoreAr = _institutionMatchScore(
        query: normalized,
        queryCore: core,
        alias: arabicKey,
        aliasCore: _universityCoreName(arabicKey),
      );
      final scoreEn = _institutionMatchScore(
        query: normalized,
        queryCore: core,
        alias: englishKey,
        aliasCore: _universityCoreName(englishKey),
      );
      final score = scoreAr > scoreEn ? scoreAr : scoreEn;
      if (score > bestScore) {
        bestScore = score;
        best = entry;
      }
    }
    if (best == null || bestScore < 50) return null;
    return best;
  }

  static const _keywordRules = <({String needle, String english})>[
    // الأطول/الأخص أولاً حتى لا يخطف «cairo» جامعة أخرى في القاهرة.
    (needle: 'american university', english: 'American University in Cairo'),
    (needle: 'الامريكيه', english: 'American University in Cairo'),
    (needle: 'german university', english: 'German University in Cairo'),
    (needle: 'الالمانيه', english: 'German University in Cairo'),
    (needle: 'ازهر', english: 'Al-Azhar University'),
    (needle: 'azhar', english: 'Al-Azhar University'),
    (needle: 'alazhar', english: 'Al-Azhar University'),
    (needle: 'عين شمس', english: 'Ain Shams University'),
    (needle: 'ain shams', english: 'Ain Shams University'),
    (needle: 'ainshams', english: 'Ain Shams University'),
    (needle: 'اسكندري', english: 'Alexandria University'),
    (needle: 'alexandria', english: 'Alexandria University'),
    (needle: 'منصوره', english: 'Mansoura University'),
    (needle: 'mansoura', english: 'Mansoura University'),
    (needle: 'حلوان', english: 'Helwan University'),
    (needle: 'helwan', english: 'Helwan University'),
    (needle: 'زقازيق', english: 'Zagazig University'),
    (needle: 'zagazig', english: 'Zagazig University'),
    (needle: 'طنطا', english: 'Tanta University'),
    (needle: 'tanta', english: 'Tanta University'),
    (needle: 'اسيوط', english: 'Assiut University'),
    (needle: 'assiut', english: 'Assiut University'),
    (needle: 'بنها', english: 'Benha University'),
    (needle: 'benha', english: 'Benha University'),
  ];

  /// اسم الجامعة بعد حذف كلمات عامة لا تُميّز بينها.
  static String _universityCoreName(String normalized) {
    var value = ' $normalized ';
    for (final stop in _institutionStopwords) {
      value = value.replaceAll(' $stop ', ' ');
    }
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static const _institutionStopwords = <String>[
    'جامعة',
    'الجامعة',
    'جامعه',
    'الجامعه',
    'university',
    'univ',
    'of',
    'the',
    'in',
    'at',
  ];

  /// درجة تطابق الاسم (أعلى = أدق). بدون تداخل رخيص على كلمة «جامعة».
  static int _institutionMatchScore({
    required String query,
    required String queryCore,
    required String alias,
    required String aliasCore,
  }) {
    if (query.isEmpty || alias.isEmpty) return 0;
    if (query == alias) return 100;
    if (queryCore.isNotEmpty &&
        aliasCore.isNotEmpty &&
        queryCore == aliasCore) {
      return 95;
    }
    if (query.contains(alias) || alias.contains(query)) {
      final shorter = query.length <= alias.length ? query : alias;
      if (shorter.length < 3) return 0;
      return 80 + (shorter.length.clamp(0, 15));
    }
    if (queryCore.isNotEmpty &&
        aliasCore.isNotEmpty &&
        queryCore.length >= 3 &&
        aliasCore.length >= 3 &&
        (queryCore.contains(aliasCore) || aliasCore.contains(queryCore))) {
      final shorter =
          queryCore.length <= aliasCore.length ? queryCore : aliasCore;
      return 70 + (shorter.length.clamp(0, 15));
    }
    return 0;
  }

  static List<String> _englishAlternates(String english) {
    if (english == 'Al-Azhar University') {
      return const [
        'Al Azhar University',
        'Alazhar University',
      ];
    }
    if (english == 'Ain Shams University') {
      return const ['AinShams University', 'Ain-Shams University'];
    }
    return const [];
  }

  /// يزيل «كلية الهندسة» ونحوها حتى لا يفشل بحث الجامعة.
  static String _stripFacultyNoise(String text) {
    var value = text;
    const noise = <String>[
      'كلية الهندسة',
      'كليه الهندسه',
      'كلية العلوم',
      'كليه العلوم',
      'كلية الطب',
      'كليه الطب',
      'كلية الحاسبات',
      'كليه الحاسبات',
      'كلية الصيدلة',
      'كليه الصيدله',
      'كلية الزراعة',
      'كليه الزراعه',
      'كلية الآداب',
      'كليه الاداب',
      'كلية التجارة',
      'كليه التجاره',
      'كلية التربية',
      'كليه التربيه',
      'كلية',
      'كليه',
      'Faculty of Engineering',
      'Faculty of Science',
      'Faculty of Medicine',
      'Faculty of',
      'Faculty',
      'faculty of engineering',
      'faculty of',
      'faculty',
    ];
    for (final phrase in noise) {
      value = value.replaceAll(RegExp(RegExp.escape(phrase), caseSensitive: false), ' ');
    }
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static List<String> authorQueries(String query) {
    final trimmed = query.trim();
    if (trimmed.length < 2) return [];

    final queries = <String>{trimmed};
    final normalized = normalizeQuery(trimmed);

    // إنجليزي بأي حالة → صيغ موحدة + بدائل إملاء شائعة
    if (!containsArabic(trimmed) && normalized.isNotEmpty) {
      queries.add(normalized);
      queries.add(_titleCaseWords(normalized));
      for (final variant in _englishNameSpellingVariants(normalized)) {
        queries.add(variant);
        queries.add(_titleCaseWords(variant));
      }
    }

    if (containsArabic(trimmed)) {
      final transliterated = transliterateArabic(trimmed);
      if (transliterated.isNotEmpty) {
        queries.add(transliterated);
        queries.add(_titleCaseWords(transliterated));
        for (final variant in _englishNameSpellingVariants(transliterated)) {
          queries.add(variant);
          queries.add(_titleCaseWords(variant));
        }
      }

      for (final variant in _nameSpellingVariants(trimmed)) {
        queries.add(variant);
      }
    }

    return queries.toList();
  }

  /// درجة تطابق اسم الباحث مع نص البحث (0–100). يُستبعد الضعفاء غير المطابقين.
  static int nameRelevanceScore(String query, String candidateName) {
    final q = normalizeQuery(query);
    final n = normalizeQuery(candidateName);
    if (q.isEmpty || n.isEmpty) return 0;
    if (q == n) return 100;
    if (n.contains(q) || q.contains(n)) {
      return 85 + (q.length.clamp(0, 15));
    }

    final qTokens = q.split(' ').where((t) => t.length >= 2).toList();
    final nTokens = n.split(' ').where((t) => t.length >= 2).toList();
    if (qTokens.isEmpty || nTokens.isEmpty) return 0;

    var matched = 0;
    for (final qt in qTokens) {
      final hit = nTokens.any(
        (nt) =>
            nt == qt ||
            nt.startsWith(qt) ||
            qt.startsWith(nt) ||
            _namesClose(qt, nt),
      );
      if (hit) matched++;
    }

    if (matched == 0) return 0;
    if (qTokens.length == 1) {
      return matched > 0 ? 70 : 0;
    }
    // اسمان فأكثر: نحتاج تطابق جزء معتبر (وليس لقب عشوائي فقط).
    final ratio = matched / qTokens.length;
    if (ratio < 0.5) return (ratio * 40).round();
    return (55 + ratio * 40).round().clamp(0, 99);
  }

  static bool isNameRelevantEnough(String query, String candidateName) {
    final tokens =
        normalizeQuery(query).split(' ').where((t) => t.length >= 2).length;
    final score = nameRelevanceScore(query, candidateName);
    if (tokens >= 2) return score >= 55;
    return score >= 40;
  }

  /// عرض اسم شخص بشكل مقروء (Ramy Farid بدل ramy faride).
  static String formatPersonName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    if (containsArabic(trimmed)) return trimmed;
    return _titleCaseWords(normalizeQuery(trimmed));
  }

  static bool _namesClose(String a, String b) {
    if (a == b) return true;
    final shorter = a.length <= b.length ? a : b;
    final longer = a.length <= b.length ? b : a;
    if (shorter.length < 3) return false;
    if (longer.startsWith(shorter) || shorter.startsWith(longer)) return true;
    // اختلاف حرف/حرفين شائع في النقل الحرفي (farid/faride, ramy/rami).
    if ((a.length - b.length).abs() <= 2 &&
        a.length >= 4 &&
        b.length >= 4 &&
        _sharedPrefixLen(a, b) >= 3) {
      return true;
    }
    return false;
  }

  static int _sharedPrefixLen(String a, String b) {
    final n = a.length < b.length ? a.length : b.length;
    var i = 0;
    while (i < n && a[i] == b[i]) {
      i++;
    }
    return i;
  }

  static List<String> _englishNameSpellingVariants(String normalizedEnglish) {
    final tokens = normalizedEnglish.split(' ').where((t) => t.isNotEmpty);
    if (tokens.isEmpty) return const [];

    const map = <String, List<String>>{
      'ramy': ['rami', 'ramy'],
      'rami': ['ramy', 'rami'],
      'farid': ['faride', 'fareed', 'farid'],
      'faride': ['farid', 'fareed', 'faride'],
      'fareed': ['farid', 'faride', 'fareed'],
      'mohamed': ['mohammed', 'muhammad', 'mohammad'],
      'mohammed': ['mohamed', 'muhammad'],
      'ahmed': ['ahmad'],
      'ahmad': ['ahmed'],
      'hassan': ['hasan'],
      'hasan': ['hassan'],
      'hussein': ['hussain', 'husain'],
      'youssef': ['yousef', 'yusuf'],
      'yousef': ['youssef', 'yusuf'],
      'mostafa': ['mustafa', 'moustafa'],
      'mustafa': ['mostafa', 'moustafa'],
      'ibrahim': ['ebrahim'],
      'khaled': ['khalid'],
      'mahmoud': ['mahmud', 'mahmood'],
    };

    // بدائل لكل مقطع ثم نولّد تركيبات محدودة للاسم الثنائي.
    final parts = tokens.toList();
    if (parts.length == 1) {
      return map[parts.first] ?? const [];
    }

    final variants = <String>{};
    final firstAlts = [parts.first, ...?map[parts.first]];
    final lastAlts = [parts.last, ...?map[parts.last]];
    for (final f in firstAlts.take(3)) {
      for (final l in lastAlts.take(3)) {
        final mid = parts.length > 2
            ? ' ${parts.sublist(1, parts.length - 1).join(' ')} '
            : ' ';
        variants.add('$f$mid$l'.replaceAll(RegExp(r'\s+'), ' ').trim());
      }
    }
    return variants.toList();
  }

  /// يعرض للمستخدم الاسم الإنجليزي المقترح (عربي أو إنجليزي بأي حالة).
  static String? suggestedInstitutionEnglish(String query) {
    final best = _bestUniversityMatch(_stripFacultyNoise(query.trim()));
    if (best != null) return best.english;
    final englishQueries = institutionQueries(query)
        .where((item) => normalizeQuery(item) != normalizeQuery(query))
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

  static String _normalizeArabic(String text) => normalizeQuery(text);

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
      'رامي': ['Ramy', 'Rami'],
      'فريد': ['Farid', 'Fareed', 'Faride'],
      'فرج': ['Farag', 'Faraj'],
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
    _UniversityAlias('جامعة القاهرة', 'Cairo University', openAlexId: 'I145487455'),
    _UniversityAlias('جامعة عين شمس', 'Ain Shams University', openAlexId: 'I107720978'),
    _UniversityAlias('جامعة الإسكندرية', 'Alexandria University', openAlexId: 'I84524832'),
    _UniversityAlias('جامعة الاسكندرية', 'Alexandria University', openAlexId: 'I84524832'),
    _UniversityAlias('جامعة الأزهر', 'Al-Azhar University', openAlexId: 'I184834183'),
    _UniversityAlias('جامعة الازهر', 'Al-Azhar University', openAlexId: 'I184834183'),
    _UniversityAlias('الازهر', 'Al-Azhar University', openAlexId: 'I184834183'),
    _UniversityAlias('الأزهر', 'Al-Azhar University', openAlexId: 'I184834183'),
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

  /// جامعات أولوية لتعبئة المشرفين (معرّف OpenAlex إن عُرف).
  static List<SeedUniversity> prioritySeedUniversities({int limit = 8}) {
    final seen = <String>{};
    final out = <SeedUniversity>[];
    for (final entry in _egyptianUniversities) {
      final key = entry.english.toLowerCase();
      if (!seen.add(key)) continue;
      out.add(
        SeedUniversity(
          arabic: entry.arabic,
          english: entry.english,
          openAlexId: entry.openAlexId,
        ),
      );
      if (out.length >= limit) break;
    }
    return out;
  }
}

/// جامعة جاهزة لتعبئة المشرفين الجماعية.
class SeedUniversity {
  final String arabic;
  final String english;
  final String? openAlexId;

  const SeedUniversity({
    required this.arabic,
    required this.english,
    this.openAlexId,
  });
}

class _UniversityAlias {
  final String arabic;
  final String english;
  final String? openAlexId;

  const _UniversityAlias(this.arabic, this.english, {this.openAlexId});
}
