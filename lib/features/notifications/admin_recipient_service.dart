import '../auth/user_account.dart';
import '../auth/user_account_service.dart';
import '../auth/user_role.dart';
import 'notification_service.dart';

/// Fan-out in-app notifications to every admin account.
class AdminRecipientService {
  AdminRecipientService._();

  static final AdminRecipientService instance = AdminRecipientService._();

  Future<List<UserAccount>> loadAdmins() async {
    final snapshot = await UserAccountService.instance.usersCollection
        .where('role', isEqualTo: UserRole.admin)
        .get();
    return snapshot.docs
        .map((doc) => UserAccount.fromMap(doc.data(), uid: doc.id))
        .toList();
  }

  Future<void> notifyAllAdmins({
    required String title,
    required String body,
    required String type,
    String contextId = '',
    String contextType = '',
  }) async {
    final admins = await loadAdmins();
    for (final admin in admins) {
      try {
        await NotificationService.instance.send(
          userId: admin.uid,
          title: title,
          body: body,
          type: type,
          contextId: contextId,
          contextType: contextType,
        );
      } catch (_) {
        // Continue notifying remaining admins.
      }
    }
  }
}
