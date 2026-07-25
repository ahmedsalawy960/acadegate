import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/locale/app_translate.dart';
import '../moderation/approval_status.dart';
import '../research_journey/thesis_progress.dart';
import '../research_journey/thesis_progress_activity.dart';
import 'manuscript_document_parser.dart';
import 'manuscript_upload_service.dart';
import 'publish_models.dart';

class ManuscriptService {
  ManuscriptService._();

  static final ManuscriptService instance = ManuscriptService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _manuscripts =>
      _db.collection('publish_manuscripts');

  Stream<List<PublishManuscript>> watchMine() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(const []);

    return _manuscripts
        .where('userId', isEqualTo: user.uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => PublishManuscript.fromMap(d.data(), id: d.id))
              .toList(),
        );
  }

  Future<PublishManuscript?> getById(String id) async {
    final doc = await _manuscripts.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return PublishManuscript.fromMap(doc.data()!, id: doc.id);
  }

  Future<String> createEmpty() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr('يجب تسجيل الدخول', 'Sign in required'));
    }

    final doc = await _manuscripts.add({
      'userId': user.uid,
      'title': '',
      'abstractText': '',
      'body': '',
      'bodyBlocks': <Map<String, dynamic>>[],
      'references': <Map<String, dynamic>>[],
      'attachments': <Map<String, dynamic>>[],
      'status': ManuscriptStatus.draft.name,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> save(PublishManuscript manuscript) async {
    if (manuscript.id == null) {
      throw Exception(appTr('معرّف المسودة غير صالح', 'Invalid manuscript id'));
    }
    var toSave = manuscript;
    if (ManuscriptDocumentParser.skipImportImageUpload &&
        manuscript.bodyBlocks.isNotEmpty) {
      toSave = manuscript.copyWith(
        bodyBlocks: ManuscriptDocumentParser.stripDataUrisForPersistence(
          manuscript.bodyBlocks,
        ),
      );
    }
    await _manuscripts.doc(manuscript.id).set(
          toSave.toMap(),
          SetOptions(merge: true),
        );
    await _recordManuscriptProgress(manuscript);
  }

  Future<void> _recordManuscriptProgress(PublishManuscript manuscript) async {
    final hasContent = manuscript.title.trim().isNotEmpty ||
        manuscript.body.trim().isNotEmpty ||
        manuscript.abstractText.trim().isNotEmpty;
    if (!hasContent) return;

    await ThesisProgressService.instance.recordActivity(
      ThesisActivityId.publishManuscript.name,
    );
    if (manuscript.body.trim().length >= 80) {
      await ThesisProgressService.instance.recordActivity(
        ThesisActivityId.chapterWriting.name,
      );
    }
  }

  Future<void> delete(String id) async {
    await deleteCompletely(id);
  }

  /// Deletes Firestore draft and associated Storage files (attachments, images).
  Future<void> deleteCompletely(String id) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr('يجب تسجيل الدخول', 'Sign in required'));
    }

    final manuscript = await getById(id);
    if (manuscript != null && manuscript.userId != user.uid) {
      throw Exception(appTr('غير مصرح بحذف هذه المسودة', 'Not allowed to delete this draft'));
    }

    if (manuscript != null) {
      await ManuscriptUploadService.instance.deleteManuscriptFiles(
        userId: user.uid,
        manuscriptId: id,
        manuscript: manuscript,
      );
    }

    await _manuscripts.doc(id).delete();
  }

  Future<void> markFormatted(String id, PublishCitationStyle style) async {
    await _manuscripts.doc(id).update({
      'citationStyle': style.name,
      'status': ManuscriptStatus.formatted.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> submitToJournal({
    required String manuscriptId,
    required String journalId,
    required String journalName,
  }) async {
    await _manuscripts.doc(manuscriptId).update({
      'journalId': journalId,
      'journalName': journalName,
      'status': ManuscriptStatus.submitted.name,
      'submittedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

class JournalCatalogService {
  JournalCatalogService._();

  static final JournalCatalogService instance = JournalCatalogService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _journals =>
      _db.collection('journals');

  Stream<List<PublishJournal>> watchApproved() {
    return _journals
        .where('approvalStatus', isEqualTo: ApprovalStatus.approved)
        .orderBy('name')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => PublishJournal.fromMap(d.data(), id: d.id))
              .toList(),
        );
  }

  Stream<List<PublishJournal>> watchPending() {
    return _journals
        .where('approvalStatus', isEqualTo: ApprovalStatus.pending)
        .orderBy('name')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => PublishJournal.fromMap(d.data(), id: d.id))
              .toList(),
        );
  }

  Future<void> addJournal(PublishJournal journal) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr('يجب تسجيل الدخول', 'Sign in required'));
    }

    await _journals.add({
      ...journal.toMap(),
      'approvalStatus': ApprovalStatus.pending,
      'createdBy': user.uid,
    });
  }

  Future<void> approve(String journalId) async {
    await _journals.doc(journalId).update({
      'approvalStatus': ApprovalStatus.approved,
    });
  }

  Future<void> reject(String journalId) async {
    await _journals.doc(journalId).update({
      'approvalStatus': ApprovalStatus.rejected,
    });
  }
}
