import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../academic_writing/writing_models.dart';
import '../community/community_models.dart';
import '../community/research_room_models.dart';
import '../moderation/approval_status.dart';
import '../science_news/science_news_models.dart';
import 'home_search_utils.dart';

class HomeSearchExtras {
  final List<WritingExpert> writingExperts;
  final List<CommunityPost> communityPosts;
  final List<ScienceNewsItem> scienceNews;
  final List<ResearchRoom> researchRooms;

  const HomeSearchExtras({
    this.writingExperts = const [],
    this.communityPosts = const [],
    this.scienceNews = const [],
    this.researchRooms = const [],
  });

  bool get isEmpty =>
      writingExperts.isEmpty &&
      communityPosts.isEmpty &&
      scienceNews.isEmpty &&
      researchRooms.isEmpty;
}

/// يجمع نتائج البحث من الأقسام غير المشمولة سابقاً في البحث الرئيسي.
class HomeSearchExtrasBuilder extends StatefulWidget {
  final String query;
  final Widget Function(BuildContext context, HomeSearchExtras extras) builder;

  const HomeSearchExtrasBuilder({
    super.key,
    required this.query,
    required this.builder,
  });

  @override
  State<HomeSearchExtrasBuilder> createState() =>
      _HomeSearchExtrasBuilderState();
}

class _HomeSearchExtrasBuilderState extends State<HomeSearchExtrasBuilder> {
  final _db = FirebaseFirestore.instance;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  List<WritingExpert> _writers = [];
  List<CommunityPost> _posts = [];
  List<ScienceNewsItem> _news = [];
  List<ResearchRoom> _rooms = [];

  @override
  void initState() {
    super.initState();
    _subscriptions.add(
      _db
          .collection('writing_services')
          .limit(400)
          .snapshots()
          .listen(_onWriters),
    );
    _subscriptions.add(
      _db
          .collection('community_posts')
          .limit(400)
          .snapshots()
          .listen(_onPosts),
    );
    _subscriptions.add(
      _db.collection('science_news').limit(200).snapshots().listen(_onNews),
    );
    _subscriptions.add(
      _db.collection('research_rooms').limit(300).snapshots().listen(_onRooms),
    );
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  void _onWriters(QuerySnapshot<Map<String, dynamic>> snap) {
    if (!mounted) return;
    setState(() {
      _writers = snap.docs
          .map((doc) => WritingExpert.fromMap(doc.data(), id: doc.id))
          .where((e) => e.isPubliclyVisible)
          .toList();
    });
  }

  void _onPosts(QuerySnapshot<Map<String, dynamic>> snap) {
    if (!mounted) return;
    setState(() {
      _posts = snap.docs
          .map((doc) => CommunityPost.fromMap(doc.data(), id: doc.id))
          .where((p) => p.isPubliclyVisible)
          .toList();
    });
  }

  void _onNews(QuerySnapshot<Map<String, dynamic>> snap) {
    if (!mounted) return;
    setState(() {
      _news = snap.docs
          .where(
            (doc) => ApprovalStatus.isPublic(
              doc.data()['approvalStatus']?.toString(),
            ),
          )
          .map((doc) => ScienceNewsItem.fromMap(doc.data(), id: doc.id))
          .toList();
    });
  }

  void _onRooms(QuerySnapshot<Map<String, dynamic>> snap) {
    if (!mounted) return;
    setState(() {
      _rooms = snap.docs
          .map((doc) => ResearchRoom.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  HomeSearchExtras _filtered() {
    final q = widget.query.trim().toLowerCase();
    if (q.isEmpty) return const HomeSearchExtras();

    return HomeSearchExtras(
      writingExperts: _writers
          .where(
            (e) => homeSearchMatches(q, [
              e.name,
              e.category,
              e.speciality,
              e.bio,
              e.priceRange,
              ...e.tags,
              ...e.languages,
              ...e.tools,
            ]),
          )
          .take(24)
          .toList(),
      communityPosts: _posts
          .where(
            (p) => homeSearchMatches(q, [
              p.title,
              p.body,
              p.authorName,
              p.type,
              p.university ?? '',
              ...p.tags,
            ]),
          )
          .take(24)
          .toList(),
      scienceNews: _news
          .where(
            (n) => homeSearchMatches(q, [
              n.title,
              n.summary,
              n.source,
              n.category,
            ]),
          )
          .take(24)
          .toList(),
      researchRooms: _rooms
          .where(
            (r) => homeSearchMatches(q, [
              r.title,
              r.description,
              r.creatorName,
              r.categoryId ?? '',
            ]),
          )
          .take(24)
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _filtered());
}
