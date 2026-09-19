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

/// Persists Thesis Studio drafts per signed-in account (local + Firestore).
class ThesisStudioStorage {
  ThesisStudioStorage._();

  static final ThesisStudioStorage instance = ThesisStudioStorage._();

  static const _legacyKey = 'offline_thesis_studio_draft_v1';
  static const _collection = 'thesis_studio_drafts';

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  String _localKey(String? uid) =>
      (uid == null || uid.isEmpty) ? _legacyKey : '${_legacyKey}_$uid';

  Future<void> save(ThesisStudioSnapshot snapshot) async {
    final uid = _uid;
    final compact = snapshot.compactedForStorage();
    final map = compact.toMap();
    final encoded = jsonEncode(map);

    final prefs = await SharedPreferences.getInstance();
    final localOk = await prefs.setString(_localKey(uid), encoded);
    if (!localOk) {
      debugPrint('ThesisStudioStorage: local save failed (quota?)');
    }
    // Keep legacy key in sync for older builds while signed in.
    if (uid != null && uid.isNotEmpty) {
      await prefs.setString(_legacyKey, encoded);
    }

    if (uid == null || uid.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection(_collection).doc(uid).set({
        'uid': uid,
        'updatedAt': FieldValue.serverTimestamp(),
        'savedAtMs': compact.savedAt.millisecondsSinceEpoch,
        'payload': map,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('ThesisStudioStorage: cloud save failed: $e');
    }
  }

  Future<ThesisStudioSnapshot?> load() async {
    final uid = _uid;
    ThesisStudioSnapshot? cloud;
    if (uid != null && uid.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection(_collection)
            .doc(uid)
            .get();
        final data = doc.data();
        final payload = data?['payload'];
        if (payload is Map) {
          cloud = ThesisStudioSnapshot.fromMap(
            Map<String, dynamic>.from(payload),
          );
        }
      } catch (e) {
        debugPrint('ThesisStudioStorage: cloud load failed: $e');
      }
    }

    final prefs = await SharedPreferences.getInstance();
    ThesisStudioSnapshot? local;
    for (final key in <String>{
      if (uid != null && uid.isNotEmpty) _localKey(uid),
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
        debugPrint('ThesisStudioStorage: local decode failed for $key: $e');
      }
    }

    if (cloud == null) return local;
    if (local == null) return cloud;
    // Prefer newer snapshot.
    return cloud.savedAt.isAfter(local.savedAt) ? cloud : local;
  }

  Future<void> clear() async {
    final uid = _uid;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localKey(uid));
    await prefs.remove(_legacyKey);
    if (uid == null || uid.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection(_collection).doc(uid).delete();
    } catch (e) {
      debugPrint('ThesisStudioStorage: cloud clear failed: $e');
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
