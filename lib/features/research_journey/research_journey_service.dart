import 'package:firebase_auth/firebase_auth.dart';

import '../../core/offline/local_profile_store.dart';
import '../profile/academic_profile_service.dart';
import 'research_journey_stage.dart';
import 'thesis_progress.dart';
import 'thesis_progress_activity.dart';

class ResearchJourneyService {
  ResearchJourneyService._();

  static final ResearchJourneyService instance = ResearchJourneyService._();

  final _local = LocalProfileStore.instance;

  Future<bool> hasCompletedOnboarding() async {
    if (await _local.isOnboardingDone()) return true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final profile = await AcademicProfileService.instance.loadProfile();
    final stage = profile?.researchJourneyStage;
    if (stage != null && stage.isNotEmpty) {
      await _local.setOnboardingDone(done: true, stage: stage);
      return true;
    }
    return false;
  }

  Future<ResearchJourneyStage?> currentStage() async {
    final local = ResearchJourneyStageX.fromId(await _local.journeyStage());
    if (local != null) return local;

    final profile = await AcademicProfileService.instance.loadProfile();
    return ResearchJourneyStageX.fromId(profile?.researchJourneyStage);
  }

  Future<void> completeOnboarding(ResearchJourneyStage stage) async {
    await setStage(stage);
  }

  Future<void> setStage(ResearchJourneyStage stage) async {
    await _local.setOnboardingDone(done: true, stage: stage.id);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final existing = await AcademicProfileService.instance.loadProfile();
    if (existing != null) {
      await AcademicProfileService.instance.saveProfile(
        existing.copyWith(researchJourneyStage: stage.id),
      );
    }

    await _recordStageActivity(stage);
  }

  Future<void> _recordStageActivity(ResearchJourneyStage stage) async {
    // Selecting a stage means "I am here", not "I finished this step".
    // Credit only the steps the user has already passed.
    const order = ResearchJourneyStage.values;
    final idx = order.indexOf(stage);
    if (idx <= 0) return;

    final completed = <String>[];
    if (idx > order.indexOf(ResearchJourneyStage.choosingTopic)) {
      completed.add(ThesisActivityId.topicIdea.name);
    }
    if (idx > order.indexOf(ResearchJourneyStage.findingSupervisor)) {
      completed.add(ThesisActivityId.supervisorMatch.name);
    }
    if (idx > order.indexOf(ResearchJourneyStage.methodology)) {
      completed.add(ThesisActivityId.methodologyEthics.name);
    }
    if (idx > order.indexOf(ResearchJourneyStage.dataCollection)) {
      completed.add(ThesisActivityId.dataCollection.name);
    }
    if (idx > order.indexOf(ResearchJourneyStage.writing)) {
      completed.add(ThesisActivityId.chapterWriting.name);
    }

    for (final activityId in completed) {
      await ThesisProgressService.instance.recordActivity(activityId);
    }
  }
}
