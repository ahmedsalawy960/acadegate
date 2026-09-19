import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/config/app_contact_info.dart';
import '../../core/locale/locale_extensions.dart';
import '../auth/auth_guard.dart';
import 'privacy_request_service.dart';

/// طلبات حقوق الخصوصية (اطلاع / تصحيح / حذف…) → Firestore + إشعار أدمن + بريد.
class PrivacyRightsScreen extends StatefulWidget {
  const PrivacyRightsScreen({super.key});

  @override
  State<PrivacyRightsScreen> createState() => _PrivacyRightsScreenState();
}

class _PrivacyRightsScreenState extends State<PrivacyRightsScreen> {
  PrivacyRequestType _type = PrivacyRequestType.erasure;
  final _messageCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = FirebaseAuth.instance.currentUser?.email ?? '';
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await ensureLoggedIn(context);
    if (!ok || !mounted) return;

    setState(() => _submitting = true);
    try {
      final locale = Localizations.localeOf(context).languageCode;
      final id = await PrivacyRequestService.instance.submit(
        type: _type,
        message: _messageCtrl.text,
        locale: locale,
        emailOverride: _emailCtrl.text.trim(),
      );
      if (!mounted) return;
      _messageCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'تم تسجيل الطلب ($id). راسلنا أيضاً عبر البريد إن فُتح.',
              'Request recorded ($id). Email draft opened when possible.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Colors.red[800],
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('حقوق الخصوصية', 'Privacy rights')),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          Card(
            color: const Color(0xFFE8EAF6),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                context.t(
                  'بحسب قانون حماية البيانات الشخصية المصري (١٥١ لسنة ٢٠٢٠) حيث ينطبق، '
                  'يمكنك طلب الاطلاع أو التصحيح أو الحذف أو تقييد/الاعتراض على معالجة معيّنة. '
                  'سنتحقق من هويتك قبل التنفيذ. الطلب يُسجَّل ويُبلَّغ المشرفون، مع نسخة بريد إلى ${AppContactInfo.supportEmail}.',
                  'Under Egypt’s Personal Data Protection Law (151/2020) where applicable, '
                  'you may request access, correction, erasure, restriction, or objection. '
                  'We may verify identity. Requests are logged, admins are notified, and a copy goes to ${AppContactInfo.supportEmail}.',
                ),
                style: TextStyle(height: 1.45, color: Colors.grey[900]),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.t('نوع الطلب', 'Request type'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PrivacyRequestType.values.map((t) {
              final selected = _type == t;
              return FilterChip(
                selected: selected,
                label: Text(t.label(isAr)),
                onSelected: _submitting
                    ? null
                    : (_) => setState(() => _type = t),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: context.t('البريد للتواصل', 'Contact email'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageCtrl,
            maxLines: 5,
            maxLength: 4000,
            decoration: InputDecoration(
              labelText: context.t('التفاصيل', 'Details'),
              hintText: context.t(
                'اشرح ماذا تريد تصحيحه أو حذفه…',
                'Explain what you want corrected or deleted…',
              ),
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(
              context.t('إرسال الطلب', 'Submit request'),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ),
    );
  }
}
