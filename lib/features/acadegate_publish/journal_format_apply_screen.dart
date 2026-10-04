import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale/app_translate.dart';
import '../../core/locale/locale_extensions.dart';
import '../../core/theme/acadegate_theme.dart';
import 'journal_format_rules.dart';
import 'citation_formatter.dart';
import 'citation_style_picker.dart';
import 'journal_guidelines_extract_service.dart';
import 'journal_guidelines_service.dart';
import 'journal_pick_item.dart';
import 'journal_template_reader.dart';
import 'manuscript_docx_export_service.dart';
import 'manuscript_document_parser.dart';
import 'manuscript_upload_service.dart';
import 'publish_models.dart';
import 'publish_services.dart';

class JournalFormatApplyScreen extends StatefulWidget {
  final String manuscriptId;
  final JournalPickItem journal;

  const JournalFormatApplyScreen({
    super.key,
    required this.manuscriptId,
    required this.journal,
  });

  @override
  State<JournalFormatApplyScreen> createState() =>
      _JournalFormatApplyScreenState();
}

class _JournalFormatApplyScreenState extends State<JournalFormatApplyScreen> {
  PublishManuscript? _manuscript;
  bool _loading = true;
  bool _processing = false;
  bool _loadingLinks = true;
  bool _extractingGuidelines = false;
  bool _extractionAttempted = false;
  bool _extractionSuccess = false;
  String? _extractionMessage;
  List<String> _keyRequirements = const [];
  String? _extractedExcerpt;
  String? _extractedSourceUrl;
  List<String> _fetchLogLines = const [];
  final _manualGuideUrlCtrl = TextEditingController();
  final _guideTextCtrl = TextEditingController();
  String? _error;
  late JournalFormatRules _fallbackRules;
  late JournalFormatRules _rules;
  bool _userChangedStyleAfterExtract = false;
  List<JournalResourceLink> _resourceLinks = const [];
  List<String> _seedUrls = const [];
  List<String> _discoveryLog = const [];
  String? _templateName;
  bool _readingTemplate = false;
  bool _applyingPaste = false;

  List<String> get _extractCandidateUrls {
    final manual = _manualGuideUrlCtrl.text.trim();
    final merged = <String>[if (manual.isNotEmpty) manual, ..._seedUrls];
    return merged.toSet().toList();
  }

  @override
  void initState() {
    super.initState();
    _fallbackRules = JournalFormatRulesService.instance.resolve(
      journalName: widget.journal.name,
      publisher: widget.journal.publisher,
      categories: widget.journal.categories,
      supportsIeee: widget.journal.supportsIeee,
      supportsApa: widget.journal.supportsApa,
      quartile: widget.journal.quartile,
      isPartner: widget.journal.isPartner,
    );
    _rules = _fallbackRules;
    _load();
  }

  @override
  void dispose() {
    _manualGuideUrlCtrl.dispose();
    _guideTextCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadingLinks = true;
      _error = null;
    });
    try {
      final m = await ManuscriptService.instance.getById(widget.manuscriptId);
      if (m == null) {
        throw Exception(appTr('المخطوطة غير موجودة', 'Manuscript not found'));
      }
      final prepared = await _prepareFromUpload(m);
      final links = await JournalGuidelinesService.instance.resolve(
        journalName: widget.journal.name,
        issn: widget.journal.issn,
        publisher: widget.journal.publisher,
        partnerSubmissionUrl: widget.journal.submissionUrl,
        isPartner: widget.journal.isPartner,
      );
      final discovery = await JournalGuidelinesService.instance.discoverForExtract(
        journalName: widget.journal.name,
        issn: widget.journal.issn,
        publisher: widget.journal.publisher,
        submissionUrl: widget.journal.submissionUrl,
      );
      if (!mounted) return;
      if (_manualGuideUrlCtrl.text.trim().isEmpty &&
          discovery.primaryUrl != null) {
        _manualGuideUrlCtrl.text = discovery.primaryUrl!;
      }
      setState(() {
        _manuscript = prepared.copyWith(
          journalId: widget.journal.id,
          journalName: widget.journal.name,
          citationStyle: _rules.citationStyle,
        );
        _resourceLinks = links;
        _seedUrls = discovery.candidateUrls;
        _discoveryLog = discovery.log;
        _loading = false;
        _loadingLinks = false;
      });
      await _extractGuidelines();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
        _loadingLinks = false;
      });
    }
  }

  Future<PublishManuscript> _prepareFromUpload(
    PublishManuscript manuscript, {
    void Function(String warning)? onWarning,
  }) async {
    final attachment = preferredSourceDocx(manuscript.attachments);
    if (attachment == null) return manuscript;

    try {
      final parsed = await ManuscriptDocumentParser.parseFromUrl(
        url: attachment.url,
        filename: attachment.name,
        manuscriptId: manuscript.id,
      );
      final parsedHasProse =
          ManuscriptDocumentParser.blocksHaveBodyProse(parsed.bodyBlocks);
      final existingHasProse =
          ManuscriptDocumentParser.blocksHaveBodyProse(manuscript.bodyBlocks);
      return ManuscriptDocumentParser.applyParseResult(
        manuscript: manuscript,
        parsed: parsed,
        replaceReferences: true,
        replaceBody: parsedHasProse || !existingHasProse,
      );
    } catch (e) {
      onWarning?.call(
        appTr(
          'تعذر إعادة قراءة ملف Word قبل التصدير — سيُستخدم محتوى المسودة الحالي. ($e)',
          'Could not re-read the Word file before export — using current draft content. ($e)',
        ),
      );
      return manuscript;
    }
  }

  Future<Uint8List?> _loadSourceDocxBytes(PublishManuscript manuscript) async {
    final attachment = preferredSourceDocx(manuscript.attachments);
    if (attachment == null || manuscript.id == null) return null;
    return ManuscriptUploadService.instance.downloadDocumentBytes(
      url: attachment.url,
      manuscriptId: manuscript.id,
      filename: attachment.name,
    );
  }

  Future<void> _extractGuidelines() async {
    setState(() {
      _extractingGuidelines = true;
      _extractionMessage = null;
    });

    try {
      final result = await JournalGuidelinesExtractService.instance.extract(
        journalName: widget.journal.name,
        publisher: widget.journal.publisher,
        issn: widget.journal.issn,
        guidelinesUrl: _manualGuideUrlCtrl.text.trim(),
        guidelinesText: _guideTextCtrl.text.trim(),
        submissionUrl: widget.journal.submissionUrl,
        candidateUrls: _extractCandidateUrls,
        fallback: _fallbackRules,
      );

      if (!mounted) return;
      setState(() {
        _extractionAttempted = true;
        _extractionSuccess = result.success;
        _extractionMessage = result.message;
        _keyRequirements = result.keyRequirements;
        _extractedExcerpt = result.excerpt;
        _extractedSourceUrl = result.sourceUrl;
        _fetchLogLines = result.fetchLog;

        if (result.success && result.rules != null) {
          _rules = result.rules!;
          _userChangedStyleAfterExtract = false;
          _manuscript =
              _manuscript?.copyWith(citationStyle: _rules.citationStyle);
          if (_keyRequirements.isEmpty && _rules.keyRequirements.isNotEmpty) {
            _keyRequirements = _rules.keyRequirements;
          }
        } else if (!_rules.extractedFromGuide) {
          _rules = _fallbackRules;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _extractionAttempted = true;
        _extractionSuccess = false;
        _extractionMessage = '$e';
      });
    } finally {
      if (mounted) setState(() => _extractingGuidelines = false);
    }
  }

  Future<void> _applyPastedGuide() async {
    final pasted = _guideTextCtrl.text.trim();
    if (pasted.length < 15) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t(
            'الصق نص دليل المؤلفين في المربع أولاً (١٥ حرفاً على الأقل).',
            'Paste the author guide into the box first (at least 15 characters).',
          )),
        ),
      );
      return;
    }
    if (_applyingPaste) return;

    setState(() => _applyingPaste = true);
    try {
      final result = await JournalGuidelinesExtractService.instance.extract(
        journalName: widget.journal.name,
        publisher: widget.journal.publisher,
        issn: widget.journal.issn,
        guidelinesText: pasted,
        fallback: _fallbackRules,
      );
      if (!mounted) return;
      setState(() {
        _extractionAttempted = true;
        _extractionSuccess = result.success;
        _extractionMessage = result.message;
        _keyRequirements = result.keyRequirements;
        _extractedExcerpt = result.excerpt;
        _extractedSourceUrl = result.sourceUrl;
        _fetchLogLines = result.fetchLog;
        if (result.success && result.rules != null) {
          _rules = result.rules!;
          _userChangedStyleAfterExtract = false;
          _manuscript =
              _manuscript?.copyWith(citationStyle: _rules.citationStyle);
          if (_keyRequirements.isEmpty && _rules.keyRequirements.isNotEmpty) {
            _keyRequirements = _rules.keyRequirements;
          }
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.success
                ? context.t(
                    'طُبّق النص الملصوق: ${result.keyRequirements.isEmpty ? (result.excerpt ?? 'قواعد من الدليل') : result.keyRequirements.take(3).join(' · ')}',
                    'Pasted guide applied: ${result.keyRequirements.isEmpty ? (result.excerpt ?? 'rules from the guide') : result.keyRequirements.take(3).join(' · ')}',
                  )
                : (result.message ??
                    context.t(
                      'لم تُستخرج قواعد من النص الملصوق.',
                      'No rules could be read from the pasted text.',
                    )),
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _applyingPaste = false);
    }
  }

  Future<void> _pickJournalTemplate() async {
    if (_readingTemplate || _extractingGuidelines) return;
    setState(() => _readingTemplate = true);
    try {
      final picked = await ManuscriptUploadService.instance.pickLocalDocument(
        extensions: const ['docx'],
      );
      if (picked == null) return;
      if (!picked.name.toLowerCase().endsWith('.docx')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t(
              'القالب يجب أن يكون DOCX (احفظ ملف .doc كـ .docx من Word ثم أعد الرفع).',
              'Template must be DOCX (save .doc as .docx in Word, then upload again).',
            )),
          ),
        );
        return;
      }
      final local = JournalTemplateReader.read(
        bytes: picked.bytes,
        filename: picked.name,
        journalName: widget.journal.name,
        publisher: widget.journal.publisher,
        fallback: _fallbackRules,
      );
      if (local == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t(
              'تعذر قراءة القالب. استخدم ملف Word (.docx) من موقع المجلة.',
              'Could not read the template. Use a Word (.docx) file from the journal site.',
            )),
          ),
        );
        return;
      }

      _guideTextCtrl.text = local.text;
      var rules = local.rules;
      final refined = await JournalGuidelinesExtractService.instance.extract(
        journalName: widget.journal.name,
        publisher: widget.journal.publisher,
        issn: widget.journal.issn,
        guidelinesText: local.text,
        fallback: _fallbackRules,
      );
      if (refined.success && refined.rules != null) {
        rules = refined.rules!.copyWith(
          fontFamily: local.rules.fontFamily,
          bodyFontHalfPoints: local.rules.bodyFontHalfPoints,
          titleFontHalfPoints: local.rules.titleFontHalfPoints,
          headingFontHalfPoints: local.rules.headingFontHalfPoints,
          lineSpacing: local.rules.lineSpacing,
          marginTwips: local.rules.marginTwips,
          columnCount: local.rules.columnCount,
          paperSize: local.rules.paperSize,
          firstLineIndentTwips: local.rules.firstLineIndentTwips,
          referenceExample:
              refined.rules!.referenceExample ?? local.rules.referenceExample,
          inTextExample:
              refined.rules!.inTextExample ?? local.rules.inTextExample,
        );
      }

      if (!mounted) return;
      setState(() {
        _templateName = local.name;
        _rules = rules.copyWith(extractedFromGuide: true);
        _extractionAttempted = true;
        _extractionSuccess = true;
        _extractionMessage = context.t(
          'قُرئ القالب «${local.name}» على الجهاز واستُخرجت قواعد التنسيق.',
          'Read template "${local.name}" on this device and extracted format rules.',
        );
        _keyRequirements = [
          'Template: ${local.name}',
          ...refined.keyRequirements,
        ];
        _extractedExcerpt = refined.excerpt ??
            (local.text.length > 400 ? local.text.substring(0, 400) : local.text);
        _manuscript = _manuscript?.copyWith(citationStyle: rules.citationStyle);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _readingTemplate = false);
    }
  }

  Future<JournalFormatRules> _resolveExportRules() async {
    final pasted = _guideTextCtrl.text.trim();
    if (pasted.length >= 15) {
      final pastedResult = await JournalGuidelinesExtractService.instance.extract(
        journalName: widget.journal.name,
        publisher: widget.journal.publisher,
        issn: widget.journal.issn,
        guidelinesText: pasted,
        fallback: _fallbackRules,
      );
      if (!mounted) return _rules;
      if (pastedResult.success && pastedResult.rules != null) {
        setState(() {
          _extractionAttempted = true;
          _extractionSuccess = true;
          _extractionMessage = pastedResult.message;
          _keyRequirements = pastedResult.keyRequirements;
          _extractedExcerpt = pastedResult.excerpt;
          _extractedSourceUrl = pastedResult.sourceUrl;
          _rules = pastedResult.rules!;
        });
        return pastedResult.rules!;
      }
    }

    if (_extractionSuccess &&
        (_rules.extractedFromGuide || _templateName != null)) {
      return _rules;
    }

    final result = await JournalGuidelinesExtractService.instance.extract(
      journalName: widget.journal.name,
      publisher: widget.journal.publisher,
      issn: widget.journal.issn,
      guidelinesUrl: _manualGuideUrlCtrl.text.trim(),
      submissionUrl: widget.journal.submissionUrl,
      candidateUrls: _extractCandidateUrls,
      fallback: _fallbackRules,
    );

    if (!mounted) return _rules;
    setState(() {
      _extractionAttempted = true;
      _extractionSuccess = result.success;
      _extractionMessage = result.message;
      _keyRequirements = result.keyRequirements;
      _extractedExcerpt = result.excerpt;
      _extractedSourceUrl = result.sourceUrl;
      _fetchLogLines = result.fetchLog;
      if (result.success && result.rules != null) {
        _rules = result.rules!;
        _userChangedStyleAfterExtract = false;
      }
    });

    return result.success && result.rules != null ? result.rules! : _rules;
  }

  Future<void> _applyAndExport() async {
    var m = _manuscript;
    if (m == null || _processing) return;

    setState(() => _processing = true);
    try {
      var exportRules = await _resolveExportRules();
      if (_userChangedStyleAfterExtract) {
        exportRules = exportRules.withCitationStyle(_rules.citationStyle);
      }

      if (!exportRules.extractedFromGuide) {
        if (!mounted) return;
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(context.t(
              'لم يُقرأ دليل المجلة',
              'Journal guide not read',
            )),
            content: Text(context.t(
              'التصدير سيستخدم قواعد تقديرية عامة (ليست من دليل هذه المجلة).\n\n'
              'الأدق: ارفع قالب Word الرسمي من البطاقة الخضراء أعلاه، أو الصق نص دليل المؤلفين في «خيارات متقدمة».\n\n'
              'هل تريد المتابعة بالقالب الاحتياطي؟',
              'Export will use generic estimated rules (not this journal\'s guide).\n\n'
              'Most accurate: upload the official Word template from the green card above, or paste the author guide under Advanced.\n\n'
              'Continue with fallback template?',
            )),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(context.t('إلغاء', 'Cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(context.t('متابعة', 'Continue')),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }

      String? prepareWarning;
      m = await _prepareFromUpload(
        m,
        onWarning: (w) => prepareWarning = w,
      );
      if (!mounted) return;
      setState(() => _manuscript = m);
      if (prepareWarning != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(prepareWarning!)),
        );
      }

      await ManuscriptService.instance.save(
        m.copyWith(
          citationStyle: exportRules.citationStyle,
          journalId: widget.journal.id,
          journalName: widget.journal.name,
          status: ManuscriptStatus.formatted,
        ),
      );
      await ManuscriptService.instance.markFormatted(
        widget.manuscriptId,
        exportRules.citationStyle,
      );

      final sourceBytes = await _loadSourceDocxBytes(m);
      final export =
          await ManuscriptDocxExportService.instance.shareFormattedDocx(
        manuscript: m.copyWith(citationStyle: exportRules.citationStyle),
        rules: exportRules,
        sourceDocxBytes: sourceBytes,
      );

      if (!mounted) return;
      if (!export.saved) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t(
              'أُلغي حفظ ملف Word — لم تُحدَّث حالة التقديم.',
              'Word save was cancelled — submission status was not updated.',
            )),
          ),
        );
        return;
      }

      // Only mark submitted after the researcher actually saved/shared the file.
      await ManuscriptService.instance.submitToJournal(
        manuscriptId: widget.manuscriptId,
        journalId: widget.journal.id,
        journalName: widget.journal.name,
      );

      if (!mounted) return;
      final imageCount = export.imageCount;
      final imageNote = imageCount > 0
          ? context.t(
              ' — $imageCount صورة مضمّنة من الملف الأصلي',
              ' — $imageCount picture(s) from the original file',
            )
          : context.t(
              ' — لم تُضمَّن صور. ارفع ملف DOCX الأصلي (وليس PDF أو ملفاً مستخرجاً سابقاً).',
              ' — No pictures embedded. Upload the original DOCX (not a PDF or a previously extracted file).',
            );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t(
            exportRules.extractedFromGuide
                ? 'تم التصدير بقواعد «${widget.journal.name}» من الدليل — تباعد ${exportRules.lineSpacing}، مراجع: ${CitationFormatter.detectedStyleLabel(exportRules.citationStyle, plainNumberList: exportRules.referenceListPlainNumber)}$imageNote'
                : 'تم التصدير بقالب احتياطي (ليس من دليل المجلة) — تباعد ${exportRules.lineSpacing}$imageNote',
            exportRules.extractedFromGuide
                ? 'Exported with «${widget.journal.name}» guide rules — spacing ${exportRules.lineSpacing}, refs: ${CitationFormatter.detectedStyleLabel(exportRules.citationStyle, plainNumberList: exportRules.referenceListPlainNumber)}$imageNote'
                : 'Exported with fallback template (not from journal guide) — spacing ${exportRules.lineSpacing}$imageNote',
          )),
          duration: const Duration(seconds: 8),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Color _confidenceColor() {
    if (_rules.extractedFromGuide) return const Color(0xFF86EFAC);
    return switch (_rules.confidence) {
      FormatRuleConfidence.partnerOfficial => const Color(0xFF86EFAC),
      FormatRuleConfidence.publisherStandard => const Color(0xFF93C5FD),
      FormatRuleConfidence.estimated => AcadeGateColors.gold,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('تنسيق حسب المجلة', 'Journal formatting')),
        backgroundColor: AcadeGateColors.appBar,
        foregroundColor: AcadeGateColors.text,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          child: Text(context.t('إعادة المحاولة', 'Retry')),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline, color: AcadeGateColors.gold),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                context.t(
                                  'مواقع المجلات غالباً تمنع القراءة الآلية (صفحات ديناميكية، تسجيل دخول، أو PDF محمي). '
                                  'الأضمن: حمّل قالب Word الرسمي من موقع المجلة وارفعه هنا. '
                                  'البحث التلقائي عبر الإنترنت غير متاح الآن.',
                                  'Journal sites often block automated reading (JavaScript pages, login, or protected PDFs). '
                                  'Most reliable: download the official Word template from the journal site and upload it here. '
                                  'Automatic web search is not available right now.',
                                ),
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.45,
                                  color: AcadeGateColors.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.journal.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            if (widget.journal.publisher.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  widget.journal.publisher,
                                  style: TextStyle(color: const Color(0xFFB7C3D6)),
                                ),
                              ),
                            if (widget.journal.issn.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'ISSN: ${widget.journal.issn}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: const Color(0xFFB7C3D6),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 10),
                            Chip(
                              avatar: Icon(
                                Icons.verified_outlined,
                                size: 18,
                                color: _confidenceColor(),
                              ),
                              label: Text(
                                _rules.confidenceLabel(isEnglish: isEnglish),
                              ),
                              labelStyle: TextStyle(
                                color: _confidenceColor(),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                              backgroundColor:
                                  _confidenceColor().withValues(alpha: 0.16),
                              side: BorderSide(
                                color: _confidenceColor().withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _rules.basis(isEnglish: isEnglish),
                              style: TextStyle(
                                fontSize: 13,
                                color: const Color(0xFFB7C3D6),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.t(
                                'رفع قالب المجلة (الأدق)',
                                'Upload journal template (most accurate)',
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AcadeGateColors.text,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              context.t(
                                'حمّل ملف Word الرسمي من صفحة دليل المؤلفين في موقع المجلة، ثم ارفعه هنا. نقرأ الخط والتباعد والهوامش ونموذج المراجع من الملف على جهازك.',
                                'Download the official Word file from the journal’s author-guide page, then upload it here. We read font, spacing, margins, and reference samples on this device.',
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: const Color(0xFFB7C3D6),
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (_templateName != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  context.t(
                                    'القالب الحالي: $_templateName',
                                    'Current template: $_templateName',
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            FilledButton.icon(
                              onPressed: (_readingTemplate ||
                                      _extractingGuidelines)
                                  ? null
                                  : _pickJournalTemplate,
                              icon: _readingTemplate
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.upload_file),
                              label: Text(
                                _templateName == null
                                    ? context.t(
                                        'رفع قالب Word للمجلة',
                                        'Upload journal Word template',
                                      )
                                    : context.t(
                                        'استبدال القالب',
                                        'Replace template',
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.t(
                                'الصق دليل المؤلفين (لأي مجلة)',
                                'Paste the author guide (any journal)',
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AcadeGateColors.text,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              context.t(
                                'انسخ نص دليل المؤلفين من موقع المجلة أو الناشر والصقه هنا، ثم اضغط تطبيق. هذا أدق من البحث التلقائي عندما تمنع المواقع الجلب.',
                                'Copy the author guide from the journal or publisher site, paste it here, then tap Apply. This is more reliable than auto-search when sites block fetching.',
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: const Color(0xFFB7C3D6),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _guideTextCtrl,
                              minLines: 6,
                              maxLines: 14,
                              textInputAction: TextInputAction.newline,
                              style: const TextStyle(color: AcadeGateColors.text),
                              cursorColor: AcadeGateColors.gold,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                labelText: context.t(
                                  'نص الدليل',
                                  'Guide text',
                                ),
                                labelStyle: const TextStyle(color: AcadeGateColors.muted),
                                hintStyle: const TextStyle(color: AcadeGateColors.muted),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              context.t(
                                '${_guideTextCtrl.text.trim().length} حرفاً ملصوقاً',
                                '${_guideTextCtrl.text.trim().length} characters pasted',
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                color: const Color(0xFFB7C3D6),
                              ),
                            ),
                            const SizedBox(height: 10),
                            FilledButton.icon(
                              onPressed: _applyingPaste ? null : _applyPastedGuide,
                              icon: _applyingPaste
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.playlist_add_check),
                              label: Text(
                                context.t(
                                  'تطبيق النص الملصوق',
                                  'Apply pasted text',
                                ),
                              ),
                            ),
                            if (_extractionAttempted &&
                                _extractedSourceUrl == 'pasted_by_user') ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(
                                    _extractionSuccess
                                        ? Icons.check_circle
                                        : Icons.warning_amber,
                                    color: _extractionSuccess
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _extractionSuccess
                                          ? context.t(
                                              'طُبّقت قواعد النص الملصوق',
                                              'Pasted-guide rules applied',
                                            )
                                          : (_extractionMessage ??
                                              context.t(
                                                'تعذر قراءة النص الملصوق',
                                                'Could not read the pasted text',
                                              )),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.t(
                                'قراءة دليل المؤلفين (تلقائي)',
                                'Author guide (automatic)',
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_extractingGuidelines)
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      context.t(
                                        'جارٍ البحث التلقائي عن دليل المؤلفين وقراءته...',
                                        'Automatically searching for and reading the author guide...',
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else if (_extractionAttempted)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _extractionSuccess
                                            ? Icons.check_circle
                                            : Icons.warning_amber,
                                        color: _extractionSuccess
                                            ? Colors.green
                                            : Colors.orange,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _extractionSuccess
                                              ? context.t(
                                                  'تم استخراج قواعد من دليل المؤلفين',
                                                  'Rules extracted from author guide',
                                                )
                                              : context.t(
                                                  'تعذّر القراءة التلقائية — قالب احتياطي',
                                                  'Auto-read failed — using fallback',
                                                ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_extractionMessage != null &&
                                      _extractionMessage!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        _extractionMessage!,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: const Color(0xFFB7C3D6),
                                        ),
                                      ),
                                    ),
                                  if (_extractedSourceUrl != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: TextButton(
                                        onPressed: () =>
                                            _openLink(_extractedSourceUrl!),
                                        child: Text(
                                          context.t(
                                            'فتح المصدر المقروء',
                                            'Open extracted source',
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            if (_discoveryLog.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                context.t(
                                  'روابط تم البحث فيها (${_discoveryLog.length})',
                                  'URLs searched locally (${_discoveryLog.length})',
                                ),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              ..._discoveryLog.take(8).map(
                                (line) => Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    line,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: const Color(0xFFB7C3D6),
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ),
                              if (_discoveryLog.length > 8)
                                Text(
                                  context.t(
                                    '... و${_discoveryLog.length - 8} رابطاً إضافياً',
                                    '... and ${_discoveryLog.length - 8} more URLs',
                                  ),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: const Color(0xFFB7C3D6),
                                  ),
                                ),
                            ],
                            if (_fetchLogLines.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                context.t('سجل الجلب', 'Fetch log'),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              ..._fetchLogLines.map(
                                (line) => Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    line,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: const Color(0xFFB7C3D6),
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            if (_extractedExcerpt != null &&
                                _extractedExcerpt!.trim().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                context.t('مقتطف من المصدر', 'Excerpt from source'),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _extractedExcerpt!,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  color: const Color(0xFFB7C3D6),
                                  height: 1.4,
                                ),
                              ),
                            ],
                            if (_keyRequirements.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                context.t(
                                  'متطلبات وُجدت في الدليل',
                                  'Requirements found in guide',
                                ),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              ..._keyRequirements.map(
                                (req) => Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('• $req'),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: Text(
                                context.t(
                                  'البحث التلقائي برابط الدليل',
                                  'Automatic search by guide URL',
                                ),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              children: [
                                TextField(
                                  controller: _manualGuideUrlCtrl,
                                  decoration: InputDecoration(
                                    labelText: context.t(
                                      'رابط دليل المؤلفين',
                                      'Author guide URL',
                                    ),
                                    hintText: 'https://...',
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: FilledButton.tonalIcon(
                                    onPressed: _extractingGuidelines
                                        ? null
                                        : _extractGuidelines,
                                    icon: const Icon(Icons.refresh),
                                    label: Text(
                                      context.t(
                                        'بحث في موقع المجلة / الناشر',
                                        'Search journal / publisher site',
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.t(
                        'الطريق الصحيح للتقديم',
                        'Correct path to submission',
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_loadingLinks)
                      const Center(child: CircularProgressIndicator())
                    else
                      Card(
                        child: Column(
                          children: _resourceLinks.map((link) {
                            final isPrimary =
                                link.source == 'google_guidelines' ||
                                link.source == 'partner' ||
                                link.source == 'crossref';
                            return ListTile(
                              leading: Icon(
                                isPrimary
                                    ? Icons.link
                                    : Icons.open_in_new_outlined,
                                color: isPrimary
                                    ? AcadeGateColors.gold
                                    : AcadeGateColors.muted,
                              ),
                              title: Text(
                                link.label(isEnglish: isEnglish),
                                style: TextStyle(
                                  fontWeight: isPrimary
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _openLink(link.url),
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 16),
                    CitationStylePicker(
                      value: _rules.citationStyle,
                      onChanged: (style) {
                        setState(() {
                          _userChangedStyleAfterExtract = true;
                          _rules = _rules.withCitationStyle(style);
                          _manuscript = _manuscript?.copyWith(
                            citationStyle: style,
                          );
                        });
                      },
                    ),
                    if ((_rules.referenceExample ?? '').trim().isNotEmpty ||
                        (_rules.inTextExample ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.t(
                                  'شكل المرجع المطلوب من دليل المجلة',
                                  'Reference shape required by the journal guide',
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AcadeGateColors.text,
                                ),
                              ),
                              if ((_rules.referenceExample ?? '')
                                  .trim()
                                  .isNotEmpty) ...[
                                const SizedBox(height: 8),
                                SelectableText(_rules.referenceExample!.trim()),
                              ],
                              if ((_rules.inTextExample ?? '')
                                  .trim()
                                  .isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  context.t(
                                    'الاقتباس داخل النص:',
                                    'In-text citation:',
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: const Color(0xFFB7C3D6),
                                  ),
                                ),
                                SelectableText(_rules.inTextExample!.trim()),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      context.t(
                        'التصدير يطبّق كل القواعد المستخرجة (خط، تباعد، أعمدة، عناوين) ويعيد كتابة المراجع بشكل الدليل أعلاه — وليس قالباً عاماً.',
                        'Export applies every extracted rule (font, spacing, columns, headings) and rewrites references to the sample above — not a generic template.',
                      ),
                      style: TextStyle(fontSize: 12, color: const Color(0xFFB7C3D6)),
                    ),
                    if (_manuscript != null &&
                        _rules.abstractMaxWords != null &&
                        _manuscript!.abstractText.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _AbstractLimitCard(
                        abstractText: _manuscript!.abstractText,
                        maxWords: _rules.abstractMaxWords!,
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      _extractionSuccess
                          ? context.t(
                              'القواعد المستخرجة (ستُطبَّق على Word)',
                              'Extracted rules (applied to Word)',
                            )
                          : context.t(
                              'قالب احتياطي (ليس من دليل المجلة)',
                              'Fallback template (not from journal guide)',
                            ),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: _rules
                              .ruleDescriptions(isEnglish: isEnglish)
                              .map(
                                (rule) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.tune,
                                        size: 20,
                                        color: const Color(0xFFB7C3D6),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(child: Text(rule)),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.t('خطوات التحقق', 'Verification steps'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _rules
                              .verificationSteps(isEnglish: isEnglish)
                              .asMap()
                              .entries
                              .map(
                                (e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    '${e.key + 1}. ${e.value}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: const Color(0xFFB7C3D6),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                    if (_manuscript?.attachments.isNotEmpty == true) ...[
                      const SizedBox(height: 12),
                      Text(
                        context.t('الملف المصدر', 'Source file'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      ..._manuscript!.attachments
                          .where((a) => a.isWord || a.isPdf)
                          .map(
                            (a) => ListTile(
                              dense: true,
                              leading: Icon(
                                a.isWord
                                    ? Icons.description_outlined
                                    : Icons.picture_as_pdf_outlined,
                              ),
                              title: Text(a.name),
                            ),
                          ),
                    ],
                  ],
                ),
      bottomNavigationBar: _loading || _error != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton.icon(
                      onPressed: _processing ? null : _applyAndExport,
                      style: FilledButton.styleFrom(
                        backgroundColor: AcadeGateColors.gold,
                        foregroundColor: AcadeGateColors.page,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      icon: _processing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AcadeGateColors.page,
                              ),
                            )
                          : const Icon(Icons.description),
                      label: Text(
                        _extractionSuccess
                            ? context.t(
                                'تطبيق القواعد المستخرجة وتصدير Word',
                                'Apply extracted rules & export Word',
                              )
                            : context.t(
                                'تصدير بالقالب الاحتياطي',
                                'Export with fallback template',
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _openLink(
                        JournalGuidelinesService.authorGuidelinesSearchUrl(
                          widget.journal.name,
                        ),
                      ),
                      icon: const Icon(Icons.menu_book_outlined),
                      label: Text(
                        context.t(
                          'فتح دليل المؤلفين (بحث)',
                          'Open author guidelines (search)',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _AbstractLimitCard extends StatelessWidget {
  final String abstractText;
  final int maxWords;

  const _AbstractLimitCard({
    required this.abstractText,
    required this.maxWords,
  });

  @override
  Widget build(BuildContext context) {
    final words = abstractText.trim().split(RegExp(r'\s+')).length;
    final over = words > maxWords;
    final tone = over ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC);
    return Card(
      child: ListTile(
        leading: Icon(
          over ? Icons.warning_amber : Icons.check_circle_outline,
          color: tone,
        ),
        title: Text(
          context.t(
            'الملخص: $words / $maxWords كلمة',
            'Abstract: $words / $maxWords words',
          ),
          style: TextStyle(color: tone, fontWeight: FontWeight.w700),
        ),
        subtitle: over
            ? Text(
                context.t(
                  'تجاوز حد المجلة — اختصر الملخص قبل التقديم.',
                  'Over the journal limit — shorten the abstract before submission.',
                ),
                style: const TextStyle(color: AcadeGateColors.muted),
              )
            : null,
      ),
    );
  }
}
