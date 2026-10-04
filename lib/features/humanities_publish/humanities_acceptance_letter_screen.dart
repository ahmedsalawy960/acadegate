import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import 'humanities_publish_branding.dart';
import 'humanities_publish_models.dart';
import 'humanities_publish_storage.dart';

class HumanitiesAcceptanceLetterScreen extends StatefulWidget {
  const HumanitiesAcceptanceLetterScreen({super.key});

  @override
  State<HumanitiesAcceptanceLetterScreen> createState() =>
      _HumanitiesAcceptanceLetterScreenState();
}

class _HumanitiesAcceptanceLetterScreenState
    extends State<HumanitiesAcceptanceLetterScreen> {
  static const _brand = Color(HumanitiesPublishBranding.brand);

  HumanitiesPublishDraft? _draft;
  bool _loading = true;
  late final TextEditingController _titleAr;
  late final TextEditingController _titleEn;
  late final TextEditingController _author;
  late final TextEditingController _aff;
  late final TextEditingController _abstract;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _titleAr = TextEditingController();
    _titleEn = TextEditingController();
    _author = TextEditingController();
    _aff = TextEditingController();
    _abstract = TextEditingController();
    _notes = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _titleAr.dispose();
    _titleEn.dispose();
    _author.dispose();
    _aff.dispose();
    _abstract.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final d = await HumanitiesPublishStorage.instance.loadOrCreate();
    if (!mounted) return;
    _titleAr.text = d.articleTitleAr;
    _titleEn.text = d.articleTitleEn;
    _author.text = d.authorName;
    _aff.text = d.affiliation;
    _abstract.text = d.abstractAr;
    _notes.text = d.notesForEditor;
    setState(() {
      _draft = d;
      _loading = false;
    });
  }

  Future<void> _persist() async {
    final d = _draft;
    if (d == null) return;
    d.articleTitleAr = _titleAr.text.trim();
    d.articleTitleEn = _titleEn.text.trim();
    d.authorName = _author.text.trim();
    d.affiliation = _aff.text.trim();
    d.abstractAr = _abstract.text.trim();
    d.notesForEditor = _notes.text.trim();
    await HumanitiesPublishStorage.instance.save(d);
  }

  Future<void> _copyLetter() async {
    await _persist();
    final d = _draft;
    if (d == null) return;
    final text = HumanitiesPublishLetterBuilder.build(d);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.t('نُسخ الخطاب', 'Letter copied')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(context.t('خطاب التقديم/القبول', 'Cover / acceptance letter')),
          backgroundColor: _brand,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final d = _draft!;
    final preview = HumanitiesPublishLetterBuilder.build(d);

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('خطاب التقديم/القبول', 'Cover / acceptance letter')),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _copyLetter,
            icon: const Icon(Icons.copy_all_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Card(
            color: _brand.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                context.t(
                  'خطاب تقديم مع الإرسال، أو إقرار باستلام القبول، أو مذكرة مرفقات للترقية. '
                  'خطاب القبول الرسمي يصدر من المجلة — هذا قالب مساعد للنسخ.',
                  'Submission cover letter, acceptance acknowledgement, or promotion attachments note. '
                  'The official acceptance letter comes from the journal — this is a helper template.',
                ),
                style: const TextStyle(height: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (d.outlet != null)
            Text(
              context.t(
                'المنفذ: ${d.outlet!.nameAr}',
                'Outlet: ${d.outlet!.nameEn}',
              ),
              style: const TextStyle(fontWeight: FontWeight.w700, color: _brand),
            )
          else
            Text(
              context.t(
                'لم تُختر مجلة بعد — سيُستخدم اسم عام في الخطاب',
                'No journal selected yet — a generic name will be used',
              ),
              style: TextStyle(color: Colors.orange[800]),
            ),
          const SizedBox(height: 12),
          Text(
            context.t('نوع الخطاب', 'Letter type'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final e in [
                ('submission', 'تقديم للنشر', 'Submission'),
                ('acceptance_ack', 'إقرار قبول', 'Acceptance ack.'),
                ('promotion_note', 'مذكرة ترقية', 'Promotion note'),
              ])
                ChoiceChip(
                  label: Text(context.t(e.$2, e.$3)),
                  selected: d.letterType == e.$1,
                  selectedColor: _brand.withValues(alpha: 0.22),
                  onSelected: (_) async {
                    setState(() => d.letterType = e.$1);
                    await _persist();
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleAr,
            decoration: InputDecoration(
              labelText: context.t('عنوان البحث (عربي)', 'Article title (AR)'),
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _titleEn,
            decoration: InputDecoration(
              labelText: context.t('العنوان (إنجليزي اختياري)', 'Title (EN optional)'),
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _author,
            decoration: InputDecoration(
              labelText: context.t('اسم الباحث', 'Author name'),
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _aff,
            decoration: InputDecoration(
              labelText: context.t('الكلية / الجامعة', 'Faculty / university'),
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _abstract,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: context.t('ملخص موجز (اختياري)', 'Short abstract (optional)'),
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: context.t('ملاحظات للتحرير', 'Notes to editors'),
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          Text(
            context.t('معاينة', 'Preview'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(preview, style: const TextStyle(height: 1.45)),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _copyLetter,
            icon: const Icon(Icons.copy_all_outlined),
            label: Text(context.t('نسخ الخطاب', 'Copy letter')),
            style: FilledButton.styleFrom(backgroundColor: _brand),
          ),
        ],
      ),
    );
  }
}
