import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import 'qualitative_branding.dart';
import 'qualitative_models.dart';
import 'qualitative_storage.dart';

class QualitativeCodebookScreen extends StatefulWidget {
  const QualitativeCodebookScreen({super.key});

  @override
  State<QualitativeCodebookScreen> createState() =>
      _QualitativeCodebookScreenState();
}

class _QualitativeCodebookScreenState extends State<QualitativeCodebookScreen> {
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
      p.codes.add(
        QualCode(
          id: 'c_${DateTime.now().microsecondsSinceEpoch}',
          label: 'رمز جديد',
          definition: 'تعريف إجرائي مختصر',
        ),
      );
    });
  }

  Future<void> _importFromPath2() async {
    final p = _project;
    if (p == null) return;
    final n = await QualitativeStorage.instance.importCodesFromContentSheet(p);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          n == 0
              ? context.t(
                  'لا رموز جديدة للاستيراد من مسار ٢',
                  'No new codes to import from Path 2',
                )
              : context.t(
                  'تم استيراد $n رمزاً من ورقة تحليل المضمون',
                  'Imported $n code(s) from the content-analysis sheet',
                ),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _project == null) {
      return Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(context.t('دفتر الرموز', 'Codebook')),
          backgroundColor: _brand,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final p = _project!;
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('دفتر الرموز', 'Codebook')),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: context.t('استيراد تعريفات محفوظة', 'Import saved definitions'),
            onPressed: _importFromPath2,
            icon: const Icon(Icons.download_outlined),
          ),
          IconButton(onPressed: _save, icon: const Icon(Icons.save_outlined)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: Text(context.t('رمز', 'Code')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        children: [
          Text(
            context.t(
              'رمز جيد: قصير، واضح، يصف معنى مشتركاً — وليس عنوان فصل جاهز.',
              'A good code is short and clear — it labels meaning, not a chapter heading.',
            ),
            style: TextStyle(color: const Color(0xFFB7C3D6), height: 1.4),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < p.codes.length; i++)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.t(
                              'رمز ${i + 1} · ${p.excerptsForCode(p.codes[i].id)} مقتطف',
                              'Code ${i + 1} · ${p.excerptsForCode(p.codes[i].id)} excerpts',
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            final id = p.codes[i].id;
                            setState(() {
                              p.codes.removeAt(i);
                              for (final e in p.excerpts) {
                                e.codeIds.remove(id);
                              }
                              for (final t in p.themes) {
                                t.codeIds.remove(id);
                              }
                            });
                          },
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                    TextFormField(
                      initialValue: p.codes[i].label,
                      decoration: InputDecoration(
                        labelText: context.t('اسم الرمز', 'Code label'),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (v) => p.codes[i].label = v,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: p.codes[i].definition,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: context.t('التعريف', 'Definition'),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (v) => p.codes[i].definition = v,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: p.codes[i].inclusionNotes,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: context.t(
                          'متى يُطبَّق / لا يُطبَّق',
                          'When to apply / not apply',
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (v) => p.codes[i].inclusionNotes = v,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
