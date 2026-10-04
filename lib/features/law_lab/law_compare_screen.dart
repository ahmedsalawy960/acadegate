import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import 'law_lab_branding.dart';
import 'law_lab_models.dart';
import 'law_lab_storage.dart';

class LawCompareScreen extends StatefulWidget {
  const LawCompareScreen({super.key});

  @override
  State<LawCompareScreen> createState() => _LawCompareScreenState();
}

class _LawCompareScreenState extends State<LawCompareScreen> {
  static const _brand = Color(LawLabBranding.brand);
  LawProject? _project;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await LawLabStorage.instance.loadOrCreate();
    if (!mounted) return;
    setState(() {
      _project = p;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final p = _project;
    if (p == null) return;
    await LawLabStorage.instance.save(p);
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
      p.comparisons.add(
        LawCompareRow(
          id: 'cm_${DateTime.now().microsecondsSinceEpoch}',
          issueLabel: 'نقطة مقارنة',
          foreignSystem: 'فرنسا / ألمانيا / …',
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _project == null) {
      return Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(context.t('مقارنة تشريعية', 'Comparative matrix')),
          backgroundColor: _brand,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final p = _project!;
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('مقارنة تشريعية', 'Comparative matrix')),
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
        label: Text(context.t('صف', 'Row')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        children: [
          Text(
            context.t(
              'المقارنة الوظيفية أفضل من نسخ النصوص: حدّد الوظيفة القانونية ثم قارن الحلول.',
              'Functional comparison beats text dumps: define the legal function, then compare solutions.',
            ),
            style: TextStyle(color: const Color(0xFFB7C3D6), height: 1.4),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < p.comparisons.length; i++)
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
                            context.t('مقارنة ${i + 1}', 'Comparison ${i + 1}'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              setState(() => p.comparisons.removeAt(i)),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                    TextFormField(
                      initialValue: p.comparisons[i].issueLabel,
                      decoration: InputDecoration(
                        labelText: context.t('نقطة المقارنة', 'Comparison point'),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (v) => p.comparisons[i].issueLabel = v,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: p.comparisons[i].egyptRule,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: context.t('الحكم في مصر', 'Egyptian rule'),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (v) => p.comparisons[i].egyptRule = v,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: p.comparisons[i].foreignSystem,
                      decoration: InputDecoration(
                        labelText: context.t('النظام المقارن', 'Foreign system'),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (v) => p.comparisons[i].foreignSystem = v,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: p.comparisons[i].foreignRule,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: context.t('الحكم المقارن', 'Foreign rule'),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (v) => p.comparisons[i].foreignRule = v,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: p.comparisons[i].note,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: context.t(
                          'تشابه / اختلاف / إشارة إصلاح',
                          'Similarity / difference / reform hint',
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (v) => p.comparisons[i].note = v,
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
