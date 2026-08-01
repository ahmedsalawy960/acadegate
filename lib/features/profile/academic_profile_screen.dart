import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';
import '../../core/locale/locale_extensions.dart';
import '../research_journey/thesis_progress.dart';
import '../research_journey/thesis_progress_activity.dart';
import '../academic/faculty_categories.dart';
import 'account_profile_screen.dart';
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
  String? _facultyCategory;
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
      _facultyCategory = profile.facultyCategory.isEmpty
          ? profile.resolvedFacultyCategory
          : profile.facultyCategory;
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
    _facultyCategory = null;
    _methodology = 'كمي';
    _preferredLanguage = 'العربية';
  }

  Future<void> _deleteProfile() async {
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t('حذف الملف الأكاديمي', 'Delete academic profile')),
        content: Text(
          isLoggedIn
              ? context.t(
                  'هل تريد حذف ملفك الأكاديمي نهائياً؟\n'
                  'ستفقد التوصيات الذكية المبنية عليه ولا يمكن التراجع.',
                  'Do you want to permanently delete your academic profile?\n'
                  'You will lose smart recommendations based on it and cannot undo this.',
                )
              : context.t(
                  'هل تريد مسح بيانات ملفك المحفوظة في هذه الجلسة؟',
                  'Do you want to clear your profile data saved in this session?',
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.t('حذف', 'Delete')),
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
        SnackBar(
          content: Text(
            context.t('تم حذف الملف الأكاديمي', 'Academic profile deleted'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t('تعذر الحذف: $error', 'Could not delete: $error'),
          ),
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

    final specialization = _specializationController.text.trim();
    final researchInterest = _researchInterestController.text.trim();
    final facultyCategory = _facultyCategory?.trim() ??
        inferFacultyCategoryFromText('$specialization $researchInterest') ??
        '';

    final profile = AcademicProfile(
      fullName: _fullNameController.text.trim(),
      university: _universityController.text.trim(),
      degree: _degree,
      facultyCategory: facultyCategory,
      specialization: specialization,
      researchInterest: researchInterest,
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

    if (profile.isComplete) {
      await ThesisProgressService.instance.recordActivity(
        ThesisActivityId.profileComplete.name,
      );
    }

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    if (!mounted) return;
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
      appBar: AcadeGateAppBar(
        title: Text(context.t('ملفي الأكاديمي', 'My academic profile')),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          if (_hasProfile && !_isLoading)
            IconButton(
              tooltip: context.t('حذف الملف', 'Delete profile'),
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
                    Text(
                      context.t(
                        'أكمل ملفك لتحصل على توصيات ذكية للمشرفين والأفكار والمختبرات.',
                        'Complete your profile to get smart recommendations for supervisors, ideas, and labs.',
                      ),
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AccountProfileScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.manage_accounts_outlined),
                      label: Text(
                        context.t(
                          'إدارة حسابي والصورة والبريد',
                          'Manage account, photo & email',
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _fullNameController,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? context.t('مطلوب', 'Required')
                          : null,
                      decoration: InputDecoration(
                        labelText: context.t('الاسم الكامل', 'Full name'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _universityController,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? context.t('مطلوب', 'Required')
                          : null,
                      decoration: InputDecoration(
                        labelText: context.t('الجامعة', 'University'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _degree,
                      decoration: InputDecoration(
                        labelText: context.t('الدرجة العلمية', 'Degree'),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'ماجستير',
                          child: Text(
                            context.t('ماجستير', "Master's"),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'دكتوراه',
                          child: Text(context.t('دكتوراه', 'PhD')),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _degree = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _facultyCategory,
                      decoration: InputDecoration(
                        labelText: context.t('الكلية', 'Faculty / college'),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value != null && value.isNotEmpty) return null;
                        final inferred = inferFacultyCategoryFromText(
                          '${_specializationController.text} ${_researchInterestController.text}',
                        );
                        return inferred == null
                            ? context.t(
                                'اختر كليتك لتحسين المطابقة',
                                'Select your faculty for better matching',
                              )
                            : null;
                      },
                      items: [
                        for (final faculty in facultyCategories)
                          DropdownMenuItem(
                            value: faculty.id,
                            child: Text(faculty.titleAr),
                          ),
                      ],
                      onChanged: (value) {
                        setState(() => _facultyCategory = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _specializationController,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? context.t('مطلوب', 'Required')
                          : null,
                      decoration: InputDecoration(
                        labelText: context.t('التخصص', 'Specialization'),
                        hintText: context.t(
                          'مثال: كيمياء عضوية، هندسة مدنية',
                          'e.g. Organic chemistry, civil engineering',
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _researchInterestController,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? context.t('مطلوب', 'Required')
                          : null,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: context.t('اهتمامك البحثي', 'Research interest'),
                        hintText: context.t(
                          'مثال: الطاقة الشمسية، النانو تكنولوجي',
                          'e.g. Solar energy, nanotechnology',
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _methodology,
                      decoration: InputDecoration(
                        labelText: context.t('المنهجية البحثية', 'Research methodology'),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'كمي',
                          child: Text(context.t('كمي', 'Quantitative')),
                        ),
                        DropdownMenuItem(
                          value: 'نوعي',
                          child: Text(context.t('نوعي', 'Qualitative')),
                        ),
                        DropdownMenuItem(
                          value: 'مختلط',
                          child: Text(context.t('مختلط', 'Mixed methods')),
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
                      decoration: InputDecoration(
                        labelText: context.t(
                          'لغة البحث المفضلة',
                          'Preferred research language',
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'العربية',
                          child: Text(context.t('العربية', 'Arabic')),
                        ),
                        DropdownMenuItem(
                          value: 'الإنجليزية',
                          child: Text(context.t('الإنجليزية', 'English')),
                        ),
                        DropdownMenuItem(
                          value: 'كلاهما',
                          child: Text(context.t('كلاهما', 'Both')),
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
                      decoration: InputDecoration(
                        labelText: context.t('المدينة (اختياري)', 'City (optional)'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _skillsController,
                      decoration: InputDecoration(
                        labelText: context.t('المهارات (اختياري)', 'Skills (optional)'),
                        hintText: context.t(
                          'SPSS، MATLAB، برمجة',
                          'SPSS, MATLAB, programming',
                        ),
                        border: const OutlineInputBorder(),
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
                            : Text(
                                context.t(
                                  'حفظ الملف والمتابعة',
                                  'Save profile and continue',
                                ),
                                style: const TextStyle(
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
                          label: Text(
                            context.t('حذف الملف الأكاديمي', 'Delete academic profile'),
                            style: const TextStyle(color: Colors.red),
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
