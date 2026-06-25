import 'advisor_attachment.dart';

enum AdvisorMessageRole { user, assistant }

class AdvisorMessage {
  final String id;
  final AdvisorMessageRole role;
  final String content;
  final DateTime createdAt;
  final bool usedCloudAi;
  final List<String> agentLabels;
  final List<AdvisorAttachment> attachments;

  const AdvisorMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.usedCloudAi = false,
    this.agentLabels = const [],
    this.attachments = const [],
  });

  AdvisorMessage copyWith({
    String? content,
    bool? usedCloudAi,
    List<String>? agentLabels,
    List<AdvisorAttachment>? attachments,
  }) {
    return AdvisorMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      createdAt: createdAt,
      usedCloudAi: usedCloudAi ?? this.usedCloudAi,
      agentLabels: agentLabels ?? this.agentLabels,
      attachments: attachments ?? this.attachments,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'role': role.name,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'usedCloudAi': usedCloudAi,
      'agentLabels': agentLabels,
      'attachments': attachments.map((item) => item.toMap()).toList(),
    };
  }

  factory AdvisorMessage.fromMap(String id, Map<String, dynamic> map) {
    final roleRaw = map['role']?.toString() ?? 'assistant';
    final createdRaw = map['createdAt'];
    DateTime createdAt;
    if (createdRaw is DateTime) {
      createdAt = createdRaw;
    } else {
      createdAt =
          DateTime.tryParse(createdRaw?.toString() ?? '') ?? DateTime.now();
    }

    return AdvisorMessage(
      id: id,
      role: roleRaw == 'user'
          ? AdvisorMessageRole.user
          : AdvisorMessageRole.assistant,
      content: map['content']?.toString() ?? '',
      createdAt: createdAt,
      usedCloudAi: map['usedCloudAi'] == true,
      agentLabels: (map['agentLabels'] as List<dynamic>?)
              ?.map((label) => label.toString())
              .toList() ??
          const [],
      attachments: (map['attachments'] as List<dynamic>?)
              ?.map(
                (item) => AdvisorAttachment.fromMap(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList() ??
          const [],
    );
  }
}
