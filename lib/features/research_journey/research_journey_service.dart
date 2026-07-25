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
    final activity = switch (stage) {
      ResearchJourneyStage.choosingTopic => ThesisActivityId.topicIdea.name,
      ResearchJourneyStage.findingSupervisor =>
        ThesisActivityId.supervisorMatch.name,
      ResearchJourneyStage.methodology =>
        ThesisActivityId.methodologyEthics.name,
      ResearchJourneyStage.dataCollection =>
        ThesisActivityId.dataCollection.name,
      ResearchJourneyStage.writing => ThesisActivityId.chapterWriting.name,
      ResearchJourneyStage.defense => ThesisActivityId.vivaPractice.name,
    };
    await ThesisProgressService.instance.recordActivity(activity);
  }
}
