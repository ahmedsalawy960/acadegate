import 'package:flutter/material.dart';

enum AdvisorAgentId {
  researchIdea,
  thesisWriter,
  researchSimulation,
  literatureReview,
  citations,
  academicEditing,
  dataAnalysis,
  presentations,
  thesisPlanning,
  supervisorMatch,
  general,
}

class AdvisorAgent {
  final AdvisorAgentId id;
  final String nameAr;
  final String shortLabel;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> keywords;
  final String systemPrompt;
  final String samplePrompt;

  const AdvisorAgent({
    required this.id,
    required this.nameAr,
    required this.shortLabel,
    required this.description,
    required this.icon,
    required this.color,
    required this.keywords,
    required this.systemPrompt,
    required this.samplePrompt,
  });

  bool get usesAppData => id == AdvisorAgentId.supervisorMatch;
}

class AdvisorRoutePlan {
  final AdvisorAgentId primary;
  final List<AdvisorAgentId> supporting;
  final Map<AdvisorAgentId, int> scores;

  const AdvisorRoutePlan({
    required this.primary,
    this.supporting = const [],
    this.scores = const {},
  });

  List<AdvisorAgentId> get allAgents => [primary, ...supporting];

  bool get isMultiAgent => supporting.isNotEmpty;
}
