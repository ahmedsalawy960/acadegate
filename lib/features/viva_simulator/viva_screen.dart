import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/locale/l10n_lookup.dart';
import '../academic/faculty_categories.dart';
import '../ai_advisor/advisor_branding.dart';
import '../ai_advisor/gemini_advisor_client.dart';
import '../auth/login_screen.dart';
import '../profile/academic_profile_screen.dart';
import '../research_journey/thesis_progress.dart';
import '../research_journey/thesis_progress_activity.dart';
import 'viva_committee.dart';
import 'viva_models.dart';
import 'viva_pdf_service.dart';
import 'viva_service.dart';
import 'viva_session_store.dart';
import 'viva_stt_service.dart';
import 'viva_tts_service.dart';

class VivaSimulatorScreen extends StatefulWidget {
  const VivaSimulatorScreen({super.key});

  @override
  State<VivaSimulatorScreen> createState() => _VivaSimulatorScreenState();
}

class _VivaSimulatorScreenState extends State<VivaSimulatorScreen> {
  static const _brand = Color(0xFF880E4F);

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _service = VivaService.instance;
  final _store = VivaSessionStore.instance;
  final _pdfService = VivaPdfService.instance;
  final _tts = VivaTtsService.instance;
  final _stt = VivaSttService.instance;
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _specializationController = TextEditingController();
  final _universityController = TextEditingController();
  final _answerController = TextEditingController();
  final _scrollController = ScrollController();

  VivaPhase _phase = VivaPhase.setup;
  String _degree = 'ماجستير';
  String _methodology = 'كمي';
  int _questionCount = 10;
  VivaAnswerMode _answerMode = VivaAnswerMode.written;
  String? _facultyCategoryId;
  String? _pdfFileName;
  String? _thesisExcerpt;
  String? _defenseContext;
  String? _sessionId;
  DateTime? _sessionCreatedAt;
  final List<VivaMessage> _messages = [];
  int _questionIndex = 0;
  bool _isLoading = false;
  bool _extractingPdf = false;
  bool _profileLoaded = false;
  bool _voiceEnabled = false;
  bool _sttAvailable = false;
  VivaReport? _report;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _tts.init();
    _initStt();
  }

  Future<void> _initStt() async {
    _stt.onStateChanged = () {
      if (mounted) setState(() {});
    };
    final available = await _stt.init();
    if (!mounted) return;
    setState(() => _sttAvailable = available);
  }

  Future<void> _toggleVoiceAnswer() async {
    if (_isLoading || _stt.isTranscribing) return;

    if (_stt.isListening) {
      await _stt.stopListening();
      return;
    }

    await _tts.stop();

    final started = await _stt.startListening(
      existingText: _answerController.text,
      onText: (text, _) {
        if (!mounted) return;
        _answerController.text = text;
        _answerController.selection = TextSelection.collapsed(
          offset: text.length,
        );
      },
    );

    if (!started && mounted) {
      final needsGemini = _stt.language != VivaSttLanguage.english;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            needsGemini && !_service.isCloudEnabled
                ? context.t(
                    'التعرف على العربية يحتاج تسجيل الدخول لتفعيل الذكاء السحابي',
                    'Arabic speech recognition needs sign-in to enable cloud AI',
                  )
                : context.t(
                    'التعرف على الصوت غير متاح — تحقق من الميكروفون',
                    'Speech recognition unavailable — check your microphone',
                  ),
          ),
        ),
      );
    }
  }

  Future<void> _loadProfile() async {
    final config = await _service.configFromProfile();
    if (!mounted) return;
    if (config != null) {
      _titleController.text = config.thesisTitle;
      _summaryController.text = config.thesisSummary;
      _specializationController.text = config.specialization;
      _universityController.text = config.university;
      _degree = config.degree;
      _methodology = config.methodology;
      _facultyCategoryId = config.facultyCategoryId;
    }
    setState(() => _profileLoaded = true);
  }

  VivaSessionConfig get _config => VivaSessionConfig(
        thesisTitle: _titleController.text.trim(),
        thesisSummary: _summaryController.text.trim(),
        degree: _degree,
        methodology: _methodology,
        specialization: _specializationController.text.trim(),
        university: _universityController.text.trim(),
        pdfFileName: _pdfFileName,
        thesisExcerpt: _thesisExcerpt,
        defenseContext: _defenseContext,
        questionCount: _questionCount,
        answerMode: _answerMode,
        facultyCategoryId: _facultyCategoryId,
      );

  int get _maxQuestions => _config.resolvedQuestionCount;

  Future<void> _persistSession() async {
    if (_sessionId == null) return;
    final now = DateTime.now();
    final session = VivaSavedSession(
      id: _sessionId!,
      title: _config.thesisTitle.isNotEmpty
          ? (_config.thesisTitle.length > 48
              ? '${_config.thesisTitle.substring(0, 48)}…'
              : _config.thesisTitle)
          : 'Viva',
      config: _config,
      phase: _phase,
      messages: List.from(_messages),
      report: _report,
      questionIndex: _questionIndex,
      createdAt: _sessionCreatedAt ?? now,
      updatedAt: now,
    );
    await _store.saveSession(session);
  }

  Future<void> _pickAndExtractPdf() async {
    if (!_service.isCloudEnabled) {
      if (GeminiAdvisorClient.needsSignInForCloudAi && mounted) {
        final goLogin = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(ctx.t('تسجيل الدخول مطلوب', 'Sign-in required')),
            content: Text(
              ctx.t(
                'رفع PDF واستخراج بيانات الرسالة يعمل عبر الذكاء السحابي بعد تسجيل الدخول — بدون مفتاح محلي.',
                'PDF upload and thesis extraction uses cloud AI after you sign in — no local API key needed.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(ctx.t('لاحقاً', 'Later')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(ctx.t('تسجيل الدخول', 'Sign in')),
              ),
            ],
          ),
        );
        if (goLogin == true && mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
          if (!mounted) return;
          if (!_service.isCloudEnabled) return;
        } else {
          return;
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t(
                'رفع PDF واستخراج البيانات غير متاح حالياً',
                'PDF upload and extraction is unavailable right now',
              ),
            ),
          ),
        );
        return;
      }
    }

    try {
      final picked = await _pdfService.pickPdf();
      if (picked == null || !mounted) return;

      setState(() => _extractingPdf = true);
      final extracted = await _pdfService.extractFromPdf(
        bytes: picked.bytes,
        fileName: picked.name,
      );
      if (!mounted) return;

      _titleController.text = extracted.title;
      _summaryController.text = extracted.summary;
      if (extracted.specialization != null) {
        _specializationController.text = extracted.specialization!;
      }
      if (extracted.methodology != null) {
        final m = extracted.methodology!.toLowerCase();
        if (m.contains('نوع') || m.contains('qual')) {
          _methodology = 'نوعي';
        } else if (m.contains('مختلط') || m.contains('mixed')) {
          _methodology = 'مختلط';
        } else {
          _methodology = 'كمي';
        }
      }
      setState(() {
        _pdfFileName = extracted.fileName;
        _thesisExcerpt = extracted.excerpt;
        _defenseContext = extracted.defenseContext;
        _extractingPdf = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'تم استخراج بيانات الرسالة — الأسئلة ستُبنى من محتوى رسالتك',
              'Thesis extracted — questions will be grounded in your thesis content',
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _extractingPdf = false);
      final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _clearPdf() {
    setState(() {
      _pdfFileName = null;
      _thesisExcerpt = null;
      _defenseContext = null;
    });
  }

  Future<void> _startSession() async {
    if (!_config.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'أدخل عنواناً (5 أحرف على الأقل) وملخصاً (40 حرفاً على الأقل)',
              'Enter a title (min 5 chars) and summary (min 40 chars)',
            ),
          ),
        ),
      );
      return;
    }

    _sessionId = await _store.createSession(
      config: _config,
      phase: VivaPhase.session,
    );
    _sessionCreatedAt = DateTime.now();

    setState(() {
      _phase = VivaPhase.session;
      _messages.clear();
      _questionIndex = 0;
      _report = null;
      _voiceEnabled = _config.isOralMode;
      _tts.setEnabled(_voiceEnabled);
      _messages.add(_service.systemMessage(_service.introMessage(_config)));
      _isLoading = true;
    });

    await _askNextQuestion();
    await _persistSession();
  }

  Future<void> _askNextQuestion() async {
    await _stt.stopListening();
    final member = _service.memberForQuestionIndex(_questionIndex);
    final question = await _service.generateQuestion(
      config: _config,
      member: member,
      questionIndex: _questionIndex,
      history: _messages,
    );
    if (!mounted) return;
    setState(() {
      _messages.add(_service.committeeMessage(member: member, content: question));
      _isLoading = false;
    });
    _scrollToBottom();
    await _tts.speakCommitteeQuestion(member: member, question: question);
  }

  Future<void> _submitAnswer() async {
    final answer = _answerController.text.trim();
    if (answer.isEmpty || _isLoading) return;

    await _stt.stopListening();
    _answerController.clear();
    setState(() {
      _messages.add(_service.studentMessage(answer));
      _questionIndex++;
      _isLoading = _questionIndex < _maxQuestions;
    });
    _scrollToBottom();
    await _persistSession();

    if (_questionIndex < _maxQuestions) {
      await _askNextQuestion();
      await _persistSession();
    } else {
      await _generateReport();
    }
  }

  Future<void> _generateReport() async {
    if (_messages.where((m) => m.role == VivaMessageRole.student).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'أجب على سؤال واحد على الأقل قبل التقرير',
              'Answer at least one question before generating the report',
            ),
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    await _tts.stop();
    final report = await _service.generateReport(
      config: _config,
      history: _messages,
    );
    if (!mounted) return;
    setState(() {
      _report = report;
      _phase = VivaPhase.report;
      _isLoading = false;
    });
    await _persistSession();
    await ThesisProgressService.instance.recordActivity(
      ThesisActivityId.vivaPractice.name,
    );
  }

  Future<void> _loadSavedSession(VivaSavedSession session) async {
    await _tts.stop();
    _titleController.text = session.config.thesisTitle;
    _summaryController.text = session.config.thesisSummary;
    _specializationController.text = session.config.specialization;
    _universityController.text = session.config.university;
    _degree = session.config.degree;
    _methodology = session.config.methodology;
    _questionCount = session.config.resolvedQuestionCount;
    _answerMode = session.config.answerMode;
    _facultyCategoryId = session.config.facultyCategoryId;
    _pdfFileName = session.config.pdfFileName;
    _thesisExcerpt = session.config.thesisExcerpt;
    _defenseContext = session.config.defenseContext;
    setState(() {
      _sessionId = session.id;
      _sessionCreatedAt = session.createdAt;
      _phase = session.phase;
      _messages
        ..clear()
        ..addAll(session.messages);
      _questionIndex = session.questionIndex;
      _report = session.report;
      _voiceEnabled = session.config.isOralMode || _voiceEnabled;
      _tts.setEnabled(_voiceEnabled);
      _isLoading = false;
    });
    if (!mounted) return;
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.pop(context);
    }
  }

  Future<void> _deleteSession(VivaSavedSession session) async {
    await _store.deleteSession(session.id);
    if (_sessionId == session.id) {
      _restart();
    }
    if (mounted) setState(() {});
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _restart() {
    _tts.stop();
    setState(() {
      _phase = VivaPhase.setup;
      _messages.clear();
      _questionIndex = 0;
      _report = null;
      _sessionId = null;
      _sessionCreatedAt = null;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _stt.onStateChanged = null;
    _stt.dispose();
    _tts.dispose();
    _titleController.dispose();
    _summaryController.dispose();
    _specializationController.dispose();
    _universityController.dispose();
    _answerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AcadeGateAppBar(
        title: Text(context.t('محاكي لجنة المناقشة', 'Viva committee simulator')),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: context.t(
              _voiceEnabled ? 'إيقاف الصوت' : 'تفعيل الصوت',
              _voiceEnabled ? 'Disable voice' : 'Enable voice',
            ),
            icon: Icon(_voiceEnabled ? Icons.volume_up : Icons.volume_off),
            onPressed: () {
              setState(() {
                _voiceEnabled = !_voiceEnabled;
                _tts.setEnabled(_voiceEnabled);
              });
            },
          ),
          IconButton(
            tooltip: context.t('الجلسات المحفوظة', 'Saved sessions'),
            icon: const Icon(Icons.history),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          if (_phase == VivaPhase.session)
            TextButton(
              onPressed: _isLoading ? null : _generateReport,
              child: Text(
                context.t('التقرير', 'Report'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Center(
              child: Chip(
                label: Text(
                  _service.isCloudEnabled
                      ? AdvisorBranding.cloudBadge
                      : AdvisorBranding.localBadge,
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
                backgroundColor: Colors.black26,
                side: BorderSide.none,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
      drawer: _SessionsDrawer(
        onOpen: _loadSavedSession,
        onDelete: _deleteSession,
        canPersist: _store.canPersist,
      ),
      body: switch (_phase) {
        VivaPhase.setup => _buildSetup(),
        VivaPhase.session => _buildSession(),
        VivaPhase.report => _buildReport(),
      },
    );
  }

  Widget _buildSetup() {
    if (!_profileLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _heroCard(),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.t('رفع رسالة PDF (حتى 40 ميجا)', 'Upload thesis PDF (up to 40 MB)'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  context.t(
                    'يستخرج العنوان والملخص والمنهجية ونقاط المناقشة من نص الرسالة (يتطلب Gemini)',
                    'Extracts title, summary, methodology, and defense points from your thesis text (requires Gemini)',
                  ),
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                if (_pdfFileName != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                    title: Text(_pdfFileName!, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _clearPdf,
                    ),
                  ),
                FilledButton.icon(
                  onPressed: _extractingPdf ? null : _pickAndExtractPdf,
                  style: FilledButton.styleFrom(backgroundColor: _brand),
                  icon: _extractingPdf
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.upload_file),
                  label: Text(
                    _extractingPdf
                        ? context.t('جاري تحليل PDF...', 'Analyzing PDF...')
                        : context.t('اختر ملف PDF', 'Choose PDF file'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          context.t('بيانات الرسالة', 'Thesis details'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: context.t('عنوان الرسالة / البحث', 'Thesis / research title'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _summaryController,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: context.t(
              'ملخص (المشكلة، الأهداف، المنهجية، النتائج المتوقعة)',
              'Summary (problem, aims, methodology, expected findings)',
            ),
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _specializationController,
          decoration: InputDecoration(
            labelText: context.t('التخصص', 'Field of study'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _universityController,
          decoration: InputDecoration(
            labelText: context.t('الجامعة', 'University'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey(_degree),
          initialValue: _degree,
          decoration: InputDecoration(
            labelText: context.t('الدرجة', 'Degree'),
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(
              value: 'ماجستير',
              child: Text(context.t('ماجستير', "Master's")),
            ),
            DropdownMenuItem(
              value: 'دكتوراه',
              child: Text(context.t('دكتوراه', 'PhD')),
            ),
          ],
          onChanged: (v) => setState(() => _degree = v ?? _degree),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey(_methodology),
          initialValue: _methodology,
          decoration: InputDecoration(
            labelText: context.t('المنهجية', 'Methodology'),
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(
              value: 'كمي',
              child: Text(context.t('كمي', 'Quantitative')),
            ),
            DropdownMenuItem(
              value: 'نوعي',
              child: Text(context.t('نوعي', 'Qualitative')),
            ),
            DropdownMenuItem(
              value: 'مختلط',
              child: Text(context.t('مختلط', 'Mixed methods')),
            ),
          ],
          onChanged: (v) => setState(() => _methodology = v ?? _methodology),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          key: ValueKey(_facultyCategoryId ?? 'none'),
          initialValue: _facultyCategoryId,
          decoration: InputDecoration(
            labelText: context.t('الكلية / التخصص العام', 'Faculty / broad field'),
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(
              value: null,
              child: Text(context.t('عام / غير محدد', 'General / unspecified')),
            ),
            ...facultyCategories.map(
              (f) => DropdownMenuItem(
                value: f.id,
                child: Text(L10nLookup.facultyTitleStatic(f.id)),
              ),
            ),
          ],
          onChanged: (v) => setState(() => _facultyCategoryId = v),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          key: ValueKey(_questionCount),
          initialValue: _questionCount,
          decoration: InputDecoration(
            labelText: context.t('عدد الأسئلة', 'Number of questions'),
            border: const OutlineInputBorder(),
          ),
          items: VivaSessionConfig.questionCountOptions
              .map(
                (n) => DropdownMenuItem(
                  value: n,
                  child: Text(context.t('$n أسئلة', '$n questions')),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _questionCount = v ?? _questionCount),
        ),
        const SizedBox(height: 12),
        Text(
          context.t('طريقة الإجابة', 'Answer mode'),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        SegmentedButton<VivaAnswerMode>(
          segments: [
            ButtonSegment(
              value: VivaAnswerMode.written,
              icon: const Icon(Icons.keyboard_alt_outlined),
              label: Text(context.t('كتابي', 'Written')),
            ),
            ButtonSegment(
              value: VivaAnswerMode.oral,
              icon: const Icon(Icons.record_voice_over_outlined),
              label: Text(context.t('شفهي', 'Oral')),
            ),
          ],
          selected: {_answerMode},
          onSelectionChanged: (set) {
            final mode = set.first;
            setState(() {
              _answerMode = mode;
              if (mode == VivaAnswerMode.oral) {
                _voiceEnabled = true;
                _tts.setEnabled(true);
              }
            });
          },
        ),
        const SizedBox(height: 8),
        Text(
          _answerMode == VivaAnswerMode.oral
              ? context.t(
                  'الوضع الشفهي: تُقرأ الأسئلة صوتياً وتُفضَّل الإجابة بالميكروفون كما في المناقشة الحقيقية.',
                  'Oral mode: questions are spoken and mic answers are preferred, like a real viva.',
                )
              : context.t(
                  'الوضع الكتابي: اكتب إجاباتك — مناسب للتدريب الهادئ ومراجعة الصياغة.',
                  'Written mode: type your answers — good for calm practice and wording review.',
                ),
          style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.35),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AcademicProfileScreen(),
              ),
            );
            _loadProfile();
          },
          icon: const Icon(Icons.person_outline),
          label: Text(
            context.t('تحديث من الملف الأكاديمي', 'Refresh from academic profile'),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: _startSession,
            style: FilledButton.styleFrom(
              backgroundColor: _brand,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(
              context.t('بدء المحاكاة', 'Start simulation'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          context.t(
            '3 أعضاء لجنة • $_questionCount أسئلة • ${_answerMode == VivaAnswerMode.oral ? 'شفهي' : 'كتابي'} • أسئلة بأسلوب مناقشات حقيقية',
            '3 committee members • $_questionCount questions • ${_answerMode == VivaAnswerMode.oral ? 'oral' : 'written'} • real-viva style questions',
          ),
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
      ],
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_brand, _brand.withValues(alpha: 0.75)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gavel, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.t(
                    'تدرّب على المناقشة قبل الموعد الحقيقي',
                    'Practice your defense before the real date',
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: VivaCommittee.members
                .map(
                  (m) => Chip(
                    avatar: Icon(m.icon, size: 16, color: m.color),
                    label: Text(
                      m.displayRole,
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor: Colors.white,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSession() {
    final answered =
        _messages.where((m) => m.role == VivaMessageRole.student).length;
    final progress = answered / _maxQuestions;

    return Column(
      children: [
        if (_voiceEnabled || _stt.isListening || _stt.isTranscribing)
          Material(
            color: _stt.isListening
                ? Colors.red.withValues(alpha: 0.08)
                : (_stt.isTranscribing
                    ? Colors.orange.withValues(alpha: 0.08)
                    : Colors.purple.withValues(alpha: 0.08)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    _stt.isTranscribing
                        ? Icons.transcribe
                        : (_stt.isListening
                            ? Icons.mic
                            : (_tts.isSpeaking
                                ? Icons.record_voice_over
                                : Icons.hearing)),
                    color: _stt.isTranscribing
                        ? Colors.orange[800]
                        : (_stt.isListening
                            ? Colors.red[800]
                            : Colors.purple[800]),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _stt.isTranscribing
                          ? context.t(
                              'جاري تحويل صوتك إلى نص...',
                              'Converting your speech to text...',
                            )
                          : (_stt.isListening
                              ? (_stt.usesCloud
                                  ? context.t(
                                      'سجّل إجابتك ثم أوقف الميكروفون',
                                      'Record your answer, then stop the mic',
                                    )
                                  : context.t(
                                      'يستمع إلى إجابتك... اضغط الميكروفون للإيقاف',
                                      'Listening… tap the mic to stop',
                                    ))
                              : (_tts.isSpeaking
                                  ? context.t(
                                      'اللجنة تتحدث...',
                                      'Committee is speaking...',
                                    )
                                  : context.t(
                                      'الوضع الصوتي مفعّل',
                                      'Voice mode is on',
                                    ))),
                      style: TextStyle(
                        fontSize: 13,
                        color: _stt.isTranscribing
                            ? Colors.orange[900]
                            : (_stt.isListening
                                ? Colors.red[900]
                                : Colors.purple[900]),
                      ),
                    ),
                  ),
                  if (_stt.isListening)
                    TextButton(
                      onPressed: _stt.stopListening,
                      child: Text(context.t('إيقاف', 'Stop')),
                    )
                  else if (_tts.isSpeaking)
                    TextButton(
                      onPressed: _tts.stop,
                      child: Text(context.t('إيقاف', 'Stop')),
                    ),
                ],
              ),
            ),
          ),
        LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          backgroundColor: Colors.grey[200],
          color: _brand,
          minHeight: 4,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            context.t(
              'السؤال ${(_questionIndex + 1).clamp(1, _maxQuestions)} من $_maxQuestions',
              'Question ${(_questionIndex + 1).clamp(1, _maxQuestions)} of $_maxQuestions',
            ),
            style: TextStyle(color: Colors.grey[700], fontSize: 13),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length + (_isLoading ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= _messages.length) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        context.t('اللجنة تفكّر...', 'Committee is thinking...'),
                      ),
                    ],
                  ),
                );
              }
              final msg = _messages[index];
              return _MessageBubble(
                message: msg,
                onSpeak: msg.role == VivaMessageRole.committee
                    ? () {
                        final member = msg.memberId != null
                            ? VivaCommittee.byId(msg.memberId!)
                            : VivaCommittee.members.first;
                        _tts.speakCommitteeQuestion(
                          member: member,
                          question: msg.content,
                        );
                      }
                    : null,
              );
            },
          ),
        ),
        if (!_isLoading && _questionIndex >= _maxQuestions)
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: _generateReport,
              style: FilledButton.styleFrom(
                backgroundColor: _brand,
                minimumSize: const Size(double.infinity, 48),
              ),
              child: Text(
                context.t('عرض تقرير التحضير', 'View preparation report'),
              ),
            ),
          )
        else if (!_isLoading ||
            _messages.any((m) => m.role == VivaMessageRole.committee))
          _buildAnswerBar(),
      ],
    );
  }

  Widget _buildAnswerBar() {
    final listening = _stt.isListening;
    final transcribing = _stt.isTranscribing;
    final busy = listening || transcribing;
    final oral = _answerMode == VivaAnswerMode.oral;
    final showMic = _sttAvailable;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (oral)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _brand.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  context.t(
                    'وضع شفهي: اضغط الميكروفون وأجب بصوتك (يمكنك تصحيح النص قبل الإرسال).',
                    'Oral mode: tap the mic and answer aloud (you can edit the text before send).',
                  ),
                  style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                ),
              ),
            if (_sttAvailable)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 8,
                  children: [
                    _SttLanguageChip(
                      label: context.t('تلقائي', 'Auto'),
                      selected: _stt.language == VivaSttLanguage.auto,
                      onSelected: busy
                          ? null
                          : () => setState(
                                () => _stt.language = VivaSttLanguage.auto,
                              ),
                    ),
                    _SttLanguageChip(
                      label: context.t('عربي', 'Arabic'),
                      selected: _stt.language == VivaSttLanguage.arabic,
                      onSelected: busy
                          ? null
                          : () => setState(
                                () => _stt.language = VivaSttLanguage.arabic,
                              ),
                    ),
                    _SttLanguageChip(
                      label: context.t('English', 'English'),
                      selected: _stt.language == VivaSttLanguage.english,
                      onSelected: busy
                          ? null
                          : () => setState(
                                () => _stt.language = VivaSttLanguage.english,
                              ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                if (showMic)
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: listening
                          ? Colors.red
                          : (oral ? _brand : Colors.grey[200]),
                      foregroundColor:
                          listening || oral ? Colors.white : _brand,
                    ),
                    tooltip: listening
                        ? context.t('إيقاف التسجيل', 'Stop recording')
                        : context.t('إجابة شفهية', 'Speak your answer'),
                    onPressed: (_isLoading || transcribing)
                        ? null
                        : _toggleVoiceAnswer,
                    icon: Icon(listening ? Icons.mic : Icons.mic_none),
                  ),
                if (showMic) const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _answerController,
                    enabled: !_isLoading && !transcribing,
                    minLines: oral ? 2 : 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: transcribing
                          ? context.t(
                              'جاري تحويل الصوت...',
                              'Converting speech...',
                            )
                          : listening
                              ? context.t('تحدّث الآن...', 'Speak now...')
                              : oral
                                  ? context.t(
                                      'نص إجابتك الشفهية يظهر هنا…',
                                      'Your spoken answer appears here…',
                                    )
                                  : context.t(
                                      'اكتب إجابتك هنا…',
                                      'Type your answer here…',
                                    ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      suffixIcon: busy
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                    ),
                    onSubmitted: (_) => _submitAnswer(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: _brand,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: (_isLoading || transcribing) ? null : _submitAnswer,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReport() {
    final report = _report!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: _brand.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.assignment_turned_in, color: _brand),
                    const SizedBox(width: 8),
                    Text(
                      context.t(
                        'تقرير التحضير للمناقشة',
                        'Viva preparation report',
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  report.overallAssessment,
                  style: const TextStyle(height: 1.5),
                ),
                if (report.fromCloudAi) ...[
                  const SizedBox(height: 8),
                  Text(
                    context.t(
                      'عبر ${AdvisorBranding.cloudBadge}',
                      'via ${AdvisorBranding.cloudBadge}',
                    ),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _reportSection(
          context.t('نقاط الضعف', 'Weaknesses'),
          Icons.warning_amber_outlined,
          Colors.orange,
          report.weaknesses,
        ),
        _reportSection(
          context.t('فجوات منهجية', 'Methodology gaps'),
          Icons.rule_folder_outlined,
          Colors.teal,
          report.methodologyGaps,
        ),
        _reportSection(
          context.t('أسئلة متوقعة', 'Likely questions'),
          Icons.quiz_outlined,
          Colors.indigo,
          report.expectedQuestions,
        ),
        _reportSection(
          context.t('نصائح التحضير', 'Preparation tips'),
          Icons.tips_and_updates_outlined,
          Colors.green,
          report.preparationTips,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _phase = VivaPhase.session;
              _isLoading = false;
            });
          },
          icon: const Icon(Icons.replay),
          label: Text(context.t('مراجعة المحاكاة', 'Review simulation')),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _restart,
          style: FilledButton.styleFrom(
            backgroundColor: _brand,
            minimumSize: const Size(double.infinity, 48),
          ),
          icon: const Icon(Icons.refresh),
          label: Text(context.t('محاكاة جديدة', 'New simulation')),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _reportSection(
    String title,
    IconData icon,
    Color color,
    List<String> items,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: Text(item, style: const TextStyle(height: 1.45)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionsDrawer extends StatelessWidget {
  final Future<void> Function(VivaSavedSession) onOpen;
  final Future<void> Function(VivaSavedSession) onDelete;
  final bool canPersist;

  const _SessionsDrawer({
    required this.onOpen,
    required this.onDelete,
    required this.canPersist,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.t('جلسات المحاكاة', 'Simulation sessions'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (!canPersist)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  context.t(
                    'سجّل الدخول لحفظ الجلسات في السحابة. بدون دخول تُحفظ محلياً في الجلسة الحالية فقط.',
                    'Sign in to save sessions to the cloud. Without sign-in, only the current session is kept locally.',
                  ),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
            if (!canPersist)
              Padding(
                padding: const EdgeInsets.all(12),
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  },
                  child: Text(context.t('تسجيل الدخول', 'Sign in')),
                ),
              ),
            Expanded(
              child: StreamBuilder<List<VivaSavedSession>>(
                stream: VivaSessionStore.instance.watchSessions(),
                builder: (context, snapshot) {
                  final sessions = snapshot.data ?? [];
                  if (sessions.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          context.t(
                            'لا توجد جلسات محفوظة بعد',
                            'No saved sessions yet',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final phaseLabel = switch (session.phase) {
                        VivaPhase.setup => context.t('إعداد', 'Setup'),
                        VivaPhase.session => context.t('جارية', 'In progress'),
                        VivaPhase.report => context.t('تقرير', 'Report'),
                      };
                      return ListTile(
                        title: Text(
                          session.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text('$phaseLabel • ${session.messages.length}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => onDelete(session),
                        ),
                        onTap: () => onOpen(session),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final VivaMessage message;
  final VoidCallback? onSpeak;

  const _MessageBubble({required this.message, this.onSpeak});

  @override
  Widget build(BuildContext context) {
    if (message.role == VivaMessageRole.system) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            message.content,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[800]),
          ),
        ),
      );
    }

    final isStudent = message.role == VivaMessageRole.student;
    VivaCommitteeMember? member;
    if (!isStudent && message.memberId != null) {
      member = VivaCommittee.byId(message.memberId!);
    }

    return Align(
      alignment: isStudent ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.88,
        ),
        child: Column(
          crossAxisAlignment:
              isStudent ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            if (member != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(member.icon, size: 16, color: member.color),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${member.displayName} — ${member.displayRole}',
                        style: TextStyle(
                          fontSize: 11,
                          color: member.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (onSpeak != null) ...[
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: onSpeak,
                        child: Icon(
                          Icons.volume_up_outlined,
                          size: 16,
                          color: member.color,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isStudent ? const Color(0xFF880E4F) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border:
                    isStudent ? null : Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  color: isStudent ? Colors.white : Colors.black87,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SttLanguageChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onSelected;

  const _SttLanguageChip({
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
      selectedColor: const Color(0xFF880E4F).withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF880E4F) : Colors.grey[800],
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
