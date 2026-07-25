import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import '../../core/locale/app_translate.dart';
import '../../core/locale/l10n_lookup.dart';
import '../../core/locale/locale_extensions.dart';
import '../academic/faculty_categories.dart';
import '../auth/auth_guard.dart';
import '../academic/academic_models.dart';
import '../moderation/approval_status.dart';
import '../store/store_categories.dart';

class _EquipmentDraft {
  final TextEditingController name = TextEditingController();
  final TextEditingController code = TextEditingController();
  final TextEditingController cost = TextEditingController();
  final TextEditingController waitDays = TextEditingController(text: '3');
  String storeCategoryTitle = storeCategories.first.title;

  void dispose() {
    name.dispose();
    code.dispose();
    cost.dispose();
    waitDays.dispose();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': code.text.trim().isNotEmpty
          ? code.text.trim().toLowerCase()
          : name.text.trim().toLowerCase().replaceAll(' ', '-'),
      'name': name.text.trim(),
      'code': code.text.trim(),
      'costPerSession': num.tryParse(cost.text.trim()) ?? 0,
      'durationMinutes': 120,
      'waitDays': int.tryParse(waitDays.text.trim()) ?? 3,
      'storeCategoryTitle': storeCategoryTitle,
    };
  }
}

class SubmitLabScreen extends StatefulWidget {
  const SubmitLabScreen({super.key});

  @override
  State<SubmitLabScreen> createState() => _SubmitLabScreenState();
}

class _SubmitLabScreenState extends State<SubmitLabScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _cityController = TextEditingController();
  final _universityController = TextEditingController();
  final _tagsController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sampleServicesController = TextEditingController();
  final List<_EquipmentDraft> _equipment = [_EquipmentDraft()];

  String _labType = 'university_lab';
  String _category = facultyCategoryIds().first;
  bool _acceptsExternalSamples = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _cityController.dispose();
    _universityController.dispose();
    _tagsController.dispose();
    _descriptionController.dispose();
    _sampleServicesController.dispose();
    for (final item in _equipment) {
      item.dispose();
    }
    super.dispose();
  }

  void _addEquipment() {
    setState(() => _equipment.add(_EquipmentDraft()));
  }

  void _removeEquipment(int index) {
    if (_equipment.length == 1) return;
    setState(() {
      _equipment.removeAt(index).dispose();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final loggedIn = await ensureLoggedIn(context);
    if (!loggedIn || !mounted) return;

    final user = FirebaseAuth.instance.currentUser!;
    final equipmentList = _equipment.map((item) => item.toMap()).toList();
    final mainEquipment = equipmentList.map((e) => e['name']).join('، ');

    setState(() => _isSaving = true);

    try {
      final tags = _tagsController.text
          .split(RegExp(r'[،,]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();

      await FirebaseFirestore.instance.collection('labs').add({
        'name': _nameController.text.trim(),
        'location': _locationController.text.trim(),
        'city': _cityController.text.trim(),
        'university': _universityController.text.trim(),
        'equipment': mainEquipment,
        'equipmentList': equipmentList,
        'tags': tags,
        'labType': _labType,
        'facultyId': _category,
        'facultyNameAr': facultyTitleForCategory(_category),
        'category': _category,
        'description': _descriptionController.text.trim(),
        'acceptsExternalSamples': _acceptsExternalSamples,
        'sampleServices': _parseSampleServices(),
        'waitDays': equipmentList
            .map((item) => item['waitDays'] as int)
            .reduce((a, b) => a < b ? a : b),
        'ownerId': user.uid,
        'approvalStatus': ApprovalStatus.pending,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _showMessage(
        context.t(
          'تم إرسال المختبر للمراجعة — سيظهر بعد الموافقة',
          'Lab sent for review — it will appear after approval',
        ),
      );
      Navigator.pop(context, true);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      _showMessage(e.message ?? e.code, isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  List<Map<String, dynamic>> _parseSampleServices() {
    return _sampleServicesController.text
        .split(RegExp(r'[،,\n]'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .map(
          (name) => SampleAnalysisService(
            id: name.toLowerCase().replaceAll(' ', '-'),
            name: name,
            specialties: [_category],
          ).toMap(),
        )
        .toList();
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
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('تسجيل مختبر', 'Register lab')),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoBanner(
                context.t(
                  'اربط المختبر بالكلية — عند البحث عن الكلية ستظهر المختبرات المرتبطة بها تلقائياً.',
                  'Link the lab to a faculty — linked labs appear automatically when searching by faculty.',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.t('بيانات المختبر', 'Lab details'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: context.t('اسم المختبر *', 'Lab name *'),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? context.t('اسم المختبر مطلوب', 'Lab name is required')
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: context.t('الموقع التفصيلي *', 'Detailed location *'),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? context.t('الموقع مطلوب', 'Location is required')
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cityController,
                decoration: InputDecoration(
                  labelText: context.t('المدينة *', 'City *'),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? context.t('المدينة مطلوبة', 'City is required')
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _universityController,
                decoration: InputDecoration(
                  labelText: context.t('الجامعة *', 'University *'),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? context.t('الجامعة مطلوبة', 'University is required')
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(_labType),
                initialValue: _labType,
                decoration: InputDecoration(
                  labelText: context.t('نوع المنشأة', 'Facility type'),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'university_lab',
                    child: Text(context.t('مختبر جامعي', 'University lab')),
                  ),
                  DropdownMenuItem(
                    value: 'research_center',
                    child: Text(context.t('مركز بحوث', 'Research center')),
                  ),
                  DropdownMenuItem(
                    value: 'core_facility',
                    child: Text(
                      context.t(
                        'منشأة تحليل مركزية',
                        'Core analysis facility',
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _labType = value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(_category),
                initialValue: _category,
                decoration: InputDecoration(
                  labelText: context.t('الكلية *', 'Faculty *'),
                  helperText: context.t(
                    'يُستخدم لربط المختبر بالكلية في البحث',
                    'Used to link the lab to a faculty in search',
                  ),
                  border: const OutlineInputBorder(),
                ),
                items: facultyCategoryIds()
                    .map(
                      (id) => DropdownMenuItem(
                        value: id,
                        child: Text(L10nLookup.facultyTitleStatic(id)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: context.t(
                    'وصف المختبر / الخدمات',
                    'Lab / services description',
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sampleServicesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: context.t(
                    'خدمات تحليل العينات (افصل بفاصلة)',
                    'Sample analysis services (comma-separated)',
                  ),
                  hintText: context.t(
                    'SEM, XRD, HPLC, تحليل تربة',
                    'SEM, XRD, HPLC, soil analysis',
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  context.t(
                    'يقبل عينات من خارج الجامعة',
                    'Accepts samples from outside the university',
                  ),
                ),
                value: _acceptsExternalSamples,
                onChanged: (value) =>
                    setState(() => _acceptsExternalSamples = value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tagsController,
                decoration: InputDecoration(
                  labelText: context.t(
                    'الوسوم (مفصولة بفاصلة)',
                    'Tags (comma-separated)',
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.t('الأجهزة والتحاليل', 'Equipment & analyses'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addEquipment,
                    icon: const Icon(Icons.add),
                    label: Text(context.t('جهاز', 'Device')),
                  ),
                ],
              ),
              ...List.generate(_equipment.length, (index) {
                final item = _equipment[index];
                return _EquipmentCard(
                  index: index,
                  draft: item,
                  canRemove: _equipment.length > 1,
                  onRemove: () => _removeEquipment(index),
                  onCategoryChanged: (value) {
                    setState(() => item.storeCategoryTitle = value);
                  },
                );
              }),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[700],
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.send_outlined),
                  label: Text(
                    _isSaving
                        ? context.t('جارٍ الإرسال...', 'Submitting...')
                        : context.t('إرسال للمراجعة', 'Submit for review'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoBanner(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.purple[800], size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _EquipmentCard extends StatelessWidget {
  final int index;
  final _EquipmentDraft draft;
  final bool canRemove;
  final VoidCallback onRemove;
  final ValueChanged<String> onCategoryChanged;

  const _EquipmentCard({
    required this.index,
    required this.draft,
    required this.canRemove,
    required this.onRemove,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  context.t('جهاز ${index + 1}', 'Device ${index + 1}'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (canRemove)
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
              ],
            ),
            TextFormField(
              controller: draft.name,
              decoration: InputDecoration(
                labelText: context.t(
                  'اسم الجهاز / التحليل *',
                  'Device / analysis name *',
                ),
                hintText: context.t(
                  'مجهر إلكتروني SEM',
                  'SEM electron microscope',
                ),
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v ?? '').trim().isEmpty
                  ? context.t('اسم الجهاز مطلوب', 'Device name is required')
                  : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: draft.code,
              decoration: InputDecoration(
                labelText: context.t('الرمز (اختياري)', 'Code (optional)'),
                hintText: 'SEM',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: draft.cost,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.t('السعر (ج.م) *', 'Price (EGP) *'),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if ((v ?? '').trim().isEmpty) {
                        return context.t('السعر مطلوب', 'Price is required');
                      }
                      if (num.tryParse(v!.trim()) == null) {
                        return context.t('أدخل رقماً', 'Enter a number');
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: draft.waitDays,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.t('أيام الانتظار', 'Wait days'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: draft.storeCategoryTitle,
              decoration: InputDecoration(
                labelText: context.t(
                  'متجر المواد المرتبط',
                  'Linked supplies store',
                ),
                border: const OutlineInputBorder(),
              ),
              items: storeCategories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category.title,
                      child: Text(L10nLookup.storeCategoryTitle(category.id)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) onCategoryChanged(value);
              },
            ),
          ],
        ),
      ),
    );
  }
}
