import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../auth/auth_guard.dart';
import '../academic/faculty_categories.dart';
import '../academic/verification_status.dart';
import '../../core/storage/storage_service.dart';
import '../moderation/approval_status.dart';

class SubmitSupervisorScreen extends StatefulWidget {
  final String? initialCategory;

  const SubmitSupervisorScreen({super.key, this.initialCategory});

  @override
  State<SubmitSupervisorScreen> createState() => _SubmitSupervisorScreenState();
}

class _SubmitSupervisorScreenState extends State<SubmitSupervisorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _universityController = TextEditingController();
  final _specialityController = TextEditingController();
  final _bioController = TextEditingController();
  final _facultyController = TextEditingController();
  final _tagsController = TextEditingController();
  final _orcidController = TextEditingController();
  final _universityEmailController = TextEditingController();

  XFile? _photoFile;

  late String _category;
  final Set<String> _methodologies = {'كمي'};
  bool _isAvailable = true;
  bool _isSaving = false;

  static const _methodologyOptions = ['كمي', 'نوعي', 'مختلط'];

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory ?? facultyCategories.first.id;
    _facultyController.text = facultyTitleForCategory(_category);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _universityController.dispose();
    _specialityController.dispose();
    _bioController.dispose();
    _facultyController.dispose();
    _tagsController.dispose();
    _orcidController.dispose();
    _universityEmailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final loggedIn = await ensureLoggedIn(context);
    if (!loggedIn || !mounted) return;

    final user = FirebaseAuth.instance.currentUser!;

    setState(() => _isSaving = true);

    try {
      final tags = _tagsController.text
          .split(RegExp(r'[،,]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();

      String? photoUrl;
      if (_photoFile != null) {
        photoUrl = await StorageService.instance.uploadImage(
          file: _photoFile!,
          folder: 'supervisors',
        );
      }

      await FirebaseFirestore.instance.collection('supervisors').add({
        'name': _nameController.text.trim(),
        'university': _universityController.text.trim(),
        'speciality': _specialityController.text.trim(),
        'bio': _bioController.text.trim(),
        'faculty': _facultyController.text.trim(),
        'category': _category,
        'tags': tags,
        'methodologies': _methodologies.toList(),
        'isAvailable': _isAvailable,
        'ownerId': user.uid,
        'orcid': _orcidController.text.trim(),
        'universityEmail': _universityEmailController.text.trim(),
        'verificationStatus': VerificationStatus.pending,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'approvalStatus': ApprovalStatus.pending,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _showMessage('تم إرسال ملف المشرف للمراجعة — سيظهر بعد الموافقة');
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
        title: const Text('تسجيل مشرف أكاديمي'),
        backgroundColor: const Color(0xFF1A237E),
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
                'سيُراجع الأدمن ملفك قبل الظهور. أضف ORCID أو بريد جامعي لتوثيق أسرع.',
                Colors.blue,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final file = await StorageService.instance.pickImage();
                  if (file != null) setState(() => _photoFile = file);
                },
                icon: const Icon(Icons.photo_camera),
                label: Text(_photoFile == null ? 'إضافة صورة' : 'تم اختيار صورة'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _orcidController,
                decoration: const InputDecoration(
                  labelText: 'ORCID (اختياري — للتوثيق)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.verified_user_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _universityEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'البريد الجامعي (اختياري)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'الاسم الكامل *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'الاسم مطلوب' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _universityController,
                decoration: const InputDecoration(
                  labelText: 'الجامعة *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_balance_outlined),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'الجامعة مطلوبة' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _specialityController,
                decoration: const InputDecoration(
                  labelText: 'التخصص *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.school_outlined),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'التخصص مطلوب' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _facultyController,
                decoration: const InputDecoration(
                  labelText: 'الكلية',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.apartment_outlined),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(_category),
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'الكلية / القسم *',
                  border: OutlineInputBorder(),
                ),
                items: facultyCategories
                    .map(
                      (faculty) => DropdownMenuItem(
                        value: faculty.id,
                        child: Text(faculty.titleAr),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _category = value;
                    _facultyController.text = facultyTitleForCategory(value);
                  });
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'المنهجية البحثية',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _methodologyOptions.map((item) {
                  final selected = _methodologies.contains(item);
                  return FilterChip(
                    label: Text(item),
                    selected: selected,
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          _methodologies.add(item);
                        } else if (_methodologies.length > 1) {
                          _methodologies.remove(item);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('متاح لإشراف طلاب جدد'),
                value: _isAvailable,
                onChanged: (value) => setState(() => _isAvailable = value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bioController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'نبذة عن الخبرة والاهتمامات البحثية',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'الوسوم (مفصولة بفاصلة)',
                  hintText: 'نانو، طاقة، ذكاء اصطناعي',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
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

  Widget _infoBanner(String text, MaterialColor color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color[800], size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
