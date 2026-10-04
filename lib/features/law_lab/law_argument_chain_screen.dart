import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import 'law_lab_branding.dart';
import 'law_lab_models.dart';
import 'law_lab_storage.dart';

class LawArgumentChainScreen extends StatefulWidget {
  const LawArgumentChainScreen({super.key});

  @override
  State<LawArgumentChainScreen> createState() => _LawArgumentChainScreenState();
}

class _LawArgumentChainScreenState extends State<LawArgumentChainScreen> {
  static const _brand = Color(LawLabBranding.brand);
  LawProject? _project;
  bool _loading = true;

  static const _roles = <(String, String, String)>[
    ('supports', 'يؤيّد', 'Supports'),
    ('limits', 'يقيّد', 'Limits'),
    ('distinguishes', 'يميّز', 'Distinguishes'),
    ('against', 'يعارض', 'Against'),
  ];

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
    if (p == null || p.issues.isEmpty || p.authorities.isEmpty) return;
    setState(() {
      p.links.add(
        LawArgumentLink(
          id: 'lk_${DateTime.now().microsecondsSinceEpoch}',
          issueId: p.issues.first.id,
          authorityId: p.authorities.first.id,
          role: 'supports',
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _project == null) {
      return Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(context.t('سلسلة الاستدلال', 'Argument chain')),
          backgroundColor: _brand,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final p = _project!;
    final canAdd = p.issues.isNotEmpty && p.authorities.isNotEmpty;

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('سلسلة الاستدلال', 'Argument chain')),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _save, icon: const Icon(Icons.save_outlined)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        onPressed: canAdd ? _add : null,
        icon: const Icon(Icons.add),
        label: Text(context.t('رابط', 'Link')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        children: [
          Text(
            context.t(
              'الاستدلال القانوني = فرع المسألة + سند + دور السند (يؤيد/يقيّد/يميّز/يعارض).',
              'Legal argument = sub-issue + authority + role (supports/limits/distinguishes/against).',
            ),
            style: TextStyle(color: const Color(0xFFB7C3D6), height: 1.4),
          ),
          if (!canAdd) ...[
            const SizedBox(height: 12),
            Text(
              context.t(
                'أضف فروعاً في خريطة المسألة وأسانيد في السجل أولاً.',
                'Add issues and authorities first.',
              ),
              style: TextStyle(color: Colors.orange[900]),
            ),
          ],
          const SizedBox(height: 12),
          for (var i = 0; i < p.links.length; i++)
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
                            context.t('رابط ${i + 1}', 'Link ${i + 1}'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              setState(() => p.links.removeAt(i)),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: p.issues.any((x) => x.id == p.links[i].issueId)
                          ? p.links[i].issueId
                          : null,
                      decoration: InputDecoration(
                        labelText: context.t('الفرع', 'Issue'),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        for (final iss in p.issues)
                          DropdownMenuItem(
                            value: iss.id,
                            child: Text(
                              iss.title.isEmpty ? iss.id : iss.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => p.links[i].issueId = v);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: p.authorities
                              .any((x) => x.id == p.links[i].authorityId)
                          ? p.links[i].authorityId
                          : null,
                      decoration: InputDecoration(
                        labelText: context.t('السند', 'Authority'),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        for (final a in p.authorities)
                          DropdownMenuItem(
                            value: a.id,
                            child: Text(
                              '[${a.kindAr}] ${a.title.isEmpty ? a.id : a.title}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => p.links[i].authorityId = v);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: p.links[i].role,
                      decoration: InputDecoration(
                        labelText: context.t('دور السند', 'Authority role'),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        for (final r in _roles)
                          DropdownMenuItem(
                            value: r.$1,
                            child: Text(context.t(r.$2, r.$3)),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => p.links[i].role = v);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: p.links[i].note,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: context.t('تعليل الرابط', 'Link rationale'),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (v) => p.links[i].note = v,
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
