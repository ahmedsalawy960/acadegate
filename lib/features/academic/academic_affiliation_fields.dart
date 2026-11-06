import 'package:flutter/material.dart';

import '../../core/locale/l10n_lookup.dart';
import '../../core/locale/locale_extensions.dart';
import 'egypt_universities.dart';
import 'faculty_categories.dart';
import 'faculty_departments.dart';

/// University → faculty → department dropdowns for register / profile.
class AcademicAffiliationFields extends StatelessWidget {
  const AcademicAffiliationFields({
    super.key,
    required this.university,
    required this.universityOtherController,
    required this.facultyCategory,
    required this.departmentId,
    required this.onUniversityChanged,
    required this.onFacultyChanged,
    required this.onDepartmentChanged,
    this.requireUniversity = true,
    this.requireFaculty = false,
    this.requireDepartment = false,
  });

  final String? university;
  final TextEditingController universityOtherController;
  final String? facultyCategory;
  final String? departmentId;
  final ValueChanged<String?> onUniversityChanged;
  final ValueChanged<String?> onFacultyChanged;
  final ValueChanged<String?> onDepartmentChanged;
  final bool requireUniversity;
  final bool requireFaculty;
  final bool requireDepartment;

  bool get _isOtherUniversity => university == EgyptUniversities.otherValue;

  List<FacultyDepartment> get _departments {
    final faculty = facultyCategory?.trim() ?? '';
    if (faculty.isEmpty) return const [];
    return FacultyDepartments.forFaculty(faculty);
  }

  @override
  Widget build(BuildContext context) {
    final universities = EgyptUniversities.names;
    final uniValue = university != null &&
            (university == EgyptUniversities.otherValue ||
                universities.contains(university))
        ? university
        : null;
    final departments = _departments;
    final deptValue = departmentId != null &&
            departments.any((d) => d.id == departmentId)
        ? departmentId
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('university-${uniValue ?? 'none'}'),
          initialValue: uniValue,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: context.t('الجامعة', 'University'),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          validator: requireUniversity
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return context.t('مطلوب', 'Required');
                  }
                  if (value == EgyptUniversities.otherValue &&
                      universityOtherController.text.trim().isEmpty) {
                    return context.t(
                      'اكتب اسم الجامعة',
                      'Enter the university name',
                    );
                  }
                  return null;
                }
              : null,
          items: [
            for (final name in universities)
              DropdownMenuItem(
                value: name,
                child: Text(name, overflow: TextOverflow.ellipsis),
              ),
            DropdownMenuItem(
              value: EgyptUniversities.otherValue,
              child: Text(
                context.t('أخرى (اكتب الاسم)', 'Other (type the name)'),
              ),
            ),
          ],
          onChanged: onUniversityChanged,
        ),
        if (_isOtherUniversity) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: universityOtherController,
            decoration: InputDecoration(
              labelText: context.t('اسم الجامعة', 'University name'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: requireUniversity
                ? (value) => (value ?? '').trim().isEmpty
                    ? context.t('مطلوب', 'Required')
                    : null
                : null,
          ),
        ],
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey('faculty-${facultyCategory ?? 'none'}'),
          initialValue: facultyCategory != null &&
                  facultyCategories.any((f) => f.id == facultyCategory)
              ? facultyCategory
              : null,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: context.t('الكلية', 'Faculty / college'),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          validator: requireFaculty
              ? (value) => (value == null || value.isEmpty)
                  ? context.t(
                      'اختر كليتك لتحسين المطابقة',
                      'Select your faculty for better matching',
                    )
                  : null
              : null,
          items: [
            for (final faculty in facultyCategories)
              DropdownMenuItem(
                value: faculty.id,
                child: Text(
                  L10nLookup.facultyTitleStatic(faculty.id),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: onFacultyChanged,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey('dept-${facultyCategory ?? 'none'}-${deptValue ?? 'none'}'),
          initialValue: deptValue,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: context.t('القسم', 'Department'),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            helperText: departments.isEmpty
                ? context.t(
                    'اختر الكلية أولاً لعرض أقسامها',
                    'Select a faculty first to list its departments',
                  )
                : null,
          ),
          validator: requireDepartment
              ? (value) => (value == null || value.isEmpty)
                  ? context.t('مطلوب', 'Required')
                  : null
              : null,
          items: [
            for (final dept in departments)
              DropdownMenuItem(
                value: dept.id,
                child: Text(
                  context.t(dept.titleAr, dept.titleEn),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: departments.isEmpty ? null : onDepartmentChanged,
        ),
      ],
    );
  }

  /// Resolved university string to persist on the profile.
  static String resolveUniversity({
    required String? university,
    required TextEditingController otherController,
  }) {
    if (university == null || university.isEmpty) return '';
    if (university == EgyptUniversities.otherValue) {
      return otherController.text.trim();
    }
    return university.trim();
  }
}
