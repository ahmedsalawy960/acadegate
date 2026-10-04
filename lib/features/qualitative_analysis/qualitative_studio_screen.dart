import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/theme/acadegate_theme.dart';
import 'qualitative_branding.dart';
import 'qualitative_codebook_screen.dart';
import 'qualitative_coding_screen.dart';
import 'qualitative_memos_screen.dart';
import 'qualitative_models.dart';
import 'qualitative_storage.dart';
import 'qualitative_themes_screen.dart';
import 'qualitative_transcripts_screen.dart';

/// مسار 3 — استوديو التحليل النوعي (Braun & Clarke عملياً).
class QualitativeStudioScreen extends StatefulWidget {
  const QualitativeStudioScreen({super.key});

  @override
  State<QualitativeStudioScreen> createState() => _QualitativeStudioScreenState();
}

class _QualitativeStudioScreenState extends State<QualitativeStudioScreen> {
  static const _brand = Color(QualitativeBranding.brand);
  QualProject? _project;
  bool _loading = true;
  late final TextEditingController _rqCtrl;

  @override
  void initState() {
    super.initState();
    _rqCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _rqCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await QualitativeStorage.instance.loadOrCreate();
    if (!mounted) return;
    setState(() {
      _project = p;
      _rqCtrl.text = p.researchQuestion;
      _loading = false;
    });
  }

  Future<void> _persist() async {
    final p = _project;
    if (p == null) return;
    p.researchQuestion = _rqCtrl.text;
    await QualitativeStorage.instance.save(p);
  }

  Future<void> _openTool(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    await _load();
  }

  Future<void> _copySummary() async {
    final p = _project;
    if (p == null) return;
    await Clipboard.setData(ClipboardData(text: p.summaryForMethodology()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t(
            'نُسخ ملخص التحليل — الصقه في المنهجية أو النتائج',
            'Analysis summary copied — paste into methods or findings',
          ),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _phaseDone(int n, QualProject p) {
    switch (n) {
      case 1:
        return p.transcripts.any(
          (t) =>
              t.body.trim().length > 40 &&
              t.familiarizationNotes.trim().isNotEmpty,
        );
      case 2:
        return p.codes.isNotEmpty && p.excerpts.isNotEmpty;
      case 3:
        return p.themes.isNotEmpty;
      case 4:
        return p.themes.length >= 2;
      case 5:
        return p.themes.any(
          (t) =>
              t.centralConcept.trim().isNotEmpty && t.writeup.trim().isNotEmpty,
        );
      case 6:
        return p.themes.any((t) => t.writeup.trim().length > 40);
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _project == null) {
      return Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(QualitativeBranding.title),
          backgroundColor: _brand,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final p = _project!;

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(QualitativeBranding.title),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: context.t('نسخ الملخص', 'Copy summary'),
            onPressed: _copySummary,
            icon: const Icon(Icons.copy_outlined),
          ),
          IconButton(
            tooltip: context.t('حفظ', 'Save'),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final savedText = context.t('تم الحفظ', 'Saved');
              await _persist();
              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(
                  content: Text(savedText),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Card(
            color: _brand.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    QualitativeBranding.tagline,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    QualitativeBranding.integrityNote,
                    style: TextStyle(height: 1.4, color: const Color(0xFFB7C3D6)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            context.t('إعداد المشروع', 'Project setup'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _rqCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: context.t('سؤال البحث', 'Research question'),
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => p.researchQuestion = v,
            onEditingComplete: _persist,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final opt in const [
                ('reflexive_ta', 'انعكاسي TA', 'Reflexive TA'),
                ('codebook_ta', 'دفتر رموز', 'Codebook TA'),
                ('content_analysis', 'مضمون', 'Content'),
              ])
                ChoiceChip(
                  label: Text(context.t(opt.$2, opt.$3)),
                  selected: p.approachId == opt.$1,
                  selectedColor: _brand.withValues(alpha: 0.18),
                  onSelected: (_) async {
                    setState(() => p.approachId = opt.$1);
                    await _persist();
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.t(
              '${p.transcripts.length} نص · ${p.codes.length} رمز · '
              '${p.excerpts.length} مقتطف · ${p.themes.length} موضوع',
              '${p.transcripts.length} transcripts · ${p.codes.length} codes · '
              '${p.excerpts.length} excerpts · ${p.themes.length} themes',
            ),
            style: TextStyle(color: const Color(0xFFB7C3D6), fontSize: 13),
          ),
          const SizedBox(height: 18),
          Text(
            context.t(
              'مراحل التحليل الموضوعي (إرشادية)',
              'Thematic analysis phases (guide)',
            ),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
          ),
          const SizedBox(height: 8),
          for (final phase in QualPhase.all)
            _PhaseTile(
              phase: phase,
              done: _phaseDone(phase.number, p),
              brand: _brand,
            ),
          const SizedBox(height: 14),
          Text(
            context.t('أدوات العمل', 'Work tools'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
          ),
          const SizedBox(height: 8),
          _ToolCard(
            icon: Icons.description_outlined,
            color: const Color(0xFF1565C0),
            title: context.t('مكتبة النصوص', 'Transcript library'),
            subtitle: context.t(
              'أضف نصوص المقابلات وملاحظات الألفة (المرحلة ١)',
              'Add interview transcripts and familiarisation notes (phase 1)',
            ),
            onTap: () => _openTool(const QualitativeTranscriptsScreen()),
          ),
          _ToolCard(
            icon: Icons.sell_outlined,
            color: const Color(0xFF6A1B9A),
            title: context.t('دفتر الرموز', 'Codebook'),
            subtitle: context.t(
              'عرّف رموز التحليل هنا — ويمكن اختيارياً سحب تعريفات محفوظة سابقاً',
              'Define analysis codes here — optionally pull previously saved definitions',
            ),
            onTap: () => _openTool(const QualitativeCodebookScreen()),
          ),
          _ToolCard(
            icon: Icons.highlight_alt_outlined,
            color: const Color(0xFFAD1457),
            title: context.t('مساحة الترميز', 'Coding workspace'),
            subtitle: context.t(
              'اربط مقتطفات من النص برمز أو أكثر (المرحلة ٢)',
              'Link transcript excerpts to one or more codes (phase 2)',
            ),
            onTap: () => _openTool(const QualitativeCodingScreen()),
          ),
          _ToolCard(
            icon: Icons.account_tree_outlined,
            color: const Color(0xFFEF6C00),
            title: context.t('بناء الموضوعات', 'Theme building'),
            subtitle: context.t(
              'اجمع الرموز في موضوعات بمفهوم منظّم مركزي (٣–٥)',
              'Cluster codes into themes with a central organising concept (3–5)',
            ),
            onTap: () => _openTool(const QualitativeThemesScreen()),
          ),
          _ToolCard(
            icon: Icons.sticky_note_2_outlined,
            color: const Color(0xFF5D4037),
            title: context.t('مذكرات تحليلية', 'Analytic memos'),
            subtitle: context.t(
              'سجّل تأملاتك واربطها برمز أو موضوع',
              'Capture reflections and link them to a code or theme',
            ),
            onTap: () => _openTool(const QualitativeMemosScreen()),
          ),
        ],
      ),
    );
  }
}

class _PhaseTile extends StatelessWidget {
  final QualPhase phase;
  final bool done;
  final Color brand;

  const _PhaseTile({
    required this.phase,
    required this.done,
    required this.brand,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: done
              ? brand.withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.12),
          foregroundColor: done ? brand : const Color(0xFFB7C3D6),
          child: done
              ? const Icon(Icons.check, size: 18)
              : Text(
                  '${phase.number}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
        ),
        title: Text(
          context.t(phase.titleAr, phase.titleEn),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
        subtitle: Text(
          context.t(phase.hintAr, phase.hintEn),
          style: const TextStyle(height: 1.3, fontSize: 12.5),
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: acadegateInk(color),
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: const TextStyle(height: 1.35)),
        trailing: const Icon(Icons.chevron_left),
        isThreeLine: true,
      ),
    );
  }
}
