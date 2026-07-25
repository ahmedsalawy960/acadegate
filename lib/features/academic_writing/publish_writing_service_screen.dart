import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/l10n_lookup.dart';
import '../../core/locale/locale_extensions.dart';
import '../auth/auth_guard.dart';
import 'writing_categories.dart';
import 'writing_models.dart';
import 'writing_service.dart';

class PublishWritingServiceScreen extends StatefulWidget {
  const PublishWritingServiceScreen({super.key});

  @override
  State<PublishWritingServiceScreen> createState() =>
      _PublishWritingServiceScreenState();
}

class _PublishWritingServiceScreenState
    extends State<PublishWritingServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _specialityController = TextEditingController();
  final _bioController = TextEditingController();
  final _priceController = TextEditingController();
  final _contactController = TextEditingController();
  final _portfolioController = TextEditingController();

  String _category = writingCategories.first.title;
  int _deliveryMin = 3;
  int _deliveryMax = 14;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _specialityController.dispose();
    _bioController.dispose();
    _priceController.dispose();
    _contactController.dispose();
    _portfolioController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!await ensureLoggedIn(context)) return;

    setState(() => _isSubmitting = true);

    try {
      final samples = _portfolioController.text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .take(8)
          .toList();

      await WritingService.instance.publishExpertProfile(
        expert: WritingExpert(
          name: _nameController.text.trim(),
          category: _category,
          speciality: _specialityController.text.trim(),
          bio: _bioController.text.trim(),
          priceRange: _priceController.text.trim(),
          deliveryDaysMin: _deliveryMin,
          deliveryDaysMax: _deliveryMax,
          contact: _contactController.text.trim(),
          portfolioSamples: samples,
        ),
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('التسجيل ككاتب أكاديمي', 'Register as academic writer')),
        backgroundColor: const Color(0xFF5D4037),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                context.t(
                  'يُراجع ملفك قبل الظهور للباحثين. '
                  'قدّم خبراتك الحقيقية ونماذج أعمالك عند التواصل.',
                  'Your profile is reviewed before researchers can see it. '
                  'Share your real experience and work samples when contacted.',
                ),
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              textAlign: TextAlign.start,
              decoration: _input(context.t('الاسم / الفريق', 'Name / team')),
              validator: (v) => (v ?? '').trim().isEmpty
                  ? context.t('الاسم مطلوب', 'Name is required')
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(_category),
              initialValue: _category,
              decoration: _input(context.t('نوع الخدمة', 'Service type')),
              items: writingCategories
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.title,
                      child: Text(L10nLookup.writingTitle(c.id)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _specialityController,
              textAlign: TextAlign.start,
              decoration: _input(
                context.t(
                  'التخصص (مثال: SPSS — رسائل علوم تطبيقية)',
                  'Speciality (e.g. SPSS — applied science theses)',
                ),
              ),
              validator: (v) => (v ?? '').trim().isEmpty
                  ? context.t('التخصص مطلوب', 'Speciality is required')
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bioController,
              textAlign: TextAlign.start,
              maxLines: 4,
              decoration: _input(context.t('نبذة عن خبرتك', 'About your experience')),
              validator: (v) => (v ?? '').trim().length < 30
                  ? context.t('اكتب نبذة أوضح', 'Write a clearer bio')
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _portfolioController,
              textAlign: TextAlign.start,
              maxLines: 4,
              decoration: _input(
                context.t(
                  'معرض أعمال (سطر لكل عينة — بدون أسماء طلاب)\n'
                  'مثال: مراجعة أدبيات في الطاقة المتجددة — ماجستير',
                  'Portfolio (one sample per line — no student names)\n'
                  'e.g. Literature review in renewable energy — Master\'s',
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceController,
              textAlign: TextAlign.start,
              decoration: _input(
                context.t(
                  'نطاق الأسعار (مثال: 800 – 3000 ج.م)',
                  'Price range (e.g. 800 – 3000 EGP)',
                ),
              ),
              validator: (v) => (v ?? '').trim().isEmpty
                  ? context.t('حدّد نطاق السعر', 'Set a price range')
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactController,
              textAlign: TextAlign.start,
              decoration: _input(
                context.t('البريد أو واتساب للتواصل', 'Email or WhatsApp for contact'),
              ),
              validator: (v) => (v ?? '').trim().isEmpty
                  ? context.t('وسيلة التواصل مطلوبة', 'Contact method is required')
                  : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: ValueKey(_deliveryMin),
                    initialValue: _deliveryMin,
                    decoration: _input(context.t('أقل مدة (يوم)', 'Min duration (days)')),
                    items: List.generate(
                      30,
                      (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
                    ),
                    onChanged: (v) => setState(() => _deliveryMin = v ?? 3),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: ValueKey(_deliveryMax),
                    initialValue: _deliveryMax,
                    decoration: _input(context.t('أقصى مدة (يوم)', 'Max duration (days)')),
                    items: List.generate(
                      60,
                      (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
                    ),
                    onChanged: (v) => setState(() => _deliveryMax = v ?? 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF5D4037),
                  foregroundColor: Colors.white,
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(context.t('إرسال للمراجعة', 'Submit for review')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _input(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
