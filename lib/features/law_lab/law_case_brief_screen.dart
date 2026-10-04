import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import 'law_lab_branding.dart';
import 'law_lab_models.dart';
import 'law_lab_storage.dart';

class LawCaseBriefScreen extends StatefulWidget {
  const LawCaseBriefScreen({super.key});

  @override
  State<LawCaseBriefScreen> createState() => _LawCaseBriefScreenState();
}

class _LawCaseBriefScreenState extends State<LawCaseBriefScreen> {
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
      p.briefs.add(
        LawCaseBrief(
          id: 'cb_${DateTime.now().microsecondsSinceEpoch}',
          court: 'محكمة النقض',
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _project == null) {
      return Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(context.t('بطاقة الحكم', 'Case brief')),
          backgroundColor: _brand,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final p = _project!;
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('بطاقة الحكم', 'Case brief')),
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
        label: Text(context.t('حكم', 'Case')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        children: [
          Text(
            context.t(
              'في مصر الأحكام مقنعة عملياً وليست سابقة ملزمة بالمعنى الأنجلوسكسوني — '
              'وثّق المبدأ وصلة الحكم بسؤالك بدقة.',
              'In Egypt judgments are practically persuasive, not common-law binding precedent — '
              'record the principle and its relevance carefully.',
            ),
            style: TextStyle(color: const Color(0xFFB7C3D6), height: 1.4),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < p.briefs.length; i++)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.t('حكم ${i + 1}', 'Case ${i + 1}'),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              setState(() => p.briefs.removeAt(i)),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                    TextFormField(
                      initialValue: p.briefs[i].court,
                      decoration: InputDecoration(
                        labelText: context.t('المحكمة', 'Court'),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (v) => p.briefs[i].court = v,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: p.briefs[i].caseRef,
                            decoration: InputDecoration(
                              labelText: context.t('رقم/مرجع', 'Case ref'),
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (v) => p.briefs[i].caseRef = v,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 88,
                          child: TextFormField(
                            initialValue: p.briefs[i].year,
                            decoration: InputDecoration(
                              labelText: context.t('السنة', 'Year'),
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (v) => p.briefs[i].year = v,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: p.briefs[i].facts,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: context.t('وقائع موجزة', 'Brief facts'),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (v) => p.briefs[i].facts = v,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: p.briefs[i].issue,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: context.t('المسألة القانونية', 'Legal issue'),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (v) => p.briefs[i].issue = v,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: p.briefs[i].holding,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: context.t('المنطوق / الخلاصة', 'Holding'),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (v) => p.briefs[i].holding = v,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: p.briefs[i].ratio,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: context.t('العلة / المبدأ', 'Ratio / principle'),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (v) => p.briefs[i].ratio = v,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: p.briefs[i].relevance,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: context.t('الصلة ببحثك', 'Relevance to your thesis'),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (v) => p.briefs[i].relevance = v,
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
