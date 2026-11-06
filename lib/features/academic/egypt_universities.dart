import '../lab_import/nbsle_university_cities.dart';

/// Egyptian universities for registration / academic profile dropdowns.
class EgyptUniversities {
  EgyptUniversities._();

  /// Sentinel so the user can type a university not in the catalog.
  static const otherValue = '__other_university__';

  static List<String> get names => NbsleUniversityCities.browseUniversities;

  static bool isKnown(String university) {
    final t = university.trim();
    if (t.isEmpty) return false;
    return names.any((n) => n == t);
  }

  /// Dropdown value for a stored university name (or [otherValue]).
  static String? dropdownValueFor(String university) {
    final t = university.trim();
    if (t.isEmpty) return null;
    if (isKnown(t)) return t;
    return otherValue;
  }
}
