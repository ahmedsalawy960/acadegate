import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../profile/academic_profile_service.dart';
import 'research_journey_service.dart';
import 'research_journey_stage.dart';
import 'thesis_progress.dart';
import 'thesis_progress_activity.dart';

class ThesisProgressSignals {
  ThesisProgressSignals._();

  static final ThesisProgressSignals instance = ThesisProgressSignals._();

  Future<Map<String, bool>> collect(ThesisProgress progress) async {
    final signals = <String, bool>{};

    for (final entry in progress.activityLog.entries) {
      signals[entry.key] = true;
    }

    final profile = await AcademicProfileService.instance.loadProfile();
    if (profile?.isComplete == true) {
      signals[ThesisActivityId.profileComplete.name] = true;
    }

    final stage = await ResearchJourneyService.instance.currentStage();
    if (stage != null) {
      _applyJourneyStage(signals, stage);
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _applyFirestoreSignals(signals, user.uid);
    }

    return signals;
  }

  void _applyJourneyStage(
    Map<String, bool> signals,
    ResearchJourneyStage stage,
  ) {
    const order = ResearchJourneyStage.values;
    final idx = order.indexOf(stage);
    // Being *at* a stage means that step is in progress — only mark
    // earlier stages complete (e.g. choosingTopic must stay 0% done).
    if (idx > order.indexOf(ResearchJourneyStage.choosingTopic)) {
      signals[ThesisActivityId.topicIdea.name] = true;
    }
    if (idx > order.indexOf(ResearchJourneyStage.findingSupervisor)) {
      signals[ThesisActivityId.supervisorMatch.name] = true;
    }
    if (idx > order.indexOf(ResearchJourneyStage.methodology)) {
      signals[ThesisActivityId.methodologyEthics.name] = true;
    }
    if (idx > order.indexOf(ResearchJourneyStage.dataCollection)) {
      signals[ThesisActivityId.dataCollection.name] = true;
    }
    if (idx > order.indexOf(ResearchJourneyStage.writing)) {
      signals[ThesisActivityId.chapterWriting.name] = true;
    }
    if (idx > order.indexOf(ResearchJourneyStage.defense)) {
      signals[ThesisActivityId.vivaPractice.name] = true;
    }
  }

  Future<void> _applyFirestoreSignals(
    Map<String, bool> signals,
    String uid,
  ) async {
    final db = FirebaseFirestore.instance;

    try {
      final publish = await db
          .collection('publish_manuscripts')
          .where('userId', isEqualTo: uid)
          .limit(1)
          .get();
      if (publish.docs.isNotEmpty) {
        signals[ThesisActivityId.publishManuscript.name] = true;
        signals[ThesisActivityId.chapterWriting.name] = true;
      }
    } catch (_) {}

    try {
      final viva = await db
          .collection('viva_sessions')
          .doc(uid)
          .collection('sessions')
          .limit(1)
          .get();
      if (viva.docs.isNotEmpty) {
        signals[ThesisActivityId.vivaPractice.name] = true;
      }
    } catch (_) {}

    try {
      final scans = await db
          .collection('originality_scans')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();
      if (scans.docs.isNotEmpty) {
        signals[ThesisActivityId.originalityCheck.name] = true;
      }
    } catch (_) {}

    try {
      final supervision = await db
          .collection('supervision_requests')
          .where('studentId', isEqualTo: uid)
          .limit(1)
          .get();
      if (supervision.docs.isNotEmpty) {
        signals[ThesisActivityId.supervisorMatch.name] = true;
      }
    } catch (_) {}

    try {
      final samples = await db
          .collection('sample_analysis_requests')
          .where('studentId', isEqualTo: uid)
          .limit(1)
          .get();
      if (samples.docs.isNotEmpty) {
        signals[ThesisActivityId.dataCollection.name] = true;
      }
    } catch (_) {}

    try {
      final orders = await db
          .collectionGroup('writing_orders')
          .where('userId', isEqualTo: uid)
          .limit(1)
          .get();
      if (orders.docs.isNotEmpty) {
        signals[ThesisActivityId.chapterWriting.name] = true;
      }
    } catch (_) {}
  }
}
