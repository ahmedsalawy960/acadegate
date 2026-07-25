import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../profile/academic_profile_screen.dart';
import '../profile/academic_profile_service.dart';
import '../research_journey/thesis_progress.dart';
import '../research_journey/thesis_progress_activity.dart';
import 'methodology_integrity_models.dart';
import 'methodology_integrity_service.dart';
import 'methodology_pdf_service.dart';

class MethodologyIntegrityScreen extends StatefulWidget {
  const MethodologyIntegrityScreen({super.key});

  @override
  State<MethodologyIntegrityScreen> createState() =>
      _MethodologyIntegrityScreenState();
}

class _MethodologyIntegrityScreenState
    extends State<MethodologyIntegrityScreen> {
  static const _brand = Color(0xFF1B5E20);

  final _service = MethodologyIntegrityService.instance;
  final _pdfService = MethodologyPdfService.instance;
  final _titleController = TextEditingController();
  final _questionController = TextEditingController();
  final _methodologyController = TextEditingController();
  final _populationController = TextEditingController();
  final _collectionController = TextEditingController();
  final _analysisController = TextEditingController();

  String _statedMethodology = 'كمي';
  bool _loading = false;
  bool _extractingPdf = false;
  MethodologyIntegrityReport? _report;
  List<int>? _pdfBytes;
  String? _pdfFileName;
  bool _pdfTruncated = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await AcademicProfileService.instance.loadProfile();
    if (!mounted || profile == null) return;
    if (_questionController.text.isEmpty &&
        profile.researchInterest.isNotEmpty) {
      _questionController.text = profile.researchInterest;
    }
    if (profile.methodology.isNotEmpty) {
      final m = profile.methodology;
      if (m.contains('نوع')) {
        _statedMethodology = 'نوعي';
      } else if (m.contains('مختلط') || m.toLowerCase().contains('mixed')) {
        _statedMethodology = 'مختلط';
      } else {
        _statedMethodology = 'كمي';
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _titleController.dispose();
    _questionController.dispose();
    _methodologyController.dispose();
    _populationController.dispose();
    _collectionController.dispose();
    _analysisController.dispose();
    super.dispose();
  }

  MethodologyIntegrityInput get _input => MethodologyIntegrityInput(
        thesisTitle: _titleController.text.trim(),
        researchQuestion: _questionController.text.trim(),
        statedMethodology: _statedMethodology,
        methodologyText: _methodologyController.text.trim(),
        population: _populationController.text.trim(),
        dataCollection: _collectionController.text.trim(),
        analysisApproach: _analysisController.text.trim(),
        pdfBytes: _pdfBytes,
        pdfFileName: _pdfFileName,
      );

  void _applyMethodologyType(String? type) {
    if (type == null || type.isEmpty) return;
    final m = type.toLowerCase();
    if (m.contains('qual') || m.contains('نوع')) {
      _statedMethodology = 'نوعي';
    } else if (m.contains('mixed') || m.contains('مختلط')) {
      _statedMethodology = 'مختلط';
    } else if (m.contains('quant') || m.contains('كمي')) {
      _statedMethodology = 'كمي';
    }
  }

  Future<void> _pickPdf() async {
    if (!_service.isCloudEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'استخراج المنهجية من PDF يتطلب تسجيل الدخول أو الذكاء السحابي',
              'Extracting methodology from PDF requires sign-in or cloud AI',
            ),
          ),
        ),
      );
      return;
    }

    try {
      final picked = await _pdfService.pickPdf();
      if (picked == null || !mounted) return;
      setState(() => _extractingPdf = true);

      _pdfBytes = picked.bytes;
      _pdfFileName = picked.name;

      final extracted = await _pdfService.extractMethodologyFromPdf(
        bytes: picked.bytes,
        fileName: picked.name,
      );
      if (!mounted) return;

      if (extracted.title.isNotEmpty) {
        _titleController.text = extracted.title;
      }
      if (extracted.researchQuestion.isNotEmpty) {
        _questionController.text = extracted.researchQuestion;
      }
      _methodologyController.text = extracted.methodologyText;
      if (extracted.populationSample?.isNotEmpty == true) {
        _populationController.text = extracted.populationSample!;
      }
      if (extracted.dataCollection?.isNotEmpty == true) {
        _collectionController.text = extracted.dataCollection!;
      }
      if (extracted.analysisApproach?.isNotEmpty == true) {
        _analysisController.text = extracted.analysisApproach!;
      }
      _applyMethodologyType(extracted.methodologyType);

      setState(() {
        _extractingPdf = false;
        _pdfTruncated = extracted.truncated;
        _report = null;
      });

      final chars = extracted.methodologyText.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            extracted.truncated
                ? context.t(
                    'تم استيراد $chars حرفاً من المنهجية (قد يكون النص مقطوعاً — سيُستخدم PDF كاملاً في الفحص)',
                    'Imported $chars methodology characters (text may be clipped — full PDF will be used for analysis)',
                  )
                : context.t(
                    'تم استيراد فصل المنهجية ($chars حرف)',
                    'Methodology chapter imported ($chars characters)',
                  ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _extractingPdf = false;
        _pdfBytes = null;
        _pdfFileName = null;
        _pdfTruncated = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _runCheck() async {
    final input = _input;
    if (!input.hasContent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'أدخل نص المنهجية أو سؤال البحث أولاً',
              'Enter methodology text or research question first',
            ),
          ),
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
      _report = null;
    });

    final profile = await AcademicProfileService.instance.loadProfile();
    final report = await _service.analyze(input: input, profile: profile);

    if (!mounted) return;
    setState(() {
      _report = report;
      _loading = false;
    });
    await ThesisProgressService.instance.recordActivity(
      ThesisActivityId.methodologyEthics.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(
          context.t(
            'كاشف الانتحال المنهجي',
            'Methodology Integrity Check',
          ),
        ),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: context.t('الملف الأكاديمي', 'Academic profile'),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AcademicProfileScreen(),
                ),
              );
              await _loadProfile();
            },
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _headerCard(),
          const SizedBox(height: 16),
          _buildForm(),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : _runCheck,
            style: FilledButton.styleFrom(
              backgroundColor: _brand,
              minimumSize: const Size(double.infinity, 48),
            ),
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.verified_user_outlined),
            label: Text(
              _loading
                  ? context.t('جاري الفحص...', 'Checking...')
                  : context.t('فحص سلامة المنهجية', 'Check methodology integrity'),
            ),
          ),
          if (_report != null) ...[
            const SizedBox(height: 20),
            _buildReport(_report!),
          ],
        ],
      ),
    );
  }

  Widget _headerCard() {
    return Card(
      color: _brand.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.policy_outlined, color: _brand, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.t(
                      'كاشف الانتحال المنهجي',
                      'Methodology Integrity Check',
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _brand,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.t(
                'يكشف التناقضات المنهجية، مؤشرات النقل غير المبرر، وضعف التبرير '
                'بين سؤال البحث والتصميم والعينة والتحليل.',
                'Detects methodological inconsistencies, unjustified copying indicators, '
                'and weak justification between your question, design, sample, and analysis.',
              ),
              style: TextStyle(height: 1.5, color: Colors.grey[800]),
            ),
            if (!_service.isCloudEnabled) ...[
              const SizedBox(height: 8),
              Text(
                context.t(
                  'الفحص المحلي متاح — التحليل الذكي السحابي اختياري لنتائج أعمق.',
                  'Local check available — optional cloud smart analysis for deeper results.',
                ),
                style: TextStyle(fontSize: 12, color: Colors.orange[800]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _extractingPdf ? null : _pickPdf,
          icon: _extractingPdf
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.picture_as_pdf_outlined),
          label: Text(
            _extractingPdf
                ? context.t('جاري استخراج المنهجية...', 'Extracting methodology...')
                : context.t('استيراد فصل المنهجية من PDF', 'Import methodology chapter from PDF'),
          ),
        ),
        if (_pdfFileName != null) ...[
          const SizedBox(height: 8),
          Material(
            color: _brand.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.attach_file, color: _brand, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _pdfFileName!,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          context.t(
                            '${_methodologyController.text.length} / ${MethodologyPdfService.maxMethodologyChars} حرف'
                            '${_pdfTruncated ? ' — سيُفحص PDF كاملاً' : ''}',
                            '${_methodologyController.text.length} / ${MethodologyPdfService.maxMethodologyChars} chars'
                            '${_pdfTruncated ? ' — full PDF will be analyzed' : ''}',
                          ),
                          style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: context.t('إزالة PDF', 'Remove PDF'),
                    onPressed: _extractingPdf
                        ? null
                        : () => setState(() {
                              _pdfBytes = null;
                              _pdfFileName = null;
                              _pdfTruncated = false;
                            }),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ],
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: context.t('عنوان البحث (اختياري)', 'Thesis title (optional)'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _questionController,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: context.t('سؤال/فرضية البحث', 'Research question/hypothesis'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          context.t('المنهجية المعلنة', 'Stated methodology'),
          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(
              value: 'كمي',
              label: Text(context.t('كمي', 'Quantitative')),
            ),
            ButtonSegment(
              value: 'نوعي',
              label: Text(context.t('نوعي', 'Qualitative')),
            ),
            ButtonSegment(
              value: 'مختلط',
              label: Text(context.t('مختلط', 'Mixed')),
            ),
          ],
          selected: {_statedMethodology},
          onSelectionChanged: (values) {
            setState(() => _statedMethodology = values.first);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _methodologyController,
          minLines: 8,
          maxLines: 20,
          decoration: InputDecoration(
            labelText: context.t(
              'نص فصل/قسم المنهجية',
              'Methodology chapter/section text',
            ),
            hintText: context.t(
              'الصق فصل المنهجية أو الجزء الخاص بالتصميم والإجراءات...',
              'Paste your methodology chapter or design/procedures section...',
            ),
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _populationController,
          decoration: InputDecoration(
            labelText: context.t('المجتمع والعينة (اختياري)', 'Population & sample (optional)'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _collectionController,
          decoration: InputDecoration(
            labelText: context.t('أدوات جمع البيانات (اختياري)', 'Data collection tools (optional)'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _analysisController,
          decoration: InputDecoration(
            labelText: context.t('أساليب التحليل (اختياري)', 'Analysis approach (optional)'),
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildReport(MethodologyIntegrityReport report) {
    final scoreColor = report.integrityScore >= 75
        ? Colors.green
        : (report.integrityScore >= 50 ? Colors.orange : Colors.red);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  context.t('درجة السلامة المنهجية', 'Methodology integrity score'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: report.integrityScore / 100,
                        strokeWidth: 10,
                        color: scoreColor,
                        backgroundColor: scoreColor.withValues(alpha: 0.15),
                      ),
                      Text(
                        '${report.integrityScore}%',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: scoreColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  report.summary,
                  textAlign: TextAlign.center,
                  style: const TextStyle(height: 1.5),
                ),
                if (report.fromCloudAi) ...[
                  const SizedBox(height: 8),
                  Text(
                    context.t('تحليل بالذكاء الاصطناعي', 'AI-powered analysis'),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
                if (report.note != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    report.note!,
                    style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (report.strengths.isNotEmpty) ...[
          const SizedBox(height: 12),
          _sectionTitle(
            context.t('نقاط قوة', 'Strengths'),
            Icons.thumb_up_outlined,
            Colors.green,
          ),
          ...report.strengths.map(
            (s) => _bulletCard(s, Colors.green.withValues(alpha: 0.08)),
          ),
        ],
        if (report.issues.isNotEmpty) ...[
          const SizedBox(height: 12),
          _sectionTitle(
            context.t(
              'ملاحظات (${report.issues.length})',
              'Issues (${report.issues.length})',
            ),
            Icons.warning_amber_rounded,
            Colors.orange,
          ),
          ...report.issues.map(_issueCard),
        ],
        if (report.recommendations.isNotEmpty) ...[
          const SizedBox(height: 12),
          _sectionTitle(
            context.t('توصيات', 'Recommendations'),
            Icons.lightbulb_outline,
            _brand,
          ),
          ...report.recommendations.map(
            (r) => _bulletCard(r, _brand.withValues(alpha: 0.06)),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          context.t(
            'تنبيه: هذه أداة مساعدة للتحضير وليست بديلاً عن مراجعة المشرف أو لجنة الجودة.',
            'Note: This is a preparation aid, not a substitute for supervisor or quality committee review.',
          ),
          style: TextStyle(fontSize: 11, color: Colors.grey[600], height: 1.4),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _sectionTitle(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _bulletCard(String text, Color bg) {
    return Card(
      color: bg,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(text, style: const TextStyle(height: 1.45)),
      ),
    );
  }

  Widget _issueCard(IntegrityIssue issue) {
    final color = switch (issue.severity) {
      IntegritySeverity.high => Colors.red,
      IntegritySeverity.medium => Colors.orange,
      IntegritySeverity.low => Colors.blueGrey,
    };
    final label = switch (issue.severity) {
      IntegritySeverity.high => context.t('عالية', 'High'),
      IntegritySeverity.medium => context.t('متوسطة', 'Medium'),
      IntegritySeverity.low => context.t('منخفضة', 'Low'),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    issue.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(issue.description, style: const TextStyle(height: 1.45)),
            if (issue.suggestion.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                context.t('اقتراح:', 'Suggestion:'),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                  fontSize: 13,
                ),
              ),
              Text(
                issue.suggestion,
                style: TextStyle(height: 1.45, color: Colors.grey[800]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
