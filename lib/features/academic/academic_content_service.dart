import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'academic_fallback_data.dart';
import 'academic_models.dart';

class AcademicContentService {
  AcademicContentService._();

  static final AcademicContentService instance = AcademicContentService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Stream<AcademicContent>? _cachedWatchAll;

  List<AcademicSupervisor> _fallbackSupervisors({String? category}) {
    if (category == null) return fallbackSupervisors;
    return fallbackSupervisors
        .where((item) => item.category == category)
        .toList();
  }

  List<AcademicSupervisor> _parseSupervisors(
    QuerySnapshot<Map<String, dynamic>> snapshot, {
    String? category,
  }) {
    if (snapshot.docs.isEmpty) return _fallbackSupervisors(category: category);

    final parsed = snapshot.docs
        .map((doc) => AcademicSupervisor.fromMap(doc.data(), id: doc.id))
        .where((item) => item.name.trim().isNotEmpty)
        .toList();

    if (snapshot.docs.isEmpty) return _fallbackSupervisors(category: category);
    if (parsed.isEmpty) return _fallbackSupervisors(category: category);

    final approved =
        parsed.where((item) => item.isPubliclyVisible).toList();
    return approved;
  }

  List<AcademicResearchIdea> _parseIdeas(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (snapshot.docs.isEmpty) return fallbackResearchIdeas;

    final parsed = snapshot.docs
        .map((doc) => AcademicResearchIdea.fromMap(doc.data(), id: doc.id))
        .where((item) => item.title.trim().isNotEmpty)
        .toList();

    if (snapshot.docs.isEmpty) return fallbackResearchIdeas;
    if (parsed.isEmpty) return fallbackResearchIdeas;

    return parsed.where((item) => item.isPubliclyVisible).toList();
  }

  List<AcademicLab> _parseLabs(QuerySnapshot<Map<String, dynamic>> snapshot) {
    if (snapshot.docs.isEmpty) return fallbackLabs;

    final parsed = snapshot.docs
        .map((doc) => AcademicLab.fromMap(doc.data(), id: doc.id))
        .where((item) => item.name.trim().isNotEmpty)
        .toList();

    if (snapshot.docs.isEmpty) return fallbackLabs;
    if (parsed.isEmpty) return fallbackLabs;

    return parsed.where((item) => item.isPubliclyVisible).toList();
  }

  Stream<List<AcademicSupervisor>> supervisorsStream({String? category}) async* {
    yield _fallbackSupervisors(category: category);

    Query<Map<String, dynamic>> query = _db.collection('supervisors');
    if (category != null) {
      query = query.where('category', isEqualTo: category);
    }

    try {
      await for (final snapshot in query.snapshots()) {
        yield _parseSupervisors(snapshot, category: category);
      }
    } catch (error) {
      debugPrint('supervisorsStream error: $error');
      yield _fallbackSupervisors(category: category);
    }
  }

  Stream<List<AcademicResearchIdea>> researchIdeasStream() async* {
    yield fallbackResearchIdeas;

    try {
      await for (final snapshot in _db.collection('research_ideas').snapshots()) {
        yield _parseIdeas(snapshot);
      }
    } catch (error) {
      debugPrint('researchIdeasStream error: $error');
      yield fallbackResearchIdeas;
    }
  }

  Stream<List<AcademicLab>> labsStream() async* {
    yield fallbackLabs;

    try {
      await for (final snapshot in _db.collection('labs').snapshots()) {
        yield _parseLabs(snapshot);
      }
    } catch (error) {
      debugPrint('labsStream error: $error');
      yield fallbackLabs;
    }
  }

  Stream<AcademicContent> watchAll() {
    return _cachedWatchAll ??= _createWatchAllStream();
  }

  Stream<AcademicContent> _createWatchAllStream() {
    final controller = StreamController<AcademicContent>.broadcast();
    var supervisors = fallbackSupervisors;
    var ideas = fallbackResearchIdeas;
    var labs = fallbackLabs;
    final subscriptions = <StreamSubscription<dynamic>>[];

    void emit() {
      if (controller.isClosed) return;
      controller.add(
        AcademicContent(
          supervisors: supervisors,
          ideas: ideas,
          labs: labs,
        ),
      );
    }

    controller.onListen = () {
      emit();

      subscriptions.add(
        supervisorsStream().listen(
          (data) {
            supervisors = data;
            emit();
          },
          onError: (_) {
            supervisors = fallbackSupervisors;
            emit();
          },
        ),
      );

      subscriptions.add(
        researchIdeasStream().listen(
          (data) {
            ideas = data;
            emit();
          },
          onError: (_) {
            ideas = fallbackResearchIdeas;
            emit();
          },
        ),
      );

      subscriptions.add(
        labsStream().listen(
          (data) {
            labs = data;
            emit();
          },
          onError: (_) {
            labs = fallbackLabs;
            emit();
          },
        ),
      );
    };

    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
      subscriptions.clear();
    };

    return controller.stream;
  }

  Future<AcademicContent> fetchAll() async {
    try {
      final supervisors = await supervisorsStream().first.timeout(
        const Duration(seconds: 8),
      );
      final ideas = await researchIdeasStream().first.timeout(
        const Duration(seconds: 8),
      );
      final labs = await labsStream().first.timeout(
        const Duration(seconds: 8),
      );

      return AcademicContent(
        supervisors: supervisors,
        ideas: ideas,
        labs: labs,
      );
    } catch (error) {
      debugPrint('fetchAll fallback used: $error');
      return fallbackContent;
    }
  }
}
