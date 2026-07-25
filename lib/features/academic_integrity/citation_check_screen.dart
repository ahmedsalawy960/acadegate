import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale/locale_extensions.dart';
import '../research_journey/thesis_progress.dart';
import '../research_journey/thesis_progress_activity.dart';
import 'citation_check_service.dart';
import 'citation_models.dart';

class CitationCheckScreen extends StatefulWidget {
  const CitationCheckScreen({super.key});

  @override
  State<CitationCheckScreen> createState() => _CitationCheckScreenState();
}

class _CitationCheckScreenState extends State<CitationCheckScreen> {
  static const _brand = Color(0xFF0D47A1);

  final _service = CitationCheckService.instance;
  final _controller = TextEditingController();
  bool _loading = false;
  CitationCheckReport? _report;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runCheck() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'الصق قائمة المراجع أولاً',
              'Paste your reference list first',
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

    try {
      final report = await _service.checkReferences(text);
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
      });
      if (report.verifiedCount > 0 || report.partialCount > 0) {
        await ThesisProgressService.instance.recordActivity(
          ThesisActivityId.citationCheck.name,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(
          context.t('فاحص المراجع', 'Reference checker'),
        ),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _headerCard(),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            minLines: 8,
            maxLines: 16,
            decoration: InputDecoration(
              labelText: context.t(
                'قائمة المراجع',
                'Reference list',
              ),
              hintText: context.t(
                'الصق المراجع هنا — سطر لكل مرجع أو قسم «المراجع»...\n'
                'DOI يُكتشف تلقائياً: 10.xxxx/...',
                'Paste references here — one per line or a References section...\n'
                'DOIs are detected automatically: 10.xxxx/...',
              ),
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.t(
              'مصادر مجانية: Crossref + OpenAlex + Semantic Scholar (حتى 40 مرجعاً)',
              'Free sources: Crossref + OpenAlex + Semantic Scholar (up to 40 references)',
            ),
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
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
                : const Icon(Icons.fact_check_outlined),
            label: Text(
              _loading
                  ? context.t('جاري التحقق...', 'Checking...')
                  : context.t('تحقق من المراجع', 'Verify references'),
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
                const Icon(Icons.menu_book_outlined, color: _brand),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.t(
                      'فحص المراجع والاستشهادات',
                      'Reference & citation verification',
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _brand,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.t(
                'يتحقق عبر Crossref وOpenAlex وSemantic Scholar — '
                'ليست قاعدة Google Scholar. المراجع بدون DOI أو العربية قد تحتاج بحثاً يدوياً.',
                'Checks via Crossref, OpenAlex, and Semantic Scholar — '
                'not the Google Scholar database. References without DOI or in Arabic may need manual search.',
              ),
              style: const TextStyle(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReport(CitationCheckReport report) {
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
                  context.t('درجة صحة المراجع', 'Reference integrity score'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  '${report.integrityScore}%',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: scoreColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.t(
                    '${report.verifiedCount} مؤكد · ${report.partialCount} تقريبي · '
                    '${report.notFoundCount} غير موجود · ${report.invalidCount} DOI خاطئ',
                    '${report.verifiedCount} verified · ${report.partialCount} partial · '
                    '${report.notFoundCount} not found · ${report.invalidCount} invalid DOI',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...report.items.map(_itemCard),
        Text(
          context.t(
            'أداة مساعدة مجانية — ليست تقرير Turnitin.',
            'Free helper tool — not a Turnitin report.',
          ),
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _itemCard(CitationCheckItem item) {
    final match = item.match;
    final status = match?.status ?? CitationValidationStatus.error;
    final color = switch (status) {
      CitationValidationStatus.verified => Colors.green,
      CitationValidationStatus.partial => Colors.orange,
      CitationValidationStatus.notFound => Colors.red,
      CitationValidationStatus.invalidDoi => Colors.deepOrange,
      CitationValidationStatus.error => Colors.grey,
    };

    final statusLabel = switch (status) {
      CitationValidationStatus.verified => context.t('مؤكد', 'Verified'),
      CitationValidationStatus.partial => context.t('تقريبي', 'Partial'),
      CitationValidationStatus.notFound => context.t('غير موجود', 'Not found'),
      CitationValidationStatus.invalidDoi => context.t('DOI خاطئ', 'Invalid DOI'),
      CitationValidationStatus.error => context.t('خطأ', 'Error'),
    };

    final sourceLabel = switch (match?.source) {
      CitationDataSource.crossref => 'Crossref',
      CitationDataSource.openAlex => 'OpenAlex',
      CitationDataSource.semanticScholar => 'Semantic Scholar',
      null => '',
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
                    statusLabel,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (sourceLabel.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    sourceLabel,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.citation.rawText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey[800], height: 1.4),
            ),
            if (match != null && match.matchedTitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                match.matchedTitle,
                style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4),
              ),
              if (match.matchedAuthors != null) ...[
                const SizedBox(height: 4),
                Text(
                  match.matchedAuthors!,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
              if (match.year != null)
                Text(
                  '${match.year}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
            ],
            if (match?.note != null) ...[
              const SizedBox(height: 4),
              Text(
                match!.note!,
                style: TextStyle(fontSize: 11, color: Colors.orange[800]),
              ),
            ],
            if (match?.url != null) ...[
              const SizedBox(height: 6),
              InkWell(
                onTap: () => launchUrl(Uri.parse(match!.url!)),
                child: Text(
                  context.t('فتح المصدر', 'Open source'),
                  style: const TextStyle(color: _brand, fontSize: 12),
                ),
              ),
            ],
            if (match?.scholarSearchUrl != null) ...[
              const SizedBox(height: 6),
              InkWell(
                onTap: () => launchUrl(
                  Uri.parse(match!.scholarSearchUrl!),
                  mode: LaunchMode.externalApplication,
                ),
                child: Text(
                  context.t(
                    'بحث على Google Scholar',
                    'Search on Google Scholar',
                  ),
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
