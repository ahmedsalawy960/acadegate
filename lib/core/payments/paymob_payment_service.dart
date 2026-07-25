import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../firebase/callable_http_client.dart';
import '../locale/app_translate.dart';

enum PaymobOrderKind { store, writing }

class PaymobCheckoutSession {
  final String checkoutUrl;
  final String clientSecret;
  final String publicKey;
  final num amount;
  final String currency;
  final String title;
  final String specialReference;

  const PaymobCheckoutSession({
    required this.checkoutUrl,
    required this.clientSecret,
    required this.publicKey,
    required this.amount,
    required this.currency,
    required this.title,
    required this.specialReference,
  });

  factory PaymobCheckoutSession.fromMap(Map<String, dynamic> map) {
    return PaymobCheckoutSession(
      checkoutUrl: map['checkoutUrl']?.toString() ?? '',
      clientSecret: map['clientSecret']?.toString() ?? '',
      publicKey: map['publicKey']?.toString() ?? '',
      amount: map['amount'] as num? ?? 0,
      currency: map['currency']?.toString() ?? 'EGP',
      title: map['title']?.toString() ?? '',
      specialReference: map['specialReference']?.toString() ?? '',
    );
  }
}

/// Server-backed Paymob checkout (Intention API + Unified Checkout).
class PaymobPaymentService {
  PaymobPaymentService._();

  static final PaymobPaymentService instance = PaymobPaymentService._();

  static bool get _preferHttp =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    if (_preferHttp) {
      return CallableHttpClient.call(
        name: name,
        data: data,
        timeout: const Duration(seconds: 60),
        callableProtocol: true,
      );
    }
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        name,
        options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
      );
      final response = await callable.call<Map<String, dynamic>>(data);
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      if (e.toString().toLowerCase().contains('channel')) {
        return CallableHttpClient.call(
          name: name,
          data: data,
          timeout: const Duration(seconds: 60),
          callableProtocol: true,
        );
      }
      rethrow;
    }
  }

  Future<PaymobCheckoutSession> createCheckout({
    required PaymobOrderKind kind,
    required String orderId,
    String? serviceId,
    String? phone,
  }) async {
    final data = <String, dynamic>{
      'kind': kind == PaymobOrderKind.store ? 'store' : 'writing',
      'orderId': orderId,
      if (serviceId != null && serviceId.isNotEmpty) 'serviceId': serviceId,
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
    };

    try {
      final result = await _call('createPaymobCheckout', data);
      final session = PaymobCheckoutSession.fromMap(result);
      if (session.checkoutUrl.isEmpty) {
        throw Exception(appTr(
          'تعذر إنشاء رابط الدفع',
          'Could not create payment link',
        ));
      }
      return session;
    } on FirebaseFunctionsException catch (e) {
      throw Exception(_mapError(e.code, e.message));
    } on CallableHttpException catch (e) {
      throw Exception(_mapError(e.code, e.message));
    }
  }

  Future<void> openCheckout(PaymobCheckoutSession session) async {
    final uri = Uri.parse(session.checkoutUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      throw Exception(appTr(
        'تعذر فتح صفحة الدفع',
        'Could not open payment page',
      ));
    }
  }

  /// Create checkout and open Paymob Unified Checkout in the browser.
  Future<PaymobCheckoutSession> payAndOpen({
    required PaymobOrderKind kind,
    required String orderId,
    String? serviceId,
    String? phone,
  }) async {
    final session = await createCheckout(
      kind: kind,
      orderId: orderId,
      serviceId: serviceId,
      phone: phone,
    );
    await openCheckout(session);
    return session;
  }

  Future<void> confirmDeliveryRelease({
    required PaymobOrderKind kind,
    required String orderId,
    String? serviceId,
    int? rating,
  }) async {
    final data = <String, dynamic>{
      'kind': kind == PaymobOrderKind.store ? 'store' : 'writing',
      'orderId': orderId,
      if (serviceId != null && serviceId.isNotEmpty) 'serviceId': serviceId,
      if (rating != null) 'rating': rating,
    };
    try {
      await _call('confirmEscrowRelease', data);
    } on FirebaseFunctionsException catch (e) {
      throw Exception(_mapError(e.code, e.message));
    } on CallableHttpException catch (e) {
      throw Exception(_mapError(e.code, e.message));
    }
  }

  String _mapError(String code, String? message) {
    switch (code) {
      case 'unauthenticated':
        return appTr('يجب تسجيل الدخول للدفع', 'Sign in to pay');
      case 'failed-precondition':
        return message?.isNotEmpty == true
            ? message!
            : appTr(
                'بوابة الدفع غير مضبوطة أو الطلب غير قابل للدفع',
                'Payment gateway not configured or order not payable',
              );
      case 'permission-denied':
        return appTr('غير مصرح', 'Not authorized');
      case 'not-found':
        return appTr('الطلب غير موجود', 'Order not found');
      default:
        return message?.isNotEmpty == true
            ? message!
            : appTr('تعذر إتمام الدفع', 'Payment failed');
    }
  }
}
