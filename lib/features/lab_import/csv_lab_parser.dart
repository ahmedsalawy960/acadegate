import '../academic/academic_models.dart';
import '../academic/faculty_categories.dart';

class CsvLabRow {
  final String name;
  final String university;
  final String city;
  final String location;
  final String labType;
  final String category;
  final String description;
  final List<String> tags;
  final List<String> sampleServices;
  final List<String> equipmentNames;
  final String contactEmail;
  final bool acceptsExternalSamples;

  const CsvLabRow({
    required this.name,
    this.university = '',
    this.city = '',
    this.location = '',
    this.labType = 'research_center',
    this.category = 'Science',
    this.description = '',
    this.tags = const [],
    this.sampleServices = const [],
    this.equipmentNames = const [],
    this.contactEmail = '',
    this.acceptsExternalSamples = true,
  });
}

class CsvLabParser {
  CsvLabParser._();

  static const _headerAliases = {
    'name': ['name', 'الاسم', 'اسم', 'lab_name', 'lab'],
    'university': ['university', 'الجامعة', 'جامعة', 'institution'],
    'city': ['city', 'المدينة', 'مدينة'],
    'location': ['location', 'الموقع', 'موقع', 'address', 'العنوان'],
    'labtype': ['labtype', 'lab_type', 'type', 'النوع', 'نوع'],
    'category': ['category', 'التخصص', 'تخصص', 'قسم'],
    'faculty': ['faculty', 'college', 'الكلية', 'كلية', 'facultyname', 'faculty_name'],
    'description': ['description', 'وصف', 'bio', 'details'],
    'tags': ['tags', 'وسوم', 'keywords'],
    'sampleservices': [
      'sampleservices',
      'sample_services',
      'services',
      'تحليل',
      'خدمات',
    ],
    'equipment': ['equipment', 'devices', 'أجهزة', 'اجهزة'],
    'contactemail': ['contactemail', 'email', 'بريد', 'contact'],
    'acceptsexternalsamples': [
      'acceptsexternalsamples',
      'external',
      'عينات_خارجية',
    ],
  };

  static String templateCsv() {
    return 'name,university,city,location,labType,faculty,description,sampleServices,equipment,tags,contactEmail\n'
        'مركز تحليل المواد,جامعة القاهرة,القاهرة,كلية العلوم,research_center,كلية العلوم,'
        'منشأة تحليل مركزية,"SEM;XRD;FTIR","SEM;XRD","تحليل;مواد",lab@cairouniv.edu.eg\n'
        'مركز البحوث الطبية,جامعة عين شمس,القاهرة,مستشفى عين شمس,research_center,كلية الطب,'
        'تحليل عينات سريرية,"HPLC;PCR","HPLC","طب;تحليل",research@aun.edu.eg\n';
  }

  static List<CsvLabRow> parse(String content) {
    final lines = _splitLines(content);
    if (lines.isEmpty) return [];

    final delimiter = _detectDelimiter(lines.first);
    final headerCells = _parseLine(lines.first, delimiter);
    final columnMap = _mapHeaders(headerCells);

    if (!columnMap.containsKey('name')) {
      throw FormatException('الملف يجب أن يحتوي على عمود name أو الاسم');
    }

    final rows = <CsvLabRow>[];
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final cells = _parseLine(line, delimiter);
      rows.add(_rowFromCells(cells, columnMap));
    }
    return rows;
  }

  static CsvLabRow _rowFromCells(
    List<String> cells,
    Map<String, int> columnMap,
  ) {
    String cell(String key) {
      final index = columnMap[key];
      if (index == null || index >= cells.length) return '';
      return cells[index].trim();
    }

    List<String> splitList(String raw) {
      if (raw.isEmpty) return const [];
      return raw
          .split(RegExp(r'[؛;،,|]'))
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList();
    }

    final labType = _normalizeLabType(cell('labtype'));
    final facultyRaw = cell('faculty').isNotEmpty
        ? cell('faculty')
        : cell('category');
    final category = _normalizeCategory(facultyRaw);

    return CsvLabRow(
      name: cell('name'),
      university: cell('university'),
      city: cell('city'),
      location: cell('location'),
      labType: labType,
      category: category,
      description: cell('description'),
      tags: splitList(cell('tags')),
      sampleServices: splitList(cell('sampleservices')),
      equipmentNames: splitList(cell('equipment')),
      contactEmail: cell('contactemail'),
      acceptsExternalSamples: _parseBool(cell('acceptsexternalsamples'), defaultValue: true),
    );
  }

  static String _normalizeLabType(String raw) {
    final value = raw.toLowerCase();
    if (value.contains('core') || value.contains('مركزية')) {
      return 'core_facility';
    }
    if (value.contains('research') || value.contains('بحوث') || value.contains('بحث')) {
      return 'research_center';
    }
    if (value.contains('university') || value.contains('جامع')) {
      return 'university_lab';
    }
    return raw.isEmpty ? 'research_center' : raw;
  }

  static String _normalizeCategory(String raw) {
    if (raw.isEmpty) return 'Science';
    return resolveFacultyId(raw) ?? raw;
  }

  static bool _parseBool(String raw, {required bool defaultValue}) {
    if (raw.isEmpty) return defaultValue;
    final value = raw.toLowerCase();
    if (value == 'true' || value == '1' || value == 'نعم' || value == 'yes') {
      return true;
    }
    if (value == 'false' || value == '0' || value == 'لا' || value == 'no') {
      return false;
    }
    return defaultValue;
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
    if (headerLine.contains(';')) return ';';
    if (headerLine.contains('\t')) return '\t';
    return ',';
  }

  static List<String> _parseLine(String line, String delimiter) {
    final result = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == delimiter && !inQuotes) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    result.add(buffer.toString());
    return result.map((cell) => cell.trim()).toList();
  }

  static Map<String, int> _mapHeaders(List<String> headers) {
    final map = <String, int>{};
    for (var i = 0; i < headers.length; i++) {
      final normalized = headers[i]
          .trim()
          .toLowerCase()
          .replaceAll(' ', '')
          .replaceAll('_', '');
      for (final entry in _headerAliases.entries) {
        if (entry.value.any((alias) => normalized == alias.replaceAll('_', ''))) {
          map.putIfAbsent(entry.key, () => i);
        }
      }
    }
    return map;
  }
}

Map<String, dynamic> csvLabRowToFirestoreMap(CsvLabRow row) {
  final facultyId = resolveFacultyId(row.category) ?? row.category;
  final facultyNameAr = facultyNameForStorage(facultyId);

  final equipmentList = row.equipmentNames
      .map(
        (name) => {
          'id': name.toLowerCase().replaceAll(' ', '-'),
          'name': name,
          'code': name,
          'costPerSession': 0,
          'durationMinutes': 120,
          'waitDays': 5,
        },
      )
      .toList();

  final sampleServices = row.sampleServices
      .map(
          (name) => SampleAnalysisService(
            id: name.toLowerCase().replaceAll(' ', '-'),
            name: name,
            specialties: [facultyId],
          ).toMap(),
      )
      .toList();

  return {
    'name': row.name,
    'university': row.university,
    'city': row.city,
    'location': row.location.isNotEmpty
        ? row.location
        : [row.university, row.city].where((part) => part.isNotEmpty).join(' — '),
    'labType': row.labType,
    'facultyId': facultyId,
    'facultyNameAr': facultyNameAr,
    'category': facultyId,
    'description': row.description.isNotEmpty
        ? row.description
        : 'مختبر/مركز بحوث — ${row.name}',
    'tags': row.tags,
    'equipment': row.equipmentNames.join('، '),
    'equipmentList': equipmentList,
    'sampleServices': sampleServices,
    'acceptsExternalSamples': row.acceptsExternalSamples,
    if (row.contactEmail.isNotEmpty) 'contactEmail': row.contactEmail,
    'waitDays': 5,
    'importSource': 'csv',
  };
}
