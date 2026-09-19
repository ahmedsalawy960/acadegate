/// Official public homepages / staff directories for Egyptian universities.
/// Used as source links — names themselves come from ORCID/Wikidata/OpenAlex.
class OfficialUniversityDirectory {
  final String english;
  final String arabic;
  final String homepage;
  final String staffUrl;

  const OfficialUniversityDirectory({
    required this.english,
    required this.arabic,
    required this.homepage,
    this.staffUrl = '',
  });

  String get displayUrl => staffUrl.isNotEmpty ? staffUrl : homepage;
}

class OfficialUniversityDirectories {
  OfficialUniversityDirectories._();

  static const entries = <OfficialUniversityDirectory>[
    OfficialUniversityDirectory(
      english: 'Cairo University',
      arabic: 'جامعة القاهرة',
      homepage: 'https://cu.edu.eg',
    ),
    OfficialUniversityDirectory(
      english: 'Ain Shams University',
      arabic: 'جامعة عين شمس',
      homepage: 'https://www.asu.edu.eg',
    ),
    OfficialUniversityDirectory(
      english: 'Alexandria University',
      arabic: 'جامعة الإسكندرية',
      homepage: 'https://alexu.edu.eg',
    ),
    OfficialUniversityDirectory(
      english: 'Al-Azhar University',
      arabic: 'جامعة الأزهر',
      homepage: 'https://www.azhar.edu.eg',
    ),
    OfficialUniversityDirectory(
      english: 'Mansoura University',
      arabic: 'جامعة المنصورة',
      homepage: 'https://www.mans.edu.eg',
    ),
    OfficialUniversityDirectory(
      english: 'Assiut University',
      arabic: 'جامعة أسيوط',
      homepage: 'https://www.aun.edu.eg',
    ),
    OfficialUniversityDirectory(
      english: 'Zagazig University',
      arabic: 'جامعة الزقازيق',
      homepage: 'https://www.zu.edu.eg',
    ),
    OfficialUniversityDirectory(
      english: 'Tanta University',
      arabic: 'جامعة طنطا',
      homepage: 'https://www.tanta.edu.eg',
    ),
    OfficialUniversityDirectory(
      english: 'Minia University',
      arabic: 'جامعة المنيا',
      homepage: 'https://www.minia.edu.eg',
    ),
    OfficialUniversityDirectory(
      english: 'Fayoum University',
      arabic: 'جامعة الفيوم',
      homepage: 'https://www.fayoum.edu.eg',
    ),
    OfficialUniversityDirectory(
      english: 'Helwan University',
      arabic: 'جامعة حلوان',
      homepage: 'https://www.helwan.edu.eg',
    ),
    OfficialUniversityDirectory(
      english: 'Suez Canal University',
      arabic: 'جامعة قناة السويس',
      homepage: 'https://suez.edu.eg',
    ),
    OfficialUniversityDirectory(
      english: 'South Valley University',
      arabic: 'جامعة جنوب الوادي',
      homepage: 'https://www.svu.edu.eg',
    ),
    OfficialUniversityDirectory(
      english: 'Beni Suef University',
      arabic: 'جامعة بني سويف',
      homepage: 'https://www.bsu.edu.eg',
    ),
    OfficialUniversityDirectory(
      english: 'Banha University',
      arabic: 'جامعة بنها',
      homepage: 'https://www.bu.edu.eg',
    ),
    OfficialUniversityDirectory(
      english: 'Sohag University',
      arabic: 'جامعة سوهاج',
      homepage: 'https://www.sohag-univ.edu.eg',
    ),
    OfficialUniversityDirectory(
      english: 'Aswan University',
      arabic: 'جامعة أسوان',
      homepage: 'https://aswu.edu.eg',
    ),
  ];

  static OfficialUniversityDirectory? match(String query) {
    final q = query.trim().toLowerCase();
    if (q.length < 3) return null;
    for (final entry in entries) {
      if (entry.english.toLowerCase().contains(q) ||
          q.contains(entry.english.toLowerCase()) ||
          entry.arabic.contains(query.trim()) ||
          query.trim().contains(entry.arabic)) {
        return entry;
      }
    }
    return null;
  }
}
