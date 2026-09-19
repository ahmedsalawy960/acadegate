import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../../core/firebase/callable_http_client.dart';
import '../../../core/locale/app_translate.dart';
import '../../ai_advisor/gemini_advisor_client.dart';
import 'assembly_guide_models.dart';

/// يولّد فيديو دليل الاستخدام: مقطعان لكل خطوة مكتوبة في مكان يناسب التخصص.
class AssemblyGuideAnimationService {
  AssemblyGuideAnimationService._();
  static final AssemblyGuideAnimationService instance =
      AssemblyGuideAnimationService._();

  Future<AssemblyGuide> generateFilm({
    required String productId,
    required String productName,
    required AssemblyGuide guide,
    String? productImageUrl,
    String? description,
    String? category,
  }) async {
    if (!GeminiAdvisorClient.canUseCloudBackend) {
      throw Exception(appTr(
        'سجّل الدخول لتوليد فيديو دليل الاستخدام.',
        'Sign in to generate the usage-guide video.',
      ));
    }

    final payload = <String, dynamic>{
      'productId': productId,
      'productName': productName,
      'description': description ?? '',
      'category': category ?? '',
      'imageUrl': productImageUrl ?? '',
      'steps': guide.steps
          .map(
            (s) => {
              'titleAr': s.titleAr,
              'titleEn': s.titleEn,
              'bodyAr': s.bodyAr,
              'bodyEn': s.bodyEn,
            },
          )
          .toList(),
    };

    late final Map<String, dynamic> data;
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        data = await CallableHttpClient.call(
          name: 'generateProductFilm',
          data: payload,
          timeout: const Duration(minutes: 8),
          callableProtocol: true,
        );
      } else {
        try {
          final callable = FirebaseFunctions.instance.httpsCallable(
            'generateProductFilm',
            options: HttpsCallableOptions(timeout: const Duration(minutes: 8)),
          );
          final response = await callable.call<Map<String, dynamic>>(payload);
          data = Map<String, dynamic>.from(response.data);
        } on FirebaseFunctionsException catch (e) {
          if ((e.message ?? '').toLowerCase().contains('channel') ||
              (e.message ?? '').toLowerCase().contains('pigeon')) {
            data = await CallableHttpClient.call(
              name: 'generateProductFilm',
              data: payload,
              timeout: const Duration(minutes: 8),
              callableProtocol: true,
            );
          } else {
            throw Exception(e.message ?? e.code);
          }
        }
      }
    } catch (e) {
      final raw = e is FirebaseFunctionsException
          ? (e.message ?? e.code)
          : e.toString().replaceAll(RegExp(r'^(Exception:\s*)+'), '');
      throw Exception(raw.replaceAll(RegExp(r'^(Exception:\s*)+'), ''));
    }

    final clips = <String>[];
    final clipSteps = <int>[];
    final rawClips = data['clips'];
    if (rawClips is List) {
      for (final item in rawClips) {
        if (item is Map) {
          final u = item['url']?.toString().trim() ?? '';
          if (u.isEmpty) continue;
          clips.add(u);
          final rawIdx = item['stepIndex'];
          final n = rawIdx is int ? rawIdx : int.tryParse('${rawIdx ?? ''}');
          clipSteps.add(n ?? clips.length - 1);
        } else {
          final u = item?.toString().trim() ?? '';
          if (u.isNotEmpty) {
            clips.add(u);
            clipSteps.add(clips.length - 1);
          }
        }
      }
    }
    final url = data['videoUrl']?.toString().trim() ?? '';
    if (clips.isEmpty && url.isNotEmpty) {
      clips.add(url);
      clipSteps.add(0);
    }
    if (clips.isEmpty) {
      throw Exception(
        data['error']?.toString() ??
            appTr(
              'تعذر توليد فيديو دليل الاستخدام. أعد المحاولة.',
              'Could not generate the usage-guide video. Try again.',
            ),
      );
    }
    return guide.copyWith(
      enabled: true,
      filmUrl: clips.first,
      filmClips: clips,
      filmClipSteps: clipSteps,
    );
  }
}
