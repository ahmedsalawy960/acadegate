import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth/auth_guard.dart';
import '../profile/academic_profile_service.dart';
import 'writing_categories.dart';
import 'writing_models.dart';
import 'writing_service.dart';

class BookWritingOrderScreen extends StatefulWidget {
  final WritingExpert expert;
  final WritingCategory category;

  const BookWritingOrderScreen({
    super.key,
    required this.expert,
    required this.category,
  });

  @override
  State<BookWritingOrderScreen> createState() => _BookWritingOrderScreenState();
}

class _BookWritingOrderScreenState extends State<BookWritingOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _topicController = TextEditingController();
  final _requirementsController = TextEditingController();
  final _wordCountController = TextEditingController();

  String _academicLevel = academicLevels.first;
  String _citationStyle = citationStyles.first;
  String _language = writingLanguages.first;
  String _urgency = urgencyLevels.first;
  String _statisticsTool = statisticsTools.last;
  final Set<String> _selectedAddons = {};
  DateTime _deadline = DateTime.now().add(const Duration(days: 14));
  bool _agreedToTerms = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _topicController.dispose();
    _requirementsController.dispose();
    _wordCountController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 180)),
      helpText: 'موعد التسليم المطلوب',
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      _showMessage('يجب الموافقة على شروط الخدمة', isError: true);
      return;
    }

    if (!await ensureLoggedIn(context)) return;

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final profile = await AcademicProfileService.instance.loadProfile();

      final order = WritingOrder(
        userId: user.uid,
        userName: profile?.fullName ?? user.email ?? 'باحث',
        expertName: widget.expert.name,
        category: widget.category.title,
        topic: _topicController.text.trim(),
        requirements: _requirementsController.text.trim(),
        academicLevel: _academicLevel,
        citationStyle: _citationStyle,
        language: _language,
        urgency: _urgency,
        wordCount: _wordCountController.text.trim(),
        statisticsTool: _statisticsTool,
        addons: _selectedAddons.toList(),
        deadline: _deadline,
      );

      await WritingService.instance.createOrder(
        expert: widget.expert,
        order: order,
      );

      if (!mounted) return;
      _showMessage('تم إرسال طلب الحجز — سيتواصل معك الكاتب قريباً');
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expert = widget.expert;
    final color = widget.category.color;

    return Scaffold(
      appBar: AppBar(
        title: const Text('حجز خدمة كتابة'),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              expert.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(expert.speciality, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            _infoBanner(color),
            const SizedBox(height: 16),
            _sectionTitle('تفاصيل البحث'),
            TextFormField(
              controller: _topicController,
              textAlign: TextAlign.right,
              decoration: _input('عنوان البحث / الموضوع'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'العنوان مطلوب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _requirementsController,
              textAlign: TextAlign.right,
              maxLines: 4,
              decoration: _input(
                'المتطلبات التفصيلية\n(الفصول، عدد المراجع، دليل الجامعة، ملفات...)',
              ),
              validator: (v) =>
                  (v ?? '').trim().length < 20 ? 'اكتب متطلبات أوضح (20 حرفاً+)' : null,
            ),
            const SizedBox(height: 16),
            _sectionTitle('خيارات أكاديمية'),
            _dropdown('المستوى الأكاديمي', _academicLevel, academicLevels, (v) {
              setState(() => _academicLevel = v!);
            }),
            _dropdown('نمط التوثيق', _citationStyle, citationStyles, (v) {
              setState(() => _citationStyle = v!);
            }),
            _dropdown('لغة الكتابة', _language, writingLanguages, (v) {
              setState(() => _language = v!);
            }),
            _dropdown('الاستعجال', _urgency, urgencyLevels, (v) {
              setState(() => _urgency = v!);
            }),
            if (widget.category.id == 'statistics' ||
                widget.category.id == 'thesis' ||
                widget.category.id == 'research_paper')
              _dropdown('برنامج الإحصاء', _statisticsTool, statisticsTools, (v) {
                setState(() => _statisticsTool = v!);
              }),
            const SizedBox(height: 12),
            TextFormField(
              controller: _wordCountController,
              textAlign: TextAlign.right,
              keyboardType: TextInputType.number,
              decoration: _input('عدد الكلمات / الصفحات التقريبي'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'حدّد حجم العمل' : null,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.event, color: color),
              title: const Text('موعد التسليم'),
              subtitle: Text(
                '${_deadline.year}/${_deadline.month}/${_deadline.day}',
              ),
              trailing: const Icon(Icons.edit_calendar),
              onTap: _pickDeadline,
            ),
            const SizedBox(height: 16),
            _sectionTitle('خدمات إضافية'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: writingAddons.map((addon) {
                final selected = _selectedAddons.contains(addon);
                return FilterChip(
                  label: Text(addon, style: const TextStyle(fontSize: 12)),
                  selected: selected,
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        _selectedAddons.add(addon);
                      } else {
                        _selectedAddons.remove(addon);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _agreedToTerms,
              onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
              title: const Text(
                'أوافق أن العمل يُنفّذ بشرياً وفق المتطلبات، '
                'وأتحمل مسؤولية الالتزام بأخلاقيات البحث في جامعتي.',
                style: TextStyle(fontSize: 13),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('إرسال طلب الحجز'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBanner(Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: const Text(
        'سيتم مراجعة طلبك من الكاتب خلال 24 ساعة. '
        'التواصل المباشر بعد تأكيد الطلب.',
        style: TextStyle(fontSize: 13, height: 1.4),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  InputDecoration _input(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        key: ValueKey(value),
        initialValue: value,
        decoration: _input(label),
        items: items
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}
