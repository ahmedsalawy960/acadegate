import 'package:flutter/material.dart';

import 'content_delete_service.dart';

/// زر حذف يظهر للمدير أو مالك المحتوى.
class DeleteContentButton extends StatelessWidget {
  final String collection;
  final String? documentId;
  final String? ownerId;
  final String itemLabel;
  final VoidCallback? onDeleted;
  final bool asAppBarAction;
  final bool asFullWidthButton;

  const DeleteContentButton({
    super.key,
    required this.collection,
    required this.documentId,
    required this.ownerId,
    required this.itemLabel,
    this.onDeleted,
    this.asAppBarAction = true,
    this.asFullWidthButton = false,
  });

  @override
  Widget build(BuildContext context) {
    if (documentId == null || documentId!.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<bool>(
      future: ContentDeleteService.instance.canDelete(ownerId: ownerId),
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();

        Future<void> handleDelete() async {
          final deleted = await ContentDeleteService.instance.confirmAndDelete(
            context,
            collection: collection,
            documentId: documentId!,
            itemLabel: itemLabel,
          );
          if (!context.mounted || !deleted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم حذف «$itemLabel»'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          onDeleted?.call();
          if (onDeleted == null) Navigator.pop(context);
        }

        if (asAppBarAction) {
          return IconButton(
            tooltip: 'حذف',
            icon: const Icon(Icons.delete_outline),
            onPressed: handleDelete,
          );
        }

        if (asFullWidthButton) {
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: OutlinedButton.icon(
              onPressed: handleDelete,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text(
                'حذف من التطبيق',
                style: TextStyle(color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          );
        }

        return IconButton(
          onPressed: handleDelete,
          icon: const Icon(Icons.delete_outline, color: Colors.red),
        );
      },
    );
  }
}

/// زر حذف + زر AppBar معاً في أسفل الشاشة وشريط العنوان.
class ManageContentActions extends StatelessWidget {
  final String collection;
  final String? documentId;
  final String? ownerId;
  final String itemLabel;
  final VoidCallback? onDeleted;

  const ManageContentActions({
    super.key,
    required this.collection,
    required this.documentId,
    required this.ownerId,
    required this.itemLabel,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DeleteContentButton(
          collection: collection,
          documentId: documentId,
          ownerId: ownerId,
          itemLabel: itemLabel,
          onDeleted: onDeleted,
          asAppBarAction: false,
          asFullWidthButton: true,
        ),
      ],
    );
  }
}

/// للـ AppBar.actions
List<Widget> deleteAppBarActions({
  required String collection,
  required String? documentId,
  required String? ownerId,
  required String itemLabel,
  VoidCallback? onDeleted,
}) {
  if (documentId == null || documentId.isEmpty) return const [];

  return [
    DeleteContentButton(
      collection: collection,
      documentId: documentId,
      ownerId: ownerId,
      itemLabel: itemLabel,
      onDeleted: onDeleted,
      asAppBarAction: true,
    ),
  ];
}
