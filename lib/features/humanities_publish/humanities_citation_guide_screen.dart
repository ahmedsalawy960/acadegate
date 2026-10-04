import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../acadegate_publish/publish_hub_screen.dart';
import 'humanities_publish_branding.dart';
import 'humanities_publish_models.dart';
import 'humanities_publish_storage.dart';

/// شروط الاقتباس حسب المنفذ المختار + اختصار لمحرر المخطوطة.
class HumanitiesCitationGuideScreen extends StatefulWidget {
  const HumanitiesCitationGuideScreen({super.key});

  @override
  State<HumanitiesCitationGuideScreen> createState() =>
      _HumanitiesCitationGuideScreenState();
}

class _HumanitiesCitationGuideScreenState
    extends State<HumanitiesCitationGuideScreen> {
  static const _brand = Color(HumanitiesPublishBranding.brand);
  HumanitiesPublishDraft? _draft;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
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

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.t('نُسخ المثال', 'Example copied')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(context.t('شروط الاقتباس', 'Citation requirements')),
          backgroundColor: _brand,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final outlet = _draft?.outlet;
    final apaEx =
        'داخل النص: (أحمد، 2022) أو أحمد (2022)\n'
        'المراجع: أحمد، م. ع. (2022). عنوان البحث. اسم المجلة، 12(3)، 45–67.';
    final chicagoEx =
        'حاشية: محمد أحمد، «عنوان المقال»، حوليات كلية الآداب 40 (2022): 12.\n'
        'قائمة: أحمد، محمد. «عنوان المقال». حوليات كلية الآداب 40 (2022): 1–30.';
    final lawEx =
        'حاشية تشريع: القانون رقم … لسنة …، الجريدة الرسمية، العدد … بتاريخ …\n'
        'حكم: الطعن رقم … لسنة … قضائية، جلسة …/…/….';

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('شروط الاقتباس', 'Citation requirements')),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          if (outlet == null)
            Card(
              color: Colors.orange.withValues(alpha: 0.08),
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(
                  context.t(
                    'اختر مجلة أولاً لعرض شروطها بدقة',
                    'Pick a journal first for precise rules',
                  ),
                ),
              ),
            )
          else ...[
            Text(
              context.t(outlet.nameAr, outlet.nameEn),
              style: const TextStyle(fontWeight: FontWeight.w800, color: _brand),
            ),
            const SizedBox(height: 6),
            Text(
              context.t(
                'النمط المقترح: ${outlet.citationLabelAr()}',
                'Suggested style: ${outlet.citationLabelEn()}',
              ),
            ),
            const SizedBox(height: 8),
            Text(context.t(outlet.citationNotesAr, outlet.citationNotesEn)),
            const SizedBox(height: 12),
            Text(
              context.t('متطلبات المنفذ', 'Outlet requirements'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            for (var i = 0; i < outlet.requirementsAr.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '• ${context.t(outlet.requirementsAr[i], outlet.requirementsEn[i])}',
                ),
              ),
          ],
          const SizedBox(height: 16),
          Text(
            context.t('أمثلة سريعة', 'Quick examples'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          _ExampleCard(
            brand: _brand,
            titleAr: 'APA عربي (تربية شائع)',
            titleEn: 'APA Arabic (common in Education)',
            body: apaEx,
            onCopy: () => _copy(apaEx),
          ),
          _ExampleCard(
            brand: _brand,
            titleAr: 'Chicago / حواشٍ (آداب شائع)',
            titleEn: 'Chicago / footnotes (common in Arts)',
            body: chicagoEx,
            onCopy: () => _copy(chicagoEx),
          ),
          _ExampleCard(
            brand: _brand,
            titleAr: 'توثيق قانوني',
            titleEn: 'Legal citation',
            body: lawEx,
            onCopy: () => _copy(lawEx),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PublishHubScreen()),
              );
            },
            icon: const Icon(Icons.edit_note_outlined),
            label: Text(
              context.t(
                'فتح محرر المخطوطة (APA/IEEE…)',
                'Open manuscript editor (APA/IEEE…)',
              ),
            ),
            style: FilledButton.styleFrom(backgroundColor: _brand),
          ),
          const SizedBox(height: 8),
          Text(
            context.t(
              'المحرر يدعم أنماط Scopus/دولية؛ للمنفذ العربي طبّق دليل المجلة يدوياً إن اختلف.',
              'The editor supports Scopus/intl styles; for Arabic outlets apply the journal guide manually if it differs.',
            ),
            style: TextStyle(fontSize: 12, color: const Color(0xFFB7C3D6), height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _ExampleCard extends StatelessWidget {
  final Color brand;
  final String titleAr;
  final String titleEn;
  final String body;
  final VoidCallback onCopy;

  const _ExampleCard({
    required this.brand,
    required this.titleAr,
    required this.titleEn,
    required this.body,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.t(titleAr, titleEn),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: onCopy,
                  icon: Icon(Icons.copy_outlined, color: brand),
                  tooltip: context.t('نسخ', 'Copy'),
                ),
              ],
            ),
            Text(body, style: const TextStyle(height: 1.45)),
          ],
        ),
      ),
    );
  }
}
