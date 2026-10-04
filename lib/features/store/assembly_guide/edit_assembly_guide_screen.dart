import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/locale/locale_extensions.dart';
import '../../../core/security/firebase_security_messages.dart';
import '../../../core/widgets/acadegate_app_bar.dart';
import '../store_theme.dart';
import 'assembly_guide_ai_service.dart';
import 'assembly_guide_animation_player.dart';
import 'assembly_guide_animation_service.dart';
import 'assembly_guide_models.dart';
import 'assembly_guide_service.dart';
import 'guide_scene_visual.dart';

/// تحرير الدليل التفاعلي للمنتج (البائع).
class EditAssemblyGuideScreen extends StatefulWidget {
  final String productId;
  final String productName;

  const EditAssemblyGuideScreen({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  State<EditAssemblyGuideScreen> createState() =>
      _EditAssemblyGuideScreenState();
}

class _EditAssemblyGuideScreenState extends State<EditAssemblyGuideScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _generating = false;
  bool _animating = false;
  int _animDone = 0;
  int _animTotal = 0;
  bool _enabled = true;
  String _unlock = AssemblyGuideUnlock.afterPurchase;
  String? _aiNotes;
  String? _productImageUrl;
  String _productDescription = '';
  String _productCategory = '';
  String? _filmUrl;
  List<String> _filmClips = [];
  List<int> _filmClipSteps = [];
  final _introAr = TextEditingController();
  final _introEn = TextEditingController();
  final List<_StepDraft> _steps = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _introAr.dispose();
    _introEn.dispose();
    for (final s in _steps) {
      s.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final guide =
        await AssemblyGuideService.instance.loadForProduct(widget.productId);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('product')
          .doc(widget.productId)
          .get();
      final data = snap.data() ?? {};
      _productImageUrl = data['imageUrl']?.toString();
      _productDescription = data['description']?.toString() ?? '';
      _productCategory = data['category']?.toString() ?? '';
    } catch (_) {}
    if (!mounted) return;
    if (guide != null) {
      _enabled = guide.enabled;
      _unlock = guide.unlock;
      _introAr.text = guide.introAr;
      _introEn.text = guide.introEn;
      _filmUrl = guide.filmUrl;
      _filmClips = List<String>.from(guide.filmClips);
      _filmClipSteps = List<int>.from(guide.filmClipSteps);
      for (final s in guide.steps) {
        _steps.add(_StepDraft.fromStep(s));
      }
    }
    if (_steps.isEmpty) {
      _steps.add(_StepDraft.empty());
    }
    setState(() => _loading = false);
  }

  void _addStep() => setState(() => _steps.add(_StepDraft.empty()));

  void _removeStep(int i) {
    if (_steps.length <= 1) return;
    setState(() {
      _steps[i].dispose();
      _steps.removeAt(i);
    });
  }

  bool get _hasMeaningfulSteps => _steps.any(
        (s) =>
            s.titleAr.text.trim().isNotEmpty ||
            s.titleEn.text.trim().isNotEmpty ||
            s.bodyAr.text.trim().isNotEmpty,
      );

  Future<void> _generateWithAi() async {
    if (_generating) return;
    if (_hasMeaningfulSteps) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.t('استبدال الخطوات؟', 'Replace steps?')),
          content: Text(
            ctx.t(
              'التوليد الذكي سيستبدل الخطوات الحالية بمسودة جديدة للمراجعة.',
              'AI generation will replace current steps with a new draft to review.',
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

    setState(() => _generating = true);
    try {
      final draft = await AssemblyGuideAiService.instance.generateForProduct(
        productId: widget.productId,
        productNameHint: widget.productName,
      );
      if (!mounted) return;
      for (final s in _steps) {
        s.dispose();
      }
      _steps.clear();
      _enabled = draft.guide.enabled;
      _unlock = draft.guide.unlock;
      _introAr.text = draft.guide.introAr;
      _introEn.text = draft.guide.introEn;
      _aiNotes = draft.notes;
      for (final step in draft.guide.steps) {
        _steps.add(_StepDraft.fromStep(step));
      }
      if (_steps.isEmpty) _steps.add(_StepDraft.empty());
      setState(() {});
      await _generateAnimation();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  AssemblyGuide _guideFromEditors() {
    final steps = <AssemblyGuideStep>[];
    for (final d in _steps) {
      final titleAr = d.titleAr.text.trim();
      final titleEn = d.titleEn.text.trim();
      if (titleAr.isEmpty && titleEn.isEmpty) continue;
      steps.add(AssemblyGuideStep(
        id: d.id,
        titleAr: titleAr.isNotEmpty ? titleAr : titleEn,
        titleEn: titleEn.isNotEmpty ? titleEn : titleAr,
        bodyAr: d.bodyAr.text.trim(),
        bodyEn: d.bodyEn.text.trim(),
        speakAr: d.speakAr.text.trim(),
        speakEn: d.speakEn.text.trim(),
        imageUrl: d.imageUrl.text.trim().isEmpty ? null : d.imageUrl.text.trim(),
        videoUrl: d.videoUrl.text.trim().isEmpty ? null : d.videoUrl.text.trim(),
        checkHintAr: d.checkHintAr.text.trim(),
        checkHintEn: d.checkHintEn.text.trim(),
      ));
    }
    return AssemblyGuide(
      enabled: _enabled,
      unlock: _unlock,
      introAr: _introAr.text.trim(),
      introEn: _introEn.text.trim(),
      steps: steps,
      filmUrl: _filmUrl,
      filmClips: _filmClips,
      filmClipSteps: _filmClipSteps,
    );
  }

  Future<void> _generateAnimation() async {
    if (_animating) return;
    final current = _guideFromEditors();
    setState(() {
      _animating = true;
      _animDone = 0;
      _animTotal = 1;
    });
    try {
      final filmed = await AssemblyGuideAnimationService.instance.generateFilm(
        productId: widget.productId,
        productName: widget.productName,
        guide: current,
        productImageUrl: _productImageUrl,
        description: _productDescription,
        category: _productCategory,
      );
      if (!mounted) return;
      _filmUrl = filmed.filmUrl;
      _filmClips = List<String>.from(filmed.filmClips);
      _filmClipSteps = List<int>.from(filmed.filmClipSteps);
      await AssemblyGuideService.instance.saveForProduct(
        productId: widget.productId,
        guide: filmed.copyWith(enabled: true),
      );
      if (!mounted) return;
      setState(() {});
      final play = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.t('فيديو الدليل جاهز', 'Guide video ready')),
          content: Text(
            ctx.t(
              'تم إعداد فيديو دليل الاستخدام حسب الخطوات المكتوبة، مع شرح صوتي أسفل كل مقطع.',
              'A usage-guide video was prepared from the written steps, with spoken explanation under each clip.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.t('لاحقاً', 'Later')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.t('تشغيل فيديو الدليل', 'Play guide video')),
            ),
          ],
        ),
      );
      if (play == true && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AssemblyGuideAnimationPlayer(
              productName: widget.productName,
              guide: filmed,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(FirebaseSecurityMessages.fromException(e)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _animating = false);
    }
  }

  Future<void> _playAnimation() async {
    final guide = _guideFromEditors();
    if (!guide.hasAnimation) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t(
            'ولّد فيديو دليل الاستخدام أولاً',
            'Generate the usage-guide video first',
          )),
        ),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssemblyGuideAnimationPlayer(
          productName: widget.productName,
          guide: guide,
        ),
      ),
    );
  }

  Future<void> _openVideoSearch(String query) async {
    final uri = Uri.parse(AssemblyGuideAiService.youtubeSearchUrl(query));
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final guide = _guideFromEditors();
      if (!guide.hasSteps) {
        throw Exception(context.t(
          'أضف خطوة واحدة على الأقل بعنوان',
          'Add at least one titled step',
        ));
      }
      await AssemblyGuideService.instance.saveForProduct(
        productId: widget.productId,
        guide: guide,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('تم حفظ الدليل', 'Guide saved')),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('الدليل التفاعلي', 'Interactive product guide')),
        actions: [
          TextButton(
            onPressed: _saving || _loading || _animating || _generating ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.t('حفظ', 'Save')),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                Text(
                  widget.productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.t(
                    'املأ الخطوات يدوياً أو ولّدها، ثم أنشئ فيديو '
                    'دليل الاستخدام الذي يتبع الخطوات مع شرح صوتي.',
                    'Fill the steps yourself or generate them, then create a '
                    'usage-guide video that follows the steps with spoken explanation.',
                  ),
                  style: TextStyle(color: StoreTheme.muted, height: 1.4),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F7FA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF80DEEA)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.t(
                          'تولّد الأداة خطوات الدليل ثم فيديو توضيحي لكل خطوة '
                          '(المشهد حسب تخصص المنتج). التوليد عادة خلال دقيقتين إلى أربع. '
                          'المقطع يعاد أثناء الشرح الصوتي حتى لا ينقطع قبل انتهاء النص.',
                          'The tool fills the guide steps then an instructional clip per step '
                          '(setting matches the product specialty). Generation usually takes 2–4 minutes. '
                          'Each clip loops during narration so the explanation is not cut short.',
                        ),
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _generating || _saving || _animating
                            ? null
                            : _generateWithAi,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF00838F),
                          minimumSize: const Size.fromHeight(44),
                        ),
                        icon: (_generating && !_animating)
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.playlist_add),
                        label: Text(
                          context.t(
                            'ولّد الخطوات + فيديو الدليل',
                            'Generate steps + guide video',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _generating || _saving || _animating
                            ? null
                            : () => _generateAnimation(),
                        icon: _animating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.science_outlined),
                        label: Text(
                          _animating
                              ? context.t(
                                  'جاري إعداد فيديو الدليل… عادة دقيقتان إلى أربع',
                                  'Preparing the guide video… usually 2–4 minutes',
                                )
                              : context.t(
                                  'توليد فيديو دليل الاستخدام',
                                  'Generate usage-guide video',
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _animating ? null : _playAnimation,
                        style: FilledButton.styleFrom(
                          backgroundColor: StoreTheme.accent,
                          minimumSize: const Size.fromHeight(44),
                        ),
                        icon: const Icon(Icons.play_circle_fill),
                        label: Text(
                          context.t(
                            'تشغيل فيديو الدليل',
                            'Play guide video',
                          ),
                        ),
                      ),
                      if ((_aiNotes ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _aiNotes!.trim(),
                          style: TextStyle(
                            fontSize: 12,
                            color: StoreTheme.muted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.t('تفعيل الدليل', 'Enable guide')),
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _unlock,
                  decoration: InputDecoration(
                    labelText: context.t('متى يُفتح؟', 'When unlock?'),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: AssemblyGuideUnlock.afterPurchase,
                      child: Text(context.t(
                        'بعد الشراء (محجوز/مُفرَج)',
                        'After purchase (held/released)',
                      )),
                    ),
                    DropdownMenuItem(
                      value: AssemblyGuideUnlock.always,
                      child: Text(context.t(
                        'متاح للجميع (معاينة)',
                        'Always available (preview)',
                      )),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _unlock = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _introAr,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: context.t('مقدمة (عربي)', 'Intro (AR)'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _introEn,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: context.t('مقدمة (إنجليزي)', 'Intro (EN)'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ...List.generate(_steps.length, (i) {
                  final s = _steps[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Text(
                                context.t('خطوة ${i + 1}', 'Step ${i + 1}'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => _removeStep(i),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                          TextField(
                            controller: s.titleAr,
                            decoration: InputDecoration(
                              labelText:
                                  context.t('عنوان عربي', 'Title AR'),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: s.titleEn,
                            decoration: InputDecoration(
                              labelText:
                                  context.t('عنوان إنجليزي', 'Title EN'),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: s.bodyAr,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText:
                                  context.t('تفاصيل عربي', 'Body AR'),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: s.bodyEn,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText:
                                  context.t('تفاصيل إنجليزي', 'Body EN'),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: s.speakAr,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: context.t(
                                'نص الصوت عربي (اختياري)',
                                'Voice text AR (optional)',
                              ),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: s.speakEn,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: context.t(
                                'نص الصوت إنجليزي (اختياري)',
                                'Voice text EN (optional)',
                              ),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: s.imageUrl,
                            decoration: InputDecoration(
                              labelText: context.t(
                                'رابط صورة الخطوة (اختياري)',
                                'Step image URL (optional)',
                              ),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          if (s.imageUrl.text.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                height: 140,
                                width: double.infinity,
                                child: GuideSceneVisual(
                                  imageUrl: s.imageUrl.text.trim(),
                                  productName: widget.productName,
                                  title: s.titleAr.text.trim().isNotEmpty
                                      ? s.titleAr.text.trim()
                                      : s.titleEn.text.trim(),
                                  body: s.bodyAr.text.trim(),
                                  index: i,
                                  total: _steps.length,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          TextField(
                            controller: s.videoUrl,
                            decoration: InputDecoration(
                              labelText: context.t(
                                'رابط فيديو / بحث يوتيوب',
                                'Video / YouTube search URL',
                              ),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton.icon(
                              onPressed: () async {
                                final raw = s.videoUrl.text.trim();
                                if (raw.isNotEmpty) {
                                  final uri = Uri.tryParse(raw);
                                  if (uri != null) {
                                    await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                    return;
                                  }
                                }
                                await _openVideoSearch(
                                  '${widget.productName} tutorial how to use',
                                );
                              },
                              icon: const Icon(Icons.play_circle_outline, size: 18),
                              label: Text(
                                context.t(
                                  'فتح الفيديو / بحث يوتيوب',
                                  'Open video / YouTube search',
                                ),
                              ),
                            ),
                          ),
                          TextField(
                            controller: s.checkHintAr,
                            decoration: InputDecoration(
                              labelText: context.t(
                                'معيار التحقق للكاميرا (عربي)',
                                'Camera check hint (AR)',
                              ),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: s.checkHintEn,
                            decoration: InputDecoration(
                              labelText: context.t(
                                'معيار التحقق للكاميرا (إنجليزي)',
                                'Camera check hint (EN)',
                              ),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                OutlinedButton.icon(
                  onPressed: _addStep,
                  icon: const Icon(Icons.add),
                  label: Text(context.t('إضافة خطوة', 'Add step')),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: StoreTheme.accent,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(context.t('حفظ الدليل', 'Save guide')),
                ),
              ],
            ),
    );
  }
}

class _StepDraft {
  final String id;
  final titleAr = TextEditingController();
  final titleEn = TextEditingController();
  final bodyAr = TextEditingController();
  final bodyEn = TextEditingController();
  final speakAr = TextEditingController();
  final speakEn = TextEditingController();
  final imageUrl = TextEditingController();
  final videoUrl = TextEditingController();
  final checkHintAr = TextEditingController();
  final checkHintEn = TextEditingController();

  _StepDraft({required this.id});

  factory _StepDraft.empty() => _StepDraft(
        id: 'step_${DateTime.now().microsecondsSinceEpoch}',
      );

  factory _StepDraft.fromStep(AssemblyGuideStep s) {
    final d = _StepDraft(id: s.id);
    d.titleAr.text = s.titleAr;
    d.titleEn.text = s.titleEn;
    d.bodyAr.text = s.bodyAr;
    d.bodyEn.text = s.bodyEn;
    d.speakAr.text = s.speakAr;
    d.speakEn.text = s.speakEn;
    d.imageUrl.text = s.imageUrl ?? '';
    d.videoUrl.text = s.videoUrl ?? '';
    d.checkHintAr.text = s.checkHintAr;
    d.checkHintEn.text = s.checkHintEn;
    return d;
  }

  void dispose() {
    titleAr.dispose();
    titleEn.dispose();
    bodyAr.dispose();
    bodyEn.dispose();
    speakAr.dispose();
    speakEn.dispose();
    imageUrl.dispose();
    videoUrl.dispose();
    checkHintAr.dispose();
    checkHintEn.dispose();
  }
}
