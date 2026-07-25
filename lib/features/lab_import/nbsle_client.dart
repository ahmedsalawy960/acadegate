import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'csv_lab_parser.dart';
import 'nbsle_device_detail.dart';
import 'nbsle_university_cities.dart';

/// Progress while scraping the public NBSLE all-devices registry.
class NbsleScrapeProgress {
  final int page;
  final int totalPages;
  final int devicesSeen;
  final int labsSoFar;

  const NbsleScrapeProgress({
    required this.page,
    required this.totalPages,
    required this.devicesSeen,
    required this.labsSoFar,
  });

  double get fraction =>
      totalPages <= 0 ? 0 : (page / totalPages).clamp(0.0, 1.0);
}

/// One device row from https://nbsle.scu.eg/all-devices
class NbsleDeviceRow {
  final int? deviceId;
  final int? labId;
  final String deviceName;
  final String labName;
  final String university;
  final String faculty;
  final String sourceUrl;

  const NbsleDeviceRow({
    this.deviceId,
    this.labId,
    required this.deviceName,
    required this.labName,
    required this.university,
    required this.faculty,
    this.sourceUrl = '',
  });
}

/// Scrapes the public NBSLE browse pages (no official API).
///
/// Works on Windows/Android/iOS. Flutter web is blocked by CORS.
class NbsleClient {
  NbsleClient._();

  static final NbsleClient instance = NbsleClient._();

  static const baseHost = 'https://nbsle.scu.eg';
  static const _userAgent =
      'AcadeGate/1.0 (lab discovery; +https://acadegate.app)';

  /// Fetch all device pages, group into labs, optionally enrich contacts
  /// from one device detail page per lab.
  Future<List<CsvLabRow>> scrapeLabs({
    int? maxPages,
    Duration delayBetweenPages = const Duration(milliseconds: 80),
    int concurrency = 5,
    bool enrichContacts = true,
    int contactEnrichConcurrency = 4,
    void Function(NbsleScrapeProgress progress)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    if (kIsWeb) {
      throw StateError(
        'استيراد NBSLE غير متاح على الويب بسبب قيود CORS — استخدم تطبيق Windows/Android',
      );
    }

    final totalPages = await fetchTotalPages();
    final pagesToFetch =
        maxPages == null ? totalPages : totalPages.clamp(1, maxPages);

    final devices = <NbsleDeviceRow>[];
    final failedPages = <int>[];
    var nextPage = 1;
    var completedPages = 0;

    Future<void> worker() async {
      while (true) {
        if (shouldCancel?.call() == true) {
          throw StateError('cancelled');
        }
        final page = nextPage;
        if (page > pagesToFetch) return;
        nextPage++;

        try {
          final rows = await fetchDevicesPage(page, retries: 3);
          devices.addAll(rows);
        } catch (e) {
          failedPages.add(page);
          // Continue other pages — one timeout must not abort ~1500 pages.
          debugPrint('NBSLE page $page failed: $e');
        }

        completedPages++;
        onProgress?.call(
          NbsleScrapeProgress(
            page: completedPages.clamp(1, pagesToFetch),
            totalPages: pagesToFetch,
            devicesSeen: devices.length,
            labsSoFar: _estimateLabCount(devices),
          ),
        );
        if (delayBetweenPages > Duration.zero) {
          await Future<void>.delayed(delayBetweenPages);
        }
      }
    }

    await Future.wait(
      List.generate(concurrency.clamp(1, 8), (_) => worker()),
    );

    if (shouldCancel?.call() == true) {
      throw StateError('cancelled');
    }

    if (devices.isEmpty) {
      throw StateError(
        'تعذر قراءة أي صفحة من NBSLE'
        '${failedPages.isNotEmpty ? ' (فشل ${failedPages.length} صفحة)' : ''}',
      );
    }

    final labs = groupDevicesIntoLabs(devices);
    if (failedPages.isNotEmpty) {
      debugPrint(
        'NBSLE scrape finished with ${failedPages.length} failed pages '
        '(e.g. ${failedPages.take(5).join(', ')})',
      );
    }
    if (!enrichContacts || labs.isEmpty) return labs;
    return enrichLabContacts(
      labs,
      concurrency: contactEnrichConcurrency,
      shouldCancel: shouldCancel,
      onProgress: onProgress == null
          ? null
          : (done, total) {
              onProgress(
                NbsleScrapeProgress(
                  page: pagesToFetch,
                  totalPages: pagesToFetch,
                  devicesSeen: devices.length,
                  labsSoFar: done,
                ),
              );
            },
    );
  }

  /// Fetch one device detail page per lab to fill staff/coordinator contacts.
  Future<List<CsvLabRow>> enrichLabContacts(
    List<CsvLabRow> labs, {
    int concurrency = 4,
    void Function(int done, int total)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    final detailClient = NbsleDeviceDetailClient.instance;
    final results = List<CsvLabRow>.from(labs);
    var next = 0;
    var done = 0;

    Future<void> worker() async {
      while (true) {
        if (shouldCancel?.call() == true) return;
        final i = next;
        if (i >= results.length) return;
        next++;
        final row = results[i];
        final url = row.sourceUrl.trim();
        if (url.contains('/device/')) {
          try {
            final detail = await detailClient.fetch(url);
            if (detail.contacts.isNotEmpty ||
                detail.bestEmail.isNotEmpty ||
                detail.bestPhone.isNotEmpty) {
              results[i] = CsvLabRow(
                name: row.name,
                university: row.university,
                city: row.city,
                location: row.location,
                labType: row.labType,
                category: row.category,
                description: row.description,
                tags: row.tags,
                sampleServices: row.sampleServices,
                equipmentNames: row.equipmentNames,
                sampleServicePrices: row.sampleServicePrices,
                equipmentPrices: row.equipmentPrices,
                contactEmail: detail.bestEmail.isNotEmpty
                    ? detail.bestEmail
                    : row.contactEmail,
                contactPhone: detail.bestPhone.isNotEmpty
                    ? detail.bestPhone
                    : row.contactPhone,
                contactName: detail.bestName.isNotEmpty
                    ? detail.bestName
                    : row.contactName,
                contacts: detail.contacts.map((c) => c.toMap()).toList(),
                acceptsExternalSamples: row.acceptsExternalSamples,
                importSource: row.importSource,
                sourceUrl: row.sourceUrl,
                externalId: row.externalId,
              );
            }
          } catch (e) {
            debugPrint('NBSLE contact enrich ${row.name}: $e');
          }
        }
        done++;
        onProgress?.call(done, results.length);
      }
    }

    await Future.wait(
      List.generate(concurrency.clamp(1, 8), (_) => worker()),
    );
    return results;
  }

  Future<int> fetchTotalPages() async {
    final html = await _getHtml('$baseHost/all-devices');
    final matches = RegExp(r'all-devices\?page=(\d+)').allMatches(html);
    var maxPage = 1;
    for (final match in matches) {
      final value = int.tryParse(match.group(1) ?? '') ?? 1;
      if (value > maxPage) maxPage = value;
    }
    return maxPage;
  }

  Future<List<NbsleDeviceRow>> fetchDevicesPage(
    int page, {
    int retries = 3,
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= retries; attempt++) {
      try {
        final html = await _getHtml('$baseHost/all-devices?page=$page');
        return parseDevicesPage(html);
      } catch (e) {
        lastError = e;
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
    throw StateError('NBSLE page $page failed after $retries tries: $lastError');
  }

  /// Exposed for tests / offline tools.
  static List<NbsleDeviceRow> parseDevicesPage(String html) {
    final rows = <NbsleDeviceRow>[];
    final rowRe = RegExp(
      r'<tr>\s*<td>\d+</td>\s*<td>([^<]+)</td>\s*<td>[\s\S]*?</td>\s*'
      r'<td>([^<]+)</td>\s*<td>([^<]+)</td>\s*<td>([^<]+)</td>[\s\S]*?'
      r'href="(https://nbsle\.scu\.eg/device/[^"]+)"',
      caseSensitive: false,
    );

    for (final match in rowRe.allMatches(html)) {
      final deviceName = _decodeHtml(match.group(1)?.trim() ?? '');
      final labName = _decodeHtml(match.group(2)?.trim() ?? '');
      final university = _decodeHtml(match.group(3)?.trim() ?? '');
      final faculty = _decodeHtml(match.group(4)?.trim() ?? '');
      final url = match.group(5)?.trim() ?? '';
      if (deviceName.isEmpty || labName.isEmpty) continue;

      final ids = _parseDeviceUrl(url);
      rows.add(
        NbsleDeviceRow(
          deviceId: ids.$1,
          labId: ids.$2,
          deviceName: deviceName,
          labName: labName,
          university: university,
          faculty: faculty,
          sourceUrl: url,
        ),
      );
    }
    return rows;
  }

  static List<CsvLabRow> groupDevicesIntoLabs(
    List<NbsleDeviceRow> devices, {
    int maxEquipmentPerLab = 120,
  }) {
    final buckets = <String, _LabBucket>{};

    for (final device in devices) {
      final key = device.labId != null
          ? 'id:${device.labId}'
          : 'name:${device.labName.toLowerCase()}|'
              '${device.university.toLowerCase()}|'
              '${device.faculty.toLowerCase()}';

      final bucket = buckets.putIfAbsent(
        key,
        () => _LabBucket(
          labId: device.labId,
          name: device.labName,
          university: device.university,
          faculty: device.faculty,
          sourceUrl: device.sourceUrl,
        ),
      );
      bucket.equipment.add(device.deviceName);
      if (bucket.sourceUrl.isEmpty && device.sourceUrl.isNotEmpty) {
        bucket.sourceUrl = device.sourceUrl;
      }
    }

    final rows = <CsvLabRow>[];
    for (final bucket in buckets.values) {
      final equipment = bucket.equipment.toList()..sort();
      final capped = equipment.take(maxEquipmentPerLab).toList();
      final city = NbsleUniversityCities.cityFor(bucket.university);
      final facultyAr = _facultyLabelAr(bucket.faculty);
      final facultyId = _facultyIdFor(bucket.faculty);
      final uniAr = NbsleUniversityCities.arabicName(bucket.university);

      rows.add(
        CsvLabRow(
          name: bucket.name,
          university: uniAr.isNotEmpty ? uniAr : bucket.university,
          city: city,
          location: [
            if (facultyAr.isNotEmpty) facultyAr,
            if (uniAr.isNotEmpty) uniAr else bucket.university,
          ].join(' — '),
          labType: 'university_lab',
          category: facultyId,
          description:
              'مستورد من البنك القومي للمعامل والأجهزة العلمية (NBSLE) — '
              '${bucket.faculty} / ${bucket.university}. '
              'المصدر: $baseHost',
          tags: const ['NBSLE', 'مصر'],
          equipmentNames: capped,
          equipmentPrices: List<num>.filled(capped.length, 0),
          sampleServices: const [],
          sampleServicePrices: const [],
          acceptsExternalSamples: true,
          importSource: 'nbsle',
          sourceUrl: bucket.sourceUrl.isNotEmpty
              ? bucket.sourceUrl
              : '$baseHost/browse',
          externalId: bucket.labId?.toString() ?? '',
        ),
      );
    }

    rows.sort((a, b) {
      final byUni = a.university.compareTo(b.university);
      if (byUni != 0) return byUni;
      return a.name.compareTo(b.name);
    });
    return rows;
  }

  Future<String> _getHtml(String url) async {
    final response = await http
        .get(
          Uri.parse(url),
          headers: {
            'User-Agent': _userAgent,
            'Accept': 'text/html,application/xhtml+xml',
            'Accept-Language': 'ar,en;q=0.8',
          },
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('NBSLE HTTP ${response.statusCode} for $url');
    }

    // Site serves UTF-8; force decode in case headers are wrong.
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }

  static (int?, int?) _parseDeviceUrl(String url) {
    final match = RegExp(r'/device/(\d+)/(\d+)/').firstMatch(url);
    if (match == null) return (null, null);
    return (
      int.tryParse(match.group(1) ?? ''),
      int.tryParse(match.group(2) ?? ''),
    );
  }

  static int _estimateLabCount(List<NbsleDeviceRow> devices) {
    final keys = <String>{};
    for (final d in devices) {
      if (d.labId != null) {
        keys.add('id:${d.labId}');
      } else {
        keys.add(
          'name:${d.labName}|${d.university}|${d.faculty}'.toLowerCase(),
        );
      }
    }
    return keys.length;
  }

  static String _decodeHtml(String raw) {
    return raw
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  static String _facultyLabelAr(String facultyEn) {
    final id = _facultyIdFor(facultyEn);
    const labels = <String, String>{
      'Science': 'كلية العلوم',
      'Medicine': 'كلية الطب',
      'Engineering': 'كلية الهندسة',
      'Pharmacy': 'كلية الصيدلة',
      'Agriculture': 'كلية الزراعة',
      'Dentistry': 'كلية طب الأسنان',
      'Veterinary': 'كلية الطب البيطري',
      'Nursing': 'كلية التمريض',
      'CS': 'كلية الحاسبات',
    };
    return labels[id] ?? facultyEn;
  }

  static String _facultyIdFor(String facultyEn) {
    final lower = facultyEn.toLowerCase();
    if (lower.contains('medicine') &&
        !lower.contains('dental') &&
        !lower.contains('vet')) {
      return 'Medicine';
    }
    if (lower.contains('dental') || lower.contains('oral')) {
      return 'Dentistry';
    }
    if (lower.contains('pharm')) return 'Pharmacy';
    if (lower.contains('engineer')) return 'Engineering';
    if (lower.contains('agricultur')) return 'Agriculture';
    if (lower.contains('veterinar')) return 'Veterinary';
    if (lower.contains('nurs')) return 'Nursing';
    if (lower.contains('computer') || lower.contains('information')) {
      return 'CS';
    }
    if (lower.contains('physical therapy') || lower.contains('physiotherap')) {
      return 'Medicine';
    }
    if (lower.contains('education') || lower.contains('spcific')) {
      return 'Education';
    }
    if (lower.contains('science') || lower.contains('central lab')) {
      return 'Science';
    }
    return 'Science';
  }
}

class _LabBucket {
  final int? labId;
  final String name;
  final String university;
  final String faculty;
  String sourceUrl;
  final Set<String> equipment = {};

  _LabBucket({
    required this.labId,
    required this.name,
    required this.university,
    required this.faculty,
    required this.sourceUrl,
  });
}
