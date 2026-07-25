import '../../core/locale/app_translate.dart';

class ScienceNewsFeed {
  final String sourceName;
  final String? sourceNameAr;
  final String url;
  final String defaultCategory;
  final String language;

  const ScienceNewsFeed({
    required this.sourceName,
    this.sourceNameAr,
    required this.url,
    required this.defaultCategory,
    required this.language,
  });

  String get displaySource =>
      language == 'ar' ? (sourceNameAr ?? sourceName) : sourceName;
}

class ScienceNewsCategory {
  ScienceNewsCategory._();

  static const all = 'all';
  static const general = 'general';
  static const medicine = 'medicine';
  static const engineering = 'engineering';
  static const physics = 'physics';
  static const biology = 'biology';
  static const chemistry = 'chemistry';
  static const technology = 'technology';
  static const environment = 'environment';
  static const agriculture = 'agriculture';
  static const psychology = 'psychology';
  static const astronomy = 'astronomy';
  static const mathematics = 'mathematics';

  static const orderedIds = <String>[
    all,
    general,
    medicine,
    engineering,
    physics,
    biology,
    chemistry,
    technology,
    environment,
    agriculture,
    psychology,
    astronomy,
    mathematics,
  ];

  static String label(String id) {
    switch (id) {
      case all:
        return appTr('الكل', 'All');
      case general:
        return appTr('عام', 'General');
      case medicine:
        return appTr('طب', 'Medicine');
      case engineering:
        return appTr('هندسة', 'Engineering');
      case physics:
        return appTr('فيزياء', 'Physics');
      case biology:
        return appTr('أحياء', 'Biology');
      case chemistry:
        return appTr('كيمياء', 'Chemistry');
      case technology:
        return appTr('تقنية', 'Technology');
      case environment:
        return appTr('بيئة', 'Environment');
      case agriculture:
        return appTr('زراعة', 'Agriculture');
      case psychology:
        return appTr('علم نفس', 'Psychology');
      case astronomy:
        return appTr('فلك', 'Astronomy');
      case mathematics:
        return appTr('رياضيات', 'Mathematics');
      default:
        return id;
    }
  }
}

/// Scientific RSS only — fetched via Cloud Function on web (avoids CORS).
const scienceNewsFeeds = <ScienceNewsFeed>[
  ScienceNewsFeed(
    sourceName: 'ScienceDaily',
    url: 'https://www.sciencedaily.com/rss/all.xml',
    defaultCategory: ScienceNewsCategory.general,
    language: 'en',
  ),
  ScienceNewsFeed(
    sourceName: 'ScienceDaily — Health',
    url: 'https://www.sciencedaily.com/rss/health_medicine.xml',
    defaultCategory: ScienceNewsCategory.medicine,
    language: 'en',
  ),
  ScienceNewsFeed(
    sourceName: 'ScienceDaily — Mind & Brain',
    url: 'https://www.sciencedaily.com/rss/mind_brain.xml',
    defaultCategory: ScienceNewsCategory.psychology,
    language: 'en',
  ),
  ScienceNewsFeed(
    sourceName: 'ScienceDaily — Tech',
    url: 'https://www.sciencedaily.com/rss/tech.xml',
    defaultCategory: ScienceNewsCategory.technology,
    language: 'en',
  ),
  ScienceNewsFeed(
    sourceName: 'ScienceDaily — Earth',
    url: 'https://www.sciencedaily.com/rss/earth_climate.xml',
    defaultCategory: ScienceNewsCategory.environment,
    language: 'en',
  ),
  ScienceNewsFeed(
    sourceName: 'ScienceDaily — Life',
    url: 'https://www.sciencedaily.com/rss/plants_animals.xml',
    defaultCategory: ScienceNewsCategory.biology,
    language: 'en',
  ),
  ScienceNewsFeed(
    sourceName: 'ScienceDaily — Physics',
    url: 'https://www.sciencedaily.com/rss/matter_energy.xml',
    defaultCategory: ScienceNewsCategory.physics,
    language: 'en',
  ),
  ScienceNewsFeed(
    sourceName: 'ScienceDaily — Space',
    url: 'https://www.sciencedaily.com/rss/space_time.xml',
    defaultCategory: ScienceNewsCategory.astronomy,
    language: 'en',
  ),
  ScienceNewsFeed(
    sourceName: 'ScienceDaily — Math & CS',
    url: 'https://www.sciencedaily.com/rss/computers_math.xml',
    defaultCategory: ScienceNewsCategory.mathematics,
    language: 'en',
  ),
  ScienceNewsFeed(
    sourceName: 'Nature',
    url: 'https://feeds.nature.com/nature/rss/current',
    defaultCategory: ScienceNewsCategory.biology,
    language: 'en',
  ),
  ScienceNewsFeed(
    sourceName: 'Nature Medicine',
    url: 'https://feeds.nature.com/nm/rss/current',
    defaultCategory: ScienceNewsCategory.medicine,
    language: 'en',
  ),
  ScienceNewsFeed(
    sourceName: 'Nature Chemistry',
    url: 'https://feeds.nature.com/nchem/rss/current',
    defaultCategory: ScienceNewsCategory.chemistry,
    language: 'en',
  ),
  ScienceNewsFeed(
    sourceName: 'Nature Biotechnology',
    url: 'https://feeds.nature.com/nbt/rss/current',
    defaultCategory: ScienceNewsCategory.biology,
    language: 'en',
  ),
  ScienceNewsFeed(
    sourceName: 'Nature Neuroscience',
    url: 'https://feeds.nature.com/neuro/rss/current',
    defaultCategory: ScienceNewsCategory.psychology,
    language: 'en',
  ),
  ScienceNewsFeed(
    sourceName: 'Phys.org',
    url: 'https://phys.org/rss-feed/',
    defaultCategory: ScienceNewsCategory.physics,
    language: 'en',
  ),
  ScienceNewsFeed(
    sourceName: 'Medical Xpress',
    url: 'https://medicalxpress.com/rss-feed/',
    defaultCategory: ScienceNewsCategory.medicine,
    language: 'en',
  ),
  ScienceNewsFeed(
    sourceName: 'Tech Xplore',
    url: 'https://techxplore.com/rss-feed/',
    defaultCategory: ScienceNewsCategory.technology,
    language: 'en',
  ),
  ScienceNewsFeed(
    sourceName: 'NASA',
    url: 'https://www.nasa.gov/rss/dyn/breaking_news.rss',
    defaultCategory: ScienceNewsCategory.astronomy,
    language: 'en',
  ),
  ScienceNewsFeed(
    sourceName: 'IEEE Spectrum',
    url: 'https://spectrum.ieee.org/feeds/feed.rss',
    defaultCategory: ScienceNewsCategory.engineering,
    language: 'en',
  ),
  ScienceNewsFeed(
    sourceName: 'MIT Technology Review',
    url: 'https://www.technologyreview.com/feed/',
    defaultCategory: ScienceNewsCategory.technology,
    language: 'en',
  ),
  ScienceNewsFeed(
    sourceName: 'WHO',
    url: 'https://www.who.int/rss-feeds/news-english.xml',
    defaultCategory: ScienceNewsCategory.medicine,
    language: 'en',
  ),
  ScienceNewsFeed(
    sourceName: 'SciDev.Net MENA',
    url: 'https://www.scidev.net/mena/rss.xml',
    defaultCategory: ScienceNewsCategory.general,
    language: 'en',
  ),
  ScienceNewsFeed(
    sourceName: 'DW — Arabic Science',
    sourceNameAr: 'دويتشه فيله — علوم',
    url: 'https://rss.dw.com/rdf/rss-ar-sci',
    defaultCategory: ScienceNewsCategory.general,
    language: 'ar',
  ),
];

List<ScienceNewsFeed> scienceNewsFeedsForLocale({required bool isEnglish}) {
  final lang = isEnglish ? 'en' : 'ar';
  return scienceNewsFeeds.where((f) => f.language == lang).toList();
}
