import 'package:cloud_firestore/cloud_firestore.dart';

import '../store_cart_service.dart';

/// عنصر محفوظ داخل فرصة الشراكة البحثية.
class PartnershipCartLine {
  final String productId;
  final String name;
  final num price;
  final String storeName;
  final String sellerId;
  final String? imageUrl;
  final int quantity;
  final String? category;

  const PartnershipCartLine({
    required this.productId,
    required this.name,
    required this.price,
    required this.storeName,
    required this.sellerId,
    this.imageUrl,
    this.quantity = 1,
    this.category,
  });

  num get lineTotal => price * quantity;

  factory PartnershipCartLine.fromCartItem(StoreCartItem item) =>
      PartnershipCartLine(
        productId: item.productId,
        name: item.name,
        price: item.price,
        storeName: item.storeName,
        sellerId: item.sellerId,
        imageUrl: item.imageUrl,
        quantity: item.quantity,
        category: item.category,
      );

  factory PartnershipCartLine.fromMap(Map<String, dynamic> m) =>
      PartnershipCartLine(
        productId: m['productId']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        price: m['price'] as num? ?? 0,
        storeName: m['storeName']?.toString() ?? '',
        sellerId: m['sellerId']?.toString() ?? '',
        imageUrl: m['imageUrl']?.toString(),
        quantity: (m['quantity'] as num?)?.toInt() ?? 1,
        category: m['category']?.toString(),
      );

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'name': name,
        'price': price,
        'storeName': storeName,
        'sellerId': sellerId,
        if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
        'quantity': quantity,
        if (category != null && category!.isNotEmpty) 'category': category,
      };
}

class ResearchPartnershipContribution {
  final String id;
  final String userId;
  final String userName;
  final int shares;
  final num amount;
  final String paymentStatus;
  final String paymentMethod;
  final DateTime? createdAt;
  final DateTime? confirmedAt;

  const ResearchPartnershipContribution({
    required this.id,
    required this.userId,
    required this.userName,
    required this.shares,
    required this.amount,
    required this.paymentStatus,
    this.paymentMethod = 'manual',
    this.createdAt,
    this.confirmedAt,
  });

  bool get isPending => paymentStatus == 'pending_payment';
  bool get isConfirmed => paymentStatus == 'paid_held';

  factory ResearchPartnershipContribution.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return ResearchPartnershipContribution(
      id: doc.id,
      userId: d['userId']?.toString() ?? '',
      userName: d['userName']?.toString() ?? '',
      shares: (d['shares'] as num?)?.toInt() ?? 0,
      amount: d['amount'] as num? ?? 0,
      paymentStatus: d['paymentStatus']?.toString() ?? 'pending_payment',
      paymentMethod: d['paymentMethod']?.toString() ?? 'manual',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      confirmedAt: (d['confirmedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class ResearchPartnershipMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime? createdAt;

  const ResearchPartnershipMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.createdAt,
  });

  factory ResearchPartnershipMessage.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return ResearchPartnershipMessage(
      id: doc.id,
      senderId: d['senderId']?.toString() ?? '',
      senderName: d['senderName']?.toString() ?? '',
      text: d['text']?.toString() ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class ResearchPartnership {
  final String id;
  final String title;
  final String hostId;
  final String hostName;
  final String hostReceiverNote;
  final String rightsText;
  final num goalAmount;
  final num sharePrice;
  final int minShares;
  final num raisedAmount;
  final String status;
  final DateTime? deadline;
  final List<PartnershipCartLine> items;
  final List<String> participantIds;
  final List<String> storeOrderIds;
  final DateTime? createdAt;
  final DateTime? fundedAt;
  final DateTime? orderedAt;

  const ResearchPartnership({
    required this.id,
    required this.title,
    required this.hostId,
    required this.hostName,
    required this.hostReceiverNote,
    required this.rightsText,
    required this.goalAmount,
    required this.sharePrice,
    required this.minShares,
    required this.raisedAmount,
    required this.status,
    this.deadline,
    required this.items,
    required this.participantIds,
    this.storeOrderIds = const [],
    this.createdAt,
    this.fundedAt,
    this.orderedAt,
  });

  bool get isOpen => status == 'open';
  bool get isFunded => status == 'funded' || status == 'ordered';
  bool get isOrdered => status == 'ordered';
  double get progress {
    if (goalAmount <= 0) return 0;
    final p = raisedAmount / goalAmount;
    if (p < 0) return 0;
    if (p > 1) return 1;
    return p.toDouble();
  }

  int get remainingShares {
    if (sharePrice <= 0) return 0;
    final left = goalAmount - raisedAmount;
    if (left <= 0) return 0;
    return (left / sharePrice).ceil();
  }

  factory ResearchPartnership.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    final rawItems = d['items'];
    final items = <PartnershipCartLine>[];
    if (rawItems is List) {
      for (final e in rawItems) {
        if (e is Map) {
          items.add(
            PartnershipCartLine.fromMap(Map<String, dynamic>.from(e)),
          );
        }
      }
    }
    return ResearchPartnership(
      id: doc.id,
      title: d['title']?.toString() ?? '',
      hostId: d['hostId']?.toString() ?? '',
      hostName: d['hostName']?.toString() ?? '',
      hostReceiverNote: d['hostReceiverNote']?.toString() ?? '',
      rightsText: d['rightsText']?.toString() ?? '',
      goalAmount: d['goalAmount'] as num? ?? 0,
      sharePrice: d['sharePrice'] as num? ?? 0,
      minShares: (d['minShares'] as num?)?.toInt() ?? 1,
      raisedAmount: d['raisedAmount'] as num? ?? 0,
      status: d['status']?.toString() ?? 'open',
      deadline: (d['deadline'] as Timestamp?)?.toDate(),
      items: items,
      participantIds: (d['participantIds'] is List)
          ? (d['participantIds'] as List).map((e) => e.toString()).toList()
          : const [],
      storeOrderIds: (d['storeOrderIds'] is List)
          ? (d['storeOrderIds'] as List).map((e) => e.toString()).toList()
          : const [],
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      fundedAt: (d['fundedAt'] as Timestamp?)?.toDate(),
      orderedAt: (d['orderedAt'] as Timestamp?)?.toDate(),
    );
  }
}
