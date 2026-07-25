import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../core/locale/app_translate.dart';
import 'viva_models.dart';

class VivaSessionStore {
  VivaSessionStore._();

  static final VivaSessionStore instance = VivaSessionStore._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Map<String, VivaSavedSession> _local = {};
  final _updates = StreamController<void>.broadcast();
  bool _cloudPersistDisabled = false;

  bool get canPersist => FirebaseAuth.instance.currentUser != null;

  List<VivaSavedSession> get _sortedLocal => _local.values.toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  void _notify() {
    if (!_updates.isClosed) _updates.add(null);
  }

  CollectionReference<Map<String, dynamic>>? _sessionsRef() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('viva_sessions').doc(uid).collection('sessions');
  }

  Future<List<VivaSavedSession>> loadSessions({int limit = 30}) async {
    if (!canPersist) {
      return _local.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }

    try {
      final snap = await _sessionsRef()!
          .orderBy('updatedAt', descending: true)
          .limit(limit)
          .get()
          .timeout(const Duration(seconds: 12));
      return snap.docs.map((doc) => _sessionFromDoc(doc.id, doc.data())).toList();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        _cloudPersistDisabled = true;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Stream<List<VivaSavedSession>> watchSessions({int limit = 30}) async* {
    if (!canPersist) {
      yield _sortedLocal;
      await for (final _ in _updates.stream) {
        yield _sortedLocal;
      }
      return;
    }

    yield await loadSessions(limit: limit);
    await for (final _ in _updates.stream) {
      yield await loadSessions(limit: limit);
    }
  }

  Future<String> createSession({
    required VivaSessionConfig config,
    required VivaPhase phase,
    List<VivaMessage> messages = const [],
    VivaReport? report,
    int questionIndex = 0,
  }) async {
    final now = DateTime.now();
    final id = 'viva_${now.millisecondsSinceEpoch}';
    final title = config.thesisTitle.trim().isNotEmpty
        ? (config.thesisTitle.length > 48
            ? '${config.thesisTitle.substring(0, 48)}…'
            : config.thesisTitle)
        : appTr('محاكاة مناقشة', 'Viva simulation');

    final session = VivaSavedSession(
      id: id,
      title: title,
      config: config,
      phase: phase,
      messages: messages,
      report: report,
      questionIndex: questionIndex,
      createdAt: now,
      updatedAt: now,
    );

    await _save(session);
    return id;
  }

  Future<void> saveSession(VivaSavedSession session) async {
    await _save(session.copyWithUpdated(DateTime.now()));
  }

  Future<void> _save(VivaSavedSession session) async {
    if (!canPersist || _cloudPersistDisabled) {
      _local[session.id] = session;
      _notify();
      return;
    }

    try {
      final data = session.toMap();
      data['updatedAt'] = Timestamp.fromDate(session.updatedAt);
      data['createdAt'] = Timestamp.fromDate(session.createdAt);
      await _sessionsRef()!.doc(session.id).set(data, SetOptions(merge: true));
      _notify();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        _cloudPersistDisabled = true;
        if (kDebugMode) {
          debugPrint(
            'VivaSessionStore: cloud save disabled (deploy firestore rules for viva_sessions).',
          );
        }
      }
      _local[session.id] = session;
      _notify();
    } catch (_) {
      _local[session.id] = session;
      _notify();
    }
  }

  VivaSavedSession _sessionFromDoc(String id, Map<String, dynamic> data) {
    final normalized = Map<String, dynamic>.from(data);
    normalized['createdAt'] = _flexDate(data['createdAt']);
    normalized['updatedAt'] = _flexDate(data['updatedAt']);
    return VivaSavedSession.fromMap(id, normalized);
  }

  String _flexDate(dynamic value) {
    if (value is Timestamp) return value.toDate().toIso8601String();
    return value?.toString() ?? DateTime.now().toIso8601String();
  }

  Future<void> deleteSession(String id) async {
    _local.remove(id);
    _notify();
    if (!canPersist) return;
    try {
      await _sessionsRef()!.doc(id).delete();
    } catch (_) {}
  }
}

extension on VivaSavedSession {
  VivaSavedSession copyWithUpdated(DateTime updatedAt) => VivaSavedSession(
        id: id,
        title: title,
        config: config,
        phase: phase,
        messages: messages,
        report: report,
        questionIndex: questionIndex,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
