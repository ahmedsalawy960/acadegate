import 'package:flutter/material.dart';

import 'advisor_branding.dart';
import 'advisor_message.dart';
import 'advisor_prompts.dart';
import 'advisor_router.dart';
import 'ai_advisor_service.dart';

class AiAdvisorScreen extends StatefulWidget {
  const AiAdvisorScreen({super.key});

  @override
  State<AiAdvisorScreen> createState() => _AiAdvisorScreenState();
}

class _AiAdvisorScreenState extends State<AiAdvisorScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _service = AiAdvisorService.instance;

  final List<AdvisorMessage> _messages = [];
  bool _isThinking = false;
  bool _showAgents = true;

  @override
  void initState() {
    super.initState();
    _messages.add(_service.welcomeMessage());
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isThinking) return;

    setState(() {
      _messages.add(
        AdvisorMessage(
          id: 'user_${DateTime.now().millisecondsSinceEpoch}',
          role: AdvisorMessageRole.user,
          content: trimmed,
          createdAt: DateTime.now(),
        ),
      );
      _isThinking = true;
      _showAgents = false;
    });
    _inputController.clear();
    _scrollToBottom();

    try {
      final reply = await _service.ask(
        message: trimmed,
        history: _messages,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(reply);
        _isThinking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          AdvisorMessage(
            id: 'err_${DateTime.now().millisecondsSinceEpoch}',
            role: AdvisorMessageRole.assistant,
            content: 'حدث خطأ أثناء المعالجة. حاول مرة أخرى.',
            createdAt: DateTime.now(),
          ),
        );
        _isThinking = false;
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const accent = Color(0xFF4527A0);

    return Scaffold(
      appBar: AppBar(
        title: Text(AdvisorBranding.assistantTitle),
        backgroundColor: accent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'الوكلاء المتخصصون',
            icon: Icon(_showAgents ? Icons.expand_less : Icons.hub_outlined),
            onPressed: () => setState(() => _showAgents = !_showAgents),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: Chip(
              label: Text(
                _service.isCloudAiEnabled
                    ? AdvisorBranding.cloudBadge
                    : AdvisorBranding.localBadge,
                style: const TextStyle(fontSize: 11, color: Colors.white),
              ),
              backgroundColor: Colors.white24,
              visualDensity: VisualDensity.compact,
              side: BorderSide.none,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showAgents) const _AgentsPanel(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              itemCount: _messages.length + (_isThinking ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isThinking && index == _messages.length) {
                  return const _TypingIndicator();
                }
                return _MessageBubble(message: _messages[index]);
              },
            ),
          ),
          if (_messages.length <= 2)
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: advisorQuickPrompts.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final prompt = advisorQuickPrompts[index];
                  return ActionChip(
                    label: Text(prompt.label, style: const TextStyle(fontSize: 12)),
                    onPressed: _isThinking
                        ? null
                        : () => _sendMessage(prompt.message),
                  );
                },
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      decoration: InputDecoration(
                        hintText: 'اطلب أي مساعدة أكاديمية...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _isThinking ? null : _sendMessage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isThinking
                        ? null
                        : () => _sendMessage(_inputController.text),
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      backgroundColor: theme.colorScheme.surfaceContainerHighest
          .withValues(alpha: 0.25),
    );
  }
}

class _AgentsPanel extends StatelessWidget {
  const _AgentsPanel();

  @override
  Widget build(BuildContext context) {
    final agents = AdvisorRouter.instance.specialistAgents();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'محرك واحد — وكلاء متخصصون',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: agents
                .map(
                  (agent) => Chip(
                    avatar: Icon(agent.icon, size: 16, color: agent.color),
                    label: Text(
                      agent.shortLabel,
                      style: const TextStyle(fontSize: 11),
                    ),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: agent.color.withValues(alpha: 0.08),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final AdvisorMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == AdvisorMessageRole.user;
    const userColor = Color(0xFF1A237E);
    const assistantColor = Colors.white;

    return Align(
      alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: isUser ? userColor : assistantColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isUser ? 4 : 14),
            bottomRight: Radius.circular(isUser ? 14 : 4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser && message.agentLabels.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: message.agentLabels
                      .map(
                        (label) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.deepPurple,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            Text(
              _formatContent(message.content),
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black87,
                height: 1.5,
              ),
            ),
            if (message.usedCloudAi) ...[
              const SizedBox(height: 6),
              Text(
                AdvisorBranding.poweredBy,
                style: TextStyle(
                  fontSize: 10,
                  color: isUser ? Colors.white70 : Colors.deepPurple,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatContent(String content) {
    return content.replaceAll('**', '').replaceAll('```', '');
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('يجمع الوكلاء المتخصصين...'),
          ],
        ),
      ),
    );
  }
}
