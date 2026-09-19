import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/locale/app_translate.dart';

class ProductQaItem {
  final String id;
  final String question;
  final String answer;
  final String askerId;
  final String askerName;
  final String? answererId;
  final DateTime? createdAt;
  final DateTime? answeredAt;

  const ProductQaItem({
    required this.id,
    required this.question,
    this.answer = '',
    required this.askerId,
    required this.askerName,
    this.answererId,
    this.createdAt,
    this.answeredAt,
  });

  bool get hasAnswer => answer.trim().isNotEmpty;

  factory ProductQaItem.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();
    return ProductQaItem(
      id: doc.id,
      question: d['question']?.toString() ?? '',
      answer: d['answer']?.toString() ?? '',
      askerId: d['askerId']?.toString() ?? '',
      askerName: d['askerName']?.toString() ?? '',
      answererId: d['answererId']?.toString(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      answeredAt: (d['answeredAt'] as Timestamp?)?.toDate(),
    );
  }
}

class ProductQaService {
  ProductQaService._();
  static final ProductQaService instance = ProductQaService._();

  CollectionReference<Map<String, dynamic>> _col(String productId) =>
      FirebaseFirestore.instance
          .collection('product')
          .doc(productId)
          .collection('qa');

  Stream<List<ProductQaItem>> watch(String productId) {
    return _col(productId).limit(40).snapshots().map((s) {
      final list = s.docs.map(ProductQaItem.fromDoc).toList()
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

  Future<void> ask({
    required String productId,
    required String question,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr('يجب تسجيل الدخول', 'You must sign in'));
    }
    final q = question.trim();
    if (q.length < 5) {
      throw Exception(appTr('السؤال قصير جداً', 'Question is too short'));
    }
    await _col(productId).add({
      'question': q,
      'answer': '',
      'askerId': user.uid,
      'askerName': user.displayName ??
          user.email?.split('@').first ??
          appTr('باحث', 'Researcher'),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> answer({
    required String productId,
    required String qaId,
    required String answer,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr('يجب تسجيل الدخول', 'You must sign in'));
    }
    final a = answer.trim();
    if (a.isEmpty) {
      throw Exception(appTr('أدخل إجابة', 'Enter an answer'));
    }
    await _col(productId).doc(qaId).update({
      'answer': a,
      'answererId': user.uid,
      'answeredAt': FieldValue.serverTimestamp(),
    });
  }
}
