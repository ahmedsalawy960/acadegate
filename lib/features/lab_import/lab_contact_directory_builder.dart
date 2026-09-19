import '../academic/academic_models.dart';

/// Builds CSV + Arabic HTML contact sheets from imported labs.
class LabContactDirectoryBuilder {
  LabContactDirectoryBuilder._();

  static String csvEsc(String v) {
    if (RegExp(r'[",\n\r]').hasMatch(v)) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  static String htmlEsc(String v) => v
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  static String contactsSummary(AcademicLab lab) {
    if (lab.contacts.isEmpty) return '';
    return lab.contacts
        .map((c) {
          final bits = <String>[
            if (c.role.trim().isNotEmpty) c.role.trim(),
            if (c.name.trim().isNotEmpty) c.name.trim(),
            if (c.email.contains('@')) c.email.trim(),
            if (c.phone.trim().length >= 8) c.phone.trim(),
          ];
          return bits.join(' · ');
        })
        .where((s) => s.isNotEmpty)
        .join(' | ');
  }

  /// Prefer labs that can be contacted (email/phone/source URL).
  static List<AcademicLab> prioritize(List<AcademicLab> labs) {
    final copy = [...labs];
    int rank(AcademicLab l) {
      var r = 0;
      if (l.displayContactEmail.contains('@')) r += 4;
      if (l.displayContactPhone.trim().length >= 8) r += 4;
      if (l.sourceUrl.trim().startsWith('http')) r += 2;
      if (l.importSource == 'nbsle' || l.importSource == 'crci') r += 1;
      return r;
    }

    copy.sort((a, b) {
      final d = rank(b).compareTo(rank(a));
      if (d != 0) return d;
      final city = a.city.compareTo(b.city);
      if (city != 0) return city;
      return a.name.compareTo(b.name);
    });
    return copy;
  }

  static String buildCsv(List<AcademicLab> labs) {
    final rows = prioritize(labs);
    final header =
        '#,الاسم,الجامعة,المدينة,المسؤول,البريد,الهاتف,جهات_إضافية,المصدر,رابط_المصدر,أجهزة,يقبل_عينات_خارجية';
    final lines = <String>[header];
    for (var i = 0; i < rows.length; i++) {
      final l = rows[i];
      final devices = l.equipmentList.isNotEmpty
          ? l.equipmentList.map((e) => e.name).take(8).join('؛ ')
          : (l.equipmentNameHints.take(8).join('؛ ').isNotEmpty
              ? l.equipmentNameHints.take(8).join('؛ ')
              : l.equipment);
      lines.add(
        [
          '${i + 1}',
          csvEsc(l.name),
          csvEsc(l.university),
          csvEsc(l.city),
          csvEsc(l.contactName),
          csvEsc(l.displayContactEmail),
          csvEsc(l.displayContactPhone),
          csvEsc(contactsSummary(l)),
          csvEsc(l.importSource.isEmpty ? 'manual' : l.importSource),
          csvEsc(l.sourceUrl),
          csvEsc(devices),
          l.acceptsExternalSamples ? 'نعم' : 'لا',
        ].join(','),
      );
    }
    return '${lines.join('\n')}\n';
  }

  static String buildHtml(List<AcademicLab> labs) {
    final rows = prioritize(labs);
    final withContact = rows
        .where(
          (l) =>
              l.displayContactEmail.contains('@') ||
              l.displayContactPhone.trim().length >= 8,
        )
        .length;
    final buf = StringBuffer();
    buf.writeln('<!DOCTYPE html>');
    buf.writeln('<html lang="ar" dir="rtl">');
    buf.writeln('<head>');
    buf.writeln('<meta charset="UTF-8" />');
    buf.writeln(
      '<meta name="viewport" content="width=device-width, initial-scale=1" />',
    );
    buf.writeln('<title>AcadeGate — كشف تواصل المختبرات</title>');
    buf.writeln('<style>');
    buf.writeln(
      'body{font-family:"Segoe UI",Tahoma,Arial,sans-serif;margin:0;background:#f4f4f5;color:#18181b;line-height:1.55}',
    );
    buf.writeln('.wrap{max-width:1100px;margin:0 auto;padding:24px 16px 48px}');
    buf.writeln(
      'h1{margin:0 0 8px;color:#0b1f4d} .meta{color:#52525b;margin-bottom:18px}',
    );
    buf.writeln(
      '.stats{display:flex;gap:10px;flex-wrap:wrap;margin-bottom:16px}',
    );
    buf.writeln(
      '.stat{background:#fff;border:1px solid #e4e4e7;border-radius:12px;padding:10px 14px}',
    );
    buf.writeln(
      'table{width:100%;border-collapse:collapse;background:#fff;border-radius:12px;overflow:hidden}',
    );
    buf.writeln(
      'th{background:#0b1f4d;color:#fff;text-align:right;padding:10px 8px;font-size:12px}',
    );
    buf.writeln(
      'td{border-bottom:1px solid #e4e4e7;padding:9px 8px;font-size:12.5px;vertical-align:top}',
    );
    buf.writeln('tr:nth-child(even) td{background:#fafafa}');
    buf.writeln('a{color:#0f766e;font-weight:700}');
    buf.writeln(
      '.empty{color:#a1a1aa} .pill{display:inline-block;background:#f3e5f5;color:#6a1b9a;border-radius:999px;padding:2px 8px;font-size:11px}',
    );
    buf.writeln('</style></head><body><div class="wrap">');
    buf.writeln('<h1>كشف تواصل المختبرات — AcadeGate</h1>');
    buf.writeln(
      '<p class="meta">مختبرات مستوردة/مسجّلة للتواصل والشراكة · '
      '${DateTime.now().toIso8601String().split('T').first} · '
      '<a href="https://acadegate-new.web.app">https://acadegate-new.web.app</a></p>',
    );
    buf.writeln('<div class="stats">');
    buf.writeln(
      '<div class="stat"><strong>${rows.length}</strong><br/>إجمالي السجلات</div>',
    );
    buf.writeln(
      '<div class="stat"><strong>$withContact</strong><br/>فيها بريد أو هاتف</div>',
    );
    buf.writeln(
      '<div class="stat"><strong>${rows.length - withContact}</strong><br/>رابط/بيانات فقط</div>',
    );
    buf.writeln('</div>');
    buf.writeln('<table><thead><tr>');
    for (final h in [
      '#',
      'المختبر',
      'الجامعة / الجهة',
      'المدينة',
      'التواصل',
      'المصدر',
      'رابط',
    ]) {
      buf.writeln('<th>$h</th>');
    }
    buf.writeln('</tr></thead><tbody>');

    for (var i = 0; i < rows.length; i++) {
      final l = rows[i];
      final email = l.displayContactEmail;
      final phone = l.displayContactPhone;
      final contactBits = <String>[
        if (l.contactName.trim().isNotEmpty) htmlEsc(l.contactName),
        if (email.contains('@'))
          '<a href="mailto:${htmlEsc(email)}">${htmlEsc(email)}</a>',
        if (phone.trim().length >= 8) htmlEsc(phone),
        if (contactsSummary(l).isNotEmpty)
          '<span class="empty">${htmlEsc(contactsSummary(l))}</span>',
      ];
      final contactHtml = contactBits.isEmpty
          ? '<span class="empty">—</span>'
          : contactBits.join('<br/>');
      final src = l.importSource.isEmpty ? 'manual' : l.importSource;
      final link = l.sourceUrl.trim().startsWith('http')
          ? '<a href="${htmlEsc(l.sourceUrl)}" target="_blank" rel="noopener">فتح</a>'
          : '<span class="empty">—</span>';

      buf.writeln('<tr>');
      buf.writeln('<td>${i + 1}</td>');
      buf.writeln('<td><strong>${htmlEsc(l.name)}</strong></td>');
      buf.writeln('<td>${htmlEsc(l.university)}</td>');
      buf.writeln('<td>${htmlEsc(l.city)}</td>');
      buf.writeln('<td>$contactHtml</td>');
      buf.writeln('<td><span class="pill">${htmlEsc(src)}</span></td>');
      buf.writeln('<td>$link</td>');
      buf.writeln('</tr>');
    }

    buf.writeln('</tbody></table>');
    buf.writeln(
      '<p class="meta" style="margin-top:18px">للتواصل الداخلي والشراكة فقط. '
      'تحققوا من صحة الأرقام/البريد قبل الإرسال الجماعي.</p>',
    );
    buf.writeln('</div></body></html>');
    return buf.toString();
  }
}
