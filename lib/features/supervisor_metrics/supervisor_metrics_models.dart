/// تقدير مستوى المجلة من مؤشرات OpenAlex (ليس تصنيف Scimago رسمياً).
class JournalTier {
  JournalTier._();

  static String labelFromCitedness(double citedness) {
    if (citedness >= 5) return 'تأثير مرتفع جداً (≈ Q1)';
    if (citedness >= 2) return 'تأثير مرتفع (≈ Q1–Q2)';
    if (citedness >= 1) return 'تأثير جيد (≈ Q2–Q3)';
    if (citedness >= 0.3) return 'تأثير معتدل (≈ Q3–Q4)';
    return 'تأثير قياسي';
  }

  static String shortLabel(double citedness) {
    if (citedness >= 2) return 'Q1–Q2';
    if (citedness >= 1) return 'Q2–Q3';
    if (citedness >= 0.3) return 'Q3–Q4';
    return '—';
  }
}

class VenuePublicationStat {
  final String journalName;
  final int worksCount;
  final double citedness;
  final String tierLabel;
  final String? quartile;
  final double? sjr;
  final String? issn;
  final bool fromScimago;

  const VenuePublicationStat({
    required this.journalName,
    required this.worksCount,
    this.citedness = 0,
    required this.tierLabel,
    this.quartile,
    this.sjr,
    this.issn,
    this.fromScimago = false,
  });

  bool get isHighImpact {
    if (fromScimago && quartile != null) {
      return quartile == 'Q1' || quartile == 'Q2';
    }
    return citedness >= 2;
  }

  String get displayTier {
    if (fromScimago && quartile != null) return quartile!;
    return JournalTier.shortLabel(citedness);
  }
}

class SupervisorPublicationMetrics {
  final int worksCount;
  final int citedByCount;
  final int hIndex;
  final List<VenuePublicationStat> topVenues;
  final bool fromOpenAlex;
  final String sourceNote;

  const SupervisorPublicationMetrics({
    this.worksCount = 0,
    this.citedByCount = 0,
    this.hIndex = 0,
    this.topVenues = const [],
    this.fromOpenAlex = false,
    this.sourceNote = '',
  });

  bool get hasData => worksCount > 0 || citedByCount > 0;

  int get highImpactVenueCount =>
      topVenues.where((v) => v.isHighImpact).length;

  int get scimagoMatchedVenueCount =>
      topVenues.where((v) => v.fromScimago).length;
}
