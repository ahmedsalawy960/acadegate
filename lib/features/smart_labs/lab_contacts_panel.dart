import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale/locale_extensions.dart';
import '../academic/academic_models.dart';

/// Shows every NBSLE contact role (lab staff, faculty, university) separately.
class LabContactsPanel extends StatelessWidget {
  final AcademicLab lab;
  final Color? backgroundColor;

  const LabContactsPanel({
    super.key,
    required this.lab,
    this.backgroundColor,
  });

  static String _roleLabel(BuildContext context, String role) {
    final r = role.trim().toLowerCase();
    if (r.contains('lab staff') || r.contains('lab person')) {
      return context.t('مسؤول المختبر', 'Lab staff');
    }
    if (r.contains('faculty')) {
      return context.t('منسق الكلية', 'Faculty coordinator');
    }
    if (r.contains('university')) {
      return context.t('منسق الجامعة', 'University coordinator');
    }
    if (role.trim().isEmpty) {
      return context.t('جهة اتصال', 'Contact');
    }
    return role.trim();
  }

  List<LabContactPerson> _people() {
    final fromList = lab.contacts
        .where(
          (c) =>
              c.name.trim().isNotEmpty ||
              c.email.contains('@') ||
              c.phone.trim().length >= 8,
        )
        .toList();
    if (fromList.isNotEmpty) return fromList;

    // Fallback when only flattened primary fields exist.
    if (lab.hasLabContact) {
      return [
        LabContactPerson(
          role: 'Lab contact',
          name: lab.contactName,
          email: lab.displayContactEmail,
          phone: lab.displayContactPhone,
        ),
      ];
    }
    return const [];
  }

  Future<void> _call(String phone) async {
    final cleaned = phone.trim();
    if (cleaned.isEmpty) return;
    await launchUrl(Uri.parse('tel:$cleaned'));
  }

  Future<void> _email(String email) async {
    final cleaned = email.trim();
    if (!cleaned.contains('@')) return;
    await launchUrl(Uri.parse('mailto:$cleaned'));
  }

  Future<void> _whatsapp(BuildContext context, String phone) async {
    var p = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (p.startsWith('00')) p = p.substring(2);
    if (p.startsWith('+')) p = p.substring(1);
    if (p.startsWith('0') && p.length >= 10) p = '20${p.substring(1)}';
    final text = Uri.encodeComponent(
      context.t(
        'مرحباً، أتواصل عبر AcadeGate بخصوص المختبر: ${lab.name}',
        'Hello, contacting via AcadeGate about lab: ${lab.name}',
      ),
    );
    await launchUrl(
      Uri.parse('https://wa.me/$p?text=$text'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final people = _people();
    if (people.isEmpty) return const SizedBox.shrink();

    return Card(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t(
                'بيانات التواصل من NBSLE',
                'Contact details from NBSLE',
              ),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              context.t(
                'كل الجهات كما في الموقع الأصلي',
                'All roles as on the original site',
              ),
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
            const SizedBox(height: 8),
            ...people.map((c) {
              final phone = c.phone.trim();
              final email = c.email.trim();
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _roleLabel(context, c.role),
                      style: TextStyle(
                        color: Colors.teal.shade800,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    if (c.name.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        c.name.trim(),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                    if (email.contains('@')) Text(email),
                    if (phone.length >= 8) Text(phone),
                    if (!email.contains('@') && phone.length < 8)
                      Text(
                        context.t('لا توجد وسيلة تواصل هنا', 'No contact method here'),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (phone.length >= 8)
                          OutlinedButton.icon(
                            onPressed: () => _call(phone),
                            icon: const Icon(Icons.phone, size: 16),
                            label: Text(context.t('اتصال', 'Call')),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        if (phone.length >= 8)
                          OutlinedButton.icon(
                            onPressed: () => _whatsapp(context, phone),
                            icon: const Icon(Icons.chat, size: 16),
                            label: Text(context.t('واتساب', 'WhatsApp')),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        if (email.contains('@'))
                          OutlinedButton.icon(
                            onPressed: () => _email(email),
                            icon: const Icon(Icons.email_outlined, size: 16),
                            label: Text(context.t('بريد', 'Email')),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
