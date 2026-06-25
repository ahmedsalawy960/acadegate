import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'academic_profile.dart';
import 'academic_profile_service.dart';

class AcademicProfileScreen extends StatefulWidget {
  const AcademicProfileScreen({super.key});

  @override
  State<AcademicProfileScreen> createState() => _AcademicProfileScreenState();
}

class _AcademicProfileScreenState extends State<AcademicProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _universityController = TextEditingController();
  final _specializationController = TextEditingController();
  final _researchInterestController = TextEditingController();
  final _cityController = TextEditingController();
  final _skillsController = TextEditingController();

  String _degree = 'ماجستير';
  String _methodology = 'كمي';
  String _preferredLanguage = 'العربية';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _hasProfile = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await AcademicProfileService.instance.loadProfile();
    if (!mounted) return;

    if (profile != null) {
      _fullNameController.text = profile.fullName;
      _universityController.text = profile.university;
      _specializationController.text = profile.specialization;
      _researchInterestController.text = profile.researchInterest;
      _cityController.text = profile.city;
      _skillsController.text = profile.skills.join('، ');
      _degree = profile.degree;
      _methodology = profile.methodology;
      _preferredLanguage = profile.preferredLanguage;
    }

    setState(() {
      _isLoading = false;
      _hasProfile = profile != null;
    });
  }

  void _resetForm() {
    _fullNameController.clear();
    _universityController.clear();
    _specializationController.clear();
    _researchInterestController.clear();
    _cityController.clear();
    _skillsController.clear();
    _degree = 'ماجستير';
    _methodology = 'كمي';
    _preferredLanguage = 'العربية';
  }

  Future<void> _deleteProfile() async {
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الملف الأكاديمي'),
        content: Text(
          isLoggedIn
              ? 'هل تريد حذف ملفك الأكاديمي نهائياً؟\n'
                  'ستفقد التوصيات الذكية المبنية عليه ولا يمكن التراجع.'
              : 'هل تريد مسح بيانات ملفك المحفوظة في هذه الجلسة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);

    try {
      await AcademicProfileService.instance.deleteProfile();
      if (!mounted) return;

      _resetForm();
      setState(() {
        _hasProfile = false;
        _isDeleting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف الملف الأكاديمي'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر الحذف: $error'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final profile = AcademicProfile(
      fullName: _fullNameController.text.trim(),
      university: _universityController.text.trim(),
      degree: _degree,
      specialization: _specializationController.text.trim(),
      researchInterest: _researchInterestController.text.trim(),
      methodology: _methodology,
      preferredLanguage: _preferredLanguage,
      city: _cityController.text.trim(),
      skills: _skillsController.text
          .split(RegExp(r'[،,]'))
          .map((skill) => skill.trim())
          .where((skill) => skill.isNotEmpty)
          .toList(),
    );

    AcademicProfileService.instance.saveSessionProfile(profile);
    await AcademicProfileService.instance.saveProfile(profile);

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _universityController.dispose();
    _specializationController.dispose();
    _researchInterestController.dispose();
    _cityController.dispose();
    _skillsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ملفي الأكاديمي'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          if (_hasProfile && !_isLoading)
            IconButton(
              tooltip: 'حذف الملف',
              icon: const Icon(Icons.delete_outline),
              onPressed: (_isSaving || _isDeleting) ? null : _deleteProfile,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'أكمل ملفك لتحصل على توصيات ذكية للمشرفين والأفكار والمختبرات.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _fullNameController,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                      decoration: const InputDecoration(
                        labelText: 'الاسم الكامل',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _universityController,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                      decoration: const InputDecoration(
                        labelText: 'الجامعة',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _degree,
                      decoration: const InputDecoration(
                        labelText: 'الدرجة العلمية',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'ماجستير',
                          child: Text('ماجستير'),
                        ),
                        DropdownMenuItem(
                          value: 'دكتوراه',
                          child: Text('دكتوراه'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _degree = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _specializationController,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                      decoration: const InputDecoration(
                        labelText: 'التخصص',
                        hintText: 'مثال: هندسة مدنية، ذكاء اصطناعي',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _researchInterestController,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'اهتمامك البحثي',
                        hintText: 'مثال: الطاقة الشمسية، النانو تكنولوجي',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _methodology,
                      decoration: const InputDecoration(
                        labelText: 'المنهجية البحثية',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'كمي', child: Text('كمي')),
                        DropdownMenuItem(value: 'نوعي', child: Text('نوعي')),
                        DropdownMenuItem(
                          value: 'مختلط',
                          child: Text('مختلط'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _methodology = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _preferredLanguage,
                      decoration: const InputDecoration(
                        labelText: 'لغة البحث المفضلة',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'العربية',
                          child: Text('العربية'),
                        ),
                        DropdownMenuItem(
                          value: 'الإنجليزية',
                          child: Text('الإنجليزية'),
                        ),
                        DropdownMenuItem(
                          value: 'كلاهما',
                          child: Text('كلاهما'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _preferredLanguage = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'المدينة (اختياري)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _skillsController,
                      decoration: const InputDecoration(
                        labelText: 'المهارات (اختياري)',
                        hintText: 'SPSS، MATLAB، برمجة',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: (_isSaving || _isDeleting) ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A237E),
                          foregroundColor: Colors.white,
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'حفظ الملف والمتابعة',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    if (_hasProfile) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: (_isSaving || _isDeleting)
                              ? null
                              : _deleteProfile,
                          icon: _isDeleting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                          label: const Text(
                            'حذف الملف الأكاديمي',
                            style: TextStyle(color: Colors.red),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
