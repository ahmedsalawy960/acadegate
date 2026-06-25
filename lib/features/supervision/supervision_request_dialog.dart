import 'package:flutter/material.dart';

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
                ? 'تم إرسال طلب الإشراف — يمكنك متابعته من لوحة المساهمة'
                : 'تم إرسال رسالتك — سنبلّغ المشرف عند تسجيله',
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
      title: Text(_isSupervision ? 'طلب إشراف' : 'رسالة للمشرف'),
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
                    ? 'عرّف نفسك وموضوع بحثك'
                    : 'رسالتك',
                hintText: _isSupervision
                    ? 'مثال: أنا طالب ماجستير في ... وأرغب بالإشراف على ...'
                    : 'اكتب استفسارك للمشرف',
                border: const OutlineInputBorder(),
              ),
            ),
            if (widget.supervisor.ownerId.isEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'هذا المشرف غير مسجّل بعد في التطبيق — يُحفظ طلبك ويصله عند ربط حسابه.',
                style: TextStyle(fontSize: 12, color: Colors.orange[800]),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _sending ? null : _submit,
          child: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('إرسال'),
        ),
      ],
    );
  }
}
