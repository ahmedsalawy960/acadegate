# نشر AcadeGate على الويب (Firebase Hosting)

الهدف: رابط عام يفتحه المختبرون من المتصفح بدون تثبيت.

**الرابط المتوقع بعد النشر**
- https://acadegate-new.web.app
- https://acadegate-new.firebaseapp.com

---

## المتطلبات مرة واحدة

1. تثبيت Firebase CLI:
   ```powershell
   npm install -g firebase-tools
   ```
2. تسجيل الدخول:
   ```powershell
   firebase login
   ```
3. التأكد من المشروع:
   ```powershell
   firebase use acadegate-new
   ```

---

## النشر (كل تحديث)

من جذر المشروع:

```powershell
flutter build web --release
firebase deploy --only hosting
```

أو سكربت واحد:

```powershell
.\scripts\deploy-web.ps1
```

---

## بعد أول نشر — تحقق سريع

1. افتح الرابط في متصفح خاص (Incognito)
2. أنشئ حساباً جديداً بالبريد
3. إن فشل Google Sign-In: Firebase Console → Authentication → Settings → Authorized domains  
   وتأكد من وجود `acadegate-new.web.app` و `acadegate-new.firebaseapp.com`
4. أرسل الرابط للمختبر مع: تسجيل → بوابة مستخدم → تجربة المتجر/الرسائل

---

## ملاحظات

- `firebase.json` يوجّه Hosting إلى `build/web` مع rewrite لـ SPA
- الصفحة موضوعة `noindex` حتى لا تظهر في محركات البحث أثناء البيتا
- لا تشارك ملفات الأسرار (`dart_defines.json` / `.env`)
- Paymob Live غير مطلوب للبيتا — التحويل اليدوي كافٍ

---

## استكشاف أعطال شائعة

| العرض | الحل |
|------|------|
| صفحة بيضاء | افتح F12 → Console؛ أعد البناء والنشر |
| فشل تسجيل الدخول | Authorized domains + تفعيل Email/Password في Auth |
| بيانات لا تظهر | اتصال الشبكة / قواعد Firestore |
| نسخة قديمة عند المختبر | Ctrl+F5 أو نافذة خاصة |
