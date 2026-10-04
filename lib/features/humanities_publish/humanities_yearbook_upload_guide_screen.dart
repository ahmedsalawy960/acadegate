import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale/locale_extensions.dart';
import 'humanities_publish_branding.dart';
import 'humanities_publish_models.dart';
import 'humanities_publish_storage.dart';

/// دليل رفع على موقع الحولية/المجلة — AcadeGate لا يستضيف بوابة المجلة.
class HumanitiesYearbookUploadGuideScreen extends StatefulWidget {
  const HumanitiesYearbookUploadGuideScreen({super.key});

  @override
  State<HumanitiesYearbookUploadGuideScreen> createState() =>
      _HumanitiesYearbookUploadGuideScreenState();
}

class _HumanitiesYearbookUploadGuideScreenState
    extends State<HumanitiesYearbookUploadGuideScreen> {
  static const _brand = Color(HumanitiesPublishBranding.brand);

  HumanitiesPublishDraft? _draft;
  bool _loading = true;
  final _checks = <String, bool>{};

  static const _steps = <(String id, String ar, String en)>[
    (
      'guide',
      'تحميل دليل المؤلفين / قالب Word من موقع الحولية',
      'Download authors’ guide / Word template from the yearbook site',
    ),
    (
      'format',
      'ضبط التوثيق والملخصين والكلمات المفتاحية وفق الدليل',
      'Align citations, dual abstracts, and keywords to the guide',
    ),
    (
      'files',
      'تجهيز الملفات: المخطوطة · خطاب التقديم · سيرة مختصرة إن طُلبت',
      'Prepare files: manuscript · cover letter · short CV if required',
    ),
    (
      'account',
      'إنشاء حساب على نظام التقديم (OJS / بوابة الكلية) أو معرفة بريد التحرير',
      'Create an account on the submission system (OJS / faculty portal) or note the editorial email',
    ),
    (
      'upload',
      'رفع الملفات وإرسال الطلب — حفظ رقم المعاملة/إيصال الرفع',
      'Upload files and submit — save the request number / upload receipt',
    ),
    (
      'track',
      'متابعة التحكيم والرد على ملاحظات المحكّمين',
      'Track peer review and respond to referee comments',
    ),
    (
      'accept',
      'حفظ خطاب القبول النهائي لمرفقات الترقية/القسم',
      'Save the final acceptance letter for promotion/department files',
    ),
  ];

  @override
  void initState() {
    super.initState();
    for (final s in _steps) {
      _checks[s.$1] = false;
    }
    _load();
  }

  Future<void> _load() async {
    final d = await HumanitiesPublishStorage.instance.loadOrCreate();
    if (!mounted) return;
    setState(() {
      _draft = d;
      _loading = false;
    });
  }

  Future<void> _openSite() async {
    final url = _draft?.outlet?.submissionUrl ?? '';
    final uri = Uri.tryParse(url);
    if (uri == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'لا يوجد رابط مباشر — ابحث عن صفحة الحولية على موقع الكلية',
              'No direct link — find the yearbook page on the faculty site',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(context.t('رفع على موقع الحولية', 'Upload to yearbook site')),
          backgroundColor: _brand,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final outlet = _draft?.outlet;
    final done = _checks.values.where((v) => v).length;

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('رفع على موقع الحولية', 'Upload to yearbook site')),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Card(
            color: Colors.blueGrey.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                context.t(
                  HumanitiesPublishBranding.integrityAr,
                  HumanitiesPublishBranding.integrityEn,
                ),
                style: const TextStyle(height: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (outlet != null) ...[
            Text(
              context.t(outlet.nameAr, outlet.nameEn),
              style: const TextStyle(fontWeight: FontWeight.w800, color: _brand),
            ),
            const SizedBox(height: 6),
            Text(context.t(outlet.portalHintAr, outlet.portalHintEn)),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _openSite,
              icon: const Icon(Icons.open_in_new),
              label: Text(
                context.t('فتح موقع المنفذ', 'Open outlet website'),
              ),
              style: FilledButton.styleFrom(backgroundColor: _brand),
            ),
          ] else
            Text(
              context.t(
                'اختر مجلة/حولية أولاً لربط رابط الموقع بهذه الخطوات',
                'Pick a journal/yearbook first to link its site to these steps',
              ),
              style: TextStyle(color: Colors.orange[800]),
            ),
          const SizedBox(height: 16),
          Text(
            context.t(
              'قائمة تحقق الرفع ($done / ${_steps.length})',
              'Upload checklist ($done / ${_steps.length})',
            ),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          for (final s in _steps)
            CheckboxListTile(
              value: _checks[s.$1] ?? false,
              onChanged: (v) => setState(() => _checks[s.$1] = v == true),
              activeColor: _brand,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(context.t(s.$2, s.$3)),
            ),
          const SizedBox(height: 8),
          Card(
            color: _brand.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                context.t(
                  'دار المنظومة للفهرسة والبحث عن مجلات — الرفع دائماً على موقع المجلة/الحولية المختارة.',
                  'Dar Al-Mandumah is for discovery/indexing — upload always happens on the chosen journal/yearbook site.',
                ),
                style: const TextStyle(height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
