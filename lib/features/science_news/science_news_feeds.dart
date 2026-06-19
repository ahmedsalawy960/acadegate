class ScienceNewsFeed {
  final String sourceName;
  final String url;
  final String defaultCategory;

  const ScienceNewsFeed({
    required this.sourceName,
    required this.url,
    required this.defaultCategory,
  });
}

class ScienceNewsCategory {
  ScienceNewsCategory._();

  static const all = 'all';
  static const general = 'general';
  static const medicine = 'medicine';
  static const engineering = 'engineering';
  static const physics = 'physics';
  static const biology = 'biology';
  static const technology = 'technology';

  static const labels = <String, String>{
    all: 'الكل',
    general: 'عام',
    medicine: 'طب',
    engineering: 'هندسة',
    physics: 'فيزياء',
    biology: 'أحياء',
    technology: 'تقنية',
  };

  static String label(String id) => labels[id] ?? id;
}

/// مصادر RSS موثوقة — تُحدَّث تلقائياً عند فتح القسم.
const scienceNewsFeeds = <ScienceNewsFeed>[
  ScienceNewsFeed(
    sourceName: 'ScienceDaily',
    url: 'https://www.sciencedaily.com/rss/all.xml',
    defaultCategory: ScienceNewsCategory.general,
  ),
  ScienceNewsFeed(
    sourceName: 'Nature',
    url: 'https://feeds.nature.com/nature/rss/current',
    defaultCategory: ScienceNewsCategory.biology,
  ),
  ScienceNewsFeed(
    sourceName: 'Phys.org',
    url: 'https://phys.org/rss-feed/',
    defaultCategory: ScienceNewsCategory.physics,
  ),
  ScienceNewsFeed(
    sourceName: 'Medical Xpress',
    url: 'https://medicalxpress.com/rss-feed/',
    defaultCategory: ScienceNewsCategory.medicine,
  ),
  ScienceNewsFeed(
    sourceName: 'Tech Xplore',
    url: 'https://techxplore.com/rss-feed/',
    defaultCategory: ScienceNewsCategory.technology,
  ),
];
