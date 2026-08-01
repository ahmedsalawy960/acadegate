# إصلاح تسجيل الدخول بـ Facebook

الخطأ الشائع:
`Can't load URL — The domain of this URL isn't included in the app's domains`

يعني تطبيق Facebook لا يعرف نطاق AcadeGate بعد.

---

## 1) Facebook Developers

افتح: https://developers.facebook.com/apps → تطبيقك

### Settings → Basic
أضف في **App Domains**:
- `acadegate-new.firebaseapp.com`
- `acadegate-new.web.app`

**Privacy Policy URL** و **User Data Deletion** مطلوبان غالباً (يمكن وضع صفحة مؤقتة).

احفظ التغييرات.

### Facebook Login → Settings
في **Valid OAuth Redirect URIs** أضف بالضبط:

```
https://acadegate-new.firebaseapp.com/__/auth/handler
```

إن استخدمت Hosting كمدخل أيضاً:

```
https://acadegate-new.web.app/__/auth/handler
```

**Client OAuth Login** و **Web OAuth Login** = مفعّلان.

### Use cases / Permissions
فعّل `email` و `public_profile` للاختبار.

في وضع التطوير (Development): أضف حسابك كمختبِر (Roles → Testers) وإلا لن يعمل إلا مع أدمن التطبيق.

---

## 2) Firebase Console

Authentication → Sign-in method → **Facebook**:
1. فعّل المزود
2. الصق **App ID** و **App Secret** من Facebook → Settings → Basic
3. انسخ **OAuth redirect URI** الظاهر في Firebase وتأكد أنه مطابق لما وضعته في Facebook

Authentication → Settings → **Authorized domains** يجب أن تتضمن:
- `acadegate-new.firebaseapp.com`
- `acadegate-new.web.app`
- `localhost` (للاختبار المحلي)

---

## 3) أين تجرب؟

| المنصة | ملاحظات |
|--------|---------|
| Web المنشور | https://acadegate-new.web.app — الأنسب بعد ضبط النطاقات أعلاه |
| Windows محلي | يحتاج `--dart-define=FACEBOOK_APP_ID=...` وقد يفشل إن لم تُضف نطاقات سطح المكتب؛ فضّل التجربة من الويب أولاً |
| البريد/Google | بديل جاهز للمختبرين دون إعداد Facebook |

---

## بعد التعديل

انتظر دقيقة، ثم جرّب من نافذة خاصة (Incognito) على الرابط المنشور.
