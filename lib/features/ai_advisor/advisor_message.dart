enum AdvisorMessageRole { user, assistant }

class AdvisorMessage {
  final String id;
  final AdvisorMessageRole role;
  final String content;
  final DateTime createdAt;
  final bool usedCloudAi;
  final List<String> agentLabels;

  const AdvisorMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.usedCloudAi = false,
    this.agentLabels = const [],
  });

  AdvisorMessage copyWith({
    String? content,
    bool? usedCloudAi,
    List<String>? agentLabels,
  }) {
    return AdvisorMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      createdAt: createdAt,
      usedCloudAi: usedCloudAi ?? this.usedCloudAi,
      agentLabels: agentLabels ?? this.agentLabels,
    );
  }
}
