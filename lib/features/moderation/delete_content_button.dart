import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/locale/l10n_lookup.dart';
import '../academic/demo_supervisor_hide_service.dart';
import '../auth/user_account_service.dart';
import '../auth/user_role.dart';
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
  final bool isDemo;
  final Color? iconColor;

  const DeleteContentButton({
    super.key,
    required this.collection,
    required this.documentId,
    required this.ownerId,
    required this.itemLabel,
    this.onDeleted,
    this.asAppBarAction = true,
    this.asFullWidthButton = false,
    this.isDemo = false,
    this.iconColor,
  });

  bool _canDeleteFromAccount({
    required bool? isAdmin,
    required String? uid,
  }) {
    if (isDemo) return isAdmin == true;
    if (isAdmin == true) return true;
    if (uid == null || uid.isEmpty) return false;
    return ownerId != null && ownerId!.isNotEmpty && ownerId == uid;
  }

  @override
  Widget build(BuildContext context) {
    if (documentId == null || documentId!.isEmpty) {
      return const SizedBox.shrink();
    }

    final color = iconColor ?? Colors.red[400];

    return StreamBuilder(
      stream: UserAccountService.instance.watchCurrentAccount(),
      builder: (context, snapshot) {
        final account = snapshot.data;
        final uid = FirebaseAuth.instance.currentUser?.uid;
        final allowed = isDemo
            ? account?.isAdmin == true
            : _canDeleteFromAccount(
                isAdmin: account?.isAdmin == true ||
                    account?.role == UserRole.admin,
                uid: uid,
              );

        if (!allowed) return const SizedBox.shrink();

        Future<void> handleDelete() async {
          final deleted = isDemo
              ? await DemoSupervisorHideService.instance.confirmAndHide(
                  context,
                  demoId: documentId!,
                  itemLabel: itemLabel,
                )
              : await ContentDeleteService.instance.confirmAndDelete(
                  context,
                  collection: collection,
                  documentId: documentId!,
                  itemLabel: itemLabel,
                );
          if (!context.mounted || !deleted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(L10nLookup.itemDeleted(itemLabel)),
              behavior: SnackBarBehavior.floating,
            ),
          );
          onDeleted?.call();
          if (onDeleted == null) Navigator.pop(context);
        }

        if (asAppBarAction) {
          return IconButton(
            tooltip: L10nLookup.delete,
            icon: Icon(Icons.delete_outline, color: color),
            onPressed: handleDelete,
          );
        }

        if (asFullWidthButton) {
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: OutlinedButton.icon(
              onPressed: handleDelete,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: Text(
                L10nLookup.deleteFromApp,
                style: const TextStyle(color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          );
        }

        return IconButton(
          tooltip: L10nLookup.delete,
          onPressed: handleDelete,
          icon: Icon(Icons.delete_outline, color: color),
        );
      },
    );
  }
}

/// زر حذف بعرض كامل أسفل الشاشة.
class ManageContentActions extends StatelessWidget {
  final String collection;
  final String? documentId;
  final String? ownerId;
  final String itemLabel;
  final VoidCallback? onDeleted;
  final bool isDemo;

  const ManageContentActions({
    super.key,
    required this.collection,
    required this.documentId,
    required this.ownerId,
    required this.itemLabel,
    this.onDeleted,
    this.isDemo = false,
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
          isDemo: isDemo,
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
  bool isDemo = false,
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
      isDemo: isDemo,
    ),
  ];
}
