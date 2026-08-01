import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import 'community_data.dart';
import 'create_research_discussion_screen.dart';
import 'research_discussion_detail_screen.dart';
import 'research_room_chat_panel.dart';
import 'research_room_models.dart';
import 'research_room_service.dart';

class ResearchRoomScreen extends StatefulWidget {
  final ResearchRoom room;

  const ResearchRoomScreen({super.key, required this.room});

  @override
  State<ResearchRoomScreen> createState() => _ResearchRoomScreenState();
}

class _ResearchRoomScreenState extends State<ResearchRoomScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  /// 0 = discussions, 1 = live chat
  int _tabIndex = 0;
  bool _chatMounted = false;

  @override
  void initState() {
    super.initState();
    // Defer Firestore writes so the first frame can paint safely.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bootstrapMembership();
    });
  }

  Future<void> _bootstrapMembership() async {
    try {
      await ResearchRoomService.instance.ensureDefaultChannels(widget.room.id);
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || !mounted) return;
      await ResearchRoomService.instance.ensureMemberRole(
        roomId: widget.room.id,
        role: uid == widget.room.creatorId ? 'owner' : 'member',
      );
    } catch (_) {
      // Never crash room entry on membership bootstrap failure.
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isCreator =>
      FirebaseAuth.instance.currentUser?.uid == widget.room.creatorId;

  String _roleLabel(BuildContext context, String role) {
    return switch (role) {
      'owner' => context.t('مالك', 'Owner'),
      'moderator' => context.t('مشرف', 'Moderator'),
      _ => context.t('عضو', 'Member'),
    };
  }

  void _selectTab(int index) {
    setState(() {
      _tabIndex = index;
      if (index == 1) _chatMounted = true;
    });
  }

  Future<void> _showMembersSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.55,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    sheetContext.t('أعضاء الغرفة', 'Room members'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<ResearchRoomMember>>(
                    stream: ResearchRoomService.instance
                        .watchRoomMembers(widget.room.id),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            context.t(
                              'تعذر تحميل الأعضاء',
                              'Could not load members',
                            ),
                          ),
                        );
                      }
                      final members =
                          snapshot.data ?? const <ResearchRoomMember>[];
                      if (snapshot.connectionState ==
                              ConnectionState.waiting &&
                          members.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (members.isEmpty) {
                        return Center(
                          child: Text(
                            context.t('لا أعضاء بعد', 'No members yet'),
                          ),
                        );
                      }
                      return ListView.separated(
                        itemCount: members.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final member = members[index];
                          final isSelf = member.uid ==
                              FirebaseAuth.instance.currentUser?.uid;
                          final shortId = member.uid.isEmpty
                              ? '—'
                              : member.uid.substring(
                                  0,
                                  member.uid.length < 8
                                      ? member.uid.length
                                      : 8,
                                );
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                member.role == 'owner'
                                    ? 'O'
                                    : member.role == 'moderator'
                                        ? 'M'
                                        : 'U',
                              ),
                            ),
                            title: Text(
                              isSelf ? context.t('أنت', 'You') : shortId,
                            ),
                            subtitle: Text(_roleLabel(context, member.role)),
                            trailing: _isCreator &&
                                    member.role != 'owner' &&
                                    !isSelf
                                ? PopupMenuButton<String>(
                                    onSelected: (value) async {
                                      final err = await ResearchRoomService
                                          .instance
                                          .setMemberRole(
                                        roomId: widget.room.id,
                                        memberId: member.uid,
                                        role: value,
                                      );
                                      if (!sheetContext.mounted) return;
                                      if (err != null) {
                                        ScaffoldMessenger.of(sheetContext)
                                            .showSnackBar(
                                          SnackBar(content: Text(err)),
                                        );
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'moderator',
                                        child: Text(
                                          context.t(
                                            'تعيين مشرف',
                                            'Make moderator',
                                          ),
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'member',
                                        child: Text(
                                          context.t(
                                            'تعيين عضو',
                                            'Make member',
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : null,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(widget.room.title),
        backgroundColor: const Color(0xFF00695C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: context.t('الأعضاء', 'Members'),
            icon: const Icon(Icons.groups_outlined),
            onPressed: _showMembersSheet,
          ),
          if (widget.room.isPasswordProtected)
            const Padding(
              padding: EdgeInsetsDirectional.only(end: 12),
              child: Icon(Icons.lock, size: 18),
            ),
        ],
      ),
      floatingActionButton: _tabIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final snackText = context.t(
                  'تم نشر المناقشة وحفظها في الغرفة',
                  'Discussion published and saved in the room',
                );
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CreateResearchDiscussionScreen(room: widget.room),
                  ),
                );
                if (!mounted) return;
                if (created == true) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(snackText),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              backgroundColor: const Color(0xFF00695C),
              icon: const Icon(Icons.add),
              label: Text(context.t('مناقشة جديدة', 'New discussion')),
            )
          : null,
      body: Column(
        children: [
          Material(
            color: const Color(0xFF00695C),
            child: Row(
              children: [
                Expanded(
                  child: _TabButton(
                    label: context.t('مناقشات', 'Discussions'),
                    selected: _tabIndex == 0,
                    onTap: () => _selectTab(0),
                  ),
                ),
                Expanded(
                  child: _TabButton(
                    label: context.t('شات حي', 'Live chat'),
                    selected: _tabIndex == 1,
                    onTap: () => _selectTab(1),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: [
                _discussionsTab(),
                _chatMounted
                    ? ResearchRoomChatPanel(room: widget.room)
                    : const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _discussionsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.room.description.isNotEmpty)
                Text(
                  widget.room.description,
                  style: TextStyle(color: Colors.grey[700], height: 1.4),
                ),
              const SizedBox(height: 8),
              Text(
                _isCreator
                    ? context.t(
                        'منشئ الغرفة: ${widget.room.creatorName} (أنت)',
                        'Room creator: ${widget.room.creatorName} (you)',
                      )
                    : context.t(
                        'منشئ الغرفة: ${widget.room.creatorName}',
                        'Room creator: ${widget.room.creatorName}',
                      ),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: context.t(
                    'ابحث في المناقشات... (عنوان، محتوى، كلمات)',
                    'Search discussions... (title, content, keywords)',
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
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<ResearchDiscussion>>(
            stream: ResearchRoomService.instance.watchDiscussions(
              roomId: widget.room.id,
              searchQuery: _searchQuery,
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    context.t(
                      'تعذر تحميل المناقشات',
                      'Could not load discussions',
                    ),
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final discussions = snapshot.data ?? [];
              if (discussions.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _searchQuery.trim().isEmpty
                          ? context.t(
                              'لا توجد مناقشات بعد.\nابدأ أول مناقشة بحثية أو استخدم تبويب الشات الحي.',
                              'No discussions yet.\nStart a research discussion or use the Live chat tab.',
                            )
                          : context.t(
                              'لا توجد نتائج لـ «$_searchQuery»',
                              'No results for "$_searchQuery"',
                            ),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[700], height: 1.5),
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                itemCount: discussions.length,
                itemBuilder: (context, index) {
                  final discussion = discussions[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: Icon(
                        CommunityPostType.icon(discussion.type),
                        color: const Color(0xFF00695C),
                      ),
                      title: Text(
                        discussion.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        context.t(
                          '${discussion.authorName} • ${discussion.repliesCount} رد',
                          '${discussion.authorName} • ${discussion.repliesCount} replies',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ResearchDiscussionDetailScreen(
                              room: widget.room,
                              discussionId: discussion.id,
                            ),
                          ),
                        );
                      },
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

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
