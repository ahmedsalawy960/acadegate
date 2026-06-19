import 'advisor_agent.dart';
import 'advisor_agent_registry.dart';
import 'advisor_query_parser.dart';

class AdvisorRouter {
  AdvisorRouter._();

  static final AdvisorRouter instance = AdvisorRouter._();

  static const _supportThreshold = 1;
  static const _maxSupporting = 2;

  AdvisorRoutePlan route(String message) {
    final parsed = AcademicQueryParser.parse(message);
    final goalAgent = _agentForGoal(parsed.goal);

    if (goalAgent != null && goalAgent != AdvisorAgentId.general) {
      final supporting = _keywordSupportingAgents(message, exclude: goalAgent);
      return AdvisorRoutePlan(
        primary: goalAgent,
        supporting: supporting,
      );
    }

    return _routeByKeywords(message);
  }

  AdvisorAgentId? _agentForGoal(AcademicQueryGoal goal) {
    return switch (goal) {
      AcademicQueryGoal.researchIdea => AdvisorAgentId.researchIdea,
      AcademicQueryGoal.thesisTitles ||
      AcademicQueryGoal.researchQuestion ||
      AcademicQueryGoal.summarize =>
        AdvisorAgentId.thesisPlanning,
      AcademicQueryGoal.supervisor => AdvisorAgentId.supervisorMatch,
      AcademicQueryGoal.thesisWriting => AdvisorAgentId.thesisWriter,
      AcademicQueryGoal.literatureReview => AdvisorAgentId.literatureReview,
      AcademicQueryGoal.citations => AdvisorAgentId.citations,
      AcademicQueryGoal.editing => AdvisorAgentId.academicEditing,
      AcademicQueryGoal.dataAnalysis => AdvisorAgentId.dataAnalysis,
      AcademicQueryGoal.presentation => AdvisorAgentId.presentations,
      AcademicQueryGoal.simulation => AdvisorAgentId.researchSimulation,
      AcademicQueryGoal.general => AdvisorAgentId.general,
    };
  }

  AdvisorRoutePlan _routeByKeywords(String message) {
    final text = message.toLowerCase();
    final scores = <AdvisorAgentId, int>{};

    for (final agent in AdvisorAgentRegistry.agents) {
      if (agent.id == AdvisorAgentId.general) continue;
      var hits = 0;
      for (final keyword in agent.keywords) {
        if (text.contains(keyword.toLowerCase())) hits++;
      }
      if (hits > 0) scores[agent.id] = hits;
    }

    if (scores.isEmpty) {
      return const AdvisorRoutePlan(primary: AdvisorAgentId.general);
    }

    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final primary = sorted.first.key;
    final supporting = sorted
        .skip(1)
        .where((entry) => entry.value >= _supportThreshold)
        .take(_maxSupporting)
        .map((entry) => entry.key)
        .toList();

    return AdvisorRoutePlan(
      primary: primary,
      supporting: supporting,
      scores: scores,
    );
  }

  List<AdvisorAgentId> _keywordSupportingAgents(
    String message, {
    required AdvisorAgentId exclude,
  }) {
    final plan = _routeByKeywords(message);
    return plan.allAgents
        .where((id) => id != exclude && id != AdvisorAgentId.general)
        .take(_maxSupporting)
        .toList();
  }

  List<AdvisorAgent> specialistAgents() {
    return AdvisorAgentRegistry.agents
        .where((agent) => agent.id != AdvisorAgentId.general)
        .toList();
  }
}
