import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';
import '../academic/academic_models.dart';
import 'supervision_request_service.dart';

Future<bool?> showSupervisionRequestDialog(
  BuildContext context, {
  required AcademicSupervisor supervisor,
  required String requestType,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _SupervisionRequestDialog(
      supervisor: supervisor,
      requestType: requestType,
    ),
  );
}

class _SupervisionRequestDialog extends StatefulWidget {
  final AcademicSupervisor supervisor;
  final String requestType;

  const _SupervisionRequestDialog({
    required this.supervisor,
    required this.requestType,
  });

  @override
  State<_SupervisionRequestDialog> createState() =>
      _SupervisionRequestDialogState();
}

class _SupervisionRequestDialogState extends State<_SupervisionRequestDialog> {
  final _messageController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  bool get _isSupervision => widget.requestType == 'supervision';

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      await SupervisionRequestService.instance.submit(
        supervisorDocId: widget.supervisor.id ?? '',
        supervisorName: widget.supervisor.name,
        supervisorUniversity: widget.supervisor.university,
        supervisorOwnerId: widget.supervisor.ownerId,
        requestType: widget.requestType,
        message: _messageController.text,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isSupervision
                ? context.t(
                    'تم إرسال طلب الإشراف — يمكنك متابعته من لوحة المساهمة',
                    'Supervision request sent — track it from the contribution dashboard',
                  )
                : context.t(
                    'تم إرسال رسالتك — سنبلّغ المشرف عند تسجيله',
                    'Your message was sent — we will notify the supervisor when they sign up',
                  ),
          ),
          backgroundColor: Colors.green[700],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isSupervision
          ? context.t('طلب إشراف', 'Supervision request')
          : context.t('رسالة للمشرف', 'Message to supervisor')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.supervisor.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (widget.supervisor.university.isNotEmpty)
              Text(
                widget.supervisor.university,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: _isSupervision
                    ? context.t('عرّف نفسك وموضوع بحثك', 'Introduce yourself and your research topic')
                    : context.t('رسالتك', 'Your message'),
                hintText: _isSupervision
                    ? context.t(
                        'مثال: أنا طالب ماجستير في ... وأرغب بالإشراف على ...',
                        'e.g. I am a master\'s student in ... and would like supervision on ...',
                      )
                    : context.t(
                        'اكتب استفسارك للمشرف',
                        'Write your question for the supervisor',
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
            if (widget.supervisor.ownerId.isEmpty) ...[
              const SizedBox(height: 10),
              Text(
                context.t(
                  'هذا المشرف غير مسجّل بعد في التطبيق — يُحفظ طلبك ويصله عند ربط حسابه.',
                  'This supervisor is not registered in the app yet — your request is saved and delivered when they link their account.',
                ),
                style: TextStyle(fontSize: 12, color: Colors.orange[800]),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: Text(context.t('إلغاء', 'Cancel')),
        ),
        FilledButton(
          onPressed: _sending ? null : _submit,
          child: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.t('إرسال', 'Send')),
        ),
      ],
    );
  }
}
