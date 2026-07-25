# تفعيل بوابة الدفع Paymob (مصر)

AcadeGate يستخدم **Paymob Intention API + Unified Checkout**.  
حالة الدفع (`paid_held` / `released`) تُحدَّث فقط عبر **Webhook** بعد التحقق من HMAC — وليس من التطبيق.

## 1) حساب Paymob

1. سجّل في [Paymob](https://accept.paymob.com) (وضع الاختبار أولاً).
2. من لوحة التحكم انسخ:
   - **Secret Key** (`sk_test_…` ثم لاحقاً `sk_live_…`)
   - **Public Key** (`pk_test_…`)
   - **HMAC Secret**
   - **Integration ID** لطريقة البطاقة (رقم التكامل)

## 2) أسرار Firebase

```bash
firebase functions:secrets:set PAYMOB_SECRET_KEY
firebase functions:secrets:set PAYMOB_PUBLIC_KEY
firebase functions:secrets:set PAYMOB_HMAC_SECRET
firebase functions:secrets:set PAYMOB_INTEGRATION_ID
```

عند كل أمر: الصق القيمة ثم Enter (لا تتركها فارغة).

## 3) نشر الدوال

```bash
firebase deploy --only functions:createPaymobCheckout,functions:paymobWebhook,functions:confirmEscrowRelease
```

رابط الـ Webhook (يُضبط تلقائياً في نية الدفع):

`https://us-central1-acadegate-new.cloudfunctions.net/paymobWebhook`

في لوحة Paymob تأكد أن Callbacks / Transaction processed مفعّلة للمشروع.

## 4) التدفق في التطبيق

عند الشراء يظهر اختيار:
- **دفع إلكتروني (Paymob)** — يحتاج أسرار Paymob أدناه.
- **تحويل يدوي / تواصل للدفع** — يعمل بدون تسجيل شركة؛ يُنشأ طلب `paymentMethod=manual` ويتواصل المشتري مع البائع، ثم يؤكد البائع استلام التحويل.

تدفق Paymob:
1. إنشاء طلب متجر أو كتابة.
2. `createPaymobCheckout` → يفتح Unified Checkout في المتصفح.
3. بعد نجاح الدفع: `paymobWebhook` يضع `paymentStatus = paid_held`.
4. عند تأكيد الاستلام: `confirmEscrowRelease` يضع `released`.

## 5) اختبار

استخدم بطاقات اختبار Paymob في وضع test.  
إذا ظهر «Paymob غير مضبوط» فالأسرار غير معيّنة أو لم تُنشر الدوال بعد.
