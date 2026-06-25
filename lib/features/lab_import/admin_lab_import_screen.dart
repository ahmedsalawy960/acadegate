import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/user_account_service.dart';
import '../../seed_data/import_package_paths.dart';
import 'csv_lab_parser.dart';
import 'lab_import_service.dart';

class AdminLabImportScreen extends StatefulWidget {
  const AdminLabImportScreen({super.key});

  @override
  State<AdminLabImportScreen> createState() => _AdminLabImportScreenState();
}

class _AdminLabImportScreenState extends State<AdminLabImportScreen> {
  List<CsvLabRow> _preview = [];
  bool _importing = false;
  String? _fileName;

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
      const SnackBar(content: Text('تم نسخ قالب CSV — الصقه في Excel أو محرر نصوص')),
    );
  }

  Future<void> _loadEgyptStarterPackage() async {
    try {
      final content =
          await rootBundle.loadString(ImportPackagePaths.labsEgyptStarter);
      final rows = CsvLabParser.parse(content);
      if (!mounted) return;
      setState(() {
        _preview = rows;
        _fileName = 'حزمة مصر الجاهزة (${rows.length} مختبر)';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تحميل ${rows.length} مختبراً نموذجياً — راجع البيانات ثم استورد',
          ),
          backgroundColor: Colors.green[700],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تحميل الحزمة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _import({required bool autoApprove}) async {
    if (_preview.isEmpty) return;
    setState(() => _importing = true);
    try {
      final result = await LabImportService.instance.importRows(
        rows: _preview,
        autoApprove: autoApprove,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم استيراد ${result.imported} مختبر/مركز — تخطي ${result.skipped}'
            '${result.errors.isNotEmpty ? '\nأخطاء: ${result.errors.length}' : ''}',
          ),
          backgroundColor: Colors.green[700],
        ),
      );
      if (result.imported > 0) {
        setState(() {
          _preview = [];
          _fileName = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('استيراد مختبرات ومراكز بحوث'),
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
                color: Colors.purple[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'أضف مختبرات ومراكز بحوث حقيقية',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: Colors.purple[900],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'حمّل ملف CSV أو استخدم «حزمة مصر الجاهزة» (18 مختبراً نموذجياً). '
                        'القوالب الكاملة في مجلد seed_data في المشروع.',
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
                    onPressed: _pickCsv,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('اختيار ملف CSV'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _copyTemplate,
                    icon: const Icon(Icons.copy),
                    label: const Text('نسخ قالب CSV'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loadEgyptStarterPackage,
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('حزمة مصر الجاهزة'),
                  ),
                ],
              ),
              if (_fileName != null) ...[
                const SizedBox(height: 12),
                Text('الملف: $_fileName • ${_preview.length} سجل'),
              ],
              if (_preview.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'معاينة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ..._preview.take(20).map(
                      (row) => Card(
                        child: ListTile(
                          title: Text(row.name),
                          subtitle: Text(
                            [
                              row.labType,
                              row.university,
                              row.city,
                              if (row.sampleServices.isNotEmpty)
                                row.sampleServices.join('، '),
                            ].where((part) => part.isNotEmpty).join(' • '),
                          ),
                        ),
                      ),
                    ),
                if (_preview.length > 20)
                  Text('... و ${_preview.length - 20} سجل آخر'),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _importing
                      ? null
                      : () => _import(autoApprove: isAdmin),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.purple[700],
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: _importing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.cloud_upload),
                  label: Text(
                    isAdmin
                        ? 'استيراد ونشر (${_preview.length})'
                        : 'إرسال للمراجعة (${_preview.length})',
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
