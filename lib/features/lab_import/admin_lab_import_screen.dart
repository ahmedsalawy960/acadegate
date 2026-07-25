import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale/locale_extensions.dart';
import '../auth/user_account_service.dart';
import 'crci_catalog.dart';
import 'csv_lab_parser.dart';
import 'lab_import_service.dart';
import 'nbsle_client.dart';

class AdminLabImportScreen extends StatefulWidget {
  const AdminLabImportScreen({super.key});

  /// Official Egyptian labs registry (Supreme Council of Universities).
  static final Uri nbsleBrowseUri = Uri.parse('https://nbsle.scu.eg/browse');

  @override
  State<AdminLabImportScreen> createState() => _AdminLabImportScreenState();
}

class _AdminLabImportScreenState extends State<AdminLabImportScreen> {
  List<CsvLabRow> _preview = [];
  bool _importing = false;
  bool _scraping = false;
  bool _cancelScrape = false;
  NbsleScrapeProgress? _scrapeProgress;
  String? _fileName;
  DateTime? _lastNbsleSyncAt;
  DateTime? _lastCrciSyncAt;
  String? _lastError;
  bool _importingCrci = false;

  bool get _previewIsNbsle =>
      _preview.isNotEmpty &&
      _preview.any(
        (r) => r.importSource == 'nbsle' || r.externalId.trim().isNotEmpty,
      );

  Future<void> _showErrorDialog(String message) async {
    if (!mounted) return;
    setState(() => _lastError = message);
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('حدث خطأ', 'Error')),
        content: SingleChildScrollView(
          child: SelectableText(message),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: message));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(context.t('نسخ', 'Copy')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t('حسناً', 'OK')),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadLastSync();
  }

  Future<void> _loadLastSync() async {
    final nbsleAt = await LabImportService.instance.loadLastNbsleSyncAt();
    final crciAt = await LabImportService.instance.loadLastCrciSyncAt();
    if (!mounted) return;
    setState(() {
      _lastNbsleSyncAt = nbsleAt;
      _lastCrciSyncAt = crciAt;
    });
  }

  Future<void> _importCrciCenters({required bool syncAfter}) async {
    final rows = CrciCatalog.toCsvRows();
    setState(() {
      _preview = rows;
      _fileName = 'CRCI centers (${rows.length})';
      _lastError = null;
    });
    if (!syncAfter) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'معاينة ${rows.length} مركزاً قومياً من CRCI',
              'Preview ${rows.length} CRCI national centers',
            ),
          ),
        ),
      );
      return;
    }

    setState(() => _importingCrci = true);
    try {
      final result = await LabImportService.instance.importRows(
        rows: rows,
        autoApprove: true,
        syncExisting: true,
      );
      if (!mounted) return;
      await _loadLastSync();
      if (!mounted) return;
      final summary = context.t(
        'CRCI: أُضيف ${result.imported} · حُدّث ${result.updated} · تُخطي ${result.skipped}',
        'CRCI: added ${result.imported} · updated ${result.updated} · skipped ${result.skipped}',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(summary),
          backgroundColor: Colors.indigo[700],
        ),
      );
      setState(() {
        _preview = [];
        _fileName = null;
      });
    } catch (e) {
      if (!mounted) return;
      await _showErrorDialog('$e');
    } finally {
      if (mounted) setState(() => _importingCrci = false);
    }
  }

  Future<void> _openCrci() async {
    final uri = Uri.parse(CrciCatalog.directoryUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _scrapeNbsle({bool syncAfter = false}) async {
    if (_scraping || _importing) return;
    setState(() {
      _scraping = true;
      _cancelScrape = false;
      _scrapeProgress = null;
      _fileName = null;
      _lastError = null;
    });

    try {
      final rows = await NbsleClient.instance.scrapeLabs(
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _scrapeProgress = progress);
        },
        shouldCancel: () => _cancelScrape,
      );
      if (!mounted) return;
      setState(() {
        _preview = rows;
        _fileName = 'NBSLE all-devices (${rows.length} labs)';
        _scraping = false;
        _scrapeProgress = null;
      });

      if (syncAfter) {
        final account =
            await UserAccountService.instance.loadCurrentAccount();
        await _import(
          autoApprove: account?.isAdmin == true,
          syncExisting: true,
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text(
            context.t(
              'تم استخراج ${rows.length} مختبراً — راجع ثم اضغط مزامنة/استيراد',
              'Extracted ${rows.length} labs — review then sync/import',
            ),
          ),
          backgroundColor: Colors.teal[700],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final cancelled = e.toString().contains('cancelled');
      setState(() {
        _scraping = false;
        _scrapeProgress = null;
      });
      if (cancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 4),
            content: Text(context.t('تم إلغاء الاستخراج', 'Scrape cancelled')),
            backgroundColor: Colors.orange[800],
          ),
        );
      } else {
        await _showErrorDialog('$e');
      }
    }
  }

  Future<void> _pickCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    try {
      final content = utf8.decode(bytes);
      final rows = CsvLabParser.parse(content);
      setState(() {
        _preview = rows;
        _fileName = file.name;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _copyTemplate() async {
    await Clipboard.setData(ClipboardData(text: CsvLabParser.templateCsv()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t(
            'تم نسخ قالب CSV — الصقه في Excel واملأه من بيانات NBSLE',
            'CSV template copied — paste into Excel and fill from NBSLE data',
          ),
        ),
      ),
    );
  }

  Future<void> _openNbsle() async {
    final uri = AdminLabImportScreen.nbsleBrowseUri;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'تعذر فتح الرابط — انسخه يدوياً: ${uri.toString()}',
              'Could not open link — copy manually: ${uri.toString()}',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _copyNbsleLink() async {
    final link = AdminLabImportScreen.nbsleBrowseUri.toString();
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t('تم نسخ رابط NBSLE', 'NBSLE link copied'),
        ),
      ),
    );
  }

  Future<void> _import({
    required bool autoApprove,
    bool? syncExisting,
  }) async {
    if (_preview.isEmpty) return;
    final sync = syncExisting ?? _previewIsNbsle;
    setState(() {
      _importing = true;
      _lastError = null;
    });
    try {
      final result = await LabImportService.instance.importRows(
        rows: _preview,
        autoApprove: autoApprove,
        syncExisting: sync,
      );
      if (!mounted) return;
      await _loadLastSync();
      if (!mounted) return;

      final summary = context.t(
        'جديد: ${result.imported} — محدّث: ${result.updated} — متخطى: ${result.skipped}',
        'New: ${result.imported} — updated: ${result.updated} — skipped: ${result.skipped}',
      );

      if (result.errors.isNotEmpty) {
        await _showErrorDialog(
          '$summary\n\n'
          '${context.t('تفاصيل الأخطاء:', 'Error details:')}\n'
          '${result.errors.take(8).join('\n')}',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 8),
            content: Text(summary),
            backgroundColor: Colors.green[700],
          ),
        );
      }

      if (result.imported > 0 || result.updated > 0) {
        setState(() {
          _preview = [];
          _fileName = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      await _showErrorDialog('$e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(
          context.t(
            'استيراد مختبرات ومراكز بحوث',
            'Import labs & research centers',
          ),
        ),
        backgroundColor: Colors.purple[800],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder(
        stream: UserAccountService.instance.watchCurrentAccount(),
        builder: (context, snapshot) {
          final isAdmin = snapshot.data?.isAdmin == true;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: Colors.teal.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.account_balance_outlined,
                              color: Colors.teal[800]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              context.t(
                                'السجل الرسمي: البنك القومي للمعامل (NBSLE)',
                                'Official registry: National Labs Bank (NBSLE)',
                              ),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.teal[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.t(
                          'لا يوجد بث مباشر من NBSLE. أعد الاستخراج/المزامنة عند الحاجة — '
                          'يُحدَّث الموجود ويُضاف الجديد دون حذف يدوي. الأسعار التي عدّلتها يدوياً تُحفظ. '
                          'الاستخراج قد يستغرق دقائق (غير متاح على الويب).',
                          'No live feed from NBSLE. Re-run extract/sync when needed — '
                          'existing labs update and new ones are added; no manual delete. '
                          'Prices you edited are kept. Extraction may take minutes (not on web).',
                        ),
                        style: const TextStyle(height: 1.4),
                      ),
                      if (_lastNbsleSyncAt != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          context.t(
                            'آخر مزامنة: ${_formatSyncAt(_lastNbsleSyncAt!)}',
                            'Last sync: ${_formatSyncAt(_lastNbsleSyncAt!)}',
                          ),
                          style: TextStyle(
                            color: Colors.teal[800],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (_lastError != null) ...[
                        const SizedBox(height: 10),
                        Material(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.error_outline,
                                        color: Colors.red[800]),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        context.t(
                                          'آخر خطأ (اضغط لنسخه)',
                                          'Last error (tap to copy)',
                                        ),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red[900],
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: context.t('إغلاق', 'Dismiss'),
                                      onPressed: () =>
                                          setState(() => _lastError = null),
                                      icon: const Icon(Icons.close, size: 18),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                InkWell(
                                  onTap: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: _lastError!),
                                    );
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          context.t('تم نسخ الخطأ', 'Error copied'),
                                        ),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    _lastError!,
                                    style: TextStyle(
                                      color: Colors.red[900],
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (_scraping) ...[
                        LinearProgressIndicator(
                          value: _scrapeProgress?.fraction,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.t(
                            'جاري الاستخراج… صفحة ${_scrapeProgress?.page ?? 0}'
                            '/${_scrapeProgress?.totalPages ?? '?'}'
                            ' — أجهزة ${_scrapeProgress?.devicesSeen ?? 0}'
                            ' — مختبرات ≈ ${_scrapeProgress?.labsSoFar ?? 0}',
                            'Extracting… page ${_scrapeProgress?.page ?? 0}'
                            '/${_scrapeProgress?.totalPages ?? '?'}'
                            ' — devices ${_scrapeProgress?.devicesSeen ?? 0}'
                            ' — labs ≈ ${_scrapeProgress?.labsSoFar ?? 0}',
                          ),
                          style:
                              TextStyle(color: Colors.teal[900], height: 1.35),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _scraping || _importing
                                ? null
                                : () => _scrapeNbsle(syncAfter: true),
                            icon: _scraping || _importing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.sync),
                            label: Text(context.t(
                              'استخراج ومزامنة الآن',
                              'Extract & sync now',
                            )),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.teal[700],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _scraping || _importing
                                ? null
                                : () => _scrapeNbsle(syncAfter: false),
                            icon: const Icon(Icons.cloud_download_outlined),
                            label: Text(context.t(
                              'استخراج للمعاينة فقط',
                              'Extract for preview only',
                            )),
                          ),
                          if (_scraping)
                            OutlinedButton.icon(
                              onPressed: () =>
                                  setState(() => _cancelScrape = true),
                              icon: const Icon(Icons.close),
                              label: Text(context.t('إلغاء', 'Cancel')),
                            ),
                          OutlinedButton.icon(
                            onPressed: _openNbsle,
                            icon: const Icon(Icons.open_in_new),
                            label: Text(context.t(
                              'فتح سجل NBSLE',
                              'Open NBSLE registry',
                            )),
                          ),
                          OutlinedButton.icon(
                            onPressed: _copyNbsleLink,
                            icon: const Icon(Icons.link),
                            label: Text(context.t(
                              'نسخ الرابط',
                              'Copy link',
                            )),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                color: Colors.indigo.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.apartment_outlined,
                              color: Colors.indigo[800]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              context.t(
                                'المراكز القومية: مجلس CRCI',
                                'National centers: CRCI council',
                              ),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.indigo[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.t(
                          'استيراد خفيف لـ ${CrciCatalog.centers.length} مركزاً/معهداً قومياً '
                          '(ليست أجهزة). تُحفظ كمراكز بحوث بجانب معامل NBSLE مع رابط الموقع.',
                          'Lightweight import of ${CrciCatalog.centers.length} national '
                          'centers/institutes (not devices). Saved as research centers '
                          'alongside NBSLE labs with website links.',
                        ),
                        style: const TextStyle(height: 1.4),
                      ),
                      if (_lastCrciSyncAt != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          context.t(
                            'آخر مزامنة CRCI: ${_formatSyncAt(_lastCrciSyncAt!)}',
                            'Last CRCI sync: ${_formatSyncAt(_lastCrciSyncAt!)}',
                          ),
                          style: TextStyle(
                            color: Colors.indigo[800],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _scraping ||
                                    _importing ||
                                    _importingCrci
                                ? null
                                : () => _importCrciCenters(syncAfter: true),
                            icon: _importingCrci
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.cloud_upload_outlined),
                            label: Text(context.t(
                              'استيراد مراكز CRCI',
                              'Import CRCI centers',
                            )),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.indigo[700],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _scraping ||
                                    _importing ||
                                    _importingCrci
                                ? null
                                : () => _importCrciCenters(syncAfter: false),
                            icon: const Icon(Icons.preview_outlined),
                            label: Text(context.t(
                              'معاينة القائمة',
                              'Preview list',
                            )),
                          ),
                          OutlinedButton.icon(
                            onPressed: _openCrci,
                            icon: const Icon(Icons.open_in_new),
                            label: Text(context.t(
                              'فتح دليل CRCI',
                              'Open CRCI directory',
                            )),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                color: Colors.purple[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t(
                          'أو استيراد يدوي عبر CSV',
                          'Or import manually via CSV',
                        ),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: Colors.purple[900],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.t(
                          'لرفع ملف مخصص أو إضافة أسعار: انسخ القالب واملأ الأجهزة بصيغة SEM:800;XRD:600',
                          'For a custom file or prices: copy the template and use SEM:800;XRD:600',
                        ),
                        style: const TextStyle(height: 1.45),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: _scraping ? null : _pickCsv,
                    icon: const Icon(Icons.upload_file),
                    label: Text(context.t('اختيار ملف CSV', 'Choose CSV file')),
                  ),
                  OutlinedButton.icon(
                    onPressed: _copyTemplate,
                    icon: const Icon(Icons.copy),
                    label: Text(context.t('نسخ قالب CSV', 'Copy CSV template')),
                  ),
                ],
              ),
              if (_fileName != null) ...[
                const SizedBox(height: 12),
                Text(
                  context.t(
                    'الملف: $_fileName • ${_preview.length} سجل',
                    'File: $_fileName • ${_preview.length} records',
                  ),
                ),
              ],
              if (_preview.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  context.t('معاينة', 'Preview'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ..._preview.take(40).map(
                      (row) => Card(
                        child: ListTile(
                          title: Text(row.name),
                          subtitle: Text(
                            [
                              if (row.university.isNotEmpty) row.university,
                              if (row.city.isNotEmpty) row.city,
                              if (row.equipmentNames.isNotEmpty)
                                row.equipmentNames.take(3).join(' · '),
                            ].join(' · '),
                          ),
                        ),
                      ),
                    ),
                if (_preview.length > 40)
                  Text(
                    context.t(
                      '... و${_preview.length - 40} أخرى',
                      '... and ${_preview.length - 40} more',
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _importing || _scraping
                      ? null
                      : () => _import(autoApprove: isAdmin),
                  icon: _importing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_outlined),
                  label: Text(
                    _previewIsNbsle
                        ? context.t(
                            'مزامنة مع التطبيق (تحديث + إضافة)',
                            'Sync to app (update + add)',
                          )
                        : isAdmin
                            ? context.t(
                                'استيراد ونشر مباشرة',
                                'Import and publish now',
                              )
                            : context.t(
                                'استيراد للمراجعة',
                                'Import for review',
                              ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.purple[800],
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  String _formatSyncAt(DateTime at) {
    final local = at.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }
}
