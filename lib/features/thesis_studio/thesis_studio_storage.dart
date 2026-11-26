import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../acadegate_publish/publish_models.dart';
import '../ai_advisor/grounded_work.dart';
import '../research_supply_chain/research_goal.dart';
import 'thesis_studio_discipline.dart';
import 'thesis_studio_kind.dart';
import 'thesis_studio_models.dart';

/// Metadata for one saved Thesis Studio project (one researcher may keep
/// several drafts side by side instead of a single overwritten draft).
class ThesisProjectMeta {
  final String id;
  final String title;
  final int createdAtMs;
  final int savedAtMs;
  final int lastVersionAtMs;
  final int lastVersionSig;

  const ThesisProjectMeta({
    required this.id,
    required this.title,
    required this.createdAtMs,
    required this.savedAtMs,
    this.lastVersionAtMs = 0,
    this.lastVersionSig = 0,
  });

  ThesisProjectMeta copyWith({
    String? title,
    int? savedAtMs,
    int? lastVersionAtMs,
    int? lastVersionSig,
  }) {
    return ThesisProjectMeta(
      id: id,
      title: title ?? this.title,
      createdAtMs: createdAtMs,
      savedAtMs: savedAtMs ?? this.savedAtMs,
      lastVersionAtMs: lastVersionAtMs ?? this.lastVersionAtMs,
      lastVersionSig: lastVersionSig ?? this.lastVersionSig,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'createdAtMs': createdAtMs,
        'savedAtMs': savedAtMs,
        'lastVersionAtMs': lastVersionAtMs,
        'lastVersionSig': lastVersionSig,
      };

  factory ThesisProjectMeta.fromMap(Map<String, dynamic> map) {
    return ThesisProjectMeta(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      createdAtMs: (map['createdAtMs'] as num?)?.toInt() ?? 0,
      savedAtMs: (map['savedAtMs'] as num?)?.toInt() ?? 0,
      lastVersionAtMs: (map['lastVersionAtMs'] as num?)?.toInt() ?? 0,
      lastVersionSig: (map['lastVersionSig'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One restorable snapshot in a project's version history.
class ThesisDraftVersionMeta {
  final String id;
  final int savedAtMs;

  const ThesisDraftVersionMeta({required this.id, required this.savedAtMs});
}

/// Outcome of one save attempt. The UI must show this honestly: a failed
/// cloud write means "saved on this device only", never "saved everywhere".
class ThesisSaveResult {
  final bool localOk;
  final bool cloudOk;

  /// True when no cloud save was attempted because nobody is signed in.
  final bool cloudSkippedSignedOut;
  final DateTime savedAt;

  const ThesisSaveResult({
    required this.localOk,
    required this.cloudOk,
    required this.cloudSkippedSignedOut,
    required this.savedAt,
  });

  bool get persistedAnywhere => localOk || cloudOk;
}

/// Cloud side of draft persistence, abstracted so the store logic can be
/// tested without Firebase. Every method may throw; callers treat a throw
/// as "cloud failed" and report it.
abstract class ThesisStudioCloudStore {
  Future<List<ThesisProjectMeta>> listProjects(String uid);
  Future<Map<String, dynamic>?> getProjectPayload(String uid, String projectId);
  Future<void> putProject(
    String uid,
    ThesisProjectMeta meta,
    Map<String, dynamic> payload,
  );
  Future<List<ThesisDraftVersionMeta>> listVersions(
    String uid,
    String projectId,
  );
  Future<Map<String, dynamic>?> getVersionPayload(
    String uid,
    String projectId,
    String versionId,
  );
  Future<void> putVersion(
    String uid,
    String projectId,
    ThesisDraftVersionMeta version,
    Map<String, dynamic> payload,
  );
  Future<void> deleteProject(String uid, String projectId);

  /// The pre-multi-project single draft document, read only for migration.
  Future<Map<String, dynamic>?> getLegacyPayload(String uid);
}

class FirebaseThesisStudioCloudStore implements ThesisStudioCloudStore {
  static const _collection = 'thesis_studio_drafts';
  static const _projects = 'projects';
  static const _versions = 'versions';

  CollectionReference<Map<String, dynamic>> _projectsRef(String uid) =>
      FirebaseFirestore.instance
          .collection(_collection)
          .doc(uid)
          .collection(_projects);

  CollectionReference<Map<String, dynamic>> _versionsRef(
    String uid,
    String projectId,
  ) =>
      _projectsRef(uid).doc(projectId).collection(_versions);

  @override
  Future<List<ThesisProjectMeta>> listProjects(String uid) async {
    final snap = await _projectsRef(uid).get();
    return [
      for (final doc in snap.docs)
        ThesisProjectMeta(
          id: doc.id,
          title: doc.data()['title']?.toString() ?? '',
          createdAtMs: (doc.data()['createdAtMs'] as num?)?.toInt() ?? 0,
          savedAtMs: (doc.data()['savedAtMs'] as num?)?.toInt() ?? 0,
          lastVersionAtMs:
              (doc.data()['lastVersionAtMs'] as num?)?.toInt() ?? 0,
          lastVersionSig: (doc.data()['lastVersionSig'] as num?)?.toInt() ?? 0,
        ),
    ];
  }

  @override
  Future<Map<String, dynamic>?> getProjectPayload(
    String uid,
    String projectId,
  ) async {
    final doc = await _projectsRef(uid).doc(projectId).get();
    final payload = doc.data()?['payload'];
    if (payload is Map) return Map<String, dynamic>.from(payload);
    return null;
  }

  @override
  Future<void> putProject(
    String uid,
    ThesisProjectMeta meta,
    Map<String, dynamic> payload,
  ) async {
    await _projectsRef(uid).doc(meta.id).set({
      'uid': uid,
      'title': meta.title,
      'createdAtMs': meta.createdAtMs,
      'savedAtMs': meta.savedAtMs,
      'lastVersionAtMs': meta.lastVersionAtMs,
      'lastVersionSig': meta.lastVersionSig,
      'updatedAt': FieldValue.serverTimestamp(),
      'payload': payload,
    });
  }

  @override
  Future<List<ThesisDraftVersionMeta>> listVersions(
    String uid,
    String projectId,
  ) async {
    final snap = await _versionsRef(uid, projectId)
        .orderBy('savedAtMs', descending: true)
        .limit(ThesisStudioStorage.cloudVersionCap)
        .get();
    return [
      for (final doc in snap.docs)
        ThesisDraftVersionMeta(
          id: doc.id,
          savedAtMs: (doc.data()['savedAtMs'] as num?)?.toInt() ?? 0,
        ),
    ];
  }

  @override
  Future<Map<String, dynamic>?> getVersionPayload(
    String uid,
    String projectId,
    String versionId,
  ) async {
    final doc = await _versionsRef(uid, projectId).doc(versionId).get();
    final payload = doc.data()?['payload'];
    if (payload is Map) return Map<String, dynamic>.from(payload);
    return null;
  }

  @override
  Future<void> putVersion(
    String uid,
    String projectId,
    ThesisDraftVersionMeta version,
    Map<String, dynamic> payload,
  ) async {
    final ref = _versionsRef(uid, projectId);
    await ref.doc(version.id).set({
      'savedAtMs': version.savedAtMs,
      'payload': payload,
    });
    // Best-effort pruning: keep only the newest [cloudVersionCap] versions.
    try {
      final all = await ref.orderBy('savedAtMs', descending: true).get();
      if (all.docs.length > ThesisStudioStorage.cloudVersionCap) {
        for (final doc
            in all.docs.sublist(ThesisStudioStorage.cloudVersionCap)) {
          await doc.reference.delete();
        }
      }
    } catch (e) {
      debugPrint('ThesisStudioStorage: cloud version prune failed: $e');
    }
  }

  @override
  Future<void> deleteProject(String uid, String projectId) async {
    try {
      final versions = await _versionsRef(uid, projectId).get();
      for (final doc in versions.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('ThesisStudioStorage: cloud versions delete failed: $e');
    }
    await _projectsRef(uid).doc(projectId).delete();
  }

  @override
  Future<Map<String, dynamic>?> getLegacyPayload(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection(_collection)
        .doc(uid)
        .get();
    final payload = doc.data()?['payload'];
    if (payload is Map) return Map<String, dynamic>.from(payload);
    return null;
  }
}

/// Persists Thesis Studio drafts per signed-in account (local + Firestore),
/// as multiple named projects each with a bounded, restorable version
/// history. Saves report their real outcome; nothing pretends a failed
/// cloud write succeeded.
class ThesisStudioStorage {
  ThesisStudioStorage._({
    ThesisStudioCloudStore? cloud,
    this._uidProvider,
  }) : _cloud = cloud ?? FirebaseThesisStudioCloudStore();

  static final ThesisStudioStorage instance = ThesisStudioStorage._();

  /// Test hook: a storage with a fake cloud and a fixed signed-in uid.
  @visibleForTesting
  factory ThesisStudioStorage.forTesting({
    required ThesisStudioCloudStore cloud,
    String? uid,
  }) =>
      ThesisStudioStorage._(cloud: cloud, uidProvider: () => uid);

  final ThesisStudioCloudStore _cloud;
  final String? Function()? _uidProvider;

  static const _legacyKey = 'offline_thesis_studio_draft_v1';
  static const _indexKeyPrefix = 'offline_thesis_studio_projects_v2';
  static const _activeKeyPrefix = 'offline_thesis_studio_active_v2';
  static const _projectKeyPrefix = 'offline_thesis_studio_project_v2';
  static const _versionsKeyPrefix = 'offline_thesis_studio_versions_v2';

  /// Versions kept per project, per layer. The current state always lives in
  /// the project document itself; versions are rollback points only.
  static const int localVersionCap = 10;
  static const int cloudVersionCap = 20;

  /// Autosaves run on every edit; a rollback version is recorded at most
  /// this often (unless a restore forces one). The latest state is never
  /// lost either way — it is the project document.
  static const Duration versionThrottle = Duration(minutes: 10);

  String? get _uid {
    final provider = _uidProvider;
    if (provider != null) {
      final override = provider();
      return (override == null || override.isEmpty) ? null : override;
    }
    return FirebaseAuth.instance.currentUser?.uid;
  }

  String get _suffix {
    final uid = _uid;
    return (uid == null || uid.isEmpty) ? 'guest' : uid;
  }

  String get _indexKey => '${_indexKeyPrefix}_$_suffix';
  String get _activeKey => '${_activeKeyPrefix}_$_suffix';
  String _projectKey(String projectId) =>
      '${_projectKeyPrefix}_${_suffix}_$projectId';
  String _versionsKey(String projectId) =>
      '${_versionsKeyPrefix}_${_suffix}_$projectId';

  String _legacyLocalKey(String? uid) =>
      (uid == null || uid.isEmpty) ? _legacyKey : '${_legacyKey}_$uid';

  /// Deterministic content signature for change detection (Dart's
  /// String.hashCode is not stable across runs).
  static int contentSignature(String text) {
    var hash = 0x811c9dc5;
    for (final unit in text.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash;
  }

  static String deriveTitle(ThesisStudioSnapshot snapshot) {
    final proposed = snapshot.draft.proposedTitle.trim();
    if (proposed.isNotEmpty) return proposed;
    final goal = snapshot.goalText.trim();
    if (goal.isEmpty) return '';
    return goal.length <= 60 ? goal : '${goal.substring(0, 60)}…';
  }

  // ─── Project index ──────────────────────────────────────────────

  Future<List<ThesisProjectMeta>> _readLocalIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_indexKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return [
        for (final entry in list)
          if (entry is Map)
            ThesisProjectMeta.fromMap(
              entry.map((k, v) => MapEntry(k.toString(), v)),
            ),
      ];
    } catch (e) {
      debugPrint('ThesisStudioStorage: project index decode failed: $e');
      return [];
    }
  }

  Future<void> _writeLocalIndex(List<ThesisProjectMeta> metas) async {
    final prefs = await SharedPreferences.getInstance();
    metas.sort((a, b) => b.savedAtMs.compareTo(a.savedAtMs));
    await prefs.setString(
      _indexKey,
      jsonEncode([for (final m in metas) m.toMap()]),
    );
  }

  /// Migrates the pre-multi-project single draft (local keys and/or the
  /// legacy cloud document) into a first project. Read-only against the
  /// legacy locations: nothing old is deleted, so a rollback of the app
  /// still finds the old draft untouched.
  Future<List<ThesisProjectMeta>> _migrateLegacyIfNeeded(
    List<ThesisProjectMeta> existing,
  ) async {
    if (existing.isNotEmpty) return existing;
    final legacy = await _loadLegacySnapshot();
    if (legacy == null) return existing;
    final meta = ThesisProjectMeta(
      id: 'legacy',
      title: deriveTitle(legacy),
      createdAtMs: legacy.savedAt.millisecondsSinceEpoch,
      savedAtMs: legacy.savedAt.millisecondsSinceEpoch,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _projectKey(meta.id),
      jsonEncode(legacy.compactedForStorage().toMap()),
    );
    await prefs.setString(_activeKey, meta.id);
    await _writeLocalIndex([meta]);
    return [meta];
  }

  Future<ThesisStudioSnapshot?> _loadLegacySnapshot() async {
    final uid = _uid;
    ThesisStudioSnapshot? cloud;
    if (uid != null && uid.isNotEmpty) {
      try {
        final payload = await _cloud.getLegacyPayload(uid);
        if (payload != null) {
          cloud = ThesisStudioSnapshot.fromMap(payload);
        }
      } catch (e) {
        debugPrint('ThesisStudioStorage: legacy cloud load failed: $e');
      }
    }

    final prefs = await SharedPreferences.getInstance();
    ThesisStudioSnapshot? local;
    for (final key in <String>{
      if (uid != null && uid.isNotEmpty) _legacyLocalKey(uid),
      _legacyKey,
    }) {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) continue;
      try {
        local = ThesisStudioSnapshot.fromMap(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        break;
      } catch (e) {
        debugPrint('ThesisStudioStorage: legacy local decode failed: $e');
      }
    }

    if (cloud == null) return local;
    if (local == null) return cloud;
    return cloud.savedAt.isAfter(local.savedAt) ? cloud : local;
  }

  /// All projects for this account: the local index merged with cloud
  /// metadata (cloud wins display metadata when its copy is newer).
  Future<List<ThesisProjectMeta>> listProjects() async {
    var metas = await _readLocalIndex();
    metas = await _migrateLegacyIfNeeded(metas);
    final uid = _uid;
    if (uid != null && uid.isNotEmpty) {
      try {
        final cloudMetas = await _cloud.listProjects(uid);
        final byId = {for (final m in metas) m.id: m};
        var changed = false;
        for (final cm in cloudMetas) {
          final local = byId[cm.id];
          if (local == null) {
            byId[cm.id] = cm;
            changed = true;
          } else if (cm.savedAtMs > local.savedAtMs) {
            byId[cm.id] = cm.copyWith(
              lastVersionAtMs: local.lastVersionAtMs > cm.lastVersionAtMs
                  ? local.lastVersionAtMs
                  : cm.lastVersionAtMs,
              lastVersionSig: cm.lastVersionSig != 0
                  ? cm.lastVersionSig
                  : local.lastVersionSig,
            );
            changed = true;
          }
        }
        metas = byId.values.toList();
        if (changed) await _writeLocalIndex(metas);
      } catch (e) {
        debugPrint('ThesisStudioStorage: cloud project list failed: $e');
      }
    }
    metas.sort((a, b) => b.savedAtMs.compareTo(a.savedAtMs));
    return metas;
  }

  Future<String?> activeProjectId() async {
    final prefs = await SharedPreferences.getInstance();
    final active = prefs.getString(_activeKey);
    if (active != null && active.isNotEmpty) return active;
    final metas = await _readLocalIndex();
    return metas.isEmpty ? null : metas.first.id;
  }

  Future<void> setActiveProject(String projectId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeKey, projectId);
  }

  /// Creates a new empty project and makes it active. Returns its id.
  Future<String> createProject({String title = ''}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'p$now';
    final meta = ThesisProjectMeta(
      id: id,
      title: title,
      createdAtMs: now,
      savedAtMs: 0,
    );
    final metas = await _readLocalIndex();
    metas.add(meta);
    await _writeLocalIndex(metas);
    await setActiveProject(id);
    return id;
  }

  // ─── Load / save ────────────────────────────────────────────────

  Future<ThesisStudioSnapshot?> loadProject(String projectId) async {
    final uid = _uid;
    ThesisStudioSnapshot? cloud;
    if (uid != null && uid.isNotEmpty) {
      try {
        final payload = await _cloud.getProjectPayload(uid, projectId);
        if (payload != null) {
          cloud = ThesisStudioSnapshot.fromMap(payload);
        }
      } catch (e) {
        debugPrint('ThesisStudioStorage: cloud load failed: $e');
      }
    }

    final prefs = await SharedPreferences.getInstance();
    ThesisStudioSnapshot? local;
    final raw = prefs.getString(_projectKey(projectId));
    if (raw != null && raw.isNotEmpty) {
      try {
        local = ThesisStudioSnapshot.fromMap(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      } catch (e) {
        debugPrint('ThesisStudioStorage: local decode failed: $e');
      }
    }

    final winner = (cloud == null)
        ? local
        : (local == null)
            ? cloud
            : (cloud.savedAt.isAfter(local.savedAt) ? cloud : local);
    // Keep the device cache in sync with the winning copy.
    if (winner != null && identical(winner, cloud)) {
      await prefs.setString(
        _projectKey(projectId),
        jsonEncode(winner.compactedForStorage().toMap()),
      );
    }
    return winner;
  }

  Future<ThesisStudioSnapshot?> loadActiveProject() async {
    final id = await activeProjectId();
    if (id == null) return null;
    return loadProject(id);
  }

  /// Saves [snapshot] under [projectId] and reports exactly what happened.
  /// When [recordVersion] is on, a rollback version is appended at most once
  /// per [versionThrottle] while the content keeps changing; [forceVersion]
  /// bypasses the throttle (used before a restore, so a restore is itself
  /// undoable).
  Future<ThesisSaveResult> saveProject(
    String projectId,
    ThesisStudioSnapshot snapshot, {
    String? title,
    bool recordVersion = true,
    bool forceVersion = false,
  }) async {
    final uid = _uid;
    final compact = snapshot.compactedForStorage();
    final map = compact.toMap();
    final encoded = jsonEncode(map);
    // savedAt changes on every save; the signature covers content only.
    final sigMap = Map<String, dynamic>.from(map)..remove('savedAtMs');
    final sig = contentSignature(jsonEncode(sigMap));
    final nowMs = compact.savedAt.millisecondsSinceEpoch;

    final prefs = await SharedPreferences.getInstance();
    final localOk = await prefs.setString(_projectKey(projectId), encoded);
    if (!localOk) {
      debugPrint('ThesisStudioStorage: local save failed (quota?)');
    }

    // Update project metadata in the local index.
    final metas = await _readLocalIndex();
    var metaIndex = metas.indexWhere((m) => m.id == projectId);
    if (metaIndex < 0) {
      metas.add(ThesisProjectMeta(
        id: projectId,
        title: title ?? deriveTitle(snapshot),
        createdAtMs: nowMs,
        savedAtMs: nowMs,
      ));
      metaIndex = metas.length - 1;
    }
    var meta = metas[metaIndex].copyWith(
      title: (title ?? deriveTitle(snapshot)).isNotEmpty
          ? (title ?? deriveTitle(snapshot))
          : metas[metaIndex].title,
      savedAtMs: nowMs,
    );

    final versionDue = recordVersion &&
        (forceVersion ||
            (sig != meta.lastVersionSig &&
                (meta.lastVersionAtMs == 0 ||
                    nowMs - meta.lastVersionAtMs >=
                        versionThrottle.inMilliseconds)));
    ThesisDraftVersionMeta? version;
    if (versionDue) {
      version = ThesisDraftVersionMeta(id: 'v$nowMs', savedAtMs: nowMs);
      await _appendLocalVersion(projectId, version, map);
      meta = meta.copyWith(lastVersionAtMs: nowMs, lastVersionSig: sig);
    }
    metas[metaIndex] = meta;
    await _writeLocalIndex(metas);

    if (uid == null || uid.isEmpty) {
      return ThesisSaveResult(
        localOk: localOk,
        cloudOk: false,
        cloudSkippedSignedOut: true,
        savedAt: compact.savedAt,
      );
    }

    var cloudOk = true;
    try {
      await _cloud.putProject(uid, meta, map);
    } catch (e) {
      cloudOk = false;
      debugPrint('ThesisStudioStorage: cloud save failed: $e');
    }
    if (version != null) {
      try {
        await _cloud.putVersion(uid, projectId, version, map);
      } catch (e) {
        debugPrint('ThesisStudioStorage: cloud version save failed: $e');
      }
    }
    return ThesisSaveResult(
      localOk: localOk,
      cloudOk: cloudOk,
      cloudSkippedSignedOut: false,
      savedAt: compact.savedAt,
    );
  }

  Future<void> _appendLocalVersion(
    String projectId,
    ThesisDraftVersionMeta version,
    Map<String, dynamic> payload,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _versionsKey(projectId);
    final versions = await _readLocalVersions(projectId);
    versions.add({
      'id': version.id,
      'savedAtMs': version.savedAtMs,
      'payload': payload,
    });
    versions.sort(
      (a, b) => ((b['savedAtMs'] as num?)?.toInt() ?? 0)
          .compareTo((a['savedAtMs'] as num?)?.toInt() ?? 0),
    );
    final kept = versions.take(localVersionCap).toList();
    try {
      await prefs.setString(key, jsonEncode(kept));
    } catch (e) {
      debugPrint('ThesisStudioStorage: local version save failed: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _readLocalVersions(
    String projectId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_versionsKey(projectId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return [
        for (final entry in list)
          if (entry is Map) entry.map((k, v) => MapEntry(k.toString(), v)),
      ];
    } catch (e) {
      debugPrint('ThesisStudioStorage: local versions decode failed: $e');
      return [];
    }
  }

  // ─── Version history ────────────────────────────────────────────

  /// Version markers for a project, newest first, local and cloud merged.
  Future<List<ThesisDraftVersionMeta>> listVersions(String projectId) async {
    final byId = <String, ThesisDraftVersionMeta>{};
    for (final entry in await _readLocalVersions(projectId)) {
      final id = entry['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      byId[id] = ThesisDraftVersionMeta(
        id: id,
        savedAtMs: (entry['savedAtMs'] as num?)?.toInt() ?? 0,
      );
    }
    final uid = _uid;
    if (uid != null && uid.isNotEmpty) {
      try {
        for (final v in await _cloud.listVersions(uid, projectId)) {
          byId[v.id] = v;
        }
      } catch (e) {
        debugPrint('ThesisStudioStorage: cloud version list failed: $e');
      }
    }
    final list = byId.values.toList()
      ..sort((a, b) => b.savedAtMs.compareTo(a.savedAtMs));
    return list;
  }

  Future<ThesisStudioSnapshot?> loadVersion(
    String projectId,
    String versionId,
  ) async {
    for (final entry in await _readLocalVersions(projectId)) {
      if (entry['id']?.toString() == versionId) {
        final payload = entry['payload'];
        if (payload is Map) {
          try {
            return ThesisStudioSnapshot.fromMap(
              payload.map((k, v) => MapEntry(k.toString(), v)),
            );
          } catch (e) {
            debugPrint('ThesisStudioStorage: local version decode failed: $e');
          }
        }
      }
    }
    final uid = _uid;
    if (uid != null && uid.isNotEmpty) {
      try {
        final payload = await _cloud.getVersionPayload(uid, projectId, versionId);
        if (payload != null) return ThesisStudioSnapshot.fromMap(payload);
      } catch (e) {
        debugPrint('ThesisStudioStorage: cloud version load failed: $e');
      }
    }
    return null;
  }

  // ─── Delete ─────────────────────────────────────────────────────

  /// Deletes one project (local + cloud, including its versions). Returns
  /// false only when the cloud delete was attempted and failed.
  Future<bool> deleteProject(String projectId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_projectKey(projectId));
    await prefs.remove(_versionsKey(projectId));
    final metas = await _readLocalIndex()
      ..removeWhere((m) => m.id == projectId);
    await _writeLocalIndex(metas);
    if (prefs.getString(_activeKey) == projectId) {
      await prefs.remove(_activeKey);
    }
    final uid = _uid;
    if (uid == null || uid.isEmpty) return true;
    try {
      await _cloud.deleteProject(uid, projectId);
      return true;
    } catch (e) {
      debugPrint('ThesisStudioStorage: cloud project delete failed: $e');
      return false;
    }
  }

  // ─── Legacy single-draft API (kept for older call sites) ────────

  Future<void> save(ThesisStudioSnapshot snapshot) async {
    final id = await activeProjectId() ?? await createProject();
    await saveProject(id, snapshot);
  }

  Future<ThesisStudioSnapshot?> load() async {
    final metas = await listProjects();
    if (metas.isEmpty) return null;
    return loadActiveProject();
  }

  Future<void> clear() async {
    final id = await activeProjectId();
    if (id != null) {
      await deleteProject(id);
      return;
    }
    // No projects yet: clear any unmigrated legacy copies.
    final uid = _uid;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyLocalKey(uid));
    await prefs.remove(_legacyKey);
    if (uid == null || uid.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('thesis_studio_drafts')
          .doc(uid)
          .delete();
    } catch (e) {
      debugPrint('ThesisStudioStorage: legacy cloud clear failed: $e');
    }
  }
}

class ThesisStudioSnapshot {
  final ThesisDraft draft;
  final String goalText;
  final ResearchDegreeTrack track;
  final ThesisKind kind;
  final ThesisShape shape;
  final bool arabicDraft;
  final String? facultyId;
  final String? departmentId;
  final PublishCitationStyle citationStyle;
  final int targetPages;
  final String priorStudiesPaste;
  final DateTime savedAt;

  const ThesisStudioSnapshot({
    required this.draft,
    required this.goalText,
    required this.track,
    required this.kind,
    required this.shape,
    required this.arabicDraft,
    required this.citationStyle,
    required this.targetPages,
    this.facultyId,
    this.departmentId,
    this.priorStudiesPaste = '',
    required this.savedAt,
  });

  /// Shrink abstracts so localStorage / Firestore stay under size limits.
  ThesisStudioSnapshot compactedForStorage({int maxAbstractChars = 900}) {
    GroundedWork slim(GroundedWork w) {
      final abs = w.abstractText.trim();
      if (abs.length <= maxAbstractChars) return w;
      return GroundedWork(
        title: w.title,
        doi: w.doi,
        year: w.year,
        authors: w.authors,
        source: w.source,
        journal: w.journal,
        abstractText: '${abs.substring(0, maxAbstractChars)}…',
      );
    }

    List<GroundedWork> slimList(List<GroundedWork> list) =>
        [for (final w in list) slim(w)];

    final chapters = [
      for (final c in draft.chapters)
        ThesisChapter(
          id: c.id,
          titleAr: c.titleAr,
          titleEn: c.titleEn,
          purposeAr: c.purposeAr,
          purposeEn: c.purposeEn,
          body: c.body,
          fromGemini: c.fromGemini,
          depth: c.depth,
          paragraphs: [
            for (final p in c.paragraphs)
              ThesisParagraph(
                id: p.id,
                headingAr: p.headingAr,
                headingEn: p.headingEn,
                body: p.body,
                fromGemini: p.fromGemini,
                lastCommand: p.lastCommand,
                references: slimList(p.references),
              ),
          ],
        ),
    ];

    final slimDraft = draft.copyWith(
      literature: GroundedReferenceBundle(
        topic: draft.literature.topic,
        works: slimList(draft.literature.works),
        droppedInventedDois: draft.literature.droppedInventedDois,
      ),
      literatureMap: [
        for (final row in draft.literatureMap)
          LiteratureMapRow(
            index: row.index,
            work: slim(row.work),
            focus: row.focus,
            notes: row.notes,
          ),
      ],
      abstractReferences: slimList(draft.abstractReferences),
      chapters: chapters,
    );

    return ThesisStudioSnapshot(
      draft: slimDraft,
      goalText: goalText,
      track: track,
      kind: kind,
      shape: shape,
      arabicDraft: arabicDraft,
      facultyId: facultyId,
      departmentId: departmentId,
      citationStyle: citationStyle,
      targetPages: targetPages,
      priorStudiesPaste: priorStudiesPaste,
      savedAt: savedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'v': 1,
        'savedAtMs': savedAt.millisecondsSinceEpoch,
        'goalText': goalText,
        'track': track.name,
        'kind': kind.name,
        'shape': shape.name,
        'arabicDraft': arabicDraft,
        'facultyId': facultyId,
        'departmentId': departmentId,
        'citationStyle': citationStyle.name,
        'targetPages': targetPages,
        'priorStudiesPaste': priorStudiesPaste,
        'draft': _encodeDraft(draft),
      };

  factory ThesisStudioSnapshot.fromMap(Map<String, dynamic> map) {
    return ThesisStudioSnapshot(
      draft: _decodeDraft(map['draft'] as Map<String, dynamic>? ?? const {}),
      goalText: map['goalText']?.toString() ?? '',
      track: _enumByName(ResearchDegreeTrack.values, map['track']) ??
          ResearchDegreeTrack.masters,
      kind: _enumByName(ThesisKind.values, map['kind']) ?? ThesisKind.experimental,
      shape: _enumByName(ThesisShape.values, map['shape']) ??
          ThesisShape.arabicEmpirical,
      arabicDraft: map['arabicDraft'] == true,
      facultyId: map['facultyId']?.toString(),
      departmentId: map['departmentId']?.toString(),
      citationStyle:
          _enumByName(PublishCitationStyle.values, map['citationStyle']) ??
              PublishCitationStyle.apa,
      targetPages: (map['targetPages'] as num?)?.toInt() ?? 40,
      priorStudiesPaste: map['priorStudiesPaste']?.toString() ?? '',
      savedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['savedAtMs'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  static T? _enumByName<T extends Enum>(List<T> values, Object? raw) {
    final name = raw?.toString();
    if (name == null || name.isEmpty) return null;
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }

  static Map<String, dynamic> _encodeDraft(ThesisDraft draft) => {
        'goal': _encodeGoal(draft.goal),
        'plan': _encodePlan(draft.plan),
        'literature': _encodeBundle(draft.literature),
        'literatureMap': [
          for (final row in draft.literatureMap) _encodeMapRow(row),
        ],
        'proposedTitle': draft.proposedTitle,
        'titleOptions': draft.titleOptions,
        'abstractText': draft.abstractText,
        'researchQuestions': draft.researchQuestions,
        'chapters': [for (final c in draft.chapters) _encodeChapter(c)],
        'fromGemini': draft.fromGemini,
        'modelUsed': draft.modelUsed,
        'note': draft.note,
        'abstractReferences': [
          for (final w in draft.abstractReferences) _encodeWork(w),
        ],
      };

  /// Firestore/JS often yields `Map<Object?, Object?>`; strict
  /// `is Map<String, dynamic>` silently drops nested works after reload.
  static Map<String, dynamic> _asStringKeyedMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return const {};
  }

  static ThesisDraft _decodeDraft(Map<String, dynamic> map) {
    final goal = _decodeGoal(_asStringKeyedMap(map['goal']));
    final plan = _decodePlan(_asStringKeyedMap(map['plan']), goal);
    return ThesisDraft(
      goal: goal,
      plan: plan,
      literature: _decodeBundle(_asStringKeyedMap(map['literature'])),
      literatureMap: [
        for (final row in (map['literatureMap'] as List<dynamic>? ?? const []))
          if (row is Map) _decodeMapRow(_asStringKeyedMap(row)),
      ],
      proposedTitle: map['proposedTitle']?.toString() ?? '',
      titleOptions: [
        for (final t in (map['titleOptions'] as List<dynamic>? ?? const []))
          if (t.toString().trim().isNotEmpty) t.toString().trim(),
      ],
      abstractText: map['abstractText']?.toString() ?? '',
      researchQuestions: [
        for (final q in (map['researchQuestions'] as List<dynamic>? ?? const []))
          q.toString(),
      ],
      chapters: [
        for (final c in (map['chapters'] as List<dynamic>? ?? const []))
          if (c is Map) _decodeChapter(_asStringKeyedMap(c)),
      ],
      fromGemini: map['fromGemini'] == true,
      modelUsed: map['modelUsed']?.toString(),
      note: map['note']?.toString(),
      abstractReferences: [
        for (final w in (map['abstractReferences'] as List<dynamic>? ?? const []))
          if (w is Map) _decodeWork(_asStringKeyedMap(w)),
      ],
    );
  }

  static Map<String, dynamic> _encodeGoal(ResearchGoal g) => {
        'raw': g.raw,
        'field': g.field,
        'fieldEn': g.fieldEn,
        'track': g.track.name,
        'institution': g.institution.name,
        'searchQuery': g.searchQuery,
        'years': g.years,
        'searchQueries': g.searchQueries,
        'matchKeywords': g.matchKeywords,
        'methods': g.methods,
      };

  static ResearchGoal _decodeGoal(Map<String, dynamic> map) {
    return ResearchGoal(
      raw: map['raw']?.toString() ?? '',
      field: map['field']?.toString() ?? '',
      fieldEn: map['fieldEn']?.toString() ?? '',
      track: _enumByName(ResearchDegreeTrack.values, map['track']) ??
          ResearchDegreeTrack.unspecified,
      institution: _enumByName(InstitutionTarget.values, map['institution']) ??
          InstitutionTarget.unspecified,
      searchQuery: map['searchQuery']?.toString() ?? '',
      years: (map['years'] as num?)?.toInt() ?? 2,
      searchQueries: [
        for (final q in (map['searchQueries'] as List<dynamic>? ?? const []))
          q.toString(),
      ],
      matchKeywords: [
        for (final q in (map['matchKeywords'] as List<dynamic>? ?? const []))
          q.toString(),
      ],
      methods: [
        for (final q in (map['methods'] as List<dynamic>? ?? const []))
          q.toString(),
      ],
    );
  }

  static Map<String, dynamic> _encodePlan(ThesisPlan p) => {
        'kind': p.kind.name,
        'shape': p.shape.name,
        'arabic': p.arabic,
        'citationStyle': p.citationStyle.name,
        'targetPages': p.targetPages,
        'discipline': {
          'facultyId': p.discipline.facultyId,
          'departmentId': p.discipline.departmentId,
          'labelAr': p.discipline.labelAr,
          'labelEn': p.discipline.labelEn,
          'searchTerms': p.discipline.searchTerms,
          'alienHints': p.discipline.alienHints,
        },
      };

  static ThesisPlan _decodePlan(Map<String, dynamic> map, ResearchGoal goal) {
    final d = _asStringKeyedMap(map['discipline']);
    return ThesisPlan(
      goal: goal,
      kind: _enumByName(ThesisKind.values, map['kind']) ?? ThesisKind.experimental,
      shape: _enumByName(ThesisShape.values, map['shape']) ??
          ThesisShape.arabicEmpirical,
      arabic: map['arabic'] == true,
      citationStyle: _enumByName(PublishCitationStyle.values, map['citationStyle']) ??
          PublishCitationStyle.apa,
      targetPages: (map['targetPages'] as num?)?.toInt() ?? 40,
      discipline: ThesisDiscipline(
        facultyId: d['facultyId']?.toString() ?? '',
        departmentId: d['departmentId']?.toString() ?? '',
        labelAr: d['labelAr']?.toString() ?? '',
        labelEn: d['labelEn']?.toString() ?? '',
        searchTerms: [
          for (final t in (d['searchTerms'] as List<dynamic>? ?? const []))
            t.toString(),
        ],
        alienHints: [
          for (final t in (d['alienHints'] as List<dynamic>? ?? const []))
            t.toString(),
        ],
      ),
    );
  }

  static Map<String, dynamic> _encodeWork(GroundedWork w) => {
        'title': w.title,
        'doi': w.doi,
        'year': w.year,
        'authors': w.authors,
        'source': w.source,
        'journal': w.journal,
        'abstractText': w.abstractText,
        'externalUrl': w.externalUrl,
      };

  static GroundedWork _decodeWork(Map<String, dynamic> map) {
    return GroundedWork(
      title: map['title']?.toString() ?? '',
      doi: map['doi']?.toString() ?? '',
      year: (map['year'] as num?)?.toInt(),
      authors: map['authors']?.toString() ?? '',
      source: map['source']?.toString() ?? '',
      journal: map['journal']?.toString(),
      abstractText: map['abstractText']?.toString() ?? '',
      externalUrl: map['externalUrl']?.toString() ?? '',
    );
  }

  static Map<String, dynamic> _encodeBundle(GroundedReferenceBundle b) => {
        'topic': b.topic,
        'works': [for (final w in b.works) _encodeWork(w)],
        'droppedInventedDois': b.droppedInventedDois,
      };

  static GroundedReferenceBundle _decodeBundle(Map<String, dynamic> map) {
    return GroundedReferenceBundle(
      topic: map['topic']?.toString() ?? '',
      works: [
        for (final w in (map['works'] as List<dynamic>? ?? const []))
          if (w is Map) _decodeWork(_asStringKeyedMap(w)),
      ],
      droppedInventedDois: (map['droppedInventedDois'] as num?)?.toInt() ?? 0,
    );
  }

  static Map<String, dynamic> _encodeMapRow(LiteratureMapRow row) => {
        'index': row.index,
        'work': _encodeWork(row.work),
        'focus': row.focus,
        'notes': row.notes,
      };

  static LiteratureMapRow _decodeMapRow(Map<String, dynamic> map) {
    return LiteratureMapRow(
      index: (map['index'] as num?)?.toInt() ?? 0,
      work: _decodeWork(_asStringKeyedMap(map['work'])),
      focus: map['focus']?.toString() ?? '',
      notes: map['notes']?.toString() ?? '',
    );
  }

  static Map<String, dynamic> _encodeParagraph(ThesisParagraph p) => {
        'id': p.id,
        'headingAr': p.headingAr,
        'headingEn': p.headingEn,
        'body': p.body,
        'fromGemini': p.fromGemini,
        'lastCommand': p.lastCommand,
        'references': [for (final w in p.references) _encodeWork(w)],
      };

  static ThesisParagraph _decodeParagraph(Map<String, dynamic> map) {
    return ThesisParagraph(
      id: map['id']?.toString() ?? '',
      headingAr: map['headingAr']?.toString() ?? '',
      headingEn: map['headingEn']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      fromGemini: map['fromGemini'] == true,
      lastCommand: map['lastCommand']?.toString() ?? '',
      references: [
        for (final w in (map['references'] as List<dynamic>? ?? const []))
          if (w is Map) _decodeWork(_asStringKeyedMap(w)),
      ],
    );
  }

  static Map<String, dynamic> _encodeChapter(ThesisChapter c) => {
        'id': c.id,
        'titleAr': c.titleAr,
        'titleEn': c.titleEn,
        'purposeAr': c.purposeAr,
        'purposeEn': c.purposeEn,
        'body': c.body,
        'fromGemini': c.fromGemini,
        'depth': c.depth.name,
        'paragraphs': [for (final p in c.paragraphs) _encodeParagraph(p)],
      };

  static ThesisChapter _decodeChapter(Map<String, dynamic> map) {
    return ThesisChapter(
      id: map['id']?.toString() ?? '',
      titleAr: map['titleAr']?.toString() ?? '',
      titleEn: map['titleEn']?.toString() ?? '',
      purposeAr: map['purposeAr']?.toString() ?? '',
      purposeEn: map['purposeEn']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      fromGemini: map['fromGemini'] == true,
      depth: _enumByName(ThesisChapterDepth.values, map['depth']) ??
          ThesisChapterDepth.full,
      paragraphs: [
        for (final p in (map['paragraphs'] as List<dynamic>? ?? const []))
          if (p is Map) _decodeParagraph(_asStringKeyedMap(p)),
      ],
    );
  }
}
