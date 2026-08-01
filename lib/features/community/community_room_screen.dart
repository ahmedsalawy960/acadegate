import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/l10n_lookup.dart';
import '../../core/locale/locale_extensions.dart';
import '../matchmaking/matchmaking_screen.dart';
import '../moderation/approval_status.dart';
import '../profile/academic_profile.dart';
import '../profile/academic_profile_service.dart';
import 'community_data.dart';
import 'community_models.dart';
import 'community_post_detail_screen.dart';
import 'community_service.dart';
import 'create_community_post_screen.dart';

class CommunityRoomScreen extends StatefulWidget {
  final CommunityRoom room;

  const CommunityRoomScreen({super.key, required this.room});

  @override
  State<CommunityRoomScreen> createState() => _CommunityRoomScreenState();
}

class _CommunityRoomScreenState extends State<CommunityRoomScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  AcademicProfile? _profile;

  static const _tabTypes = <String?>[
    null,
    CommunityPostType.question,
    CommunityPostType.discussion,
    CommunityPostType.announcement,
    CommunityPostType.studyGroup,
  ];

  String _tabLabel(BuildContext context, String? type) {
    if (type == null) return context.t('الكل', 'All');
    return CommunityPostType.label(type);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabTypes.length, vsync: this);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await AcademicProfileService.instance.loadProfile();
    if (mounted) setState(() => _profile = profile);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  String? get _selectedType => _tabTypes.elementAt(_tabController.index);

  void _openSupervisors() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MatchmakingScreen(
          supervisorJourney: true,
          focusFacultyId: widget.room.facultyCategoryId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t(
          'غرفة ${L10nLookup.communityRoomTitle(widget.room.id)}',
          '${L10nLookup.communityRoomTitle(widget.room.id)} room',
        )),
        backgroundColor: widget.room.color,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          onTap: (_) => setState(() {}),
          tabs: _tabTypes
              .map((type) => Tab(text: _tabLabel(context, type)))
              .toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => CreateCommunityPostScreen(
                room: widget.room,
                initialType: _selectedType ?? CommunityPostType.discussion,
              ),
            ),
          );
          if (created == true && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.t(
                  'تم إرسال المنشور للمراجعة — سيظهر بعد الموافقة',
                  'Post sent for review — it will appear after approval',
                )),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        backgroundColor: widget.room.color,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(context.t('منشور جديد', 'New post')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: context.t(
                  'ابحث في مناقشات الغرفة...',
                  'Search room discussions...',
                ),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          if (widget.room.facultyCategoryId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: OutlinedButton.icon(
                onPressed: _openSupervisors,
                style: OutlinedButton.styleFrom(
                  foregroundColor: widget.room.color,
                  side: BorderSide(color: widget.room.color),
                  minimumSize: const Size.fromHeight(42),
                ),
                icon: const Icon(Icons.school_outlined, size: 20),
                label: Text(
                  context.t(
                    'ابحث عن مشرفين في هذا التخصص',
                    'Find supervisors in this faculty',
                  ),
                ),
              ),
            ),
          Expanded(
            child: StreamBuilder<List<CommunityPost>>(
              stream: CommunityService.instance.watchRoomPosts(
                roomId: widget.room.id,
                type: _selectedType,
                searchQuery: _searchQuery,
                viewerFaculty: _profile?.resolvedFacultyCategory,
                viewerSpecialization: _profile?.specialization,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(context.t(
                      'حدث خطأ: ${snapshot.error}',
                      'Error: ${snapshot.error}',
                    )),
                  );
                }

                final posts = snapshot.data ?? [];
                if (posts.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _searchQuery.trim().isEmpty
                            ? context.t(
                                'لا توجد منشورات في هذا القسم بعد.\nاضغط «منشور جديد» لتبدأ النقاش.',
                                'No posts in this section yet.\nTap "New post" to start the discussion.',
                              )
                            : context.t(
                                'لا توجد نتائج لـ «$_searchQuery»',
                                'No results for "$_searchQuery"',
                              ),
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: Colors.grey[700], height: 1.5),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return _PostCard(
                      post: post,
                      roomColor: widget.room.color,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CommunityPostDetailScreen(
                              post: post,
                              room: widget.room,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final CommunityPost post;
  final Color roomColor;
  final VoidCallback onTap;

  const _PostCard({
    required this.post,
    required this.roomColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final typeLabel = CommunityPostType.label(post.type);
    final pending = post.approvalStatus == ApprovalStatus.pending;
    final english = Localizations.localeOf(context).languageCode == 'en';
    final audienceLabel = PostAudienceScope.label(
      post.audienceScope,
      english: english,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
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
                  Icon(
                    CommunityPostType.icon(post.type),
                    size: 18,
                    color: roomColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    typeLabel,
                    style: TextStyle(
                      color: roomColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    PostAudienceScope.icon(post.audienceScope),
                    size: 14,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      post.audienceScope == PostAudienceScope.specialization &&
                              (post.targetSpecialization ?? '').isNotEmpty
                          ? post.targetSpecialization!
                          : audienceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ),
                  if (pending) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        context.t('بانتظار المراجعة', 'Pending review'),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (post.eventDate != null)
                    Text(
                      post.eventDate!,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                post.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                post.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[800], height: 1.4),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    post.authorName,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (post.university != null) ...[
                    Text(
                      ' • ${post.university}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                  const Spacer(),
                  Icon(Icons.thumb_up_alt_outlined,
                      size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('${post.upvotesCount}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(width: 12),
                  Icon(Icons.chat_bubble_outline,
                      size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('${post.repliesCount}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
