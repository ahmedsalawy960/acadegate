import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';
import 'academic_reference_lookup_service.dart';
import 'citation_formatter.dart';
import 'manuscript_citation_helper.dart';
import 'manuscript_preview.dart';
import 'manuscript_table_dialog.dart';
import 'manuscript_upload_service.dart';
import 'publish_models.dart';

class ManuscriptBodyEditor extends StatefulWidget {
  final PublishManuscript manuscript;
  final bool readOnly;
  final ValueChanged<List<ManuscriptBlock>> onBlocksChanged;
  final ValueChanged<PublishReference>? onReferenceAdded;

  const ManuscriptBodyEditor({
    super.key,
    required this.manuscript,
    required this.readOnly,
    required this.onBlocksChanged,
    this.onReferenceAdded,
  });

  @override
  State<ManuscriptBodyEditor> createState() => _ManuscriptBodyEditorState();
}

class _ManuscriptBodyEditorState extends State<ManuscriptBodyEditor> {
  late List<ManuscriptBlock> _blocks;
  final Map<String, GlobalKey<_BlockTextFieldState>> _fieldKeys = {};
  static const _maxEditBlocks = 60;
  bool _showAllBlocks = true;

  @override
  void initState() {
    super.initState();
    _blocks = List.of(widget.manuscript.bodyBlocks);
  }

  @override
  void didUpdateWidget(ManuscriptBodyEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.manuscript.bodyBlocks != widget.manuscript.bodyBlocks) {
      _blocks = List.of(widget.manuscript.bodyBlocks);
    }
  }

  GlobalKey<_BlockTextFieldState> _keyFor(String blockId) =>
      _fieldKeys.putIfAbsent(blockId, GlobalKey<_BlockTextFieldState>.new);

  void _emit() => widget.onBlocksChanged(_blocks);

  void _addBlock(ManuscriptBlock block) {
    setState(() => _blocks = [..._blocks, block]);
    _emit();
  }

  void _updateBlock(int index, ManuscriptBlock block) {
    final next = [..._blocks];
    next[index] = block;
    setState(() => _blocks = next);
    _emit();
  }

  void _removeBlock(int index) {
    final removed = _blocks[index];
    _fieldKeys.remove(removed.id);
    setState(() => _blocks = [..._blocks]..removeAt(index));
    _emit();
  }

  void _moveBlock(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _blocks.length) return;
    final next = [..._blocks];
    final item = next.removeAt(index);
    next.insert(target, item);
    setState(() => _blocks = next);
    _emit();
  }

  Future<void> _insertCitation(int index) async {
    final block = _blocks[index];
    if (block.type != ManuscriptBlockType.paragraph &&
        block.type != ManuscriptBlockType.heading) {
      return;
    }

    final fieldState = _keyFor(block.id).currentState;
    final cursor = fieldState?.cursorOffset ?? block.text.length;

    final result = await showDialog<_CitationInsertResult>(
      context: context,
      builder: (ctx) => _InsertCitationDialog(
        references: widget.manuscript.references,
        style: widget.manuscript.effectiveStyle,
      ),
    );
    if (result == null) return;

    if (result.isNewReference) {
      widget.onReferenceAdded?.call(result.reference);
    }

    final marker = ManuscriptCitationHelper.citationMarker(
      result.reference.id,
      form: result.form,
    );
    final newText = ManuscriptCitationHelper.insertCitationAt(
      block.text,
      cursor,
      marker,
    );
    _updateBlock(index, block.copyWith(text: newText));
    fieldState?.setTextAndSelection(newText, cursor + marker.length);
  }

  Future<void> _addImage() async {
    if (widget.readOnly) return;
    final file = await ManuscriptUploadService.instance.pickImageFromGallery();
    if (file == null || widget.manuscript.id == null) return;

    try {
      final url = await ManuscriptUploadService.instance.uploadImage(
        manuscriptId: widget.manuscript.id!,
        file: file,
      );
      _addBlock(
        ManuscriptBlock(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: ManuscriptBlockType.image,
          imageUrl: url,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _addTable() async {
    final result = await showManuscriptTableDialog(context);
    if (result == null) return;
    _addBlock(
      ManuscriptBlock(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: ManuscriptBlockType.table,
        rows: result.rows,
        caption: result.caption,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.readOnly)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _toolBtn(Icons.text_fields, context.t('فقرة', 'Paragraph'), () {
                  _addBlock(ManuscriptBlock(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    type: ManuscriptBlockType.paragraph,
                  ));
                }),
                _toolBtn(Icons.title, context.t('عنوان', 'Heading'), () {
                  _addBlock(ManuscriptBlock(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    type: ManuscriptBlockType.heading,
                  ));
                }),
                _toolBtn(
                    Icons.image_outlined, context.t('صورة', 'Image'), _addImage),
                _toolBtn(Icons.table_chart_outlined, context.t('جدول', 'Table'),
                    _addTable),
                _toolBtn(Icons.functions, context.t('معادلة', 'Equation'), () {
                  _addBlock(ManuscriptBlock(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    type: ManuscriptBlockType.equation,
                  ));
                }),
              ],
            ),
          ),
        const SizedBox(height: 8),
        if (!widget.readOnly)
          Card(
            color: Colors.blue.shade50,
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.format_quote,
                          color: Colors.blue.shade800, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.t(
                            'إدراج اقتباس في النص',
                            'Insert citation in text',
                          ),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.t(
                      '① ضع المؤشر داخل الفقرة\n'
                      '② اضغط «إدراج اقتباس» واختر شكل الاقتباس\n'
                      '③ تُولَّد قائمة المراجع في نهاية البحث من الاقتباسات المدرجة',
                      '① Place the cursor inside a paragraph\n'
                      '② Tap «Insert citation» and choose the citation form\n'
                      '③ References at the end are generated from inserted citations',
                    ),
                    style: TextStyle(
                        fontSize: 12, height: 1.45, color: Colors.blue.shade900),
                  ),
                ],
              ),
            ),
          ),
        if (_blocks.isNotEmpty && _blocks.length <= 12)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              context.t(
                'هيكل المسودة: (1) العنوان والمؤلفون (2) الملخص والكلمات المفتاحية (3) متن البحث مع الجداول والصور',
                'Draft layout: (1) Title & authors (2) Abstract & keywords (3) Body with tables & figures',
              ),
              style:
                  TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.4),
            ),
          ),
        if (_blocks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              context.t(
                'استخدم شريط الأدوات لإضافة فقرات، صور، جداول، أو معادلات',
                'Use the toolbar to add paragraphs, images, tables, or equations',
              ),
              style: TextStyle(color: Colors.grey[600]),
            ),
          )
        else ...[
          if (_blocks.length > _maxEditBlocks && !_showAllBlocks)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                context.t(
                  'عرض $_maxEditBlocks من ${_blocks.length} عنصر — المحتوى الكامل في تبويب المعاينة',
                  'Showing $_maxEditBlocks of ${_blocks.length} blocks — full content in Preview tab',
                ),
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ),
          ...List.generate(
            _showAllBlocks
                ? _blocks.length
                : _blocks.length.clamp(0, _maxEditBlocks),
            (i) => _blockTile(i),
          ),
          if (_blocks.length > _maxEditBlocks && !_showAllBlocks)
            TextButton.icon(
              onPressed: () => setState(() => _showAllBlocks = true),
              icon: const Icon(Icons.unfold_more),
              label: Text(context.t(
                'عرض كل العناصر (${_blocks.length})',
                'Show all blocks (${_blocks.length})',
              )),
            ),
        ],
      ],
    );
  }

  Widget _toolBtn(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6, bottom: 6),
      child: ActionChip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        onPressed: onTap,
      ),
    );
  }

  Widget _blockTile(int index) {
    final block = _blocks[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (_importSectionLabel(index, block) case final label?)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Chip(
                      label: Text(label, style: const TextStyle(fontSize: 10)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                Text(
                  _blockTypeLabel(context, block.type),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (!widget.readOnly) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_upward, size: 18),
                    onPressed: () => _moveBlock(index, -1),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_downward, size: 18),
                    onPressed: () => _moveBlock(index, 1),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        color: Colors.red[400], size: 20),
                    onPressed: () => _removeBlock(index),
                  ),
                ],
              ],
            ),
            _blockEditor(index, block),
          ],
        ),
      ),
    );
  }

  Widget _blockEditor(int index, ManuscriptBlock block) {
    if (widget.readOnly) {
      return ManuscriptBlockPreview(
        block: block,
        manuscript: widget.manuscript,
      );
    }

    return switch (block.type) {
      ManuscriptBlockType.paragraph || ManuscriptBlockType.heading => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BlockTextField(
              key: _keyFor(block.id),
              initialText: block.text,
              minLines: block.type == ManuscriptBlockType.heading ? 1 : 4,
              maxLines: block.type == ManuscriptBlockType.heading ? 3 : null,
              hint: block.type == ManuscriptBlockType.heading
                  ? context.t('عنوان فرعي', 'Section heading')
                  : context.t('نص الفقرة', 'Paragraph text'),
              onChanged: (v) => _updateBlock(index, block.copyWith(text: v)),
            ),
            TextButton.icon(
              onPressed: () => _insertCitation(index),
              icon: const Icon(Icons.format_quote, size: 18),
              label: Text(context.t('إدراج اقتباس', 'Insert citation')),
            ),
            Text(
              context.t(
                'ضع المؤشر في موضع الإدراج ثم اضغط الزر',
                'Place the cursor where you want the citation, then tap',
              ),
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ManuscriptBlockType.equation => _BlockTextField(
          key: _keyFor('eq_${block.id}'),
          initialText: block.text,
          minLines: 2,
          maxLines: 6,
          hint: context.t('LaTeX أو نص المعادلة', 'LaTeX or equation text'),
          monospace: true,
          onChanged: (v) => _updateBlock(index, block.copyWith(text: v)),
        ),
      ManuscriptBlockType.image => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (block.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: (!kIsWeb &&
                        defaultTargetPlatform == TargetPlatform.windows)
                    ? Container(
                        height: 120,
                        width: double.infinity,
                        color: Colors.grey.shade200,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_outlined,
                                size: 48, color: Colors.grey.shade600),
                            const SizedBox(height: 6),
                            Text(
                              context.t(
                                  'صورة — انظر المعاينة', 'Image — see Preview'),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Image.network(
                        block.imageUrl!,
                        height: 160,
                        fit: BoxFit.contain,
                      ),
              ),
            _CaptionField(
              key: ValueKey('cap_${block.id}'),
              initialCaption: block.caption ?? '',
              onChanged: (v) => _updateBlock(index, block.copyWith(caption: v)),
            ),
          ],
        ),
      ManuscriptBlockType.table => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ManuscriptBlockPreview(block: block, manuscript: widget.manuscript),
            TextButton.icon(
              onPressed: () async {
                final result = await showManuscriptTableDialog(
                  context,
                  existingRows: block.rows,
                  existingCaption: block.caption,
                );
                if (result != null) {
                  _updateBlock(
                    index,
                    block.copyWith(rows: result.rows, caption: result.caption),
                  );
                }
              },
              icon: const Icon(Icons.edit),
              label: Text(context.t('تعديل الجدول', 'Edit table')),
            ),
          ],
        ),
    };
  }

  String? _importSectionLabel(int index, ManuscriptBlock block) {
    if (block.type != ManuscriptBlockType.paragraph &&
        block.type != ManuscriptBlockType.heading) {
      return null;
    }
    return switch (index) {
      0 => context.t('العنوان والمؤلفون', 'Title & authors'),
      1 => context.t('الملخص والكلمات المفتاحية', 'Abstract & keywords'),
      2 => context.t('متن البحث', 'Manuscript body'),
      _ => null,
    };
  }

  String _blockTypeLabel(BuildContext context, ManuscriptBlockType type) =>
      switch (type) {
        ManuscriptBlockType.paragraph => context.t('فقرة', 'Paragraph'),
        ManuscriptBlockType.heading => context.t('عنوان', 'Heading'),
        ManuscriptBlockType.image => context.t('صورة', 'Figure'),
        ManuscriptBlockType.table => context.t('جدول', 'Table'),
        ManuscriptBlockType.equation => context.t('معادلة', 'Equation'),
      };
}

class _CaptionField extends StatefulWidget {
  final String initialCaption;
  final ValueChanged<String> onChanged;

  const _CaptionField({
    super.key,
    required this.initialCaption,
    required this.onChanged,
  });

  @override
  State<_CaptionField> createState() => _CaptionFieldState();
}

class _CaptionFieldState extends State<_CaptionField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialCaption);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      decoration: InputDecoration(
        labelText: context.t('تعليق الصورة', 'Figure caption'),
        border: const OutlineInputBorder(),
      ),
      onChanged: widget.onChanged,
    );
  }
}

class _BlockTextField extends StatefulWidget {
  final String initialText;
  final int? minLines;
  final int? maxLines;
  final String hint;
  final bool monospace;
  final ValueChanged<String> onChanged;

  const _BlockTextField({
    super.key,
    required this.initialText,
    this.minLines,
    required this.maxLines,
    required this.hint,
    required this.onChanged,
    this.monospace = false,
  });

  @override
  State<_BlockTextField> createState() => _BlockTextFieldState();
}

class _BlockTextFieldState extends State<_BlockTextField> {
  late final TextEditingController _ctrl;

  int get cursorOffset => _ctrl.selection.baseOffset.clamp(0, _ctrl.text.length);

  void setTextAndSelection(String text, int cursor) {
    _ctrl.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor.clamp(0, text.length)),
    );
  }

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
  }

  @override
  void didUpdateWidget(_BlockTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialText != widget.initialText &&
        _ctrl.text != widget.initialText) {
      final offset = cursorOffset;
      _ctrl.text = widget.initialText;
      _ctrl.selection = TextSelection.collapsed(
        offset: offset.clamp(0, widget.initialText.length),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      minLines: widget.minLines ?? (widget.maxLines == null ? 4 : 1),
      maxLines: widget.maxLines,
      keyboardType: TextInputType.multiline,
      textAlignVertical: TextAlignVertical.top,
      style: widget.monospace ? const TextStyle(fontFamily: 'monospace') : null,
      decoration: InputDecoration(
        hintText: widget.hint,
        alignLabelWithHint: true,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      onChanged: widget.onChanged,
    );
  }
}

class _CitationInsertResult {
  final PublishReference reference;
  final InTextCitationForm form;
  final bool isNewReference;

  const _CitationInsertResult({
    required this.reference,
    required this.form,
    this.isNewReference = false,
  });
}

class _InsertCitationDialog extends StatefulWidget {
  final List<PublishReference> references;
  final PublishCitationStyle style;

  const _InsertCitationDialog({
    required this.references,
    required this.style,
  });

  @override
  State<_InsertCitationDialog> createState() => _InsertCitationDialogState();
}

class _InsertCitationDialogState extends State<_InsertCitationDialog> {
  InTextCitationForm _form = InTextCitationForm.auto;
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _searching = false;
  String? _portalError;
  List<AcademicWorkHit> _portalHits = const [];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<PublishReference> get _localMatches {
    if (_query.trim().isEmpty) return widget.references;
    return widget.references
        .where((r) => AcademicReferenceLookupService.matchesLocal(r, _query))
        .toList();
  }

  Future<void> _searchPortal() async {
    final q = _searchCtrl.text.trim();
    if (q.length < 3) {
      setState(() {
        _portalError = null;
        _portalHits = const [];
      });
      return;
    }
    setState(() {
      _searching = true;
      _portalError = null;
    });
    try {
      final hits = await AcademicReferenceLookupService.instance.search(q);
      if (!mounted) return;
      setState(() {
        _portalHits = hits;
        _searching = false;
        if (hits.isEmpty) {
          _portalError = 'empty';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _portalError = e.toString();
        _portalHits = const [];
      });
    }
  }

  void _pickLocal(PublishReference ref) {
    Navigator.pop(
      context,
      _CitationInsertResult(reference: ref, form: _form),
    );
  }

  void _pickPortal(AcademicWorkHit hit) {
    PublishReference? existing;
    for (final r in widget.references) {
      final sameDoi = hit.doi.isNotEmpty &&
          r.doi.isNotEmpty &&
          r.doi.toLowerCase() == hit.doi.toLowerCase();
      final sameTitle = r.title.trim().isNotEmpty &&
          r.title.trim().toLowerCase() == hit.title.trim().toLowerCase();
      if (sameDoi || sameTitle) {
        existing = r;
        break;
      }
    }
    final ref = existing ?? hit.toReference();
    Navigator.pop(
      context,
      _CitationInsertResult(
        reference: ref,
        form: _form,
        isNewReference: existing == null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final local = _localMatches;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final previewRef = local.isNotEmpty
        ? local.first
        : (widget.references.isNotEmpty
            ? widget.references.first
            : (_portalHits.isNotEmpty
                ? _portalHits.first.toReference()
                : null));

    return AlertDialog(
      title: Text(context.t('إدراج اقتباس', 'Insert citation')),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.t('شكل الاقتباس في النص', 'In-text citation form'),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: InTextCitationForm.values.map((form) {
                return ChoiceChip(
                  label: Text(
                    CitationFormatter.formLabel(form, arabic: isAr),
                    style: const TextStyle(fontSize: 12),
                  ),
                  selected: _form == form,
                  onSelected: (_) => setState(() => _form = form),
                );
              }).toList(),
            ),
            if (previewRef != null) ...[
              const SizedBox(height: 6),
              Text(
                '${isAr ? 'المعاينة' : 'Preview'}: ${CitationFormatter.formatInText(reference: previewRef, style: widget.style, index: 1, form: _form)}',
                style: TextStyle(fontSize: 12, color: Colors.indigo.shade700),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: context.t(
                  'اسم مؤلف، عنوان، أو DOI…',
                  'Author name, title, or DOI…',
                ),
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: const OutlineInputBorder(),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        tooltip: context.t(
                          'بحث أكاديمي',
                          'Academic search',
                        ),
                        icon: const Icon(Icons.travel_explore, size: 20),
                        onPressed: _searchPortal,
                      ),
              ),
              onChanged: (v) => setState(() => _query = v),
              onSubmitted: (_) => _searchPortal(),
            ),
            const SizedBox(height: 4),
            Text(
              context.t(
                'ابحث محلياً أو اضغط أيقونة البوابة / Enter للبحث في Crossref وOpenAlex',
                'Filter local refs, or tap portal / Enter to search Crossref & OpenAlex',
              ),
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (local.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          context.t(
                            'مراجع البحث (${local.length})',
                            'Manuscript refs (${local.length})',
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      ...local.map((r) {
                        final subtitle = [
                          if (r.authors.isNotEmpty) r.authors.first,
                          if (r.year.isNotEmpty) r.year,
                        ].join(' · ');
                        final label = r.title.trim().isNotEmpty
                            ? r.title
                            : (r.rawText.trim().isNotEmpty
                                ? r.rawText
                                : r.id);
                        return ListTile(
                          dense: true,
                          leading:
                              const Icon(Icons.bookmark_outline, size: 20),
                          title: Text(
                            label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle:
                              subtitle.isEmpty ? null : Text(subtitle),
                          trailing: Text(
                            CitationFormatter.formatInText(
                              reference: r,
                              style: widget.style,
                              index: widget.references.indexOf(r) + 1,
                              form: _form,
                            ),
                            style: TextStyle(
                              color: Colors.indigo.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          onTap: () => _pickLocal(r),
                        );
                      }),
                    ],
                    if (_portalHits.isNotEmpty) ...[
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4, top: 4),
                        child: Text(
                          context.t(
                            'نتائج البوابة الأكاديمية',
                            'Academic portal results',
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      ..._portalHits.map((hit) {
                        final subtitle = [
                          if (hit.authors.isNotEmpty) hit.authors.first,
                          if (hit.year.isNotEmpty) hit.year,
                          hit.source,
                        ].join(' · ');
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.public,
                            size: 20,
                            color: Colors.teal.shade700,
                          ),
                          title: Text(
                            hit.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(subtitle),
                          trailing: Text(
                            CitationFormatter.formatInText(
                              reference: hit.toReference(),
                              style: widget.style,
                              index: 1,
                              form: _form,
                            ),
                            style: TextStyle(
                              color: Colors.teal.shade800,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          onTap: () => _pickPortal(hit),
                        );
                      }),
                    ],
                    if (local.isEmpty &&
                        _portalHits.isEmpty &&
                        !_searching) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            _portalError == 'empty'
                                ? context.t(
                                    'لا نتائج من البوابة — جرّب اسم مؤلف أقصر أو DOI',
                                    'No portal results — try a shorter author name or DOI',
                                  )
                                : context.t(
                                    'اكتب اسم مؤلف أو عنواناً ثم اضغط Enter',
                                    'Type an author or title, then press Enter',
                                  ),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _searching ? null : _searchPortal,
          child: Text(context.t('بحث أكاديمي', 'Academic search')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t('إلغاء', 'Cancel')),
        ),
      ],
    );
  }
}
