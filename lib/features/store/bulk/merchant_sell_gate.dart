import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/locale/locale_extensions.dart';
import '../../auth/provider_publish_gate.dart';
import '../../auth/user_account.dart';
import '../../auth/user_account_service.dart';
import '../../auth/user_role.dart';

/// Ensures the signed-in user may write products (merchant role + not
/// rejected). Offers to enable the merchant role. Returns null when blocked.
Future<UserAccount?> ensureMerchantCanSell(BuildContext context) async {
  void fail(String ar, String en) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.t(ar, en)),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    fail('يجب تسجيل الدخول لإضافة منتج', 'You must sign in to add a product');
    return null;
  }

  await UserAccountService.instance.ensureAccountExists(user);
  var account = await UserAccountService.instance.loadCurrentAccount();
  if (!UserRole.canSellProducts(account?.role)) {
    if (!context.mounted) return null;
    final enable = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('تفعيل حساب تاجر؟', 'Enable merchant account?')),
        content: Text(
          ctx.t(
            'حسابك الحالي ليس بدور تاجر/مورد. لتتمكن من حفظ المنتجات، فعّل دور التاجر لهذا الحساب.',
            'Your account is not a merchant/supplier. Enable the merchant role to save products.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.t('تفعيل وحفظ', 'Enable & save')),
          ),
        ],
      ),
    );
    if (enable != true) return null;
    try {
      await UserAccountService.instance.enableMerchantSelling();
      account = await UserAccountService.instance.loadCurrentAccount();
    } catch (e) {
      fail('تعذر تفعيل دور التاجر: $e', 'Could not enable merchant role: $e');
      return null;
    }
    if (!UserRole.canSellProducts(account?.role)) {
      fail(
        'ما زال الحساب بدون صلاحية بيع. سجّل حساباً بدور تاجر أو تواصل مع الإدارة.',
        'Account still cannot sell. Register as a merchant or contact admin.',
      );
      return null;
    }
  }

  if (!ProviderPublishGate.canSubmitContent(account)) {
    fail(
      ProviderPublishGate.blockMessageAr(account),
      ProviderPublishGate.blockMessageEn(account),
    );
    return null;
  }
  return account;
}
