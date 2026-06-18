import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../auth/auth_guard.dart';
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
  final List<_EquipmentDraft> _equipment = [_EquipmentDraft()];

  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _cityController.dispose();
    _universityController.dispose();
    _tagsController.dispose();
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
        'waitDays': equipmentList
            .map((item) => item['waitDays'] as int)
            .reduce((a, b) => a < b ? a : b),
        'ownerId': user.uid,
        'approvalStatus': ApprovalStatus.pending,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _showMessage('تم إرسال المختبر للمراجعة — سيظهر بعد الموافقة');
      Navigator.pop(context, true);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      _showMessage(e.message ?? e.code, isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل مختبر'),
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
                'أضف بيانات المختبر والأجهزة والأسعار. يُراجع الطلب قبل النشر.',
              ),
              const SizedBox(height: 16),
              const Text(
                'بيانات المختبر',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم المختبر *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'اسم المختبر مطلوب' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'الموقع التفصيلي *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'الموقع مطلوب' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'المدينة *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'المدينة مطلوبة' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _universityController,
                decoration: const InputDecoration(
                  labelText: 'الجامعة *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'الجامعة مطلوبة' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'الوسوم (مفصولة بفاصلة)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'الأجهزة والتحاليل',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addEquipment,
                    icon: const Icon(Icons.add),
                    label: const Text('جهاز'),
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
                    _isSaving ? 'جارٍ الإرسال...' : 'إرسال للمراجعة',
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
                  'جهاز ${index + 1}',
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
              decoration: const InputDecoration(
                labelText: 'اسم الجهاز / التحليل *',
                hintText: 'مجهر إلكتروني SEM',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'اسم الجهاز مطلوب' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: draft.code,
              decoration: const InputDecoration(
                labelText: 'الرمز (اختياري)',
                hintText: 'SEM',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: draft.cost,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'السعر (ج.م) *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if ((v ?? '').trim().isEmpty) return 'السعر مطلوب';
                      if (num.tryParse(v!.trim()) == null) {
                        return 'أدخل رقماً';
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
                    decoration: const InputDecoration(
                      labelText: 'أيام الانتظار',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: draft.storeCategoryTitle,
              decoration: const InputDecoration(
                labelText: 'متجر المواد المرتبط',
                border: OutlineInputBorder(),
              ),
              items: storeCategories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category.title,
                      child: Text(category.title),
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
