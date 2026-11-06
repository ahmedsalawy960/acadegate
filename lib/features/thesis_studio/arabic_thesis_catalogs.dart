/// مكتبة الرسائل العلمية — بوابات تصفح وبحث (داخل استوديو الرسالة).
///
/// بعضها للتصفح اليدوي (مبتعث / دار المنظومة)، وبعضها يدعم بحثاً مفتوحاً
/// (OpenAlex / OATD / CORE). لا نسحب PDF محمية بحقوق أو اشتراك.
class ArabicThesisCatalog {
  final String id;
  final String titleAr;
  final String titleEn;
  final String blurbAr;
  final String blurbEn;
  final Uri uri;
  /// إن وُجد، يُبنى رابط بحث بالنقطة البحثية.
  final Uri Function(String query)? searchUriBuilder;
  final bool supportsLiveSearch;

  const ArabicThesisCatalog({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.blurbAr,
    required this.blurbEn,
    required this.uri,
    this.searchUriBuilder,
    this.supportsLiveSearch = false,
  });

  Uri uriForQuery(String query) {
    final q = query.trim();
    if (q.isEmpty || searchUriBuilder == null) return uri;
    return searchUriBuilder!(q);
  }
}

class ArabicThesisCatalogs {
  ArabicThesisCatalogs._();

  /// مبتعث — رسائل فقط (بدون الصفحة الرئيسية).
  static final mobt3athMastersPhd = ArabicThesisCatalog(
    id: 'mobt3ath_masters_phd',
    titleAr: 'مبتعث — رسائل ماجستير ودكتوراه',
    titleEn: 'Mobt3ath — Masters & PhD theses',
    blurbAr:
        'تصفح تجميعات PDF لرسائل عربية. افتح الموضوع يدوياً، ثم الصق DOI إن وُجد.',
    blurbEn:
        'Browse Arabic thesis PDF collections. Open the topic manually, then paste a DOI if available.',
    uri: Uri.parse(
      'https://www.mobt3ath.com/Library.php?library=1&title='
      '%D8%B1%D8%B3%D8%A7%D8%A6%D9%84_%D9%85%D8%A7%D8%AC%D8%B3%D8%AA%D9%8A%D8%B1_'
      '%D9%88%D8%AF%D9%83%D8%AA%D9%88%D8%B1%D8%A7_PDF',
    ),
  );

  /// دار المنظومة — البحث فقط (بدون موقع التعريف).
  static final mandumahHome = ArabicThesisCatalog(
    id: 'mandumah_home',
    titleAr: 'دار المنظومة',
    titleEn: 'Dar Al-Mandumah',
    blurbAr:
        'قواعد الرسائل والأبحاث العربية (اشتراك مؤسسي). تصفح يدوياً؛ لا API عام.',
    blurbEn:
        'Arabic theses/articles databases (institutional subscription). Browse manually; no public API.',
    uri: Uri.parse('https://search.mandumah.com/'),
  );

  static final openAlexTheses = ArabicThesisCatalog(
    id: 'openalex_theses',
    titleAr: 'OpenAlex — رسائل ومخرجات مفتوحة',
    titleEn: 'OpenAlex — open theses & works',
    blurbAr:
        'أفضل نقطة بداية: فهرس مفتوح يشمل أطروحات مع بيانات وصفية وروابط وصول مفتوح. البحث الحي متاح داخل AcadeGate.',
    blurbEn:
        'Best starting point: open index including dissertations with metadata and OA links. Live search is available inside AcadeGate.',
    uri: Uri.parse(
      'https://openalex.org/works?page=1&filter=type:dissertation',
    ),
    searchUriBuilder: (q) => Uri.parse(
      'https://openalex.org/works?page=1&filter=type:dissertation&search=${Uri.encodeQueryComponent(q)}',
    ),
    supportsLiveSearch: true,
  );

  static final oatd = ArabicThesisCatalog(
    id: 'oatd',
    titleAr: 'OATD — فهرس الرسائل المفتوحة',
    titleEn: 'OATD — Open Access Theses & Dissertations',
    blurbAr:
        'متخصص في الرسائل الجامعية المفتوحة عالمياً. افتح نتائج البحث في المتصفح.',
    blurbEn:
        'Specialized in open university theses worldwide. Open search results in the browser.',
    uri: Uri.parse('https://oatd.org/'),
    searchUriBuilder: (q) => Uri.parse(
      'https://oatd.org/oatd/search?q=${Uri.encodeQueryComponent(q)}',
    ),
  );

  static final core = ArabicThesisCatalog(
    id: 'core',
    titleAr: 'CORE — نص كامل مفتوح',
    titleEn: 'CORE — open full texts',
    blurbAr:
        'مجمّع مستودعات مفتوحة لاكتشاف أوراق ورسائل مع روابط للنص الكامل عند التوفر.',
    blurbEn:
        'Aggregator of open repositories for discovering papers and theses with full-text links when available.',
    uri: Uri.parse('https://core.ac.uk/'),
    searchUriBuilder: (q) => Uri.parse(
      'https://core.ac.uk/search?q=${Uri.encodeQueryComponent(q)}',
    ),
  );

  /// مكتبة الرسائل العلمية كما تظهر في استوديو الرسالة.
  static final List<ArabicThesisCatalog> all = [
    openAlexTheses,
    oatd,
    core,
    mobt3athMastersPhd,
    mandumahHome,
  ];
}
