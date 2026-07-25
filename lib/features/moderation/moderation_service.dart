import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/locale/l10n_lookup.dart';
import 'approval_status.dart';

class PendingItem {
  final String id;
  final String collection;
  final String title;
  final String subtitle;
  final String ownerId;
  final DateTime? createdAt;
  final Map<String, dynamic> data;

  const PendingItem({
    required this.id,
    required this.collection,
    required this.title,
    required this.subtitle,
    required this.ownerId,
    required this.data,
    this.createdAt,
  });
}

class ModerationStats {
  final int pendingSupervisors;
  final int pendingLabs;
  final int pendingProducts;
  final int pendingIdeas;
  final int pendingCommunityPosts;
  final int totalUsers;
  final Map<String, int> usersByRole;

  const ModerationStats({
    this.pendingSupervisors = 0,
    this.pendingLabs = 0,
    this.pendingProducts = 0,
    this.pendingIdeas = 0,
    this.pendingCommunityPosts = 0,
    this.totalUsers = 0,
    this.usersByRole = const {},
  });

  int get totalPending =>
      pendingSupervisors +
      pendingLabs +
      pendingProducts +
      pendingIdeas +
      pendingCommunityPosts;
}

class ModerationService {
  ModerationService._();

  static final ModerationService instance = ModerationService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const collections = [
    'supervisors',
    'labs',
    'product',
    'research_ideas',
    'community_posts',
  ];

  Stream<List<PendingItem>> watchPendingItems() {
    final controller = StreamController<List<PendingItem>>.broadcast();
    final latest = <String, List<PendingItem>>{};
    final subscriptions = <StreamSubscription<dynamic>>[];

    void emitMerged() {
      if (controller.isClosed) return;
      final merged = latest.values.expand((items) => items).toList()
        ..sort(
          (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
        );
      controller.add(merged);
    }

    controller.onListen = () {
      for (final collection in collections) {
        subscriptions.add(
          _db
              .collection(collection)
              .where('approvalStatus', isEqualTo: ApprovalStatus.pending)
              .snapshots()
              .listen(
            (snapshot) {
              latest[collection] = snapshot.docs
                  .map((doc) => _fromDoc(doc, collection))
                  .toList();
              emitMerged();
            },
            onError: (_) {
              latest[collection] = [];
              emitMerged();
            },
          ),
        );
      }
    };

    controller.onCancel = () async {
      for (final sub in subscriptions) {
        await sub.cancel();
      }
      subscriptions.clear();
    };

    return controller.stream;
  }

  Stream<ModerationStats> watchStats({
    required Stream<List<PendingItem>> pendingStream,
    required Stream<List<Map<String, dynamic>>> usersStream,
  }) {
    return Stream.multi((controller) {
      List<PendingItem> pending = [];
      List<Map<String, dynamic>> users = [];

      void emit() {
        final roleCounts = <String, int>{};
        for (final user in users) {
          final role = user['role']?.toString() ?? 'student';
          roleCounts[role] = (roleCounts[role] ?? 0) + 1;
        }

        controller.add(
          ModerationStats(
            pendingSupervisors:
                pending.where((i) => i.collection == 'supervisors').length,
            pendingLabs: pending.where((i) => i.collection == 'labs').length,
            pendingProducts:
                pending.where((i) => i.collection == 'product').length,
            pendingIdeas:
                pending.where((i) => i.collection == 'research_ideas').length,
            pendingCommunityPosts:
                pending.where((i) => i.collection == 'community_posts').length,
            totalUsers: users.length,
            usersByRole: roleCounts,
          ),
        );
      }

      final pendingSub = pendingStream.listen((items) {
        pending = items;
        emit();
      });

      final usersSub = usersStream.listen((items) {
        users = items;
        emit();
      });

      controller.onCancel = () async {
        await pendingSub.cancel();
        await usersSub.cancel();
      };
    });
  }

  PendingItem _fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String collection,
  ) {
    final data = doc.data();
    DateTime? created;
    final rawDate = data['createdAt'];
    if (rawDate is Timestamp) {
      created = rawDate.toDate();
    }

    return PendingItem(
      id: doc.id,
      collection: collection,
      title: _titleFor(collection, data),
      subtitle: _subtitleFor(collection, data),
      ownerId: _ownerId(data),
      data: data,
      createdAt: created,
    );
  }

  String _ownerId(Map<String, dynamic> data) {
    return data['ownerId']?.toString() ??
        data['createdBy']?.toString() ??
        data['publisherId']?.toString() ??
        data['authorId']?.toString() ??
        '';
  }

  String _titleFor(String collection, Map<String, dynamic> data) {
    return switch (collection) {
      'supervisors' =>
        data['name']?.toString() ?? L10nLookup.supervisor,
      'labs' => data['name']?.toString() ?? L10nLookup.lab,
      'product' => data['name']?.toString() ?? L10nLookup.product,
      'research_ideas' =>
        data['title']?.toString() ?? L10nLookup.researchIdea,
      'community_posts' =>
        data['title']?.toString() ?? L10nLookup.communityPost,
      _ => L10nLookup.item,
    };
  }

  String _subtitleFor(String collection, Map<String, dynamic> data) {
    return switch (collection) {
      'supervisors' =>
        '${data['university'] ?? ''} • ${data['speciality'] ?? ''}',
      'labs' => data['location']?.toString() ?? '',
      'product' => L10nLookup.currencyPriceCategory(
        data['category']?.toString() ?? '',
        (data['price'] as num?) ?? 0,
      ),
      'research_ideas' => data['provider']?.toString() ?? '',
      'community_posts' =>
        '${data['roomId'] ?? ''} • ${data['type'] ?? ''}',
      _ => '',
    };
  }

  String collectionLabel(String collection) =>
      L10nLookup.collectionLabel(collection);

  List<MapEntry<String, String>> detailFields(PendingItem item) {
    final data = item.data;
    return switch (item.collection) {
      'supervisors' => [
        MapEntry(L10nLookup.moderationDetailField('name'),
            data['name']?.toString() ?? ''),
        MapEntry(L10nLookup.moderationDetailField('university'),
            data['university']?.toString() ?? ''),
        MapEntry(L10nLookup.moderationDetailField('speciality'),
            data['speciality']?.toString() ?? ''),
        MapEntry(L10nLookup.moderationDetailField('faculty'),
            data['faculty']?.toString() ?? ''),
        MapEntry(L10nLookup.moderationDetailField('category'),
            data['category']?.toString() ?? ''),
        MapEntry(L10nLookup.moderationDetailField('methodology'),
            _formatList(data['methodologies'])),
        MapEntry(
          L10nLookup.moderationDetailField('available'),
          data['isAvailable'] == true ? L10nLookup.yes : L10nLookup.no,
        ),
        MapEntry(L10nLookup.moderationDetailField('bio'),
            data['bio']?.toString() ?? ''),
        MapEntry(L10nLookup.moderationDetailField('tags'),
            _formatList(data['tags'])),
      ],
      'labs' => [
        MapEntry(L10nLookup.moderationDetailField('name'),
            data['name']?.toString() ?? ''),
        MapEntry(L10nLookup.moderationDetailField('location'),
            data['location']?.toString() ?? ''),
        MapEntry(L10nLookup.moderationDetailField('city'),
            data['city']?.toString() ?? ''),
        MapEntry(L10nLookup.moderationDetailField('university'),
            data['university']?.toString() ?? ''),
        MapEntry(L10nLookup.moderationDetailField('equipment'),
            data['equipment']?.toString() ?? ''),
        MapEntry(L10nLookup.moderationDetailField('equipmentList'),
            _formatEquipmentList(data['equipmentList'])),
        MapEntry(L10nLookup.moderationDetailField('tags'),
            _formatList(data['tags'])),
      ],
      'product' => [
        MapEntry(L10nLookup.moderationDetailField('name'),
            data['name']?.toString() ?? ''),
        MapEntry(
          L10nLookup.moderationDetailField('price'),
          L10nLookup.currencyEgp((data['price'] as num?) ?? 0),
        ),
        MapEntry(L10nLookup.moderationDetailField('department'),
            data['category']?.toString() ?? ''),
        MapEntry(L10nLookup.moderationDetailField('description'),
            data['description']?.toString() ?? ''),
        MapEntry(L10nLookup.moderationDetailField('store'),
            data['storeName']?.toString() ?? ''),
        MapEntry(L10nLookup.moderationDetailField('contact'),
            data['contact']?.toString() ?? ''),
      ],
      'research_ideas' => [
        MapEntry(L10nLookup.moderationDetailField('title'),
            data['title']?.toString() ?? ''),
        MapEntry(L10nLookup.moderationDetailField('provider'),
            data['provider']?.toString() ?? ''),
        MapEntry(L10nLookup.moderationDetailField('details'),
            data['details']?.toString() ?? ''),
        MapEntry(L10nLookup.moderationDetailField('budget'),
            data['budget']?.toString() ?? ''),
        MapEntry(L10nLookup.moderationDetailField('status'),
            data['status']?.toString() ?? ''),
        MapEntry(L10nLookup.moderationDetailField('tags'),
            _formatList(data['tags'])),
      ],
      'community_posts' => [
        MapEntry(L10nLookup.moderationDetailField('title'),
            data['title']?.toString() ?? ''),
        MapEntry(L10nLookup.moderationDetailField('room'),
            data['roomId']?.toString() ?? ''),
        MapEntry(L10nLookup.moderationDetailField('type'),
            data['type']?.toString() ?? ''),
        MapEntry(L10nLookup.moderationDetailField('content'),
            data['body']?.toString() ?? ''),
        MapEntry(L10nLookup.moderationDetailField('author'),
            data['authorName']?.toString() ?? ''),
        MapEntry(L10nLookup.moderationDetailField('university'),
            data['university']?.toString() ?? ''),
        MapEntry(L10nLookup.moderationDetailField('eventDate'),
            data['eventDate']?.toString() ?? ''),
        MapEntry(L10nLookup.moderationDetailField('tags'),
            _formatList(data['tags'])),
      ],
      _ => [MapEntry(L10nLookup.data, data.toString())],
    };
  }

  String _formatList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).join(L10nLookup.listSeparator());
    }
    return value?.toString() ?? '';
  }

  String _formatEquipmentList(dynamic value) {
    if (value is! List) return '';
    final lines = <String>[];
    for (final item in value) {
      if (item is Map) {
        lines.add(
          L10nLookup.equipmentLine(
            item['name']?.toString() ?? '',
            (item['costPerSession'] as num?) ?? 0,
            (item['waitDays'] as num?)?.toInt() ?? 3,
          ),
        );
      }
    }
    return lines.join('\n');
  }

  Future<void> approve(String collection, String id) async {
    final updates = <String, dynamic>{
      'approvalStatus': ApprovalStatus.approved,
      'reviewedAt': FieldValue.serverTimestamp(),
    };

    if (collection == 'supervisors') {
      final snap = await _db.collection(collection).doc(id).get();
      final data = snap.data() ?? {};
      final orcid = data['orcid']?.toString() ?? '';
      final uniEmail = data['universityEmail']?.toString() ?? '';
      if (orcid.isNotEmpty || uniEmail.contains('.edu')) {
        updates['verificationStatus'] = 'verified';
      } else {
        updates['verificationStatus'] = 'unverified';
      }
    }

    await _db.collection(collection).doc(id).update(updates);
  }

  Future<void> reject(String collection, String id, {String? reason}) async {
    await _db.collection(collection).doc(id).update({
      'approvalStatus': ApprovalStatus.rejected,
      'rejectionReason': reason ?? '',
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }
}
