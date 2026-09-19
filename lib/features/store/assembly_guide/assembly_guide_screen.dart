import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/locale/locale_extensions.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/widgets/acadegate_app_bar.dart';
import '../../ai_advisor/advisor_attachment_service.dart';
import '../store_theme.dart';
import 'assembly_guide_animation_player.dart';
import 'assembly_guide_models.dart';
import 'assembly_guide_service.dart';
import 'assembly_guide_tts.dart';
import 'guide_scene_visual.dart';

/// مشغّل الدليل التفاعلي (إرشاد هاتفي + صوت + فحص صورة لأي منتج).
class AssemblyGuideScreen extends StatefulWidget {
  final String productId;
  final String productName;
  final AssemblyGuide guide;

  const AssemblyGuideScreen({
    super.key,
    required this.productId,
    required this.productName,
    required this.guide,
  });

  @override
  State<AssemblyGuideScreen> createState() => _AssemblyGuideScreenState();
}

class _AssemblyGuideScreenState extends State<AssemblyGuideScreen> {
  int _index = 0;
  bool _voiceOn = true;
  bool _checking = false;
  AssemblyGuideCheckResult? _lastCheck;
  final Set<int> _passedSteps = {};

  AssemblyGuideStep get _step => widget.guide.steps[_index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakCurrent());
  }

  @override
  void dispose() {
    AssemblyGuideTts.instance.stop();
    super.dispose();
  }

  String _title(AssemblyGuideStep s) => LocaleService.instance.isEnglish
      ? (s.titleEn.isNotEmpty ? s.titleEn : s.titleAr)
      : (s.titleAr.isNotEmpty ? s.titleAr : s.titleEn);

  String _body(AssemblyGuideStep s) => LocaleService.instance.isEnglish
      ? (s.bodyEn.isNotEmpty ? s.bodyEn : s.bodyAr)
      : (s.bodyAr.isNotEmpty ? s.bodyAr : s.bodyEn);

  String _speakText(AssemblyGuideStep s) {
    final spoken = LocaleService.instance.isEnglish
        ? (s.speakEn.isNotEmpty ? s.speakEn : s.speakAr)
        : (s.speakAr.isNotEmpty ? s.speakAr : s.speakEn);
    if (spoken.trim().isNotEmpty) return spoken.trim();
    final t = _title(s);
    final b = _body(s);
    return b.isEmpty ? t : '$t. $b';
  }

  Future<void> _speakCurrent() async {
    if (!_voiceOn) return;
    await AssemblyGuideTts.instance.speak(_speakText(_step));
  }

  Future<void> _go(int next) async {
    if (next < 0 || next >= widget.guide.steps.length) return;
    await AssemblyGuideTts.instance.stop();
    setState(() {
      _index = next;
      _lastCheck = null;
    });
    await _speakCurrent();
  }

  Future<void> _openVideo(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _checkWithCamera({required bool fromCamera}) async {
    setState(() {
      _checking = true;
      _lastCheck = null;
    });
    try {
      final pending = fromCamera
          ? await AdvisorAttachmentService.instance.pickFromCamera()
          : await AdvisorAttachmentService.instance.pickImage();
      if (pending == null || !mounted) {
        setState(() => _checking = false);
        return;
      }
      final parts =
          AdvisorAttachmentService.instance.toGeminiParts([pending]);
      if (parts.isEmpty) {
        setState(() => _checking = false);
        return;
      }
      final result = await AssemblyGuideService.instance.verifyStepPhoto(
        step: _step,
        stepIndex: _index,
        totalSteps: widget.guide.steps.length,
        productName: widget.productName,
        photo: parts.first,
      );
      if (!mounted) return;
      setState(() {
        _checking = false;
        _lastCheck = result;
        if (result.passed) _passedSteps.add(_index);
      });
      if (_voiceOn && result.feedback.isNotEmpty) {
        await AssemblyGuideTts.instance.speak(result.feedback);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _lastCheck = AssemblyGuideCheckResult(
          passed: false,
          feedback: '$e',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.guide.steps;
    final intro = LocaleService.instance.isEnglish
        ? (widget.guide.introEn.isNotEmpty
            ? widget.guide.introEn
            : widget.guide.introAr)
        : (widget.guide.introAr.isNotEmpty
            ? widget.guide.introAr
            : widget.guide.introEn);
    final progress = (_index + 1) / steps.length;

    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(
          context.t('الدليل التفاعلي', 'Interactive product guide'),
        ),
        actions: [
          IconButton(
            tooltip: _voiceOn
                ? context.t('إيقاف الصوت', 'Mute voice')
                : context.t('تشغيل الصوت', 'Enable voice'),
            onPressed: () async {
              setState(() => _voiceOn = !_voiceOn);
              if (!_voiceOn) {
                await AssemblyGuideTts.instance.stop();
              } else {
                await _speakCurrent();
              }
            },
            icon: Icon(_voiceOn ? Icons.volume_up : Icons.volume_off),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBDEFB)),
            ),
            child: Text(
              context.t(
                'إرشاد عبر الهاتف + صوت + فحص صورة بالذكاء الاصطناعي. '
                'ليس نظارات واقع مختلط كاملة — يوجّهك في مكان استخدام المنتج الفعلي.',
                'Phone coaching + voice + AI photo check. '
                'Not full mixed-reality glasses — guides you where the product is actually used.',
              ),
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
          if (widget.guide.hasAnimation) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AssemblyGuideAnimationPlayer(
                      productName: widget.productName,
                      guide: widget.guide,
                    ),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D7377),
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.science_outlined),
              label: Text(
                context.t(
                  'تشغيل فيديو الدليل',
                  'Play guide video',
                ),
              ),
            ),
          ],
          if (intro.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(intro.trim(), style: const TextStyle(height: 1.45)),
          ],
          const SizedBox(height: 16),
          Text(
            widget.productName,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            color: StoreTheme.accent,
          ),
          const SizedBox(height: 6),
          Text(
            context.t(
              'الخطوة ${_index + 1} من ${steps.length}'
              '${_passedSteps.contains(_index) ? ' · تم التحقق' : ''}',
              'Step ${_index + 1} of ${steps.length}'
              '${_passedSteps.contains(_index) ? ' · verified' : ''}',
            ),
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Text(
            _title(_step),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(_body(_step), style: const TextStyle(height: 1.5, fontSize: 15)),
          if ((_step.imageUrl ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 220,
                width: double.infinity,
                child: GuideSceneVisual(
                  imageUrl: _step.imageUrl,
                  productName: widget.productName,
                  title: _title(_step),
                  body: _body(_step),
                  index: _index,
                  total: steps.length,
                ),
              ),
            ),
          ],
          if ((_step.videoUrl ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openVideo(_step.videoUrl!),
              icon: const Icon(Icons.play_circle_outline),
              label: Text(
                context.t('فتح فيديو الخطوة', 'Open step video'),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _speakCurrent,
            icon: const Icon(Icons.record_voice_over_outlined),
            label: Text(context.t('أعد سماع الإرشاد', 'Replay voice guide')),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _checking
                ? null
                : () => _checkWithCamera(fromCamera: true),
            style: FilledButton.styleFrom(
              backgroundColor: StoreTheme.accent,
              minimumSize: const Size.fromHeight(48),
            ),
            icon: _checking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.camera_alt_outlined),
            label: Text(
              context.t(
                'صوّر الخطوة للتحقق الذكي',
                'Photograph this step for AI check',
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _checking
                ? null
                : () => _checkWithCamera(fromCamera: false),
            child: Text(
              context.t('أو اختر صورة من المعرض', 'Or pick from gallery'),
            ),
          ),
          if (_lastCheck != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _lastCheck!.passed
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _lastCheck!.passed
                      ? const Color(0xFFA5D6A7)
                      : const Color(0xFFFFCC80),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _lastCheck!.passed
                        ? context.t('يبدو صحيحاً', 'Looks correct')
                        : context.t('يحتاج تصحيحاً', 'Needs correction'),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _lastCheck!.passed
                          ? Colors.green.shade800
                          : Colors.orange.shade900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(_lastCheck!.feedback, style: const TextStyle(height: 1.4)),
                  if ((_lastCheck!.tip ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      context.t(
                        'نصيحة: ${_lastCheck!.tip}',
                        'Tip: ${_lastCheck!.tip}',
                      ),
                      style: const TextStyle(height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _index == 0 ? null : () => _go(_index - 1),
                  child: Text(context.t('السابق', 'Previous')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _index >= steps.length - 1
                      ? null
                      : () => _go(_index + 1),
                  style: FilledButton.styleFrom(
                    backgroundColor: StoreTheme.accent,
                  ),
                  child: Text(context.t('التالي', 'Next')),
                ),
              ),
            ],
          ),
          if (_index >= steps.length - 1) ...[
            const SizedBox(height: 12),
            Text(
              context.t(
                'أكملت خطوات الدليل. إن بقي شك، راجع الفيديو أو تواصل مع البائع.',
                'You finished the guide steps. If unsure, review the video or contact the seller.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ],
      ),
    );
  }
}
