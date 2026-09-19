import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/escrow/payment_status.dart';
import '../../../core/locale/app_translate.dart';
import '../../../core/locale/locale_service.dart';
import '../../ai_advisor/advisor_attachment.dart';
import '../../ai_advisor/gemini_advisor_client.dart';
import 'assembly_guide_models.dart';

class AssemblyGuideService {
  AssemblyGuideService._();
  static final AssemblyGuideService instance = AssemblyGuideService._();

  final _db = FirebaseFirestore.instance;

  Future<AssemblyGuide?> loadForProduct(String productId) async {
    final doc = await _db.collection('product').doc(productId).get();
    if (!doc.exists) return null;
    final guide = AssemblyGuide.fromMap(doc.data()?['assemblyGuide']);
    if (!guide.enabled || !guide.hasSteps) return null;
    return guide;
  }

  Future<void> saveForProduct({
    required String productId,
    required AssemblyGuide guide,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(appTr('سجّل الدخول أولاً', 'Sign in first'));
    }
    final snap = await _db.collection('product').doc(productId).get();
    if (!snap.exists) {
      throw Exception(appTr('المنتج غير موجود', 'Product not found'));
    }
    final createdBy = snap.data()?['createdBy']?.toString() ?? '';
    if (createdBy != user.uid) {
      throw Exception(appTr(
        'يمكنك تعديل دليل منتجاتك فقط',
        'You can only edit guides for your own products',
      ));
    }
    await _db.collection('product').doc(productId).set({
      'assemblyGuide': guide.toMap(),
      'hasAssemblyGuide': guide.enabled && guide.hasSteps,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// يفتح دليلاً موجوداً، أو ينشئ دليلاً تجريبياً جاهزاً للمالك.
  Future<AssemblyGuide> ensurePlayableGuide({
    required String productId,
    required String productName,
  }) async {
    final existing = await loadForProduct(productId);
    if (existing != null) return existing;
    final starter = AssemblyGuide.starterForProduct(productName);
    await saveForProduct(productId: productId, guide: starter);
    return starter;
  }

  /// هل يحق للمستخدم فتح الدليل؟
  Future<bool> canAccess({
    required String productId,
    required AssemblyGuide guide,
  }) async {
    if (!guide.enabled || !guide.hasSteps) return false;
    if (guide.unlock == AssemblyGuideUnlock.always) return true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    // البائع يرى دليله دائماً
    final product = await _db.collection('product').doc(productId).get();
    if (product.data()?['createdBy']?.toString() == user.uid) return true;

    final orders = await _db
        .collection('store_orders')
        .where('buyerId', isEqualTo: user.uid)
        .limit(40)
        .get();
    for (final d in orders.docs) {
      final data = d.data();
      if (data['productId']?.toString() != productId) continue;
      final status = data['paymentStatus']?.toString() ?? '';
      if (status == PaymentStatus.held || status == PaymentStatus.released) {
        return true;
      }
    }
    return false;
  }

  Future<AssemblyGuideCheckResult> verifyStepPhoto({
    required AssemblyGuideStep step,
    required int stepIndex,
    required int totalSteps,
    required String productName,
    required GeminiInlinePart photo,
  }) async {
    if (!GeminiAdvisorClient.isAvailable) {
      return AssemblyGuideCheckResult(
        passed: false,
        feedback: appTr(
          'فحص الصورة يحتاج تسجيل الدخول أو مفتاح Gemini.',
          'Photo check needs sign-in or a Gemini key.',
        ),
      );
    }

    final isEn = LocaleService.instance.isEnglish;
    final title = isEn
        ? (step.titleEn.isNotEmpty ? step.titleEn : step.titleAr)
        : (step.titleAr.isNotEmpty ? step.titleAr : step.titleEn);
    final body = isEn
        ? (step.bodyEn.isNotEmpty ? step.bodyEn : step.bodyAr)
        : (step.bodyAr.isNotEmpty ? step.bodyAr : step.bodyEn);
    final hint = isEn
        ? (step.checkHintEn.isNotEmpty ? step.checkHintEn : step.checkHintAr)
        : (step.checkHintAr.isNotEmpty ? step.checkHintAr : step.checkHintEn);

    final system = isEn
        ? '''
You are a practical coach for research equipment, chemicals, and supplies.
Given a PHOTO of the user's real workspace (lab, workshop, clinic, field, or desk — matching the product) and the expected STEP, decide if the step looks correctly done.
Return ONLY valid JSON:
{"passed": true|false, "feedback": "1-2 short sentences", "tip": "optional short tip if failed"}
Be practical. If the photo is unclear, set passed=false and ask for a clearer angle.
Do not invent brand-specific certs. Respond in English.
'''
        : '''
أنت مدرّب عملي لمعدات ومواد ومستلزمات البحث.
أمامك صورة من مكان استخدام المنتج الفعلي والخطوة المتوقعة. هل تبدو الخطوة منفّذة بشكل صحيح؟
أعد JSON صالحاً فقط:
{"passed": true|false, "feedback": "جملة أو جملتان", "tip": "نصيحة قصيرة إن فشل"}
كن عملياً. إن كانت الصورة غير واضحة: passed=false واطلب زاوية أوضح.
لا تخترع شهادات. اكتب بالعربية.
''';

    final userMsg = [
      appTr('المنتج: $productName', 'Product: $productName'),
      appTr(
        'الخطوة ${stepIndex + 1} من $totalSteps: $title',
        'Step ${stepIndex + 1} of $totalSteps: $title',
      ),
      if (body.isNotEmpty) appTr('التفاصيل: $body', 'Details: $body'),
      if (hint.isNotEmpty)
        appTr('معايير التحقق: $hint', 'Check criteria: $hint'),
      appTr(
        'افحص الصورة المرفقة وقيّم اكتمال هذه الخطوة فقط.',
        'Inspect the attached photo and judge only this step.',
      ),
    ].join('\n');

    final result = await GeminiAdvisorClient.instance.generateResult(
      systemPrompt: system,
      userMessage: userMsg,
      attachments: [photo],
      maxOutputTokens: 1024,
    );
    if (!result.isSuccess) {
      return AssemblyGuideCheckResult(
        passed: false,
        feedback: result.error ??
            appTr('تعذر فحص الصورة', 'Could not check the photo'),
      );
    }

    final parsed = _parseCheck(result.text!);
    if (parsed == null) {
      return AssemblyGuideCheckResult(
        passed: false,
        feedback: appTr(
          'تعذر قراءة نتيجة الفحص. أعد المحاولة بصورة أوضح.',
          'Could not parse check result. Retry with a clearer photo.',
        ),
        fromAi: true,
      );
    }
    return AssemblyGuideCheckResult(
      passed: parsed.$1,
      feedback: parsed.$2,
      tip: parsed.$3,
      fromAi: true,
    );
  }

  (bool, String, String?)? _parseCheck(String raw) {
    var t = raw.trim();
    if (!t.startsWith('{')) {
      final fence =
          RegExp(r'```(?:json)?\s*([\s\S]*?)```', caseSensitive: false)
              .firstMatch(t);
      if (fence != null) t = fence.group(1)?.trim() ?? t;
      final start = t.indexOf('{');
      final end = t.lastIndexOf('}');
      if (start >= 0 && end > start) t = t.substring(start, end + 1);
    }
    try {
      final map = jsonDecode(t);
      if (map is! Map) return null;
      final passed = map['passed'] == true;
      final feedback = map['feedback']?.toString() ?? '';
      final tip = map['tip']?.toString();
      if (feedback.isEmpty) return null;
      return (passed, feedback, tip?.trim().isEmpty == true ? null : tip);
    } catch (_) {
      return null;
    }
  }
}
