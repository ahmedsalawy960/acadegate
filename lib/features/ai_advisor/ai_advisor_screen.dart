import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/theme/acadegate_theme.dart';
import '../../core/voice/voice_stt_service.dart';
import '../../core/voice/voice_tts_service.dart';
import '../auth/usage_quota_banner.dart';
import '../guides/section_guide_catalog.dart';
import '../guides/section_guide_screen.dart';
import '../viva_simulator/viva_screen.dart';
import 'advisor_attachment.dart';
import 'advisor_attachment_service.dart';
import 'advisor_branding.dart';
import 'advisor_chat_store.dart';
import 'advisor_conversation.dart';
import 'advisor_message.dart';
import 'advisor_prompts.dart';
import 'advisor_router.dart';
import 'ai_advisor_service.dart';
import 'catalog_hit.dart';
import 'catalog_hit_actions.dart';

class AiAdvisorScreen extends StatefulWidget {
  final String? initialMessage;

  const AiAdvisorScreen({super.key, this.initialMessage});

  @override
  State<AiAdvisorScreen> createState() => _AiAdvisorScreenState();
}

class _AiAdvisorScreenState extends State<AiAdvisorScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _service = AiAdvisorService.instance;
  final _store = AdvisorChatStore.instance;
  final _tts = VoiceTtsService.instance;
  final _stt = VoiceSttService.instance;

  final List<AdvisorMessage> _messages = [];
  final List<PendingAdvisorAttachment> _pendingAttachments = [];
  String? _activeConversationId;
  bool _isDraftConversation = true;
  bool _isThinking = false;
  bool _showAgents = true;
  bool _isLoadingHistory = true;
  int _sidebarRevision = 0;
  bool _initialMessageQueued = false;
  bool _voiceEnabled = true;
  bool _sttAvailable = false;

  static const _accent = Color(0xFF4527A0);
  static const _sidebarWidth = 280.0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _initVoice();
  }

  Future<void> _initVoice() async {
    _tts.onStateChanged = _onVoiceState;
    _stt.addListener(_onVoiceState);
    if (!mounted) return;
    setState(() => _sttAvailable = true);
  }

  void _onVoiceState() {
    if (mounted) setState(() {});
  }

  Future<void> _bootstrap() async {
    final seedMessage = widget.initialMessage?.trim();

    try {
      if (seedMessage != null && seedMessage.isNotEmpty) {
        _startDraftConversation();
        if (!mounted) return;
        setState(() => _isLoadingHistory = false);
        _queueInitialMessage(seedMessage);
        return;
      }

      final conversations = await _store.loadConversations();
      if (!mounted) return;

      if (conversations.isEmpty) {
        _startDraftConversation();
        setState(() => _isLoadingHistory = false);
        return;
      }

      await _openConversation(conversations.first.id, closeDrawer: false);
    } catch (_) {
      if (!mounted) return;
      _startDraftConversation();
      setState(() => _isLoadingHistory = false);
      if (seedMessage != null && seedMessage.isNotEmpty) {
        _queueInitialMessage(seedMessage);
      }
    }
  }

  void _queueInitialMessage(String message) {
    if (_initialMessageQueued) return;
    _initialMessageQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _sendMessage(message);
    });
  }

  void _bumpSidebar() {
    if (mounted) setState(() => _sidebarRevision++);
  }

  void _closeDrawerIfOpen() {
    final state = _scaffoldKey.currentState;
    if (state?.isDrawerOpen == true) {
      state!.closeDrawer();
    }
  }

  void _startDraftConversation() {
    setState(() {
      _activeConversationId = null;
      _isDraftConversation = true;
      _pendingAttachments.clear();
      _messages
        ..clear()
        ..add(_service.welcomeMessage());
      _showAgents = true;
      _sidebarRevision++;
    });
  }

  Future<void> _openConversation(
    String conversationId, {
    bool closeDrawer = true,
  }) async {
    setState(() => _isLoadingHistory = true);

    final stored = await _store.loadMessages(conversationId);
    if (!mounted) return;

    setState(() {
      _activeConversationId = conversationId;
      _isDraftConversation = false;
      _messages
        ..clear()
        ..addAll(
          stored.isEmpty ? [_service.welcomeMessage()] : stored,
        );
      _showAgents = stored.isEmpty;
      _isLoadingHistory = false;
    });

    if (closeDrawer && mounted) {
      _closeDrawerIfOpen();
    }
    _scrollToBottom();
  }

  Future<void> _newConversation() async {
    _startDraftConversation();
    _closeDrawerIfOpen();
  }

  Future<void> _deleteConversation(AdvisorConversation conversation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t('حذف المحادثة', 'Delete conversation')),
        content: Text(context.t(
          'هل تريد حذف «${conversation.title}» نهائياً؟',
          'Permanently delete "${conversation.title}"?',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.t('حذف', 'Delete')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _store.deleteConversation(conversation.id);

    if (_activeConversationId == conversation.id) {
      final remaining = await _store.loadConversations();
      if (!mounted) return;
      if (remaining.isEmpty) {
        _startDraftConversation();
      } else {
        await _openConversation(remaining.first.id, closeDrawer: false);
      }
    }

    if (mounted) setState(() {});
    _bumpSidebar();
  }

  Future<String> _ensureConversationId(String firstUserMessage) async {
    if (_activeConversationId != null) return _activeConversationId!;

    final id = await _store.createConversation(
      title: firstUserMessage.trim(),
    );
    if (!mounted) return id;

    setState(() {
      _activeConversationId = id;
      _isDraftConversation = false;
      _sidebarRevision++;
    });
    return id;
  }

  Future<void> _pickImage() async {
    if (_pendingAttachments.length >=
        AdvisorAttachmentService.maxAttachmentsPerMessage) {
      _showSnack(context.t(
        'يمكن إرفاق ${AdvisorAttachmentService.maxAttachmentsPerMessage} ملفات كحد أقصى',
        'You can attach up to ${AdvisorAttachmentService.maxAttachmentsPerMessage} files',
      ));
      return;
    }
    try {
      final picked = await AdvisorAttachmentService.instance.pickImage();
      if (picked == null || !mounted) return;
      setState(() => _pendingAttachments.add(picked));
    } catch (error) {
      _showSnack(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _pickFile() async {
    if (_pendingAttachments.length >=
        AdvisorAttachmentService.maxAttachmentsPerMessage) {
      _showSnack(context.t(
        'يمكن إرفاق ${AdvisorAttachmentService.maxAttachmentsPerMessage} ملفات كحد أقصى',
        'You can attach up to ${AdvisorAttachmentService.maxAttachmentsPerMessage} files',
      ));
      return;
    }
    try {
      final picked = await AdvisorAttachmentService.instance.pickFile();
      if (picked == null || !mounted) return;
      setState(() => _pendingAttachments.add(picked));
    } catch (error) {
      _showSnack(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _removePendingAttachment(int index) {
    setState(() => _pendingAttachments.removeAt(index));
  }

  Future<void> _showAttachOptions() async {
    if (_isThinking) return;

    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined, color: Color(0xFF4527A0)),
              title: Text(sheetContext.t('إرفاق صورة', 'Attach image')),
              subtitle: Text(sheetContext.t(
                'JPG · PNG · WebP',
                'JPG · PNG · WebP',
              )),
              onTap: () => Navigator.pop(sheetContext, 'image'),
            ),
            ListTile(
              leading: const Icon(
                Icons.insert_drive_file_outlined,
                color: Color(0xFF4527A0),
              ),
              title: Text(sheetContext.t('إرفاق ملف', 'Attach file')),
              subtitle: Text(sheetContext.t('PDF, Word, نص', 'PDF, Word, text')),
              onTap: () => Navigator.pop(sheetContext, 'file'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (choice == 'image') {
      await _pickImage();
    } else if (choice == 'file') {
      await _pickFile();
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _toggleMic() async {
    if (_isThinking || _stt.isTranscribing) return;
    if (_stt.isListening) {
      await _stt.stopListening();
      return;
    }
    await _tts.stop();
    final started = await _stt.startListening(
      existingText: _inputController.text,
      onText: (text, _) {
        if (!mounted) return;
        _inputController.text = text;
        _inputController.selection = TextSelection.collapsed(offset: text.length);
      },
    );
    if (!started && mounted) {
      final needsCloud = _stt.language != VoiceSttLanguage.english;
      _showSnack(
        needsCloud && !_service.isCloudAiEnabled
            ? context.t(
                'التعرف على العربية على Windows يحتاج تسجيل الدخول. على Chrome يُستخدم ميكروفون المتصفح.',
                'Arabic on Windows needs sign-in. On Chrome the browser microphone is used.',
              )
            : context.t(
                'التعرف على الصوت غير متاح — اسمح بالميكروفون ثم أعد المحاولة.',
                'Speech recognition unavailable — allow the microphone and try again.',
              ),
      );
    }
  }

  Future<void> _speakMessage(String content) async {
    if (!_voiceEnabled) {
      setState(() => _voiceEnabled = true);
    }
    await _tts.speak(content);
  }

  @override
  void dispose() {
    _stt.removeListener(_onVoiceState);
    _tts.onStateChanged = null;
    _stt.cancel();
    _tts.stop();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? text]) async {
    final trimmed = (text ?? _inputController.text).trim();
    final fallbackTitle = context.t('محادثة جديدة', 'New conversation');
    if ((trimmed.isEmpty && _pendingAttachments.isEmpty) || _isThinking) {
      return;
    }
    await _stt.cancel();
    await _tts.stop();

    final pending = List<PendingAdvisorAttachment>.from(_pendingAttachments);
    final geminiParts =
        AdvisorAttachmentService.instance.toGeminiParts(pending);
    final isFirstUserMessage = _messages.every(
      (m) => m.role != AdvisorMessageRole.user,
    );
    final titleSource = trimmed.isNotEmpty
        ? trimmed
        : pending.isNotEmpty
            ? pending.first.name
            : fallbackTitle;

    setState(() {
      _pendingAttachments.clear();
      _isThinking = true;
      _showAgents = false;
    });
    _inputController.clear();

    final conversationId = await _ensureConversationId(titleSource);
    List<AdvisorAttachment> uploaded = [];
    try {
      uploaded = await AdvisorAttachmentService.instance.uploadAll(
        pending: pending,
        conversationId: conversationId,
      );
    } catch (_) {
      uploaded = pending
          .map(
            (item) => AdvisorAttachment(
              name: item.name,
              mimeType: item.mimeType,
              url: '',
              isImage: item.isImage,
            ),
          )
          .toList();
      if (mounted && _store.canPersist) {
        _showSnack(context.t(
          'تعذر رفع المرفقات — فعّل Firebase Storage من لوحة Firebase',
          'Could not upload attachments — enable Firebase Storage in the Firebase console',
        ));
      }
    }

    final userMessage = AdvisorMessage(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      role: AdvisorMessageRole.user,
      content: trimmed,
      createdAt: DateTime.now(),
      attachments: uploaded,
    );

    if (!mounted) return;
    setState(() => _messages.add(userMessage));
    await _persistMessage(
      userMessage,
      titleIfFirstUserMessage: isFirstUserMessage ? titleSource : null,
      conversationId: conversationId,
    );
    _scrollToBottom();

    final List<AdvisorMessage> historyForAi = _messages.length > 1
        ? _messages.sublist(0, _messages.length - 1)
        : const [];

    try {
      final reply = await _service.ask(
        message: trimmed,
        history: historyForAi,
        attachments: geminiParts,
      );
      if (!mounted) return;
      setState(() {
        _isThinking = false;
        _messages.add(reply);
      });
      await _persistMessage(reply, conversationId: conversationId);
      if (_voiceEnabled && mounted) {
        await _tts.speak(reply.content);
      }
    } catch (_) {
      if (!mounted) return;
      final errorMessage = AdvisorMessage(
        id: 'err_${DateTime.now().millisecondsSinceEpoch}',
        role: AdvisorMessageRole.assistant,
        content: context.t(
          'حدث خطأ أثناء المعالجة. حاول مرة أخرى.',
          'An error occurred while processing. Please try again.',
        ),
        createdAt: DateTime.now(),
      );
      setState(() {
        _messages.add(errorMessage);
        _isThinking = false;
      });
      await _persistMessage(errorMessage, conversationId: conversationId);
    }

    _scrollToBottom();
  }

  Future<void> _persistMessage(
    AdvisorMessage message, {
    String? titleIfFirstUserMessage,
    String? conversationId,
  }) async {
    final id = conversationId ?? _activeConversationId;
    if (id == null) return;

    try {
      await _store.saveMessage(
        conversationId: id,
        message: message,
        titleIfFirstUserMessage: titleIfFirstUserMessage,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t(
            'تعذر حفظ الرسالة — تحقق من الاتصال',
            'Could not save message — check your connection',
          )),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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

  Widget _buildSidebar({bool inDrawer = false}) {
    return _ConversationSidebar(
      activeConversationId: _activeConversationId,
      isDraftConversation: _isDraftConversation,
      refreshToken: _sidebarRevision,
      inDrawer: inDrawer,
      onNewConversation: _newConversation,
      onOpenConversation: _openConversation,
      onDeleteConversation: _deleteConversation,
    );
  }

  Widget _buildChatPanel(ThemeData theme) {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: SectionGuideBanner(
            guideId: SectionGuideCatalog.ai,
            accent: _accent,
          ),
        ),
        const UsageQuotaBanner(
          showGemini: true,
          showScholar: false,
        ),
        if (_showAgents) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: _VivaPromoCard(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const VivaSimulatorScreen(),
                  ),
                );
              },
            ),
          ),
          const _AgentsPanel(),
        ],
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            itemCount: _messages.length + (_isThinking ? 1 : 0),
            itemBuilder: (context, index) {
              if (_isThinking && index == _messages.length) {
                return const _TypingIndicator();
              }
              return _MessageBubble(
                message: _messages[index],
                onSpeak: _messages[index].role == AdvisorMessageRole.assistant
                    ? () => _speakMessage(_messages[index].content)
                    : null,
              );
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
                  onPressed:
                      _isThinking ? null : () => _sendMessage(prompt.message),
                );
              },
            ),
          ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_pendingAttachments.isNotEmpty)
                  SizedBox(
                    height: 88,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _pendingAttachments.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final item = _pendingAttachments[index];
                        return _PendingAttachmentChip(
                          attachment: item,
                          onRemove: () => _removePendingAttachment(index),
                        );
                      },
                    ),
                  ),
                if (_pendingAttachments.isNotEmpty) const SizedBox(height: 8),
                if (_stt.isListening || _stt.isTranscribing)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _stt.isTranscribing
                          ? context.t(
                              'جاري تحويل صوتك إلى نص…',
                              'Turning your voice into text…',
                            )
                          : context.t(
                              'جارٍ الاستماع — اضغط الميكروفون للإيقاف',
                              'Listening — tap the mic to stop',
                            ),
                      style: TextStyle(
                        fontSize: 12,
                        color: _stt.isListening ? Colors.red[700] : _accent,
                      ),
                    ),
                  ),
                Wrap(
                  spacing: 6,
                  children: [
                    _SttLangChip(
                      label: context.t('تلقائي', 'Auto'),
                      selected: _stt.language == VoiceSttLanguage.auto,
                      onSelected: _stt.isListening || _stt.isTranscribing
                          ? null
                          : () => setState(
                                () => _stt.language = VoiceSttLanguage.auto,
                              ),
                    ),
                    _SttLangChip(
                      label: context.t('عربي', 'Arabic'),
                      selected: _stt.language == VoiceSttLanguage.arabic,
                      onSelected: _stt.isListening || _stt.isTranscribing
                          ? null
                          : () => setState(
                                () => _stt.language = VoiceSttLanguage.arabic,
                              ),
                    ),
                    _SttLangChip(
                      label: context.t('English', 'English'),
                      selected: _stt.language == VoiceSttLanguage.english,
                      onSelected: _stt.isListening || _stt.isTranscribing
                          ? null
                          : () => setState(
                                () => _stt.language = VoiceSttLanguage.english,
                              ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 1,
                      child: IconButton(
                        tooltip: context.t(
                          'إرفاق صورة أو ملف',
                          'Attach image or file',
                        ),
                        onPressed: _isThinking ? null : _showAttachOptions,
                        icon: const Icon(Icons.attach_file),
                        color: _accent,
                        iconSize: 26,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Material(
                      color: _stt.isListening ? Colors.red : Colors.white,
                      shape: const CircleBorder(),
                      elevation: 1,
                      child: IconButton(
                        tooltip: _stt.isListening
                            ? context.t('إيقاف التسجيل', 'Stop recording')
                            : (_sttAvailable
                                ? context.t(
                                    'تحدث إلى المستشار',
                                    'Speak to the advisor',
                                  )
                                : context.t(
                                    'تفعيل الميكروفون',
                                    'Enable the microphone',
                                  )),
                        onPressed: _isThinking || _stt.isTranscribing
                            ? null
                            : _toggleMic,
                        icon: Icon(
                          _stt.isListening ? Icons.mic : Icons.mic_none,
                          color: _stt.isListening ? Colors.white : _accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        enabled: !_stt.isTranscribing,
                        decoration: InputDecoration(
                          hintText: _stt.isTranscribing
                              ? context.t(
                                  'جاري تحويل الصوت...',
                                  'Converting speech...',
                                )
                              : _stt.isListening
                                  ? context.t('تحدّث الآن…', 'Speak now…')
                                  : context.t(
                                      'اكتب أو تحدّث…',
                                      'Type or speak…',
                                    ),
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
                        onSubmitted: _isThinking ? null : (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isThinking ? null : () => _sendMessage(),
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AcadeGateAppBar(
        title: Text(AdvisorBranding.assistantTitle),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: context.t('رجوع إلى البوابة', 'Back to portal'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          const SectionGuideAppBarButton(
            guideId: SectionGuideCatalog.ai,
            accent: _accent,
          ),
          IconButton(
            tooltip: _voiceEnabled
                ? context.t('إيقاف قراءة الردود', 'Stop reading replies')
                : context.t('تفعيل قراءة الردود', 'Read replies aloud'),
            icon: Icon(
              _tts.isSpeaking
                  ? Icons.volume_up
                  : (_voiceEnabled ? Icons.volume_up_outlined : Icons.volume_off),
            ),
            onPressed: () async {
              if (_tts.isSpeaking) {
                await _tts.stop();
                return;
              }
              setState(() => _voiceEnabled = !_voiceEnabled);
              if (!_voiceEnabled) await _tts.stop();
            },
          ),
          IconButton(
            tooltip: context.t(
              'محاكي لجنة المناقشة',
              'Viva committee simulator',
            ),
            icon: const Icon(Icons.gavel_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const VivaSimulatorScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: context.t('إرفاق ملف', 'Attach file'),
            icon: const Icon(Icons.attach_file),
            onPressed: _isThinking ? null : _showAttachOptions,
          ),
          IconButton(
            tooltip: context.t('محادثة جديدة', 'New conversation'),
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: _isThinking ? null : _newConversation,
          ),
          if (!wide)
            IconButton(
              tooltip: context.t('المحادثات السابقة', 'Previous conversations'),
              icon: const Icon(Icons.menu),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          IconButton(
            tooltip: context.t('الوكلاء المتخصصون', 'Specialist agents'),
            icon: Icon(_showAgents ? Icons.expand_less : Icons.smart_toy_outlined),
            onPressed: () => setState(() => _showAgents = !_showAgents),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: Center(
              child: Tooltip(
                message: _service.isCloudAiEnabled
                    ? context.t(
                        'المساعد الأكاديمي مفعّل',
                        'Academic Assistant is on',
                      )
                    : context.t(
                        'الوضع الأساسي — سجّل الدخول لتفعيل المساعد الأكاديمي',
                        'Basic mode — sign in to turn on the Academic Assistant',
                      ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white70),
                  ),
                  child: Text(
                    _service.isCloudAiEnabled
                        ? AdvisorBranding.cloudBadge
                        : AdvisorBranding.localBadge,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: wide
          ? null
          : Drawer(
              backgroundColor: AcadeGateColors.page,
              child: _buildSidebar(inDrawer: true),
            ),
      body: wide
          ? Row(
              children: [
                SizedBox(width: _sidebarWidth, child: _buildSidebar()),
                const VerticalDivider(width: 1),
                Expanded(child: _buildChatPanel(theme)),
              ],
            )
          : _buildChatPanel(theme),
      backgroundColor:
          theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
    );
  }
}

class _ConversationSidebar extends StatelessWidget {
  final String? activeConversationId;
  final bool isDraftConversation;
  final int refreshToken;
  final bool inDrawer;
  final VoidCallback onNewConversation;
  final Future<void> Function(String id, {bool closeDrawer}) onOpenConversation;
  final Future<void> Function(AdvisorConversation conversation)
      onDeleteConversation;

  const _ConversationSidebar({
    required this.activeConversationId,
    required this.isDraftConversation,
    required this.refreshToken,
    required this.inDrawer,
    required this.onNewConversation,
    required this.onOpenConversation,
    required this.onDeleteConversation,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AcadeGateColors.page,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (inDrawer)
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF4527A0)),
              child: Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  context.t('محادثاتك', 'Your conversations'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                context.t('المحادثات', 'Conversations'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AcadeGateColors.text,
                    ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: FilledButton.icon(
              onPressed: onNewConversation,
              icon: const Icon(Icons.add, size: 18),
              label: Text(context.t('محادثة جديدة', 'New conversation')),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4527A0),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (isDraftConversation)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Material(
                color: AcadeGateColors.card,
                borderRadius: BorderRadius.circular(10),
                child: ListTile(
                  dense: true,
                  leading: const Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: AcadeGateColors.gold,
                  ),
                  title: Text(
                    context.t('محادثة جديدة', 'New conversation'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AcadeGateColors.text,
                    ),
                  ),
                  subtitle: Text(
                    context.t('لم تُرسل رسائل بعد', 'No messages sent yet'),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AcadeGateColors.muted,
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: AdvisorChatStore.instance.canPersist
                ? StreamBuilder<List<AdvisorConversation>>(
                    stream: AdvisorChatStore.instance.watchConversations(),
                    builder: (context, snapshot) =>
                        _buildConversationList(context, snapshot.data ?? []),
                  )
                : FutureBuilder<List<AdvisorConversation>>(
                    key: ValueKey(refreshToken),
                    future: AdvisorChatStore.instance.loadConversations(),
                    builder: (context, snapshot) =>
                        _buildConversationList(context, snapshot.data ?? []),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationList(
    BuildContext context,
    List<AdvisorConversation> conversations,
  ) {
    if (conversations.isEmpty && !isDraftConversation) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            context.t(
              'لا توجد محادثات محفوظة بعد',
              'No saved conversations yet',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AcadeGateColors.muted),
          ),
        ),
      );
    }

    if (conversations.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      itemCount: conversations.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        final isActive =
            !isDraftConversation && conversation.id == activeConversationId;

        return Material(
          color: isActive ? const Color(0xFF1E3358) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: ListTile(
            dense: true,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            leading: Icon(
              Icons.chat_bubble_outline,
              size: 20,
              color: isActive ? AcadeGateColors.gold : AcadeGateColors.muted,
            ),
            title: Text(
              conversation.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: AcadeGateColors.text,
              ),
            ),
            subtitle: Text(
              _formatDate(context, conversation.updatedAt),
              style: const TextStyle(
                fontSize: 11,
                color: AcadeGateColors.muted,
              ),
            ),
            onTap: () => onOpenConversation(
              conversation.id,
              closeDrawer: true,
            ),
            trailing: IconButton(
              tooltip: context.t('حذف', 'Delete'),
              icon: const Icon(Icons.delete_outline, size: 18),
              color: Colors.red.shade300,
              onPressed: () => onDeleteConversation(conversation),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(BuildContext context, DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return context.t('الآن', 'Now');
    if (diff.inHours < 1) {
      return context.t('منذ ${diff.inMinutes} د', '${diff.inMinutes}m ago');
    }
    if (diff.inDays < 1) {
      return context.t('منذ ${diff.inHours} س', '${diff.inHours}h ago');
    }
    if (diff.inDays < 7) {
      return context.t('منذ ${diff.inDays} يوم', '${diff.inDays}d ago');
    }
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _VivaPromoCard extends StatelessWidget {
  final VoidCallback onTap;

  const _VivaPromoCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF880E4F).withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.gavel, color: const Color(0xFFF9A8D4)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t(
                        'محاكي لجنة المناقشة',
                        'Viva committee simulator',
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFF9A8D4),
                      ),
                    ),
                    Text(
                      context.t(
                        '3 مناقشين افتراضيين + تقرير تحضيري',
                        '3 virtual examiners + prep report',
                      ),
                      style: TextStyle(fontSize: 12, color: const Color(0xFFB7C3D6)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left, color: const Color(0xFFF9A8D4)),
            ],
          ),
        ),
      ),
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
          Text(
            context.t(
              'محرك واحد — وكلاء متخصصون',
              'One engine — specialist agents',
            ),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: agents
                .map(
                  (agent) => Tooltip(
                    message: agent.displayDescription,
                    child: Chip(
                      avatar: Icon(agent.icon, size: 16, color: agent.color),
                      label: Text(
                        agent.displayShortLabel,
                        style: const TextStyle(fontSize: 11),
                      ),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: agent.color.withValues(alpha: 0.08),
                    ),
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
  final VoidCallback? onSpeak;

  const _MessageBubble({required this.message, this.onSpeak});

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
            if (!isUser && onSpeak != null)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: context.t('اقرأ الرد', 'Read aloud'),
                  onPressed: onSpeak,
                  icon: Icon(
                    Icons.volume_up_outlined,
                    size: 18,
                    color: Colors.deepPurple.shade400,
                  ),
                ),
              ),
            if (!isUser && message.catalog.allHits.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...message.catalog.labs.map(
                (hit) => _CatalogHitCard(hit: hit),
              ),
              ...message.catalog.supervisors.map(
                (hit) => _CatalogHitCard(hit: hit),
              ),
            ],
            if (message.attachments.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...message.attachments.map(
                (attachment) => _AttachmentTile(
                  attachment: attachment,
                  onDarkBackground: isUser,
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

class _CatalogHitCard extends StatelessWidget {
  final CatalogHit hit;

  const _CatalogHitCard({required this.hit});

  @override
  Widget build(BuildContext context) {
    final isLab = hit.kind == CatalogHitKind.lab;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hit.title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
          if (hit.subtitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                hit.subtitle,
                style: TextStyle(fontSize: 12, color: const Color(0xFFB7C3D6)),
              ),
            ),
          if (hit.reason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                hit.reason,
                style: TextStyle(fontSize: 11.5, color: const Color(0xFFB7C3D6)),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _hitButton(
                context.t('فتح', 'Open'),
                () => CatalogHitActions.open(context, hit),
              ),
              if (isLab && hit.canBook)
                _hitButton(
                  context.t('حجز', 'Book'),
                  () => CatalogHitActions.book(context, hit),
                  filled: true,
                ),
              if (!isLab && hit.canContact)
                _hitButton(
                  context.t('تواصل', 'Contact'),
                  () => CatalogHitActions.contact(context, hit),
                  filled: true,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hitButton(String label, VoidCallback onTap, {bool filled = false}) {
    return FilledButton.tonal(
      onPressed: onTap,
      style: filled
          ? FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00695C),
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            )
          : FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(context.t(
              'يجمع الوكلاء المتخصصين...',
              'Consulting specialist agents...',
            )),
          ],
        ),
      ),
    );
  }
}

class _PendingAttachmentChip extends StatelessWidget {
  final PendingAdvisorAttachment attachment;
  final VoidCallback onRemove;

  const _PendingAttachmentChip({
    required this.attachment,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 76,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: attachment.isImage
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    Uint8List.fromList(attachment.bytes),
                    width: 76,
                    height: 76,
                    fit: BoxFit.cover,
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.insert_drive_file, size: 28),
                      const SizedBox(height: 4),
                      Text(
                        attachment.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ),
        ),
        Positioned(
          top: -6,
          left: -6,
          child: IconButton(
            style: IconButton.styleFrom(
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              minimumSize: const Size(24, 24),
              padding: EdgeInsets.zero,
            ),
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 14),
          ),
        ),
      ],
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  final AdvisorAttachment attachment;
  final bool onDarkBackground;

  const _AttachmentTile({
    required this.attachment,
    this.onDarkBackground = false,
  });

  Future<void> _openUrl() async {
    if (attachment.url.isEmpty) return;
    final uri = Uri.tryParse(attachment.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final labelColor = onDarkBackground ? Colors.white : Colors.black87;
    final subColor = onDarkBackground ? Colors.white70 : Colors.black54;

    if (attachment.isImage && attachment.url.isNotEmpty) {
      return GestureDetector(
        onTap: _openUrl,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            attachment.url,
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fileRow(labelColor, subColor),
          ),
        ),
      );
    }

    return InkWell(
      onTap: attachment.url.isEmpty ? null : _openUrl,
      borderRadius: BorderRadius.circular(8),
      child: _fileRow(labelColor, subColor),
    );
  }

  Widget _fileRow(Color labelColor, Color subColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: onDarkBackground
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.insert_drive_file, color: labelColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              attachment.name,
              style: TextStyle(color: labelColor, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (attachment.url.isNotEmpty)
            Icon(Icons.open_in_new, size: 16, color: subColor),
        ],
      ),
    );
  }
}

class _SttLangChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onSelected;

  const _SttLangChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: onSelected == null ? null : (_) => onSelected!(),
      selectedColor: const Color(0xFF4527A0).withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF4527A0) : const Color(0xFFB7C3D6),
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
