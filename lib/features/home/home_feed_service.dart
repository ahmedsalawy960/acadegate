import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'home_feed_models.dart';
import 'home_feed_seed.dart';

class HomeFeedService {
  HomeFeedService._();
  static final HomeFeedService instance = HomeFeedService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Stream<HomeFeedSnapshot>? _feedStream;

  Stream<HomeFeedSnapshot> watchFeed() =>
      _feedStream ??= _createFeedStream();

  Stream<HomeFeedSnapshot> _createFeedStream() {
    final controller = StreamController<HomeFeedSnapshot>.broadcast();
    StreamSubscription? sectionsSub;
    StreamSubscription? bannersSub;
    QuerySnapshot<Map<String, dynamic>>? latestSections;
    QuerySnapshot<Map<String, dynamic>>? latestBanners;
    var sectionsReady = false;
    var bannersReady = false;

    void emit() {
      if (!sectionsReady || !bannersReady || controller.isClosed) return;
      try {
        var sections = (latestSections?.docs ?? const [])
            .map((d) => HomeSection.fromMap(d.id, d.data()))
            .where((s) => s.enabled && s.type != HomeSectionType.unknown)
            .toList();
        sections.sort((a, b) => a.order.compareTo(b.order));

        var banners = (latestBanners?.docs ?? const [])
            .map((d) => HomePromoBanner.fromMap(d.id, d.data()))
            .where((b) => b.isLive)
            .toList();

        final fromRemote = (latestSections?.docs.isNotEmpty ?? false) ||
            (latestBanners?.docs.isNotEmpty ?? false);
        if (sections.isEmpty) sections = HomeFeedSeed.defaultSections();
        if (banners.isEmpty) banners = HomeFeedSeed.defaultBanners();

        controller.add(
          HomeFeedSnapshot(
            sections: sections,
            banners: banners,
            fromRemote: fromRemote,
          ),
        );
      } catch (e) {
        debugPrint('HomeFeedService.emit error: $e');
        controller.add(
          HomeFeedSnapshot(
            sections: HomeFeedSeed.defaultSections(),
            banners: HomeFeedSeed.defaultBanners(),
          ),
        );
      }
    }

    controller.onListen = () {
      // Immediate local fallback so UI never waits on network.
      controller.add(
        HomeFeedSnapshot(
          sections: HomeFeedSeed.defaultSections(),
          banners: HomeFeedSeed.defaultBanners(),
        ),
      );

      sectionsSub = _db.collection('home_sections').snapshots().listen(
        (snap) {
          latestSections = snap;
          sectionsReady = true;
          emit();
        },
        onError: (Object e) {
          debugPrint('home_sections stream error: $e');
          sectionsReady = true;
          latestSections = null;
          emit();
        },
      );
      bannersSub = _db.collection('promo_banners').snapshots().listen(
        (snap) {
          latestBanners = snap;
          bannersReady = true;
          emit();
        },
        onError: (Object e) {
          debugPrint('promo_banners stream error: $e');
          bannersReady = true;
          latestBanners = null;
          emit();
        },
      );
    };

    controller.onCancel = () async {
      await sectionsSub?.cancel();
      await bannersSub?.cancel();
      sectionsSub = null;
      bannersSub = null;
    };

    return controller.stream;
  }

  /// ترتيب يومي شبه عشوائي للبنرات حسب الوزن — يختلف كل يوم.
  List<HomePromoBanner> rotateForDisplay(
    List<HomePromoBanner> input, {
    int? seed,
  }) {
    if (input.isEmpty) return const [];
    final now = DateTime.now();
    final daySeed =
        seed ?? now.year * 1000 + now.month * 50 + now.day;
    final rng = Random(daySeed);
    final bag = <HomePromoBanner>[];
    for (final b in input) {
      for (var i = 0; i < b.weight; i++) {
        bag.add(b);
      }
    }
    bag.shuffle(rng);
    final seen = <String>{};
    final ordered = <HomePromoBanner>[];
    for (final b in bag) {
      if (seen.add(b.id)) ordered.add(b);
    }
    return ordered;
  }

  Stream<List<HomePromoBanner>> watchBanners() {
    return _db.collection('promo_banners').snapshots().map((snap) {
      final list = snap.docs
          .map((d) => HomePromoBanner.fromMap(d.id, d.data()))
          .toList();
      list.sort((a, b) {
        final p = a.placement.compareTo(b.placement);
        if (p != 0) return p;
        return b.weight.compareTo(a.weight);
      });
      return list;
    });
  }

  Future<String> saveBanner(HomePromoBanner banner, {String? docId}) async {
    final id = (docId ?? banner.id).trim().isEmpty
        ? _db.collection('promo_banners').doc().id
        : (docId ?? banner.id).trim();
    await _db.collection('promo_banners').doc(id).set(
          banner.toMap(),
          SetOptions(merge: true),
        );
    return id;
  }

  Future<void> deleteBanner(String id) async {
    if (id.trim().isEmpty) return;
    await _db.collection('promo_banners').doc(id.trim()).delete();
  }

  Future<void> seedDefaults({bool overwrite = false}) async {
    final sections = HomeFeedSeed.defaultSections();
    final banners = HomeFeedSeed.defaultBanners();
    final batch = _db.batch();
    var ops = 0;

    for (final s in sections) {
      final ref = _db.collection('home_sections').doc(s.id);
      if (!overwrite && (await ref.get()).exists) continue;
      batch.set(ref, s.toMap(), SetOptions(merge: true));
      ops++;
    }
    for (final b in banners) {
      final ref = _db.collection('promo_banners').doc(b.id);
      if (!overwrite && (await ref.get()).exists) continue;
      batch.set(ref, b.toMap(), SetOptions(merge: true));
      ops++;
    }
    if (ops > 0) await batch.commit();
  }
}

/// خيارات الوجهات الداخلية لاختيار الأدمن من القائمة.
class HomeAdRouteOption {
  final String id;
  final String labelAr;
  final String labelEn;

  const HomeAdRouteOption(this.id, this.labelAr, this.labelEn);
}

const homeAdRouteOptions = <HomeAdRouteOption>[
  HomeAdRouteOption('supervisors', 'المشرفون', 'Supervisors'),
  HomeAdRouteOption('matchmaking', 'المطابقة الذكية', 'Smart matchmaking'),
  HomeAdRouteOption('ideas', 'سوق الأفكار', 'Research ideas'),
  HomeAdRouteOption('research_path', 'مسار البحث الذكي', 'Research path'),
  HomeAdRouteOption('labs', 'المختبرات', 'Labs'),
  HomeAdRouteOption('store', 'المتجر', 'Store'),
  HomeAdRouteOption('community', 'المجتمع', 'Community'),
  HomeAdRouteOption('ai', 'المساعد الذكي', 'AI advisor'),
  HomeAdRouteOption('writing', 'خدمات الكتابة', 'Writing'),
  HomeAdRouteOption('thesis_studio', 'استوديو الرسالة', 'Thesis Studio'),
  HomeAdRouteOption('integrity', 'نزاهة أكاديمية', 'Integrity'),
  HomeAdRouteOption('publish', 'النشر', 'Publish'),
  HomeAdRouteOption('fund', 'صندوق التمويل', 'Research fund'),
  HomeAdRouteOption('news', 'أخبار علمية', 'Science news'),
];
