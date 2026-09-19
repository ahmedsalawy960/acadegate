import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/directory/directory_trust_status.dart';
import '../../core/locale/locale_extensions.dart';
import '../../core/storage/storage_service.dart';
import '../auth/provider_org_profile.dart';
import '../auth/user_account.dart';
import '../auth/user_account_service.dart';
import '../auth/user_role.dart';

/// Lab managers + other service providers: org credentials + trust status.
class ProviderOrgSection extends StatefulWidget {
  const ProviderOrgSection({super.key, required this.account});

  final UserAccount account;

  @override
  State<ProviderOrgSection> createState() => _ProviderOrgSectionState();
}

class _ProviderOrgSectionState extends State<ProviderOrgSection> {
  late final TextEditingController _org;
  late final TextEditingController _aff;
  late final TextEditingController _title;
  late final TextEditingController _license;
  late final TextEditingController _id;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _web;
  late final TextEditingController _city;
  late final TextEditingController _services;
  String _proofUrl = '';
  bool _saving = false;
  bool _uploading = false;

  String get _role => widget.account.role;

  @override
  void initState() {
    super.initState();
    final p = widget.account.providerProfile;
    _org = TextEditingController(text: p.orgName);
    _aff = TextEditingController(text: p.affiliation);
    _title = TextEditingController(text: p.jobTitle);
    _license = TextEditingController(text: p.licenseNo);
    _id = TextEditingController(text: p.taxOrNationalId);
    _email = TextEditingController(text: p.officialEmail);
    _phone = TextEditingController(text: p.officialPhone);
    _web = TextEditingController(text: p.website);
    _city = TextEditingController(text: p.city);
    _services = TextEditingController(text: p.servicesNote);
    _proofUrl = p.proofUrl;
  }

  @override
  void dispose() {
    _org.dispose();
    _aff.dispose();
    _title.dispose();
    _license.dispose();
    _id.dispose();
    _email.dispose();
    _phone.dispose();
    _web.dispose();
    _city.dispose();
    _services.dispose();
    super.dispose();
  }

  ProviderOrgProfile _draft() => ProviderOrgProfile(
        orgName: _org.text,
        affiliation: _aff.text,
        jobTitle: _title.text,
        licenseNo: _license.text,
        taxOrNationalId: _id.text,
        officialEmail: _email.text,
        officialPhone: _phone.text,
        website: _web.text,
        city: _city.text,
        servicesNote: _services.text,
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
      final contentType = ext == 'pdf' ? 'application/pdf' : 'image/$ext';
      final url = await StorageService.instance.uploadBytes(
        bytes: bytes,
        folder: 'claims',
        fileName: 'provider_proof.$ext',
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
      await UserAccountService.instance.updateProviderProfile(_draft());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t('تم حفظ بيانات الجهة', 'Organization details saved'),
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

  Stream<bool> _trustStream() {
    if (_role == UserRole.labManager) {
      return UserAccountService.instance.watchHasManagedVerifiedLab();
    }
    if (_role == UserRole.supervisor) {
      return UserAccountService.instance.watchHasManagedVerifiedSupervisor();
    }
    return Stream<bool>.value(false);
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final draft = _draft();
    return Card(
      elevation: 0,
      color: Colors.purple.shade50.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.purple.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              ProviderOrgProfile.sectionTitle(_role, isAr: isAr),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            StreamBuilder<bool>(
              stream: _trustStream(),
              builder: (context, snap) {
                final managed = snap.data == true;
                final isLab = _role == UserRole.labManager;
                final isSupervisor = _role == UserRole.supervisor;
                final showTrustChip = isLab || isSupervisor;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showTrustChip)
                      DirectoryTrustChip(
                        status: managed
                            ? DirectoryTrustStatus.managedVerified
                            : DirectoryTrustStatus.unverified,
                      )
                    else
                      Chip(
                        avatar: Icon(
                          draft.hasCoreIdentity
                              ? Icons.badge_outlined
                              : Icons.help_outline,
                          size: 16,
                          color: draft.hasCoreIdentity
                              ? Colors.blue[800]
                              : Colors.grey[700],
                        ),
                        label: Text(
                          draft.hasCoreIdentity
                              ? context.t(
                                  'بيانات مهنية مكتملة (بانتظار مراجعة المنصة عند التفعيل)',
                                  'Professional details filled (pending platform review when enabled)',
                                )
                              : context.t(
                                  'غير مكتمل — أضف بيانات الجهة',
                                  'Incomplete — add organization details',
                                ),
                          style: TextStyle(
                            fontSize: 11,
                            color: draft.hasCoreIdentity
                                ? Colors.blue[900]
                                : Colors.grey[800],
                          ),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    const SizedBox(height: 6),
                    Text(
                      isLab
                          ? (managed
                              ? context.t(
                                  'لديك مختبر «موثّق ومُدار» بعد مراجعة إثبات التمثيل. الحقول أدناه لا تمنح الشارة وحدها.',
                                  'You have a Managed Verified lab after representation review. Fields below do not grant the badge alone.',
                                )
                              : context.t(
                                  'غير موثّق بعد. املأ البيانات ثم طالب ملف المختبر من الدليل وارفع إثباتاً للمراجعة.',
                                  'Not verified yet. Fill these details, then claim the lab profile and submit proof for review.',
                                ))
                          : isSupervisor
                              ? (managed
                                  ? context.t(
                                      'لديك ملف مشرف «موثّق ومُدار» بعد مراجعة الإثبات. الحقول أدناه لا تمنح الشارة وحدها.',
                                      'You have a Managed Verified supervisor listing after proof review. Fields below do not grant the badge alone.',
                                    )
                                  : context.t(
                                      'غير موثّق بعد. املأ البيانات ثم طالب ملفك من دليل المشرفين بإثبات (بريد جامعي / ORCID / خطاب).',
                                      'Not verified yet. Fill these details, then claim your supervisor listing with proof (uni email / ORCID / letter).',
                                    ))
                          : context.t(
                              'هذه البيانات تدعم ثقة مقدّم الخدمة. التوثيق الكامل يتم عبر مراجعة المنصة (وليس بمجرد الحفظ).',
                              'These details support provider trust. Full verification requires platform review (not save alone).',
                            ),
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            _field(
              _org,
              ProviderOrgProfile.orgLabel(_role, isAr: isAr),
            ),
            _field(
              _aff,
              context.t('الجامعة / الانتساب', 'University / affiliation'),
            ),
            _field(
              _title,
              context.t('صفتك / المسمى', 'Your role / title'),
            ),
            _field(
              _license,
              _role == UserRole.labManager
                  ? context.t(
                      'ترخيص / رقم NBSLE أو ما يعادله',
                      'License / NBSLE ID or equivalent',
                    )
                  : context.t(
                      'ترخيص / عضوية مهنية',
                      'License / professional membership',
                    ),
            ),
            _field(
              _id,
              context.t(
                'رقم قومي / ضريبي (اختياري)',
                'National / tax ID (optional)',
              ),
            ),
            _field(
              _email,
              context.t('بريد رسمي', 'Official email'),
              keyboard: TextInputType.emailAddress,
            ),
            _field(
              _phone,
              context.t('هاتف رسمي', 'Official phone'),
              keyboard: TextInputType.phone,
            ),
            _field(_web, context.t('الموقع / الصفحة', 'Website / page')),
            _field(_city, context.t('المدينة', 'City')),
            _field(
              _services,
              context.t(
                'نبذة عن الخدمات / الأجهزة',
                'Services / equipment summary',
              ),
              maxLines: 3,
            ),
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
                        'رفع إثبات تمثيل / ترخيص',
                        'Upload representation / license proof',
                      )
                    : context.t('تم رفع الإثبات — استبدال؟', 'Proof uploaded — replace?'),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.purple[800],
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
                context.t('حفظ بيانات الجهة', 'Save organization details'),
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
