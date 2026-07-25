import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import 'package:flutter/services.dart';

import '../academic/faculty_categories.dart';
import '../auth/user_account_service.dart';
import '../admin/admin_moderation_screen.dart';
import '../../core/locale/l10n_lookup.dart';
import '../../core/locale/locale_extensions.dart';
import '../../seed_data/import_package_paths.dart';
import 'csv_supervisor_parser.dart';
import 'import_models.dart';
import 'openalex_client.dart';
import 'openalex_author_preview_card.dart';
import 'openalex_faculty_mapper.dart';
import 'openalex_search_aliases.dart';
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

  Future<void> _showUniversitiesGuide() async {
    try {
      final text =
          await rootBundle.loadString(ImportPackagePaths.universitiesGuide);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            dialogContext.t('جامعات مصر — OpenAlex', 'Egypt universities — OpenAlex'),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 420,
            child: SingleChildScrollView(
              child: SelectableText(
                text,
                style: const TextStyle(fontSize: 13, height: 1.45),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: text));
                Navigator.pop(dialogContext);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.t(
                        'تم نسخ دليل الجامعات',
                        'Universities guide copied',
                      ),
                    ),
                  ),
                );
              },
              child: Text(L10nLookup.copyAll),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(L10nLookup.close),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t('تعذر فتح الدليل: $e', 'Could not open guide: $e'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('استيراد المشرفين', 'Import supervisors')),
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
        actions: [
          IconButton(
            tooltip: context.t('دليل جامعات OpenAlex', 'OpenAlex universities guide'),
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: _showUniversitiesGuide,
          ),
        ],
      ),
      body: StreamBuilder(
        stream: UserAccountService.instance.watchCurrentAccount(),
        builder: (context, snapshot) {
          final account = snapshot.data;
          final isAdmin = account?.isAdmin == true;

          return Column(
            children: [
              if (!isAdmin && kDebugMode)
                _AdminAccessBanner(
                  claiming: _claimingAdmin,
                  onClaimAdmin: () async {
                    setState(() => _claimingAdmin = true);
                    final messenger = ScaffoldMessenger.of(context);
                    final successMsg = context.t(
                      'تم تفعيل صلاحية المدير',
                      'Admin access enabled',
                    );
                    final failMsg = context.t(
                      'فعّل allowBootstrap في Firebase: config/app',
                      'Enable allowBootstrap in Firebase: config/app',
                    );
                    try {
                      final ok = await UserAccountService.instance
                          .tryClaimDevAdmin();
                      if (!mounted) return;
                      if (ok) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(successMsg),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } else {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(failMsg),
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
          Text(
            context.t(
              'لوحة الإدارة تظهر فقط لحساب «مدير».',
              'The admin panel is only visible to admin accounts.',
            ),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            context.t(
              'عيّن دور admin من Firebase Console للمستخدم المناسب. '
              'زر التطوير أدناه يتحقق فقط من صلاحيتك الحالية.',
              'Assign the admin role in Firebase Console for the right user. '
              'The dev button below only checks your current permissions.',
            ),
            style: const TextStyle(fontSize: 12, height: 1.4),
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
            label: Text(context.t('تفعيل مدير (تطوير)', 'Enable admin (dev)')),
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
    _autoApprove = false;
  }

  Future<void> _loadPackageTemplate() async {
    try {
      final content =
          await rootBundle.loadString(ImportPackagePaths.supervisorsTemplate);
      final rows = CsvSupervisorParser.parse(content);
      if (!mounted) return;
      setState(() {
        _preview = rows;
        _fileName = context.t(
          'قالب المشرفين (${rows.length} صف)',
          'Supervisors template (${rows.length} rows)',
        );
      });
      _showMessage(
        context.t(
          'تم تحميل القالب — عدّل البيانات أو استورد للتجربة',
          'Template loaded — edit data or import to test',
        ),
      );
    } catch (error) {
      _showMessage(
        context.t('تعذر تحميل القالب: $error', 'Could not load template: $error'),
        isError: true,
      );
    }
  }

  Future<void> _copyPackageTemplate() async {
    try {
      final content =
          await rootBundle.loadString(ImportPackagePaths.supervisorsTemplate);
      await Clipboard.setData(ClipboardData(text: content));
      if (!mounted) return;
      _showMessage(
        context.t(
          'تم نسخ قالب CSV من حزمة seed_data',
          'CSV template copied from seed_data package',
        ),
      );
    } catch (error) {
      _showMessage(
        context.t('تعذر نسخ القالب: $error', 'Could not copy template: $error'),
        isError: true,
      );
    }
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
      if (!mounted) return;
      _showMessage(
        context.t('تعذر قراءة الملف', 'Could not read file'),
        isError: true,
      );
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
        context.t(
          'تم استيراد ${result.imported} مشرف'
          '${result.skipped > 0 ? ' — تخطي ${result.skipped}' : ''}',
          'Imported ${result.imported} supervisor(s)'
          '${result.skipped > 0 ? ' — skipped ${result.skipped}' : ''}',
        ),
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
          context.t(
            'ارفع ملف CSV أو استخدم «قالب الحزمة» من مجلد seed_data. '
            'الأعمدة: name, university, speciality, bio, faculty, category, tags, orcid...',
            'Upload a CSV or use the package template from seed_data. '
            'Columns: name, university, speciality, bio, faculty, category, tags, orcid...',
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.upload_file),
              label: Text(context.t('اختيار ملف CSV', 'Choose CSV file')),
            ),
            OutlinedButton.icon(
              onPressed: _copyPackageTemplate,
              icon: const Icon(Icons.copy),
              label: Text(context.t('نسخ قالب CSV', 'Copy CSV template')),
            ),
            OutlinedButton.icon(
              onPressed: _loadPackageTemplate,
              icon: const Icon(Icons.inventory_2_outlined),
              label: Text(context.t('قالب الحزمة', 'Package template')),
            ),
          ],
        ),
        if (_fileName != null) ...[
          const SizedBox(height: 8),
          Text(
            context.t(
              'الملف: $_fileName — ${_preview.length} صف',
              'File: $_fileName — ${_preview.length} rows',
            ),
          ),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.t('موافقة تلقائية (Admin)', 'Auto-approve (Admin)')),
          subtitle: Text(
            widget.isAdmin
                ? context.t(
                    'افتراضياً: يذهب للمراجعة. فعّله فقط إذا كنت متأكداً من البيانات.',
                    'Default: sent for review. Enable only if you trust the data.',
                  )
                : context.t(
                    'متاح للمدير فقط — سيُرسل للمراجعة',
                    'Admin only — will be sent for review',
                  ),
          ),
          value: _autoApprove,
          onChanged: widget.isAdmin ? (v) => setState(() => _autoApprove = v) : null,
        ),
        if (_preview.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            L10nLookup.preview,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
              context.t(
                '... و ${_preview.length - 8} صف إضافي',
                '... and ${_preview.length - 8} more rows',
              ),
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
              label: Text(
                context.t(
                  'استيراد ${_preview.length} مشرف',
                  'Import ${_preview.length} supervisor(s)',
                ),
              ),
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
  String? _facultyFilterId;
  bool _searchingUniversity = false;
  bool _searchingProfessor = false;
  bool _loadingAuthors = false;
  bool _importing = false;
  bool _limitToSelectedUniversity = true;
  bool _directProfessorSearch = false;
  String? _universitySearchHint;

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
      _universitySearchHint =
          OpenAlexSearchAliases.suggestedInstitutionEnglish(query);
    });

    try {
      final results = await OpenAlexClient.instance.searchInstitutions(query);
      if (!mounted) return;
      setState(() => _institutions = results);
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().contains('OpenAlex')
          ? context.t(
              'تعذر الاتصال بـ OpenAlex. تأكد من الإنترنت ثم أعد المحاولة.',
              'Could not reach OpenAlex. Check your connection and try again.',
            )
          : '$error';
      _showMessage(message, isError: true);
    } finally {
      if (mounted) setState(() => _searchingUniversity = false);
    }
  }

  Future<void> _searchProfessor() async {
    final query = _professorController.text.trim();
    if (query.length < 2) {
      _showMessage(
        context.t(
          'اكتب اسم الدكتور (حرفين على الأقل)',
          'Enter professor name (at least 2 characters)',
        ),
        isError: true,
      );
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
        final usedArabic = OpenAlexSearchAliases.containsArabic(query);
        _showMessage(
          usedArabic
              ? context.t(
                  'لم يُعثر على نتائج — جرّب الاسم بالإنجليزية أو ORCID '
                  '(مثل: Mohamed Ahmed)',
                  'No results — try the name in English or ORCID '
                  '(e.g. Mohamed Ahmed)',
                )
              : context.t(
                  'لم يُعثر على نتائج — جرّب الاسم بالإنجليزية أو ORCID',
                  'No results — try the name in English or ORCID',
                ),
          isError: true,
        );
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
        institutionName: _selectedInstitution?.name,
        autoApprove: false,
      );
      if (!mounted) return;
      _showMessage(
        context.t(
          'تم إرسال ${result.imported} ملفاً للمراجعة الإدارية'
          '${result.skipped > 0 ? ' — تخطي ${result.skipped}' : ''}. '
          'راجعها من شاشة اعتماد المشرفين.',
          'Submitted ${result.imported} profile(s) for admin review'
          '${result.skipped > 0 ? ' — skipped ${result.skipped}' : ''}. '
          'Review them in supervisor moderation.',
        ),
      );
      setState(() => _selectedAuthorIds.clear());
      if (!mounted || !widget.isAdmin) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.t('تم الإرسال للمراجعة', 'Submitted for review')),
          content: Text(
            context.t(
              'المشرفون المستوردون لن يظهروا للطلاب حتى تعتمدهم. '
              'هل تفتح شاشة المراجعة الآن؟',
              'Imported supervisors stay hidden from students until you approve them. '
              'Open the review screen now?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(L10nLookup.close),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminModerationScreen(
                      initialFilter: 'supervisors',
                    ),
                  ),
                );
              },
              child: Text(context.t('مراجعة الآن', 'Review now')),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage('$error', isError: true);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  List<OpenAlexAuthor> get _visibleAuthors {
    return _authors
        .where(
          (author) => OpenAlexFacultyMapper.matchesFilter(author, _facultyFilterId),
        )
        .toList();
  }

  void _pruneHiddenSelections() {
    _selectedAuthorIds.removeWhere((id) {
      final author = _authors.where((item) => item.id == id).firstOrNull;
      if (author == null) return true;
      return !OpenAlexFacultyMapper.matchesFilter(author, _facultyFilterId);
    });
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
    final visibleAuthors = _visibleAuthors;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _infoCard(
          context.t(
            'الطريقة الأسهل: ابحث عن الجامعة → حمّل كل الباحثين → صفِّ حسب الكلية → اختر الكل → استورد. '
            'لا يلزم كتابة اسم كل دكتور. البحث باسم شخص معيّن اختياري في الأسفل.',
            'Easiest path: search university → load all researchers → filter by faculty → select all → import. '
            'You do not need each doctor\'s name. Person search is optional below.',
          ),
        ),
        const SizedBox(height: 16),
        Text(
          context.t('1) الجامعة', '1) University'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _universityController,
                textAlign: TextAlign.start,
                decoration: InputDecoration(
                  labelText: context.t('اسم الجامعة', 'University name'),
                  hintText: context.t(
                    'جامعة القاهرة، Cairo University...',
                    'جامعة القاهرة، Cairo University...',
                  ),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
        if (_universitySearchHint != null) ...[
          const SizedBox(height: 8),
          Text(
            context.t(
              'البحث أيضاً بـ: $_universitySearchHint',
              'Also searching as: $_universitySearchHint',
            ),
            style: TextStyle(color: Colors.teal[700], fontSize: 13),
          ),
        ],
        if (_institutions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            context.t(
              'اختر الجامعة لتحميل كل المؤلفين/المشرفين',
              'Pick a university to load all authors/supervisors',
            ),
            style: const TextStyle(fontWeight: FontWeight.bold),
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
                  '${institution.country ?? '—'} • ${L10nLookup.publicationsCount(institution.worksCount)}',
                ),
                trailing: FilledButton(
                  onPressed: _loadingAuthors
                      ? null
                      : () => _loadAuthors(institution),
                  child: Text(
                    context.t('تحميل الكل', 'Load all'),
                  ),
                ),
                onTap: () => _loadAuthors(institution),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          context.t('2) تصفية حسب الكلية', '2) Filter by faculty'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          key: ValueKey('faculty_filter_$_facultyFilterId'),
          initialValue: _facultyFilterId,
          decoration: InputDecoration(
            labelText: context.t(
              'الكلية (بعد تحميل الجامعة)',
              'Faculty (after loading university)',
            ),
            helperText: context.t(
              'يعرض فقط الباحثين المطابقين لهذه الكلية من القائمة المحمّلة',
              'Shows only matching researchers from the loaded list',
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(context.t('كل الكليات', 'All faculties')),
            ),
            ...facultyCategories.map(
              (faculty) => DropdownMenuItem<String?>(
                value: faculty.id,
                child: Text(L10nLookup.facultyTitleStatic(faculty.id)),
              ),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _facultyFilterId = value;
              _pruneHiddenSelections();
            });
          },
        ),
        if (_loadingAuthors || _searchingProfessor)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text(
                  context.t(
                    'جاري جلب كل الباحثين من OpenAlex لهذه الجامعة...',
                    'Loading all researchers from OpenAlex for this university...',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        if (_authors.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            context.t('3) اختر واستورد', '3) Select and import'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.pending_actions, color: Colors.orange),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.t(
                      'كل استيراد من OpenAlex يذهب لقائمة المراجعة ولن يظهر للطلاب '
                      'حتى يعتمد المدير.',
                      'Every OpenAlex import goes to the review queue and stays hidden '
                      'from students until an admin approves it.',
                    ),
                    style: const TextStyle(height: 1.4, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  _facultyFilterId == null
                      ? (_directProfessorSearch
                          ? context.t(
                              '${_authors.length} نتيجة بحث — محدد ${_selectedAuthorIds.length}',
                              '${_authors.length} search results — ${_selectedAuthorIds.length} selected',
                            )
                          : context.t(
                              '${_authors.length} باحث — محدد ${_selectedAuthorIds.length}',
                              '${_authors.length} researchers — ${_selectedAuthorIds.length} selected',
                            ))
                      : context.t(
                          'يعرض ${visibleAuthors.length} من ${_authors.length} — محدد ${_selectedAuthorIds.length}',
                          'Showing ${visibleAuthors.length} of ${_authors.length} — ${_selectedAuthorIds.length} selected',
                        ),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (visibleAuthors.isNotEmpty) ...[
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedAuthorIds
                        ..clear()
                        ..addAll(visibleAuthors.map((author) => author.id));
                    });
                  },
                  child: Text(
                    _facultyFilterId == null
                        ? L10nLookup.selectAll
                        : context.t(
                            'اختيار كل هذه الكلية',
                            'Select this faculty',
                          ),
                  ),
                ),
                TextButton(
                  onPressed: _selectedAuthorIds.isEmpty
                      ? null
                      : () => setState(() => _selectedAuthorIds.clear()),
                  child: Text(context.t('إلغاء التحديد', 'Clear')),
                ),
              ],
            ],
          ),
          if (visibleAuthors.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                context.t(
                  'لا يوجد باحثون مطابقون لهذه الكلية في القائمة الحالية.',
                  'No researchers match this faculty in the current list.',
                ),
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ...visibleAuthors.map(
            (author) => OpenAlexAuthorPreviewCard(
              author: author,
              institutionLabel: openAlexInstitutionLabel(
                author,
                _selectedInstitution?.name,
              ),
              selected: _selectedAuthorIds.contains(author.id),
              onSelected: (checked) {
                setState(() {
                  if (checked == true) {
                    _selectedAuthorIds.add(author.id);
                  } else {
                    _selectedAuthorIds.remove(author.id);
                  }
                });
              },
            ),
          ),
          if (!_directProfessorSearch && _authors.length > 100)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                context.t(
                  'قائمة كاملة ${_authors.length} باحث — صفِّ بالكلية أعلاه أو استخدم البحث الاختياري بالاسم',
                  'Full list of ${_authors.length} researchers — filter by faculty above or use optional name search',
                ),
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
              label: Text(
                context.t(
                  'إرسال ${_selectedAuthorIds.length} للمراجعة',
                  'Submit ${_selectedAuthorIds.length} for review',
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: false,
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            leading: const Icon(Icons.person_search, color: Colors.teal),
            title: Text(
              context.t(
                'اختياري: بحث باسم دكتور معيّن',
                'Optional: search by a specific professor',
              ),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            subtitle: Text(
              context.t(
                'فقط إذا كنت تعرف الاسم — غير مطلوب لتعبئة الكلية',
                'Only if you know the name — not needed to fill a faculty',
              ),
            ),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.teal.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _professorController,
                      textAlign: TextAlign.start,
                      decoration: InputDecoration(
                        labelText: context.t(
                          'اسم الدكتور / الباحث',
                          'Professor / researcher name',
                        ),
                        hintText: context.t(
                          'محمد أحمد، Mohamed Ahmed، ORCID...',
                          'محمد أحمد، Mohamed Ahmed، ORCID...',
                        ),
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
                        title: Text(
                          context.t(
                            'البحث داخل الجامعة المختارة فقط',
                            'Search within selected university only',
                          ),
                        ),
                        subtitle: Text(_selectedInstitution!.name),
                        value: _limitToSelectedUniversity,
                        onChanged: (v) =>
                            setState(() => _limitToSelectedUniversity = v),
                      ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed:
                          _searchingProfessor ? null : _searchProfessor,
                      icon: _searchingProfessor
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_search),
                      label: Text(
                        context.t('بحث عن الدكتور', 'Search professor'),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.teal[700],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
