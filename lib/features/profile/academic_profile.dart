import '../academic/faculty_categories.dart';

class AcademicProfile {
  final String fullName;
  final String university;
  final String degree;
  /// معرّف الكلية الموحّد (Science, Medicine, …) — يُستخدم في المطابقة الذكية.
  final String facultyCategory;
  final String specialization;
  final String researchInterest;
  final String methodology;
  final String preferredLanguage;
  final String city;
  final List<String> skills;
  final String? researchJourneyStage;

  const AcademicProfile({
    required this.fullName,
    required this.university,
    required this.degree,
    this.facultyCategory = '',
    required this.specialization,
    required this.researchInterest,
    required this.methodology,
    required this.preferredLanguage,
    required this.city,
    this.skills = const [],
    this.researchJourneyStage,
  });

  /// الكلية المختارة صراحةً أو المستنتجة من التخصص والاهتمام.
  String? get resolvedFacultyCategory {
    if (facultyCategory.trim().isNotEmpty) return facultyCategory.trim();
    return inferFacultyCategoryFromText('$specialization $researchInterest');
  }

  bool get isComplete {
    return fullName.trim().isNotEmpty &&
        university.trim().isNotEmpty &&
        specialization.trim().isNotEmpty &&
        researchInterest.trim().isNotEmpty;
  }

  List<String> get keywords {
    final facultyLabel = resolvedFacultyCategory != null
        ? facultyTitleForCategory(resolvedFacultyCategory!)
        : '';
    final raw = [
      specialization,
      researchInterest,
      university,
      city,
      methodology,
      preferredLanguage,
      facultyLabel,
      ...skills,
    ].join(' ');

    return raw
        .toLowerCase()
        .split(RegExp(r'[\s,،.؛;]+'))
        .map((word) => word.trim())
        .where((word) => word.length >= 2)
        .toSet()
        .toList();
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'university': university,
      'degree': degree,
      'facultyCategory': facultyCategory,
      'specialization': specialization,
      'researchInterest': researchInterest,
      'methodology': methodology,
      'preferredLanguage': preferredLanguage,
      'city': city,
      'skills': skills,
      if (researchJourneyStage != null)
        'researchJourneyStage': researchJourneyStage,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  factory AcademicProfile.fromMap(Map<String, dynamic> map) {
    return AcademicProfile(
      fullName: map['fullName']?.toString() ?? '',
      university: map['university']?.toString() ?? '',
      degree: map['degree']?.toString() ?? 'ماجستير',
      facultyCategory: map['facultyCategory']?.toString() ?? '',
      specialization: map['specialization']?.toString() ?? '',
      researchInterest: map['researchInterest']?.toString() ?? '',
      methodology: map['methodology']?.toString() ?? 'كمي',
      preferredLanguage: map['preferredLanguage']?.toString() ?? 'العربية',
      city: map['city']?.toString() ?? '',
      skills: (map['skills'] as List<dynamic>?)
              ?.map((skill) => skill.toString())
              .toList() ??
          const [],
      researchJourneyStage: map['researchJourneyStage']?.toString(),
    );
  }

  AcademicProfile copyWith({
    String? fullName,
    String? university,
    String? degree,
    String? facultyCategory,
    String? specialization,
    String? researchInterest,
    String? methodology,
    String? preferredLanguage,
    String? city,
    List<String>? skills,
    String? researchJourneyStage,
  }) {
    return AcademicProfile(
      fullName: fullName ?? this.fullName,
      university: university ?? this.university,
      degree: degree ?? this.degree,
      facultyCategory: facultyCategory ?? this.facultyCategory,
      specialization: specialization ?? this.specialization,
      researchInterest: researchInterest ?? this.researchInterest,
      methodology: methodology ?? this.methodology,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      city: city ?? this.city,
      skills: skills ?? this.skills,
      researchJourneyStage: researchJourneyStage ?? this.researchJourneyStage,
    );
  }
}
