import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// One contact block from an NBSLE device detail page.
class NbsleContactPerson {
  final String role;
  final String name;
  final String email;
  final String phone;

  const NbsleContactPerson({
    this.role = '',
    this.name = '',
    this.email = '',
    this.phone = '',
  });

  bool get hasUsableContact {
    final e = email.trim();
    final p = cleanPhone(phone);
    return e.contains('@') || p.length >= 8;
  }

  Map<String, dynamic> toMap() => {
        'role': role,
        'name': name,
        'email': email,
        'phone': cleanPhone(phone),
      };

  factory NbsleContactPerson.fromMap(Map<String, dynamic> map) {
    return NbsleContactPerson(
      role: map['role']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      phone: cleanPhone(map['phone']?.toString() ?? ''),
    );
  }

  static String cleanPhone(String raw) {
    var p = raw.trim();
    if (p.isEmpty || p.toLowerCase() == 'null') return '';
    // NBSLE sometimes prefixes with 00
    if (p.startsWith('00') && p.length > 4) {
      p = '+${p.substring(2)}';
    }
    return p;
  }
}

/// Parsed fields from https://nbsle.scu.eg/device/...
class NbsleDeviceDetail {
  final List<NbsleContactPerson> contacts;
  final String imageUrl;
  final String manufactureYear;
  final String description;
  final String manufacturerUrl;

  const NbsleDeviceDetail({
    this.contacts = const [],
    this.imageUrl = '',
    this.manufactureYear = '',
    this.description = '',
    this.manufacturerUrl = '',
  });

  NbsleContactPerson? get primaryContact {
    for (final c in contacts) {
      if (c.hasUsableContact) return c;
    }
    return null;
  }

  String get bestEmail {
    for (final c in contacts) {
      if (c.email.contains('@')) return c.email.trim();
    }
    return '';
  }

  String get bestPhone {
    for (final c in contacts) {
      final p = NbsleContactPerson.cleanPhone(c.phone);
      if (p.length >= 8) return p;
    }
    return '';
  }

  String get bestName {
    for (final c in contacts) {
      if (c.name.trim().isNotEmpty && c.hasUsableContact) {
        return c.name.trim();
      }
    }
    return contacts.isNotEmpty ? contacts.first.name.trim() : '';
  }
}

/// Fetches and parses public NBSLE device detail pages (contacts, image…).
class NbsleDeviceDetailClient {
  NbsleDeviceDetailClient._();

  static final NbsleDeviceDetailClient instance = NbsleDeviceDetailClient._();

  static const _userAgent =
      'AcadeGate/1.0 (lab discovery; +https://acadegate.app)';

  Future<NbsleDeviceDetail> fetch(String deviceUrl) async {
    if (kIsWeb) {
      throw StateError('NBSLE detail fetch blocked on web (CORS)');
    }
    final response = await http
        .get(
          Uri.parse(deviceUrl),
          headers: {
            'User-Agent': _userAgent,
            'Accept': 'text/html,application/xhtml+xml',
            'Accept-Language': 'ar,en;q=0.8',
          },
        )
        .timeout(const Duration(seconds: 45));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('NBSLE detail HTTP ${response.statusCode}');
    }
    final html = utf8.decode(response.bodyBytes, allowMalformed: true);
    return parse(html);
  }

  /// Exposed for tests.
  static NbsleDeviceDetail parse(String html) {
    final contacts = <NbsleContactPerson>[];

    // Prefer splitting by the three known NBSLE contact section headers.
    final sectionRe = RegExp(
      r'<h6 class="mb-0 fw-bold">\s*<i class="fas fa-[^"]+"[^>]*>\s*</i>\s*'
      r'(Lab Staff|Lab Person|Faculty Coordinator|University Coordinator)\s*</h6>'
      r'([\s\S]*?)(?='
      r'<h6 class="mb-0 fw-bold">\s*<i class="fas fa-|'
      r'</div>\s*</div>\s*</div>\s*</section|'
      r'</main>)',
      caseSensitive: false,
    );

    for (final m in sectionRe.allMatches(html)) {
      final role = _decode(m.group(1)?.trim() ?? '');
      final body = m.group(2) ?? '';
      final nameMatch = RegExp(
        r'<div class="fw-bold text-dark">([^<]*)</div>',
        caseSensitive: false,
      ).firstMatch(body);
      final emailMatch = RegExp(
        r'href="mailto:([^"]*)"',
        caseSensitive: false,
      ).firstMatch(body);
      final phoneMatch = RegExp(
        r'href="tel:([^"]*)"',
        caseSensitive: false,
      ).firstMatch(body);
      final person = NbsleContactPerson(
        role: role,
        name: _decode(nameMatch?.group(1)?.trim() ?? ''),
        email: (emailMatch?.group(1) ?? '').trim(),
        phone: phoneMatch?.group(1) ?? '',
      );
      if (person.name.isEmpty &&
          !person.email.contains('@') &&
          NbsleContactPerson.cleanPhone(person.phone).isEmpty) {
        continue;
      }
      contacts.add(person);
    }

    // Fallback generic blocks if section headers were not found.
    if (contacts.isEmpty) {
      final blockRe = RegExp(
        r'<h6 class="mb-0 fw-bold">\s*<i class="fas fa-[^"]+"[^>]*>\s*</i>\s*'
        r'([^<]+?)\s*</h6>[\s\S]*?'
        r'<div class="fw-bold text-dark">([^<]*)</div>[\s\S]*?'
        r'href="mailto:([^"]*)"[\s\S]*?'
        r'href="tel:([^"]*)"',
        caseSensitive: false,
      );
      for (final m in blockRe.allMatches(html)) {
        final person = NbsleContactPerson(
          role: _decode(m.group(1)?.trim() ?? ''),
          name: _decode(m.group(2)?.trim() ?? ''),
          email: (m.group(3) ?? '').trim(),
          phone: m.group(4) ?? '',
        );
        if (person.name.isEmpty &&
            !person.email.contains('@') &&
            NbsleContactPerson.cleanPhone(person.phone).isEmpty) {
          continue;
        }
        contacts.add(person);
      }
    }

    String imageUrl = '';
    final imgRe = RegExp(
      r'<img[^>]+src="(https://nbsle\.scu\.eg/images/[^"]+)"',
      caseSensitive: false,
    );
    for (final m in imgRe.allMatches(html)) {
      final src = m.group(1) ?? '';
      if (src.contains('No_image') || src.contains('logo')) continue;
      imageUrl = src;
      break;
    }
    if (imageUrl.isEmpty) {
      final any = imgRe.firstMatch(html);
      imageUrl = any?.group(1) ?? '';
    }

    String manufactureYear = '';
    final yearRe = RegExp(
      r'Manufacture Year[\s\S]*?<[^>]+>([^<]{0,40})</',
      caseSensitive: false,
    );
    final yearMatch = yearRe.firstMatch(html);
    if (yearMatch != null) {
      manufactureYear = _decode(yearMatch.group(1)?.trim() ?? '');
    }

    String manufacturerUrl = '';
    final mfgRe = RegExp(
      r'Manufacturer Website[\s\S]*?href="(https?://[^"]+)"',
      caseSensitive: false,
    );
    manufacturerUrl = mfgRe.firstMatch(html)?.group(1) ?? '';

    String description = '';
    final descRe = RegExp(
      r'Description[\s\S]*?<p[^>]*>([\s\S]*?)</p>',
      caseSensitive: false,
    );
    final descMatch = descRe.firstMatch(html);
    if (descMatch != null) {
      description = _decode(
        descMatch.group(1)?.replaceAll(RegExp(r'<[^>]+>'), ' ').trim() ?? '',
      );
    }

    return NbsleDeviceDetail(
      contacts: contacts,
      imageUrl: imageUrl,
      manufactureYear: manufactureYear,
      description: description,
      manufacturerUrl: manufacturerUrl,
    );
  }

  static String _decode(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&nbsp;', ' ')
        .trim();
  }
}
