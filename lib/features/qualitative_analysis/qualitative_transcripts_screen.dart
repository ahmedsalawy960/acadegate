import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import 'qualitative_branding.dart';
import 'qualitative_models.dart';
import 'qualitative_storage.dart';

class QualitativeTranscriptsScreen extends StatefulWidget {
  const QualitativeTranscriptsScreen({super.key});

  @override
  State<QualitativeTranscriptsScreen> createState() =>
      _QualitativeTranscriptsScreenState();
}

class _QualitativeTranscriptsScreenState
    extends State<QualitativeTranscriptsScreen> {
  static const _brand = Color(QualitativeBranding.brand);
  QualProject? _project;
  bool _loading = true;

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

  void _add() {
    final p = _project;
    if (p == null) return;
    setState(() {
      p.transcripts.add(
        QualTranscript(
          id: 'tr_${DateTime.now().microsecondsSinceEpoch}',
          title: 'مقابلة ${p.transcripts.length + 1}',
          participantLabel: 'مشارك',
          body: '',
          familiarizationNotes: '',
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _project == null) {
      return Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(context.t('مكتبة النصوص', 'Transcript library')),
          backgroundColor: _brand,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final p = _project!;
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('مكتبة النصوص', 'Transcript library')),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _save, icon: const Icon(Icons.save_outlined)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: Text(context.t('نص', 'Transcript')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        children: [
          Text(
            context.t(
              'المرحلة ١: الصق تفريغ المقابلة، ثم اكتب ملاحظات الألفة قبل الترميز.',
              'Phase 1: paste the transcript, then write familiarisation notes before coding.',
            ),
            style: TextStyle(color: const Color(0xFFB7C3D6), height: 1.4),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < p.transcripts.length; i++)
            _TranscriptCard(
              index: i,
              item: p.transcripts[i],
              onChanged: () => setState(() {}),
              onDelete: () {
                setState(() {
                  final id = p.transcripts[i].id;
                  p.transcripts.removeAt(i);
                  p.excerpts.removeWhere((e) => e.transcriptId == id);
                });
              },
            ),
        ],
      ),
    );
  }
}

class _TranscriptCard extends StatelessWidget {
  final int index;
  final QualTranscript item;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _TranscriptCard({
    required this.index,
    required this.item,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.t('نص ${index + 1}', 'Transcript ${index + 1}'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: context.t('حذف', 'Delete'),
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                ),
              ],
            ),
            TextFormField(
              initialValue: item.title,
              decoration: InputDecoration(
                labelText: context.t('العنوان', 'Title'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) {
                item.title = v;
                onChanged();
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: item.participantLabel,
              decoration: InputDecoration(
                labelText: context.t('المشارك / المصدر', 'Participant / source'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) {
                item.participantLabel = v;
                onChanged();
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: item.body,
              minLines: 5,
              maxLines: 12,
              decoration: InputDecoration(
                labelText: context.t('نص التفريغ', 'Transcript text'),
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) {
                item.body = v;
                onChanged();
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: item.familiarizationNotes,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: context.t(
                  'ملاحظات الألفة (قبل الترميز)',
                  'Familiarisation notes (before coding)',
                ),
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) {
                item.familiarizationNotes = v;
                onChanged();
              },
            ),
          ],
        ),
      ),
    );
  }
}
