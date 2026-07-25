/// رابط بحث Google Scholar للتحقق اليدوي — لا يوجد API رسمي مجاني.
String buildGoogleScholarSearchUrl({
  required String query,
  int? year,
}) {
  var q = query.trim();
  if (q.length > 180) {
    q = q.substring(0, 180);
  }
  if (year != null) {
    q = '$q $year';
  }
  return 'https://scholar.google.com/scholar?q=${Uri.encodeComponent(q)}';
}
