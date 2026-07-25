import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale/app_translate.dart';
import '../../core/locale/locale_extensions.dart';
import '../academic/academic_models.dart';
import '../auth/login_screen.dart';
import '../messaging/chat_screen.dart';
import '../messaging/messaging_models.dart';
import '../messaging/messaging_service.dart';
import 'supervision_request_dialog.dart';

/// Always opens a visible UI: chat, message form, or sign-in prompt.
Future<void> contactSupervisor(
  BuildContext context,
  AcademicSupervisor supervisor,
) async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    await _showLoginRequiredDialog(context);
    return;
  }

  if (supervisor.hasMessagingAccount) {
    if (supervisor.ownerId == user.uid) {
      if (!context.mounted) return;
      await _showInfoDialog(
        context,
        title: context.t('ملفك كمشرف', 'Your supervisor profile'),
        message: context.t(
          'هذا ملفك الذي سجّلته أنت. الطلاب هم من يراسلونك — ستصلك رسائلهم من أيقونة «الرسائل» في الصفحة الرئيسية أو لوحة المساهمة.',
          'This is your own profile. Students message you — their messages arrive via Messages on the home screen or contribution dashboard.',
        ),
      );
      return;
    }

    await _openDirectChat(context, supervisor);
    return;
  }

  if (!context.mounted) return;
  await showSupervisorContactSheet(context, supervisor: supervisor);
}

Future<void> requestSupervision(
  BuildContext context,
  AcademicSupervisor supervisor,
) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    await _showLoginRequiredDialog(context);
    return;
  }

  if (!context.mounted) return;
  await showSupervisionRequestDialog(
    context,
    supervisor: supervisor,
    requestType: 'supervision',
  );
}

Future<void> showSupervisorContactSheet(
  BuildContext context, {
  required AcademicSupervisor supervisor,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.t(
                'مراسلة ${supervisor.name}',
                'Message ${supervisor.name}',
              ),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              supervisor.isImportedListing
                  ? context.t(
                      'هذا المشرف مدرج من قاعدة بيانات أكاديمية. أرسل رسالة أو طلب إشراف وسنحفظه حتى يربط المشرف حسابه.',
                      'This supervisor is listed from an academic database. Send a message or supervision request and we will keep it until they link their account.',
                    )
                  : context.t(
                      'المشرف غير مرتبط بحساب داخل التطبيق بعد. اختر طريقة التواصل:',
                      'This supervisor is not linked to an in-app account yet. Choose how to contact them:',
                    ),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(sheetContext);
                if (!context.mounted) return;
                await showSupervisionRequestDialog(
                  context,
                  supervisor: supervisor,
                  requestType: 'message',
                );
              },
              icon: const Icon(Icons.chat_bubble_outline),
              label: Text(context.t(
                'إرسال رسالة داخل التطبيق',
                'Send in-app message',
              )),
            ),
            if (supervisor.universityEmail.isNotEmpty) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  await _openUniversityEmail(context, supervisor);
                },
                icon: const Icon(Icons.alternate_email),
                label: Text(context.t(
                  'البريد الجامعي: ${supervisor.universityEmail}',
                  'University email: ${supervisor.universityEmail}',
                )),
              ),
            ],
          ],
        ),
      );
    },
  );
}

Future<void> _openDirectChat(
  BuildContext context,
  AcademicSupervisor supervisor,
) async {
  if (!context.mounted) return;

  var loadingVisible = true;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(dialogContext.t(
                'جاري فتح المحادثة...',
                'Opening conversation...',
              )),
            ],
          ),
        ),
      ),
    ),
  ).whenComplete(() => loadingVisible = false);

  void closeLoading() {
    if (!loadingVisible || !context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    loadingVisible = false;
  }

  try {
    final user = FirebaseAuth.instance.currentUser!;
    final id = await MessagingService.instance.openConversation(
      otherUserId: supervisor.ownerId,
      otherUserName: supervisor.name,
      contextType: 'supervisor',
      contextId: supervisor.id ?? '',
      contextTitle: supervisor.name,
    );

    if (!context.mounted) return;
    closeLoading();

    final conv = Conversation(
      id: id,
      participantIds: [user.uid, supervisor.ownerId],
      participantNames: {supervisor.ownerId: supervisor.name},
      contextType: 'supervisor',
      contextId: supervisor.id ?? '',
    );

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen(conversation: conv)),
    );
  } catch (e) {
    if (!context.mounted) return;
    closeLoading();
    await _showInfoDialog(
      context,
      title: context.t('تعذر فتح المحادثة', 'Could not open conversation'),
      message: '$e',
    );
  }
}

Future<void> _openUniversityEmail(
  BuildContext context,
  AcademicSupervisor supervisor,
) async {
  final uri = Uri(
    scheme: 'mailto',
    path: supervisor.universityEmail,
    query: _encodeQuery({
      'subject': appTr(
        'تواصل عبر AcadeGate — ${supervisor.name}',
        'Contact via AcadeGate — ${supervisor.name}',
      ),
      'body': appTr(
        'السلام عليكم د.${supervisor.name},\n\nأتواصل معكم عبر تطبيق AcadeGate بخصوص ...\n',
        'Dear Dr. ${supervisor.name},\n\nI am contacting you via the AcadeGate app regarding ...\n',
      ),
    }),
  );

  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    await _showInfoDialog(
      context,
      title: context.t('البريد الجامعي', 'University email'),
      message: context.t(
        'لم يُعثر على تطبيق بريد على الجهاز.\n\nانسخ العنوان:\n${supervisor.universityEmail}',
        'No mail app found on this device.\n\nCopy the address:\n${supervisor.universityEmail}',
      ),
    );
  }
}

Future<void> _showLoginRequiredDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(dialogContext.t('تسجيل الدخول مطلوب', 'Sign-in required')),
      content: Text(dialogContext.t(
        'للمراسلة أو إرسال طلب إشراف يجب تسجيل الدخول أولاً.',
        'You must sign in to message or send a supervision request.',
      )),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(dialogContext.t('لاحقاً', 'Later')),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
          child: Text(dialogContext.t('تسجيل الدخول', 'Sign in')),
        ),
      ],
    ),
  );
}

Future<void> _showInfoDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(dialogContext.t('حسناً', 'OK')),
        ),
      ],
    ),
  );
}

String? _encodeQuery(Map<String, String> params) {
  if (params.isEmpty) return null;
  return params.entries
      .map(
        (e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
      )
      .join('&');
}
