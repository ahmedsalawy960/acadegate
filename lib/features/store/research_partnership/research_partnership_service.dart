import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/escrow/payment_status.dart';
import '../../../core/locale/app_translate.dart';
import '../../../core/payments/payment_method.dart';
import '../../notifications/notification_service.dart';
import '../store_cart_service.dart';
import '../store_order_service.dart';
import 'research_partnership_models.dart';

class ResearchPartnershipService {
  ResearchPartnershipService._();
  static final ResearchPartnershipService instance =
      ResearchPartnershipService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('store_research_partnerships');

  String _displayName(User user) =>
      user.displayName ??
      user.email?.split('@').first ??
      appTr('باحث', 'Researcher');

  Future<String> createFromCart({
    required List<StoreCartItem> items,
    required String title,
    required String rightsText,
    required String hostReceiverNote,
    required num sharePrice,
    required int minShares,
    required int deadlineDays,
    int hostShares = 0,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr('يجب تسجيل الدخول', 'You must sign in'));
    }
    final escrow = items
        .where((e) => !e.isDirectoryListing && e.price > 0 && e.sellerId.isNotEmpty)
        .toList();
    if (escrow.isEmpty) {
      throw Exception(
        appTr(
          'لا توجد أصناف قابلة للشراكة في العربة',
          'No partnership-eligible items in the cart',
        ),
      );
    }
    final t = title.trim();
    if (t.length < 5) {
      throw Exception(appTr('أدخل عنواناً أوضح', 'Enter a clearer title'));
    }
    final rights = rightsText.trim();
    if (rights.length < 20) {
      throw Exception(
        appTr(
          'وضّح حقوق المساهمين (استخدام / نتائج / نشر) بتفصيل أكثر',
          'Clarify contributor rights in more detail',
        ),
      );
    }
    final receiver = hostReceiverNote.trim();
    if (receiver.length < 8) {
      throw Exception(
        appTr(
          'أضف بيانات التحويل للمستضيف (محفظة/حساب)',
          'Add host payment instructions (wallet/account)',
        ),
      );
    }
    if (sharePrice <= 0) {
      throw Exception(appTr('سعر الحصة غير صالح', 'Invalid share price'));
    }
    final min = minShares < 1 ? 1 : minShares;
    final days = deadlineDays.clamp(3, 90);
    final lines = escrow.map(PartnershipCartLine.fromCartItem).toList();
    final goal = lines.fold<num>(0, (s, e) => s + e.lineTotal);
    if (goal <= 0) {
      throw Exception(appTr('قيمة السلة غير صالحة', 'Invalid cart total'));
    }
    if (sharePrice > goal) {
      throw Exception(
        appTr(
          'سعر الحصة أكبر من قيمة السلة',
          'Share price exceeds cart total',
        ),
      );
    }

    final hostSharesClamped = hostShares.clamp(0, (goal / sharePrice).floor());
    final hostAmount = sharePrice * hostSharesClamped;
    final hostName = _displayName(user);
    final deadline = DateTime.now().add(Duration(days: days));

    final docRef = _col.doc();
    final batch = _db.batch();
    batch.set(docRef, {
      'title': t,
      'hostId': user.uid,
      'hostName': hostName,
      'hostReceiverNote': receiver,
      'rightsText': rights,
      'goalAmount': goal,
      'sharePrice': sharePrice,
      'minShares': min,
      'raisedAmount': hostAmount,
      'status': hostAmount >= goal ? 'funded' : 'open',
      'deadline': Timestamp.fromDate(deadline),
      'items': lines.map((e) => e.toMap()).toList(),
      'participantIds': [user.uid],
      'storeOrderIds': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
      if (hostAmount >= goal) 'fundedAt': FieldValue.serverTimestamp(),
    });

    if (hostSharesClamped > 0) {
      batch.set(docRef.collection('contributions').doc(user.uid), {
        'userId': user.uid,
        'userName': hostName,
        'shares': hostSharesClamped,
        'amount': hostAmount,
        'paymentStatus': PaymentStatus.held,
        'paymentMethod': PaymentMethod.manual,
        'createdAt': FieldValue.serverTimestamp(),
        'confirmedAt': FieldValue.serverTimestamp(),
        'isHostSeed': true,
      });
    }

    await batch.commit();

    if (hostAmount >= goal) {
      await placeStoreOrders(docRef.id);
    }

    return docRef.id;
  }

  Stream<List<ResearchPartnership>> watchOpen({int limit = 40}) {
    return _col
        .where('status', isEqualTo: 'open')
        .limit(limit)
        .snapshots()
        .map((s) {
      final list = s.docs.map(ResearchPartnership.fromDoc).toList()
        ..sort((a, b) {
          final aAt = a.createdAt;
          final bAt = b.createdAt;
          if (aAt == null && bAt == null) return 0;
          if (aAt == null) return 1;
          if (bAt == null) return -1;
          return bAt.compareTo(aAt);
        });
      return list;
    });
  }

  Stream<List<ResearchPartnership>> watchMine() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Stream.value(const []);
    }
    return _col
        .where('participantIds', arrayContains: uid)
        .limit(40)
        .snapshots()
        .map((s) {
      final list = s.docs.map(ResearchPartnership.fromDoc).toList()
        ..sort((a, b) {
          final aAt = a.createdAt;
          final bAt = b.createdAt;
          if (aAt == null && bAt == null) return 0;
          if (aAt == null) return 1;
          if (bAt == null) return -1;
          return bAt.compareTo(aAt);
        });
      return list;
    });
  }

  Stream<ResearchPartnership?> watchById(String id) {
    return _col.doc(id).snapshots().map((d) {
      if (!d.exists) return null;
      return ResearchPartnership.fromDoc(d);
    });
  }

  Future<ResearchPartnership?> getById(String id) async {
    final d = await _col.doc(id).get();
    if (!d.exists) return null;
    return ResearchPartnership.fromDoc(d);
  }

  Stream<List<ResearchPartnershipContribution>> watchContributions(
    String partnershipId,
  ) {
    return _col
        .doc(partnershipId)
        .collection('contributions')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map(ResearchPartnershipContribution.fromDoc)
              .toList(),
        );
  }

  Stream<List<ResearchPartnershipMessage>> watchMessages(
    String partnershipId,
  ) {
    return _col
        .doc(partnershipId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limit(200)
        .snapshots()
        .map(
          (s) =>
              s.docs.map(ResearchPartnershipMessage.fromDoc).toList(),
        );
  }

  Future<void> sendMessage({
    required String partnershipId,
    required String text,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr('يجب تسجيل الدخول', 'You must sign in'));
    }
    final body = text.trim();
    if (body.isEmpty) return;
    if (body.length > 2000) {
      throw Exception(appTr('الرسالة طويلة جداً', 'Message is too long'));
    }

    final snap = await _col.doc(partnershipId).get();
    if (!snap.exists) {
      throw Exception(appTr('الفرصة غير موجودة', 'Opportunity not found'));
    }
    final p = ResearchPartnership.fromDoc(snap);
    if (!p.participantIds.contains(user.uid) && p.hostId != user.uid) {
      throw Exception(
        appTr('انضم للشراكة أولاً للمراسلة', 'Join the partnership first'),
      );
    }

    await _col.doc(partnershipId).collection('messages').add({
      'senderId': user.uid,
      'senderName': _displayName(user),
      'text': body,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// المساهمة بحصة/حصص — تحويل يدوي بانتظار تأكيد المضيف.
  Future<void> joinWithShares({
    required String partnershipId,
    required int shares,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr('يجب تسجيل الدخول', 'You must sign in'));
    }
    if (shares < 1) {
      throw Exception(appTr('عدد الحصص غير صالح', 'Invalid share count'));
    }

    final ref = _col.doc(partnershipId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw Exception(appTr('الفرصة غير موجودة', 'Opportunity not found'));
      }
      final p = ResearchPartnership.fromDoc(snap);
      if (!p.isOpen) {
        throw Exception(
          appTr('هذه الفرصة لم تعد مفتوحة', 'This opportunity is no longer open'),
        );
      }
      if (p.deadline != null && p.deadline!.isBefore(DateTime.now())) {
        throw Exception(appTr('انتهت مهلة الشراكة', 'Partnership deadline passed'));
      }
      if (shares < p.minShares) {
        throw Exception(
          appTr(
            'الحد الأدنى للحصص: ${p.minShares}',
            'Minimum shares: ${p.minShares}',
          ),
        );
      }
      if (p.hostId == user.uid) {
        throw Exception(
          appTr(
            'المضيف يضيف حصصه عند الإنشاء فقط',
            'Host can only seed shares at creation',
          ),
        );
      }

      final contribRef = ref.collection('contributions').doc(user.uid);
      final existing = await tx.get(contribRef);
      if (existing.exists) {
        final st = existing.data()?['paymentStatus']?.toString();
        if (st == PaymentStatus.held || st == PaymentStatus.pending) {
          throw Exception(
            appTr(
              'لديك مساهمة قائمة بالفعل في هذه الفرصة',
              'You already have a contribution on this opportunity',
            ),
          );
        }
      }

      final amount = p.sharePrice * shares;
      final remaining = p.goalAmount - p.raisedAmount;
      if (amount > remaining + 0.01) {
        throw Exception(
          appTr(
            'الحصص تتجاوز المتبقي (${remaining.toStringAsFixed(0)} ج.م)',
            'Shares exceed remaining (${remaining.toStringAsFixed(0)} EGP)',
          ),
        );
      }

      tx.set(contribRef, {
        'userId': user.uid,
        'userName': _displayName(user),
        'shares': shares,
        'amount': amount,
        'paymentStatus': PaymentStatus.pending,
        'paymentMethod': PaymentMethod.manual,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(ref, {
        'participantIds': FieldValue.arrayUnion([user.uid]),
      });
    });

    final after = await getById(partnershipId);
    if (after != null && after.hostId.isNotEmpty) {
      await NotificationService.instance.send(
        userId: after.hostId,
        title: appTr('مساهمة جديدة في شراكة بحثية', 'New research partnership contribution'),
        body: '${_displayName(user)} — ${after.title}',
        type: 'store_order',
        contextId: partnershipId,
        contextType: 'store_research_partnership',
      );
    }
  }

  /// المضيف يؤكد استلام تحويل المساهم.
  Future<void> confirmContribution({
    required String partnershipId,
    required String contributorId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr('يجب تسجيل الدخول', 'You must sign in'));
    }

    final ref = _col.doc(partnershipId);
    var shouldOrder = false;
    String? contributorUid;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw Exception(appTr('الفرصة غير موجودة', 'Opportunity not found'));
      }
      final p = ResearchPartnership.fromDoc(snap);
      if (p.hostId != user.uid) {
        throw Exception(
          appTr('فقط المضيف يؤكد التحويلات', 'Only the host can confirm transfers'),
        );
      }
      final contribRef = ref.collection('contributions').doc(contributorId);
      final cSnap = await tx.get(contribRef);
      if (!cSnap.exists) {
        throw Exception(appTr('المساهمة غير موجودة', 'Contribution not found'));
      }
      final c = ResearchPartnershipContribution.fromDoc(cSnap);
      if (c.isConfirmed) return;
      if (!c.isPending) {
        throw Exception(
          appTr('حالة المساهمة غير قابلة للتأكيد', 'Contribution cannot be confirmed'),
        );
      }

      final newRaised = p.raisedAmount + c.amount;
      final funded = newRaised >= p.goalAmount;
      tx.update(contribRef, {
        'paymentStatus': PaymentStatus.held,
        'confirmedAt': FieldValue.serverTimestamp(),
      });
      tx.update(ref, {
        'raisedAmount': newRaised,
        if (funded && p.status == 'open') ...{
          'status': 'funded',
          'fundedAt': FieldValue.serverTimestamp(),
        },
      });
      shouldOrder = funded && p.status == 'open';
      contributorUid = c.userId;
    });

    if (contributorUid != null && contributorUid!.isNotEmpty) {
      await NotificationService.instance.send(
        userId: contributorUid!,
        title: appTr('تم تأكيد مساهمتك', 'Your contribution was confirmed'),
        body: appTr(
          'المضيف أكّد استلام التحويل — الشراكة البحثية',
          'Host confirmed your transfer — research partnership',
        ),
        type: 'payment_held',
        contextId: partnershipId,
        contextType: 'store_research_partnership',
      );
    }

    if (shouldOrder) {
      await placeStoreOrders(partnershipId);
    }
  }

  /// عند اكتمال التمويل: إنشاء طلبات متجر عادية باسم المضيف (المستخدم الحالي).
  Future<List<String>> placeStoreOrders(String partnershipId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr('يجب تسجيل الدخول', 'You must sign in'));
    }

    final ref = _col.doc(partnershipId);
    final snap = await ref.get();
    if (!snap.exists) {
      throw Exception(appTr('الفرصة غير موجودة', 'Opportunity not found'));
    }
    final p = ResearchPartnership.fromDoc(snap);
    if (p.hostId != user.uid) {
      throw Exception(
        appTr(
          'فقط المضيف ينشئ طلبات الشراء',
          'Only the host can place store orders',
        ),
      );
    }
    if (p.isOrdered && p.storeOrderIds.isNotEmpty) {
      return p.storeOrderIds;
    }
    if (p.raisedAmount + 0.01 < p.goalAmount && p.status != 'funded') {
      throw Exception(
        appTr('التمويل غير مكتمل بعد', 'Funding is not complete yet'),
      );
    }

    final orderIds = <String>[];
    for (final line in p.items) {
      for (var i = 0; i < line.quantity; i++) {
        final id = await StoreOrderService.instance.createOrder(
          productId: line.productId,
          productName: line.name,
          price: line.price,
          sellerId: line.sellerId,
          paymentMethod: PaymentMethod.manual,
        );
        orderIds.add(id);
      }
    }

    await ref.update({
      'status': 'ordered',
      'storeOrderIds': orderIds,
      'orderedAt': FieldValue.serverTimestamp(),
      if (p.status == 'open') 'fundedAt': FieldValue.serverTimestamp(),
    });

    for (final uid in p.participantIds) {
      if (uid == user.uid) continue;
      await NotificationService.instance.send(
        userId: uid,
        title: appTr('اكتملت الشراكة — تم إنشاء الطلبات', 'Partnership funded — orders placed'),
        body: p.title,
        type: 'store_order',
        contextId: partnershipId,
        contextType: 'store_research_partnership',
      );
    }

    return orderIds;
  }

  Future<void> cancelOpen(String partnershipId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr('يجب تسجيل الدخول', 'You must sign in'));
    }
    final ref = _col.doc(partnershipId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final p = ResearchPartnership.fromDoc(snap);
    if (p.hostId != user.uid) {
      throw Exception(appTr('غير مسموح', 'Not allowed'));
    }
    if (!p.isOpen) {
      throw Exception(
        appTr('لا يمكن إلغاء فرصة غير مفتوحة', 'Cannot cancel a non-open opportunity'),
      );
    }
    await ref.update({
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
