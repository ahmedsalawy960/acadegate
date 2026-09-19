import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';
import 'multi_source_supervisor_service.dart';
import 'official_university_directories.dart';
import 'supervisor_import_service.dart';

class MultiSourceImportTab extends StatefulWidget {
  final bool isAdmin;

  const MultiSourceImportTab({super.key, required this.isAdmin});

  @override
  State<MultiSourceImportTab> createState() => _MultiSourceImportTabState();
}

class _MultiSourceImportTabState extends State<MultiSourceImportTab> {
  final _universityController = TextEditingController();
  final _topicController = TextEditingController();
  final _nameController = TextEditingController();
  final _selected = <String>{};
  List<SupervisorSourceHit> _hits = const [];
  bool _searching = false;
  bool _importing = false;

  @override
  void dispose() {
    _universityController.dispose();
    _topicController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String _key(SupervisorSourceHit hit) => SupervisorSourceHit.dedupeKey(hit);

  Future<void> _search() async {
    setState(() {
      _searching = true;
      _hits = const [];
      _selected.clear();
    });
    try {
      final hits = await MultiSourceSupervisorService.instance.search(
        university: _universityController.text,
        topic: _topicController.text,
        personName: _nameController.text,
      );
      if (!mounted) return;
      setState(() => _hits = hits);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _import() async {
    final chosen = _hits.where((h) => _selected.contains(_key(h))).toList();
    if (chosen.isEmpty) return;
    setState(() => _importing = true);
    try {
      final result = await SupervisorImportService.instance.importSourceHits(
        hits: chosen,
        autoApprove: widget.isAdmin,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'استيراد ${result.imported} — تخطي ${result.skipped}',
              'Imported ${result.imported} — skipped ${result.skipped}',
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final directory = OfficialUniversityDirectories.match(
      _universityController.text,
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          context.t(
            'البحث لا يعتمد على OpenAlex وحده: ORCID + مواقع الجامعات الرسمية '
            '(عبر دليل الجامعة وWikidata) + Semantic Scholar + OpenAlex.',
            'Search does not rely on OpenAlex alone: ORCID + official university '
            'sites (directory + Wikidata) + Semantic Scholar + OpenAlex.',
          ),
          style: TextStyle(color: Colors.grey[800], height: 1.4),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _universityController,
          decoration: InputDecoration(
            labelText: context.t('الجامعة', 'University'),
            hintText: context.t('جامعة الفيوم / Fayoum University', 'Fayoum University'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (directory != null) ...[
          const SizedBox(height: 8),
          Text(
            context.t(
              'الموقع الرسمي: ${directory.displayUrl}',
              'Official site: ${directory.displayUrl}',
            ),
            style: TextStyle(color: Colors.teal[800], fontSize: 13),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _topicController,
          decoration: InputDecoration(
            labelText: context.t('التخصص / نقطة البحث', 'Field / research point'),
            hintText: context.t('كيمياء تحليلية / analytical chemistry', 'analytical chemistry'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: context.t('اسم الباحث (اختياري أو ORCID)', 'Researcher name (optional or ORCID)'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _searching ? null : _search,
          icon: _searching
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.hub_outlined),
          label: Text(context.t('بحث من كل المصادر', 'Search all sources')),
        ),
        if (_hits.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                context.t('${_hits.length} نتيجة', '${_hits.length} result(s)'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() {
                  _selected
                    ..clear()
                    ..addAll(_hits.map(_key));
                }),
                child: Text(context.t('اختيار الكل', 'Select all')),
              ),
              FilledButton(
                onPressed: _importing || _selected.isEmpty ? null : _import,
                child: Text(context.t('استيراد المحدد', 'Import selected')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final hit in _hits)
            CheckboxListTile(
              value: _selected.contains(_key(hit)),
              onChanged: (on) => setState(() {
                if (on == true) {
                  _selected.add(_key(hit));
                } else {
                  _selected.remove(_key(hit));
                }
              }),
              title: Text(hit.name),
              subtitle: Text(
                [
                  if (hit.institution.isNotEmpty) hit.institution,
                  if (hit.speciality.isNotEmpty) hit.speciality,
                  hit.sourceLabel,
                  if (hit.orcid != null) 'ORCID ${hit.orcid}',
                ].join(' · '),
              ),
            ),
        ],
      ],
    );
  }
}
