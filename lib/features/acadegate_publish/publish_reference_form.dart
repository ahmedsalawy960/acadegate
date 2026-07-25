import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';
import 'publish_models.dart';

Future<PublishReference?> showPublishReferenceForm(
  BuildContext context, {
  PublishReference? existing,
}) {
  return showModalBottomSheet<PublishReference>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _PublishReferenceFormSheet(existing: existing),
  );
}

class _PublishReferenceFormSheet extends StatefulWidget {
  final PublishReference? existing;

  const _PublishReferenceFormSheet({this.existing});

  @override
  State<_PublishReferenceFormSheet> createState() =>
      _PublishReferenceFormSheetState();
}

class _PublishReferenceFormSheetState extends State<_PublishReferenceFormSheet> {
  late ReferenceType _type;
  late final TextEditingController _authorsCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _containerCtrl;
  late final TextEditingController _yearCtrl;
  late final TextEditingController _volumeCtrl;
  late final TextEditingController _issueCtrl;
  late final TextEditingController _pagesCtrl;
  late final TextEditingController _doiCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _publisherCtrl;
  late final TextEditingController _conferenceCtrl;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? ReferenceType.journal;
    _authorsCtrl = TextEditingController(text: e?.authors.join('; ') ?? '');
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _containerCtrl = TextEditingController(text: e?.container ?? '');
    _yearCtrl = TextEditingController(text: e?.year ?? '');
    _volumeCtrl = TextEditingController(text: e?.volume ?? '');
    _issueCtrl = TextEditingController(text: e?.issue ?? '');
    _pagesCtrl = TextEditingController(text: e?.pages ?? '');
    _doiCtrl = TextEditingController(text: e?.doi ?? '');
    _urlCtrl = TextEditingController(text: e?.url ?? '');
    _publisherCtrl = TextEditingController(text: e?.publisher ?? '');
    _conferenceCtrl = TextEditingController(text: e?.conference ?? '');
  }

  @override
  void dispose() {
    _authorsCtrl.dispose();
    _titleCtrl.dispose();
    _containerCtrl.dispose();
    _yearCtrl.dispose();
    _volumeCtrl.dispose();
    _issueCtrl.dispose();
    _pagesCtrl.dispose();
    _doiCtrl.dispose();
    _urlCtrl.dispose();
    _publisherCtrl.dispose();
    _conferenceCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    final authors = _authorsCtrl.text
        .split(';')
        .map((a) => a.trim())
        .where((a) => a.isNotEmpty)
        .toList();

    Navigator.pop(
      context,
      PublishReference(
        id: widget.existing?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        type: _type,
        authors: authors,
        title: title,
        container: _containerCtrl.text.trim(),
        year: _yearCtrl.text.trim(),
        volume: _volumeCtrl.text.trim(),
        issue: _issueCtrl.text.trim(),
        pages: _pagesCtrl.text.trim(),
        doi: _doiCtrl.text.trim(),
        url: _urlCtrl.text.trim(),
        publisher: _publisherCtrl.text.trim(),
        conference: _conferenceCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.t('مرجع bibliographic', 'Bibliographic reference'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ReferenceType>(
              initialValue: _type,
              decoration: InputDecoration(
                labelText: context.t('نوع المرجع', 'Reference type'),
                border: const OutlineInputBorder(),
              ),
              items: ReferenceType.values
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(_typeLabel(context, t)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _authorsCtrl,
              decoration: InputDecoration(
                labelText: context.t(
                  'المؤلفون (افصل بـ ;)',
                  'Authors (separate with ;)',
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: context.t('العنوان', 'Title'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            if (_type == ReferenceType.journal) ...[
              TextField(
                controller: _containerCtrl,
                decoration: InputDecoration(
                  labelText: context.t('اسم المجلة', 'Journal name'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _volumeCtrl,
                      decoration: InputDecoration(
                        labelText: context.t('المجلد', 'Volume'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _issueCtrl,
                      decoration: InputDecoration(
                        labelText: context.t('العدد', 'Issue'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (_type == ReferenceType.book) ...[
              TextField(
                controller: _publisherCtrl,
                decoration: InputDecoration(
                  labelText: context.t('الناشر', 'Publisher'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            if (_type == ReferenceType.web) ...[
              TextField(
                controller: _containerCtrl,
                decoration: InputDecoration(
                  labelText: context.t('اسم الموقع', 'Site name'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _urlCtrl,
                decoration: InputDecoration(
                  labelText: 'URL',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            if (_type == ReferenceType.conference) ...[
              TextField(
                controller: _conferenceCtrl,
                decoration: InputDecoration(
                  labelText: context.t('اسم المؤتمر', 'Conference name'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _yearCtrl,
                    decoration: InputDecoration(
                      labelText: context.t('السنة', 'Year'),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _pagesCtrl,
                    decoration: InputDecoration(
                      labelText: context.t('الصفحات', 'Pages'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            if (_type == ReferenceType.journal) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _doiCtrl,
                decoration: InputDecoration(
                  labelText: 'DOI',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: Text(context.t('حفظ المرجع', 'Save reference')),
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(BuildContext context, ReferenceType t) => switch (t) {
        ReferenceType.journal => context.t('مقال مجلة', 'Journal article'),
        ReferenceType.book => context.t('كتاب', 'Book'),
        ReferenceType.web => context.t('موقع', 'Website'),
        ReferenceType.conference => context.t('مؤتمر', 'Conference'),
      };
}
