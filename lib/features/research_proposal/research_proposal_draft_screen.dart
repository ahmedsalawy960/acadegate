import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../ai_advisor/gemini_advisor_client.dart';
import 'research_proposal_branding.dart';
import 'research_proposal_coach_service.dart';
import 'research_proposal_models.dart';
import 'research_proposal_storage.dart';
import 'research_proposal_templates.dart';
import 'research_proposal_workshop.dart';

class ResearchProposalDraftScreen extends StatefulWidget {
  const ResearchProposalDraftScreen({super.key});

  @override
  State<ResearchProposalDraftScreen> createState() =>
      _ResearchProposalDraftScreenState();
}

class _ResearchProposalDraftScreenState
    extends State<ResearchProposalDraftScreen> {
  static const _brand = Color(ResearchProposalBranding.brand);

  ProposalDraft? _draft;
  bool _loading = true;
  bool _fillingAll = false;
  String? _fillingKey;
  final _controllers = <String, TextEditingController>{};
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final d = await ResearchProposalStorage.instance.loadOrCreate();
    final keys = d.activeSections;
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    for (final k in keys) {
      _controllers[k] = TextEditingController(text: d.section(k));
    }
    _controllers.putIfAbsent(
      ProposalSectionKeys.titleAr,
      () => TextEditingController(text: d.section(ProposalSectionKeys.titleAr)),
    );
    _controllers.putIfAbsent(
      ProposalSectionKeys.titleEn,
      () => TextEditingController(text: d.section(ProposalSectionKeys.titleEn)),
    );
    if (!mounted) return;
    setState(() {
      _draft = d;
      _loading = false;
    });
  }

  void _syncControllersFromDraft(ProposalDraft d) {
    for (final e in _controllers.entries) {
      final text = d.section(e.key);
      if (e.value.text != text) {
        e.value.text = text;
        e.value.selection = TextSelection.collapsed(offset: text.length);
      }
    }
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 450), _persist);
  }

  Future<void> _persist() async {
    final d = _draft;
    if (d == null) return;
    for (final e in _controllers.entries) {
      d.setSection(e.key, e.value.text);
    }
    await ResearchProposalStorage.instance.save(d);
    if (mounted) setState(() {});
  }

  Future<void> _copy() async {
    await _persist();
    final d = _draft;
    if (d == null) return;
    await Clipboard.setData(
      ClipboardData(text: d.exportText(arabic: true)),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.t('نُسخت المسودة', 'Draft copied')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _fillOne(String key, {required bool overwrite}) async {
    final d = _draft;
    if (d == null || _fillingAll || _fillingKey != null) return;
    await _persist();
    if (!overwrite && d.section(key).trim().length >= 24) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.t('الفقرة فيها نص', 'Section already has text')),
          content: Text(
            ctx.t(
              'استبدال النص الحالي بنص مولَّد؟',
              'Replace current text with generated text?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.t('إلغاء', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.t('استبدال', 'Replace')),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    setState(() => _fillingKey = key);
    try {
      final text = await ResearchProposalCoachService.instance.generateSectionText(
        draft: d,
        sectionKey: key,
      );
      if (!mounted) return;
      if (text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t(
                'اكتب العنوان أو فقرة المشكلة أولاً ثم أعد التوليد',
                'Enter the title or problem paragraph first, then generate again',
              ),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      d.setSection(key, text);
      _controllers[key]?.text = text;
      await ResearchProposalStorage.instance.save(d);
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _fillingKey = null);
    }
  }

  Future<void> _fillAll({required bool overwrite}) async {
    final d = _draft;
    if (d == null || _fillingAll) return;
    await _persist();

    if (d.titleAr.trim().length < 8 &&
        d.section(ProposalSectionKeys.problem).trim().length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'اكتب العنوان أو المشكلة أولاً ثم اطلب ملء المسودة',
              'Enter the title or problem first, then fill the draft',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _fillingAll = true);
    try {
      final n = await ResearchProposalCoachService.instance.fillDraftSections(
        draft: d,
        overwriteFilled: overwrite,
        onlyKeys: d.activeSections,
      );
      _syncControllersFromDraft(d);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              n == 0
                  ? 'لم يُضف نص جديد (الفقرات ممتلئة أو فشل التوليد)'
                  : 'تم ملء/تحديث $n فقرة في المسودة',
              n == 0
                  ? 'Nothing new added (sections full or generation failed)'
                  : 'Filled/updated $n draft sections',
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
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _fillingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(context.t('مسودة الخطة', 'Proposal draft')),
          backgroundColor: _brand,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final draft = _draft!;
    final keys = draft.activeSections;
    final preset = proposalTemplateById(draft.templateId);
    final report = ProposalConsistencyEngine.instance.evaluate(draft);
    final ratio = draft.completionRatio(keys);
    final busy = _fillingAll || _fillingKey != null;

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('مسودة الخطة', 'Proposal draft')),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: busy ? null : _copy,
            icon: const Icon(Icons.copy_all_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            context.t(
              preset != null && preset.id != 'catalog_all'
                  ? 'فقرات المسودة · ${preset.titleAr} (${keys.length})'
                  : 'فقرات المسودة المختارة (${keys.length})',
              preset != null && preset.id != 'catalog_all'
                  ? 'Draft sections · ${preset.titleEn} (${keys.length})'
                  : 'Selected draft sections (${keys.length})',
            ),
            style: const TextStyle(fontWeight: FontWeight.w800, color: _brand),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            color: _brand,
            backgroundColor: _brand.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 6),
          Text(
            context.t(
              'اكتمال الأقسام: ${(ratio * 100).round()}% · درجة الاتساق: ${report.score}%',
              'Sections: ${(ratio * 100).round()}% · Consistency: ${report.score}%',
            ),
            style: TextStyle(fontSize: 12.5, color: const Color(0xFFB7C3D6)),
          ),
          const SizedBox(height: 12),
          Card(
            color: _brand.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.t(
                      'ملء المسودة',
                      'Fill the draft',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.t(
                      GeminiAdvisorClient.isAvailable
                          ? 'امسح الفقرات الفارغة أو ولّد فقرة فقرة تحت كل حقل.'
                          : 'بدون تسجيل دخول: ملء محلي من العنوان والمشكلة. سجّل الدخول لتحسين الصياغة.',
                      GeminiAdvisorClient.isAvailable
                          ? 'Fill empty sections at once, or generate under each field.'
                          : 'Signed out: local fill from the title and problem. Sign in for stronger wording.',
                    ),
                    style: TextStyle(fontSize: 12.5, color: const Color(0xFFB7C3D6), height: 1.35),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: busy ? null : () => _fillAll(overwrite: false),
                    icon: _fillingAll
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.drive_file_rename_outline),
                    label: Text(
                      _fillingAll
                          ? context.t('جاري الملء…', 'Filling…')
                          : context.t(
                              'ملء الفقرات الفارغة',
                              'Fill empty sections',
                            ),
                    ),
                    style: FilledButton.styleFrom(backgroundColor: _brand),
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => _fillAll(overwrite: true),
                    icon: const Icon(Icons.sync),
                    label: Text(
                      context.t(
                        'إعادة توليد كل الفقرات (استبدال)',
                        'Regenerate all sections (overwrite)',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.t('الدرجة', 'Degree'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final e in [
                ('masters', 'ماجستير', "Master's"),
                ('phd', 'دكتوراه', 'PhD'),
                ('both', 'ماجستير/دكتوراه', 'MSc/PhD'),
              ])
                ChoiceChip(
                  label: Text(context.t(e.$2, e.$3)),
                  selected: draft.degreeLevel == e.$1,
                  selectedColor: _brand.withValues(alpha: 0.22),
                  onSelected: busy
                      ? null
                      : (_) async {
                          setState(() => draft.degreeLevel = e.$1);
                          await ResearchProposalStorage.instance.save(draft);
                        },
                ),
            ],
          ),
          if (report.issues.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              context.t('فحص الاتساق (منهج–أداة–أسئلة…)', 'Consistency check'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            for (final issue in report.issues.take(8))
              Card(
                color: issue.severity == 'high'
                    ? Colors.red.withValues(alpha: 0.06)
                    : Colors.orange.withValues(alpha: 0.06),
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    issue.severity == 'high'
                        ? Icons.error_outline
                        : Icons.info_outline,
                    color: issue.severity == 'high'
                        ? Colors.red.shade700
                        : Colors.orange.shade800,
                  ),
                  title: Text(
                    context.t(issue.titleAr, issue.titleEn),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(context.t(issue.detailAr, issue.detailEn)),
                ),
              ),
          ],
          const SizedBox(height: 12),
          for (final key in keys) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.t(
                      ProposalSectionKeys.labelAr(key),
                      ProposalSectionKeys.labelEn(key),
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton.icon(
                  onPressed: busy
                      ? null
                      : () => _fillOne(key, overwrite: false),
                  icon: _fillingKey == key
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.drive_file_rename_outline, size: 16),
                  label: Text(
                    _fillingKey == key
                        ? context.t('…', '…')
                        : context.t('صياغة', 'Draft'),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: _brand,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            Text(
              ProposalSectionKeys.hintAr(key),
              style:
                  TextStyle(fontSize: 12, color: const Color(0xFFB7C3D6), height: 1.35),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _controllers[key],
              minLines: key.contains('title') ? 1 : 3,
              maxLines: key.contains('title') ? 2 : 10,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                isDense: true,
                hintText: context.t(
                  'اضغط «صياغة» بجانب العنوان لتوليد هذه الفقرة',
                  'Tap Draft beside the title to generate this section',
                ),
              ),
              onChanged: (_) {
                draft.setSection(key, _controllers[key]?.text ?? '');
                _scheduleSave();
                setState(() {});
              },
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: busy ? null : () => _fillOne(key, overwrite: true),
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(
                  context.t('إعادة توليد هذه الفقرة', 'Regenerate this section'),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
