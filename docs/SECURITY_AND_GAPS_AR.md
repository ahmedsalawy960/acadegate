# AcadeGate — سجل الثغرات والميزات الناقصة

مراجعة ثابتة للكود (Flutter + Firestore/Storage + Cloud Functions).  
الغرض: فهم المخاطر وإصلاحها، وليس استغلال أنظمة الغير.

---

## أ) الثغرات الأمنية — الوصف وكيفية الاستغلال (للمطورين)

### حرج

#### 1) تزوير حالة الدفع / الضمان (escrow)
- **أين:** `firestore.rules` → `store_orders` / `writing_orders` · `lib/core/escrow/escrow_service.dart`
- **ما المشكلة:** العميل يستطيع تحديث `paymentStatus` إلى `paid_held` أو `released` دون بوابة دفع.
- **كيف تُستغل:** مستخدم مسجّل ينشئ طلباً ثم يكتب مباشرة على وثيقة الطلب في Firestore فيغيّر الحالة إلى «مدفوع/محجوز» فيبدو أنه دفع دون تحويل مال.
- **الإصلاح:** منع العميل من كتابة `paymentStatus`؛ الانتقالات عبر Cloud Functions أو webhook بوابة الدفع فقط.

#### 2) قراءة ملفات Storage عبر المستخدمين
- **أين:** `storage.rules` — `allow read: if request.auth != null` على `uploads/{userId}/**` و `publish/{userId}/**`
- **ما المشكلة:** أي مستخدم مسجّل يقرأ ملفات مستخدم آخر إذا عرف المسار.
- **كيف تُستغل:** تخمين/تسريب مسار مثل `uploads/{uid}/viva/thesis.pdf` ثم تنزيل ملف الرسالة أو المسودة.
- **الإصلاح:** قراءة لصاحب الملف فقط (`request.auth.uid == userId`).

#### 3) Webhook Copyleaks بدون تحقق
- **أين:** `functions/originality_handlers.js` → `copyleaksWebhook`
- **ما المشكلة:** أي طلب POST عام يمكنه الكتابة على `originality_scans/{scanId}`.
- **كيف تُستغل:** إرسال JSON مزيف إلى رابط الـ webhook مع `scanId` معروف لتلطيخ نتيجة فحص التشابه.
- **الإصلاح:** سر مشترك / توقيع HMAC؛ رفض الطلبات غير الموقّعة.

#### 4) SSRF عبر `fileUrl` في استخراج المستندات
- **أين:** `functions/publish_extract.js` → `downloadFileBuffer(fileUrl)`
- **ما المشكلة:** الدالة تجلب أي URL بعد مصادقة المستخدم.
- **كيف تُستغل:** تمرير عناوين داخلية (`169.254.169.254` أو خدمات الشبكة الخاصة) عبر `fileUrl`.
- **الإصلاح:** السماح بـ Storage للمستخدم أو قائمة بيضاء للمضيفين + حظر IP خاص.

---

### عالي

#### 5) مفتاح Gemini داخل بناء العميل
- **أين:** `gemini_advisor_client.dart` + `dart_defines.json`
- **الاستخدام الخبيث:** استخراج المفتاح من ثنائي Windows/APK واستخدامه لاستنزاف الحصة.
- **الإصلاح:** Cloud Function فقط في الإنتاج + App Check + حدود لكل UID.

#### 6) دوال HTTP عامة (RSS / Citation)
- **أين:** `science_news_rss.js` · `citation_proxy.js`
- **الاستخدام الخبيث:** استدعاء متكرر من الإنترنت بدون حساب لاستنزاف الحصة/التكلفة.
- **الإصلاح:** Auth أو App Check + rate limit.

#### 7) SSRF في استخراج أدلة المجلات
- **أين:** `journal_guidelines.js` → `fetchPage`
- **الاستخدام الخبيث:** نفس فكرة #4 عبر `manualUrl` بعد تسجيل الدخول.
- **الإصلاح:** Allowlist + حظر الشبكات الخاصة.

#### 8) إشعارات مزيفة لأي مستخدم
- **أين:** `firestore.rules` notifications · `NotificationService`
- **الاستخدام الخبيث:** إنشاء إشعار «تم تحرير الدفع» لمستخدم آخر لتصيّده داخل التطبيق.
- **الإصلاح:** إنشاء الإشعارات من Cloud Functions فقط.

#### 9) شاشات الإدارة بلا بوابة واجهة كافية
- **أين:** `admin_moderation_screen.dart` وغيرها
- **الاستخدام الخبيث:** التنقل للشاشة ومحاولة عمليات؛ القواعد تمنع الكتابة اليوم لكن الواجهة تكشف مسارات الإدارة.
- **الإصلاح:** فحص `isAdmin` قبل عرض الشاشة + callables حساسة.

#### 10) هاش كلمات غرف البحث ضعيف / قديم
- **أين:** `functions/research_rooms.js` (SHA-256 بدون ملح) · حقول legacy
- **الاستخدام الخبيث:** إن وُجد `passwordHash` على وثيقة الغرفة يُكسر offline بسهولة.
- **الإصلاح:** Argon2/bcrypt + ملح؛ إزالة الهاش من وثائق الغرف.

---

### متوسط / منخفض (ملخص)

| # | الثغرة | كيف تُستغل باختصار |
|---|--------|-------------------|
| 11 | تضخيم العدادات | تحديث `votesCount` مباشرة دون تصويت حقيقي |
| 12 | قراءة كل المقترحات | أي مسجّل يقرأ proposals لكل الأفكار |
| 13 | `topic_claims` عامة | قراءة بدون تسجيل دخول لأسماء الحجوزات |
| 14 | كتالوج عام | سحب `categories` / `store_suppliers` بدون حساب (مقصود غالباً) |
| 15 | لا App Check / حصص AI | حسابات وهمية تحرق Gemini/Copyleaks |
| 16 | `systemPrompt` من العميل | حقن تعليمات لتجاوز سياسة المساعد |
| 17 | الثقة في MIME + روابط تنزيل | رفع ملف بنوع مزيف؛ تسريب download URL |
| 18–22 | مسارات/خصوصية/ضيف/تخزين محلي | مخاطر متبقية أقل حدة |
| 23–27 | مفاتيح Firebase / CORS / hygiene | متوقعة أو منخفضة إن ضُبطت القيود |

---

## ب) الميزات الناقصة أو غير المكتملة

### P0 — أولوية إطلاق / ثقة
1. **بوابة دفع حقيقية** (Paymob/Fawry/Stripe) بدل أعلام Firestore.
2. **إرسال FCM من السيرفر** — التوكن يُحفظ لكن لا يوجد `admin.messaging().send`.
3. **بيانات حقيقية** بدل مشرفين/مختبرات demo في المطابقة والحجز.
4. **تفعيل صندوق التمويل** أو إخفاؤه من الترحيب/الرئيسية حتى يُعدّ.
5. **نشر أسرار فحص الأصالة** + الدوال، أو تخفيف وعود الترحيب.
6. **اختبارات آلية** لمسارات المال/المصادقة/المطابقة.
7. **تهيئة Google Sign-In على Windows** (`GOOGLE_WEB_CLIENT_ID`).

### P1 — جودة المنتج
- أسعار متجر للمنتجات المستوردة؛ تفاعل أفكار/مختبرات غير demo.
- Offline أوسع + شريط انقطاع الشبكة.
- Accessibility (`Semantics`).
- إصلاح CORS لاستيراد NBSLE ومتجر WooCommerce على الويب.
- Facebook/Apple حيث ينطبق؛ ثبات جلسات محاكي المناقشة.
- منهجية أعمق بدون الاعتماد الكلي على السحابة.

### P2 — تحسينات
- إبراز سلامة أكاديمية في الرئيسية.
- دعم Linux في `firebase_options`.
- طبقة أخطاء موحدة؛ أدوات إدارة أعمق.

---

## ج) حالة الإصلاح في المستودع

| البند | الحالة |
|------|--------|
| قراءة Storage لصاحب الملف | تم في `storage.rules` |
| قفل `paymentStatus` على العميل | تم في `firestore.rules` + واجهة المتجر |
| نصوص الضمان الصادقة | تم — «طلب شراء» بدل ادعاء ضمان وهمي |
| SSRF `fileUrl` | تم — `functions/url_safety.js` + publish_extract |
| SSRF أدلة المجلات | تم — `journal_guidelines.js` |
| سر webhook الأصالة | تم — `COPYLEAKS_WEBHOOK_SECRET` |
| إشعارات عبر Function | تم — `sendAppNotification` + العميل |
| بوابة شاشات الإدارة | تم — `AdminAccessGate` |
| `topic_claims` تتطلب تسجيل دخول | تم |
| خصوصية المقترحات / جوائز التمويل | تم تضييق القراءة |
| بوابة دفع Paymob (كود جاهز — يحتاج أسرار + نشر) | تم التنفيذ في الكود؛ التفعيل عبر docs/PAYMOB_SETUP.md |
| FCM send / demo data | مفتوح (ميزات ناقصة) |
| باقي البنود | مفتوح — حسب الأولوية أعلاه |

### نشر مطلوب بعد السحب

```bash
firebase functions:secrets:set COPYLEAKS_WEBHOOK_SECRET
firebase deploy --only storage,firestore:rules,functions:sendAppNotification,functions:originalityCheck,functions:originalityCheckHttp,functions:copyleaksWebhook,functions:publishExtractReferencesHttp,functions:journalGuidelinesExtract,functions:journalGuidelinesExtractHttp
```

---

*آخر تحديث: يوليو 2026*
