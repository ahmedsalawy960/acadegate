import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/locale/locale_extensions.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/video/network_film_view.dart';
import '../../../core/widgets/acadegate_app_bar.dart';
import '../store_theme.dart';
import 'assembly_guide_models.dart';
import 'assembly_guide_tts.dart';

/// مشغّل فيديو دليل الاستخدام مع شرح صوتي لنص الخطوات.
class AssemblyGuideAnimationPlayer extends StatefulWidget {
  final String productName;
  final AssemblyGuide guide;

  const AssemblyGuideAnimationPlayer({
    super.key,
    required this.productName,
    required this.guide,
  });

  @override
  State<AssemblyGuideAnimationPlayer> createState() =>
      _AssemblyGuideAnimationPlayerState();
}

class _AssemblyGuideAnimationPlayerState
    extends State<AssemblyGuideAnimationPlayer> {
  int _index = 0;

  List<String> get _clips => widget.guide.playlist;

  int get _stepIndex => widget.guide.stepIndexForClip(_index);

  AssemblyGuideStep? get _step {
    if (_stepIndex < 0 || _stepIndex >= widget.guide.steps.length) return null;
    return widget.guide.steps[_stepIndex];
  }

  int get _stepCount {
    if (widget.guide.steps.isNotEmpty) return widget.guide.steps.length;
    return _clips.length;
  }

  bool get _hasNextPart {
    if (_index + 1 >= _clips.length) return false;
    return widget.guide.stepIndexForClip(_index + 1) == _stepIndex;
  }

  int _firstClipOfStep(int stepIndex) {
    for (var i = 0; i < _clips.length; i++) {
      if (widget.guide.stepIndexForClip(i) == stepIndex) return i;
    }
    return stepIndex.clamp(0, _clips.isEmpty ? 0 : _clips.length - 1);
  }

  int get _prevStepIndex {
    final current = _stepIndex;
    for (var i = _index - 1; i >= 0; i--) {
      final s = widget.guide.stepIndexForClip(i);
      if (s != current) return s;
    }
    return -1;
  }

  int get _nextStepIndex {
    final current = _stepIndex;
    for (var i = _index + 1; i < _clips.length; i++) {
      final s = widget.guide.stepIndexForClip(i);
      if (s != current) return s;
    }
    return -1;
  }

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

  Future<void> _speakCurrent() async {
    final step = _step;
    if (step == null) return;
    final en = LocaleService.instance.isEnglish;
    final text = en
        ? (step.speakEn.trim().isNotEmpty
            ? step.speakEn
            : '${step.titleEn}. ${step.bodyEn}')
        : (step.speakAr.trim().isNotEmpty
            ? step.speakAr
            : '${step.titleAr}. ${step.bodyAr}');
    await AssemblyGuideTts.instance.speak(text);
  }

  Future<void> _goClip(int next, {bool speak = true}) async {
    if (next < 0 || next >= _clips.length) return;
    if (speak) await AssemblyGuideTts.instance.stop();
    setState(() => _index = next);
    if (speak) await _speakCurrent();
  }

  Future<void> _goStep(int stepIndex) async {
    if (stepIndex < 0) return;
    await _goClip(_firstClipOfStep(stepIndex), speak: true);
  }

  void _onClipEnded() {
    if (!_hasNextPart) return;
    _goClip(_index + 1, speak: false);
  }

  Future<void> _openInBrowser() async {
    if (_clips.isEmpty) return;
    final uri = Uri.tryParse(_clips[_index]);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final step = _step;
    final en = LocaleService.instance.isEnglish;
    final title = step == null
        ? widget.productName
        : (en ? step.titleEn : step.titleAr);
    final body = step == null
        ? ''
        : (en ? step.bodyEn : step.bodyAr);

    return Scaffold(
      backgroundColor: const Color(0xFF05070C),
      appBar: AcadeGateAppBar(
        title: Text(context.t('فيديو دليل الاستخدام', 'Usage guide video')),
      ),
      body: _clips.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.t(
                    'لا يوجد فيديو بعد. من محرر الدليل اضغط توليد فيديو دليل الاستخدام.',
                    'No video yet. Generate the usage-guide video from the editor.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: NetworkFilmView(
                    key: ValueKey(_clips[_index]),
                    url: _clips[_index],
                    loop: !_hasNextPart,
                    onEnded: _hasNextPart ? _onClipEnded : null,
                  ),
                ),
                Container(
                  width: double.infinity,
                  color: const Color(0xFF0F1720),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.t(
                          'الخطوة ${_stepIndex + 1} من $_stepCount  ·  المقطع يعاد مع الشرح الصوتي',
                          'Step ${_stepIndex + 1} of $_stepCount  ·  clip loops with narration',
                        ),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (body.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          body.trim(),
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.45,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          IconButton.filled(
                            onPressed: _prevStepIndex >= 0
                                ? () => _goStep(_prevStepIndex)
                                : null,
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF1F2A36),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.skip_previous),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: _nextStepIndex >= 0
                                ? () => _goStep(_nextStepIndex)
                                : null,
                            style: IconButton.styleFrom(
                              backgroundColor: StoreTheme.accent,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.skip_next),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _openInBrowser,
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: Text(
                              context.t('فتح المقطع', 'Open clip'),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: _speakCurrent,
                            tooltip: context.t('إعادة الشرح الصوتي', 'Replay narration'),
                            icon: const Icon(Icons.volume_up, color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
