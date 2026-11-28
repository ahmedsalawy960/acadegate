import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../core/firebase/callable_http_client.dart';

/// Fan-out in-app notifications to every admin account.
///
/// Admins are resolved server-side by the notifyAdmins callable. Clients no
/// longer query users by role: the users read rule is owner/admin only.
class AdminRecipientService {
  AdminRecipientService._();

  static final AdminRecipientService instance = AdminRecipientService._();

  static bool get _preferHttpCallable =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  /// Best-effort: a notification failure never blocks the caller's flow.
  Future<void> notifyAllAdmins({
    required String title,
    required String body,
    required String type,
    String contextId = '',
    String contextType = '',
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      'body': body,
      'type': type,
      if (contextId.isNotEmpty) 'contextId': contextId,
      if (contextType.isNotEmpty) 'contextType': contextType,
    };
    try {
      if (_preferHttpCallable) {
        await CallableHttpClient.call(
          name: 'notifyAdmins',
          data: payload,
          timeout: const Duration(seconds: 30),
          callableProtocol: true,
        );
        return;
      }

      final callable = FirebaseFunctions.instance.httpsCallable(
        'notifyAdmins',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );
      await callable.call(payload);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('notifyAdmins failed: $e');
      }
      // Fallback for channel errors on desktop.
      if (!_preferHttpCallable &&
          e.toString().toLowerCase().contains('channel')) {
        try {
          await CallableHttpClient.call(
            name: 'notifyAdmins',
            data: payload,
            timeout: const Duration(seconds: 30),
            callableProtocol: true,
          );
        } catch (fallbackError) {
          if (kDebugMode) {
            debugPrint('notifyAdmins fallback failed: $fallbackError');
          }
        }
      }
    }
  }
}
