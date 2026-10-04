import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import 'citation_formatter.dart';
import 'citation_style_picker.dart';
import 'citation_style_shapes.dart';
import 'journal_format_rules.dart';
import 'journal_selection_screen.dart';
import 'manuscript_citation_helper.dart';
import 'manuscript_docx_export_service.dart';
import 'manuscript_draft_chat_panel.dart';
import 'manuscript_export_service.dart';
import 'manuscript_preview.dart';
import 'manuscript_upload_service.dart';
import 'manuscript_reference_styler.dart';
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
  PublishCitationStyle? _styledFor;
  int _lastRefCount = 0;
  int _lastCiteCount = 0;
  bool _loading = true;
  bool _extracting = false;
  bool _openingJournal = false;

  int get _maxImportedNumber {
    final refs = _manuscript?.references ?? const [];
    var maxN = 0;
    for (final r in refs) {
      final n = r.importedNumber ??
          PublishReference.numberFromImportedLine(r.rawText) ??
          0;
      if (n > maxN) maxN = n;
    }
    return maxN;
  }

  bool get _isStyledForCurrent => _styledFor == _style;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final m = await ManuscriptService.instance.getById(widget.manuscriptId);
      if (!mounted) return;
      if (m == null) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t('المسودة غير موجودة', 'Draft not found'),
            ),
          ),
        );
        Navigator.pop(context);
        return;
      }
      setState(() {
        _manuscript = m;
        _style = m.effectiveStyle;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
      Navigator.pop(context);
    }
  }

  String get _bibliography {
    final m = _manuscript;
    if (m == null) return '';
    return CitationFormatter.formatBibliography(
      references: ManuscriptCitationHelper.bibliographyReferences(
        m,
        style: _style,
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

  Future<void> _selectStyle(PublishCitationStyle style) async {
    setState(() => _style = style);
    if (_manuscript?.attachments.any((a) => a.isWord || a.isPdf) == true) {
      await _restyleManuscript(style);
    } else {
      await ManuscriptService.instance.markFormatted(widget.manuscriptId, style);
      final m = _manuscript;
      if (m != null) {
        await ManuscriptService.instance.save(m.copyWith(citationStyle: style));
      }
      if (!mounted) return;
      setState(() => _styledFor = style);
    }
  }

  Future<bool> _restyleManuscript(PublishCitationStyle style) async {
    final m = _manuscript;
    if (m == null || _extracting) return false;

    setState(() {
      _style = style;
      _extracting = true;
    });
    try {
      final result = await ManuscriptReferenceStyler.restyle(
        manuscript: m,
        style: style,
      );
      await ManuscriptService.instance.save(result.manuscript);
      await ManuscriptService.instance.markFormatted(
        widget.manuscriptId,
        style,
      );
      if (!mounted) return false;
      setState(() {
        _manuscript = result.manuscript;
        _styledFor = style;
        _lastRefCount = result.referenceCount;
        _lastCiteCount = result.inTextCount;
      });

      final source = result.sourceName.isNotEmpty
          ? result.sourceName
          : context.t('المسودة', 'the draft');
      if (result.referenceCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t(
              'لم تُعثر على مراجع في $source — تأكد من وجود Introduction ثم قسم References',
              'No references found in $source — ensure Introduction then a References section',
            )),
            duration: const Duration(seconds: 7),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t(
              result.fromFile
                  ? 'قُرئ الملف الأصلي «$source»: ${result.referenceCount} مرجعاً. [n] في النص = نفس المرجع n في القائمة.'
                  : 'لم يُقرأ ملف Word الأصلي — أوقف التطبيق وارفع الملف من جهازك ثم أعد التنسيق.',
              result.fromFile
                  ? 'Read the original file "$source": ${result.referenceCount} references. In-text [n] is bibliography item n.'
                  : 'The original Word file was not read — quit the app, upload the original file, then format again.',
            )),
            duration: const Duration(seconds: 6),
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _extracting = false);
    }
  }

  Future<void> _continueToJournal() async {
    if (_openingJournal || _manuscript == null) return;
    setState(() => _openingJournal = true);
    try {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              JournalSelectionScreen(manuscriptId: widget.manuscriptId),
        ),
      );
    } finally {
      if (mounted) setState(() => _openingJournal = false);
    }
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
      if (!_isStyledForCurrent) {
        final hasSource = m.attachments.any((a) => a.isWord || a.isPdf);
        if (hasSource) {
          final ok = await _restyleManuscript(_style);
          if (!ok) return;
        } else {
          setState(() => _styledFor = _style);
        }
      }
      final current = _manuscript;
      if (current == null) return;
      final source = preferredSourceDocx(current.attachments);
      final sourceBytes = source == null || current.id == null
          ? null
          : await ManuscriptUploadService.instance.downloadDocumentBytes(
              url: source.url,
              manuscriptId: current.id,
              filename: source.name,
            );
      final export =
          await ManuscriptDocxExportService.instance.shareFormattedDocx(
        manuscript: current.copyWith(citationStyle: _style),
        rules: JournalFormatRules.forStudentStyle(_style),
        sourceDocxBytes: sourceBytes,
      );
      if (!mounted) return;
      if (!export.saved) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t(
              'أُلغي حفظ ملف Word.',
              'Word save was cancelled.',
            )),
          ),
        );
        return;
      }
      final n = export.imageCount;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t(
            n > 0 ? 'تم تصدير Word ($n صورة).' : 'تم تصدير Word.',
            n > 0 ? 'Word exported ($n picture(s)).' : 'Word exported.',
          )),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
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
        title: Text(context.t('تنسيق المراجع', 'Reference formatting')),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: context.t('اسأل المسودة', 'Ask the draft'),
            icon: const Icon(Icons.chat_outlined),
            onPressed: () => showManuscriptDraftChatSheet(
              context: context,
              manuscript: m,
            ),
          ),
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
          CitationStylePicker(
            value: _style,
            onChanged: _selectStyle,
            enabled: !_extracting,
          ),
          const SizedBox(height: 8),
          Text(
            context.t(
              'رقم [n] في النص = نفس المرجع رقم n في القائمة أسفل الملف. IEEE يبقي [n]. APA يحذف الرقم ويكتب (المؤلف، السنة) لذلك المرجع نفسه. القائمة تبقى بنفس ترتيب الملف. اضغط «تنسيق المراجع الآن».',
              'In-text [n] is the same work as bibliography item n at the bottom. IEEE keeps [n]. APA deletes the number and writes (Author, Year) for that same work. The list stays in file order. Tap “Format references now”.',
            ),
            style: TextStyle(fontSize: 13, color: const Color(0xFFB7C3D6), height: 1.4),
          ),
          const SizedBox(height: 12),
          _StyleShapeCard(style: _style),
          if (m.attachments.any((a) => a.isWord || a.isPdf)) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _extracting ? null : () => _restyleManuscript(_style),
                style: FilledButton.styleFrom(
                  backgroundColor: _brand,
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: _extracting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_fix_high),
                label: Text(context.t(
                  _isStyledForCurrent
                      ? 'إعادة تنسيق المراجع (${CitationFormatter.styleLabel(_style)})'
                      : 'تنسيق المراجع الآن (${CitationFormatter.styleLabel(_style)})',
                  _isStyledForCurrent
                      ? 'Re-format references (${CitationFormatter.styleLabel(_style)})'
                      : 'Format references now (${CitationFormatter.styleLabel(_style)})',
                )),
              ),
            ),
          ],
          if (_isStyledForCurrent && _lastRefCount > 0) ...[
            const SizedBox(height: 12),
            Card(
              color: Colors.green.shade50,
              child: ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text(context.t(
                  'تم تنسيق $_lastRefCount مرجعاً و$_lastCiteCount اقتباساً بنمط ${CitationFormatter.styleLabel(_style)}'
                  '${_maxImportedNumber > 0 ? ' — أرقام القائمة 1–$_maxImportedNumber' : ''}',
                  'Formatted $_lastRefCount references and $_lastCiteCount in-text citations as ${CitationFormatter.styleLabel(_style)}'
                  '${_maxImportedNumber > 0 ? ' — list numbers 1–$_maxImportedNumber' : ''}',
                )),
              ),
            ),
          ],
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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4E342E),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.t(
                        m.attachments.any((a) => a.isWord || a.isPdf)
                            ? 'اضغط «تنسيق المراجع الآن» ليقرأ التطبيق الملف من Introduction ويتعرّف على المراجع ثم ينسّقها.'
                            : 'ارجع للمسودة وارفع PDF أو DOCX ثم اضغط تنسيق المراجع.',
                        m.attachments.any((a) => a.isWord || a.isPdf)
                            ? 'Tap “Format references now” so the app reads from Introduction, finds the references, and restyles them.'
                            : 'Go back to the draft, upload a PDF or DOCX, then format references.',
                      ),
                      style: const TextStyle(color: Color(0xFF4E342E), fontSize: 13),
                    ),
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
                    references: ManuscriptCitationHelper.bibliographyReferences(
                      m,
                      style: _style,
                    ),
                    style: _style,
                  ).map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SelectableText.rich(
                            CitationFormatter.buildBibliographyInlineSpan(
                              entry: entry,
                              baseStyle: const TextStyle(
                                height: 1.6,
                                fontSize: 13,
                              ),
                            ),
                            textAlign: TextAlign.left,
                          ),
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
            onPressed: _openingJournal ? null : _continueToJournal,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFBBF24),
              foregroundColor: const Color(0xFF071433),
              minimumSize: const Size.fromHeight(48),
            ),
            child: _openingJournal
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF071433),
                    ),
                  )
                : Text(
                    context.t('التالي: اختيار المجلة', 'Next: choose journal'),
                  ),
          ),
        ),
      ),
    );
  }
}

class _StyleShapeCard extends StatelessWidget {
  final PublishCitationStyle style;

  const _StyleShapeCard({required this.style});

  @override
  Widget build(BuildContext context) {
    final shape = CitationStyleShapes.of(style);
    return Card(
      color: const Color(0xFFF3E5F5),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t(
                'شكل المرجع المعتمد: ${CitationFormatter.styleLabel(style)}',
                'Required ${CitationFormatter.styleLabel(style)} shape',
              ),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A148C),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.t(
                'داخل النص: ${shape.inTextDescriptionAr} — مثال ${shape.inTextExample}',
                'In text: ${shape.inTextDescriptionEn} — e.g. ${shape.inTextExample}',
              ),
              style: const TextStyle(fontSize: 13, color: Color(0xFF4A148C), height: 1.4),
            ),
            const SizedBox(height: 8),
            Text(
              context.t('شكل قائمة المراجع', 'Bibliography shape'),
              style: const TextStyle(fontSize: 12, color: Color(0xFF4A148C)),
            ),
            const SizedBox(height: 4),
            Directionality(
              textDirection: TextDirection.ltr,
              child: SelectableText(
                shape.bibliographyExample,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: Color(0xFF4A148C),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
