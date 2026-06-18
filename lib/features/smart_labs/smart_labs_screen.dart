import 'package:flutter/material.dart';
import '../academic/academic_content_service.dart';
import '../academic/academic_models.dart';
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
  bool _groupByCity = true;
  AcademicProfile? _profile;
  List<MatchResult<AcademicLab>> _recommended = [];

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
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
    if (_selectedCity == 'الكل') return labs;
    return labs.where((lab) => lab.city == _selectedCity).toList();
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
        title: const Text('مختبرات ذكية'),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
        actions: [
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

          final labs = _filterLabs(snapshot.data ?? []);
          final cities = _citiesFrom(snapshot.data ?? []);

          if (labs.isEmpty) {
            return const Center(child: Text('لا توجد مختبرات في هذه المدينة'));
          }

          return RefreshIndicator(
            onRefresh: _loadRecommendations,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeaderCard(),
                if (_recommended.isNotEmpty) ...[
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
                _buildCityFilter(cities),
                const SizedBox(height: 12),
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
                    _profile?.isComplete == true
                        ? 'نعرض لك المختبرات حسب ملفك الأكاديمي ومدينتك'
                        : 'أكمل ملفك الأكاديمي لتوصيات أدق',
                    style: TextStyle(color: Colors.purple[800], fontSize: 13),
                  ),
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

  Widget _buildCityFilter(List<String> cities) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cities.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final city = cities[index];
          final selected = city == _selectedCity;
          return ChoiceChip(
            label: Text(city),
            selected: selected,
            onSelected: (_) => setState(() => _selectedCity = city),
            selectedColor: Colors.purple[200],
          );
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
                  Icon(Icons.science, color: Colors.purple[700]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      lab.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
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
