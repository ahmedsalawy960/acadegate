import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/assets/weekly_image_rotator.dart';
import '../../core/locale/locale_extensions.dart';
import '../../core/widgets/section_cover_image.dart';
import '../academic/faculty_categories.dart';
import '../academic/faculty_departments.dart';
import '../acadegate_publish/citation_style_picker.dart';
import '../acadegate_publish/publish_models.dart';
import '../academic_integrity/academic_integrity_hub_screen.dart';
import '../academic_integrity/citation_check_screen.dart';
import '../ai_advisor/gemini_advisor_client.dart';
import '../ai_advisor/grounded_work.dart';
import '../auth/usage_quota_banner.dart';
import '../profile/academic_profile.dart';
import '../profile/academic_profile_screen.dart';
import '../profile/academic_profile_service.dart';
import '../research_journey/thesis_progress.dart';
import '../research_journey/thesis_progress_activity.dart';
import '../research_supply_chain/research_goal.dart';
import '../guides/section_guide_catalog.dart';
import '../guides/section_guide_screen.dart';
import 'arabic_thesis_catalogs.dart';
import 'thesis_studio_ai_service.dart';
import 'thesis_studio_branding.dart';
import 'thesis_studio_citation_report.dart';
import 'thesis_studio_citations.dart';
import 'thesis_studio_docx_export.dart';
import 'thesis_studio_engine.dart';
import 'thesis_studio_file_share.dart';
import 'thesis_studio_command.dart';
import 'thesis_studio_discipline.dart';
import 'thesis_studio_kind.dart';
import 'thesis_studio_latex_export.dart';
import 'thesis_studio_length.dart';
import 'thesis_studio_models.dart';
import 'thesis_studio_pdf_service.dart';
import 'thesis_studio_storage.dart';

class ThesisStudioScreen extends StatefulWidget {
  final String? initialGoal;

  const ThesisStudioScreen({super.key, this.initialGoal});

  @override
  State<ThesisStudioScreen> createState() => _ThesisStudioScreenState();
}

class _ThesisStudioScreenState extends State<ThesisStudioScreen>
    with WidgetsBindingObserver {
  static const _brand = Color(ThesisStudioBranding.brand);

  final _goalController = TextEditingController();
  final _abstractCmd = TextEditingController();
  final _priorStudiesPaste = TextEditingController();
  final Map<String, TextEditingController> _paraCmds = {};
  ResearchDegreeTrack _track = ResearchDegreeTrack.masters;
  ThesisKind _kind = ThesisKind.experimental;
  ThesisShape _shape = ThesisShape.arabicEmpirical;
  bool _arabicDraft = true;
  String? _facultyId;
  String? _departmentId;
  PublishCitationStyle _style = PublishCitationStyle.apa;
  int _targetPages = ThesisLengthBudget.defaultPages;
  bool _loading = false;
  String _progress = '';
  ThesisDraft? _draft;
  AcademicProfile? _profile;
  String? _busyKey;
  bool _restoredDraft = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Only an explicit navigation argument may prefill — never profile/examples.
    final seed = widget.initialGoal?.trim() ?? '';
    if (seed.isNotEmpty) _goalController.text = seed;
    _bootstrap();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _persistDraft();
    }
  }

  Future<void> _bootstrap() async {
    await _loadProfile();
    await _restoreSavedDraft();
  }

  Future<void> _restoreSavedDraft() async {
    final snap = await ThesisStudioStorage.instance.load();
    if (!mounted || snap == null) return;
    // Explicit nav goal wins over saved goal text.
    final navGoal = widget.initialGoal?.trim() ?? '';
    setState(() {
      _draft = snap.draft;
      _restoredDraft = true;
      if (navGoal.isEmpty && snap.goalText.trim().isNotEmpty) {
        _goalController.text = snap.goalText;
      }
      _track = snap.track;
      _kind = snap.kind;
      _shape = snap.shape;
      _arabicDraft = snap.arabicDraft;
      _facultyId = snap.facultyId;
      _departmentId = snap.departmentId;
      _style = snap.citationStyle;
      _targetPages = snap.targetPages;
      if (snap.priorStudiesPaste.trim().isNotEmpty) {
        _priorStudiesPaste.text = snap.priorStudiesPaste;
      }
      for (final c in _paraCmds.values) {
        c.dispose();
      }
      _paraCmds.clear();
    });
  }

  Future<void> _persistDraft() async {
    final draft = _draft;
    if (draft == null) return;
    try {
      await ThesisStudioStorage.instance.save(
        ThesisStudioSnapshot(
          draft: draft,
          goalText: _goalController.text.trim().isNotEmpty
              ? _goalController.text.trim()
              : draft.goal.raw,
          track: _track,
          kind: _kind,
          shape: _shape,
          arabicDraft: _arabicDraft,
          facultyId: _facultyId,
          departmentId: _departmentId,
          citationStyle: _style,
          targetPages: _targetPages,
          priorStudiesPaste: _priorStudiesPaste.text,
          savedAt: DateTime.now(),
        ),
      );
      final goalLen = _goalController.text.trim().isNotEmpty
          ? _goalController.text.trim().length
          : draft.goal.raw.trim().length;
      if (draft.hasGeneratedProse ||
          draft.literature.works.isNotEmpty ||
          goalLen >= 24) {
        await ThesisProgressService.instance.recordActivity(
          ThesisActivityId.thesisStudio.name,
        );
      }
    } catch (e) {
      debugPrint('Thesis studio persist failed: $e');
    }
  }

  Future<void> _clearSavedDraft({required bool wipeUi}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('حذف مسودة الرسالة؟', 'Delete thesis draft?')),
        content: Text(
          ctx.t(
            'سيُحذف النص والمراجع المحفوظة لهذا الحساب على الجهاز والسحابة. لا يُحذف شيء تلقائياً عند الإغلاق أو تسجيل الخروج.',
            'This removes the saved text and references for this account on device and cloud. Nothing is deleted automatically on close or sign-out.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.t('حذف المسودة', 'Delete draft')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ThesisStudioStorage.instance.clear();
    if (!wipeUi || !mounted) return;
    setState(() {
      _draft = null;
      _restoredDraft = false;
      _abstractCmd.clear();
      _priorStudiesPaste.clear();
      for (final c in _paraCmds.values) {
        c.dispose();
      }
      _paraCmds.clear();
      _progress = '';
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t('تم حذف المسودة المحفوظة.', 'Saved draft deleted.'),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Best-effort save before leaving the screen.
    final draft = _draft;
    if (draft != null) {
      ThesisStudioStorage.instance.save(
        ThesisStudioSnapshot(
          draft: draft,
          goalText: _goalController.text.trim().isNotEmpty
              ? _goalController.text.trim()
              : draft.goal.raw,
          track: _track,
          kind: _kind,
          shape: _shape,
          arabicDraft: _arabicDraft,
          facultyId: _facultyId,
          departmentId: _departmentId,
          citationStyle: _style,
          targetPages: _targetPages,
          priorStudiesPaste: _priorStudiesPaste.text,
          savedAt: DateTime.now(),
        ),
      );
    }
    _goalController.dispose();
    _abstractCmd.dispose();
    _priorStudiesPaste.dispose();
    for (final controller in _paraCmds.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await AcademicProfileService.instance.loadProfile();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      // Goal field stays empty — never auto-fill from profile interest or examples.
      if (profile != null && profile.degree.trim().isNotEmpty) {
        final parsed = ResearchGoalParser.parse(
          profile.degree,
          profileDegree: profile.degree,
        );
        if (parsed.track != ResearchDegreeTrack.unspecified) {
          _track = parsed.track;
        }
      }
      final disc = ThesisDiscipline.resolve(profile: profile);
      if (disc.facultyId.isNotEmpty) _facultyId = disc.facultyId;
      if (disc.departmentId.isNotEmpty) _departmentId = disc.departmentId;
      final guess = ThesisKindDetector.detect(
        raw: _goalController.text.trim(),
        profile: profile,
      );
      _kind = guess.kind;
      _shape = guess.shape;
      _arabicDraft = guess.arabic;
    });
  }

  Future<void> _openProfile() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AcademicProfileScreen()),
    );
    if (saved == true) await _loadProfile();
  }

  /// Profile + on-screen faculty/department overrides for literature and prose.
  AcademicProfile? _profileForStudio() {
    final base = _profile;
    final faculty = _facultyId?.trim() ?? '';
    final dept = _selectedDepartment;
    final specialization = dept != null
        ? (dept.titleAr.isNotEmpty ? dept.titleAr : dept.titleEn)
        : (base?.specialization ?? '');
    if (base == null) {
      if (faculty.isEmpty && specialization.trim().isEmpty) return null;
      return AcademicProfile(
        fullName: '',
        university: '',
        degree: '',
        facultyCategory: faculty,
        specialization: specialization,
        researchInterest: _goalController.text.trim(),
        methodology: '',
        preferredLanguage: _arabicDraft ? 'العربية' : 'English',
        city: '',
      );
    }
    return base.copyWith(
      facultyCategory: faculty.isNotEmpty ? faculty : base.facultyCategory,
      specialization:
          specialization.trim().isNotEmpty ? specialization : base.specialization,
    );
  }

  FacultyDepartment? get _selectedDepartment {
    final faculty = _facultyId?.trim() ?? '';
    final deptId = _departmentId?.trim() ?? '';
    if (faculty.isEmpty || deptId.isEmpty) return null;
    return FacultyDepartments.byId(faculty, deptId);
  }

  ThesisDiscipline get _selectedDiscipline => ThesisDiscipline.resolve(
        facultyId: _facultyId,
        departmentId: _departmentId,
        profile: _profileForStudio(),
      );

  void _onFacultyChanged(String? id) {
    setState(() {
      _facultyId = id;
      final depts = id == null || id.isEmpty
          ? const <FacultyDepartment>[]
          : FacultyDepartments.forFaculty(id);
      if (_departmentId != null &&
          !depts.any((d) => d.id == _departmentId)) {
        _departmentId = null;
      }
      if ((_departmentId == null || _departmentId!.isEmpty) &&
          id != null &&
          id.isNotEmpty &&
          _profile != null) {
        _departmentId =
            FacultyDepartments.match(id, _profile!.specialization)?.id;
      }
      final guess = ThesisKindDetector.detect(
        raw: _goalController.text.trim().isEmpty
            ? ''
            : _goalController.text,
        profile: _profileForStudio(),
      );
      _kind = guess.kind;
      _shape = ThesisKindDetector.defaultShape(
        kind: _kind,
        arabic: _arabicDraft,
      );
    });
  }

  void _onDepartmentChanged(String? id) {
    setState(() => _departmentId = id);
  }

  Future<void> _generate() async {
    final raw = _goalController.text.trim();
    if (raw.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'اكتب هدف الرسالة: فقرة أو عدة جمل (التخصص والمشكلة والمنهج إن وُجد).',
              'Write the thesis goal as a paragraph or several sentences (field, problem, and method if you have them).',
            ),
          ),
        ),
      );
      return;
    }
    if (!_selectedDiscipline.isPresent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'اختر الكلية والقسم بالأعلى (أو أكمل الملف الأكاديمي) حتى تُجلب مراجع تخصصك فقط.',
              'Select faculty and department above (or complete your academic profile) so sources stay in your discipline.',
            ),
          ),
        ),
      );
      return;
    }

    final existing = _draft;
    if (existing != null && existing.hasGeneratedProse) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.t('إعادة بناء الهيكل؟', 'Rebuild the outline?')),
          content: Text(
            ctx.t(
              'سيُحذف النص الذي ولّدته في الفقرات. خيارات اللغة والشكل أسفل الهدف تبقى.',
              'Generated paragraph text will be deleted. Language and structure choices under the goal stay.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.t('إلغاء', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.t('متابعة', 'Continue')),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    setState(() {
      _loading = true;
      _progress = context.t('جارٍ بناء الهيكل الفارغ...', 'Building the empty outline...');
      _draft = null;
      _abstractCmd.clear();
      for (final controller in _paraCmds.values) {
        controller.clear();
      }
      _paraCmds.clear();
    });

    try {
      final draft = await ThesisStudioEngine.instance.buildSkeleton(
        rawGoal: raw,
        trackOverride: _track,
        kindOverride: _kind,
        shapeOverride: _shape,
        arabicDraft: _arabicDraft,
        citationStyle: _style,
        targetPages: _targetPages,
        profile: _profileForStudio(),
        facultyId: _facultyId,
        departmentId: _departmentId,
        onProgress: (label) {
          if (!mounted) return;
          setState(() => _progress = label);
        },
      );
      if (!mounted) return;
      setState(() => _draft = draft);
      await _persistDraft();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _progress = '';
        });
      }
    }
  }

  TextEditingController _paraCmd(ThesisParagraph paragraph) {
    return _paraCmds.putIfAbsent(
      paragraph.id,
      () => TextEditingController(text: paragraph.lastCommand),
    );
  }

  Future<void> _runBusy(
    String key,
    Future<ThesisDraft> Function() job,
  ) async {
    setState(() => _busyKey = key);
    try {
      final draft = await job();
      if (!mounted) return;
      setState(() => _draft = draft);
      await _persistDraft();
      final isWrite = key.startsWith('write:');
      final diagnostic =
          ThesisStudioAiService.instance.lastFillDiagnostic?.trim() ?? '';
      final progressLeft = _progress.trim();
      final snack = !isWrite
          ? ''
          : (diagnostic.isNotEmpty
              ? diagnostic
              : (progressLeft.isNotEmpty &&
                      _looksLikeWriteDiagnostic(progressLeft)
                  ? progressLeft
                  : ''));
      if (snack.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(snack),
            duration: const Duration(seconds: 14),
            backgroundColor: Colors.orange.shade900,
          ),
        );
      }
      if (isWrite) {
        ThesisStudioAiService.instance.lastFillDiagnostic = null;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyKey = null;
          _progress = '';
        });
      }
    }
  }

  bool _looksLikeWriteDiagnostic(String text) {
    final lower = text.toLowerCase();
    return text.contains('تعذّر') ||
        text.contains('توقفت') ||
        text.contains('اكتمل جزئياً') ||
        text.contains('الحد اليومي') ||
        text.contains('حصة') ||
        lower.contains('quota') ||
        lower.contains('failed') ||
        lower.contains('stopped') ||
        lower.contains('partial') ||
        lower.contains('daily');
  }

  Future<void> _importPriorStudyDois() {
    final pasted = _priorStudiesPaste.text.trim();
    if (pasted.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'الصق قائمة DOI أو روابط doi.org للمراجع المعتمدة في دراستك.',
              'Paste DOIs or doi.org links for the references your study relies on.',
            ),
          ),
        ),
      );
      return Future.value();
    }
    return _runBusy('prior:import', () {
      return ThesisStudioEngine.instance.importPriorStudyDois(
        draft: _draft!,
        pasted: pasted,
        onProgress: (label) {
          if (!mounted) return;
          setState(() => _progress = label);
        },
      );
    });
  }

  Future<void> _writePriorStudiesChapter() {
    final draft = _draft;
    if (draft == null) return Future.value();
    final hasWorks = draft.literature.works.isNotEmpty ||
        draft.chapters.any(
          (c) =>
              c.id == 'literature' &&
              c.paragraphs.any((p) => p.references.isNotEmpty),
        );
    if (!hasWorks) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'اجلب المراجع للفصل أولاً، أو الصق DOI خارجياً ثم استورد.',
              'Harvest chapter references first, or paste external DOIs and import.',
            ),
          ),
        ),
      );
      return Future.value();
    }
    return _runBusy('prior:write', () {
      return ThesisStudioEngine.instance.writePriorStudiesChapter(
        draft: draft,
        onProgress: (label) {
          if (!mounted) return;
          setState(() => _progress = label);
        },
      );
    });
  }

  Future<void> _writePriorStudyParagraph(
    ThesisChapter chapter,
    ThesisParagraph paragraph,
  ) {
    return _runBusy('write:${paragraph.id}', () {
      return ThesisStudioEngine.instance.writePriorStudyParagraph(
        draft: _draft!,
        chapterId: chapter.id,
        paragraphId: paragraph.id,
        onProgress: (label) {
          if (!mounted) return;
          setState(() => _progress = label);
        },
      );
    });
  }

  Future<void> _harvestParagraph(ThesisChapter chapter, ThesisParagraph paragraph) {
    final typed = _paraCmd(paragraph).text.trim();
    if (typed.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'اكتب أمر الفقرة أولاً (بما يخص هدف رسالتك)، ثم اجلب المراجع.',
              'Type the paragraph command first (about your thesis goal), then fetch sources.',
            ),
          ),
        ),
      );
      return Future.value();
    }
    return _runBusy('refs:${paragraph.id}', () async {
      final draft = await ThesisStudioEngine.instance.harvestParagraph(
        draft: _draft!,
        chapterId: chapter.id,
        paragraphId: paragraph.id,
        command: typed,
        onProgress: (label) {
          if (!mounted) return;
          setState(() => _progress = label);
        },
      );
      if (mounted) {
        ThesisParagraph? updated;
        for (final c in draft.chapters) {
          for (final p in c.paragraphs) {
            if (p.id == paragraph.id) updated = p;
          }
        }
        final n = updated?.references.length ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: n > 0 ? Colors.green.shade700 : Colors.orange.shade800,
            content: Text(
              n > 0
                  ? context.t(
                      'تم جلب $n مرجعاً مؤكداً بـ DOI لهذه الفقرة.',
                      'Fetched $n DOI-confirmed sources for this paragraph.',
                    )
                  : context.t(
                      'لم يُعثر على مراجع مناسبة. جرّب صياغة إنجليزية أدق للموضوع أو كلمات مفتاحية علمية.',
                      'No matching sources found. Try a clearer English topic or scholarly keywords.',
                    ),
            ),
          ),
        );
      }
      return draft;
    });
  }

  Future<void> _writeParagraph(ThesisChapter chapter, ThesisParagraph paragraph) {
    if (paragraph.id == 'lit_abstracts_all') {
      return _writePriorStudiesChapter();
    }
    if (paragraph.id.startsWith('lit_study_') &&
        paragraph.references.isNotEmpty) {
      return _writePriorStudyParagraph(chapter, paragraph);
    }
    final typed = _paraCmd(paragraph).text.trim();
    if (typed.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'اكتب أمر الفقرة أولاً داخل هدف رسالتك، ثم ولّد.',
              'Type the paragraph command inside your thesis goal first, then generate.',
            ),
          ),
        ),
      );
      return Future.value();
    }
    return _runBusy('write:${paragraph.id}', () {
      return ThesisStudioEngine.instance.writeParagraph(
        draft: _draft!,
        chapterId: chapter.id,
        paragraphId: paragraph.id,
        command: typed,
        profile: _profile,
        onProgress: (label) {
          if (!mounted) return;
          setState(() => _progress = label);
        },
        onPartial: (draft) {
          if (!mounted) return;
          setState(() => _draft = draft);
        },
      );
    });
  }

  Future<void> _harvestAbstract() {
    final typed = _abstractCmd.text.trim();
    if (typed.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'اكتب أمر الملخص أولاً، ثم اجلب المراجع.',
              'Type the abstract command first, then fetch sources.',
            ),
          ),
        ),
      );
      return Future.value();
    }
    return _runBusy('refs:abstract', () {
      return ThesisStudioEngine.instance.harvestAbstract(
        draft: _draft!,
        command: typed,
        onProgress: (label) {
          if (!mounted) return;
          setState(() => _progress = label);
        },
      );
    });
  }

  Future<void> _writeAbstract() {
    final typed = _abstractCmd.text.trim();
    if (typed.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'اكتب أمر الملخص أولاً، ثم ولّد.',
              'Type the abstract command first, then generate.',
            ),
          ),
        ),
      );
      return Future.value();
    }
    return _runBusy('write:abstract', () {
      return ThesisStudioEngine.instance.writeAbstract(
        draft: _draft!,
        command: typed,
        profile: _profile,
        onProgress: (label) {
          if (!mounted) return;
          setState(() => _progress = label);
        },
      );
    });
  }

  void _addParagraph(ThesisChapter chapter) {
    final draft = _draft;
    if (draft == null) return;
    final n = chapter.paragraphs.length + 1;
    final extra = ThesisParagraph(
      id: '${chapter.id}_extra$n',
      headingAr: 'فقرة إضافية $n',
      headingEn: 'Extra paragraph $n',
    );
    final next = [...chapter.paragraphs, extra];
    setState(() {
      _draft = draft.replacingChapter(
        chapter.copyWith(
          paragraphs: next,
          body: ThesisChapter.assembleBody(next, draft.arabic),
        ),
      );
    });
  }

  Future<void> _copyAll() async {
    final draft = _draft;
    if (draft == null) return;
    final arabic = draft.arabic;
    final buffer = StringBuffer()
      ..writeln(draft.proposedTitle)
      ..writeln()
      ..writeln(ThesisStudioCitations.styledProse(draft.abstractText, draft))
      ..writeln();
    for (final q in draft.researchQuestions) {
      buffer.writeln('• $q');
    }
    buffer.writeln();
    for (final ch in draft.chapters) {
      buffer.writeln(ch.title(arabic));
      buffer.writeln(ThesisStudioCitations.styledProse(ch.body, draft));
      buffer.writeln();
    }
    if (draft.literature.works.isNotEmpty) {
      buffer.writeln(context.t('المراجع', 'References'));
      buffer.writeln(
        ThesisStudioCitations.bibliography(
          draft.literature.works,
          style: draft.plan.citationStyle,
        ),
      );
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.t('تم نسخ المسودة', 'Draft copied')),
      ),
    );
  }

  Future<void> _exportOrPrint() async {
    final draft = _draft;
    if (draft == null) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.print_outlined),
              title: Text(ctx.t('طباعة', 'Print')),
              onTap: () => Navigator.pop(ctx, 'print'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: Text(ctx.t('حفظ / مشاركة PDF', 'Save / share PDF')),
              onTap: () => Navigator.pop(ctx, 'share'),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(ctx.t('Word (.docx)', 'Word (.docx)')),
              onTap: () => Navigator.pop(ctx, 'docx'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_zip_outlined),
              title: Text(ctx.t('Overleaf: LaTeX + BibTeX', 'Overleaf: LaTeX + BibTeX')),
              onTap: () => Navigator.pop(ctx, 'zip'),
            ),
            ListTile(
              leading: const Icon(Icons.data_object_outlined),
              title: Text(ctx.t('BibTeX فقط', 'BibTeX only')),
              onTap: () => Navigator.pop(ctx, 'bib'),
            ),
            ListTile(
              leading: const Icon(Icons.verified_outlined),
              title: Text(ctx.t('تقرير الاستشهادات', 'Citation report')),
              onTap: () => Navigator.pop(ctx, 'report'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: Text(ctx.t('نسخ النص', 'Copy text')),
              onTap: () => Navigator.pop(ctx, 'copy'),
            ),
          ],
        ),
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'copy') {
      await _copyAll();
      return;
    }
    if (action == 'report') {
      await Clipboard.setData(
        ClipboardData(
          text: ThesisCitationReport.fromDraft(draft).asText(arabic: draft.arabic),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t('تم نسخ تقرير الاستشهادات', 'Citation report copied'),
          ),
        ),
      );
      return;
    }
    try {
      if (action == 'print') {
        await ThesisStudioPdfService.instance.printDraft(
          draft,
          profile: _profile,
        );
      } else if (action == 'docx') {
        await ThesisStudioDocxExport.instance.share(draft, profile: _profile);
      } else if (action == 'zip') {
        await shareThesisFile(
          bytes: ThesisStudioLatexExport.instance.overleafZip(
            draft,
            profile: _profile,
          ),
          name: 'acadegate_thesis_overleaf.zip',
        );
      } else if (action == 'bib') {
        await shareThesisFile(
          bytes: Uint8List.fromList(
            utf8.encode(ThesisStudioLatexExport.instance.bibtex(draft)),
          ),
          name: 'references.bib',
        );
      } else {
        await ThesisStudioPdfService.instance.shareDraft(
          draft,
          profile: _profile,
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'تعذّر التصدير: $error',
              'Could not export: $error',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _openDoi(String doi) async {
    final uri = Uri.parse('https://doi.org/$doi');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openExternalUri(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _exportExcerpt({
    required String format,
    required String heading,
    required String body,
    required List<GroundedWork> works,
  }) async {
    final draft = _draft;
    if (draft == null || body.trim().isEmpty) return;
    try {
      if (format == 'docx') {
        await ThesisStudioDocxExport.instance.shareExcerpt(
          draft: draft,
          heading: heading,
          body: body,
          works: works,
        );
      } else {
        await ThesisStudioPdfService.instance.shareExcerpt(
          draft: draft,
          heading: heading,
          body: body,
          works: works,
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'تعذّر التصدير: $error',
              'Could not export: $error',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(ThesisStudioBranding.title),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        actions: [
          const SectionGuideAppBarButton(
            guideId: SectionGuideCatalog.thesisStudio,
            accent: _brand,
          ),
          if (_draft != null)
            IconButton(
              tooltip: context.t('تصدير المسودة', 'Export draft'),
              onPressed: _exportOrPrint,
              icon: const Icon(Icons.picture_as_pdf_outlined),
            ),
          IconButton(
            tooltip: context.t('الملف الأكاديمي', 'Academic profile'),
            onPressed: _openProfile,
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionGuideBanner(
            guideId: SectionGuideCatalog.thesisStudio,
            accent: _brand,
          ),
          const UsageQuotaBanner(
            showGemini: true,
            showScholar: true,
            padding: EdgeInsets.only(bottom: 12),
          ),
          _hero(),
          const SizedBox(height: 16),
          TextField(
            controller: _goalController,
            minLines: 4,
            maxLines: 12,
            enabled: !_loading,
            decoration: InputDecoration(
              labelText: context.t(
                'اكتب هدف رسالتك (جملة أو عدة جمل)',
                'Write your thesis goal (one sentence or several)',
              ),
              helperText: context.t(
                'الحقل فارغ عمداً. اكتب هدفك بنفسك فقط.',
                'This field stays empty on purpose. Write your own goal only.',
              ),
              helperMaxLines: 2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              alignLabelWithHint: true,
              prefixIcon: const Icon(Icons.edit_note, color: const Color(0xFF93C5FD)),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _trackChip(
                ResearchDegreeTrack.masters,
                context.t('ماجستير', "Master's"),
              ),
              _trackChip(
                ResearchDegreeTrack.phd,
                context.t('دكتوراه', 'PhD'),
              ),
              _trackChip(
                ResearchDegreeTrack.diploma,
                context.t('دبلوم', 'Diploma'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _disciplineSelectors(),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _kindChip(
                ThesisKind.literary,
                context.t('أدبي / إنساني', 'Literary / humanities'),
              ),
              _kindChip(
                ThesisKind.experimental,
                context.t('معملي / تجريبي', 'Lab / experimental'),
              ),
              _kindChip(
                ThesisKind.empirical,
                context.t('ميداني / إحصائي', 'Field / statistical'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final shape in ThesisKindDetector.shapesFor(_kind))
                _shapeChip(shape),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text(context.t('مسودة بالعربية', 'Arabic draft')),
                selected: _arabicDraft,
                onSelected: _loading ? null : (_) => setState(() {
                  _arabicDraft = true;
                  _shape = ThesisKindDetector.defaultShape(
                    kind: _kind,
                    arabic: true,
                  );
                }),
                selectedColor: _brand.withValues(alpha: 0.18),
              ),
              ChoiceChip(
                label: Text(context.t('مسودة بالإنجليزية', 'English draft')),
                selected: !_arabicDraft,
                onSelected: _loading ? null : (_) => setState(() {
                  _arabicDraft = false;
                  _shape = ThesisKindDetector.defaultShape(
                    kind: _kind,
                    arabic: false,
                  );
                }),
                selectedColor: _brand.withValues(alpha: 0.18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CitationStylePicker(
            value: _style,
            enabled: !_loading,
            onChanged: (style) {
              setState(() {
                _style = style;
                if (_draft != null) {
                  _draft = _draft!.copyWith(
                    plan: _draft!.plan.copyWith(citationStyle: style),
                  );
                }
              });
              _persistDraft();
            },
          ),
          const SizedBox(height: 6),
          Text(
            context.t(
              'APA/Harvard/Chicago: يظهر داخل النص (مؤلف، سنة) من القائمة المؤكدة. IEEE/Vancouver: [n]. النموذج يكتب [n] حتى لا يختلق أسماء. أوامر عربية تُترجم تلقائياً إلى استعلامات إنجليزية للفهارس العلمية.',
              'APA/Harvard/Chicago: in-text shows (Author, Year) from the confirmed list. IEEE/Vancouver: [n]. The model writes [n] so it cannot invent names. Arabic commands are auto-translated into English scholarly search queries.',
            ),
            style: TextStyle(fontSize: 12, color: const Color(0xFFB7C3D6), height: 1.35),
          ),
          const SizedBox(height: 8),
          Text(
            context.t(
              'حجم المسودة: $_targetPages صفحة (≈ ${ThesisLengthBudget.totalWords(_targetPages)} كلمة). الافتراضي 40، والحد 80. المقدمة والأدبيات تتوسعان؛ النتائج تبقى جداول فارغة.',
              'Draft length: $_targetPages pages (≈ ${ThesisLengthBudget.totalWords(_targetPages)} words). Default 40, max 80. Introduction and literature expand; results stay empty tables.',
            ),
            style: TextStyle(fontSize: 12, color: const Color(0xFFB7C3D6), height: 1.4),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final n in const [24, 40, 56, 80])
                ChoiceChip(
                  label: Text(context.t('$n صفحة', '$n pp.')),
                  selected: _targetPages == n,
                  onSelected: _loading
                      ? null
                      : (_) => setState(() => _targetPages = n),
                  selectedColor: _brand.withValues(alpha: 0.18),
                ),
            ],
          ),
          Slider(
            value: _targetPages.toDouble(),
            min: ThesisLengthBudget.minPages.toDouble(),
            max: ThesisLengthBudget.maxPages.toDouble(),
            divisions: ThesisLengthBudget.maxPages - ThesisLengthBudget.minPages,
            label: '$_targetPages',
            activeColor: _brand,
            onChanged: _loading
                ? null
                : (v) => setState(() => _targetPages = v.round()),
          ),
          const SizedBox(height: 4),
          _workflowStrip(),
          const SizedBox(height: 12),
          if (!GeminiAdvisorClient.isAvailable)
            _banner(
              context.t(
                'سجّل الدخول لربط استوديو الرسالة بـ Gemini 2.5 Pro: يقرأ هدفك كاملاً، يضع العنوان بلغة المسودة، ويصفّي المقالات والرسائل الجامعية من الفهارس العالمية حسب أمر كل فقرة.',
                'Sign in to connect Thesis Studio to Gemini 2.5 Pro: it reads your full goal, writes the title in the draft language, and filters papers and dissertations from global indexes for each paragraph command.',
              ),
              color: Colors.orange.shade50,
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _loading ? null : _generate,
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.view_agenda_outlined),
              label: Text(
                _loading
                    ? (_progress.isEmpty
                        ? context.t('جارٍ البناء...', 'Building...')
                        : _progress)
                    : ThesisStudioBranding.buildButton,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          if (_draft != null) ...[
            const SizedBox(height: 8),
            Text(
              context.t(
                _restoredDraft
                    ? 'المسودة محفوظة لهذا الحساب (جهاز + سحابة) وتُستعاد عند العودة.'
                    : 'تُحفظ المسودة تلقائياً لهذا الحساب على الجهاز والسحابة.',
                _restoredDraft
                    ? 'Draft is saved for this account (device + cloud) and restored when you return.'
                    : 'The draft is auto-saved for this account on device and cloud.',
              ),
              style: TextStyle(fontSize: 12, color: const Color(0xFFB7C3D6), height: 1.35),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: _loading || _busyKey != null
                    ? null
                    : () => _clearSavedDraft(wipeUi: true),
                icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
                label: Text(
                  context.t('حذف المسودة المحفوظة', 'Delete saved draft'),
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            ),
          ],
          if (_loading && _progress.isNotEmpty) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              color: const Color(0xFF93C5FD),
              backgroundColor: const Color(0xFF1E3A5F),
            ),
            const SizedBox(height: 6),
            Text(
              _progress,
              style: TextStyle(color: const Color(0xFFB7C3D6), fontSize: 13),
            ),
          ],
          if (_draft != null) ...[
            const SizedBox(height: 20),
            _banner(ThesisStudioBranding.integrityBanner),
            const SizedBox(height: 12),
            _titleCard(_draft!),
            const SizedBox(height: 12),
            _questionsCard(_draft!),
            const SizedBox(height: 12),
            _literatureMapCard(_draft!),
            const SizedBox(height: 12),
            _citationReportCard(_draft!),
            const SizedBox(height: 12),
            _integrityActions(_draft!),
            const SizedBox(height: 12),
            Text(
              context.t('فقرات المسودة', 'Draft paragraphs'),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: const Color(0xFFFDE68A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.t(
                'كل فقرة فارغة حتى تكتب أمرها بالأسفل. اجلب المراجع الخاصة بذلك الأمر ثم ولّد الفقرة وحدها.',
                'Each paragraph stays empty until you type a command beneath it. Fetch sources for that command, then generate only that paragraph.',
              ),
              style: TextStyle(fontSize: 12, color: const Color(0xFFB7C3D6), height: 1.4),
            ),
            const SizedBox(height: 8),
            for (final ch in _draft!.chapters) _chapterTile(ch, _draft!.arabic),
            if (_draft!.note != null && _draft!.note!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              _banner(_draft!.note!),
            ],
          ],
        ],
      ),
    );
  }

  Widget _hero() {
    final cover = AcadeGateWeeklyImages.feature('feat_thesis');
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 148,
            child: SectionCoverImage(
              cover,
              errorBuilder: (_, _, _) => Container(color: const Color(0xFF93C5FD)),
            ),
          ),
          Container(
            width: double.infinity,
            color: _brand,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ThesisStudioBranding.tagline,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  ThesisStudioBranding.description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _disciplineSelectors() {
    final departments = (_facultyId == null || _facultyId!.isEmpty)
        ? const <FacultyDepartment>[]
        : FacultyDepartments.forFaculty(_facultyId!);
    final disc = _selectedDiscipline;
    final fromProfile = _profile?.resolvedFacultyCategory != null ||
        (_profile?.specialization.trim().isNotEmpty ?? false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.t(
            'الكلية والقسم (يقيّدان جلب المراجع والكتابة بتخصصك)',
            'Faculty and department (constrain sources and writing to your discipline)',
          ),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFFFDE68A),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.t(
            fromProfile
                ? 'يُملآن من ملفك الأكاديمي ويمكنك تعديلهما هنا. بدون ذلك قد تُجلب مراجع عن نفس الموضوع من تخصص آخر.'
                : 'اختر كليتك وقسمك، أو افتح الملف الأكاديمي بالأعلى. البحث والكتابة يبقيان داخل هذا التخصص فقط.',
            fromProfile
                ? 'Filled from your academic profile — you can override here. Without this, sources may match the topic from another faculty.'
                : 'Choose your faculty and department, or open the academic profile above. Search and writing stay inside this discipline only.',
          ),
          style: TextStyle(
            fontSize: 12,
            color: const Color(0xFFB7C3D6),
            height: 1.35,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey('faculty-${_facultyId ?? 'none'}'),
          initialValue: _facultyId != null &&
                  facultyCategories.any((f) => f.id == _facultyId)
              ? _facultyId
              : null,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: context.t('الكلية', 'Faculty / college'),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            prefixIcon: const Icon(Icons.account_balance, color: const Color(0xFF93C5FD)),
          ),
          items: [
            for (final faculty in facultyCategories)
              DropdownMenuItem(
                value: faculty.id,
                child: Text(
                  context.t(
                    faculty.titleAr,
                    FacultyDepartments.facultyTitleEn(faculty.id),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: _loading ? null : _onFacultyChanged,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey('dept-${_facultyId ?? 'none'}'),
          initialValue: _departmentId != null &&
                  departments.any((d) => d.id == _departmentId)
              ? _departmentId
              : null,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: context.t('القسم / التخصص', 'Department / specialization'),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            prefixIcon: const Icon(Icons.school_outlined, color: const Color(0xFF93C5FD)),
            helperText: departments.isEmpty
                ? context.t(
                    'اختر الكلية أولاً لعرض أقسامها',
                    'Select a faculty first to list its departments',
                  )
                : null,
          ),
          items: [
            for (final dept in departments)
              DropdownMenuItem(
                value: dept.id,
                child: Text(
                  context.t(dept.titleAr, dept.titleEn),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: _loading || departments.isEmpty
              ? null
              : _onDepartmentChanged,
        ),
        if (disc.isPresent) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _brand.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _brand.withValues(alpha: 0.18)),
            ),
            child: Text(
              context.t(
                'نطاق البحث: ${disc.facultyAr}'
                '${disc.labelAr.isNotEmpty ? ' · ${disc.labelAr}' : ''}',
                'Search scope: ${disc.facultyEn}'
                '${disc.labelEn.isNotEmpty ? ' · ${disc.labelEn}' : ''}',
              ),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFFFDE68A),
                height: 1.35,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _trackChip(ResearchDegreeTrack track, String label) {
    final selected = _track == track;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: _loading ? null : (_) => setState(() => _track = track),
      selectedColor: _brand.withValues(alpha: 0.18),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFFFDE68A) : const Color(0xFFF4F7FB),
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }

  Widget _kindChip(ThesisKind kind, String label) {
    final selected = _kind == kind;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: _loading
          ? null
          : (_) => setState(() {
                _kind = kind;
                _shape = ThesisKindDetector.defaultShape(
                  kind: kind,
                  arabic: _arabicDraft,
                );
              }),
      selectedColor: _brand.withValues(alpha: 0.18),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFFFDE68A) : const Color(0xFFF4F7FB),
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }

  Widget _shapeChip(ThesisShape shape) {
    final selected = _shape == shape;
    final plan = ThesisPlan(
      goal: ResearchGoalParser.parse(_goalController.text.trim().isEmpty
          ? 'topic'
          : _goalController.text),
      kind: _kind,
      shape: shape,
      arabic: _arabicDraft,
    );
    return ChoiceChip(
      label: Text(plan.shapeLabel, maxLines: 2, overflow: TextOverflow.ellipsis),
      selected: selected,
      onSelected: _loading
          ? null
          : (_) => setState(() {
                _shape = shape;
                _arabicDraft = shape.isArabicSpine;
              }),
      selectedColor: _brand.withValues(alpha: 0.18),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFFFDE68A) : const Color(0xFFF4F7FB),
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
    );
  }

  Widget _workflowStrip() {
    final steps = [
      context.t('1. هيكل فارغ', '1. Empty outline'),
      context.t('2. أمر الفقرة', '2. Paragraph command'),
      context.t('3. جلب المراجع', '3. Fetch sources'),
      context.t('4. توليد الفقرة', '4. Generate paragraph'),
      context.t('5. نزاهة', '5. Integrity'),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final step in steps)
          Chip(
            visualDensity: VisualDensity.compact,
            label: Text(step, style: const TextStyle(fontSize: 11)),
            backgroundColor: _brand.withValues(alpha: 0.08),
            side: BorderSide.none,
          ),
      ],
    );
  }

  Widget _banner(String text, {Color? color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color ?? const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          height: 1.4,
          fontSize: 13,
          color: Color(0xFF3E2723),
        ),
      ),
    );
  }

  Widget _titleCard(ThesisDraft draft) {
    return Card(
      elevation: 0,
      color: const Color(0xFF12284F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('العنوان المقترح', 'Proposed title'),
              style: const TextStyle(
                color: const Color(0xFFFDE68A),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              draft.proposedTitle,
              textDirection:
                  draft.arabic ? TextDirection.rtl : TextDirection.ltr,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              [
                draft.goal.degreeLabelFor(draft.arabic),
                draft.plan.kindLabel,
                draft.plan.shapeLabel,
                if (draft.plan.discipline.isPresent)
                  draft.arabic
                      ? '${draft.plan.discipline.facultyAr}'
                          '${draft.plan.discipline.labelAr.isNotEmpty ? ' / ${draft.plan.discipline.labelAr}' : ''}'
                      : '${draft.plan.discipline.facultyEn}'
                          '${draft.plan.discipline.labelEn.isNotEmpty ? ' / ${draft.plan.discipline.labelEn}' : ''}',
                '${draft.literature.works.length} '
                    '${context.t('دراسة/رسالة DOI مؤكدة', 'DOI-confirmed papers/theses')}',
                if (draft.modelUsed != null &&
                    draft.modelUsed!.trim().isNotEmpty)
                  draft.modelUsed!
                else if (draft.fromGemini)
                  'AI',
              ].join(' · '),
              style: TextStyle(color: const Color(0xFFB7C3D6), fontSize: 12),
            ),
            const SizedBox(height: 12),
            Text(
              context.t('الملخص', 'Abstract'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            if (draft.abstractText.trim().isEmpty)
              Text(
                context.t(
                  'فقرة الملخص فارغة. اكتب أمر الملخص بالأسفل ثم اجلب مراجعه أو ولّده.',
                  'The abstract is empty. Type a command below, then fetch its sources or generate it.',
                ),
                style: TextStyle(
                  color: const Color(0xFFB7C3D6),
                  height: 1.45,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              Text(
                ThesisStudioCitations.styledProse(
                  draft.abstractText,
                  draft,
                  works: draft.abstractReferences.isNotEmpty
                      ? draft.abstractReferences
                      : null,
                ),
                textDirection:
                    draft.arabic ? TextDirection.rtl : TextDirection.ltr,
                style: const TextStyle(height: 1.45),
              ),
            const SizedBox(height: 10),
            _commandTools(
              controller: _abstractCmd,
              hint: '',
              writeKey: 'write:abstract',
              refsKey: 'refs:abstract',
              onWrite: _writeAbstract,
              onRefs: _harvestAbstract,
              references: draft.abstractReferences,
              canExport: draft.abstractText.trim().isNotEmpty,
              onExportPdf: () => _exportExcerpt(
                format: 'pdf',
                heading: context.t('الملخص', 'Abstract'),
                body: draft.abstractText,
                works: draft.abstractReferences,
              ),
              onExportDocx: () => _exportExcerpt(
                format: 'docx',
                heading: context.t('الملخص', 'Abstract'),
                body: draft.abstractText,
                works: draft.abstractReferences,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _questionsCard(ThesisDraft draft) {
    if (draft.researchQuestions.isEmpty) return const SizedBox.shrink();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('أسئلة البحث', 'Research questions'),
              style: const TextStyle(
                color: const Color(0xFFFDE68A),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            for (final q in draft.researchQuestions)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(
                      child: Text(
                        q,
                        textDirection: draft.arabic
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                        style: const TextStyle(height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _literatureMapCard(ThesisDraft draft) {
    final rows = draft.literatureMap;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t(
                'خريطة الأدبيات (DOI مؤكد فقط)',
                'Literature map (DOI-confirmed only)',
              ),
              style: const TextStyle(
                color: const Color(0xFFFDE68A),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.t(
                'جلب تلقائي من OpenAlex وSemantic Scholar وCrossref (مع فلتر Arabic في OpenAlex للمسودات العربية). مواقع مثل مبتعث مفيدة للتصفح اليدوي ثم لصق DOI إن وُجد — لا نملك واجهة برمجية لسحب PDF منها.',
                'Auto-fetch from OpenAlex, Semantic Scholar, and Crossref (plus OpenAlex Arabic language filter for Arabic drafts). Sites like Mobt3ath help manual browsing, then paste a DOI if available — we have no API to pull their PDFs.',
              ),
              style: TextStyle(fontSize: 12, color: const Color(0xFFB7C3D6)),
            ),
            const SizedBox(height: 8),
            _arabicCatalogLinks(),
            const SizedBox(height: 8),
            if (draft.literature.works.isEmpty)
              Text(
                context.t(
                  'لا توجد دراسات DOI بعد. اكتب أمر الفقرة الفارغة ثم اضغط «جلب المراجع».',
                  'No DOI studies yet. Type a command under an empty paragraph, then tap “Fetch sources”.',
                ),
              )
            else
              for (final row in rows)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: _brand.withValues(alpha: 0.12),
                    child: Text(
                      '${row.index}',
                      style: const TextStyle(
                        color: const Color(0xFFFDE68A),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  title: Text(
                    row.work.title,
                    style: const TextStyle(fontSize: 13, height: 1.3),
                  ),
                  subtitle: Text(
                    ThesisStudioCitations.bibliographyLine(
                      row.work,
                      index: row.index,
                      style: draft.plan.citationStyle,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: IconButton(
                    tooltip: 'DOI',
                    icon: const Icon(Icons.open_in_new, size: 18),
                    onPressed: () => _openDoi(row.work.doi),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _citationReportCard(ThesisDraft draft) {
    final report = ThesisCitationReport.fromDraft(draft);
    return Card(
      elevation: 0,
      color: const Color(0xFF12284F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t(
                'تقرير تحقق الاستشهادات',
                'Citation verification report',
              ),
              style: const TextStyle(
                color: const Color(0xFFFDE68A),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.t(
                'دراسات ${report.sourceCount} · مستخدمة ${report.usedIndexes.length} · تغطية الجمل ${(report.citationCoverage * 100).toStringAsFixed(0)}%',
                '${report.sourceCount} studies · ${report.usedIndexes.length} used · ${(report.citationCoverage * 100).toStringAsFixed(0)}% sentence coverage',
              ),
              style: const TextStyle(height: 1.4, fontSize: 13),
            ),
            if (report.unknownMarkers.isNotEmpty)
              Text(
                context.t(
                  'علامات غير مؤكدة: ${report.unknownMarkers.join(', ')}',
                  'Unknown markers: ${report.unknownMarkers.join(', ')}',
                ),
                style: TextStyle(color: Colors.red.shade800, fontSize: 12),
              ),
            const SizedBox(height: 4),
            Text(
              context.t(
                'المطابقة على قائمة المراجع المجلوبة (DOI إن وُجد، أو عنوان/مؤلف/سنة من الفهارس الحرة) — لا قراءة كاملة لكل PDF.',
                'Matching is to the harvested list (DOI when present, otherwise title/author/year from free indexes) — we do not read every PDF.',
              ),
              style: TextStyle(fontSize: 11, color: const Color(0xFFB7C3D6), height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  Widget _integrityActions(ThesisDraft draft) {
    final bib = ThesisStudioCitations.bibliography(
      draft.literature.works,
      style: draft.plan.citationStyle,
    );
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CitationCheckScreen(
                    initialBibliography: bib,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.menu_book_outlined),
            label: Text(context.t('فحص المراجع', 'Check citations')),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AcademicIntegrityHubScreen(),
                ),
              );
            },
            icon: const Icon(Icons.verified_user_outlined),
            label: Text(context.t('النزاهة', 'Integrity')),
          ),
        ),
      ],
    );
  }

  Widget _chapterTile(ThesisChapter chapter, bool arabic) {
    final dir = arabic ? TextDirection.rtl : TextDirection.ltr;
    final filled = chapter.paragraphs.where((p) => !p.isEmpty).length;
    return Directionality(
      textDirection: dir,
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ExpansionTile(
          initiallyExpanded: _draft?.chapters.first.id == chapter.id,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          title: Text(
            chapter.title(arabic),
            textDirection: dir,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          subtitle: Text(
            context.t(
              '$filled من ${chapter.paragraphs.length} فقرة · ${chapter.purpose(arabic)}',
              '$filled of ${chapter.paragraphs.length} paragraphs · ${chapter.purpose(arabic)}',
            ),
            textDirection: dir,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          children: [
            if (chapter.id == 'literature') ...[
              _priorStudiesImportCard(arabic),
              const SizedBox(height: 12),
            ],
            for (final paragraph in chapter.paragraphs) ...[
              _paragraphCard(chapter, paragraph, arabic),
              const SizedBox(height: 10),
            ],
            if (chapter.id == 'literature') ...[
              _priorStudiesChapterExportBar(chapter, arabic),
              const SizedBox(height: 8),
            ],
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: _loading || _busyKey != null
                    ? null
                    : () => _addParagraph(chapter),
                icon: const Icon(Icons.add),
                label: Text(
                  context.t('إضافة فقرة فارغة', 'Add empty paragraph'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priorStudiesChapterExportBar(ThesisChapter chapter, bool arabic) {
    final studies = chapter.paragraphs
        .where(
          (p) =>
              p.body.trim().isNotEmpty &&
              (p.id.startsWith('lit_study_') || p.id == 'lit_abstracts_all'),
        )
        .toList();
    if (studies.isEmpty) return const SizedBox.shrink();
    return Directionality(
      textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF12284F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _brand.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.t(
                'تصدير فصل الدراسات السابقة كاملاً (${studies.length} دراسة)',
                'Export the full prior-studies chapter (${studies.length} studies)',
              ),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: const Color(0xFFFDE68A),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.t(
                'ملف Word واحد يجمع كل الفقرات بالترتيب، مع قائمة المراجع في النهاية.',
                'One Word file with every study paragraph in order, plus references at the end.',
              ),
              style: TextStyle(fontSize: 12, color: const Color(0xFFB7C3D6)),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _loading || _busyKey != null
                  ? null
                  : _exportPriorStudiesChapterDocx,
              icon: const Icon(Icons.description_outlined),
              label: Text(
                context.t(
                  'توليد Word لكل الدراسات السابقة',
                  'Generate Word for all prior studies',
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPriorStudiesChapterDocx() async {
    final draft = _draft;
    if (draft == null) return;
    try {
      await ThesisStudioDocxExport.instance.sharePriorStudiesChapter(draft);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'تعذّر تصدير الدراسات السابقة: $error',
              'Could not export prior studies: $error',
            ),
          ),
        ),
      );
    }
  }

  Widget _priorStudiesImportCard(bool arabic) {
    final dir = arabic ? TextDirection.rtl : TextDirection.ltr;
    final works = _draft?.literature.works.length ?? 0;
    final withAbs = _draft?.literature.works
            .where((w) => w.abstractText.trim().isNotEmpty)
            .length ??
        0;
    final busyImport = _busyKey == 'prior:import';
    final busyWrite = _busyKey == 'prior:write';
    return Directionality(
      textDirection: dir,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF12284F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFDE68A).withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.t(
                'فصل الدراسات السابقة (شكل الرسائل)',
                'Prior studies chapter (thesis form)',
              ),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: const Color(0xFFFDE68A),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.t(
                '1) «تلخيص Abstracts» يأخذ مراجع فصل المقدمة (+ الأدبيات)، يجلب Abstract لكل بحث، ويكتب فقرة لكل دراسة بالشكل: Author et al. (Year). ثم المنهج والنتائج من الملخص.\n'
                '2) الطول غير محدود بصفحة واحدة — يمكن أن يتجاوز 30 صفحة إذا كثرت الدراسات.\n'
                '3) «إضافة DOI خارجي» يضيف مراجع دون حذف الفقرات المكتوبة؛ أعد التلخيص بعدها.',
                '1) “Summarise abstracts” takes introduction (+ literature) references, fetches each Abstract, and writes one paragraph per study: Author et al. (Year). then methods/findings from the abstract.\n'
                '2) Length is not capped at one page — it may exceed 30 pages when many studies are included.\n'
                '3) “Add external DOIs” adds works without deleting written paragraphs; summarise again afterwards.',
              ),
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: const Color(0xFFB7C3D6),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _priorStudiesPaste,
              minLines: 3,
              maxLines: 8,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                hintText: 'https://doi.org/10.…\n10.xxxx/…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.t(
                'في المسودة الآن: $works مرجعاً مؤكداً ($withAbs بملخص).',
                'In draft now: $works confirmed works ($withAbs with abstracts).',
              ),
              style: TextStyle(fontSize: 11, color: const Color(0xFFB7C3D6)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _loading || _busyKey != null
                        ? null
                        : _importPriorStudyDois,
                    icon: busyImport
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_outlined),
                    label: Text(
                      context.t(
                        'إضافة DOI خارجي',
                        'Add external DOIs',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading || _busyKey != null
                        ? null
                        : _writePriorStudiesChapter,
                    icon: busyWrite
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_stories_outlined),
                    label: Text(
                      context.t(
                        'تلخيص Abstracts (شكل الدراسات السابقة)',
                        'Summarise abstracts (prior-studies form)',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _arabicCatalogLinks(),
          ],
        ),
      ),
    );
  }

  Widget _arabicCatalogLinks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.t(
            'مصادر عربية للتصفح (ليست API)',
            'Arabic browse sources (not APIs)',
          ),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: const Color(0xFFFDE68A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.t(
            'مبتعث ودار المنظومة وغيرها للتصفح اليدوي. لا يمكن جلب Abstract/نص كامل آلياً منها (اشتراك/حقوق نشر)؛ افتح الموقع، ثم الصق DOI هنا إن توفر.',
            'Mobt3ath, Mandumah, and similar sites are for manual browsing. We cannot auto-fetch abstracts/full text (subscription/copyright); open the site, then paste a DOI here if available.',
          ),
          style: TextStyle(fontSize: 11, height: 1.4, color: const Color(0xFFB7C3D6)),
        ),
        const SizedBox(height: 6),
        for (final catalog in ArabicThesisCatalogs.all)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: OutlinedButton.icon(
              onPressed: () => _openExternalUri(catalog.uri),
              icon: const Icon(Icons.menu_book_outlined, size: 18),
              label: Text(
                context.t(catalog.titleAr, catalog.titleEn),
                textAlign: TextAlign.start,
              ),
            ),
          ),
      ],
    );
  }

  Widget _paragraphCard(
    ThesisChapter chapter,
    ThesisParagraph paragraph,
    bool arabic,
  ) {
    final dir = arabic ? TextDirection.rtl : TextDirection.ltr;
    final isPriorStudy = paragraph.id == 'lit_abstracts_all' ||
        paragraph.id.startsWith('lit_study_');
    final hasAbs = paragraph.references.any(
      (w) => w.abstractText.trim().length >= 80,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF12284F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _brand.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            paragraph.heading(arabic),
            textDirection: dir,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: const Color(0xFFFDE68A),
              fontSize: 13,
            ),
          ),
          if (isPriorStudy) ...[
            const SizedBox(height: 4),
            Text(
              hasAbs
                  ? context.t(
                      'Abstract متاح — زر التلخيص يعيد كتابة فقرة هذه الدراسة فقط بالشكل الأكاديمي.',
                      'Abstract available — summarise rewrites only this study in thesis form.',
                    )
                  : context.t(
                      'سيُجلب Abstract من الفهارس المفتوحة عند التلخيص إن وُجد.',
                      'Abstract will be fetched from open indexes when summarising, if available.',
                    ),
              style: TextStyle(fontSize: 11, color: const Color(0xFFB7C3D6)),
            ),
          ],
          const SizedBox(height: 8),
          if (paragraph.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey.shade300,
                  style: BorderStyle.solid,
                ),
              ),
              child: Text(
                isPriorStudy
                    ? context.t(
                        'فقرة دراسة فارغة. اضغط تلخيص Abstracts أعلاه لبناء الفصل من مراجع المقدمة، أو لخّص هذه البطاقة.',
                        'Empty study paragraph. Tap Summarise abstracts above to build from introduction refs, or summarise this card.',
                      )
                    : context.t(
                        'قسم فارغ. اكتب أمرك بالأسفل ثم اجلب المراجع وولّد.',
                        'Empty section. Type your command below, then fetch sources and generate.',
                      ),
                textDirection: dir,
                style: TextStyle(
                  color: const Color(0xFFB7C3D6),
                  fontStyle: FontStyle.italic,
                  height: 1.45,
                ),
              ),
            )
          else ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: SingleChildScrollView(
                child: SelectableText(
                  ThesisStudioCitations.styledProse(
                    paragraph.body,
                    _draft!,
                    works: paragraph.references.isNotEmpty
                        ? paragraph.references
                        : null,
                  ),
                  textDirection: dir,
                  textAlign: arabic ? TextAlign.right : TextAlign.start,
                  style: const TextStyle(height: 1.55),
                ),
              ),
            ),
            const SizedBox(height: 6),
            _lengthMeter(chapter, paragraph),
          ],
          const SizedBox(height: 10),
          if (isPriorStudy)
            _priorStudyTools(chapter, paragraph, arabic)
          else
            _commandTools(
              controller: _paraCmd(paragraph),
              hint: '',
              writeKey: 'write:${paragraph.id}',
              refsKey: 'refs:${paragraph.id}',
              onWrite: () => _writeParagraph(chapter, paragraph),
              onRefs: () => _harvestParagraph(chapter, paragraph),
              references: paragraph.references,
              canExport: paragraph.body.trim().isNotEmpty,
              onExportPdf: () => _exportExcerpt(
                format: 'pdf',
                heading: paragraph.heading(arabic),
                body: paragraph.body,
                works: paragraph.references,
              ),
              onExportDocx: () => _exportExcerpt(
                format: 'docx',
                heading: paragraph.heading(arabic),
                body: paragraph.body,
                works: paragraph.references,
              ),
            ),
        ],
      ),
    );
  }

  Widget _priorStudyTools(
    ThesisChapter chapter,
    ThesisParagraph paragraph,
    bool arabic,
  ) {
    final thisKey = 'write:${paragraph.id}';
    final writing = _busyKey == thisKey;
    final otherBusy = _busyKey != null && _busyKey != thisKey;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _loading || writing || otherBusy
                    ? null
                    : () {
                        if (paragraph.id == 'lit_abstracts_all') {
                          _writePriorStudiesChapter();
                          return;
                        }
                        if (paragraph.references.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                context.t(
                                  'لا مرجع مؤكد على هذه البطاقة لتلخيص Abstract.',
                                  'No confirmed reference on this card to summarise.',
                                ),
                              ),
                            ),
                          );
                          return;
                        }
                        _writePriorStudyParagraph(chapter, paragraph);
                      },
                icon: writing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.summarize),
                label: Text(
                  writing
                      ? context.t(
                          'جارٍ تلخيص Abstract لهذه الدراسة فقط...',
                          'Summarising Abstract for this study only...',
                        )
                      : context.t(
                          'تلخيص Abstract لهذه الدراسة',
                          'Summarise Abstract for this study',
                        ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _brand,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            if (paragraph.body.trim().isNotEmpty) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'PDF',
                onPressed: _loading || _busyKey != null
                    ? null
                    : () => _exportExcerpt(
                          format: 'pdf',
                          heading: paragraph.heading(arabic),
                          body: paragraph.body,
                          works: paragraph.references,
                        ),
                icon: const Icon(Icons.picture_as_pdf_outlined),
              ),
              IconButton(
                tooltip: 'Word',
                onPressed: _loading || _busyKey != null
                    ? null
                    : () => _exportExcerpt(
                          format: 'docx',
                          heading: paragraph.heading(arabic),
                          body: paragraph.body,
                          works: paragraph.references,
                        ),
                icon: const Icon(Icons.description_outlined),
              ),
            ],
          ],
        ),
        if (paragraph.references.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            context.t(
              'مرجع مؤكد: ${paragraph.references.length}'
              '${hasAbsLabel(paragraph) ? ' · Abstract ✓' : ' · Abstract؟'}',
              'Confirmed reference: ${paragraph.references.length}'
              '${hasAbsLabel(paragraph) ? ' · Abstract ✓' : ' · Abstract?'}',
            ),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFB7C3D6),
            ),
          ),
          for (final w in paragraph.references) ...[
            const SizedBox(height: 4),
            Text(
              w.title,
              style: const TextStyle(fontSize: 12, height: 1.35),
            ),
            Text(
              '${w.year ?? 'n.d.'} · ${w.doi}',
              style: TextStyle(fontSize: 11, color: const Color(0xFFB7C3D6)),
            ),
          ],
        ],
      ],
    );
  }

  bool hasAbsLabel(ThesisParagraph paragraph) => paragraph.references.any(
        (w) => w.abstractText.trim().length >= 80,
      );

  Widget _lengthMeter(ThesisChapter chapter, ThesisParagraph paragraph) {
    final command = _paraCmd(paragraph).text.trim().isNotEmpty
        ? _paraCmd(paragraph).text
        : paragraph.lastCommand;
    final spec = ThesisCommandSpec.parse(
      command,
      depth: chapter.depth,
      chapterId: chapter.id,
    );
    final words = ThesisLengthBudget.wordCount(paragraph.body);
    final pages = ThesisLengthBudget.estimatedPagesOf(paragraph.body);
    final asked = spec.hasExplicitLength
        ? context.t(
            'طلب ≈ ${spec.estimatedPages} صفحة',
            'Asked ≈ ${spec.estimatedPages} pages',
          )
        : null;
    return Text(
      [
        context.t('$words كلمة · ≈ $pages صفحة', '$words words · ≈ $pages pp.'),
        if (asked != null) asked,
        if (spec.hasExplicitLength && pages < spec.estimatedPages)
          context.t(
            'لم يكتمل الطول بعد — أعد التوليد للمتابعة أو انتظر حتى تنتهي الدفعات.',
            'Length not reached yet — generate again to continue, or wait until all passes finish.',
          ),
      ].join(' · '),
      style: TextStyle(fontSize: 12, color: const Color(0xFFB7C3D6), height: 1.35),
    );
  }

  Widget _commandTools({
    required TextEditingController controller,
    required String hint,
    required String writeKey,
    required String refsKey,
    required Future<void> Function() onWrite,
    required Future<void> Function() onRefs,
    required List<GroundedWork> references,
    bool canExport = false,
    Future<void> Function()? onExportPdf,
    Future<void> Function()? onExportDocx,
  }) {
    final busy = _busyKey != null || _loading;
    final writing = _busyKey == writeKey;
    final fetching = _busyKey == refsKey;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          enabled: !busy,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            prefixIcon: const Icon(Icons.edit_note, color: const Color(0xFF93C5FD)),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: busy ? null : onRefs,
              icon: fetching
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.menu_book_outlined, size: 18),
              label: Text(context.t('جلب المراجع', 'Fetch sources')),
            ),
            FilledButton.icon(
              onPressed: busy ? null : onWrite,
              icon: writing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.notes, size: 18),
              label: Text(context.t('توليد هذه الفقرة', 'Generate this paragraph')),
              style: FilledButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
              ),
            ),
            IconButton.outlined(
              tooltip: context.t('تصدير PDF', 'Export PDF'),
              onPressed: busy || !canExport ? null : onExportPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined, color: const Color(0xFF93C5FD)),
            ),
            IconButton.outlined(
              tooltip: context.t('تصدير Word', 'Export Word'),
              onPressed: busy || !canExport ? null : onExportDocx,
              icon: const Icon(Icons.description_outlined, color: const Color(0xFF93C5FD)),
            ),
          ],
        ),
        if (fetching || writing) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(
            color: const Color(0xFFFDE68A),
            backgroundColor: _brand.withValues(alpha: 0.12),
          ),
          if (_progress.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _progress,
              style: TextStyle(fontSize: 12, color: const Color(0xFFB7C3D6)),
            ),
          ],
        ],
        if (references.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            context.t(
              '${references.length} مرجع مؤكد لهذا الأمر',
              '${references.length} confirmed sources for this command',
            ),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          for (var i = 0; i < references.length && i < 12; i++)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                references[i].title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, height: 1.3),
              ),
              subtitle: Text(
                '${references[i].year ?? 'n.d.'} · ${references[i].doi}',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: IconButton(
                tooltip: 'DOI',
                icon: const Icon(Icons.open_in_new, size: 16),
                onPressed: () => _openDoi(references[i].doi),
              ),
            ),
        ],
      ],
    );
  }
}
