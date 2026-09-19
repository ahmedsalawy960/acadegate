import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/directory/directory_trust_status.dart';
import '../../core/locale/locale_extensions.dart';
import '../../core/storage/storage_service.dart';
import '../auth/merchant_business_profile.dart';
import '../auth/user_account.dart';
import '../auth/user_account_service.dart';

/// Merchant-only: business entity fields + verification status (not auto-Verified).
class MerchantBusinessSection extends StatefulWidget {
  const MerchantBusinessSection({super.key, required this.account});

  final UserAccount account;

  @override
  State<MerchantBusinessSection> createState() =>
      _MerchantBusinessSectionState();
}

class _MerchantBusinessSectionState extends State<MerchantBusinessSection> {
  late final TextEditingController _legal;
  late final TextEditingController _trade;
  late final TextEditingController _title;
  late final TextEditingController _cr;
  late final TextEditingController _tax;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _web;
  late final TextEditingController _city;
  late final TextEditingController _address;
  String _proofUrl = '';
  bool _saving = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final p = widget.account.businessProfile;
    _legal = TextEditingController(text: p.legalName);
    _trade = TextEditingController(text: p.tradeName);
    _title = TextEditingController(text: p.jobTitle);
    _cr = TextEditingController(text: p.commercialRegisterNo);
    _tax = TextEditingController(text: p.taxId);
    _email = TextEditingController(text: p.officialEmail);
    _phone = TextEditingController(text: p.officialPhone);
    _web = TextEditingController(text: p.website);
    _city = TextEditingController(text: p.city);
    _address = TextEditingController(text: p.address);
    _proofUrl = p.proofUrl;
  }

  @override
  void didUpdateWidget(covariant MerchantBusinessSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account.businessProfile.toMap().toString() !=
            widget.account.businessProfile.toMap().toString() &&
        !_saving) {
      final p = widget.account.businessProfile;
      _legal.text = p.legalName;
      _trade.text = p.tradeName;
      _title.text = p.jobTitle;
      _cr.text = p.commercialRegisterNo;
      _tax.text = p.taxId;
      _email.text = p.officialEmail;
      _phone.text = p.officialPhone;
      _web.text = p.website;
      _city.text = p.city;
      _address.text = p.address;
      _proofUrl = p.proofUrl;
    }
  }

  @override
  void dispose() {
    _legal.dispose();
    _trade.dispose();
    _title.dispose();
    _cr.dispose();
    _tax.dispose();
    _email.dispose();
    _phone.dispose();
    _web.dispose();
    _city.dispose();
    _address.dispose();
    super.dispose();
  }

  MerchantBusinessProfile _draft() => MerchantBusinessProfile(
        legalName: _legal.text,
        tradeName: _trade.text,
        jobTitle: _title.text,
        commercialRegisterNo: _cr.text,
        taxId: _tax.text,
        officialEmail: _email.text,
        officialPhone: _phone.text,
        website: _web.text,
        city: _city.text,
        address: _address.text,
        proofUrl: _proofUrl,
      );

  Future<void> _uploadProof() async {
    setState(() => _uploading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
        withData: true,
      );
      final file = result?.files.single;
      final bytes = file?.bytes;
      if (bytes == null || bytes.isEmpty) return;
      final name = file!.name.toLowerCase();
      final ext = name.contains('.') ? name.split('.').last : 'pdf';
      final contentType =
          ext == 'pdf' ? 'application/pdf' : 'image/$ext';
      final url = await StorageService.instance.uploadBytes(
        bytes: bytes,
        folder: 'claims',
        fileName: 'business_proof.$ext',
        contentType: contentType,
      );
      if (!mounted) return;
      setState(() => _proofUrl = url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await UserAccountService.instance.updateBusinessProfile(_draft());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t('تم حفظ بيانات المنشأة', 'Business details saved'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red[800]),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _draft();
    return Card(
      elevation: 0,
      color: Colors.teal.shade50.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.teal.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.t('بيانات المنشأة (تاجر)', 'Business entity (merchant)'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            StreamBuilder<bool>(
              stream: UserAccountService.instance
                  .watchHasManagedVerifiedSupplier(),
              builder: (context, snap) {
                final managed = snap.data == true;
                final status = managed
                    ? DirectoryTrustStatus.managedVerified
                    : DirectoryTrustStatus.unverified;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DirectoryTrustChip(status: status),
                    const SizedBox(height: 6),
                    Text(
                      managed
                          ? context.t(
                              'لديك ملف مورد «موثّق ومُدار» بعد مراجعة إثبات التمثيل. ملء الحقول أدناه لا يمنح الشارة وحدها.',
                              'You have a Managed Verified supplier listing after representation review. Filling fields below does not grant the badge alone.',
                            )
                          : context.t(
                              'غير موثّق بعد. املأ البيانات ثم طالب ملفك من صفحة المورد في الدليل وارفع إثباتاً للمراجعة.',
                              'Not verified yet. Fill these details, then claim your directory profile and submit proof for review.',
                            ),
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Colors.grey[800],
                      ),
                    ),
                    if (!managed && profile.hasCoreIdentity) ...[
                      const SizedBox(height: 6),
                      Text(
                        context.t(
                          'بيانات أساسية مكتملة — الخطوة التالية: مطالبة الملف من الدليل.',
                          'Core details filled — next: claim your directory profile.',
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.teal[900],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            _field(_legal, context.t('الاسم القانوني *', 'Legal name *')),
            _field(_trade, context.t('الاسم التجاري', 'Trade name')),
            _field(
              _title,
              context.t('صفتك / المسمى', 'Your role / title'),
            ),
            _field(
              _cr,
              context.t('السجل التجاري / الترخيص', 'Commercial register / license'),
            ),
            _field(_tax, context.t('الرقم / البطاقة الضريبية', 'Tax ID')),
            _field(
              _email,
              context.t('بريد المنشأة الرسمي', 'Official entity email'),
              keyboard: TextInputType.emailAddress,
            ),
            _field(
              _phone,
              context.t('هاتف رسمي', 'Official phone'),
              keyboard: TextInputType.phone,
            ),
            _field(_web, context.t('الموقع الرسمي', 'Official website')),
            _field(_city, context.t('المدينة', 'City')),
            _field(_address, context.t('العنوان', 'Address'), maxLines: 2),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: _uploading ? null : _uploadProof,
              icon: _uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_outlined),
              label: Text(
                _proofUrl.isEmpty
                    ? context.t(
                        'رفع إثبات (سجل / بطاقة / خطاب)',
                        'Upload proof (CR / tax / letter)',
                      )
                    : context.t('تم رفع الإثبات — استبدال؟', 'Proof uploaded — replace?'),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.teal[800],
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                context.t('حفظ بيانات المنشأة', 'Save business details'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    TextInputType? keyboard,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}
