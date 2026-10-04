import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../academic_writing/writing_categories.dart';
import '../academic_writing/writing_expert_list_screen.dart';
import '../academic_writing/writing_hub_screen.dart';
import 'research_proposal_branding.dart';
import 'research_proposal_models.dart';
import 'research_proposal_storage.dart';
import 'research_proposal_workshop.dart';

/// طلب مراجعة بشرية (تربية/قانون/مقترحات) قبل العرض على القسم.
class ResearchProposalReviewScreen extends StatefulWidget {
  const ResearchProposalReviewScreen({super.key});

  @override
  State<ResearchProposalReviewScreen> createState() =>
      _ResearchProposalReviewScreenState();
}

class _ResearchProposalReviewScreenState
    extends State<ResearchProposalReviewScreen> {
  static const _brand = Color(ResearchProposalBranding.brand);

  ProposalDraft? _draft;
  bool _loading = true;
  late final TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final d = await ResearchProposalStorage.instance.loadOrCreate();
    if (!mounted) return;
    setState(() {
      _draft = d;
      _notesCtrl.text = d.expertNotes;
      _loading = false;
    });
  }

  Future<void> _persist() async {
    final d = _draft;
    if (d == null) return;
    d.expertNotes = _notesCtrl.text.trim();
    await ResearchProposalStorage.instance.save(d);
  }

  String _brief(ProposalDraft d) {
    final report = ProposalConsistencyEngine.instance.evaluate(d);
    final b = StringBuffer();
    b.writeln('طلب مراجعة خطة بحث — قبل العرض على القسم');
    b.writeln('التخصص المفضّل للمراجع: ${d.preferredExpertTrack}');
    b.writeln('الكلية: ${d.facultyId} · فقرات مفعّلة: ${d.activeSections.length}');
    if (d.titleAr.isNotEmpty) b.writeln('العنوان: ${d.titleAr}');
    if (d.titleEn.isNotEmpty) b.writeln('Title: ${d.titleEn}');
    b.writeln('درجة الاتساق الآلي: ${report.score}%');
    if (report.issues.isNotEmpty) {
      b.writeln('أبرز ملاحظات الاتساق:');
      for (final i in report.issues.take(6)) {
        b.writeln('- ${i.titleAr}');
      }
    }
    if (d.expertNotes.trim().isNotEmpty) {
      b.writeln('');
      b.writeln('طلب الباحث من المراجع:');
      b.writeln(d.expertNotes.trim());
    }
    b.writeln('');
    b.writeln('--- مسودة موجزة ---');
    b.writeln(d.exportText(arabic: true));
    return b.toString().trim();
  }

  Future<void> _copyBrief() async {
    await _persist();
    final d = _draft;
    if (d == null) return;
    await Clipboard.setData(ClipboardData(text: _brief(d)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t(
            'نُسخ موجز المراجعة — الصقه في طلب الخبير',
            'Review brief copied — paste into the expert order',
          ),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openExperts() async {
    await _persist();
    await _copyBrief();
    if (!mounted) return;
    final cat = writingCategoryById('proposal');
    if (cat == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WritingHubScreen()),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WritingExpertListScreen(category: cat)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(context.t('مراجعة بشرية', 'Human review')),
          backgroundColor: _brand,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final draft = _draft!;
    final report = ProposalConsistencyEngine.instance.evaluate(draft);

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('مراجعة بشرية قبل القسم', 'Human review before department')),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Card(
            color: const Color(0xFF6A1B9A).withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                context.t(
                  'بعد اختيار فقرات كليتك وتشخيص المسودة: اطلب مراجعة من خبير تربية أو قانون أو آداب '
                  '(أو مقترحات بحث) قبل السمينار/مجلس القسم. المراجعة البشرية لا تلغي اعتماد القسم الرسمي.',
                  'After choosing your faculty sections and diagnosing the draft: request Education/Law/Arts '
                  '(or proposal) expert review before seminar/department board. '
                  'Human review does not replace official department approval.',
                ),
                style: const TextStyle(height: 1.45),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            context.t('تخصص المراجع المفضّل', 'Preferred reviewer track'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final e in [
                ('education', 'تربية', 'Education'),
                ('law', 'قانون', 'Law'),
                ('arts', 'آداب', 'Arts'),
                ('any', 'أي خبير مقترح', 'Any proposal expert'),
              ])
                ChoiceChip(
                  label: Text(context.t(e.$2, e.$3)),
                  selected: draft.preferredExpertTrack == e.$1,
                  selectedColor: _brand.withValues(alpha: 0.22),
                  onSelected: (_) async {
                    setState(() => draft.preferredExpertTrack = e.$1);
                    await ResearchProposalStorage.instance.save(draft);
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            context.t('ماذا تريد من المراجع؟', 'What should the reviewer check?'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _notesCtrl,
            minLines: 4,
            maxLines: 8,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: context.t(
                'مثال: راجع اتساق الأسئلة مع الأداة، ونقد الدراسات السابقة، وصياغة العنوان…',
                'e.g. Check questions–instrument fit, critical lit review, title wording…',
              ),
            ),
            onChanged: (_) => _persist(),
          ),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: Icon(
                report.score >= 70 ? Icons.verified_outlined : Icons.warning_amber,
                color: report.score >= 70 ? Colors.green[700] : Colors.orange[800],
              ),
              title: Text(
                context.t(
                  'درجة الاتساق الحالية: ${report.score}%',
                  'Current consistency score: ${report.score}%',
                ),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                context.t(
                  report.score >= 70
                      ? 'جاهز تقريباً لطلب مراجعة بشرية.'
                      : 'يُفضَّل تحسين المسودة/الورشة قبل إرسالها للخبير.',
                  report.score >= 70
                      ? 'Roughly ready for human review.'
                      : 'Improve the draft/workshop before sending to an expert.',
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _openExperts,
            icon: const Icon(Icons.person_search_outlined),
            label: Text(
              context.t(
                'نسخ الموجز وفتح خبراء خطة البحث',
                'Copy brief & open proposal experts',
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _brand,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _copyBrief,
            icon: const Icon(Icons.copy_all_outlined),
            label: Text(context.t('نسخ موجز المراجعة فقط', 'Copy review brief only')),
          ),
        ],
      ),
    );
  }
}
