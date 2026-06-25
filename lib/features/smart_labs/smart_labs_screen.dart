import 'package:flutter/material.dart';
import '../academic/academic_content_service.dart';
import '../academic/academic_models.dart';
import '../academic/faculty_categories.dart';
import '../analysis_labs/sample_requests_screens.dart';
import '../auth/user_account_service.dart';
import '../lab_import/admin_lab_import_screen.dart';
import '../contributor/submit_lab_screen.dart';
import '../matchmaking/smart_matchmaking_engine.dart';
import '../profile/academic_profile.dart';
import '../profile/academic_profile_service.dart';
import 'my_lab_bookings_screen.dart';
import 'smart_lab_detail_screen.dart';

class SmartLabsScreen extends StatefulWidget {
  const SmartLabsScreen({super.key});

  @override
  State<SmartLabsScreen> createState() => _SmartLabsScreenState();
}

class _SmartLabsScreenState extends State<SmartLabsScreen> {
  String _selectedCity = 'الكل';
  String? _selectedFacultyId;
  bool _groupByCity = true;
  bool _sampleAnalysisOnly = false;
  bool _showFacultySuggestions = false;
  AcademicProfile? _profile;
  List<MatchResult<AcademicLab>> _recommended = [];

  final _facultySearchController = TextEditingController();
  final _labSearchController = TextEditingController();
  final _facultyFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  @override
  void dispose() {
    _facultySearchController.dispose();
    _labSearchController.dispose();
    _facultyFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadRecommendations() async {
    final profile = await AcademicProfileService.instance.loadProfile();
    if (!mounted) return;

    if (profile != null && profile.isComplete) {
      final labs = await AcademicContentService.instance.labsStream().first;
      setState(() {
        _profile = profile;
        _recommended = SmartMatchmakingEngine.matchLabs(profile, labs);
      });
    }
  }

  List<String> _citiesFrom(List<AcademicLab> labs) {
    final cities = labs
        .map((lab) => lab.city.trim())
        .where((city) => city.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['الكل', ...cities];
  }

  List<AcademicLab> _filterLabs(List<AcademicLab> labs) {
    var filtered = labs;
    if (_selectedCity != 'الكل') {
      filtered = filtered.where((lab) => lab.city == _selectedCity).toList();
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
    if (_sampleAnalysisOnly) {
      filtered = filtered
          .where((lab) => lab.offersSampleAnalysis || lab.acceptsExternalSamples)
          .toList();
    }
    return filtered;
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
    ];
    return fields.any((field) => field.toLowerCase().contains(query));
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
      _facultySearchController.text = faculty.titleAr;
      _showFacultySuggestions = false;
      _labSearchController.clear();
    });
    _facultyFocusNode.unfocus();
  }

  void _clearFaculty() {
    setState(() {
      _selectedFacultyId = null;
      _facultySearchController.clear();
      _labSearchController.clear();
      _showFacultySuggestions = false;
    });
  }

  Map<String, List<AcademicLab>> _groupLabs(List<AcademicLab> labs) {
    final grouped = <String, List<AcademicLab>>{};
    for (final lab in labs) {
      final key = lab.city.isNotEmpty ? lab.city : 'أخرى';
      grouped.putIfAbsent(key, () => []).add(lab);
    }
    return grouped;
  }

  void _openLab(AcademicLab lab) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SmartLabDetailScreen(lab: lab),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مختبرات ومراكز التحليل'),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
        actions: [
          StreamBuilder(
            stream: UserAccountService.instance.watchCurrentAccount(),
            builder: (context, snapshot) {
              if (snapshot.data?.isAdmin != true) {
                return const SizedBox.shrink();
              }
              return IconButton(
                tooltip: 'استيراد مختبرات CSV',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminLabImportScreen(),
                  ),
                ),
                icon: const Icon(Icons.upload_file),
              );
            },
          ),
          IconButton(
            tooltip: 'طلبات تحليل العينات',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MySampleAnalysisRequestsScreen(),
              ),
            ),
            icon: const Icon(Icons.biotech_outlined),
          ),
          IconButton(
            tooltip: 'حجوزاتي',
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
              const SnackBar(
                content: Text('تم إرسال المختبر للمراجعة'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('سجّل مختبر'),
      ),
      body: StreamBuilder<List<AcademicLab>>(
        stream: AcademicContentService.instance.labsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allLabs = snapshot.data ?? [];
          final labs = _filterLabs(allLabs);
          final cities = _citiesFrom(allLabs);

          return RefreshIndicator(
            onRefresh: _loadRecommendations,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeaderCard(),
                const SizedBox(height: 12),
                _buildSearchPanel(labs.length, allLabs.length),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('مراكز تقبل تحليل عينات خارجية فقط'),
                  value: _sampleAnalysisOnly,
                  onChanged: (value) => setState(() => _sampleAnalysisOnly = value),
                ),
                _buildCityDropdown(cities),
                if (_recommended.isNotEmpty && _selectedFacultyId == null) ...[
                  const SizedBox(height: 16),
                  _sectionTitle('مقترحة لك', Icons.auto_awesome),
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
                if (_selectedFacultyId == null)
                  _buildSelectFacultyHint()
                else if (labs.isEmpty)
                  _buildNoLabsHint()
                else ...[
                  _sectionTitle(
                    'مختبرات ${facultyTitleForCategory(_selectedFacultyId!)}',
                    Icons.science_outlined,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${labs.length} مختبر/مركز متاح',
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
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      color: Colors.purple[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.map_outlined, color: Colors.purple[700], size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'حجز فوري للأجهزة',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.purple[900],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'مختبرات جامعية ومراكز بحوث — حجز أجهزة أو طلب تحليل عينات لأي تخصص',
                    style: TextStyle(color: Colors.purple[800], fontSize: 13),
                  ),
                  if (_profile?.isComplete == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      'مقترحات مخصصة حسب ملفك الأكاديمي أدناه',
                      style: TextStyle(color: Colors.purple[700], fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
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
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            labelText: 'ابحث عن الكلية',
            hintText: 'مثال: الهندسة، الطب، العلوم...',
            prefixIcon: const Icon(Icons.school_outlined),
            suffixIcon: _selectedFacultyId != null
                ? IconButton(
                    tooltip: 'مسح',
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
                  ? facultyTitleForCategory(_selectedFacultyId!)
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
                      title: Text(faculty.titleAr),
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
            label: Text(facultyTitleForCategory(_selectedFacultyId!)),
            onDeleted: _clearFaculty,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _labSearchController,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              labelText: 'ابحث عن المختبر أو مركز البحث',
              hintText: 'اسم المختبر، الجامعة، نوع التحليل...',
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
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 6),
          Text(
            '$visibleCount مختبر/مركز'
            '${_labSearchController.text.trim().isNotEmpty ? ' مطابق للبحث' : ''}'
            ' — من $totalCount إجمالاً',
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
          Icon(Icons.search, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 12),
          const Text(
            'ابحث عن الكلية واخترها',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            'بعد اختيار الكلية يمكنك البحث عن مختبر أو مركز بحثي بالاسم',
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
            ? 'لا يوجد مختبر يطابق البحث في هذه الكلية'
            : 'لا توجد مختبرات مسجّلة لهذه الكلية حالياً',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey[600]),
      ),
    );
  }

  Widget _buildCityDropdown(List<String> cities) {
    if (cities.length <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: DropdownButtonFormField<String>(
        key: ValueKey(_selectedCity),
        initialValue: _selectedCity,
        decoration: const InputDecoration(
          labelText: 'المدينة (اختياري)',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        items: cities
            .map((city) => DropdownMenuItem(value: city, child: Text(city)))
            .toList(),
        onChanged: (value) {
          if (value != null) setState(() => _selectedCity = value);
        },
      ),
    );
  }

  Widget _buildViewToggle() {
    return Row(
      children: [
        Expanded(
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                label: Text('حسب المدينة'),
                icon: Icon(Icons.location_city_outlined, size: 18),
              ),
              ButtonSegment(
                value: false,
                label: Text('قائمة'),
                icon: Icon(Icons.view_list_outlined, size: 18),
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
                city,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text('${labs.length} مختبر'),
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
                    Icons.devices,
                    '${lab.devices.length} جهاز',
                  ),
                  _infoChip(
                    Icons.schedule,
                    'انتظار ${lab.minWaitDays} يوم',
                  ),
                  if (lab.offersSampleAnalysis)
                    _infoChip(
                      Icons.biotech_outlined,
                      '${lab.sampleServices.length} تحليل عينات',
                    ),
                  if (lab.minCost > 0)
                    _infoChip(
                      Icons.payments_outlined,
                      'من ${lab.minCost} ج.م',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
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
