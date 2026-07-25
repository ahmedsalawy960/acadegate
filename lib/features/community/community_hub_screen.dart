import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/l10n_lookup.dart';
import '../../core/locale/locale_extensions.dart';
import '../profile/academic_profile_service.dart';
import 'community_data.dart';
import 'community_room_screen.dart';
import 'create_research_room_screen.dart';
import 'research_room_models.dart';
import 'research_room_navigator.dart';
import 'research_room_service.dart';

class CommunityHubScreen extends StatefulWidget {
  const CommunityHubScreen({super.key});

  @override
  State<CommunityHubScreen> createState() => _CommunityHubScreenState();
}

class _CommunityHubScreenState extends State<CommunityHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateResearchRoomScreen(),
      ),
    );
    if (created == true && mounted) {
      _tabController.animateTo(1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t(
            'تم إنشاء الغرفة البحثية',
            'Research room created',
          )),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('المجتمع الأكاديمي', 'Academic community')),
        backgroundColor: const Color(0xFF00695C),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: context.t('غرف التخصص', 'Faculty rooms')),
            Tab(text: context.t('الغرف البحثية', 'Research rooms')),
          ],
        ),
        actions: [
          IconButton(
            tooltip: context.t('إنشاء غرفة بحثية', 'Create research room'),
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _createRoom,
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              onPressed: _createRoom,
              backgroundColor: const Color(0xFF00695C),
              icon: const Icon(Icons.meeting_room_outlined),
              label: Text(context.t('غرفة جديدة', 'New room')),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: const [
          _FacultyRoomsTab(),
          _ResearchRoomsTab(),
        ],
      ),
    );
  }
}

class _FacultyRoomsTab extends StatefulWidget {
  const _FacultyRoomsTab();

  @override
  State<_FacultyRoomsTab> createState() => _FacultyRoomsTabState();
}

class _FacultyRoomsTabState extends State<_FacultyRoomsTab> {
  String? _preferredFacultyId;
  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadPreferredFaculty();
  }

  Future<void> _loadPreferredFaculty() async {
    final profile = await AcademicProfileService.instance.loadProfile();
    if (!mounted) return;
    setState(() {
      _preferredFacultyId = profile?.resolvedFacultyCategory;
      _loadingProfile = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rooms = communityRoomsPinnedFirst(_preferredFacultyId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF00695C).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            context.t(
              'غرف نقاش لكل الكليات والتخصصات — ابحث داخل كل غرفة عن المناقشات المحفوظة.',
              'Discussion rooms for every faculty — search saved discussions inside each room.',
            ),
            style: const TextStyle(height: 1.4),
          ),
        ),
        Expanded(
          child: _loadingProfile
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: rooms.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    final isPinned = _preferredFacultyId != null &&
                        room.id ==
                            normalizeCommunityRoomId(_preferredFacultyId!);
                    return _RoomCard(
                      title: L10nLookup.communityRoomTitle(room.id),
                      description:
                          L10nLookup.communityRoomDescription(room.id),
                      icon: room.icon,
                      color: room.color,
                      badge: isPinned
                          ? context.t('تخصصك', 'Your faculty')
                          : null,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                CommunityRoomScreen(room: room),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ResearchRoomsTab extends StatefulWidget {
  const _ResearchRoomsTab();

  @override
  State<_ResearchRoomsTab> createState() => _ResearchRoomsTabState();
}

class _ResearchRoomsTabState extends State<_ResearchRoomsTab> {
  String? _filterCategoryId;

  List<ResearchRoom> _applyFilter(List<ResearchRoom> rooms) {
    final filter = _filterCategoryId;
    if (filter == null || filter.isEmpty) return rooms;
    return rooms
        .where((room) {
          final cat = room.categoryId;
          if (cat == null || cat.isEmpty) return false;
          return normalizeCommunityRoomId(cat) == filter;
        })
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filterRooms = communityRooms
        .where((room) => room.id != 'general')
        .toList();

    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF00695C).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            context.t(
              'غرف أنشأها الباحثون — محمية بكلمة مرور اختيارياً، '
              'مع بحث داخل المناقشات وإشعار لمنشئ الغرفة عند كل رد جديد.',
              'Rooms created by researchers — optionally password-protected, '
              'with in-discussion search and notifications to the room creator on each new reply.',
            ),
            style: const TextStyle(height: 1.4),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: FilterChip(
                  label: Text(context.t('الكل', 'All')),
                  selected: _filterCategoryId == null,
                  onSelected: (_) => setState(() => _filterCategoryId = null),
                ),
              ),
              ...filterRooms.map(
                (room) => Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: FilterChip(
                    label: Text(L10nLookup.communityRoomTitle(room.id)),
                    selected: _filterCategoryId == room.id,
                    onSelected: (_) =>
                        setState(() => _filterCategoryId = room.id),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
            children: [
              StreamBuilder<List<ResearchRoom>>(
                stream: ResearchRoomService.instance.watchMyRooms(),
                builder: (context, snapshot) {
                  final myRooms = snapshot.data ?? const <ResearchRoom>[];
                  if (myRooms.isEmpty) return const SizedBox.shrink();
                  final filtered = _applyFilter(myRooms);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('غرفتي البحثية', 'My research rooms'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            context.t(
                              'لا غرف ضمن هذا التخصص من غرفك.',
                              'None of your rooms match this faculty filter.',
                            ),
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        )
                      else
                        ...filtered.map(
                          (room) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _RoomCard(
                              title: room.title,
                              description: room.description.isNotEmpty
                                  ? room.description
                                  : context.t(
                                      'بواسطة ${room.creatorName}',
                                      'By ${room.creatorName}',
                                    ),
                              icon: Icons.meeting_room_outlined,
                              color: const Color(0xFF00695C),
                              trailing: room.isPasswordProtected
                                  ? const Icon(
                                      Icons.lock,
                                      size: 18,
                                      color: Colors.grey,
                                    )
                                  : null,
                              subtitle: context.t(
                                '${room.discussionsCount} مناقشة',
                                '${room.discussionsCount} discussions',
                              ),
                              onTap: () => openResearchRoom(context, room),
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        context.t('كل الغرف', 'All rooms'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  );
                },
              ),
              StreamBuilder<List<ResearchRoom>>(
                stream: ResearchRoomService.instance.watchPublicRooms(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final rooms = _applyFilter(snapshot.data ?? []);
                  if (rooms.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.meeting_room_outlined,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _filterCategoryId == null
                                ? context.t(
                                    'لا توجد غرف بحثية بعد.\nأنشئ أول غرفة من الزر أعلاه.',
                                    'No research rooms yet.\nCreate the first one with the button above.',
                                  )
                                : context.t(
                                    'لا غرف بحثية لهذا التخصص بعد.',
                                    'No research rooms for this faculty yet.',
                                  ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: rooms
                        .map(
                          (room) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _RoomCard(
                              title: room.title,
                              description: room.description.isNotEmpty
                                  ? room.description
                                  : context.t(
                                      'بواسطة ${room.creatorName}',
                                      'By ${room.creatorName}',
                                    ),
                              icon: Icons.science_outlined,
                              color: const Color(0xFF00695C),
                              trailing: room.isPasswordProtected
                                  ? const Icon(
                                      Icons.lock,
                                      size: 18,
                                      color: Colors.grey,
                                    )
                                  : null,
                              subtitle: [
                                if (room.categoryId != null &&
                                    room.categoryId!.isNotEmpty)
                                  L10nLookup.communityRoomTitle(
                                    normalizeCommunityRoomId(room.categoryId!),
                                  ),
                                context.t(
                                  '${room.discussionsCount} مناقشة • ${room.creatorName}',
                                  '${room.discussionsCount} discussions • ${room.creatorName}',
                                ),
                              ].join(' · '),
                              onTap: () => openResearchRoom(context, room),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoomCard extends StatelessWidget {
  final String title;
  final String description;
  final String? subtitle;
  final String? badge;
  final IconData icon;
  final Color color;
  final Widget? trailing;
  final VoidCallback onTap;

  const _RoomCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
    this.subtitle,
    this.badge,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 1,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badge!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle ?? description,
                      style: TextStyle(color: Colors.grey[700], height: 1.3),
                    ),
                  ],
                ),
              ),
              trailing ?? Icon(Icons.chevron_left, color: Colors.grey[500]),
            ],
          ),
        ),
      ),
    );
  }
}
