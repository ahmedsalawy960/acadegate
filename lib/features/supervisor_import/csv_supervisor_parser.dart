import '../../core/locale/l10n_lookup.dart';
import 'import_models.dart';
import '../academic/faculty_categories.dart';

class CsvSupervisorParser {
  CsvSupervisorParser._();

  static const _headerAliases = {
    'name': ['name', 'الاسم', 'اسم', 'full_name', 'display_name'],
    'university': ['university', 'الجامعة', 'جامعة', 'institution'],
    'speciality': [
      'speciality',
      'specialty',
      'التخصص',
      'تخصص',
      'field',
      'major',
    ],
    'bio': ['bio', 'نبذة', 'description', 'about'],
    'faculty': ['faculty', 'الكلية', 'كلية', 'college', 'department'],
    'category': ['category', 'القسم', 'قسم', 'تصنيف'],
    'tags': ['tags', 'وسوم', 'keywords', 'كلمات'],
    'methodologies': ['methodologies', 'methodology', 'المنهجية', 'منهجية'],
    'isavailable': ['isavailable', 'available', 'متاح', 'is_available'],
    'orcid': ['orcid'],
    'scholarurl': ['scholarurl', 'scholar', 'google_scholar', 'scholar_url'],
    'researchgateurl': [
      'researchgateurl',
      'researchgate',
      'research_gate',
      'rg_url',
    ],
  };

  static List<CsvSupervisorRow> parse(String content) {
    final lines = _splitLines(content);
    if (lines.isEmpty) return [];

    final delimiter = _detectDelimiter(lines.first);
    final headerCells = _parseLine(lines.first, delimiter);
    final columnMap = _mapHeaders(headerCells);

    if (!columnMap.containsKey('name')) {
      throw FormatException(L10nLookup.csvMissingNameColumn());
    }

    final rows = <CsvSupervisorRow>[];
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final cells = _parseLine(line, delimiter);
      final row = _rowFromCells(cells, columnMap);
      if (row.name.trim().isNotEmpty) rows.add(row);
    }

    return rows;
  }

  static String templateCsv() {
    return 'name,university,speciality,bio,faculty,category,tags,orcid,scholarUrl,researchGateUrl\n'
        'د. أحمد محمد,جامعة القاهرة,ذكاء اصطناعي,أستاذ مساعد...,كلية الهندسة,Engineering,"AI,ML",,,\n'
        'Dr. Sara Ali,Cairo University,Statistics,Associate professor...,Science,Science,"SPSS,data",0000-0002-1234-5678,,';
  }

  static List<String> _splitLines(String content) {
    return content
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
  }

  static String _detectDelimiter(String headerLine) {
    if (headerLine.contains('\t')) return '\t';
    if (headerLine.contains(';')) return ';';
    return ',';
  }

  static Map<String, int> _mapHeaders(List<String> headers) {
    final map = <String, int>{};
    for (var i = 0; i < headers.length; i++) {
      final normalized = _normalizeHeader(headers[i]);
      for (final entry in _headerAliases.entries) {
        if (entry.value.contains(normalized)) {
          map.putIfAbsent(entry.key, () => i);
        }
      }
    }
    return map;
  }

  static String _normalizeHeader(String value) {
    return value.trim().toLowerCase().replaceAll(' ', '_');
  }

  static CsvSupervisorRow _rowFromCells(
    List<String> cells,
    Map<String, int> columnMap,
  ) {
    String cell(String key, {String fallback = ''}) {
      final index = columnMap[key];
      if (index == null || index >= cells.length) return fallback;
      return cells[index].trim();
    }

    List<String> listCell(String key) {
      final raw = cell(key);
      if (raw.isEmpty) return const [];
      return raw
          .split(RegExp(r'[؛;|/]'))
          .expand((part) => part.split(RegExp(r'[،,]')))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    bool boolCell(String key, {bool fallback = true}) {
      final raw = cell(key).toLowerCase();
      if (raw.isEmpty) return fallback;
      if (['0', 'false', 'no', 'لا', 'غير متاح'].contains(raw)) {
        return false;
      }
      return true;
    }

    return CsvSupervisorRow(
      name: cell('name'),
      university: cell('university'),
      speciality: cell('speciality'),
      bio: cell('bio'),
      faculty: cell('faculty'),
      category: _normalizeCategory(cell('category')),
      tags: listCell('tags'),
      methodologies: listCell('methodologies').isEmpty
          ? L10nLookup.defaultMethodologies
          : listCell('methodologies'),
      isAvailable: boolCell('isavailable'),
      orcid: cell('orcid').isEmpty ? null : cell('orcid'),
      scholarUrl: cell('scholarurl').isEmpty ? null : cell('scholarurl'),
      researchGateUrl:
          cell('researchgateurl').isEmpty ? null : cell('researchgateurl'),
    );
  }

  static String _normalizeCategory(String value) {
    final v = value.trim().toLowerCase();
    const map = {
      'engineering': 'Engineering',
      'هندسة': 'Engineering',
      'هندسي': 'Engineering',
      'science': 'Science',
      'علوم': 'Science',
      'medicine': 'Medicine',
      'طب': 'Medicine',
      'dentistry': 'Dentistry',
      'أسنان': 'Dentistry',
      'pharmacy': 'Pharmacy',
      'صيدلة': 'Pharmacy',
      'nursing': 'Nursing',
      'تمريض': 'Nursing',
      'veterinary': 'Veterinary',
      'بيطري': 'Veterinary',
      'law': 'Law',
      'حقوق': 'Law',
      'cs': 'CS',
      'computer': 'CS',
      'حاسبات': 'CS',
      'agriculture': 'Agriculture',
      'زراعة': 'Agriculture',
      'business': 'Business',
      'تجارة': 'Business',
      'education': 'Education',
      'تربية': 'Education',
      'arts': 'Arts',
      'آداب': 'Arts',
      'architecture': 'Architecture',
      'عمارة': 'Architecture',
      'masscommunication': 'MassCommunication',
      'إعلام': 'MassCommunication',
      'tourism': 'Tourism',
      'سياحة': 'Tourism',
      'physicaleducation': 'PhysicalEducation',
      'رياضية': 'PhysicalEducation',
      'finearts': 'FineArts',
      'فنون': 'FineArts',
    };
    if (map.containsKey(v)) return map[v]!;
    final byTitle = facultyById(value);
    if (byTitle != null) return byTitle.id;
    for (final faculty in facultyCategories) {
      if (faculty.titleAr == value.trim()) return faculty.id;
    }
    return value.isEmpty ? facultyCategories.first.id : value;
  }

  static List<String> _parseLine(String line, String delimiter) {
    final cells = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == delimiter && !inQuotes) {
        cells.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    cells.add(buffer.toString());
    return cells;
  }
}
