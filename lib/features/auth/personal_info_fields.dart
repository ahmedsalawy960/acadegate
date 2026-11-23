import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';
import 'personal_info.dart';

/// Phone, gender, birth date and governorate — must sit inside a [Form].
class PersonalInfoFields extends StatelessWidget {
  const PersonalInfoFields({
    super.key,
    required this.phoneController,
    required this.gender,
    required this.birthDate,
    required this.governorate,
    required this.onGenderChanged,
    required this.onBirthDateChanged,
    required this.onGovernorateChanged,
    this.enabled = true,
  });

  final TextEditingController phoneController;
  final String? gender;
  final DateTime? birthDate;
  final String? governorate;
  final ValueChanged<String?> onGenderChanged;
  final ValueChanged<DateTime> onBirthDateChanged;
  final ValueChanged<String?> onGovernorateChanged;
  final bool enabled;

  OutlineInputBorder get _border =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(12));

  Future<void> _pickBirthDate(BuildContext context) async {
    final now = DateTime.now();
    final last = DateTime(now.year - PersonalInfo.minAge, now.month, now.day);
    final first = DateTime(now.year - PersonalInfo.maxAge);
    final initial = birthDate ?? DateTime(now.year - 25, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(last) ? last : initial,
      firstDate: first,
      lastDate: last,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      initialDatePickerMode: DatePickerMode.year,
      helpText: context.t('تاريخ الميلاد', 'Date of birth'),
    );
    if (picked != null) onBirthDateChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final age = birthDate == null
        ? null
        : PersonalInfo.ageOn(birthDate!, DateTime.now());
    final birthLabel = birthDate == null
        ? ''
        : '${birthDate!.day}/${birthDate!.month}/${birthDate!.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: phoneController,
          enabled: enabled,
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
            labelText: context.t(
              'رقم الموبايل (اختياري)',
              'Mobile number (optional)',
            ),
            hintText: '01xxxxxxxxx',
            prefixIcon: const Icon(Icons.phone_outlined),
            border: _border,
          ),
          validator: (value) {
            final v = (value ?? '').trim();
            if (v.isEmpty) return null;
            if (PersonalInfo.normalizePhone(v) == null) {
              return context.t(
                'رقم غير صحيح — مثال: 01012345678 (أو رقم دولي يبدأ بـ +)',
                'Invalid number — e.g. 01012345678 (or international starting with +)',
              );
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: Gender.all.contains(gender) ? gender : null,
          decoration: InputDecoration(
            labelText: context.t('النوع', 'Gender'),
            prefixIcon: const Icon(Icons.wc_outlined),
            border: _border,
          ),
          items: [
            for (final g in Gender.all)
              DropdownMenuItem(
                value: g,
                child: Text(context.t(Gender.labelAr(g), Gender.labelEn(g))),
              ),
          ],
          onChanged: enabled ? onGenderChanged : null,
          validator: (v) =>
              v == null ? context.t('اختر النوع', 'Select gender') : null,
        ),
        const SizedBox(height: 16),
        FormField<DateTime>(
          initialValue: birthDate,
          validator: (_) => null,
          builder: (state) => InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: enabled
                ? () async {
                    await _pickBirthDate(context);
                    state.didChange(birthDate);
                  }
                : null,
            child: InputDecorator(
              isEmpty: birthDate == null,
              decoration: InputDecoration(
                labelText: context.t(
                  'تاريخ الميلاد (اختياري)',
                  'Date of birth (optional)',
                ),
                prefixIcon: const Icon(Icons.cake_outlined),
                suffixText: age == null
                    ? null
                    : context.t('العمر: $age سنة', 'Age: $age'),
                border: _border,
                errorText: state.errorText,
              ),
              child: Text(birthLabel),
            ),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: EgyptGovernorates.all.any((g) => g.$1 == governorate)
              ? governorate
              : null,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: context.t('المحافظة', 'Governorate'),
            prefixIcon: const Icon(Icons.location_on_outlined),
            border: _border,
          ),
          items: [
            for (final g in EgyptGovernorates.all)
              DropdownMenuItem(value: g.$1, child: Text(context.t(g.$1, g.$2))),
          ],
          onChanged: enabled ? onGovernorateChanged : null,
          validator: (v) => v == null
              ? context.t('اختر المحافظة', 'Select governorate')
              : null,
        ),
      ],
    );
  }
}
