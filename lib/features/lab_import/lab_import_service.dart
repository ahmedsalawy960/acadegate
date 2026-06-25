import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/user_account_service.dart';
import '../moderation/approval_status.dart';
import 'csv_lab_parser.dart';

class LabImportResult {
  final int imported;
  final int skipped;
  final List<String> errors;

  const LabImportResult({
    this.imported = 0,
    this.skipped = 0,
    this.errors = const [],
  });
}

class LabImportService {
  LabImportService._();

  static final LabImportService instance = LabImportService._();

  final _db = FirebaseFirestore.instance;

  Future<LabImportResult> importRows({
    required List<CsvLabRow> rows,
    bool autoApprove = true,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول');

    final account = await UserAccountService.instance.loadCurrentAccount();
    final isAdmin = account?.isAdmin == true;
    if (autoApprove && !isAdmin) {
      throw Exception('الموافقة التلقائية متاحة للمدير فقط');
    }

    final existingKeys = await _loadExistingKeys();
    var imported = 0;
    var skipped = 0;
    final errors = <String>[];
    final pending = <Map<String, dynamic>>[];

    for (final row in rows) {
      if (row.name.trim().isEmpty) {
        skipped++;
        continue;
      }

      final key = _dedupeKey(row);
      if (existingKeys.contains(key)) {
        skipped++;
        continue;
      }

      pending.add({
        ...csvLabRowToFirestoreMap(row),
        'importedBy': user.uid,
        'ownerId': isAdmin ? '' : user.uid,
        'approvalStatus': (isAdmin && autoApprove)
            ? ApprovalStatus.approved
            : ApprovalStatus.pending,
        'createdAt': FieldValue.serverTimestamp(),
        'importedAt': FieldValue.serverTimestamp(),
      });
      existingKeys.add(key);
    }

    for (var i = 0; i < pending.length; i += 400) {
      final chunk = pending.skip(i).take(400).toList();
      final batch = _db.batch();
      for (final item in chunk) {
        batch.set(_db.collection('labs').doc(), item);
      }
      try {
        await batch.commit();
        imported += chunk.length;
      } catch (error) {
        errors.add(error.toString());
      }
    }

    return LabImportResult(
      imported: imported,
      skipped: skipped,
      errors: errors,
    );
  }

  String _dedupeKey(CsvLabRow row) {
    final name = row.name.toLowerCase().trim();
    final university = row.university.toLowerCase().trim();
    final city = row.city.toLowerCase().trim();
    return 'name:$name|$university|$city';
  }

  Future<Set<String>> _loadExistingKeys() async {
    final snapshot = await _db.collection('labs').get();
    final keys = <String>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      keys.add(
        _dedupeKey(
          CsvLabRow(
            name: data['name']?.toString() ?? '',
            university: data['university']?.toString() ?? '',
            city: data['city']?.toString() ?? '',
          ),
        ),
      );
    }
    return keys;
  }
}
