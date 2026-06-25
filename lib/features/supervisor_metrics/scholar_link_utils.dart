import '../academic/academic_models.dart';

/// رابط Google Scholar المحفوظ أو رابط بحث مُولَّد.
String resolveScholarUrl(AcademicSupervisor supervisor) {
  final stored = supervisor.scholarUrl.trim();
  if (stored.isNotEmpty) return stored;

  final name = supervisor.name.trim();
  return 'https://scholar.google.com/citations?view_op=search_authors&mauthors=${Uri.encodeComponent(name)}';
}

bool supervisorHasScholarLink(AcademicSupervisor supervisor) {
  return supervisor.scholarUrl.isNotEmpty ||
      supervisor.orcid.isNotEmpty ||
      supervisor.name.trim().isNotEmpty;
}
