import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../auth/user_account_service.dart';
import 'publish_models.dart';
import 'publish_services.dart';

class AdminJournalFormScreen extends StatefulWidget {
  const AdminJournalFormScreen({super.key});

  @override
  State<AdminJournalFormScreen> createState() => _AdminJournalFormScreenState();
}

class _AdminJournalFormScreenState extends State<AdminJournalFormScreen> {
  static const _brand = Color(0xFF4A148C);

  final _nameCtrl = TextEditingController();
  final _publisherCtrl = TextEditingController();
  final _issnCtrl = TextEditingController();
  final _scopesCtrl = TextEditingController();
  final _submissionUrlCtrl = TextEditingController();
  final _partnerCtrl = TextEditingController();
  bool _supportsIeee = true;
  bool _supportsApa = true;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _publisherCtrl.dispose();
    _issnCtrl.dispose();
    _scopesCtrl.dispose();
    _submissionUrlCtrl.dispose();
    _partnerCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final scopes = _scopesCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      await JournalCatalogService.instance.addJournal(
        PublishJournal(
          name: _nameCtrl.text.trim(),
          publisher: _publisherCtrl.text.trim(),
          issn: _issnCtrl.text.trim(),
          scopes: scopes,
          supportsIeee: _supportsIeee,
          supportsApa: _supportsApa,
          submissionUrl: _submissionUrlCtrl.text.trim(),
          partnerUniversity: _partnerCtrl.text.trim(),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t(
            'تم إرسال المجلة للمراجعة',
            'Journal submitted for review',
          )),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: UserAccountService.instance.watchCurrentAccount(),
      builder: (context, snapshot) {
        if (snapshot.data?.isAdmin != true) {
          return Scaffold(
            appBar: AcadeGateAppBar(
              title: Text(context.t('إضافة مجلة', 'Add journal')),
              backgroundColor: _brand,
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: Text(context.t(
                'متاح لمدير النظام فقط',
                'Admin only',
              )),
            ),
          );
        }

        return Scaffold(
          appBar: AcadeGateAppBar(
            title: Text(context.t('إضافة مجلة', 'Add journal')),
            backgroundColor: _brand,
            foregroundColor: Colors.white,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: context.t('اسم المجلة *', 'Journal name *'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _publisherCtrl,
                decoration: InputDecoration(
                  labelText: context.t('الناشر', 'Publisher'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _issnCtrl,
                decoration: InputDecoration(
                  labelText: 'ISSN',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _scopesCtrl,
                decoration: InputDecoration(
                  labelText: context.t(
                    'التخصصات (افصل بفاصلة)',
                    'Scopes (comma-separated)',
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _partnerCtrl,
                decoration: InputDecoration(
                  labelText: context.t('الجامعة الشريكة', 'Partner university'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _submissionUrlCtrl,
                decoration: InputDecoration(
                  labelText: context.t('رابط التقديم', 'Submission URL'),
                  border: const OutlineInputBorder(),
                ),
              ),
              SwitchListTile(
                title: Text(context.t('يدعم IEEE', 'Supports IEEE')),
                value: _supportsIeee,
                onChanged: (v) => setState(() => _supportsIeee = v),
              ),
              SwitchListTile(
                title: Text(context.t('يدعم APA', 'Supports APA')),
                value: _supportsApa,
                onChanged: (v) => setState(() => _supportsApa = v),
              ),
              const SizedBox(height: 16),
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
                    : Text(context.t('إرسال للمراجعة', 'Submit for review')),
              ),
            ],
          ),
        );
      },
    );
  }
}
