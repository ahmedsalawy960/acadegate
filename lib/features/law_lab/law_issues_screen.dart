import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import 'law_lab_branding.dart';
import 'law_lab_models.dart';
import 'law_lab_storage.dart';

class LawIssuesScreen extends StatefulWidget {
  const LawIssuesScreen({super.key});

  @override
  State<LawIssuesScreen> createState() => _LawIssuesScreenState();
}

class _LawIssuesScreenState extends State<LawIssuesScreen> {
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
      p.issues.add(
        LawIssue(
          id: 'iss_${DateTime.now().microsecondsSinceEpoch}',
          title: 'فرع جديد',
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _project == null) {
      return Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(context.t('خريطة المسألة', 'Issue map')),
          backgroundColor: _brand,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final p = _project!;
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('خريطة المسألة', 'Issue map')),
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
        label: Text(context.t('فرع', 'Issue')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        children: [
          Text(
            context.t(
              'كل فرع يجب أن يقبل سنداً قانونياً لاحقاً — تجنّب العناوين العامة الفضفاضة.',
              'Each sub-issue should later accept a legal authority — avoid vague headings.',
            ),
            style: TextStyle(color: const Color(0xFFB7C3D6), height: 1.4),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < p.issues.length; i++)
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
                              'فرع ${i + 1} · ${p.linksForIssue(p.issues[i].id)} رابط',
                              'Issue ${i + 1} · ${p.linksForIssue(p.issues[i].id)} links',
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            final id = p.issues[i].id;
                            setState(() {
                              p.issues.removeAt(i);
                              p.links.removeWhere((l) => l.issueId == id);
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
                      initialValue: p.issues[i].title,
                      decoration: InputDecoration(
                        labelText: context.t('عنوان الفرع', 'Issue title'),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (v) => p.issues[i].title = v,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: p.issues[i].notes,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: context.t('ملاحظات', 'Notes'),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (v) => p.issues[i].notes = v,
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
