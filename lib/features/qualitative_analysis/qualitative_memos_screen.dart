import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import 'qualitative_branding.dart';
import 'qualitative_models.dart';
import 'qualitative_storage.dart';

class QualitativeMemosScreen extends StatefulWidget {
  const QualitativeMemosScreen({super.key});

  @override
  State<QualitativeMemosScreen> createState() => _QualitativeMemosScreenState();
}

class _QualitativeMemosScreenState extends State<QualitativeMemosScreen> {
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
      p.memos.insert(
        0,
        QualMemo(
          id: 'm_${DateTime.now().microsecondsSinceEpoch}',
          title: 'مذكرة تحليلية',
          body: '',
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _project == null) {
      return Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(context.t('مذكرات تحليلية', 'Analytic memos')),
          backgroundColor: _brand,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final p = _project!;
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('مذكرات تحليلية', 'Analytic memos')),
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
        label: Text(context.t('مذكرة', 'Memo')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        children: [
          Text(
            context.t(
              'المذكرة تُظهر كيف تطوّر تفكيرك — مفيدة جداً عند مراجعة المشرف.',
              'Memos show how your thinking evolved — very useful in supervisor review.',
            ),
            style: TextStyle(color: const Color(0xFFB7C3D6), height: 1.4),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < p.memos.length; i++)
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
                            context.t('مذكرة ${i + 1}', 'Memo ${i + 1}'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              setState(() => p.memos.removeAt(i)),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                    TextFormField(
                      initialValue: p.memos[i].title,
                      decoration: InputDecoration(
                        labelText: context.t('العنوان', 'Title'),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (v) => p.memos[i].title = v,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: p.memos[i].body,
                      minLines: 3,
                      maxLines: 8,
                      decoration: InputDecoration(
                        labelText: context.t('النص', 'Body'),
                        alignLabelWithHint: true,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (v) {
                        p.memos[i].body = v;
                        p.memos[i].updatedAt = DateTime.now();
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      // ignore: deprecated_member_use
                      value: p.memos[i].linkedCodeId,
                      decoration: InputDecoration(
                        labelText: context.t('مرتبط برمز (اختياري)', 'Linked code'),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(context.t('— بدون —', '— none —')),
                        ),
                        for (final c in p.codes)
                          DropdownMenuItem(value: c.id, child: Text(c.label)),
                      ],
                      onChanged: (v) => setState(() => p.memos[i].linkedCodeId = v),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      // ignore: deprecated_member_use
                      value: p.memos[i].linkedThemeId,
                      decoration: InputDecoration(
                        labelText:
                            context.t('مرتبط بموضوع (اختياري)', 'Linked theme'),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(context.t('— بدون —', '— none —')),
                        ),
                        for (final t in p.themes)
                          DropdownMenuItem(
                            value: t.id,
                            child: Text(
                              t.title.isEmpty ? t.id : t.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) =>
                          setState(() => p.memos[i].linkedThemeId = v),
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
