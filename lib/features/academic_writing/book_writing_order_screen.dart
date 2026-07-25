import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
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
  final Set<String> _selectedMilestones = {};
  DateTime _deadline = DateTime.now().add(const Duration(days: 14));
  bool _agreedToTerms = false;
  bool _isSubmitting = false;
  bool get _isThesisPackage =>
      widget.category.id == 'thesis' ||
      _academicLevel.contains('ماجستير') ||
      _academicLevel.contains('دكتوراه') ||
      _academicLevel.toLowerCase().contains('master') ||
      _academicLevel.toLowerCase().contains('phd');

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
      helpText: context.t('موعد التسليم المطلوب', 'Required delivery date'),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      _showMessage(
        context.t('يجب الموافقة على شروط الخدمة', 'You must agree to the service terms'),
        isError: true,
      );
      return;
    }

    if (!await ensureLoggedIn(context)) return;
    if (!mounted) return;

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final researcherFallback = context.t('باحث', 'Researcher');
      final profile = await AcademicProfileService.instance.loadProfile();

      final order = WritingOrder(
        userId: user.uid,
        userName: profile?.fullName ?? user.email ?? researcherFallback,
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
        milestones: _selectedMilestones.toList(),
        deadline: _deadline,
      );

      await WritingService.instance.createOrder(
        expert: widget.expert,
        order: order,
      );

      if (!mounted) return;
      _showMessage(
        context.t(
          'تم إرسال طلب الحجز — سيتواصل معك الكاتب قريباً',
          'Booking request sent — the writer will contact you soon',
        ),
      );
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
      appBar: AcadeGateAppBar(
        title: Text(context.t('حجز خدمة كتابة', 'Book writing service')),
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
            _sectionTitle(context.t('تفاصيل البحث', 'Research details')),
            TextFormField(
              controller: _topicController,
              textAlign: TextAlign.start,
              decoration: _input(context.t('عنوان البحث / الموضوع', 'Research title / topic')),
              validator: (v) => (v ?? '').trim().isEmpty
                  ? context.t('العنوان مطلوب', 'Title is required')
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _requirementsController,
              textAlign: TextAlign.start,
              maxLines: 4,
              decoration: _input(
                context.t(
                  'المتطلبات التفصيلية\n(الفصول، عدد المراجع، دليل الجامعة، ملفات...)',
                  'Detailed requirements\n(chapters, references, university guide, files...)',
                ),
              ),
              validator: (v) => (v ?? '').trim().length < 20
                  ? context.t(
                      'اكتب متطلبات أوضح (20 حرفاً+)',
                      'Write clearer requirements (20+ characters)',
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            _sectionTitle(context.t('خيارات أكاديمية', 'Academic options')),
            _dropdown(
              context.t('المستوى الأكاديمي', 'Academic level'),
              _academicLevel,
              academicLevels,
              localizedAcademicLevel,
              (v) => setState(() => _academicLevel = v!),
            ),
            _dropdown(
              context.t('نمط التوثيق', 'Citation style'),
              _citationStyle,
              citationStyles,
              localizedCitationStyle,
              (v) => setState(() => _citationStyle = v!),
            ),
            _dropdown(
              context.t('لغة الكتابة', 'Writing language'),
              _language,
              writingLanguages,
              localizedWritingLanguage,
              (v) => setState(() => _language = v!),
            ),
            _dropdown(
              context.t('الاستعجال', 'Urgency'),
              _urgency,
              urgencyLevels,
              localizedUrgencyLevel,
              (v) => setState(() => _urgency = v!),
            ),
            if (widget.category.id == 'statistics' ||
                widget.category.id == 'thesis' ||
                widget.category.id == 'research_paper')
              _dropdown(
                context.t('برنامج الإحصاء', 'Statistics software'),
                _statisticsTool,
                statisticsTools,
                localizedStatisticsTool,
                (v) => setState(() => _statisticsTool = v!),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _wordCountController,
              textAlign: TextAlign.start,
              keyboardType: TextInputType.number,
              decoration: _input(
                context.t('عدد الكلمات / الصفحات التقريبي', 'Approx. word / page count'),
              ),
              validator: (v) => (v ?? '').trim().isEmpty
                  ? context.t('حدّد حجم العمل', 'Specify work size')
                  : null,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.event, color: color),
              title: Text(context.t('موعد التسليم', 'Delivery date')),
              subtitle: Text(
                '${_deadline.year}/${_deadline.month}/${_deadline.day}',
              ),
              trailing: const Icon(Icons.edit_calendar),
              onTap: _pickDeadline,
            ),
            const SizedBox(height: 16),
            if (_isThesisPackage) ...[
              _sectionTitle(
                context.t('باقة مرحلية للرسالة', 'Thesis milestone package'),
              ),
              Text(
                context.t(
                  'اختر المراحل المطلوبة — يُسلَّم كل جزء على حدة ضمن الضمان الحالي',
                  'Pick stages — each part is delivered separately under current escrow',
                ),
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: thesisMilestones.map((stage) {
                  final selected = _selectedMilestones.contains(stage);
                  return FilterChip(
                    label: Text(
                      localizedThesisMilestone(stage),
                      style: const TextStyle(fontSize: 12),
                    ),
                    selected: selected,
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          _selectedMilestones.add(stage);
                        } else {
                          _selectedMilestones.remove(stage);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              if (_selectedMilestones.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    context.t(
                      '${_selectedMilestones.length} مراحل محددة',
                      '${_selectedMilestones.length} stages selected',
                    ),
                    style: TextStyle(fontSize: 12, color: color),
                  ),
                ),
              const SizedBox(height: 16),
            ],
            _sectionTitle(context.t('خدمات إضافية', 'Additional services')),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: writingAddons.map((addon) {
                final selected = _selectedAddons.contains(addon);
                return FilterChip(
                  label: Text(
                    localizedWritingAddon(addon),
                    style: const TextStyle(fontSize: 12),
                  ),
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
              title: Text(
                context.t(
                  'أوافق أن العمل يُنفّذ بشرياً وفق المتطلبات، '
                  'وأتحمل مسؤولية الالتزام بأخلاقيات البحث في جامعتي.',
                  'I agree the work is done by a human per my requirements, '
                  'and I accept responsibility for my university\'s research ethics.',
                ),
                style: const TextStyle(fontSize: 13),
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
                    : Text(context.t('إرسال طلب الحجز', 'Submit booking request')),
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
      child: Text(
        context.t(
          'سيتم مراجعة طلبك من الكاتب خلال 24 ساعة. '
          'التواصل المباشر بعد تأكيد الطلب.',
          'The writer will review your request within 24 hours. '
          'Direct contact after order confirmation.',
        ),
        style: const TextStyle(fontSize: 13, height: 1.4),
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
    String Function(String) displayLabel,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        key: ValueKey(value),
        initialValue: value,
        decoration: _input(label),
        items: items
            .map(
              (item) => DropdownMenuItem(
                value: item,
                child: Text(displayLabel(item)),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}
