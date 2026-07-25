import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/locale/app_translate.dart';
import '../auth/user_account_service.dart';
import '../moderation/approval_status.dart';
import 'csv_lab_parser.dart';

class LabImportResult {
  final int imported;
  final int updated;
  final int skipped;
  final List<String> errors;

  const LabImportResult({
    this.imported = 0,
    this.updated = 0,
    this.skipped = 0,
    this.errors = const [],
  });
}

class LabImportService {
  LabImportService._();

  static final LabImportService instance = LabImportService._();

  final _db = FirebaseFirestore.instance;

  static const nbsleMetaDoc = 'app_meta/nbsle_sync';
  static const crciMetaDoc = 'app_meta/crci_sync';

  /// Import rows. When [syncExisting] is true, labs matched by
  /// `nbsleLabId` / `crciCenterId` / `externalId` are updated instead of skipped.
  Future<LabImportResult> importRows({
    required List<CsvLabRow> rows,
    bool autoApprove = true,
    bool syncExisting = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr('يجب تسجيل الدخول', 'You must sign in'));
    }

    final account = await UserAccountService.instance.loadCurrentAccount();
    final isAdmin = account?.isAdmin == true;
    if (autoApprove && !isAdmin) {
      throw Exception(
        appTr(
          'الموافقة التلقائية متاحة للمدير فقط',
          'Auto-approval is available to admins only',
        ),
      );
    }

    final existingByKey = await _loadExistingDocs();
    var imported = 0;
    var updated = 0;
    var skipped = 0;
    final errors = <String>[];
    final toCreate = <Map<String, dynamic>>[];
    final toUpdate = <({String docId, Map<String, dynamic> data})>[];
    final seenKeys = <String>{};

    for (final row in rows) {
      if (row.name.trim().isEmpty) {
        skipped++;
        continue;
      }

      final key = _dedupeKey(row);
      if (seenKeys.contains(key)) {
        skipped++;
        continue;
      }
      seenKeys.add(key);

      final existing = existingByKey[key];
      if (existing != null) {
        if (!syncExisting) {
          skipped++;
          continue;
        }
        final mapped = csvLabRowToFirestoreMap(row);
        final merged = _mergeForSync(
          existing.data(),
          mapped,
          preserveManualPrices: true,
        );
        merged['updatedAt'] = FieldValue.serverTimestamp();
        merged['syncedAt'] = FieldValue.serverTimestamp();
        merged['importedBy'] = user.uid;
        toUpdate.add((docId: existing.id, data: merged));
        continue;
      }

      toCreate.add({
        ...csvLabRowToFirestoreMap(row),
        'importedBy': user.uid,
        'ownerId': isAdmin ? '' : user.uid,
        'approvalStatus': (isAdmin && autoApprove)
            ? ApprovalStatus.approved
            : ApprovalStatus.pending,
        'createdAt': FieldValue.serverTimestamp(),
        'importedAt': FieldValue.serverTimestamp(),
        'syncedAt': FieldValue.serverTimestamp(),
      });
    }

    for (var i = 0; i < toCreate.length; i += 400) {
      final chunk = toCreate.skip(i).take(400).toList();
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

    for (var i = 0; i < toUpdate.length; i += 400) {
      final chunk = toUpdate.skip(i).take(400).toList();
      final batch = _db.batch();
      for (final item in chunk) {
        batch.set(
          _db.collection('labs').doc(item.docId),
          item.data,
          SetOptions(merge: true),
        );
      }
      try {
        await batch.commit();
        updated += chunk.length;
      } catch (error) {
        errors.add(error.toString());
      }
    }

    final hasNbsle = rows.any((r) => r.importSource == 'nbsle');
    if (hasNbsle && (imported > 0 || updated > 0)) {
      try {
        await _db.doc(nbsleMetaDoc).set({
          'lastSyncedAt': FieldValue.serverTimestamp(),
          'lastSyncedBy': user.uid,
          'lastImported': imported,
          'lastUpdated': updated,
          'lastTotalRows': rows.length,
        }, SetOptions(merge: true));
      } catch (error) {
        // Labs already written — don't fail the whole sync for meta.
        errors.add('nbsle_meta: $error');
      }
    }

    final hasCrci = rows.any((r) => r.importSource == 'crci');
    if (hasCrci && (imported > 0 || updated > 0)) {
      try {
        await _db.doc(crciMetaDoc).set({
          'lastSyncedAt': FieldValue.serverTimestamp(),
          'lastSyncedBy': user.uid,
          'lastImported': imported,
          'lastUpdated': updated,
          'lastTotalRows': rows.length,
          'centerCount': rows.where((r) => r.importSource == 'crci').length,
        }, SetOptions(merge: true));
      } catch (error) {
        errors.add('crci_meta: $error');
      }
    }

    if (errors.isNotEmpty && imported == 0 && updated == 0) {
      throw Exception(errors.take(3).join('\n'));
    }

    return LabImportResult(
      imported: imported,
      updated: updated,
      skipped: skipped,
      errors: errors,
    );
  }

  Future<DateTime?> loadLastNbsleSyncAt() async {
    try {
      final snap = await _db.doc(nbsleMetaDoc).get();
      final ts = snap.data()?['lastSyncedAt'];
      if (ts is Timestamp) return ts.toDate();
    } catch (_) {}
    return null;
  }

  Future<DateTime?> loadLastCrciSyncAt() async {
    try {
      final snap = await _db.doc(crciMetaDoc).get();
      final ts = snap.data()?['lastSyncedAt'];
      if (ts is Timestamp) return ts.toDate();
    } catch (_) {}
    return null;
  }

  String _dedupeKey(CsvLabRow row) {
    final externalId = row.externalId.trim();
    final source = row.importSource.trim().toLowerCase();
    if (externalId.isNotEmpty) {
      if (source == 'crci') return 'crci:$externalId';
      if (source == 'nbsle') return 'nbsle:$externalId';
      return 'ext:$source:$externalId';
    }
    final name = row.name.toLowerCase().trim();
    final university = row.university.toLowerCase().trim();
    final city = row.city.toLowerCase().trim();
    final location = row.location.toLowerCase().trim();
    return 'name:$name|$university|$city|$location';
  }

  Future<Map<String, QueryDocumentSnapshot<Map<String, dynamic>>>>
      _loadExistingDocs() async {
    final snapshot = await _db.collection('labs').get();
    final map = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final importSource = data['importSource']?.toString() ?? '';
      final externalId = (data['crciCenterId'] ??
              data['nbsleLabId'] ??
              data['externalId'])
          ?.toString() ??
          '';
      final key = _dedupeKey(
        CsvLabRow(
          name: data['name']?.toString() ?? '',
          university: data['university']?.toString() ?? '',
          city: data['city']?.toString() ?? '',
          location: data['location']?.toString() ?? '',
          importSource: importSource,
          externalId: externalId,
        ),
      );
      map.putIfAbsent(key, () => doc);
    }
    return map;
  }

  /// Refresh NBSLE fields; keep admin-edited prices when scrape has 0.
  Map<String, dynamic> _mergeForSync(
    Map<String, dynamic> existing,
    Map<String, dynamic> incoming, {
    required bool preserveManualPrices,
  }) {
    final merged = Map<String, dynamic>.from(incoming);

    // Never wipe ownership / approval on sync.
    if (existing['ownerId'] != null) {
      merged['ownerId'] = existing['ownerId'];
    }
    if (existing['approvalStatus'] != null) {
      merged['approvalStatus'] = existing['approvalStatus'];
    }
    if (existing['createdAt'] != null) {
      merged['createdAt'] = existing['createdAt'];
    }
    if (existing['importedAt'] != null) {
      merged['importedAt'] = existing['importedAt'];
    }

    if (existing['contactEmail'] != null &&
        (merged['contactEmail'] == null ||
            merged['contactEmail'].toString().isEmpty)) {
      merged['contactEmail'] = existing['contactEmail'];
    }
    if (existing['contactPhone'] != null &&
        (merged['contactPhone'] == null ||
            merged['contactPhone'].toString().isEmpty)) {
      merged['contactPhone'] = existing['contactPhone'];
    }
    if (existing['contacts'] is List &&
        (merged['contacts'] == null ||
            (merged['contacts'] is List &&
                (merged['contacts'] as List).isEmpty))) {
      merged['contacts'] = existing['contacts'];
    }

    if (!preserveManualPrices) return merged;

    final oldEquip = existing['equipmentList'];
    final newEquip = incoming['equipmentList'];
    if (oldEquip is List && newEquip is List) {
      final priceByName = <String, num>{};
      for (final item in oldEquip) {
        if (item is! Map) continue;
        final name = item['name']?.toString().toLowerCase().trim() ?? '';
        final price = item['costPerSession'];
        if (name.isEmpty || price is! num || price <= 0) continue;
        priceByName[name] = price;
      }
      merged['equipmentList'] = newEquip.map((item) {
        if (item is! Map) return item;
        final map = Map<String, dynamic>.from(item);
        final name = map['name']?.toString().toLowerCase().trim() ?? '';
        final price = map['costPerSession'];
        final oldPrice = priceByName[name];
        if ((price is! num || price <= 0) && oldPrice != null) {
          map['costPerSession'] = oldPrice;
        }
        return map;
      }).toList();
    }

    return merged;
  }
}
