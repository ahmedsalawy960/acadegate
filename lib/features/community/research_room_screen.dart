import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'community_data.dart';
import 'create_research_discussion_screen.dart';
import 'research_discussion_detail_screen.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isCreator =>
      FirebaseAuth.instance.currentUser?.uid == widget.room.creatorId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.room.title),
        backgroundColor: const Color(0xFF00695C),
        foregroundColor: Colors.white,
        actions: [
          if (widget.room.isPasswordProtected)
            const Padding(
              padding: EdgeInsetsDirectional.only(end: 12),
              child: Icon(Icons.lock, size: 18),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  CreateResearchDiscussionScreen(room: widget.room),
            ),
          );
          if (created == true) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم نشر المناقشة وحفظها في الغرفة'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        backgroundColor: const Color(0xFF00695C),
        icon: const Icon(Icons.add),
        label: const Text('مناقشة جديدة'),
      ),
      body: Column(
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
                  'منشئ الغرفة: ${widget.room.creatorName}'
                  '${_isCreator ? ' (أنت)' : ''}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'ابحث في المناقشات... (عنوان، محتوى، كلمات)',
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
                            ? 'لا توجد مناقشات بعد.\nابدأ أول مناقشة بحثية.'
                            : 'لا توجد نتائج لـ «$_searchQuery»',
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
                          '${discussion.authorName} • ${discussion.repliesCount} رد',
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
      ),
    );
  }
}
