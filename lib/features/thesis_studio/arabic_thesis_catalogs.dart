/// External Arabic thesis / dissertation catalogs that researchers can browse.
///
/// These sites are useful for finding Arabic Masters/PhD theses, but they are
/// **not** bibliographic APIs (no structured DOI/abstract search like OpenAlex).
/// AcadeGate opens them in the browser; it does not scrape or download PDFs.
class ArabicThesisCatalog {
  final String id;
  final String titleAr;
  final String titleEn;
  final String blurbAr;
  final String blurbEn;
  final Uri uri;

  const ArabicThesisCatalog({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.blurbAr,
    required this.blurbEn,
    required this.uri,
  });
}

class ArabicThesisCatalogs {
  ArabicThesisCatalogs._();

  /// Mobt3ath masters/PhD PDF library (category browse, not a DOI API).
  static final mobt3athMastersPhd = ArabicThesisCatalog(
    id: 'mobt3ath_masters_phd',
    titleAr: 'مبتعث — رسائل ماجستير ودكتوراه',
    titleEn: 'Mobt3ath — Masters & PhD theses',
    blurbAr:
        'مكتبة تصفح لتجميعات PDF لرسائل جامعية عربية. افتح الموضوع يدوياً، ثم الصق أي DOI مؤكد هنا إن وُجد.',
    blurbEn:
        'Browseable PDF collections of Arabic theses. Open the topic manually, then paste any confirmed DOI here if available.',
    uri: Uri.parse(
      'https://www.mobt3ath.com/Library.php?library=1&title='
      '%D8%B1%D8%B3%D8%A7%D8%A6%D9%84_%D9%85%D8%A7%D8%AC%D8%B3%D8%AA%D9%8A%D8%B1_'
      '%D9%88%D8%AF%D9%83%D8%AA%D9%88%D8%B1%D8%A7_PDF',
    ),
  );

  static final mobt3athHome = ArabicThesisCatalog(
    id: 'mobt3ath_home',
    titleAr: 'مبتعث — الصفحة الرئيسية',
    titleEn: 'Mobt3ath — home',
    blurbAr: 'بوابة مبتعث للمكتبات والتصنيفات العلمية.',
    blurbEn: 'Mobt3ath portal for scientific library categories.',
    uri: Uri.parse('https://www.mobt3ath.com/'),
  );

  /// Commercial Arabic databases — institutional login; no public API.
  static final mandumahHome = ArabicThesisCatalog(
    id: 'mandumah_home',
    titleAr: 'دار المنظومة',
    titleEn: 'Dar Al-Mandumah',
    blurbAr:
        'أكبر قواعد الرسائل والأبحاث العربية (اشتراك مؤسسي). افتح البحث يدوياً؛ لا API عام، ولا نسحب نصوصها.',
    blurbEn:
        'Major Arabic theses/articles databases (institutional subscription). Browse manually; no public API, and we do not scrape full texts.',
    uri: Uri.parse('https://search.mandumah.com/'),
  );

  static final mandumahSite = ArabicThesisCatalog(
    id: 'mandumah_site',
    titleAr: 'دار المنظومة — الموقع',
    titleEn: 'Dar Al-Mandumah — site',
    blurbAr: 'صفحة المنصة والتعريف بقواعد المعلومات.',
    blurbEn: 'Platform home and database overview.',
    uri: Uri.parse('https://www.mandumah.com/'),
  );

  static final List<ArabicThesisCatalog> all = [
    mobt3athMastersPhd,
    mobt3athHome,
    mandumahHome,
    mandumahSite,
  ];
}
