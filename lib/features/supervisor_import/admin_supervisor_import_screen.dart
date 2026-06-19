import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../academic/faculty_categories.dart';
import '../auth/user_account_service.dart';
import 'csv_supervisor_parser.dart';
import 'import_models.dart';
import 'openalex_client.dart';
import 'supervisor_import_service.dart';

class AdminSupervisorImportScreen extends StatefulWidget {
  const AdminSupervisorImportScreen({super.key});

  @override
  State<AdminSupervisorImportScreen> createState() =>
      _AdminSupervisorImportScreenState();
}

class _AdminSupervisorImportScreenState extends State<AdminSupervisorImportScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _claimingAdmin = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('استيراد المشرفين'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.table_chart_outlined), text: 'CSV / Excel'),
            Tab(icon: Icon(Icons.travel_explore), text: 'OpenAlex'),
          ],
        ),
      ),
      body: StreamBuilder(
        stream: UserAccountService.instance.watchCurrentAccount(),
        builder: (context, snapshot) {
          final account = snapshot.data;
          final isAdmin = account?.isAdmin == true;

          return Column(
            children: [
              if (!isAdmin)
                _AdminAccessBanner(
                  claiming: _claimingAdmin,
                  onClaimAdmin: () async {
                    setState(() => _claimingAdmin = true);
                    try {
                      final ok =
                          await UserAccountService.instance.tryClaimDevAdmin();
                      if (!context.mounted) return;
                      if (ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم تفعيل صلاحية المدير'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'فعّل allowBootstrap في Firebase: config/app',
                            ),
                            backgroundColor: Colors.orange,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _claimingAdmin = false);
                    }
                  },
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _CsvImportTab(isAdmin: isAdmin),
                    _OpenAlexImportTab(isAdmin: isAdmin),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AdminAccessBanner extends StatelessWidget {
  final bool claiming;
  final VoidCallback onClaimAdmin;

  const _AdminAccessBanner({
    required this.claiming,
    required this.onClaimAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'لوحة الإدارة تظهر فقط لحساب «مدير».',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'يمكنك الاستيراد الآن (يُرسل للمراجعة). '
            'لتفعيل المدير اضغط الزر أدناه — يُنشئ الإعداد تلقائياً.',
            style: TextStyle(fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: claiming ? null : onClaimAdmin,
            icon: claiming
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.admin_panel_settings_outlined, size: 18),
            label: const Text('تفعيل مدير (تطوير)'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange[800],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _CsvImportTab extends StatefulWidget {
  final bool isAdmin;

  const _CsvImportTab({required this.isAdmin});

  @override
  State<_CsvImportTab> createState() => _CsvImportTabState();
}

class _CsvImportTabState extends State<_CsvImportTab> {
  List<CsvSupervisorRow> _preview = [];
  String? _fileName;
  late bool _autoApprove;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _autoApprove = widget.isAdmin;
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      _showMessage('تعذر قراءة الملف', isError: true);
      return;
    }

    try {
      final content = utf8.decode(bytes);
      final rows = CsvSupervisorParser.parse(content);
      setState(() {
        _preview = rows;
        _fileName = file.name;
      });
    } catch (error) {
      _showMessage('$error', isError: true);
    }
  }

  Future<void> _import() async {
    if (_preview.isEmpty) return;

    setState(() => _isImporting = true);
    try {
      final result = await SupervisorImportService.instance.importCsvRows(
        rows: _preview,
        autoApprove: _autoApprove,
      );
      if (!mounted) return;
      _showMessage(
        'تم استيراد ${result.imported} مشرف'
        '${result.skipped > 0 ? ' — تخطي ${result.skipped}' : ''}',
      );
      setState(() => _preview = []);
      _fileName = null;
    } catch (error) {
      if (!mounted) return;
      _showMessage('$error', isError: true);
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _infoCard(
          'ارفع ملف CSV يحتوي أعمدة: name, university, speciality, bio, faculty, category, tags, orcid...',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('اختيار ملف CSV'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'نسخ نموذج CSV',
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(text: CsvSupervisorParser.templateCsv()),
                );
                _showMessage('تم نسخ نموذج CSV');
              },
              icon: const Icon(Icons.copy),
            ),
          ],
        ),
        if (_fileName != null) ...[
          const SizedBox(height: 8),
          Text('الملف: $_fileName — ${_preview.length} صف'),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('موافقة تلقائية (Admin)'),
          subtitle: Text(
            widget.isAdmin
                ? 'يظهر المشرفون فوراً بدون مراجعة'
                : 'متاح للمدير فقط — سيُرسل للمراجعة',
          ),
          value: _autoApprove,
          onChanged: widget.isAdmin ? (v) => setState(() => _autoApprove = v) : null,
        ),
        if (_preview.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'معاينة',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ..._preview.take(8).map(
                (row) => Card(
                  child: ListTile(
                    title: Text(row.name),
                    subtitle: Text(
                      '${row.university}\n${row.speciality}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Chip(label: Text(row.category)),
                  ),
                ),
              ),
          if (_preview.length > 8)
            Text(
              '... و ${_preview.length - 8} صف إضافي',
              style: TextStyle(color: Colors.grey[600]),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _isImporting ? null : _import,
              icon: _isImporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload),
              label: Text('استيراد ${_preview.length} مشرف'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _OpenAlexImportTab extends StatefulWidget {
  final bool isAdmin;

  const _OpenAlexImportTab({required this.isAdmin});

  @override
  State<_OpenAlexImportTab> createState() => _OpenAlexImportTabState();
}

class _OpenAlexImportTabState extends State<_OpenAlexImportTab> {
  final _universityController = TextEditingController();
  final _professorController = TextEditingController();
  List<OpenAlexInstitution> _institutions = [];
  OpenAlexInstitution? _selectedInstitution;
  List<OpenAlexAuthor> _authors = [];
  final Set<String> _selectedAuthorIds = {};
  String _selectedFacultyId = facultyCategories.first.id;
  bool _searchingUniversity = false;
  bool _searchingProfessor = false;
  bool _loadingAuthors = false;
  bool _importing = false;
  bool _limitToSelectedUniversity = true;
  bool _directProfessorSearch = false;
  late bool _autoApprove;

  @override
  void initState() {
    super.initState();
    _autoApprove = widget.isAdmin;
  }

  @override
  void dispose() {
    _universityController.dispose();
    _professorController.dispose();
    super.dispose();
  }

  Future<void> _searchInstitutions() async {
    final query = _universityController.text.trim();
    if (query.length < 2) return;

    setState(() {
      _searchingUniversity = true;
      _institutions = [];
      _selectedInstitution = null;
      _authors = [];
      _selectedAuthorIds.clear();
      _directProfessorSearch = false;
    });

    try {
      final results = await OpenAlexClient.instance.searchInstitutions(query);
      if (!mounted) return;
      setState(() => _institutions = results);
    } catch (error) {
      if (!mounted) return;
      _showMessage('$error', isError: true);
    } finally {
      if (mounted) setState(() => _searchingUniversity = false);
    }
  }

  Future<void> _searchProfessor() async {
    final query = _professorController.text.trim();
    if (query.length < 2) {
      _showMessage('اكتب اسم الدكتور (حرفين على الأقل)', isError: true);
      return;
    }

    final institutionId = _limitToSelectedUniversity && _selectedInstitution != null
        ? _selectedInstitution!.id
        : null;

    setState(() {
      _searchingProfessor = true;
      _authors = [];
      _selectedAuthorIds.clear();
      _directProfessorSearch = true;
    });

    try {
      final authors = await OpenAlexClient.instance.searchAuthors(
        query: query,
        institutionId: institutionId,
      );
      if (!mounted) return;
      setState(() => _authors = authors);
      if (authors.isEmpty) {
        _showMessage('لم يُعثر على نتائج — جرّب الاسم بالإنجليزية أو ORCID', isError: true);
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage('$error', isError: true);
    } finally {
      if (mounted) setState(() => _searchingProfessor = false);
    }
  }

  Future<void> _loadAuthors(OpenAlexInstitution institution) async {
    setState(() {
      _selectedInstitution = institution;
      _loadingAuthors = true;
      _authors = [];
      _selectedAuthorIds.clear();
      _directProfessorSearch = false;
    });

    try {
      final authors = await OpenAlexClient.instance.fetchAuthorsForInstitution(
        institutionId: institution.id,
      );
      if (!mounted) return;
      setState(() => _authors = authors);
    } catch (error) {
      if (!mounted) return;
      _showMessage('$error', isError: true);
    } finally {
      if (mounted) setState(() => _loadingAuthors = false);
    }
  }

  Future<void> _importSelected() async {
    final selected = _authors
        .where((author) => _selectedAuthorIds.contains(author.id))
        .toList();
    if (selected.isEmpty) return;

    setState(() => _importing = true);
    try {
      final result =
          await SupervisorImportService.instance.importOpenAlexAuthors(
        authors: selected,
        category: _selectedFacultyId,
        faculty: facultyTitleForCategory(_selectedFacultyId),
        autoApprove: _autoApprove,
      );
      if (!mounted) return;
      _showMessage(
        'تم استيراد ${result.imported} باحث'
        '${result.skipped > 0 ? ' — تخطي ${result.skipped}' : ''}',
      );
      setState(() => _selectedAuthorIds.clear());
    } catch (error) {
      if (!mounted) return;
      _showMessage('$error', isError: true);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _infoCard(
          'ابحث عن جامعة (اختياري) ثم ابحث عن دكتور بعينه بالاسم. '
          'يمكنك أيضاً لصق ORCID. المصدر: OpenAlex.',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.teal.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.teal.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.person_search, color: Colors.teal, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'بحث عن دكتور بعينه',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _professorController,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  labelText: 'اسم الدكتور / الباحث',
                  hintText: 'Ahmed Hassan, Mohamed Ali, ORCID...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onSubmitted: (_) => _searchProfessor(),
              ),
              if (_selectedInstitution != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('البحث داخل الجامعة المختارة فقط'),
                  subtitle: Text(_selectedInstitution!.name),
                  value: _limitToSelectedUniversity,
                  onChanged: (v) => setState(() => _limitToSelectedUniversity = v),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _searchingProfessor ? null : _searchProfessor,
                icon: _searchingProfessor
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_search),
                label: const Text('بحث عن الدكتور'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.teal[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'أو: ابحث عن الجامعة أولاً',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _universityController,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  labelText: 'اسم الجامعة (اختياري)',
                  hintText: 'Cairo University, جامعة القاهرة...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onSubmitted: (_) => _searchInstitutions(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _searchingUniversity ? null : _searchInstitutions,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              ),
              child: _searchingUniversity
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
            ),
          ],
        ),
        if (_institutions.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'اختر المؤسسة',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._institutions.map(
            (institution) => Card(
              color: _selectedInstitution?.id == institution.id
                  ? const Color(0xFF1A237E).withValues(alpha: 0.08)
                  : null,
              child: ListTile(
                title: Text(institution.name),
                subtitle: Text(
                  '${institution.country ?? '—'} • ${institution.worksCount} منشور',
                ),
                trailing: TextButton(
                  onPressed: () => _loadAuthors(institution),
                  child: const Text('الكل'),
                ),
                onTap: () {
                  setState(() => _selectedInstitution = institution);
                },
              ),
            ),
          ),
        ],
        if (_loadingAuthors)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_authors.isNotEmpty) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey(_selectedFacultyId),
            initialValue: _selectedFacultyId,
            decoration: InputDecoration(
              labelText: 'الكلية في AcadeGate',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: facultyCategories
                .map(
                  (faculty) => DropdownMenuItem(
                    value: faculty.id,
                    child: Text(faculty.titleAr),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _selectedFacultyId = v);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('موافقة تلقائية'),
            value: _autoApprove,
            onChanged:
                widget.isAdmin ? (v) => setState(() => _autoApprove = v) : null,
          ),
          Row(
            children: [
              Text(
                _directProfessorSearch
                    ? '${_authors.length} نتيجة بحث — محدد ${_selectedAuthorIds.length}'
                    : '${_authors.length} باحث — محدد ${_selectedAuthorIds.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (!_directProfessorSearch)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedAuthorIds
                        ..clear()
                        ..addAll(_authors.map((a) => a.id));
                    });
                  },
                  child: const Text('تحديد الكل'),
                ),
            ],
          ),
          ..._authors.map(
                (author) => CheckboxListTile(
                  value: _selectedAuthorIds.contains(author.id),
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        _selectedAuthorIds.add(author.id);
                      } else {
                        _selectedAuthorIds.remove(author.id);
                      }
                    });
                  },
                  title: Text(author.name),
                  subtitle: Text(
                    '${author.institutionName.isNotEmpty ? author.institutionName : '—'}\n'
                    '${author.speciality} • ${author.worksCount} منشور',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  secondary: author.orcid != null
                      ? const Icon(Icons.verified_outlined, size: 18)
                      : null,
                ),
              ),
          if (!_directProfessorSearch && _authors.length > 100)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'قائمة كاملة ${_authors.length} باحث — استخدم «بحث عن دكتور» للتضييق',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _importing || _selectedAuthorIds.isEmpty
                  ? null
                  : _importSelected,
              icon: _importing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: Text('استيراد ${_selectedAuthorIds.length} باحث'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

Widget _infoCard(String text) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF1A237E).withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF1A237E).withValues(alpha: 0.15)),
    ),
    child: Text(text, style: const TextStyle(height: 1.4, fontSize: 13)),
  );
}
