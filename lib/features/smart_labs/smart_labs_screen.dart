import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import '../../core/locale/app_translate.dart';
import '../../core/locale/l10n_lookup.dart';
import '../../core/locale/locale_extensions.dart';
import '../home/home_search_utils.dart';
import '../academic/academic_content_service.dart';
import '../academic/academic_models.dart';
import '../academic/faculty_categories.dart';
import '../analysis_labs/sample_requests_screens.dart';
import '../auth/user_account_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../lab_import/admin_lab_import_screen.dart';
import '../lab_import/crci_catalog.dart';
import '../lab_import/nbsle_university_cities.dart';
import '../contributor/submit_lab_screen.dart';
import '../matchmaking/smart_matchmaking_engine.dart';
import '../moderation/delete_content_button.dart';
import '../profile/academic_profile.dart';
import '../profile/academic_profile_service.dart';
import '../sample_analysis_marketplace/sample_analysis_marketplace_tab.dart';
import 'my_lab_bookings_screen.dart';
import 'smart_lab_detail_screen.dart';

enum SmartLabsTab { sampleAnalysis, equipmentBooking }

/// Official Egyptian labs registry (Supreme Council of Universities).
final Uri kNbsleBrowseUri = Uri.parse('https://nbsle.scu.eg/browse');

class SmartLabsScreen extends StatefulWidget {
  final SmartLabsTab initialTab;

  const SmartLabsScreen({
    super.key,
    this.initialTab = SmartLabsTab.sampleAnalysis,
  });

  @override
  State<SmartLabsScreen> createState() => _SmartLabsScreenState();
}

class _SmartLabsScreenState extends State<SmartLabsScreen>
    with SingleTickerProviderStateMixin {
  static const _allCitiesKey = '__all__';
  static const _allUniversitiesKey = '__all_uni__';
  static const _otherCityKey = '__other__';

  late TabController _tabController;
  Stream<List<AcademicLab>>? _labsStream;

  String _selectedCity = _allCitiesKey;
  String _selectedUniversity = _allUniversitiesKey;
  String? _selectedFacultyId;
  bool _groupByCity = true;
  bool _showFacultySuggestions = false;
  AcademicProfile? _profile;
  List<MatchResult<AcademicLab>> _recommended = [];

  final _facultySearchController = TextEditingController();
  final _labSearchController = TextEditingController();
  final _facultyFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: SmartLabsTab.values.length,
      vsync: this,
      initialIndex: widget.initialTab.index,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _loadRecommendations();
  }

  void _refreshLabsStream() {
    final faculty = _selectedFacultyId;
    final city = _selectedCity == _allCitiesKey ? null : _selectedCity;
    final university =
        _selectedUniversity == _allUniversitiesKey ? null : _selectedUniversity;
    final query = _labSearchController.text.trim();
    if (faculty == null &&
        (city == null || city.isEmpty) &&
        (university == null || university.isEmpty) &&
        query.length < 2) {
      _labsStream = null;
      return;
    }
    _labsStream = Stream.fromFuture(
      AcademicContentService.instance.searchLabs(
        query: query,
        facultyId: faculty,
        city: city,
        university: university,
        limit: 500,
      ),
    );
  }

  bool get _hasLabsFocus {
    final city = _selectedCity != _allCitiesKey;
    final university = _selectedUniversity != _allUniversitiesKey;
    final query = _labSearchController.text.trim().length >= 2;
    return _selectedFacultyId != null || city || university || query;
  }

  List<String> _cityDropdownOptions(List<AcademicLab> loadedLabs) {
    final fromData = loadedLabs
        .map((lab) => lab.city.trim())
        .where((city) => city.isNotEmpty)
        .toSet();
    final catalog = NbsleUniversityCities.browseCities.toSet();
    final merged = {...catalog, ...fromData}.toList()..sort();
    return [_allCitiesKey, ...merged];
  }

  List<String> _universityDropdownOptions(List<AcademicLab> loadedLabs) {
    final fromData = loadedLabs
        .map((lab) => lab.university.trim())
        .where((u) => u.isNotEmpty)
        .toSet();
    final catalog = NbsleUniversityCities.browseUniversities.toSet();
    final merged = {...catalog, ...fromData}.toList()..sort();
    return [_allUniversitiesKey, ...merged];
  }

  List<AcademicLab> _filterLabs(List<AcademicLab> labs) {
    var filtered = labs;
    if (_selectedCity != _allCitiesKey) {
      filtered = filtered
          .where(
            (lab) => NbsleUniversityCities.cityMatches(
              lab.city,
              _selectedCity,
            ),
          )
          .toList();
    }
    if (_selectedUniversity != _allUniversitiesKey) {
      filtered = filtered
          .where(
            (lab) => NbsleUniversityCities.universityMatches(
              lab.university,
              _selectedUniversity,
            ),
          )
          .toList();
    }
    if (_selectedFacultyId != null) {
      filtered = filtered
          .where((lab) => _labMatchesFaculty(lab, _selectedFacultyId!))
          .toList();
    }
    final labQuery = _labSearchController.text.trim().toLowerCase();
    if (labQuery.isNotEmpty) {
      filtered = filtered.where((lab) => _labMatchesQuery(lab, labQuery)).toList();
    }
    return filtered;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _facultySearchController.dispose();
    _labSearchController.dispose();
    _facultyFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadRecommendations() async {
    final profile = await AcademicProfileService.instance.loadProfile();
    if (!mounted) return;

    if (profile != null && profile.isComplete) {
      final faculty = profile.resolvedFacultyCategory;
      final labs = await AcademicContentService.instance.searchLabs(
        facultyId: faculty,
        limit: 60,
      );
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _recommended = SmartMatchmakingEngine.matchLabs(profile, labs);
      });
    }
  }

  Future<void> _openLab(AcademicLab lab) async {
    AcademicLab target = lab;
    if (lab.isFromFirebase &&
        (lab.equipmentList.isEmpty ||
            lab.sampleServices.any((s) => s.id == '_listed'))) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      try {
        final full = await AcademicContentService.instance.fetchLabById(lab.id!);
        if (full != null) target = full;
      } finally {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
      }
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SmartLabDetailScreen(lab: target),
      ),
    );
  }

  bool _labMatchesQuery(AcademicLab lab, String query) {
    final fields = [
      lab.name,
      lab.university,
      lab.location,
      lab.description,
      lab.city,
      ...lab.tags,
      ...lab.sampleServices.map((s) => s.name),
      ...lab.sampleServices.map((s) => s.description),
    ];
    return homeSearchMatches(query, fields);
  }

  List<FacultyCategory> _matchingFaculties(String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return facultyCategories;
    return facultyCategories
        .where(
          (faculty) =>
              faculty.titleAr.toLowerCase().contains(trimmed) ||
              faculty.id.toLowerCase().contains(trimmed),
        )
        .toList();
  }

  bool _labMatchesFaculty(AcademicLab lab, String facultyId) {
    return lab.matchesFaculty(facultyId);
  }

  void _selectFaculty(FacultyCategory faculty) {
    setState(() {
      _selectedFacultyId = faculty.id;
      _facultySearchController.text = L10nLookup.facultyTitleStatic(faculty.id);
      _showFacultySuggestions = false;
      _labSearchController.clear();
      _refreshLabsStream();
    });
    _facultyFocusNode.unfocus();
  }

  void _showCrciCenters() {
    setState(() {
      _selectedUniversity = CrciCatalog.affiliationAr;
      _selectedCity = _allCitiesKey;
      _selectedFacultyId = null;
      _facultySearchController.clear();
      _labSearchController.clear();
      _refreshLabsStream();
    });
  }

  void _clearFaculty() {
    setState(() {
      _selectedFacultyId = null;
      _facultySearchController.clear();
      _labSearchController.clear();
      _showFacultySuggestions = false;
      _refreshLabsStream();
    });
  }

  Map<String, List<AcademicLab>> _groupLabs(List<AcademicLab> labs) {
    final grouped = <String, List<AcademicLab>>{};
    for (final lab in labs) {
      final key = lab.city.isNotEmpty ? lab.city : _otherCityKey;
      grouped.putIfAbsent(key, () => []).add(lab);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(
          context.t(
            'المختبرات والتحليل',
            'Labs & analysis',
          ),
        ),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              icon: const Icon(Icons.biotech_outlined),
              text: context.t('تحليل عينات', 'Sample analysis'),
            ),
            Tab(
              icon: const Icon(Icons.precision_manufacturing_outlined),
              text: context.t('حجز أجهزة', 'Book equipment'),
            ),
          ],
        ),
        actions: [
          StreamBuilder(
            stream: UserAccountService.instance.watchCurrentAccount(),
            builder: (context, snapshot) {
              if (snapshot.data?.isAdmin != true) {
                return const SizedBox.shrink();
              }
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: context.t(
                      'استيراد مختبرات CSV',
                      'Import labs CSV',
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminLabImportScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.upload_file),
                  ),
                ],
              );
            },
          ),
          IconButton(
            tooltip: context.t(
              'طلبات تحليل العينات',
              'Sample analysis requests',
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MySampleAnalysisRequestsScreen(),
              ),
            ),
            icon: const Icon(Icons.biotech_outlined),
          ),
          IconButton(
            tooltip: context.t('حجوزاتي', 'My bookings'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MyLabBookingsScreen(),
              ),
            ),
            icon: const Icon(Icons.event_available_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => const SubmitLabScreen(),
            ),
          );
          if (created == true && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  context.t(
                    'تم إرسال المختبر للمراجعة',
                    'Lab sent for review',
                  ),
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(context.t('سجّل مختبر', 'Register lab')),
      ),
      body: Column(
        children: [
          StreamBuilder(
            stream: UserAccountService.instance.watchCurrentAccount(),
            builder: (context, snapshot) {
              if (snapshot.data?.isAdmin != true) {
                return const SizedBox.shrink();
              }
              return Material(
                color: Colors.teal.shade50,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.t(
                          'إدارة المختبرات (مدير)',
                          'Labs admin',
                        ),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal[900],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: () async {
                              await launchUrl(
                                kNbsleBrowseUri,
                                mode: LaunchMode.externalApplication,
                              );
                            },
                            icon: const Icon(Icons.open_in_new, size: 18),
                            label: Text(context.t(
                              'فتح سجل NBSLE',
                              'Open NBSLE',
                            )),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.teal[700],
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminLabImportScreen(),
                              ),
                            ),
                            icon: const Icon(Icons.upload_file, size: 18),
                            label: Text(context.t(
                              'استيراد CSV',
                              'Import CSV',
                            )),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                const SampleAnalysisMarketplaceTab(),
                _buildEquipmentBookingTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentBookingTab() {
    final stream = _labsStream;
    if (stream == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.purple.shade50,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                context.t(
                  'اختر المدينة أو الكلية أو ابحث باسم الجهاز/المختبر — لا نحمّل كل سجل NBSLE دفعة واحدة.',
                  'Pick a city or faculty, or search by device/lab name — we do not download the full NBSLE catalog at once.',
                ),
                style: TextStyle(height: 1.45, color: Colors.purple.shade900),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildSearchPanel(0, 0),
          const SizedBox(height: 8),
          _buildCityDropdown(_cityDropdownOptions(const [])),
          const SizedBox(height: 8),
          _buildUniversityDropdown(_universityDropdownOptions(const [])),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _showCrciCenters,
            icon: const Icon(Icons.apartment_outlined),
            label: Text(
              context.t(
                'عرض مراكز CRCI القومية (${CrciCatalog.centers.length})',
                'Show CRCI national centers (${CrciCatalog.centers.length})',
              ),
            ),
          ),
          if (_recommended.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionTitle(
              context.t('مقترحة لك', 'Recommended for you'),
              Icons.auto_awesome,
            ),
            ..._recommended.map(
              (result) => _RecommendedLabCard(
                lab: result.item,
                score: result.score,
                reason: result.reasons.isNotEmpty ? result.reasons.first : '',
                onTap: () => _openLab(result.item),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _buildSelectFacultyHint(),
        ],
      );
    }

    return StreamBuilder<List<AcademicLab>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allLabs = snapshot.data ?? [];
        var labs = _filterLabs(allLabs);
        const maxLabs = 400;
        final truncated = labs.length > maxLabs;
        if (truncated) labs = labs.take(maxLabs).toList();
        final cities = _cityDropdownOptions(allLabs);
        final universities = _universityDropdownOptions(allLabs);

        return RefreshIndicator(
          onRefresh: () async {
            _refreshLabsStream();
            await _loadRecommendations();
            if (mounted) setState(() {});
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: Colors.purple.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    context.t(
                      'احجز جلسة على جهاز بنفسك (SEM، HPLC...) — للتحليل الجاهز بالتقرير استخدم تبويب «تحليل عينات».'
                      '${_profile?.isComplete == true ? '\nمقترحات مخصصة لملفك الأكاديمي أدناه.' : ''}',
                      'Book a device session yourself (SEM, HPLC...) — for full analysis with report use the Sample analysis tab.'
                      '${_profile?.isComplete == true ? '\nPersonalized suggestions for your profile below.' : ''}',
                    ),
                    style: TextStyle(
                      height: 1.45,
                      color: Colors.purple.shade900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildSearchPanel(labs.length, allLabs.length),
              const SizedBox(height: 8),
              _buildCityDropdown(cities),
              const SizedBox(height: 8),
              _buildUniversityDropdown(universities),
              if (_recommended.isNotEmpty && !_hasLabsFocus) ...[
                const SizedBox(height: 16),
                _sectionTitle(
                  context.t('مقترحة لك', 'Recommended for you'),
                  Icons.auto_awesome,
                ),
                ..._recommended.map(
                  (result) => _RecommendedLabCard(
                    lab: result.item,
                    score: result.score,
                    reason: result.reasons.isNotEmpty
                        ? result.reasons.first
                        : '',
                    onTap: () => _openLab(result.item),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (!_hasLabsFocus)
                _buildSelectFacultyHint()
              else if (labs.isEmpty)
                _buildNoLabsHint()
              else ...[
                _sectionTitle(
                  _selectedFacultyId != null
                      ? context.t(
                          'مختبرات ${L10nLookup.facultyTitleStatic(_selectedFacultyId!)}',
                          '${L10nLookup.facultyTitleStatic(_selectedFacultyId!)} labs',
                        )
                      : _selectedUniversity != _allUniversitiesKey
                          ? context.t(
                              'مختبرات $_selectedUniversity',
                              '$_selectedUniversity labs',
                            )
                          : _selectedCity != _allCitiesKey
                              ? context.t(
                                  'مختبرات $_selectedCity',
                                  '$_selectedCity labs',
                                )
                              : context.t('نتائج البحث', 'Search results'),
                  Icons.science_outlined,
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    context.t(
                      truncated
                          ? 'عرض أول $maxLabs من النتائج — ضيّق البحث أو المدينة'
                          : '${labs.length} مختبر/مركز متاح',
                      truncated
                          ? 'Showing first $maxLabs results — narrow search or city'
                          : '${labs.length} lab(s)/center(s) available',
                    ),
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                ),
                _buildViewToggle(),
                const SizedBox(height: 12),
                if (_groupByCity)
                  ..._groupLabs(labs).entries.map(
                        (entry) => _CityGroup(
                          city: entry.key,
                          labs: entry.value,
                          onOpenLab: _openLab,
                        ),
                      )
                else
                  ...labs.map(
                    (lab) => SmartLabCard(lab: lab, onTap: () => _openLab(lab)),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }


  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: Colors.purple[700]),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
              color: Colors.purple[900],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPanel(int visibleCount, int totalCount) {
    final facultySuggestions = _matchingFaculties(_facultySearchController.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _facultySearchController,
          focusNode: _facultyFocusNode,
          textAlign: TextAlign.start,
          decoration: InputDecoration(
            labelText: context.t('ابحث عن الكلية', 'Search for faculty'),
            hintText: context.t(
              'مثال: الهندسة، الطب، العلوم...',
              'e.g. Engineering, Medicine, Science...',
            ),
            prefixIcon: const Icon(Icons.school_outlined),
            suffixIcon: _selectedFacultyId != null
                ? IconButton(
                    tooltip: context.t('مسح', 'Clear'),
                    onPressed: _clearFaculty,
                    icon: const Icon(Icons.close),
                  )
                : const Icon(Icons.search),
            border: const OutlineInputBorder(),
          ),
          onTap: () => setState(() => _showFacultySuggestions = true),
          onChanged: (value) {
            setState(() {
              final selectedTitle = _selectedFacultyId != null
                  ? L10nLookup.facultyTitleStatic(_selectedFacultyId!)
                  : null;
              if (selectedTitle != null && value.trim() == selectedTitle) {
                _showFacultySuggestions = false;
                return;
              }
              _selectedFacultyId = null;
              _showFacultySuggestions = true;
            });
          },
        ),
        if (_showFacultySuggestions &&
            _selectedFacultyId == null &&
            facultySuggestions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: facultySuggestions.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final faculty = facultySuggestions[index];
                  return InkWell(
                    onTap: () => _selectFaculty(faculty),
                    child: ListTile(
                      dense: true,
                      leading: Icon(faculty.icon, color: faculty.color, size: 22),
                      title: Text(L10nLookup.facultyTitleStatic(faculty.id)),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
        if (_selectedFacultyId != null) ...[
          const SizedBox(height: 10),
          InputChip(
            avatar: Icon(
              facultyById(_selectedFacultyId!)?.icon ?? Icons.school,
              size: 18,
              color: facultyById(_selectedFacultyId!)?.color,
            ),
            label: Text(L10nLookup.facultyTitleStatic(_selectedFacultyId!)),
            onDeleted: _clearFaculty,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _labSearchController,
            textAlign: TextAlign.start,
            decoration: InputDecoration(
              labelText: context.t(
                'ابحث عن المختبر أو مركز البحث',
                'Search for a lab or research center',
              ),
              hintText: context.t(
                'اسم المختبر، الجامعة، نوع التحليل...',
                'Lab name, university, analysis type...',
              ),
              prefixIcon: const Icon(Icons.biotech_outlined),
              suffixIcon: _labSearchController.text.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _labSearchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              setState(() {
                _refreshLabsStream();
              });
            },
          ),
          const SizedBox(height: 6),
          Text(
            context.t(
              '$visibleCount مختبر/مركز'
              '${_labSearchController.text.trim().isNotEmpty ? ' مطابق للبحث' : ''}',
              '$visibleCount lab(s)/center(s)'
              '${_labSearchController.text.trim().isNotEmpty ? ' matching search' : ''}',
            ),
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ],
    );
  }

  Widget _buildSelectFacultyHint() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.location_city_outlined, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            context.t(
              'اختر المدينة أو الكلية للبدء',
              'Pick a city or faculty to start',
            ),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            context.t(
              'مثال: الشرقية — أو ابحث باسم الجهاز مثل SEM / HPLC',
              'Example: Sharqia — or search a device name like SEM / HPLC',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildNoLabsHint() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        _labSearchController.text.trim().isNotEmpty
            ? context.t(
                'لا يوجد مختبر يطابق البحث في هذه الكلية',
                'No lab matches your search in this faculty',
              )
            : context.t(
                'لا توجد مختبرات مسجّلة لهذه الكلية حالياً',
                'No labs registered for this faculty yet',
              ),
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey[600]),
      ),
    );
  }

  Widget _buildCityDropdown(List<String> cities) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: DropdownButtonFormField<String>(
        key: ValueKey('city-$_selectedCity-${cities.length}'),
        initialValue: cities.contains(_selectedCity)
            ? _selectedCity
            : _allCitiesKey,
        decoration: InputDecoration(
          labelText: context.t('المدينة / المحافظة', 'City / governorate'),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: cities
            .map(
              (city) => DropdownMenuItem(
                value: city,
                child: Text(
                  city == _allCitiesKey
                      ? context.t('كل المدن', 'All cities')
                      : city,
                ),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _selectedCity = value;
              _refreshLabsStream();
            });
          }
        },
      ),
    );
  }

  Widget _buildUniversityDropdown(List<String> universities) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: DropdownButtonFormField<String>(
        key: ValueKey('uni-$_selectedUniversity-${universities.length}'),
        initialValue: universities.contains(_selectedUniversity)
            ? _selectedUniversity
            : _allUniversitiesKey,
        decoration: InputDecoration(
          labelText: context.t('الجامعة', 'University'),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: universities
            .map(
              (uni) => DropdownMenuItem(
                value: uni,
                child: Text(
                  uni == _allUniversitiesKey
                      ? context.t('كل الجامعات', 'All universities')
                      : uni,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _selectedUniversity = value;
              _refreshLabsStream();
            });
          }
        },
      ),
    );
  }

  Widget _buildViewToggle() {
    return Row(
      children: [
        Expanded(
          child: SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: true,
                label: Text(context.t('حسب المدينة', 'By city')),
                icon: const Icon(Icons.location_city_outlined, size: 18),
              ),
              ButtonSegment(
                value: false,
                label: Text(context.t('قائمة', 'List')),
                icon: const Icon(Icons.view_list_outlined, size: 18),
              ),
            ],
            selected: {_groupByCity},
            onSelectionChanged: (value) {
              setState(() => _groupByCity = value.first);
            },
          ),
        ),
      ],
    );
  }
}

class _CityGroup extends StatelessWidget {
  static const _otherCityKey = '__other__';

  final String city;
  final List<AcademicLab> labs;
  final ValueChanged<AcademicLab> onOpenLab;

  const _CityGroup({
    required this.city,
    required this.labs,
    required this.onOpenLab,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.place_outlined, size: 18),
              const SizedBox(width: 6),
              Text(
                city == _otherCityKey
                    ? context.t('أخرى', 'Other')
                    : city,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text(
                  context.t('${labs.length} مختبر', '${labs.length} labs'),
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        ...labs.map(
          (lab) => SmartLabCard(lab: lab, onTap: () => onOpenLab(lab)),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class SmartLabCard extends StatelessWidget {
  final AcademicLab lab;
  final VoidCallback onTap;

  const SmartLabCard({
    super.key,
    required this.lab,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      lab.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  DeleteContentButton(
                    collection: 'labs',
                    documentId: lab.id,
                    ownerId: lab.ownerId,
                    itemLabel: lab.name,
                    asAppBarAction: false,
                    iconColor: Colors.red,
                    onDeleted: () {},
                  ),
                  if (lab.isResearchCenter)
                    Chip(
                      label: Text(
                        lab.labTypeLabel,
                        style: const TextStyle(fontSize: 10),
                      ),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.purple[100],
                    ),
                  if (lab.ratingAvg > 0) _RatingStars(rating: lab.ratingAvg),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                lab.location,
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
              ),
              if (lab.university.isNotEmpty)
                Text(
                  lab.university,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              if (lab.hasFacultyLink) ...[
                const SizedBox(height: 4),
                Chip(
                  label: Text(
                    lab.displayFacultyName,
                    style: const TextStyle(fontSize: 11),
                  ),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Colors.purple[50],
                  avatar: Icon(Icons.school, size: 14, color: Colors.purple[800]),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _infoChip(
                    context,
                    Icons.devices,
                    context.t(
                      '${lab.deviceCount} جهاز',
                      '${lab.deviceCount} devices',
                    ),
                  ),
                  _infoChip(
                    context,
                    Icons.schedule,
                    context.t(
                      'انتظار ${lab.minWaitDays} يوم',
                      'Wait ${lab.minWaitDays} days',
                    ),
                  ),
                  if (lab.offersSampleAnalysis)
                    _infoChip(
                      context,
                      Icons.biotech_outlined,
                      context.t(
                        '${lab.sampleServices.length} تحليل عينات',
                        '${lab.sampleServices.length} sample analyses',
                      ),
                    ),
                  if (lab.minCost > 0)
                    _infoChip(
                      context,
                      Icons.payments_outlined,
                      context.t(
                        'من ${lab.minCost} ج.م',
                        'From ${lab.minCost} EGP',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(BuildContext context, IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _RecommendedLabCard extends StatelessWidget {
  final AcademicLab lab;
  final int score;
  final String reason;
  final VoidCallback onTap;

  const _RecommendedLabCard({
    required this.lab,
    required this.score,
    required this.reason,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.purple[50],
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Colors.purple[700],
          child: Text(
            '$score%',
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ),
        title: Text(
          lab.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          reason.isNotEmpty ? '$reason\n${lab.location}' : lab.location,
        ),
        isThreeLine: reason.isNotEmpty,
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      ),
    );
  }
}

class _RatingStars extends StatelessWidget {
  final double rating;

  const _RatingStars({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star, color: Colors.amber, size: 16),
        const SizedBox(width: 2),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }
}
