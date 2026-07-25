import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale/app_translate.dart';
import '../../core/locale/locale_extensions.dart';
import 'journal_format_rules.dart';
import 'journal_guidelines_heuristic.dart';
import 'citation_formatter.dart';
import 'journal_guidelines_extract_service.dart';
import 'journal_guidelines_service.dart';
import 'journal_selection_screen.dart';
import 'manuscript_docx_export_service.dart';
import 'manuscript_document_parser.dart';
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
  static const _brand = Color(0xFF4A148C);

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
  List<JournalResourceLink> _resourceLinks = const [];
  List<String> _seedUrls = const [];
  List<String> _discoveryLog = const [];

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
    PublishManuscript manuscript,
  ) async {
    final wordFiles = manuscript.attachments.where((a) => a.isWord).toList();
    if (wordFiles.isEmpty) return manuscript;
    final wordAttachment = wordFiles.last;

    try {
      final parsed = await ManuscriptDocumentParser.parseFromUrl(
        url: wordAttachment.url,
        filename: wordAttachment.name,
      );
      return ManuscriptDocumentParser.applyParseResult(
        manuscript: manuscript,
        parsed: parsed,
        replaceReferences: manuscript.references.isEmpty,
        replaceBody: true,
      );
    } catch (_) {
      return manuscript;
    }
  }

  Future<void> _extractGuidelines() async {
    setState(() {
      _extractingGuidelines = true;
      _extractionMessage = null;
    });

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
      _extractingGuidelines = false;
      _extractionAttempted = true;
      _extractionSuccess = result.success;
      _extractionMessage = result.message;
      _keyRequirements = result.keyRequirements;
      _extractedExcerpt = result.excerpt;
      _extractedSourceUrl = result.sourceUrl;
      _fetchLogLines = result.fetchLog;

      if (result.success && result.rules != null) {
        _rules = result.rules!.orFallback(_fallbackRules);
        _manuscript = _manuscript?.copyWith(citationStyle: _rules.citationStyle);
      } else {
        _rules = _fallbackRules;
      }
    });
  }

  Future<JournalFormatRules> _resolveExportRules() async {
    final pasted = _guideTextCtrl.text.trim();
    if (pasted.length >= 15) {
      final heuristic = JournalGuidelinesHeuristic.extract(pasted);
      if (heuristic != null) {
        return JournalFormatRules.fromExtracted(
          journalName: widget.journal.name,
          publisher: widget.journal.publisher,
          sourceUrl: _manualGuideUrlCtrl.text.trim().isNotEmpty
              ? _manualGuideUrlCtrl.text.trim()
              : 'pasted_by_user',
          extracted: heuristic,
          fallback: _fallbackRules,
        );
      }
    }

    final result = await JournalGuidelinesExtractService.instance.extract(
      journalName: widget.journal.name,
      publisher: widget.journal.publisher,
      issn: widget.journal.issn,
      guidelinesUrl: _manualGuideUrlCtrl.text.trim(),
      guidelinesText: pasted,
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
        _rules = result.rules!.orFallback(_fallbackRules);
      }
    });

    return result.success && result.rules != null
        ? result.rules!.orFallback(_fallbackRules)
        : _rules;
  }

  JournalFormatRules _finalizeExportRules(
    JournalFormatRules rules,
    PublishManuscript manuscript,
  ) {
    // Author guide rules take priority over guessing from imported references.
    if (rules.extractedFromGuide) return rules;
    if (manuscript.references.isEmpty) return rules;

    final detected = CitationFormatter.detectReferenceStyle(manuscript.references);
    if (detected != rules.citationStyle) {
      return rules.withCitationStyle(detected);
    }
    return rules;
  }

  Future<void> _applyAndExport() async {
    var m = _manuscript;
    if (m == null || _processing) return;

    setState(() => _processing = true);
    try {
      final exportRules = _finalizeExportRules(
        await _resolveExportRules(),
        m,
      );

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
              'للدقة: الصق نص دليل المؤلفين في «خيارات متقدمة» ثم اضغط «إعادة القراءة».\n\n'
              'هل تريد المتابعة بالقالب الاحتياطي؟',
              'Export will use generic estimated rules (not this journal\'s guide).\n\n'
              'For accuracy: paste the author guide text under Advanced options, then tap Re-read.\n\n'
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

      m = await _prepareFromUpload(m);
      if (!mounted) return;
      setState(() => _manuscript = m);

      await ManuscriptService.instance.submitToJournal(
        manuscriptId: widget.manuscriptId,
        journalId: widget.journal.id,
        journalName: widget.journal.name,
      );
      await ManuscriptService.instance.markFormatted(
        widget.manuscriptId,
        exportRules.citationStyle,
      );
      await ManuscriptService.instance.save(
        m.copyWith(
          citationStyle: exportRules.citationStyle,
          journalId: widget.journal.id,
          journalName: widget.journal.name,
        ),
      );

      await ManuscriptDocxExportService.instance.shareFormattedDocx(
        manuscript: m.copyWith(citationStyle: exportRules.citationStyle),
        rules: exportRules,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t(
            exportRules.extractedFromGuide
                ? 'تم التصدير بقواعد «${widget.journal.name}» من الدليل — تباعد ${exportRules.lineSpacing}، مراجع: ${CitationFormatter.detectedStyleLabel(exportRules.citationStyle, plainNumberList: exportRules.referenceListPlainNumber)}'
                : 'تم التصدير بقالب احتياطي (ليس من دليل المجلة) — تباعد ${exportRules.lineSpacing}',
            exportRules.extractedFromGuide
                ? 'Exported with «${widget.journal.name}» guide rules — spacing ${exportRules.lineSpacing}, refs: ${CitationFormatter.detectedStyleLabel(exportRules.citationStyle, plainNumberList: exportRules.referenceListPlainNumber)}'
                : 'Exported with fallback template (not from journal guide) — spacing ${exportRules.lineSpacing}',
          )),
          duration: const Duration(seconds: 6),
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
    if (_rules.extractedFromGuide) return const Color(0xFF1B5E20);
    return switch (_rules.confidence) {
      FormatRuleConfidence.partnerOfficial => const Color(0xFF1B5E20),
      FormatRuleConfidence.publisherStandard => const Color(0xFF0D47A1),
      FormatRuleConfidence.estimated => const Color(0xFFE65100),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('تنسيق حسب المجلة', 'Journal formatting')),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
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
                      color: Colors.amber.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, color: Colors.amber.shade900),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                context.t(
                                  'عند اختيار المجلة، يبحث الذكاء الاصطناعي تلقائياً عن دليل المؤلفين. '
                                  'لصق القواعد في «خيارات متقدمة» يعمل مجاناً بدون اشتراك. '
                                  'البحث التلقائي عبر الإنترنت يحتاج رصيد Gemini API (Google AI Studio) — ليس اشتراك AcadeGate.',
                                  'When you pick a journal, AI searches for the author guide. '
                                  'Pasting rules in Advanced options is free — no subscription. '
                                  'Automatic online search needs Gemini API credits (Google AI Studio) — not an AcadeGate subscription.',
                                ),
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.45,
                                  color: Colors.grey[900],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      color: _brand.withValues(alpha: 0.08),
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
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                              ),
                            if (widget.journal.issn.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'ISSN: ${widget.journal.issn}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
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
                                style: TextStyle(
                                  color: _confidenceColor(),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              backgroundColor:
                                  _confidenceColor().withValues(alpha: 0.1),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _rules.basis(isEnglish: isEnglish),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[800],
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
                                          color: Colors.grey[700],
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
                                      color: Colors.grey[700],
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
                                    color: Colors.grey[600],
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
                                      color: Colors.grey[700],
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
                                  color: Colors.grey[800],
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
                                  'خيارات متقدمة (رابط أو نص يدوي)',
                                  'Advanced (manual URL or text)',
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
                                TextField(
                                  controller: _guideTextCtrl,
                                  minLines: 4,
                                  maxLines: 8,
                                  decoration: InputDecoration(
                                    labelText: context.t(
                                      'أو انسخ نص الدليل والصقه هنا',
                                      'Or paste guide text here',
                                    ),
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
                                        'إعادة القراءة',
                                        'Re-read',
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
                                color: isPrimary ? _brand : Colors.grey[600],
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
                                        color: Colors.grey[600],
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
                                      color: Colors.grey[800],
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
                        backgroundColor: _brand,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      icon: _processing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
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
