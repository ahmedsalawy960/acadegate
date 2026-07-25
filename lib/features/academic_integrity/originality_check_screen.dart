import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale/locale_extensions.dart';
import '../auth/auth_guard.dart';
import '../research_journey/thesis_progress.dart';
import '../research_journey/thesis_progress_activity.dart';
import 'originality_check_models.dart';
import 'originality_check_service.dart';

class OriginalityCheckScreen extends StatefulWidget {
  const OriginalityCheckScreen({super.key});

  @override
  State<OriginalityCheckScreen> createState() => _OriginalityCheckScreenState();
}

class _OriginalityCheckScreenState extends State<OriginalityCheckScreen> {
  static const _brand = Color(0xFF6A1B9A);

  final _service = OriginalityCheckService.instance;
  final _controller = TextEditingController();

  OriginalityProvider _provider = OriginalityProvider.auto;
  bool _loading = false;
  String? _fileName;
  List<int>? _fileBytes;
  int? _fileSizeBytes;
  OriginalityCheckReport? _report;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final picked = await _service.pickDocument();
      if (picked == null || !mounted) return;
      setState(() {
        _fileBytes = picked.bytes;
        _fileName = picked.name;
        _fileSizeBytes = picked.sizeBytes;
        _report = null;
        if (picked.extractedTextPreview != null &&
            picked.extractedTextPreview!.isNotEmpty) {
          _controller.text = picked.extractedTextPreview!;
        }
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'تم رفع الملف: ${picked.name} (${picked.sizeLabel})',
              'File ready: ${picked.name} (${picked.sizeLabel})',
            ),
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  void _clearFile() {
    setState(() {
      _fileBytes = null;
      _fileName = null;
      _fileSizeBytes = null;
    });
  }

  String? _fileSizeLabel() {
    final size = _fileSizeBytes;
    if (size == null) return null;
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _runCheck() async {
    final loggedIn = await ensureLoggedIn(context);
    if (!loggedIn || !mounted) return;

    setState(() {
      _loading = true;
      _report = null;
    });

    try {
      final report = await _service.check(
        provider: _provider,
        text: _controller.text,
        fileBytes: _fileBytes,
        fileName: _fileName,
      );
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
      });
      await ThesisProgressService.instance.recordActivity(
        ThesisActivityId.originalityCheck.name,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Color _scoreColor(double percent) {
    if (percent < 15) return Colors.green.shade700;
    if (percent < 30) return Colors.orange.shade800;
    return Colors.red.shade700;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(
          context.t('فاحص التشابه', 'Similarity checker'),
        ),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _warningCard(),
          const SizedBox(height: 16),
          _providerCard(),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            minLines: 6,
            maxLines: 14,
            decoration: InputDecoration(
              labelText: context.t('نص البحث', 'Document text'),
              hintText: context.t(
                'الصق فصلاً أو مقطعاً للفحص...\n'
                'PlagiarismCheck يتطلب 80+ حرفاً (إنجليزي حالياً)',
                'Paste a chapter or excerpt to scan...\n'
                'PlagiarismCheck needs 80+ chars (English only for now)',
              ),
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (_fileName != null) ...[
            Card(
              color: Colors.green.shade50,
              child: ListTile(
                leading: Icon(Icons.insert_drive_file, color: Colors.green.shade800),
                title: Text(
                  _fileName!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  context.t(
                    'جاهز للفحص${_fileSizeLabel() != null ? ' · ${_fileSizeLabel()}' : ''}',
                    'Ready to scan${_fileSizeLabel() != null ? ' · ${_fileSizeLabel()}' : ''}',
                  ),
                ),
                trailing: _loading
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _clearFile,
                        tooltip: context.t('إزالة الملف', 'Remove file'),
                      ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _loading ? null : _pickFile,
                icon: const Icon(Icons.upload_file),
                label: Text(
                  _fileName == null
                      ? context.t('رفع ملف', 'Upload file')
                      : context.t('تغيير الملف', 'Change file'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.t(
              'PDF · DOCX · DOC · TXT — حتى ${OriginalityCheckService.maxSizeMb} ميجابايت · Copyleaks يدعم العربية',
              'PDF · DOCX · DOC · TXT — up to ${OriginalityCheckService.maxSizeMb} MB · Copyleaks supports Arabic',
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
                  ? context.t(
                      'جاري الفحص — قد يستغرق دقائق...',
                      'Scanning — may take a few minutes...',
                    )
                  : context.t('فحص التشابه', 'Run similarity check'),
            ),
          ),
          if (_report != null) ...[
            const SizedBox(height: 24),
            _reportCard(_report!),
          ],
        ],
      ),
    );
  }

  Widget _warningCard() {
    return Card(
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
                  'أداة تحضيرية — ليست Turnitin رسمياً.\n'
                  'Copyleaks و PlagiarismCheck مدفوعان — يتطلبان رصيداً في حسابك.',
                  'Preparation tool — not official Turnitin.\n'
                  'Copyleaks & PlagiarismCheck are paid — require credits in your account.',
                ),
                style: TextStyle(
                  height: 1.45,
                  color: Colors.amber.shade900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _providerCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('مزود الفحص', 'Scan provider'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: OriginalityProvider.values.map((option) {
                final selected = _provider == option;
                final label = switch (option) {
                  OriginalityProvider.auto => context.t('تلقائي', 'Auto'),
                  OriginalityProvider.copyleaks => 'Copyleaks',
                  OriginalityProvider.plagiarismCheck => 'PlagiarismCheck',
                };
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: _loading
                      ? null
                      : (_) => setState(() => _provider = option),
                );
              }).toList(),
            ),
            if (_provider == OriginalityProvider.plagiarismCheck) ...[
              const SizedBox(height: 8),
              Text(
                context.t(
                  'PlagiarismCheck: يُستخرج النص من الملف (DOCX/PDF/TXT) — الإنجليزية مدعومة رسمياً',
                  'PlagiarismCheck: text is extracted from files (DOCX/PDF/TXT) — English officially supported',
                ),
                style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _reportCard(OriginalityCheckReport report) {
    final scoreColor = _scoreColor(report.similarityPercent);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics_outlined, color: scoreColor, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.t('نتيجة التشابه', 'Similarity result'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${report.similarityPercent.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: scoreColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${report.providerLabel}'
              '${report.totalWords != null ? ' · ${report.totalWords} ${context.t('كلمة', 'words')}' : ''}'
              '${report.sourceCount > 0 ? ' · ${report.sourceCount} ${context.t('مصدر', 'sources')}' : ''}',
              style: TextStyle(color: Colors.grey[700]),
            ),
            if (report.sources.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                context.t('المصادر المطابقة', 'Matching sources'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...report.sources.map((source) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.link, size: 20),
                  title: Text(
                    source.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: source.url.isNotEmpty ? Text(source.url) : null,
                  trailing: source.percent != null
                      ? Text('${source.percent!.toStringAsFixed(0)}%')
                      : (source.matchedWords != null
                          ? Text('${source.matchedWords}w')
                          : null),
                  onTap: source.url.isNotEmpty
                      ? () => _openUrl(source.url)
                      : null,
                );
              }),
            ] else ...[
              const SizedBox(height: 12),
              Text(
                context.t(
                  'لم تُكتشف مصادر مطابقة واضحة',
                  'No clear matching sources detected',
                ),
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
