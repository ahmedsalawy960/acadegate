import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale/locale_extensions.dart';
import 'citation_formatter.dart';
import 'manuscript_body_editor.dart';
import 'manuscript_citation_helper.dart';
import 'manuscript_document_parser.dart';
import 'manuscript_export_service.dart';
import 'manuscript_format_screen.dart';
import 'manuscript_preview.dart';
import 'manuscript_upload_service.dart';
import 'publish_models.dart';
import 'publish_reference_form.dart';
import 'publish_services.dart';

class ManuscriptEditorScreen extends StatefulWidget {
  final String manuscriptId;

  const ManuscriptEditorScreen({super.key, required this.manuscriptId});

  @override
  State<ManuscriptEditorScreen> createState() => _ManuscriptEditorScreenState();
}

class _ManuscriptEditorScreenState extends State<ManuscriptEditorScreen>
    with SingleTickerProviderStateMixin {
  static const _brand = Color(0xFF4A148C);

  final _titleCtrl = TextEditingController();
  final _abstractCtrl = TextEditingController();

  PublishManuscript? _manuscript;
  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _abstractCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final m = await ManuscriptService.instance.getById(widget.manuscriptId);
    if (!mounted) return;
    if (m == null) {
      Navigator.pop(context);
      return;
    }
    _titleCtrl.text = m.title;
    _abstractCtrl.text = m.abstractText;
    setState(() {
      _manuscript = m;
      _loading = false;
    });
  }

  PublishManuscript _buildDraft() {
    final base = _manuscript!;
    return base.copyWith(
      title: _titleCtrl.text,
      abstractText: _abstractCtrl.text,
    );
  }

  Future<void> _save({bool quiet = false}) async {
    final m = _manuscript;
    if (m == null || _saving) return;
    setState(() => _saving = true);
    try {
      await ManuscriptService.instance.save(_buildDraft());
      if (mounted && !quiet) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('تم الحفظ', 'Saved'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addReference() async {
    final ref = await showPublishReferenceForm(context);
    if (ref == null || _manuscript == null) return;

    final style = _manuscript!.effectiveStyle;
    final formatted = CitationFormatter.formatBibliography(
      references: [ref],
      style: style,
    );

    setState(() {
      _manuscript = _manuscript!.copyWith(
        references: [..._manuscript!.references, ref],
      );
    });
    await _save(quiet: true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.t(
          'تمت إضافة المرجع — معاينة التنسيق في الأسفل',
          'Reference added — formatted preview below',
        )),
        duration: const Duration(seconds: 3),
      ),
    );
    if (formatted.isNotEmpty) {
      showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(16),
          child: SelectableText(formatted),
        ),
      );
    }
  }

  Future<void> _editReference(int index) async {
    final ref = await showPublishReferenceForm(
      context,
      existing: _manuscript!.references[index],
    );
    if (ref == null) return;
    final updated = [..._manuscript!.references];
    updated[index] = ref;
    setState(() => _manuscript = _manuscript!.copyWith(references: updated));
    await _save(quiet: true);
  }

  Future<void> _removeReference(int index) async {
    final updated = [..._manuscript!.references]..removeAt(index);
    setState(() => _manuscript = _manuscript!.copyWith(references: updated));
    await _save(quiet: true);
  }

  Future<void> _uploadFullDocument() async {
    if (_uploading) return;
    setState(() => _uploading = true);
    try {
      final result = await ManuscriptUploadService.instance
          .pickAndUploadDocument(manuscriptId: widget.manuscriptId);

      final attachment = ManuscriptAttachment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: result.name,
        url: result.url,
        mime: result.mime,
        sizeBytes: result.size,
      );

      final manuscript = _manuscript!.copyWith(
        attachments: [..._manuscript!.attachments, attachment],
      );

      setState(() => _manuscript = manuscript);
      await ManuscriptService.instance.save(_buildDraft().copyWith(
        attachments: manuscript.attachments,
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t(
              'تم رفع الملف — اضغط «استخراج المراجع والنص من الملف»',
              'File uploaded — tap "Extract references & text from file"',
            )),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _onReferenceAdded(PublishReference ref) {
    final m = _manuscript;
    if (m == null) return;
    if (m.references.any((r) =>
        r.id == ref.id ||
        (ref.doi.isNotEmpty &&
            r.doi.isNotEmpty &&
            r.doi.toLowerCase() == ref.doi.toLowerCase()))) {
      return;
    }
    setState(() {
      _manuscript = m.copyWith(references: [...m.references, ref]);
    });
    _save(quiet: true);
  }

  void _onBlocksChanged(List<ManuscriptBlock> blocks) {
    setState(() => _manuscript = _manuscript!.copyWith(bodyBlocks: blocks));
    ManuscriptService.instance.save(_buildDraft().copyWith(bodyBlocks: blocks));
  }

  void _onStyleChanged(PublishCitationStyle style) {
    setState(() => _manuscript = _manuscript!.copyWith(citationStyle: style));
    _save(quiet: true);
  }

  Future<void> _removeAttachment(ManuscriptAttachment attachment) async {
    if (_uploading || _manuscript == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('إزالة الملف', 'Remove file')),
        content: Text(context.t(
          'إزالة «${attachment.name}»؟\nيمكنك رفع ملف آخر بعد الإزالة.',
          'Remove "${attachment.name}"?\nYou can upload another file after removal.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.t('إزالة', 'Remove')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _uploading = true);
    try {
      await ManuscriptUploadService.instance.deleteFileAtUrl(attachment.url);
      final updatedAttachments =
          _manuscript!.attachments.where((a) => a.id != attachment.id).toList();
      setState(
        () => _manuscript = _manuscript!.copyWith(attachments: updatedAttachments),
      );
      await ManuscriptService.instance.save(
        _buildDraft().copyWith(attachments: updatedAttachments),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('تمت إزالة الملف', 'File removed'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _extractFromAttachment(ManuscriptAttachment attachment) async {
    if (_uploading) return;
    setState(() => _uploading = true);

    var progressOpen = false;
    if (mounted) {
      progressOpen = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(context.t(
                    'جاري استخراج المراجع والنص…',
                    'Extracting references and text…',
                  )),
                ),
              ],
            ),
          ),
        ),
      );
    }

    try {
      await Future<void>.delayed(Duration.zero);
      final parsed = await ManuscriptDocumentParser.parseFromUrl(
        url: attachment.url,
        filename: attachment.name,
      );
      final manuscript = await ManuscriptDocumentParser.applyParseResult(
        manuscript: _manuscript!,
        parsed: parsed,
        replaceReferences: true,
      );

      if (manuscript.title.trim().isNotEmpty) {
        _titleCtrl.text = manuscript.title;
      }

      final draft = _buildDraft().copyWith(
        references: manuscript.references,
        bodyBlocks: manuscript.bodyBlocks,
        title: manuscript.title.trim().isNotEmpty
            ? manuscript.title
            : _manuscript!.title,
      );
      await ManuscriptService.instance.save(draft);

      if (!mounted) return;

      final isWindows =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
      if (isWindows) {
        setState(() {
          _manuscript = _manuscript!.copyWith(
            references: draft.references,
            bodyBlocks: draft.bodyBlocks,
            title: draft.title,
          );
        });
      } else {
        await _load();
      }

      if (!mounted) return;

      final images = manuscript.bodyBlocks
          .where((b) => b.type == ManuscriptBlockType.image)
          .length;
      final tableCellImages = manuscript.bodyBlocks
          .where((b) => b.type == ManuscriptBlockType.table)
          .fold<int>(
            0,
            (sum, b) =>
                sum +
                b.rowCellImages.fold<int>(
                  0,
                  (rowSum, row) => rowSum + row.where((u) => u.isNotEmpty).length,
                ),
          );
      final tables = manuscript.bodyBlocks
          .where((b) => b.type == ManuscriptBlockType.table)
          .length;
      final equations = manuscript.bodyBlocks
          .where((b) => b.type == ManuscriptBlockType.equation)
          .length;
      final blockMsg = parsed.bodyBlocks.length >= ManuscriptDocumentParser.maxImportedBlocks
          ? context.t(' (اختُصر جزء من النص)', ' (some text truncated)')
          : '';
      if (parsed.references.isEmpty && parsed.bodyBlocks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t(
              'لم تُعثر على مراجع في الملف — تأكد من وجود قسم References أو [1] IEEE',
              'No references in file — ensure References section or IEEE [1] format',
            )),
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        var msg = context.t(
          'تم استيراد ${parsed.references.length} مرجعاً، ${manuscript.bodyBlocks.length} عنصراً'
          ' ($tables جداول، ${images + tableCellImages} صور، $equations معادلات)$blockMsg',
          'Imported ${parsed.references.length} refs, ${manuscript.bodyBlocks.length} blocks'
          ' ($tables tables, ${images + tableCellImages} figures, $equations equations)$blockMsg',
        );
        if (tables > 0 && tableCellImages == 0) {
          msg += context.t(
            ' — تحذير: لم تُستخرج رسوم من الجدول (Structure). صدّر DOCX أو الصق الهياكل كصورة في Word',
            ' — Warning: no Structure drawings extracted. Export DOCX or paste structures as pictures in Word',
          );
        }
        if (equations == 0 && manuscript.bodyBlocks.any((b) =>
            b.type == ManuscriptBlockType.paragraph &&
            RegExp(r'Equation\s*\d', caseSensitive: false)
                .hasMatch(b.text))) {
          msg += context.t(
            ' — تحذير: المعادلات لم تُستخرج كمعادلات',
            ' — Warning: equations were not extracted as math blocks',
          );
        }
        if (isWindows && (images + tableCellImages) > 0) {
          msg += context.t(
            ' — الصور محفوظة محلياً؛ صدّر Word الآن قبل إغلاق التطبيق',
            ' — Images kept locally; export Word now before closing the app',
          );
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            duration: Duration(seconds: tableCellImages == 0 ? 10 : 6),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted && progressOpen) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _goToFormat() async {
    await _save(quiet: true);
    if (!mounted) return;

    final m = _manuscript!;
    if (m.references.isEmpty && m.attachments.isNotEmpty) {
      await _extractFromAttachment(m.attachments.last);
      if (!mounted) return;
      if (_manuscript!.references.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t(
              'لا مراجع بعد — استخدم «استخراج من الملف» أو أضف مراجع يدوياً قبل التنسيق',
              'No references yet — use "Extract from file" or add references before formatting',
            )),
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ManuscriptFormatScreen(manuscriptId: widget.manuscriptId),
      ),
    );
    _load();
  }

  Future<void> _exportPdf() async {
    try {
      await ManuscriptExportService.instance.sharePdf(_buildDraft());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  Future<void> _exportWord() async {
    try {
      await ManuscriptExportService.instance.shareWordHtml(_buildDraft());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(context.t('المسودة', 'Draft')),
          backgroundColor: _brand,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final m = _manuscript!;
    final isSubmitted = m.status == ManuscriptStatus.submitted;

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('المسودة', 'Draft')),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: context.t('تحرير', 'Edit')),
            Tab(text: context.t('معاينة', 'Preview')),
          ],
        ),
        actions: [
          if (!isSubmitted)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (v) {
                if (v == 'pdf') _exportPdf();
                if (v == 'word') _exportWord();
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'pdf',
                  child: Text(context.t('تصدير PDF', 'Export PDF')),
                ),
                PopupMenuItem(
                  value: 'word',
                  child: Text(context.t('تصدير Word (HTML)', 'Export Word (HTML)')),
                ),
              ],
            ),
          if (!isSubmitted)
            TextButton(
              onPressed: _saving ? null : _save,
              child: Text(
                context.t('حفظ', 'Save'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _editTab(context, m, isSubmitted),
          _previewTab(context, m),
        ],
      ),
      bottomNavigationBar: isSubmitted
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: _titleCtrl.text.trim().isEmpty &&
                          m.bodyBlocks.isEmpty &&
                          m.attachments.isEmpty &&
                          m.references.isEmpty
                      ? null
                      : _goToFormat,
                  style: FilledButton.styleFrom(
                    backgroundColor: _brand,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(
                    context.t('التالي: التنسيق IEEE/APA', 'Next: IEEE/APA format'),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _editTab(BuildContext context, PublishManuscript m, bool isSubmitted) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (isSubmitted)
          Card(
            color: Colors.green.shade50,
            child: ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: Text(context.t('تم التقديم', 'Submitted')),
              subtitle: Text(m.journalName ?? ''),
            ),
          ),
        TextField(
          controller: _titleCtrl,
          readOnly: isSubmitted,
          decoration: InputDecoration(
            labelText: context.t('عنوان البحث', 'Paper title'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _abstractCtrl,
          readOnly: isSubmitted,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: context.t('الملخص', 'Abstract'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          context.t('نمط الاقتباس', 'Citation style'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PublishCitationStyle.values.map((style) {
            final selected = m.effectiveStyle == style;
            return ChoiceChip(
              label: Text(CitationFormatter.styleLabel(style)),
              selected: selected,
              onSelected: isSubmitted
                  ? null
                  : (_) => _onStyleChanged(style),
            );
          }).toList(),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            context.t(
              'يُنسَّق به الاقتباسات في النص وقائمة المراجع في النهاية',
              'Formats in-text citations and the end bibliography',
            ),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ),
        if (m.attachments.isNotEmpty && m.references.isEmpty)
          Card(
            color: Colors.amber.shade50,
            margin: const EdgeInsets.only(top: 12),
            child: ListTile(
              leading: Icon(Icons.info_outline, color: Colors.amber.shade900),
              title: Text(context.t(
                'الملف مرفوع — المراجع لم تُستورد بعد',
                'File uploaded — references not imported yet',
              )),
              subtitle: Text(context.t(
                'اضغط «استخراج من الملف» أدناه',
                'Tap "Extract from file" below',
              )),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          context.t('محتوى البحث', 'Manuscript content'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        ManuscriptBodyEditor(
          manuscript: m,
          readOnly: isSubmitted,
          onBlocksChanged: _onBlocksChanged,
          onReferenceAdded: isSubmitted ? null : _onReferenceAdded,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Text(
              context.t('رفع البحث كاملاً', 'Upload full manuscript'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Spacer(),
            if (!isSubmitted)
              FilledButton.tonalIcon(
                onPressed: _uploading ? null : _uploadFullDocument,
                icon: _uploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file),
                label: Text(context.t('PDF / Word', 'PDF / Word')),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (m.attachments.isEmpty)
          Text(
            context.t(
              'ارفع PDF أو DOCX — يُستخرج قسم المراجع تلقائياً (حتى 24 MB)',
              'Upload PDF or DOCX — References section extracted automatically (up to 24 MB)',
            ),
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          )
        else
          ...m.attachments.map((a) {
            return Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(a.isPdf ? Icons.picture_as_pdf : Icons.description),
                    title: Text(a.name),
                    subtitle: Text('${(a.sizeBytes / 1024).toStringAsFixed(0)} KB'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isSubmitted)
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                            tooltip: context.t('إزالة الملف', 'Remove file'),
                            onPressed: _uploading ? null : () => _removeAttachment(a),
                          ),
                        IconButton(
                          icon: const Icon(Icons.open_in_new),
                          tooltip: context.t('فتح', 'Open'),
                          onPressed: () => launchUrl(
                            Uri.parse(a.url),
                            mode: LaunchMode.externalApplication,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isSubmitted)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: _uploading
                              ? null
                              : () => _extractFromAttachment(a),
                          icon: const Icon(Icons.auto_fix_high),
                          label: Text(context.t(
                            'استخراج المراجع والنص من الملف',
                            'Extract references & text from file',
                          )),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        const SizedBox(height: 20),
        Row(
          children: [
            Text(
              context.t('المراجع', 'References'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Spacer(),
            if (!isSubmitted)
              TextButton.icon(
                onPressed: _addReference,
                icon: const Icon(Icons.add),
                label: Text(context.t('إضافة', 'Add')),
              ),
          ],
        ),
        if (m.references.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              context.t(
                'أضف مراجعك — يُنسَّق APA/IEEE فوراً',
                'Add references — APA/IEEE formats instantly',
              ),
              style: TextStyle(color: Colors.grey[600]),
            ),
          )
        else ...[
          if (m.references.length > 12)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                context.t(
                  'عرض 12 من ${m.references.length} مرجع — الباقي في تبويب المعاينة',
                  'Showing 12 of ${m.references.length} references — rest in Preview tab',
                ),
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ),
          ...m.references.take(12).toList().asMap().entries.map((entry) {
            final i = entry.key;
            final ref = entry.value;
            final entryFormatted = CitationFormatter.buildBibliographyEntry(
              reference: ref,
              style: m.effectiveStyle,
              index: i + 1,
            );
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ref.rawText.isNotEmpty ? ref.rawText : ref.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isSubmitted) ...[
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () => _editReference(i),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline,
                                color: Colors.red[400], size: 20),
                            onPressed: () => _removeReference(i),
                          ),
                        ],
                      ],
                    ),
                    if (ref.authors.isNotEmpty)
                      Text(
                        ref.authors.join('; '),
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    const Divider(height: 16),
                    SelectableText.rich(
                      CitationFormatter.buildBibliographyInlineSpan(
                        entry: entryFormatted,
                        baseStyle: const TextStyle(fontSize: 12, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _previewTab(BuildContext context, PublishManuscript m) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          m.title.trim().isEmpty ? context.t('بدون عنوان', 'Untitled') : m.title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        if (m.abstractText.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            context.t('الملخص', 'Abstract'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(m.abstractText),
        ],
        const Divider(height: 24),
        ManuscriptPreview(manuscript: m),
        if (ManuscriptCitationHelper.bibliographyReferences(m, citedOnly: true)
            .isNotEmpty) ...[
          const Divider(height: 24),
          Text(
            context.t('المراجع', 'References'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            context.t(
              'مولَّدة تلقائياً من الاقتباسات المدرجة في النص',
              'Auto-generated from in-text citations',
            ),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          ...CitationFormatter.buildBibliographyEntries(
            references: ManuscriptCitationHelper.bibliographyReferences(
              m,
              citedOnly: true,
            ),
            style: m.effectiveStyle,
          ).map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SelectableText.rich(
                CitationFormatter.buildBibliographyInlineSpan(
                  entry: entry,
                  baseStyle: const TextStyle(height: 1.6, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
        if (m.attachments.isNotEmpty) ...[
          const Divider(height: 24),
          Text(
            context.t('مرفقات', 'Attachments'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          ...m.attachments.map(
            (a) => ListTile(
              leading: const Icon(Icons.attach_file),
              title: Text(a.name),
            ),
          ),
        ],
      ],
    );
  }
}
