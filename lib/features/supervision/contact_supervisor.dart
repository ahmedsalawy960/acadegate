import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../academic/academic_models.dart';
import '../auth/login_screen.dart';
import '../messaging/chat_screen.dart';
import '../messaging/messaging_models.dart';
import '../messaging/messaging_service.dart';
import 'supervision_request_dialog.dart';

/// يفتح دائماً واجهة مرئية: محادثة، نموذج رسالة، أو طلب تسجيل دخول.
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
        title: 'ملفك كمشرف',
        message:
            'هذا ملفك الذي سجّلته أنت. الطلاب هم من يراسلونك — ستصلك رسائلهم من أيقونة «الرسائل» في الصفحة الرئيسية أو لوحة المساهمة.',
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
              'مراسلة ${supervisor.name}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              supervisor.isImportedListing
                  ? 'هذا المشرف مدرج من قاعدة بيانات أكاديمية. أرسل رسالة أو طلب إشراف وسنحفظه حتى يربط المشرف حسابه.'
                  : 'المشرف غير مرتبط بحساب داخل التطبيق بعد. اختر طريقة التواصل:',
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
              label: const Text('إرسال رسالة داخل التطبيق'),
            ),
            if (supervisor.universityEmail.isNotEmpty) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  await _openUniversityEmail(context, supervisor);
                },
                icon: const Icon(Icons.alternate_email),
                label: Text('البريد الجامعي: ${supervisor.universityEmail}'),
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
    builder: (_) => const Center(
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('جاري فتح المحادثة...'),
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
      title: 'تعذر فتح المحادثة',
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
      'subject': 'تواصل عبر AcadeGate — ${supervisor.name}',
      'body':
          'السلام عليكم د.${supervisor.name},\n\nأتواصل معكم عبر تطبيق AcadeGate بخصوص ...\n',
    }),
  );

  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    await _showInfoDialog(
      context,
      title: 'البريد الجامعي',
      message:
          'لم يُعثر على تطبيق بريد على الجهاز.\n\nانسخ العنوان:\n${supervisor.universityEmail}',
    );
  }
}

Future<void> _showLoginRequiredDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('تسجيل الدخول مطلوب'),
      content: const Text(
        'للمراسلة أو إرسال طلب إشراف يجب تسجيل الدخول أولاً.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('لاحقاً'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
          child: const Text('تسجيل الدخول'),
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
          child: const Text('حسناً'),
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
