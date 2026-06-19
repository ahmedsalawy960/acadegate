import 'package:flutter/material.dart';

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
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!await ensureLoggedIn(context)) return;

    setState(() => _isSubmitting = true);

    try {
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
      appBar: AppBar(
        title: const Text('التسجيل ككاتب أكاديمي'),
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
              child: const Text(
                'يُراجع ملفك قبل الظهور للباحثين. '
                'قدّم خبراتك الحقيقية ونماذج أعمالك عند التواصل.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              textAlign: TextAlign.right,
              decoration: _input('الاسم / الفريق'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'الاسم مطلوب' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(_category),
              initialValue: _category,
              decoration: _input('نوع الخدمة'),
              items: writingCategories
                  .map(
                    (c) => DropdownMenuItem(value: c.title, child: Text(c.title)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _specialityController,
              textAlign: TextAlign.right,
              decoration: _input('التخصص (مثال: SPSS — رسائل علوم تطبيقية)'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'التخصص مطلوب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bioController,
              textAlign: TextAlign.right,
              maxLines: 4,
              decoration: _input('نبذة عن خبرتك'),
              validator: (v) =>
                  (v ?? '').trim().length < 30 ? 'اكتب نبذة أوضح' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceController,
              textAlign: TextAlign.right,
              decoration: _input('نطاق الأسعار (مثال: 800 – 3000 ج.م)'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'حدّد نطاق السعر' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactController,
              textAlign: TextAlign.right,
              decoration: _input('البريد أو واتساب للتواصل'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'وسيلة التواصل مطلوبة' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: ValueKey(_deliveryMin),
                    initialValue: _deliveryMin,
                    decoration: _input('أقل مدة (يوم)'),
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
                    decoration: _input('أقصى مدة (يوم)'),
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
                    : const Text('إرسال للمراجعة'),
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
