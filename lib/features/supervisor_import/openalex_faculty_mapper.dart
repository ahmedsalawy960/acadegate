import '../academic/faculty_categories.dart';
import 'import_models.dart';

class InferredFaculty {
  final String categoryId;
  final String facultyTitle;
  final String sourceConcept;

  const InferredFaculty({
    required this.categoryId,
    required this.facultyTitle,
    required this.sourceConcept,
  });
}

/// يستنتج كلية AcadeGate من مفاهيم OpenAlex (Medicine → الطب، Computer science → الحاسبات...).
class OpenAlexFacultyMapper {
  OpenAlexFacultyMapper._();

  static InferredFaculty resolve(OpenAlexAuthor author) {
    final scores = <String, double>{};
    var topConcept = author.speciality;

    void addScore(String? categoryId, double weight, String concept) {
      if (categoryId == null || weight <= 0) return;
      scores[categoryId] = (scores[categoryId] ?? 0) + weight;
      if (weight >= 4) topConcept = concept;
    }

    for (var i = 0; i < author.tags.length; i++) {
      final tag = author.tags[i];
      final weight = (5 - i).toDouble();
      addScore(_categoryFromOpenAlexConcept(tag), weight, tag);
      addScore(inferFacultyCategoryFromText(tag), weight * 0.75, tag);
    }

    addScore(_categoryFromOpenAlexConcept(author.speciality), 6, author.speciality);
    addScore(inferFacultyCategoryFromText(author.speciality), 5, author.speciality);

    if (scores.isEmpty) {
      return InferredFaculty(
        categoryId: 'Science',
        facultyTitle: facultyTitleForCategory('Science'),
        sourceConcept: author.speciality,
      );
    }

    final best = scores.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );

    return InferredFaculty(
      categoryId: best.key,
      facultyTitle: facultyTitleForCategory(best.key),
      sourceConcept: topConcept,
    );
  }

  static String categoryIdFor(OpenAlexAuthor author) => resolve(author).categoryId;

  static bool matchesFilter(OpenAlexAuthor author, String? facultyFilterId) {
    if (facultyFilterId == null || facultyFilterId.isEmpty) return true;
    return categoryIdFor(author) == facultyFilterId;
  }

  static String? _categoryFromOpenAlexConcept(String concept) {
    final lower = concept.trim().toLowerCase();
    if (lower.isEmpty) return null;

    for (final entry in _openAlexConceptMap) {
      if (lower == entry.key || lower.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  /// مرتبة من الأطول للأقصر لتفادي تطابق جزئي خاطئ.
  static final List<MapEntry<String, String>> _openAlexConceptMap = [
    const MapEntry('internal medicine', 'Medicine'),
    const MapEntry('electrical engineering', 'Engineering'),
    const MapEntry('mechanical engineering', 'Engineering'),
    const MapEntry('civil engineering', 'Engineering'),
    const MapEntry('chemical engineering', 'Engineering'),
    const MapEntry('computer engineering', 'Engineering'),
    const MapEntry('biomedical engineering', 'Engineering'),
    const MapEntry('industrial engineering', 'Engineering'),
    const MapEntry('environmental engineering', 'Engineering'),
    const MapEntry('structural engineering', 'Engineering'),
    const MapEntry('software engineering', 'CS'),
    const MapEntry('artificial intelligence', 'CS'),
    const MapEntry('machine learning', 'CS'),
    const MapEntry('computer science', 'CS'),
    const MapEntry('data science', 'CS'),
    const MapEntry('information technology', 'CS'),
    const MapEntry('food science', 'Agriculture'),
    const MapEntry('political science', 'Arts'),
    const MapEntry('materials science', 'Science'),
    const MapEntry('molecular biology', 'Science'),
    const MapEntry('cell biology', 'Science'),
    const MapEntry('public health', 'Medicine'),
    const MapEntry('veterinary medicine', 'Veterinary'),
    const MapEntry('physical education', 'PhysicalEducation'),
    const MapEntry('mass communication', 'MassCommunication'),
    const MapEntry('fine arts', 'FineArts'),
    const MapEntry('business administration', 'Business'),
    const MapEntry('medicine', 'Medicine'),
    const MapEntry('surgery', 'Medicine'),
    const MapEntry('cardiology', 'Medicine'),
    const MapEntry('pediatrics', 'Medicine'),
    const MapEntry('oncology', 'Medicine'),
    const MapEntry('nursing', 'Nursing'),
    const MapEntry('dentistry', 'Dentistry'),
    const MapEntry('pharmacy', 'Pharmacy'),
    const MapEntry('pharmacology', 'Pharmacy'),
    const MapEntry('engineering', 'Engineering'),
    const MapEntry('agriculture', 'Agriculture'),
    const MapEntry('nutrition', 'Agriculture'),
    const MapEntry('chemistry', 'Science'),
    const MapEntry('physics', 'Science'),
    const MapEntry('biology', 'Science'),
    const MapEntry('biochemistry', 'Science'),
    const MapEntry('mathematics', 'Science'),
    const MapEntry('geology', 'Science'),
    const MapEntry('law', 'Law'),
    const MapEntry('economics', 'Business'),
    const MapEntry('business', 'Business'),
    const MapEntry('education', 'Education'),
    const MapEntry('architecture', 'Architecture'),
    const MapEntry('veterinary', 'Veterinary'),
    const MapEntry('tourism', 'Tourism'),
    const MapEntry('journalism', 'MassCommunication'),
    const MapEntry('history', 'Arts'),
    const MapEntry('literature', 'Arts'),
    const MapEntry('psychology', 'Arts'),
  ];
}
