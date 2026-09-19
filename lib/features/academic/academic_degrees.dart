/// Shared degree options for profiles, matchmaking, and writing orders.
class AcademicDegreeOption {
  final String value;
  final String labelAr;
  final String labelEn;

  const AcademicDegreeOption({
    required this.value,
    required this.labelAr,
    required this.labelEn,
  });
}

const academicDegreeOptions = <AcademicDegreeOption>[
  AcademicDegreeOption(
    value: 'ماجستير',
    labelAr: 'ماجستير أكاديمي',
    labelEn: 'Academic Master\'s',
  ),
  AcademicDegreeOption(
    value: 'ماجستير مهني',
    labelAr: 'ماجستير مهني',
    labelEn: 'Professional Master\'s',
  ),
  AcademicDegreeOption(
    value: 'MBA',
    labelAr: 'MBA / EMBA',
    labelEn: 'MBA / EMBA',
  ),
  AcademicDegreeOption(
    value: 'MPA',
    labelAr: 'MPA (إدارة عامة / محاسبة)',
    labelEn: 'MPA (public admin / accounting)',
  ),
  AcademicDegreeOption(
    value: 'دبلوم دراسات عليا',
    labelAr: 'دبلوم دراسات عليا',
    labelEn: 'Postgraduate diploma',
  ),
  AcademicDegreeOption(
    value: 'دكتوراه',
    labelAr: 'دكتوراه أكاديمية (PhD)',
    labelEn: 'Academic doctorate (PhD)',
  ),
  AcademicDegreeOption(
    value: 'دكتوراه مهنية',
    labelAr: 'دكتوراه مهنية (DBA / DPA / EdD)',
    labelEn: 'Professional doctorate (DBA / DPA / EdD)',
  ),
];

bool isDoctoralDegree(String degree) {
  final d = degree.toLowerCase();
  return d.contains('دكتوراه') ||
      d.contains('phd') ||
      d.contains('dba') ||
      d.contains('dpa') ||
      d.contains('edd') ||
      d.contains('dnp') ||
      d.contains('doctorate');
}

bool isMastersLevelDegree(String degree) {
  final d = degree.toLowerCase();
  return d.contains('ماجستير') ||
      d.contains('master') ||
      d.contains('mba') ||
      d.contains('mpa') ||
      d.contains('emba') ||
      d.contains('mha') ||
      d.contains('mpm') ||
      d.contains('mph');
}

bool isDiplomaDegree(String degree) {
  final d = degree.toLowerCase();
  return d.contains('دبلوم') || d.contains('diploma') || d.contains('pgdip');
}
