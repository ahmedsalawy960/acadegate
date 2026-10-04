import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../config/app_contact_info.dart';
import '../locale/locale_extensions.dart';
import '../storage/storage_service.dart';
import '../../features/auth/auth_guard.dart';
import 'profile_claim_service.dart';

/// Evidence form: Claim this profile → pending admin review.
Future<void> showClaimProfileSheet(
  BuildContext context, {
  required String targetType,
  required String targetId,
  required String targetName,
}) async {
  final ok = await ensureLoggedIn(context);
  if (!ok || !context.mounted) return;

  final legalCtrl = TextEditingController(text: targetName);
  final tradeCtrl = TextEditingController();
  final titleCtrl = TextEditingController();
  final crCtrl = TextEditingController();
  final taxCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final webCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  var proofUrl = '';
  var uploading = false;
  var submitting = false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
        ),
        child: StatefulBuilder(
          builder: (ctx, setLocal) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ctx.t('مطالبة هذا الملف', 'Claim this profile'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ctx.t(
                      'أثبت أنك تمثّل $targetName. بعد المراجعة يصبح الملف «موثّق ومُدار» ويمكنك ترتيب البيانات والمنتجات/الخدمات.',
                      'Prove you represent $targetName. After review the profile becomes Managed Verified and you can manage data, products/services.',
                    ),
                    style: TextStyle(
                      height: 1.4,
                      color: const Color(0xFFB7C3D6),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: legalCtrl,
                    decoration: InputDecoration(
                      labelText: ctx.t(
                        'الاسم القانوني للمنشأة *',
                        'Legal entity name *',
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: tradeCtrl,
                    decoration: InputDecoration(
                      labelText: ctx.t('الاسم التجاري', 'Trade name'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: ctx.t(
                        'صفتك / المسمى الوظيفي *',
                        'Your role / job title *',
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: ctx.t(
                        'بريد رسمي للمنشأة *',
                        'Official entity email *',
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: ctx.t('هاتف رسمي', 'Official phone'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: crCtrl,
                    decoration: InputDecoration(
                      labelText: ctx.t(
                        'السجل التجاري / الترخيص',
                        'Commercial register / license',
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: taxCtrl,
                    decoration: InputDecoration(
                      labelText: ctx.t('الرقم الضريبي', 'Tax ID'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: webCtrl,
                    decoration: InputDecoration(
                      labelText: ctx.t('الموقع الرسمي', 'Official website'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: uploading
                        ? null
                        : () async {
                            setLocal(() => uploading = true);
                            try {
                              final result = await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: const [
                                  'pdf',
                                  'png',
                                  'jpg',
                                  'jpeg',
                                  'webp',
                                ],
                                withData: true,
                              );
                              final file = result?.files.single;
                              final bytes = file?.bytes;
                              if (bytes == null || bytes.isEmpty) return;
                              final name = file!.name.toLowerCase();
                              final ext = name.contains('.')
                                  ? name.split('.').last
                                  : 'pdf';
                              final contentType = ext == 'pdf'
                                  ? 'application/pdf'
                                  : 'image/$ext';
                              final url = await StorageService.instance
                                  .uploadBytes(
                                bytes: bytes,
                                folder: 'claims',
                                fileName: 'proof.$ext',
                                contentType: contentType,
                              );
                              setLocal(() => proofUrl = url);
                            } catch (e) {
                              if (!ctx.mounted) return;
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('$e')),
                              );
                            } finally {
                              setLocal(() => uploading = false);
                            }
                          },
                    icon: uploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file_outlined),
                    label: Text(
                      proofUrl.isEmpty
                          ? ctx.t(
                              'رفع إثبات التمثيل * (سجل/خطاب/بطاقة)',
                              'Upload representation proof * (CR / letter / ID)',
                            )
                          : ctx.t('تم رفع الإثبات', 'Proof uploaded'),
                    ),
                  ),
                  if (proofUrl.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        ctx.t(
                          'الإثبات إلزامي قبل الإرسال للمراجعة.',
                          'Proof is required before submitting for review.',
                        ),
                        style: TextStyle(fontSize: 12, color: Colors.red[800]),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: ctx.t('ملاحظات إضافية', 'Additional notes'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            setLocal(() => submitting = true);
                            try {
                              if (proofUrl.trim().isEmpty) {
                                throw StateError(
                                  ctx.t(
                                    'ارفع إثبات التمثيل قبل الإرسال',
                                    'Upload representation proof before submitting',
                                  ),
                                );
                              }
                              final id =
                                  await ProfileClaimService.instance.submitClaim(
                                targetType: targetType,
                                targetId: targetId,
                                targetName: targetName,
                                evidence: ProfileClaimEvidence(
                                  legalName: legalCtrl.text,
                                  tradeName: tradeCtrl.text,
                                  jobTitle: titleCtrl.text,
                                  commercialRegisterNo: crCtrl.text,
                                  taxId: taxCtrl.text,
                                  officialEmail: emailCtrl.text,
                                  officialPhone: phoneCtrl.text,
                                  websiteUrl: webCtrl.text,
                                  proofUrl: proofUrl,
                                  notes: notesCtrl.text,
                                ),
                              );
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    context.t(
                                      'تم إرسال المطالبة للمراجعة ($id). سنراجع إثبات التمثيل ثم نفعّل Managed Verified.',
                                      'Claim submitted for review ($id). We will verify representation then enable Managed Verified.',
                                    ),
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (!ctx.mounted) return;
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text('$e'),
                                  backgroundColor: Colors.red[800],
                                ),
                              );
                            } finally {
                              setLocal(() => submitting = false);
                            }
                          },
                    child: Text(
                      ctx.t('إرسال للمراجعة', 'Submit for review'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ctx.t(
                      'الدعم: ${AppContactInfo.supportEmail}',
                      'Support: ${AppContactInfo.supportEmail}',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: const Color(0xFFB7C3D6)),
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );

  legalCtrl.dispose();
  tradeCtrl.dispose();
  titleCtrl.dispose();
  crCtrl.dispose();
  taxCtrl.dispose();
  emailCtrl.dispose();
  phoneCtrl.dispose();
  webCtrl.dispose();
  notesCtrl.dispose();
}
