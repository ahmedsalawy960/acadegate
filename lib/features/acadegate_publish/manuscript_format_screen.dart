import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import 'citation_formatter.dart';
import 'journal_selection_screen.dart';
import 'manuscript_citation_helper.dart';
import 'manuscript_document_parser.dart';
import 'manuscript_export_service.dart';
import 'manuscript_preview.dart';
import 'publish_models.dart';
import 'publish_services.dart';

class ManuscriptFormatScreen extends StatefulWidget {
  final String manuscriptId;

  const ManuscriptFormatScreen({super.key, required this.manuscriptId});

  @override
  State<ManuscriptFormatScreen> createState() => _ManuscriptFormatScreenState();
}

class _ManuscriptFormatScreenState extends State<ManuscriptFormatScreen> {
  static const _brand = Color(0xFF4A148C);

  PublishManuscript? _manuscript;
  PublishCitationStyle _style = PublishCitationStyle.apa;
  bool _loading = true;
  bool _extracting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await ManuscriptService.instance.getById(widget.manuscriptId);
    if (!mounted) return;
    setState(() {
      _manuscript = m;
      _style = m?.effectiveStyle ?? PublishCitationStyle.apa;
      _loading = false;
    });
  }

  String get _bibliography {
    final m = _manuscript;
    if (m == null) return '';
    return CitationFormatter.formatBibliography(
      references: ManuscriptCitationHelper.bibliographyReferences(
        m,
        citedOnly: true,
      ),
      style: _style,
    );
  }

  Future<void> _copyBibliography() async {
    await Clipboard.setData(ClipboardData(text: _bibliography));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.t('تم النسخ', 'Copied'))),
    );
  }

  Future<void> _applyStyle(PublishCitationStyle style) async {
    setState(() => _style = style);
    await ManuscriptService.instance.markFormatted(widget.manuscriptId, style);
    final m = _manuscript;
    if (m != null) {
      await ManuscriptService.instance.save(m.copyWith(citationStyle: style));
    }
  }

  Future<void> _continueToJournal() async {
    await _applyStyle(_style);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JournalSelectionScreen(manuscriptId: widget.manuscriptId),
      ),
    );
  }

  Future<void> _exportPdf() async {
    final m = _manuscript;
    if (m == null) return;
    try {
      await ManuscriptExportService.instance.sharePdf(m.copyWith(citationStyle: _style));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _exportWord() async {
    final m = _manuscript;
    if (m == null) return;
    try {
      await ManuscriptExportService.instance
          .shareWordHtml(m.copyWith(citationStyle: _style));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _extractFromUploadedFile() async {
    final m = _manuscript;
    if (m == null || m.attachments.isEmpty || _extracting) return;

    setState(() => _extracting = true);
    try {
      final attachment = m.attachments.last;
      final parsed = await ManuscriptDocumentParser.parseFromUrl(
        url: attachment.url,
        filename: attachment.name,
      );
      var updated = await ManuscriptDocumentParser.applyParseResult(
        manuscript: m,
        parsed: parsed,
        replaceReferences: true,
      );
      updated = updated.copyWith(citationStyle: _style);
      await ManuscriptService.instance.save(updated);
      if (!mounted) return;
      setState(() => _manuscript = updated);

      if (parsed.references.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t(
              'لم تُعثر على مراجع — تأكد من وجود قسم References أو [1] في الملف',
              'No references found — ensure the file has a References section or IEEE [1] style',
            )),
            duration: const Duration(seconds: 6),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t(
              'تم استيراد ${parsed.references.length} مرجعاً من ${attachment.name}',
              'Imported ${parsed.references.length} references from ${attachment.name}',
            )),
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
      if (mounted) setState(() => _extracting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _manuscript == null) {
      return Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(context.t('التنسيق', 'Formatting')),
          backgroundColor: _brand,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final m = _manuscript!.copyWith(citationStyle: _style);

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('تنسيق IEEE / APA', 'IEEE / APA formatting')),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: context.t('تصدير PDF', 'Export PDF'),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _exportPdf,
          ),
          IconButton(
            tooltip: context.t('تصدير Word', 'Export Word'),
            icon: const Icon(Icons.description_outlined),
            onPressed: _exportWord,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PublishCitationStyle.values.map((style) {
              return ChoiceChip(
                label: Text(CitationFormatter.styleLabel(style)),
                selected: _style == style,
                onSelected: (_) => _applyStyle(style),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Text(
            context.t('معاينة البحث', 'Manuscript preview'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  if (m.abstractText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(m.abstractText),
                  ],
                  const Divider(),
                  ManuscriptPreview(manuscript: m),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.t('قائمة المراجع', 'Reference list'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (m.references.isEmpty)
            Card(
              color: Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t(
                        'لا توجد مراجع بعد',
                        'No references yet',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.t(
                        'رفع الملف لا يكفي وحده — يجب استخراج المراجع من الملف أولاً. '
                        'أزرار APA/IEEE تُنسّق المراجع المستوردة فقط.',
                        'Uploading alone is not enough — extract references from the file first. '
                        'APA/IEEE buttons only format already-imported references.',
                      ),
                      style: TextStyle(color: Colors.grey[800], fontSize: 13),
                    ),
                    if (m.attachments.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: _extracting ? null : _extractFromUploadedFile,
                          icon: _extracting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.auto_fix_high),
                          label: Text(context.t(
                            'استخراج المراجع من ${m.attachments.last.name}',
                            'Extract references from ${m.attachments.last.name}',
                          )),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Text(
                        context.t(
                          'ارجع للمسودة وارفع PDF أو DOCX',
                          'Go back to the draft and upload a PDF or DOCX',
                        ),
                        style: TextStyle(color: Colors.grey[700], fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: CitationFormatter.buildBibliographyEntries(
                    references: m.references,
                    style: _style,
                  ).map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SelectableText.rich(
                        CitationFormatter.buildBibliographyInlineSpan(
                          entry: entry,
                          baseStyle: const TextStyle(height: 1.6, fontSize: 13),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          if (m.references.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _copyBibliography,
                icon: const Icon(Icons.copy),
                label: Text(context.t('نسخ المراجع', 'Copy references')),
              ),
            ),
          if (m.attachments.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              context.t('ملفات مرفوعة', 'Uploaded files'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            ...m.attachments.map((a) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.attach_file),
                  title: Text(a.name),
                )),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _continueToJournal,
            style: FilledButton.styleFrom(
              backgroundColor: _brand,
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(
              context.t('التالي: اختيار المجلة', 'Next: choose journal'),
            ),
          ),
        ),
      ),
    );
  }
}
