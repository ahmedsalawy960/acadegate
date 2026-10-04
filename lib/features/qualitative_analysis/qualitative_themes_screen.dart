import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import 'qualitative_branding.dart';
import 'qualitative_models.dart';
import 'qualitative_storage.dart';

class QualitativeThemesScreen extends StatefulWidget {
  const QualitativeThemesScreen({super.key});

  @override
  State<QualitativeThemesScreen> createState() =>
      _QualitativeThemesScreenState();
}

class _QualitativeThemesScreenState extends State<QualitativeThemesScreen> {
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
      p.themes.add(
        QualTheme(
          id: 'th_${DateTime.now().microsecondsSinceEpoch}',
          title: 'موضوع مرشّح',
          centralConcept: 'ما الحجة التي يقدّمها هذا الموضوع عن البيانات؟',
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _project == null) {
      return Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(context.t('بناء الموضوعات', 'Theme building')),
          backgroundColor: _brand,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final p = _project!;
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('بناء الموضوعات', 'Theme building')),
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
        label: Text(context.t('موضوع', 'Theme')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        children: [
          Text(
            context.t(
              'الموضوع ليس عنواناً عاماً («الأسرة»)، بل حجة منظّمة عن البيانات '
              '(«العلاقات الأسرية تُعاد صياغتها بعد تغيّر الدور»).',
              'A theme is not a broad topic (“family”) but an organising claim '
              '(“family ties are renegotiated after a role change”).',
            ),
            style: TextStyle(color: const Color(0xFFB7C3D6), height: 1.4),
          ),
          const SizedBox(height: 12),
          if (p.codes.isEmpty)
            Text(
              context.t(
                'أضف رموزاً أولاً ثم اجمعها هنا.',
                'Add codes first, then cluster them here.',
              ),
              style: TextStyle(color: Colors.orange[900]),
            ),
          for (var i = 0; i < p.themes.length; i++)
            _ThemeCard(
              index: i,
              theme: p.themes[i],
              project: p,
              onChanged: () => setState(() {}),
              onDelete: () => setState(() => p.themes.removeAt(i)),
            ),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final int index;
  final QualTheme theme;
  final QualProject project;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _ThemeCard({
    required this.index,
    required this.theme,
    required this.project,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final linkedQuotes = project.excerpts
        .where(
          (e) => e.codeIds.any(theme.codeIds.contains) && e.quote.trim().isNotEmpty,
        )
        .take(4)
        .toList();

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
                    context.t('موضوع ${index + 1}', 'Theme ${index + 1}'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                ),
              ],
            ),
            TextFormField(
              initialValue: theme.title,
              decoration: InputDecoration(
                labelText: context.t('عنوان الموضوع', 'Theme title'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) {
                theme.title = v;
                onChanged();
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: theme.centralConcept,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: context.t(
                  'المفهوم المنظّم المركزي',
                  'Central organising concept',
                ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) {
                theme.centralConcept = v;
                onChanged();
              },
            ),
            const SizedBox(height: 8),
            Text(
              context.t('الرموز المضمّنة', 'Included codes'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in project.codes)
                  FilterChip(
                    label: Text(
                      '${c.label} (${project.excerptsForCode(c.id)})',
                    ),
                    selected: theme.codeIds.contains(c.id),
                    onSelected: (sel) {
                      if (sel) {
                        if (!theme.codeIds.contains(c.id)) {
                          theme.codeIds.add(c.id);
                        }
                      } else {
                        theme.codeIds.remove(c.id);
                      }
                      onChanged();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: theme.writeup,
              minLines: 3,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: context.t(
                  'صياغة تحليلية (المراحل ٤–٦)',
                  'Analytic write-up (phases 4–6)',
                ),
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) {
                theme.writeup = v;
                onChanged();
              },
            ),
            if (linkedQuotes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                context.t('أدلة من المقتطفات', 'Evidence from excerpts'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              for (final q in linkedQuotes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '«${q.quote.trim()}»',
                    style: TextStyle(
                      height: 1.4,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[850],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
