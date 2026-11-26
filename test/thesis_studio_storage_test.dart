import 'dart:convert';

import 'package:acadegate/features/thesis_studio/thesis_studio_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeCloudStore implements ThesisStudioCloudStore {
  final projects = <String, Map<String, dynamic>>{};
  final versionDocs = <String, Map<String, dynamic>>{};
  Map<String, dynamic>? legacyPayload;
  bool failWrites = false;

  String _key(String uid, String projectId) => '$uid/$projectId';

  @override
  Future<List<ThesisProjectMeta>> listProjects(String uid) async {
    return [
      for (final entry in projects.entries)
        if (entry.key.startsWith('$uid/'))
          ThesisProjectMeta.fromMap(
            (entry.value['meta'] as Map).map((k, v) => MapEntry(k.toString(), v)),
          ),
    ];
  }

  @override
  Future<Map<String, dynamic>?> getProjectPayload(
    String uid,
    String projectId,
  ) async {
    final doc = projects[_key(uid, projectId)];
    final payload = doc?['payload'];
    if (payload is Map) return Map<String, dynamic>.from(payload);
    return null;
  }

  @override
  Future<void> putProject(
    String uid,
    ThesisProjectMeta meta,
    Map<String, dynamic> payload,
  ) async {
    if (failWrites) throw StateError('simulated cloud outage');
    projects[_key(uid, meta.id)] = {'meta': meta.toMap(), 'payload': payload};
  }

  @override
  Future<List<ThesisDraftVersionMeta>> listVersions(
    String uid,
    String projectId,
  ) async {
    final prefix = '$uid/$projectId/';
    final list = [
      for (final entry in versionDocs.entries)
        if (entry.key.startsWith(prefix))
          ThesisDraftVersionMeta(
            id: entry.key.substring(prefix.length),
            savedAtMs: (entry.value['savedAtMs'] as num?)?.toInt() ?? 0,
          ),
    ];
    list.sort((a, b) => b.savedAtMs.compareTo(a.savedAtMs));
    return list;
  }

  @override
  Future<Map<String, dynamic>?> getVersionPayload(
    String uid,
    String projectId,
    String versionId,
  ) async {
    final doc = versionDocs['$uid/$projectId/$versionId'];
    final payload = doc?['payload'];
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
    if (failWrites) throw StateError('simulated cloud outage');
    versionDocs['$uid/$projectId/${version.id}'] = {
      'savedAtMs': version.savedAtMs,
      'payload': payload,
    };
  }

  @override
  Future<void> deleteProject(String uid, String projectId) async {
    if (failWrites) throw StateError('simulated cloud outage');
    projects.remove(_key(uid, projectId));
    versionDocs.removeWhere((k, v) => k.startsWith('$uid/$projectId/'));
  }

  @override
  Future<Map<String, dynamic>?> getLegacyPayload(String uid) async =>
      legacyPayload;
}

ThesisStudioSnapshot _snapshot({
  required int savedAtMs,
  String goalText = 'test goal about analytical chemistry',
  String proposedTitle = '',
}) {
  return ThesisStudioSnapshot.fromMap({
    'savedAtMs': savedAtMs,
    'goalText': goalText,
    'targetPages': 40,
    'draft': {
      'proposedTitle': proposedTitle,
      'abstractText': proposedTitle.isEmpty ? '' : 'abstract of $proposedTitle',
    },
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCloudStore cloud;
  late ThesisStudioStorage storage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    cloud = FakeCloudStore();
    storage = ThesisStudioStorage.forTesting(cloud: cloud, uid: 'u1');
  });

  test('two projects keep independent contents and metas', () async {
    await storage.saveProject(
      'pa',
      _snapshot(savedAtMs: 1000, proposedTitle: 'First thesis'),
    );
    await storage.saveProject(
      'pb',
      _snapshot(savedAtMs: 2000, proposedTitle: 'Second thesis'),
    );

    final metas = await storage.listProjects();
    expect(metas.map((m) => m.id).toSet(), {'pa', 'pb'});
    expect(metas.firstWhere((m) => m.id == 'pa').title, 'First thesis');
    expect(metas.firstWhere((m) => m.id == 'pb').title, 'Second thesis');

    final a = await storage.loadProject('pa');
    final b = await storage.loadProject('pb');
    expect(a!.draft.proposedTitle, 'First thesis');
    expect(b!.draft.proposedTitle, 'Second thesis');
    expect(cloud.projects.keys.toSet(), {'u1/pa', 'u1/pb'});
  });

  test('save result reports honest success for signed-in user', () async {
    final result = await storage.saveProject(
      'pa',
      _snapshot(savedAtMs: 1000),
    );
    expect(result.localOk, isTrue);
    expect(result.cloudOk, isTrue);
    expect(result.cloudSkippedSignedOut, isFalse);
    expect(result.persistedAnywhere, isTrue);
  });

  test('signed-out save reports device-only, never claims cloud', () async {
    final guest = ThesisStudioStorage.forTesting(cloud: cloud, uid: null);
    final result = await guest.saveProject('pa', _snapshot(savedAtMs: 1000));
    expect(result.localOk, isTrue);
    expect(result.cloudOk, isFalse);
    expect(result.cloudSkippedSignedOut, isTrue);
    expect(result.persistedAnywhere, isTrue);
  });

  test('cloud failure is reported, draft still kept locally', () async {
    cloud.failWrites = true;
    final result = await storage.saveProject(
      'pa',
      _snapshot(savedAtMs: 1000, proposedTitle: 'Local only'),
    );
    expect(result.localOk, isTrue);
    expect(result.cloudOk, isFalse);
    expect(result.cloudSkippedSignedOut, isFalse);
    expect(cloud.projects, isEmpty);
    final loaded = await storage.loadProject('pa');
    expect(loaded!.draft.proposedTitle, 'Local only');
  });

  test('legacy single draft migrates into a project, legacy key untouched',
      () async {
    final legacy = _snapshot(savedAtMs: 5000, proposedTitle: 'Old draft');
    SharedPreferences.setMockInitialValues({
      'offline_thesis_studio_draft_v1_u1': jsonEncode(legacy.toMap()),
    });
    storage = ThesisStudioStorage.forTesting(cloud: cloud, uid: 'u1');

    final metas = await storage.listProjects();
    expect(metas.length, 1);
    expect(metas.single.id, 'legacy');
    expect(metas.single.title, 'Old draft');

    final active = await storage.loadActiveProject();
    expect(active!.draft.proposedTitle, 'Old draft');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('offline_thesis_studio_draft_v1_u1'), isNotNull);
  });

  test('version throttle: rapid edits record one version, force adds another',
      () async {
    await storage.saveProject(
      'pa',
      _snapshot(savedAtMs: 10000, proposedTitle: 'v1 title'),
    );
    // 1 minute later with changed content: within the 10-minute throttle.
    await storage.saveProject(
      'pa',
      _snapshot(savedAtMs: 70000, proposedTitle: 'v2 title'),
    );
    var versions = await storage.listVersions('pa');
    expect(versions.length, 1);

    // A forced version (what a restore does) bypasses the throttle.
    await storage.saveProject(
      'pa',
      _snapshot(savedAtMs: 80000, proposedTitle: 'v2 title'),
      forceVersion: true,
    );
    versions = await storage.listVersions('pa');
    expect(versions.length, 2);
    expect(versions.first.savedAtMs, 80000);

    // After the throttle window, normal saves version again.
    await storage.saveProject(
      'pa',
      _snapshot(savedAtMs: 80000 + 11 * 60 * 1000, proposedTitle: 'v3 title'),
    );
    versions = await storage.listVersions('pa');
    expect(versions.length, 3);
  });

  test('no new version when content is unchanged', () async {
    await storage.saveProject(
      'pa',
      _snapshot(savedAtMs: 10000, proposedTitle: 'Same'),
    );
    await storage.saveProject(
      'pa',
      _snapshot(savedAtMs: 10000 + 11 * 60 * 1000, proposedTitle: 'Same'),
    );
    final versions = await storage.listVersions('pa');
    expect(versions.length, 1);
  });

  test('older version restores its own content', () async {
    await storage.saveProject(
      'pa',
      _snapshot(savedAtMs: 10000, proposedTitle: 'Original'),
      forceVersion: true,
    );
    await storage.saveProject(
      'pa',
      _snapshot(savedAtMs: 20000, proposedTitle: 'Rewritten'),
      forceVersion: true,
    );
    final versions = await storage.listVersions('pa');
    expect(versions.length, 2);
    final restored = await storage.loadVersion('pa', versions.last.id);
    expect(restored!.draft.proposedTitle, 'Original');
    // Current state stays the rewritten one until the UI applies a restore.
    final current = await storage.loadProject('pa');
    expect(current!.draft.proposedTitle, 'Rewritten');
  });

  test('local version history is capped, newest kept', () async {
    // Signed out: exercises the local cap alone (cloud keeps its own cap).
    final guest = ThesisStudioStorage.forTesting(cloud: cloud, uid: null);
    for (var i = 1; i <= 12; i++) {
      await guest.saveProject(
        'pa',
        _snapshot(savedAtMs: i * 1000, proposedTitle: 'rev $i'),
        forceVersion: true,
      );
    }
    final versions = await guest.listVersions('pa');
    expect(versions.length, ThesisStudioStorage.localVersionCap);
    expect(versions.first.savedAtMs, 12000);
    expect(versions.last.savedAtMs, 3000);
  });

  test('deleteProject removes local and cloud data for that project only',
      () async {
    await storage.saveProject(
      'pa',
      _snapshot(savedAtMs: 1000, proposedTitle: 'Keep me not'),
    );
    await storage.saveProject(
      'pb',
      _snapshot(savedAtMs: 2000, proposedTitle: 'Keep me'),
    );
    final ok = await storage.deleteProject('pa');
    expect(ok, isTrue);
    final metas = await storage.listProjects();
    expect(metas.map((m) => m.id).toList(), ['pb']);
    expect(await storage.loadProject('pa'), isNull);
    expect(cloud.projects.keys.toList(), ['u1/pb']);
    final b = await storage.loadProject('pb');
    expect(b!.draft.proposedTitle, 'Keep me');
  });

  test('deriveTitle prefers proposed title, falls back to trimmed goal',
      () async {
    expect(
      ThesisStudioStorage.deriveTitle(
        _snapshot(savedAtMs: 0, proposedTitle: '  My title  '),
      ),
      'My title',
    );
    final longGoal = 'g' * 100;
    final derived = ThesisStudioStorage.deriveTitle(
      _snapshot(savedAtMs: 0, goalText: longGoal),
    );
    expect(derived.length, 61);
    expect(derived.endsWith('…'), isTrue);
    expect(
      ThesisStudioStorage.deriveTitle(_snapshot(savedAtMs: 0, goalText: '')),
      '',
    );
  });

  test('contentSignature is deterministic and content-sensitive', () {
    expect(
      ThesisStudioStorage.contentSignature('abc'),
      ThesisStudioStorage.contentSignature('abc'),
    );
    expect(
      ThesisStudioStorage.contentSignature('abc'),
      isNot(ThesisStudioStorage.contentSignature('abd')),
    );
    expect(
      ThesisStudioStorage.contentSignature('أطروحة عربية'),
      ThesisStudioStorage.contentSignature('أطروحة عربية'),
    );
  });
}
