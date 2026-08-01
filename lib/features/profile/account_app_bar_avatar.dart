import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/locale/locale_extensions.dart';
import '../auth/user_account_service.dart';
import 'account_profile_screen.dart';

/// أيقونة الحساب في شريط التطبيق — تعرض صورة المستخدم إن وُجدت.
class AccountAppBarAvatar extends StatelessWidget {
  const AccountAppBarAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) return const SizedBox.shrink();

    return StreamBuilder(
      stream: UserAccountService.instance.watchCurrentAccount(),
      builder: (context, snapshot) {
        final account = snapshot.data;
        final photoUrl = (account?.photoUrl?.trim().isNotEmpty == true)
            ? account!.photoUrl!.trim()
            : (authUser.photoURL?.trim() ?? '');
        final name = (account?.displayName.trim().isNotEmpty == true)
            ? account!.displayName.trim()
            : (authUser.displayName?.trim() ??
                authUser.email?.split('@').first ??
                '?');
        final initial = name.isNotEmpty ? name.characters.first : '?';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Tooltip(
            message: context.t('حسابي', 'My account'),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AccountProfileScreen(),
                  ),
                );
              },
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage:
                    photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                child: photoUrl.isEmpty
                    ? Text(
                        initial.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }
}
