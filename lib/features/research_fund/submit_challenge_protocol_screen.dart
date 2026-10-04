import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../profile/academic_profile_service.dart';
import 'industry_challenge_models.dart';

class SubmitChallengeProtocolScreen extends StatefulWidget {
  final IndustryChallenge challenge;

  const SubmitChallengeProtocolScreen({super.key, required this.challenge});

  @override
  State<SubmitChallengeProtocolScreen> createState() =>
      _SubmitChallengeProtocolScreenState();
}

class _SubmitChallengeProtocolScreenState
    extends State<SubmitChallengeProtocolScreen> {
  static const _brand = Color(0xFFBF360C);

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    final profile = await AcademicProfileService.instance.loadProfile();
    if (profile != null && profile.fullName.trim().isNotEmpty) {
      _nameCtrl.text = profile.fullName.trim();
    } else {
      final user = FirebaseAuth.instance.currentUser;
      _nameCtrl.text = user?.displayName?.trim().isNotEmpty == true
          ? user!.displayName!.trim()
          : (user?.email ?? '');
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _summaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await IndustryChallengeService.instance.submitProtocol(
        challenge: widget.challenge,
        researcherName: _nameCtrl.text,
        summary: _summaryCtrl.text,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('تقديم بروتوكول', 'Submit protocol')),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.challenge.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              context.t(
                'العربون محجوز مسبقاً. اكتب خطة العمل ومعيار التسليم.',
                'The deposit is already held. Write the work plan and delivery bar.',
              ),
              style: TextStyle(color: const Color(0xFFB7C3D6), height: 1.4),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: context.t('اسمك', 'Your name'),
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v ?? '').trim().isEmpty
                  ? context.t('مطلوب', 'Required')
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _summaryCtrl,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: context.t('البروتوكول', 'Protocol'),
                hintText: context.t(
                  'الخطة، الأجهزة، والجدول حتى معيار القبول',
                  'Plan, instruments, and timeline against the acceptance criteria',
                ),
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v ?? '').trim().length < 20
                  ? context.t('٢٠ حرفاً على الأقل', 'At least 20 characters')
                  : null,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: _brand,
                minimumSize: const Size.fromHeight(48),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.t('إرسال البروتوكول', 'Send protocol')),
            ),
          ],
        ),
      ),
    );
  }
}
