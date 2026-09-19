/// دليل تفاعلي مرتبط بمنتج المتجر (استخدام / تشغيل / تعامل — عبر الهاتف).
class AssemblyGuideUnlock {
  AssemblyGuideUnlock._();
  static const always = 'always';
  static const afterPurchase = 'after_purchase';
}

class AssemblyGuideStep {
  final String id;
  final String titleAr;
  final String titleEn;
  final String bodyAr;
  final String bodyEn;
  final String speakAr;
  final String speakEn;
  final String? imageUrl;
  final String? videoUrl;
  final String checkHintAr;
  final String checkHintEn;

  const AssemblyGuideStep({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    this.bodyAr = '',
    this.bodyEn = '',
    this.speakAr = '',
    this.speakEn = '',
    this.imageUrl,
    this.videoUrl,
    this.checkHintAr = '',
    this.checkHintEn = '',
  });

  AssemblyGuideStep copyWith({
    String? id,
    String? titleAr,
    String? titleEn,
    String? bodyAr,
    String? bodyEn,
    String? speakAr,
    String? speakEn,
    String? imageUrl,
    String? videoUrl,
    String? checkHintAr,
    String? checkHintEn,
  }) {
    return AssemblyGuideStep(
      id: id ?? this.id,
      titleAr: titleAr ?? this.titleAr,
      titleEn: titleEn ?? this.titleEn,
      bodyAr: bodyAr ?? this.bodyAr,
      bodyEn: bodyEn ?? this.bodyEn,
      speakAr: speakAr ?? this.speakAr,
      speakEn: speakEn ?? this.speakEn,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      checkHintAr: checkHintAr ?? this.checkHintAr,
      checkHintEn: checkHintEn ?? this.checkHintEn,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'titleAr': titleAr,
        'titleEn': titleEn,
        'bodyAr': bodyAr,
        'bodyEn': bodyEn,
        'speakAr': speakAr,
        'speakEn': speakEn,
        if (imageUrl != null && imageUrl!.trim().isNotEmpty)
          'imageUrl': imageUrl!.trim(),
        if (videoUrl != null && videoUrl!.trim().isNotEmpty)
          'videoUrl': videoUrl!.trim(),
        'checkHintAr': checkHintAr,
        'checkHintEn': checkHintEn,
      };

  factory AssemblyGuideStep.fromMap(Map<String, dynamic> map, {int index = 0}) {
    return AssemblyGuideStep(
      id: map['id']?.toString() ?? 'step_$index',
      titleAr: map['titleAr']?.toString() ?? map['title']?.toString() ?? '',
      titleEn: map['titleEn']?.toString() ?? map['title']?.toString() ?? '',
      bodyAr: map['bodyAr']?.toString() ?? map['body']?.toString() ?? '',
      bodyEn: map['bodyEn']?.toString() ?? map['body']?.toString() ?? '',
      speakAr: map['speakAr']?.toString() ?? '',
      speakEn: map['speakEn']?.toString() ?? '',
      imageUrl: map['imageUrl']?.toString(),
      videoUrl: map['videoUrl']?.toString(),
      checkHintAr: map['checkHintAr']?.toString() ?? '',
      checkHintEn: map['checkHintEn']?.toString() ?? '',
    );
  }
}

class AssemblyGuide {
  final bool enabled;
  final String version;
  final String unlock;
  final String introAr;
  final String introEn;
  final List<AssemblyGuideStep> steps;
  /// فيديو دليل الاستخدام (مقاطع لكل خطوة).
  final String? filmUrl;
  final List<String> filmClips;
  /// فهرس الخطوة المكتوبة لكل مقطع (قد يكون مقطعان لنفس الخطوة).
  final List<int> filmClipSteps;

  const AssemblyGuide({
    this.enabled = false,
    this.version = '1',
    this.unlock = AssemblyGuideUnlock.afterPurchase,
    this.introAr = '',
    this.introEn = '',
    this.steps = const [],
    this.filmUrl,
    this.filmClips = const [],
    this.filmClipSteps = const [],
  });

  bool get hasSteps => steps.isNotEmpty;

  bool get hasFilm =>
      filmClips.isNotEmpty || (filmUrl ?? '').trim().isNotEmpty;

  List<String> get playlist {
    if (filmClips.isNotEmpty) {
      return filmClips.where((u) => u.trim().isNotEmpty).toList();
    }
    final u = (filmUrl ?? '').trim();
    return u.isEmpty ? const <String>[] : <String>[u];
  }

  bool get hasAnimation => hasFilm;

  AssemblyGuide copyWith({
    bool? enabled,
    String? version,
    String? unlock,
    String? introAr,
    String? introEn,
    List<AssemblyGuideStep>? steps,
    String? filmUrl,
    List<String>? filmClips,
    List<int>? filmClipSteps,
  }) {
    return AssemblyGuide(
      enabled: enabled ?? this.enabled,
      version: version ?? this.version,
      unlock: unlock ?? this.unlock,
      introAr: introAr ?? this.introAr,
      introEn: introEn ?? this.introEn,
      steps: steps ?? this.steps,
      filmUrl: filmUrl ?? this.filmUrl,
      filmClips: filmClips ?? this.filmClips,
      filmClipSteps: filmClipSteps ?? this.filmClipSteps,
    );
  }

  int stepIndexForClip(int clipIndex) {
    if (clipIndex < 0 || clipIndex >= playlist.length) return 0;
    final lastStep = steps.isEmpty ? 0 : steps.length - 1;
    int clampStep(int value) {
      if (value < 0) return 0;
      if (value > lastStep) return lastStep;
      return value;
    }

    if (filmClipSteps.length == playlist.length) {
      return clampStep(filmClipSteps[clipIndex]);
    }
    if (steps.isNotEmpty &&
        playlist.length >= steps.length * 2 &&
        playlist.length % steps.length == 0) {
      final parts = playlist.length ~/ steps.length;
      return clampStep(clipIndex ~/ parts);
    }
    return clampStep(clipIndex);
  }

  /// دليل تجريبي جاهز للتجربة على أي منتج (بدون انتظار الذكاء الاصطناعي).
  factory AssemblyGuide.starterForProduct(String productName) {
    final n = productName.trim().isEmpty ? 'المنتج' : productName.trim();
    return AssemblyGuide(
      enabled: true,
      version: '1',
      unlock: AssemblyGuideUnlock.always,
      introAr:
          'دليل تجريبي لاستخدام «$n». اتبع الخطوات بالصوت والصورة. يمكنك تعديله أو توليد دليل أدق لاحقاً.',
      introEn:
          'Starter guide for “$n”. Follow the steps with voice and photos. You can edit or generate a smarter guide later.',
      steps: [
        AssemblyGuideStep(
          id: 's1',
          titleAr: 'السلامة أولاً',
          titleEn: 'Safety first',
          bodyAr:
              'اقرأ الملصق والتحذيرات. ارتدِ القفازات أو النظارة إن لزم. جهّز مكاناً نظيفاً وجيداً الإضاءة قبل لمس «$n».',
          bodyEn:
              'Read the label and warnings. Wear gloves or goggles if needed. Prepare a clean, well-lit space before handling “$n”.',
          speakAr:
              'قبل استخدام $n: اقرأ التحذيرات، ارتدِ معدات الحماية إن لزم، وجهّز مكاناً آمناً.',
          speakEn:
              'Before using $n: read the warnings, wear protection if needed, and prepare a safe workspace.',
          checkHintAr: 'ظهر الملصق أو معدات الحماية في الصورة',
          checkHintEn: 'Label or protective gear visible in the photo',
        ),
        AssemblyGuideStep(
          id: 's2',
          titleAr: 'تعرّف على المنتج',
          titleEn: 'Identify the product',
          bodyAr:
              'أخرج «$n» من العبوة برفق. طابق الاسم والرقم على العبوة مع ما طلبت. لا تخلطه بمنتج مشابه.',
          bodyEn:
              'Take “$n” out of the packaging gently. Match the name and code on the pack with what you ordered. Do not mix it with a similar item.',
          speakAr:
              'أخرج $n من العبوة، وتأكد أن الاسم على الملصق يطابق المنتج المطلوب.',
          speakEn:
              'Unpack $n and confirm the label matches the product you ordered.',
          checkHintAr: 'العبوة والملصق ظاهران بوضوح',
          checkHintEn: 'Packaging and label clearly visible',
        ),
        AssemblyGuideStep(
          id: 's3',
          titleAr: 'التحضير قبل الاستخدام',
          titleEn: 'Prepare before use',
          bodyAr:
              'رتّب الأدوات المساعدة (كؤوس، ماصات، كابل، حامل…). تأكد من درجة الحرارة والتهوية حسب تعليمات «$n».',
          bodyEn:
              'Lay out accessories (beakers, pipettes, cable, stand…). Check temperature and ventilation according to the instructions for “$n”.',
          speakAr:
              'جهّز الأدوات المساعدة، وتأكد من ظروف المكان قبل تشغيل أو استخدام $n.',
          speakEn:
              'Prepare accessories and check the workspace conditions before using $n.',
          checkHintAr: 'الأدوات المساعدة مرتبة بجانب المنتج',
          checkHintEn: 'Accessories arranged next to the product',
        ),
        AssemblyGuideStep(
          id: 's4',
          titleAr: 'الاستخدام الأول',
          titleEn: 'First use',
          bodyAr:
              'نفّذ الاستخدام الأساسي لـ«$n» ببطء حسب الغرض المكتوب على العبوة. لا تتجاوز الجرعة أو الجهد أو الوقت الموصى به.',
          bodyEn:
              'Perform the basic use of “$n” slowly according to the purpose on the pack. Do not exceed the recommended dose, voltage, or time.',
          speakAr:
              'ابدأ الاستخدام الأساسي لـ $n ببطء، ولا تتجاوز الجرعة أو الإعداد الموصى به.',
          speakEn:
              'Start the basic use of $n slowly, and do not exceed the recommended setting.',
          checkHintAr: 'المنتج في وضع الاستخدام الصحيح',
          checkHintEn: 'Product in the correct use position',
        ),
        AssemblyGuideStep(
          id: 's5',
          titleAr: 'بعد الانتهاء والتخزين',
          titleEn: 'After use and storage',
          bodyAr:
              'أغلق العبوة بإحكام، نظّف ما لامس المادة أو الجهاز، واحفظ «$n» بعيداً عن الحرارة والرطوبة والأطفال.',
          bodyEn:
              'Seal the pack, clean anything that touched the material or device, and store “$n” away from heat, moisture, and children.',
          speakAr:
              'بعد الانتهاء: أغلق $n، نظّف المكان، واحفظه في مكان آمن بعيداً عن الحرارة والرطوبة.',
          speakEn:
              'When finished: close $n, clean the area, and store it safely away from heat and moisture.',
          checkHintAr: 'العبوة مغلقة ومكان التخزين ظاهر',
          checkHintEn: 'Sealed pack and storage place visible',
        ),
      ],
    );
  }

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'version': version,
        'unlock': unlock,
        'introAr': introAr,
        'introEn': introEn,
        'steps': steps.map((s) => s.toMap()).toList(),
        if (filmUrl != null && filmUrl!.trim().isNotEmpty)
          'filmUrl': filmUrl!.trim(),
        if (filmClips.isNotEmpty) 'filmClips': filmClips,
        if (filmClipSteps.isNotEmpty) 'filmClipSteps': filmClipSteps,
      };

  factory AssemblyGuide.fromMap(dynamic raw) {
    if (raw is! Map) return const AssemblyGuide();
    final map = Map<String, dynamic>.from(raw);
    final stepsRaw = map['steps'];
    final steps = <AssemblyGuideStep>[];
    if (stepsRaw is List) {
      for (var i = 0; i < stepsRaw.length; i++) {
        final item = stepsRaw[i];
        if (item is Map) {
          steps.add(AssemblyGuideStep.fromMap(
            Map<String, dynamic>.from(item),
            index: i,
          ));
        }
      }
    }
    final clipRaw = map['filmClips'];
    final clips = <String>[];
    if (clipRaw is List) {
      for (final e in clipRaw) {
        final u = e?.toString().trim() ?? '';
        if (u.isNotEmpty) clips.add(u);
      }
    }
    final clipSteps = <int>[];
    final stepsRawIdx = map['filmClipSteps'];
    if (stepsRawIdx is List) {
      for (final e in stepsRawIdx) {
        final n = e is int ? e : int.tryParse(e.toString());
        if (n != null) clipSteps.add(n);
      }
    }
    return AssemblyGuide(
      enabled: map['enabled'] == true,
      version: map['version']?.toString() ?? '1',
      unlock: map['unlock']?.toString() ?? AssemblyGuideUnlock.afterPurchase,
      introAr: map['introAr']?.toString() ?? '',
      introEn: map['introEn']?.toString() ?? '',
      steps: steps,
      filmUrl: map['filmUrl']?.toString(),
      filmClips: clips,
      filmClipSteps: clipSteps,
    );
  }
}

class AssemblyGuideCheckResult {
  final bool passed;
  final String feedback;
  final String? tip;
  final bool fromAi;

  const AssemblyGuideCheckResult({
    required this.passed,
    required this.feedback,
    this.tip,
    this.fromAi = false,
  });
}
