import '../home/home_search_utils.dart';
import '../lab_import/nbsle_university_cities.dart';

/// Parsed catalog request — generic for any city, device, or specialty
/// added to Firestore later.
class CatalogIntent {
  final bool wantsLabs;
  final bool wantsSupervisors;
  final String? city;
  final String equipmentQuery;
  final String supervisorQuery;

  const CatalogIntent({
    required this.wantsLabs,
    required this.wantsSupervisors,
    this.city,
    this.equipmentQuery = '',
    this.supervisorQuery = '',
  });

  bool get isCatalogRequest {
    if (wantsLabs) return true;
    if (!wantsSupervisors) return false;
    return hasCity || hasEquipment;
  }

  bool get hasCity => city != null && city!.trim().isNotEmpty;
  bool get hasEquipment => equipmentQuery.trim().length >= 2;
}

class CatalogIntentParser {
  CatalogIntentParser._();

  static CatalogIntent parse(String message) {
    final raw = message.trim();
    if (raw.isEmpty) {
      return const CatalogIntent(
        wantsLabs: false,
        wantsSupervisors: false,
      );
    }

    final lower = raw.toLowerCase();
    final city = _extractCity(raw);
    final wantsSupervisors = _hasSupervisorCue(lower);
    final instrument = _extractInstrument(raw);
    final wantsLabs = _hasLabCue(lower) || instrument.isNotEmpty;

    var equipmentQuery = instrument;
    var supervisorQuery = '';

    if (wantsSupervisors) {
      supervisorQuery = _extractSupervisorQuery(raw);
    }

    if (equipmentQuery.isEmpty && wantsLabs) {
      equipmentQuery = _extractEquipmentFallback(raw, city: city);
    }

    return CatalogIntent(
      wantsLabs: wantsLabs,
      wantsSupervisors: wantsSupervisors,
      city: city,
      equipmentQuery: equipmentQuery,
      supervisorQuery: supervisorQuery,
    );
  }

  static bool _hasLabCue(String lower) {
    const cues = [
      'مختبر',
      'معمل',
      'مختبرات',
      'معامل',
      'جهاز',
      'اجهزه',
      'أجهزة',
      'حجز',
      'تحليل عينات',
      'تحليل عينة',
      'lab',
      'labs',
      'equipment',
      'hplc',
      'gc-ms',
      'gcms',
      'nmr',
      'pcr',
      'ftir',
      'xrd',
      'sem',
      'tem',
      'icp',
      'aas',
      'elisa',
    ];
    return cues.any(lower.contains);
  }

  static bool _hasSupervisorCue(String lower) {
    const cues = [
      'مشرف',
      'مشرفين',
      'supervisor',
      'supervisors',
      'يشرف',
      'أشرفني',
    ];
    return cues.any(lower.contains);
  }

  static String _extractInstrument(String message) {
    final matches = RegExp(
      r'\b([A-Za-z]{2,}(?:-[A-Za-z0-9]+)+|[A-Z]{2,}[A-Za-z0-9]*)\b',
    ).allMatches(message);
    const notInstruments = {
      'AND',
      'OR',
      'FOR',
      'THE',
      'PLUS',
      'WANT',
      'NEED',
      'WITH',
      'FROM',
      'THIS',
      'THAT',
      'AI',
      'APA',
      'IEEE',
      'EGP',
    };
    const knownInstruments = {
      'HPLC',
      'GC',
      'MS',
      'NMR',
      'PCR',
      'FTIR',
      'XRD',
      'SEM',
      'TEM',
      'ICP',
      'AAS',
      'UV',
      'IR',
      'LC',
      'GCMS',
      'ELISA',
    };
    final found = <String>[];
    for (final m in matches) {
      final token = m.group(1) ?? '';
      if (token.length < 2) continue;
      final upper = token.toUpperCase();
      if (_englishStop.contains(token.toLowerCase())) continue;
      if (notInstruments.contains(upper)) continue;
      if (knownInstruments.contains(upper) ||
          upper.contains('-') ||
          (token.length >= 3 && token == token.toUpperCase())) {
        found.add(token);
      }
    }
    if (found.isNotEmpty) return found.first;

    final lower = message.toLowerCase();
    for (final name in const [
      'hplc',
      'gc-ms',
      'gcms',
      'nmr',
      'pcr',
      'ftir',
      'spectrophotometer',
      'كروماتوجراف',
      'مطياف',
    ]) {
      if (lower.contains(name)) return name;
    }
    return '';
  }

  static String _extractSupervisorQuery(String message) {
    final match = RegExp(
      r'(?:مشرف(?:ين)?|supervisor(?:s)?)\s*(?:في|عن|ل|لـ|for|in)?\s*(.+)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(message);
    var text = (match?.group(1) ?? message).trim();
    text = text.replaceAll(RegExp(r'[+＋]'), ' ');
    text = text.replaceAll(
      RegExp(r'^(?:في|عن|ل|لـ|for|in)\s+', caseSensitive: false),
      '',
    );
    return _collapse(text);
  }

  static String _extractEquipmentFallback(String message, {String? city}) {
    var text = message;
    if (city != null) {
      text = text.replaceAll(RegExp(RegExp.escape(city), caseSensitive: false), ' ');
      for (final alias in _cityAliases.keys) {
        if (_cityAliases[alias] == city) {
          text = text.replaceAll(
            RegExp(RegExp.escape(alias), caseSensitive: false),
            ' ',
          );
        }
      }
    }
    for (final noise in _noisePatterns) {
      text = text.replaceAll(noise, ' ');
    }
    text = text.replaceAll(RegExp(r'[+＋]'), ' ');
    return _collapse(text);
  }

  static String? _extractCity(String message) {
    final normalizedMessage = normalizeSearchText(message);
    final entries = _cityAliases.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    for (final entry in entries) {
      final needle = normalizeSearchText(entry.key);
      if (needle.length < 2) continue;
      if (normalizedMessage.contains(needle)) {
        return NbsleUniversityCities.canonicalCity(entry.value);
      }
    }
    return null;
  }

  static String _collapse(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static const _englishStop = {
    'in',
    'at',
    'the',
    'for',
    'and',
    'or',
    'with',
    'want',
    'need',
    'lab',
    'labs',
    'plus',
  };

  static final _noisePatterns = [
    RegExp(
      r'(?:أريد|اريد|عايز|محتاج|ممكن|لو سمحت|في|الى|إلى|من|على|و|مع|'
      r'جهاز|مختبر|معمل|حجز|تحليل|عينات|عينة|مشرف(?:ين)?|'
      r'i want|need|please|a|an|the|lab|labs|equipment|supervisor(?:s)?)',
      caseSensitive: false,
    ),
  ];

  static Map<String, String> get _cityAliases {
    final map = <String, String>{};
    for (final city in NbsleUniversityCities.browseCities) {
      map[city] = city;
    }
    map['الزقازيق'] = 'الشرقية';
    map['zagazig'] = 'الشرقية';
    map['sharqia'] = 'الشرقية';
    map['sharkia'] = 'الشرقية';
    map['cairo'] = 'القاهرة';
    map['alexandria'] = 'الإسكندرية';
    map['alex'] = 'الإسكندرية';
    return map;
  }
}
