import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/locale/app_translate.dart';
import '../../../core/locale/locale_extensions.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/widgets/acadegate_app_bar.dart';
import '../../ai_advisor/advisor_attachment.dart';
import '../../ai_advisor/advisor_attachment_service.dart';
import '../../ai_advisor/gemini_advisor_client.dart';
import '../../auth/auth_guard.dart';
import '../store_catalog_service.dart';
import '../store_product_navigation.dart';
import '../store_theme.dart';
import 'store_custom_fit_ai_service.dart';
import 'store_custom_fit_models.dart';
import 'store_custom_fit_service.dart';
import 'store_product_discover_screen.dart';

/// أداة التوافق المخصص: رسم/مواصفات → مطابقة كتالوج → موجز تصنيع رقمي.
class StoreCustomFitScreen extends StatefulWidget {
  const StoreCustomFitScreen({super.key});

  @override
  State<StoreCustomFitScreen> createState() => _StoreCustomFitScreenState();
}

class _StoreCustomFitScreenState extends State<StoreCustomFitScreen> {
  final _titleCtrl = TextEditingController();
  final _specsCtrl = TextEditingController();

  PendingAdvisorAttachment? _diagram;
  String? _diagramPreviewUrl;
  bool _analyzing = false;
  bool _submitting = false;
  CustomFitAnalysisResult? _result;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _specsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDiagram() async {
    try {
      final pending = await AdvisorAttachmentService.instance.pickImage();
      if (pending == null) return;
      setState(() {
        _diagram = pending;
        _diagramPreviewUrl = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _analyze() async {
    final loggedIn = await ensureLoggedIn(context);
    if (!loggedIn || !mounted) return;

    setState(() {
      _analyzing = true;
      _error = null;
      _result = null;
    });

    try {
      final catalog = await StoreCatalogService.instance.loadPublicCatalog();
      List<GeminiInlinePart> parts = const [];
      if (_diagram != null) {
        final normalized =
            AdvisorAttachmentService.instance.normalizeImageForGemini(_diagram!);
        _diagram = normalized;
        parts = await AdvisorAttachmentService.instance.prepareGeminiParts(
          [normalized],
          conversationId: 'custom_fit',
          preferStorage: true,
        );
        if (_diagramPreviewUrl == null || _diagramPreviewUrl!.isEmpty) {
          _diagramPreviewUrl = await _uploadPendingDiagram(normalized);
        }
      }

      final analysis = await StoreCustomFitAiService.instance.analyze(
        specsText: _specsCtrl.text,
        catalog: catalog.products,
        diagramParts: parts,
        experimentTitle: _titleCtrl.text,
      );

      if (!mounted) return;
      setState(() {
        _result = analysis;
        _error = analysis.hasError ? analysis.error : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<String?> _uploadPendingDiagram(PendingAdvisorAttachment pending) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    try {
      final uploaded = await AdvisorAttachmentService.instance.uploadAll(
        pending: [pending],
        conversationId: 'custom_fit',
      );
      if (uploaded.isEmpty) return null;
      return uploaded.first.url;
    } catch (_) {
      return null;
    }
  }

  /// يجهّز نص البحث من الوصف المكتوب، أو من نتيجة التحليل، أو من الصورة وحدها.
  Future<String?> _resolveDiscoverQuery() async {
    final typed = [
      _titleCtrl.text.trim(),
      _specsCtrl.text.trim(),
    ].where((e) => e.isNotEmpty).join('\n');
    if (typed.trim().length >= 8) return typed.trim();

    final analysis = _result;
    if (analysis != null) {
      final fromAnalysis = [
        analysis.requirements.summaryAr,
        analysis.requirements.summaryEn,
        ...analysis.requirements.criticalSpecs,
        ...analysis.requirements.keywords,
      ].where((e) => e.trim().isNotEmpty).join('\n');
      if (fromAnalysis.trim().length >= 8) return fromAnalysis.trim();
    }

    if (_diagram == null) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'ارفع صورة/رسماً أو اكتب وصفاً للبحث.',
              'Upload a diagram/image or type a description to search.',
            ),
          ),
        ),
      );
      return null;
    }

    if (!GeminiAdvisorClient.isAvailable) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'البحث بالصورة وحدها يحتاج تسجيل دخول (AI). أو اكتب وصفاً قصيراً.',
              'Image-only search needs sign-in (AI). Or type a short description.',
            ),
          ),
        ),
      );
      return null;
    }

    PendingAdvisorAttachment diagram;
    try {
      diagram =
          AdvisorAttachmentService.instance.normalizeImageForGemini(_diagram!);
      _diagram = diagram;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
      return null;
    }

    final parts = await AdvisorAttachmentService.instance.prepareGeminiParts(
      [diagram],
      conversationId: 'custom_fit',
      preferStorage: true,
    );
    final extracted =
        await StoreCustomFitAiService.instance.extractSearchQueryFromDiagram(
      diagramParts: parts,
      experimentTitle: _titleCtrl.text,
    );
    if (!extracted.isSuccess) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            extracted.error ??
                context.t(
                  'تعذر تحليل الصورة. إن استمر الخطأ: احفظها JPG، أو أضف وصفاً قصيراً، أو تحقق من رصيد Gemini.',
                  'Could not analyze the image. Save as JPG, add a short description, or check Gemini quota.',
                ),
          ),
          duration: const Duration(seconds: 8),
        ),
      );
      return null;
    }
    return extracted.text!.trim();
  }

  Future<void> _openDiscover() async {
    final loggedIn = await ensureLoggedIn(context);
    if (!loggedIn || !mounted) return;

    setState(() => _analyzing = true);
    try {
      final query = await _resolveDiscoverQuery();
      if (query == null || !mounted) return;
      // إن كان البحث من الصورة فقط، اعرض النص المستخرج في حقل المواصفات
      if (_specsCtrl.text.trim().length < 8) {
        _specsCtrl.text = query;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StoreProductDiscoverScreen(initialQuery: query),
        ),
      );
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<void> _requestFabrication({CustomFitMatchItem? related}) async {
    final result = _result;
    if (result == null) return;

    final loggedIn = await ensureLoggedIn(context);
    if (!loggedIn || !mounted) return;

    setState(() => _submitting = true);
    try {
      String? diagramUrl = _diagramPreviewUrl;
      if (diagramUrl == null && _diagram != null) {
        diagramUrl = await _uploadPendingDiagram(_diagram!);
      }

      final sellerId = related?.product?.createdBy ?? '';
      // RFQ rules: productId only when seller matches product owner
      final productId = (sellerId.isNotEmpty && related != null)
          ? related.productId
          : null;

      await StoreCustomFitService.instance.submitFabricationRequest(
        title: _titleCtrl.text.trim().isEmpty
            ? appTr('طلب توافق مخصص', 'Custom fit request')
            : _titleCtrl.text.trim(),
        specsText: _specsCtrl.text.trim(),
        diagramUrl: diagramUrl,
        analysis: result,
        sellerId: sellerId,
        relatedProductId: productId,
        relatedProductName: related?.productName ?? '',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'تم إرسال طلب التصنيع/التعديل للموردين.',
              'Fabrication/modification request sent to suppliers.',
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _openProduct(CustomFitMatchItem item) {
    final p = item.product;
    if (p == null) return;
    openStoreProductDetail(context, p);
  }

  @override
  Widget build(BuildContext context) {
    final isAr = !LocaleService.instance.isEnglish;
    final aiReady = GeminiAdvisorClient.isAvailable;

    return Theme(
      data: StoreTheme.overlay(context),
      child: Scaffold(
        appBar: AcadeGateAppBar(
          title: Text(
            context.t('توافق مخصص للتجربة', 'Custom experiment fit'),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _IntroCard(aiReady: aiReady),
            const SizedBox(height: 14),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: context.t(
                  'عنوان التجربة / الجهاز (اختياري)',
                  'Experiment / instrument title (optional)',
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _specsCtrl,
              minLines: 5,
              maxLines: 12,
              decoration: InputDecoration(
                labelText: context.t(
                  'المواصفات الدقيقة',
                  'Precise specifications',
                ),
                hintText: context.t(
                  'مثال: مرشح 0.22µm متوافق مع حامل سيلنجر، ضغط تشغيل حتى 4 bar، مادة PTFE، أو مواصفات حامل لعينة SEM…',
                  'e.g. 0.22µm filter for syringe holder, up to 4 bar, PTFE; or SEM sample holder dimensions…',
                ),
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _analyzing ? null : _pickDiagram,
              icon: const Icon(Icons.image_outlined),
              label: Text(
                _diagram == null
                    ? context.t(
                        'رفع رسم بياني / مخطط قطعة',
                        'Upload diagram / part schematic',
                      )
                    : context.t(
                        'تم اختيار: ${_diagram!.name}',
                        'Selected: ${_diagram!.name}',
                      ),
              ),
            ),
            if (_diagram != null) ...[
              const SizedBox(height: 6),
              TextButton(
                onPressed: _analyzing
                    ? null
                    : () => setState(() {
                          _diagram = null;
                          _diagramPreviewUrl = null;
                        }),
                child: Text(context.t('إزالة الرسم', 'Remove diagram')),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _analyzing ? null : _analyze,
              style: FilledButton.styleFrom(
                backgroundColor: StoreTheme.accent,
                minimumSize: const Size.fromHeight(48),
              ),
              icon: _analyzing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                _analyzing
                    ? context.t('جارٍ التحليل…', 'Analyzing…')
                    : context.t(
                        'تحليل المطابقة والتصنيع',
                        'Analyze fit & fabrication',
                      ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _analyzing ? null : _openDiscover,
              icon: const Icon(Icons.travel_explore),
              label: Text(
                context.t(
                  'امسح المتاجر والإنترنت (وصف أو صورة)',
                  'Scan stores & web (text or image)',
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.t(
                'يمكنك رفع رسم فقط بدون كتابة — يُستخرج الوصف من الصورة ثم يُبحث في المتجر والنت.',
                'You can upload a diagram alone — we extract the description from the image, then search the store and web.',
              ),
              style: const TextStyle(
                fontSize: 11.5,
                color: StoreTheme.muted,
                height: 1.35,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: StoreTheme.danger)),
            ],
            if (_result != null) ...[
              const SizedBox(height: 20),
              _ResultSection(
                result: _result!,
                isAr: isAr,
                submitting: _submitting,
                onOpenProduct: _openProduct,
                onRequestFabrication: (m) => _requestFabrication(related: m),
                onRequestOpenFabrication: () => _requestFabrication(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  final bool aiReady;
  const _IntroCard({required this.aiReady});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StoreTheme.accentSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: StoreTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t(
              'توافُق 100٪ قبل الشحن — هدف المنصة',
              '100% fit before shipping — platform goal',
            ),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: StoreTheme.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.t(
              'ارفع رسماً فقط أو اكتب مواصفات تجربتك (ضغط، حرارة، واجهة جهاز…). '
              'من الصورة نستخرج الوصف ثم نمسح الكتالوج والمتاجر والنت، ونولّد موجز تصنيع عند الحاجة.',
              'Upload a diagram alone or type specs (pressure, temperature, instrument interface…). '
              'From the image we extract a description, then scan the catalog, stores & web, and generate a fabrication brief when needed.',
            ),
            style: const TextStyle(
              color: StoreTheme.muted,
              height: 1.45,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            aiReady
                ? context.t(
                    'الذكاء الاصطناعي جاهز للتحليل.',
                    'AI analysis is ready.',
                  )
                : context.t(
                    'سجّل الدخول لاستخدام التحليل بالذكاء الاصطناعي (أو فعّل مفتاح Gemini محلياً).',
                    'Sign in for AI analysis (or enable a local Gemini key).',
                  ),
            style: TextStyle(
              fontSize: 12,
              color: aiReady ? StoreTheme.verified : StoreTheme.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultSection extends StatelessWidget {
  final CustomFitAnalysisResult result;
  final bool isAr;
  final bool submitting;
  final ValueChanged<CustomFitMatchItem> onOpenProduct;
  final ValueChanged<CustomFitMatchItem> onRequestFabrication;
  final VoidCallback onRequestOpenFabrication;

  const _ResultSection({
    required this.result,
    required this.isAr,
    required this.submitting,
    required this.onOpenProduct,
    required this.onRequestFabrication,
    required this.onRequestOpenFabrication,
  });

  @override
  Widget build(BuildContext context) {
    final req = result.requirements;
    final summary = isAr
        ? (req.summaryAr.isNotEmpty ? req.summaryAr : req.summaryEn)
        : (req.summaryEn.isNotEmpty ? req.summaryEn : req.summaryAr);
    final note = isAr ? result.confidenceNoteAr : result.confidenceNoteEn;
    final fab = result.fabrication;
    final ask = isAr
        ? (fab.supplierAskAr.isNotEmpty ? fab.supplierAskAr : fab.supplierAskEn)
        : (fab.supplierAskEn.isNotEmpty ? fab.supplierAskEn : fab.supplierAskAr);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('نتيجة التحليل', 'Analysis result'),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        if (result.fromAi)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              context.t(
                'مصدر: AcadeGate AI${result.modelUsed != null ? ' · ${result.modelUsed}' : ''}',
                'Source: AcadeGate AI${result.modelUsed != null ? ' · ${result.modelUsed}' : ''}',
              ),
              style: const TextStyle(fontSize: 12, color: StoreTheme.muted),
            ),
          ),
        if (note.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(note, style: const TextStyle(fontSize: 12.5, height: 1.4)),
        ],
        if (summary.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            context.t('المتطلبات المستخرجة', 'Extracted requirements'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(summary, style: const TextStyle(height: 1.4)),
        ],
        if (req.criticalSpecs.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...req.criticalSpecs.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• '),
                  Expanded(child: Text(s)),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          context.t('منتجات متوافقة من الكتالوج', 'Compatible catalog products'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 8),
        if (result.matches.isEmpty)
          Text(
            context.t(
              'لا يوجد تطابق كافٍ في المخزون الحالي — اطلب تصنيعاً مخصصاً.',
              'No strong catalog match — request custom fabrication.',
            ),
          )
        else
          ...result.matches.map((m) {
            final why = isAr
                ? (m.whyAr.isNotEmpty ? m.whyAr : m.whyEn)
                : (m.whyEn.isNotEmpty ? m.whyEn : m.whyAr);
            final gap = isAr
                ? (m.gapAr.isNotEmpty ? m.gapAr : m.gapEn)
                : (m.gapEn.isNotEmpty ? m.gapEn : m.gapAr);
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => onOpenProduct(m),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              m.productName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: m.matchPercent >= 85
                                  ? const Color(0xFFDCFCE7)
                                  : StoreTheme.accentSoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${m.matchPercent}%',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: m.matchPercent >= 85
                                    ? StoreTheme.verified
                                    : StoreTheme.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (why.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(why, style: const TextStyle(fontSize: 13)),
                      ],
                      if (gap.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          gap,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: StoreTheme.muted,
                          ),
                        ),
                      ],
                      if (m.matchPercent < 90) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: submitting
                              ? null
                              : () => onRequestFabrication(m),
                          icon: const Icon(Icons.precision_manufacturing_outlined,
                              size: 18),
                          label: Text(
                            context.t(
                              'عدّل/صنّع لتلائم 100٪',
                              'Modify/fabricate for full fit',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        if (result.needsCustomFabrication || !fab.isEmpty) ...[
          const SizedBox(height: 8),
          Text(
            context.t('موجز التصنيع الرقمي', 'Digital fabrication brief'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: StoreTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: StoreTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (fab.processHint.isNotEmpty)
                  _kv(context.t('العملية', 'Process'), fab.processHint),
                if (fab.materialHint.isNotEmpty)
                  _kv(context.t('المادة', 'Material'), fab.materialHint),
                if (fab.dimensionsSummary.isNotEmpty)
                  _kv(context.t('الأبعاد', 'Dimensions'), fab.dimensionsSummary),
                if (fab.tolerances.isNotEmpty)
                  _kv(context.t('التحمّلات', 'Tolerances'), fab.tolerances),
                if (ask.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    ask,
                    style: const TextStyle(height: 1.4, fontSize: 13),
                  ),
                ],
                if (fab.checklist.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...fab.checklist.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text('✓ $c', style: const TextStyle(fontSize: 12.5)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: submitting ? null : onRequestOpenFabrication,
          style: FilledButton.styleFrom(
            backgroundColor: StoreTheme.ink,
            minimumSize: const Size.fromHeight(48),
          ),
          icon: submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send_outlined),
          label: Text(
            context.t(
              'أرسل طلب تصنيع مخصص للموردين',
              'Send custom fabrication request',
            ),
          ),
        ),
      ],
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: StoreTheme.ink, fontSize: 13, height: 1.35),
          children: [
            TextSpan(
              text: '$k: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: v),
          ],
        ),
      ),
    );
  }
}
