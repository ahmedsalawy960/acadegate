import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../auth/user_account_service.dart';
import 'industry_challenge_models.dart';

class CreateIndustryChallengeScreen extends StatefulWidget {
  const CreateIndustryChallengeScreen({super.key});

  @override
  State<CreateIndustryChallengeScreen> createState() =>
      _CreateIndustryChallengeScreenState();
}

class _CreateIndustryChallengeScreenState
    extends State<CreateIndustryChallengeScreen> {
  static const _brand = Color(0xFFBF360C);

  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _problemCtrl = TextEditingController();
  final _criteriaCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController(text: 'EGP');
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _prefillCompany();
  }

  Future<void> _prefillCompany() async {
    final account = await UserAccountService.instance.loadCurrentAccount();
    final name = account?.displayName.trim() ?? '';
    if (name.isNotEmpty) {
      _companyCtrl.text = name;
    } else {
      final email = FirebaseAuth.instance.currentUser?.email ?? '';
      if (email.isNotEmpty) _companyCtrl.text = email;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _companyCtrl.dispose();
    _problemCtrl.dispose();
    _criteriaCtrl.dispose();
    _budgetCtrl.dispose();
    _currencyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await IndustryChallengeService.instance.createChallenge(
        title: _titleCtrl.text,
        problem: _problemCtrl.text,
        acceptanceCriteria: _criteriaCtrl.text,
        budgetAmount: double.parse(_budgetCtrl.text.trim()),
        currency: _currencyCtrl.text,
        companyName: _companyCtrl.text,
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
        title: Text(context.t(
          'نشر تحدٍ صناعي',
          'Post an industry challenge',
        )),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              context.t(
                'العربون يبقى معلّقاً حتى تؤكد إيداعه. الباحثون لا يقدّمون قبل الحجز.',
                'The deposit stays pending until you confirm it. Researchers cannot submit before it is held.',
              ),
              style: const TextStyle(color: Color(0xFFB7C3D6), height: 1.4),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: context.t('عنوان التحدي', 'Challenge title'),
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v ?? '').trim().length < 8
                  ? context.t('٨ أحرف على الأقل', 'At least 8 characters')
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _companyCtrl,
              decoration: InputDecoration(
                labelText: context.t('اسم الشركة', 'Company name'),
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v ?? '').trim().isEmpty
                  ? context.t('مطلوب', 'Required')
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _problemCtrl,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: context.t('المشكلة الصناعية', 'Industry problem'),
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v ?? '').trim().length < 20
                  ? context.t('٢٠ حرفاً على الأقل', 'At least 20 characters')
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _criteriaCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: context.t(
                  'معيار القبول',
                  'Acceptance criteria',
                ),
                hintText: context.t(
                  'مثال: بروتوكول + نتائج جهاز محدد خلال ٦٠ يوماً',
                  'Example: protocol + instrument results within 60 days',
                ),
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v ?? '').trim().length < 10
                  ? context.t('١٠ أحرف على الأقل', 'At least 10 characters')
                  : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _budgetCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: context.t('ميزانية العربون', 'Deposit budget'),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final n = double.tryParse((v ?? '').trim());
                      if (n == null || n <= 0) {
                        return context.t('مبلغ صحيح', 'Valid amount');
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _currencyCtrl,
                    decoration: InputDecoration(
                      labelText: context.t('العملة', 'Currency'),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? context.t('مطلوب', 'Required')
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
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
                  : Text(context.t('نشر التحدي', 'Publish challenge')),
            ),
          ],
        ),
      ),
    );
  }
}
