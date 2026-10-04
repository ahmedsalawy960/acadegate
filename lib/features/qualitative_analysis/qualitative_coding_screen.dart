import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import 'qualitative_branding.dart';
import 'qualitative_models.dart';
import 'qualitative_storage.dart';

class QualitativeCodingScreen extends StatefulWidget {
  const QualitativeCodingScreen({super.key});

  @override
  State<QualitativeCodingScreen> createState() =>
      _QualitativeCodingScreenState();
}

class _QualitativeCodingScreenState extends State<QualitativeCodingScreen> {
  static const _brand = Color(QualitativeBranding.brand);
  QualProject? _project;
  bool _loading = true;
  String? _selectedTranscriptId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await QualitativeStorage.instance.loadOrCreate();
    if (!mounted) return;
    setState(() {
      _project = p;
      _selectedTranscriptId =
          p.transcripts.isEmpty ? null : p.transcripts.first.id;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final p = _project;
    if (p == null) return;
    await QualitativeStorage.instance.save(p);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.t('تم الحفظ', 'Saved')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _addExcerpt() {
    final p = _project;
    final tid = _selectedTranscriptId;
    if (p == null || tid == null) return;
    setState(() {
      p.excerpts.insert(
        0,
        QualExcerpt(
          id: 'ex_${DateTime.now().microsecondsSinceEpoch}',
          transcriptId: tid,
          quote: '',
        ),
      );
    });
  }

  List<QualExcerpt> get _filtered {
    final p = _project;
    final tid = _selectedTranscriptId;
    if (p == null || tid == null) return const [];
    return p.excerpts.where((e) => e.transcriptId == tid).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _project == null) {
      return Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(context.t('مساحة الترميز', 'Coding workspace')),
          backgroundColor: _brand,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final p = _project!;
    if (p.transcripts.isEmpty) {
      return Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(context.t('مساحة الترميز', 'Coding workspace')),
          backgroundColor: _brand,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              context.t(
                'أضف نص مقابلة أولاً من مكتبة النصوص.',
                'Add a transcript first from the transcript library.',
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final tr = p.transcriptById(_selectedTranscriptId ?? '');

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('مساحة الترميز', 'Coding workspace')),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _save, icon: const Icon(Icons.save_outlined)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        onPressed: p.codes.isEmpty ? null : _addExcerpt,
        icon: const Icon(Icons.add),
        label: Text(context.t('مقتطف', 'Excerpt')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        children: [
          Text(
            context.t(
              'انسخ مقتطفاً من النص، ثم اختر الرموز المناسبة. لا تختلق اقتباسات.',
              'Paste an excerpt from the transcript, then pick codes. Do not invent quotes.',
            ),
            style: TextStyle(color: const Color(0xFFB7C3D6), height: 1.4),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: _selectedTranscriptId,
            decoration: InputDecoration(
              labelText: context.t('النص', 'Transcript'),
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final t in p.transcripts)
                DropdownMenuItem(
                  value: t.id,
                  child: Text(
                    '${t.title.isEmpty ? t.id : t.title}'
                    '${t.participantLabel.isEmpty ? '' : ' · ${t.participantLabel}'}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _selectedTranscriptId = v),
          ),
          if (tr != null && tr.body.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Card(
              color: Colors.grey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('معاينة النص', 'Transcript preview'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr.body.length > 600
                          ? '${tr.body.substring(0, 600)}…'
                          : tr.body,
                      style: const TextStyle(height: 1.45, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (p.codes.isEmpty) ...[
            const SizedBox(height: 16),
            Text(
              context.t(
                'أنشئ رموزاً في دفتر الرموز قبل الترميز.',
                'Create codes in the codebook before coding.',
              ),
              style: TextStyle(color: Colors.orange[900]),
            ),
          ],
          const SizedBox(height: 12),
          for (final ex in _filtered)
            _ExcerptCard(
              excerpt: ex,
              project: p,
              onChanged: () => setState(() {}),
              onDelete: () {
                setState(() => p.excerpts.removeWhere((e) => e.id == ex.id));
              },
            ),
        ],
      ),
    );
  }
}

class _ExcerptCard extends StatelessWidget {
  final QualExcerpt excerpt;
  final QualProject project;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _ExcerptCard({
    required this.excerpt,
    required this.project,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.t('مقتطف مرمّز', 'Coded excerpt'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                ),
              ],
            ),
            TextFormField(
              initialValue: excerpt.quote,
              minLines: 3,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: context.t('الاقتباس', 'Quote'),
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) {
                excerpt.quote = v;
                onChanged();
              },
            ),
            const SizedBox(height: 8),
            Text(
              context.t('الرموز', 'Codes'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in project.codes)
                  FilterChip(
                    label: Text(c.label),
                    selected: excerpt.codeIds.contains(c.id),
                    onSelected: (sel) {
                      if (sel) {
                        if (!excerpt.codeIds.contains(c.id)) {
                          excerpt.codeIds.add(c.id);
                        }
                      } else {
                        excerpt.codeIds.remove(c.id);
                      }
                      onChanged();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: excerpt.note,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: context.t('ملاحظة تحليلية (اختياري)', 'Analytic note'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) {
                excerpt.note = v;
                onChanged();
              },
            ),
          ],
        ),
      ),
    );
  }
}
