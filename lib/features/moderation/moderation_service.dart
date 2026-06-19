import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
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
      'supervisors' => data['name']?.toString() ?? 'مشرف',
      'labs' => data['name']?.toString() ?? 'مختبر',
      'product' => data['name']?.toString() ?? 'منتج',
      'research_ideas' => data['title']?.toString() ?? 'فكرة بحثية',
      'community_posts' => data['title']?.toString() ?? 'منشور',
      _ => 'عنصر',
    };
  }

  String _subtitleFor(String collection, Map<String, dynamic> data) {
    return switch (collection) {
      'supervisors' =>
        '${data['university'] ?? ''} • ${data['speciality'] ?? ''}',
      'labs' => data['location']?.toString() ?? '',
      'product' => '${data['category'] ?? ''} • ${data['price'] ?? 0} ج.م',
      'research_ideas' => data['provider']?.toString() ?? '',
      'community_posts' =>
        '${data['roomId'] ?? ''} • ${data['type'] ?? ''}',
      _ => '',
    };
  }

  String collectionLabel(String collection) {
    return switch (collection) {
      'supervisors' => 'مشرف',
      'labs' => 'مختبر',
      'product' => 'منتج',
      'research_ideas' => 'فكرة بحثية',
      'community_posts' => 'منشور مجتمع',
      _ => collection,
    };
  }

  List<MapEntry<String, String>> detailFields(PendingItem item) {
    final data = item.data;
    return switch (item.collection) {
      'supervisors' => [
        MapEntry('الاسم', data['name']?.toString() ?? ''),
        MapEntry('الجامعة', data['university']?.toString() ?? ''),
        MapEntry('التخصص', data['speciality']?.toString() ?? ''),
        MapEntry('الكلية', data['faculty']?.toString() ?? ''),
        MapEntry('التصنيف', data['category']?.toString() ?? ''),
        MapEntry('المنهجية', _formatList(data['methodologies'])),
        MapEntry('متاح', data['isAvailable'] == true ? 'نعم' : 'لا'),
        MapEntry('نبذة', data['bio']?.toString() ?? ''),
        MapEntry('الوسوم', _formatList(data['tags'])),
      ],
      'labs' => [
        MapEntry('الاسم', data['name']?.toString() ?? ''),
        MapEntry('الموقع', data['location']?.toString() ?? ''),
        MapEntry('المدينة', data['city']?.toString() ?? ''),
        MapEntry('الجامعة', data['university']?.toString() ?? ''),
        MapEntry('الأجهزة', data['equipment']?.toString() ?? ''),
        MapEntry('قائمة الأجهزة', _formatEquipmentList(data['equipmentList'])),
        MapEntry('الوسوم', _formatList(data['tags'])),
      ],
      'product' => [
        MapEntry('الاسم', data['name']?.toString() ?? ''),
        MapEntry('السعر', '${data['price'] ?? 0} ج.م'),
        MapEntry('القسم', data['category']?.toString() ?? ''),
        MapEntry('الوصف', data['description']?.toString() ?? ''),
        MapEntry('المتجر', data['storeName']?.toString() ?? ''),
        MapEntry('التواصل', data['contact']?.toString() ?? ''),
      ],
      'research_ideas' => [
        MapEntry('العنوان', data['title']?.toString() ?? ''),
        MapEntry('الجهة', data['provider']?.toString() ?? ''),
        MapEntry('التفاصيل', data['details']?.toString() ?? ''),
        MapEntry('الميزانية', data['budget']?.toString() ?? ''),
        MapEntry('الحالة', data['status']?.toString() ?? ''),
        MapEntry('الوسوم', _formatList(data['tags'])),
      ],
      'community_posts' => [
        MapEntry('العنوان', data['title']?.toString() ?? ''),
        MapEntry('الغرفة', data['roomId']?.toString() ?? ''),
        MapEntry('النوع', data['type']?.toString() ?? ''),
        MapEntry('المحتوى', data['body']?.toString() ?? ''),
        MapEntry('الكاتب', data['authorName']?.toString() ?? ''),
        MapEntry('الجامعة', data['university']?.toString() ?? ''),
        MapEntry('تاريخ المناقشة', data['eventDate']?.toString() ?? ''),
        MapEntry('الوسوم', _formatList(data['tags'])),
      ],
      _ => [MapEntry('بيانات', data.toString())],
    };
  }

  String _formatList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).join('، ');
    return value?.toString() ?? '';
  }

  String _formatEquipmentList(dynamic value) {
    if (value is! List) return '';
    final lines = <String>[];
    for (final item in value) {
      if (item is Map) {
        lines.add(
          '• ${item['name']} — ${item['costPerSession'] ?? 0} ج.م — انتظار ${item['waitDays'] ?? 3} يوم',
        );
      }
    }
    return lines.join('\n');
  }

  Future<void> approve(String collection, String id) async {
    await _db.collection(collection).doc(id).update({
      'approvalStatus': ApprovalStatus.approved,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reject(String collection, String id, {String? reason}) async {
    await _db.collection(collection).doc(id).update({
      'approvalStatus': ApprovalStatus.rejected,
      'rejectionReason': reason ?? '',
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }
}
