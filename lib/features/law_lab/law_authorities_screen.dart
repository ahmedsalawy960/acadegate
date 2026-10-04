import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import 'law_lab_branding.dart';
import 'law_lab_models.dart';
import 'law_lab_storage.dart';

class LawAuthoritiesScreen extends StatefulWidget {
  const LawAuthoritiesScreen({super.key});

  @override
  State<LawAuthoritiesScreen> createState() => _LawAuthoritiesScreenState();
}

class _LawAuthoritiesScreenState extends State<LawAuthoritiesScreen> {
  static const _brand = Color(LawLabBranding.brand);
  LawProject? _project;
  bool _loading = true;

  static const _kinds = <(String, String, String)>[
    ('constitution', 'دستور', 'Constitution'),
    ('statute', 'تشريع', 'Statute'),
    ('regulation', 'لائحة/قرار', 'Regulation'),
    ('judgment', 'حكم', 'Judgment'),
    ('doctrine', 'فقه/شرح', 'Doctrine'),
    ('treaty', 'معاهدة', 'Treaty'),
    ('soft', 'إرشادي', 'Soft law'),
  ];

  static const _statuses = <(String, String, String)>[
    ('in_force', 'نافذ', 'In force'),
    ('amended', 'معدَّل', 'Amended'),
    ('repealed', 'ملغى/مستبدل', 'Repealed'),
    ('unknown', 'غير مؤكد', 'Unknown'),
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
    if (p == null) return;
    setState(() {
      p.authorities.add(
        LawAuthority(
          id: 'au_${DateTime.now().microsecondsSinceEpoch}',
          kind: 'statute',
          title: 'سند جديد',
          status: 'in_force',
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _project == null) {
      return Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(context.t('سجل الأسانيد', 'Authorities ledger')),
          backgroundColor: _brand,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final p = _project!;
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('سجل الأسانيد', 'Authorities ledger')),
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
        label: Text(context.t('سند', 'Authority')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        children: [
          Text(
            context.t(
              'رتّب من الأعلى للأدنى: دستور → تشريع → لائحة → حكم → فقه. '
              'لا تعتمد سنداً بحالة «غير مؤكد» في المسودة النهائية.',
              'Rank hierarchy: constitution → statute → regulation → judgment → doctrine. '
              'Do not rely on “unknown” status in the final draft.',
            ),
            style: TextStyle(color: const Color(0xFFB7C3D6), height: 1.4),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < p.authorities.length; i++)
            _AuthorityCard(
              index: i,
              item: p.authorities[i],
              kinds: _kinds,
              statuses: _statuses,
              linkCount: p.linksForAuthority(p.authorities[i].id),
              onDelete: () {
                final id = p.authorities[i].id;
                setState(() {
                  p.authorities.removeAt(i);
                  p.links.removeWhere((l) => l.authorityId == id);
                });
              },
            ),
        ],
      ),
    );
  }
}

class _AuthorityCard extends StatelessWidget {
  final int index;
  final LawAuthority item;
  final List<(String, String, String)> kinds;
  final List<(String, String, String)> statuses;
  final int linkCount;
  final VoidCallback onDelete;

  const _AuthorityCard({
    required this.index,
    required this.item,
    required this.kinds,
    required this.statuses,
    required this.linkCount,
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
                    context.t(
                      'سند ${index + 1} · $linkCount رابط',
                      'Authority ${index + 1} · $linkCount links',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                ),
              ],
            ),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: item.kind,
              decoration: InputDecoration(
                labelText: context.t('النوع', 'Type'),
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final k in kinds)
                  DropdownMenuItem(
                    value: k.$1,
                    child: Text(context.t(k.$2, k.$3)),
                  ),
              ],
              onChanged: (v) {
                if (v != null) item.kind = v;
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: item.title,
              decoration: InputDecoration(
                labelText: context.t('العنوان', 'Title'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => item.title = v,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: item.citation,
                    decoration: InputDecoration(
                      labelText: context.t('الإسناد / المادة', 'Citation / article'),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) => item.citation = v,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 88,
                  child: TextFormField(
                    initialValue: item.year,
                    decoration: InputDecoration(
                      labelText: context.t('السنة', 'Year'),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) => item.year = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: item.status,
              decoration: InputDecoration(
                labelText: context.t('حالة السريان', 'Status'),
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final s in statuses)
                  DropdownMenuItem(
                    value: s.$1,
                    child: Text(context.t(s.$2, s.$3)),
                  ),
              ],
              onChanged: (v) {
                if (v != null) item.status = v;
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: item.keyProvision,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: context.t('النص / المبدأ الحاكم', 'Key provision / principle'),
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => item.keyProvision = v,
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: item.notes,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: context.t('ملاحظات', 'Notes'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => item.notes = v,
            ),
          ],
        ),
      ),
    );
  }
}
