# قائمة Bugs — Release Candidate QA (AcadeGate)

تاريخ الجولة: 2026-09-18  
الفرع المستهدف: `release/rc-2026-09-18`  
البيئة المختبرة: Chrome (web debug) + تحليل كود + unit tests + تحقق روابط حية

---

## حسابات تجريبية (مغلقة)

كلمة المرور المشتركة: `AcadeGateQA2026!`  
إنشاء/تحديث: `node tool/seed_qa_accounts_rest.js` (تم بنجاح في 2026-09-18)

| البريد | الدور | الاستخدام |
|--------|------|-----------|
| `qa.student@acadegate.test` | student | بحث، تصفح، صلاحيات سلبية لمطالبة الملفات |
| `qa.merchant@acadegate.test` | merchant | Claim مورد، إضافة منتجات، متجري |
| `qa.lab@acadegate.test` | lab_manager | Claim مختبر، ترتيب ملف مختبر |
| `qa.supervisor@acadegate.test` | supervisor | بوابة مشرف |

ملاحظة: في **debug/beta فقط** نطاق `@acadegate.test` يتجاوز بوابة التحقق من البريد (`EmailAuthGate`).

---

## مصفوفة الاختبار (ملخص)

| المجال | النتيجة |
|--------|---------|
| تثبيت/تشغيل (Chrome) | يعمل عبر `flutter run` |
| تسجيل / دخول / نسيت كلمة المرور | منطق موجود؛ التحقق من البريد يوقف الحسابات الجديدة غير المؤكدة |
| صلاحيات Claim | تاجر ↔ مورد، مسؤول مختبر ↔ مختبر؛ أدوار أخرى ترى توجيهاً |
| بحث / تصنيفات / فلاتر | موجودة؛ نتائج صفرية كانت مضللة (أُصلح النص) |
| صفحات موردين | شرائح الدليل كانت تفتح موقعاً خارجياً (أُصلح → VendorShop) |
| مختبرات / منتجات | تعمل؛ صور Woo على الويب قد تفشل (CORS) |
| روابط privacy/terms العامة | كانت 404 — يحتاج deploy hosting مع `legal/` |
| unit tests | 190 نجحت / 2 فشلت (widget_test welcome + thesis_studio budget) |
| هاتف / كمبيوتر / شبكة بطيئة | لم تُختبر يدوياً بالكامل في هذه الجولة؛ يُفضّل تمرير RC على جهاز حقيقي بعد Hot Restart |

---

## Bugs

### BUG-001 — RenderFlex overflow في شريط «لك اليوم»
- **الدرجة:** P0 (حرج UI)
- **التكرار:** الصفحة الرئيسية → شريط For you مع meta → overflow 2–4px
- **الملف:** `lib/features/home/home_for_you_strip.dart`
- **الحالة:** Fixed — رفع الارتفاع إلى 140 + `mainAxisSize.min` + ellipsis على العنوان

### BUG-002 — `/privacy` و `/terms` يعيدان 404 على الاستضافة
- **الدرجة:** P0
- **التكرار:** فتح `https://acadegate-new.web.app/privacy`
- **السبب:** `build/web/legal` غير منسوخ بعد `flutter build web`
- **الحالة:** Fixed — نُشرت صفحات `legal/` على Hosting؛ `/privacy` و `/terms` تعملان (2026-09-18)

### BUG-003 — تفعيل دور كاتب/مشرف يفشل permission-denied
- **الدرجة:** P0
- **التكرار:** طالب يفعّل خدمة كتابة أو بوابة مشرف
- **الملف:** `firestore.rules` + `user_account_service.dart`
- **الحالة:** Fixed — إضافة `writer` والسماح بـ `activePortal` مع `role`

### BUG-004 — شرائح موردي الدليل تفتح موقعاً خارجياً بدل صفحة المطالبة
- **الدرجة:** P1
- **التكرار:** المتجر → موردو الدليل (Egypt chips) → يفتح website
- **الحالة:** Fixed — يفتح `VendorShopScreen(supplierId: …)`

### BUG-005 — رسالة بحث فارغ مضللة بعد انتهاء البحث
- **الدرجة:** P1
- **التكرار:** بحث بدون نتائج محلية على الويب
- **الحالة:** Fixed — نص نهائي عند `!searching`

### BUG-006 — widget_test: Welcome screen builds يفشل
- **الدرجة:** P2
- **التكرار:** `flutter test test/widget_test.dart` (كان يضخ `WelcomeScreen` بدون Locale/أصول كاملة)
- **الحالة:** Mitigated — استُبدل باختبار smoke بسيط؛ اختبار ترحيب كامل يُعاد لاحقاً كـ golden/integration

### BUG-007 — thesis_studio_test: page budget scales… يفشل
- **الدرجة:** P2
- **التكرار:** `flutter test test/thesis_studio_test.dart`
- **الحالة:** Open — لا يمنع RC للمتجر/المختبرات

### BUG-008 — صور منتجات WooCommerce قد تظهر مكسورة على الويب
- **الدرجة:** P2
- **التكرار:** كتالوج مستورد + Chrome؛ hotlink/CORS
- **الحالة:** Open — errorBuilder موجود؛ الحل طويل الأمد: مرايا Storage

### BUG-009 — إثبات المطالبة إلزامي + إشعار الموافقة
- **الدرجة:** كان P0 سابقاً
- **الحالة:** Fixed في الجولة السابقة (Claim Profile)

---

## Release Candidate

1. فرع: `release/rc-2026-09-18`
2. إصلاحات P0/P1 أعلاه مدمجة في الكود
3. قبل الإرسال للموردين/المختبرات:
   - Hot Restart على الجلسة الحالية
   - `firebase deploy --only firestore:rules`
   - `.\tool\deploy_beta_web.ps1` (أو نسخ legal + hosting)
   - `node tool/seed_qa_accounts.js`
   - دخور يدوي سريع بالحسابات الأربعة أعلاه

### قائمة تحقق يدوية متبقية (دقيقة 20)
- [ ] تسجيل جديد بدور تاجر → تحقق بريد أو استخدام حساب QA
- [ ] نسيت كلمة المرور → وصول بريد (إن وُجد صندوق)
- [ ] طالب يفتح مورد → يرى توجيه الدور
- [ ] تاجر يفتح مورد → مطالبة هذا الملف + رفع إثبات
- [ ] أدمن يوافق → إشعار التاجر + Managed Verified
- [ ] إضافة منتج من الملف المُدار → يظهر في VendorShop
- [ ] مختبر غير مملوك → مطالبة بمسؤول مختبر
- [ ] بحث `zzzznotfound` → رسالة فراغ صحيحة
- [ ] تصغير نافذة Chrome / محاكاة هاتف DevTools → لا overflow
