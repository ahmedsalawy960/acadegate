import 'package:flutter/material.dart';

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
        const SnackBar(
          content: Text('تم إنشاء الغرفة البحثية'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المجتمع الأكاديمي'),
        backgroundColor: const Color(0xFF00695C),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'غرف التخصص'),
            Tab(text: 'الغرف البحثية'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'إنشاء غرفة بحثية',
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
              label: const Text('غرفة جديدة'),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          _FacultyRoomsTab(),
          _ResearchRoomsTab(),
        ],
      ),
    );
  }
}

class _FacultyRoomsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
          child: const Text(
            'غرف نقاش حسب التخصص — ابحث داخل كل غرفة عن المناقشات المحفوظة.',
            style: TextStyle(height: 1.4),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: communityRooms.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final room = communityRooms[index];
              return _RoomCard(
                title: room.title,
                description: room.description,
                icon: room.icon,
                color: room.color,
                trailing: null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CommunityRoomScreen(room: room),
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

class _ResearchRoomsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF00695C).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'غرف أنشأها الباحثون — محمية بكلمة مرور اختيارياً، '
            'مع بحث داخل المناقشات وإشعار لمنشئ الغرفة عند كل رد جديد.',
            style: TextStyle(height: 1.4),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<ResearchRoom>>(
            stream: ResearchRoomService.instance.watchPublicRooms(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final rooms = snapshot.data ?? [];
              if (rooms.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.meeting_room_outlined,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        const Text(
                          'لا توجد غرف بحثية بعد.\nأنشئ أول غرفة من الزر أعلاه.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                itemCount: rooms.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final room = rooms[index];
                  return _RoomCard(
                    title: room.title,
                    description: room.description.isNotEmpty
                        ? room.description
                        : 'بواسطة ${room.creatorName}',
                    icon: Icons.science_outlined,
                    color: const Color(0xFF00695C),
                    trailing: room.isPasswordProtected
                        ? const Icon(Icons.lock, size: 18, color: Colors.grey)
                        : null,
                    subtitle:
                        '${room.discussionsCount} مناقشة • ${room.creatorName}',
                    onTap: () => openResearchRoom(context, room),
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

class _RoomCard extends StatelessWidget {
  final String title;
  final String description;
  final String? subtitle;
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
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
