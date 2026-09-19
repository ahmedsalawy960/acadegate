import '../supervisor_metrics/scimago_quartile_service.dart';
import 'publish_models.dart';

class JournalPickItem {
  final String id;
  final String name;
  final String publisher;
  final String quartile;
  final double? sjr;
  final String categories;
  final String issn;
  final String submissionUrl;
  final bool isPartner;
  final String? partnerUniversity;
  final bool? supportsIeee;
  final bool? supportsApa;

  const JournalPickItem({
    required this.id,
    required this.name,
    this.publisher = '',
    this.quartile = '',
    this.sjr,
    this.categories = '',
    this.issn = '',
    this.submissionUrl = '',
    this.isPartner = false,
    this.partnerUniversity,
    this.supportsIeee,
    this.supportsApa,
  });

  factory JournalPickItem.fromFirebase(PublishJournal journal) {
    return JournalPickItem(
      id: journal.id ?? 'partner:${journal.name}',
      name: journal.name,
      publisher: journal.publisher,
      quartile: '',
      categories: journal.scopes.join(' • '),
      issn: journal.issn,
      submissionUrl: journal.submissionUrl.trim(),
      isPartner: true,
      partnerUniversity: journal.partnerUniversity,
      supportsIeee: journal.supportsIeee,
      supportsApa: journal.supportsApa,
    );
  }

  factory JournalPickItem.fromScimago(ScimagoJournalInfo journal) {
    return JournalPickItem(
      id: 'scimago:${journal.title}',
      name: journal.title,
      publisher: journal.publisher,
      quartile: journal.quartile,
      sjr: journal.sjr,
      categories: journal.categories,
      issn: journal.issn,
    );
  }
}
