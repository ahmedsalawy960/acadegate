import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/locale/app_translate.dart';

/// The one thesis file for a researcher. Thesis Studio writes it, the
/// assistant reads it, and a linked supervisor can open it.
class ResearchFile {
  final String ownerId;
  final String title;
  final String aim;
  final String field;
  final List<String> questions;
  final List<String> chapters;
  final String supervisorUid;
  final String supervisorName;
  final String studentName;
  final DateTime? updatedAt;

  const ResearchFile({
    required this.ownerId,
    this.title = '',
    this.aim = '',
    this.field = '',
    this.questions = const [],
    this.chapters = const [],
    this.supervisorUid = '',
    this.supervisorName = '',
    this.studentName = '',
    this.updatedAt,
  });

  bool get hasContent =>
      title.trim().isNotEmpty || aim.trim().isNotEmpty || chapters.isNotEmpty;

  /// Text the matcher should prefer over the academic profile.
  String get matchText => [
        title,
        aim,
        field,
        ...questions,
      ].where((part) => part.trim().isNotEmpty).join(' ');

  factory ResearchFile.fromMap(Map<String, dynamic> map, {required String ownerId}) {
    DateTime? updated;
    final raw = map['updatedAt'];
    if (raw is Timestamp) updated = raw.toDate();
    return ResearchFile(
      ownerId: map['ownerId']?.toString().isNotEmpty == true
          ? map['ownerId'].toString()
          : ownerId,
      title: map['title']?.toString() ?? '',
      aim: map['aim']?.toString() ?? '',
      field: map['field']?.toString() ?? '',
      questions: _strings(map['questions']),
      chapters: _strings(map['chapters']),
      supervisorUid: map['supervisorUid']?.toString() ?? '',
      supervisorName: map['supervisorName']?.toString() ?? '',
      studentName: map['studentName']?.toString() ?? '',
      updatedAt: updated,
    );
  }

  static List<String> _strings(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item.toString().trim().isNotEmpty) item.toString().trim(),
    ];
  }

  String promptBlock() {
    if (!hasContent) {
      return appTr(
        'لا يوجد ملف رسالة بعد. إذا سأل عن رسالته فاسأله عن العنوان والهدف باختصار.',
        'No thesis file yet. If they ask about their thesis, ask briefly for the title and aim.',
      );
    }
    final missing = appTr('غير محدد', 'Not set');
    final buffer = StringBuffer()
      ..writeln('${appTr('العنوان', 'Title')}: ${title.isEmpty ? missing : title}')
      ..writeln('${appTr('المجال', 'Field')}: ${field.isEmpty ? missing : field}')
      ..writeln('${appTr('الهدف', 'Aim')}: ${aim.isEmpty ? missing : aim}');
    if (questions.isNotEmpty) {
      buffer.writeln('${appTr('الأسئلة', 'Questions')}: ${questions.take(6).join(' | ')}');
    }
    if (chapters.isNotEmpty) {
      buffer.writeln('${appTr('الفصول', 'Chapters')}: ${chapters.take(12).join(' | ')}');
    }
    if (supervisorName.isNotEmpty) {
      buffer.writeln('${appTr('المشرف المرتبط', 'Linked supervisor')}: $supervisorName');
    }
    return buffer.toString().trim();
  }
}

class ResearchFileService {
  ResearchFileService._();
  static final ResearchFileService instance = ResearchFileService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _files =>
      _db.collection('research_files');

  Stream<ResearchFile?> watchMine() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _files.doc(uid).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      return ResearchFile.fromMap(data, ownerId: uid);
    });
  }

  Stream<List<ResearchFile>> watchForSupervisor() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return _files.where('supervisorUid', isEqualTo: uid).snapshots().map(
          (snap) => snap.docs
              .map((doc) => ResearchFile.fromMap(doc.data(), ownerId: doc.id))
              .toList(),
        );
  }

  Future<void> upsert({
    required String title,
    required String aim,
    required String field,
    required List<String> questions,
    required List<String> chapters,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final studentName = FirebaseAuth.instance.currentUser?.displayName?.trim() ?? '';
    await _files.doc(uid).set({
      'ownerId': uid,
      'title': title.trim(),
      'aim': _clip(aim, 2000),
      'field': field.trim(),
      'questions': questions.take(8).map((q) => _clip(q, 300)).toList(),
      'chapters': chapters.take(16).map((c) => _clip(c, 200)).toList(),
      if (studentName.isNotEmpty) 'studentName': studentName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(mergeFields: [
      'ownerId',
      'title',
      'aim',
      'field',
      'questions',
      'chapters',
      if (studentName.isNotEmpty) 'studentName',
      'updatedAt',
    ]));
  }

  Future<void> linkSupervisor({
    required String supervisorUid,
    required String supervisorName,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || supervisorUid.trim().isEmpty) return;
    await _files.doc(uid).set({
      'ownerId': uid,
      'supervisorUid': supervisorUid.trim(),
      'supervisorName': supervisorName.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static String _clip(String value, int max) {
    final text = value.trim();
    if (text.length <= max) return text;
    return text.substring(0, max);
  }
}
