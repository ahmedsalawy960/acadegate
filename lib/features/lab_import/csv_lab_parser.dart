import '../academic/academic_models.dart';
import '../academic/faculty_categories.dart';
import '../../core/locale/app_translate.dart';

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
  /// Optional prices aligned by index with [sampleServices] (0 = unknown).
  final List<num> sampleServicePrices;
  /// Optional prices aligned by index with [equipmentNames] (0 = unknown).
  final List<num> equipmentPrices;
  final String contactEmail;
  final String contactPhone;
  final String contactName;
  final List<Map<String, dynamic>> contacts;
  final bool acceptsExternalSamples;
  final String importSource;
  final String sourceUrl;
  final String externalId;

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
    this.sampleServicePrices = const [],
    this.equipmentPrices = const [],
    this.contactEmail = '',
    this.contactPhone = '',
    this.contactName = '',
    this.contacts = const [],
    this.acceptsExternalSamples = true,
    this.importSource = 'csv',
    this.sourceUrl = '',
    this.externalId = '',
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
        'منشأة تحليل مركزية,"SEM:800;XRD:600;FTIR:350","SEM:800;XRD:600","تحليل;مواد",lab@cairouniv.edu.eg\n'
        'مركز البحوث الطبية,جامعة عين شمس,القاهرة,مستشفى عين شمس,research_center,كلية الطب,'
        'تحليل عينات سريرية,"HPLC:500;PCR:400","HPLC:500","طب;تحليل",research@aun.edu.eg\n';
  }

  static List<CsvLabRow> parse(String content) {
    final lines = _splitLines(content);
    if (lines.isEmpty) return [];

    final delimiter = _detectDelimiter(lines.first);
    final headerCells = _parseLine(lines.first, delimiter);
    final columnMap = _mapHeaders(headerCells);

    if (!columnMap.containsKey('name')) {
      throw FormatException(
        appTr(
          'الملف يجب أن يحتوي على عمود name أو الاسم',
          'File must contain a name or الاسم column',
        ),
      );
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

    /// Supports `SEM` or `SEM:800` (name:price).
    ({List<String> names, List<num> prices}) splitNamedPrices(String raw) {
      final names = <String>[];
      final prices = <num>[];
      for (final part in splitList(raw)) {
        final sep = part.lastIndexOf(':');
        if (sep > 0) {
          final name = part.substring(0, sep).trim();
          final price = num.tryParse(part.substring(sep + 1).trim()) ?? 0;
          if (name.isEmpty) continue;
          names.add(name);
          prices.add(price);
        } else {
          names.add(part);
          prices.add(0);
        }
      }
      return (names: names, prices: prices);
    }

    final labType = _normalizeLabType(cell('labtype'));
    final facultyRaw = cell('faculty').isNotEmpty
        ? cell('faculty')
        : cell('category');
    final category = _normalizeCategory(facultyRaw);
    final services = splitNamedPrices(cell('sampleservices'));
    final equipment = splitNamedPrices(cell('equipment'));

    return CsvLabRow(
      name: cell('name'),
      university: cell('university'),
      city: cell('city'),
      location: cell('location'),
      labType: labType,
      category: category,
      description: cell('description'),
      tags: splitList(cell('tags')),
      sampleServices: services.names,
      sampleServicePrices: services.prices,
      equipmentNames: equipment.names,
      equipmentPrices: equipment.prices,
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

  final equipmentList = <Map<String, dynamic>>[];
  for (var i = 0; i < row.equipmentNames.length; i++) {
    final name = row.equipmentNames[i];
    final price = i < row.equipmentPrices.length ? row.equipmentPrices[i] : 0;
    equipmentList.add({
      'id': name.toLowerCase().replaceAll(' ', '-'),
      'name': name,
      'code': name,
      'costPerSession': price,
      'durationMinutes': 120,
      'waitDays': 5,
    });
  }

  final sampleServices = <Map<String, dynamic>>[];
  for (var i = 0; i < row.sampleServices.length; i++) {
    final name = row.sampleServices[i];
    final price =
        i < row.sampleServicePrices.length ? row.sampleServicePrices[i] : 0;
    sampleServices.add(
      SampleAnalysisService(
        id: name.toLowerCase().replaceAll(' ', '-'),
        name: name,
        specialties: [facultyId],
        priceFrom: price,
        turnaroundDays: 5,
      ).toMap(),
    );
  }

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
        : appTr(
            'مختبر/مركز بحوث — ${row.name}',
            'Lab/research center — ${row.name}',
          ),
    'tags': row.tags,
    'equipment': row.equipmentNames.join('، '),
    'equipmentList': equipmentList,
    'sampleServices': sampleServices,
    'acceptsExternalSamples': row.acceptsExternalSamples,
    if (row.contactEmail.isNotEmpty) 'contactEmail': row.contactEmail,
    if (row.contactPhone.isNotEmpty) 'contactPhone': row.contactPhone,
    if (row.contactName.isNotEmpty) 'contactName': row.contactName,
    if (row.contacts.isNotEmpty) 'contacts': row.contacts,
    'waitDays': 5,
    'importSource':
        row.importSource.isNotEmpty ? row.importSource : 'csv',
    if (row.sourceUrl.isNotEmpty) 'sourceUrl': row.sourceUrl,
    if (row.externalId.isNotEmpty) 'externalId': row.externalId,
    if (row.importSource == 'nbsle' && row.externalId.isNotEmpty)
      'nbsleLabId': row.externalId,
    if (row.importSource == 'crci' && row.externalId.isNotEmpty)
      'crciCenterId': row.externalId,
  };
}
