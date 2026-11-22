import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import 'personal_info.dart';
import 'personal_info_fields.dart';
import 'user_account_service.dart';

/// Collects phone / gender / birth date / governorate.
///
/// Shown once by the portal gateway for accounts missing these details
/// (Google sign-in, older accounts), and reused from "My account" to edit.
class CompletePersonalInfoScreen extends StatefulWidget {
  const CompletePersonalInfoScreen({
    super.key,
    this.initial = const PersonalInfo(),
    this.onCompleted,
    this.isEdit = false,
  });

  final PersonalInfo initial;
  final VoidCallback? onCompleted;
  final bool isEdit;

  @override
  State<CompletePersonalInfoScreen> createState() =>
      _CompletePersonalInfoScreenState();
}

class _CompletePersonalInfoScreenState
    extends State<CompletePersonalInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneController;
  String? _gender;
  DateTime? _birthDate;
  String? _governorate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _phoneController =
        TextEditingController(text: PersonalInfo.localPhone(i.phone));
    _gender = Gender.all.contains(i.gender) ? i.gender : null;
    _birthDate = i.birthDate;
    _governorate = i.governorate.isEmpty ? null : i.governorate;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await UserAccountService.instance.savePersonalInfo(
        PersonalInfo(
          phone: PersonalInfo.normalizePhone(_phoneController.text) ?? '',
          gender: _gender ?? '',
          birthDate: _birthDate,
          governorate: _governorate ?? '',
        ),
      );
      if (!mounted) return;
      if (widget.isEdit) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t('تم حفظ البيانات', 'Details saved')),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      } else {
        widget.onCompleted?.call();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red[800],
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(
          widget.isEdit
              ? context.t('البيانات الشخصية', 'Personal details')
              : context.t('أكمل بيانات حسابك', 'Complete your account'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.isEdit
                  ? context.t(
                      'هذه البيانات خاصة بك ولا تظهر لباقي المستخدمين.',
                      'These details are private and not shown to other users.',
                    )
                  : context.t(
                      'نحتاج بعض البيانات الأساسية لإكمال حسابك والتواصل معك بخصوص الطلبات. '
                          'هذه البيانات خاصة بك ولا تظهر لباقي المستخدمين.',
                      'We need a few basic details to complete your account and contact you about orders. '
                          'They are private and not shown to other users.',
                    ),
              style: const TextStyle(height: 1.5, color: Color(0xFFB7C3D6)),
            ),
            const SizedBox(height: 20),
            PersonalInfoFields(
              phoneController: _phoneController,
              gender: _gender,
              birthDate: _birthDate,
              governorate: _governorate,
              enabled: !_saving,
              onGenderChanged: (v) => setState(() => _gender = v),
              onBirthDateChanged: (v) => setState(() => _birthDate = v),
              onGovernorateChanged: (v) => setState(() => _governorate = v),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        widget.isEdit
                            ? context.t('حفظ', 'Save')
                            : context.t('متابعة', 'Continue'),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
