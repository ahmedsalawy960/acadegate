# نسخ احتياطي واستعادة — AcadeGate (Firestore / Storage)

هذا الدليل يغطي **ما لا يوجد في الكود**: إعدادات Firebase/GCP اليدوية + سكربتات مساعدة.

## 1) تفعيل النسخ الاحتياطي الدوري (موصى به)

### الطريقة السريعة (سكربت)

يتطلب `firebase login` صالحاً (نفس حساب مالك مشروع `acadegate-new`):

```powershell
firebase login --reauth
node tool\enable_firestore_backup.cjs
```

السكربت يقوم بـ:
1. إنشاء **جدول نسخ يومي** (احتفاظ 14 يوماً) + أسبوعي (أحد، 14 أسبوعاً) على قاعدة `(default)`
2. إنشاء bucket خاص: `gs://acadegate-new-firestore-backups` (غير عام)
3. تصدير يدوي فوري + استيراد إلى قاعدة تجريبية `backup-drill-YYYYMMDD` (لا يمس بيانات الإنتاج)
4. فحص سريع لقراءة مجموعة `users` من قاعدة التجربة

### من Google Cloud Console (يدوياً)

1. افتح [Firestore → Databases](https://console.cloud.google.com/firestore/databases?project=acadegate-new)
2. بجانب قاعدة `(default)` اختر **Scheduled backups** / **Disaster recovery** → Edit
3. فعّل **Daily** (مثلاً احتفاظ 14 يوماً) واحفظ
4. (اختياري) فعّل **Weekly** يوم الأحد باحتفاظ أطول

### Storage

- فعّل **Object Versioning** على bucket التخزين، أو انسخ دورياً إلى bucket ثانٍ عبر Transfer Service.

### Auth / Config

- صدّر قائمة المستخدمين عند الحاجة عبر Firebase Auth CLI / Admin SDK (ليس بديلاً عن Firestore).
- وثّق `config/app` يدوياً: يجب أن يبقى `allowBootstrap: false` في الإنتاج.

## 2) سكربت تصدير يدوي (اختبار)

من جذر المشروع (يتطلب `gcloud` مثبتاً ومصادقاً على مشروع `acadegate-new`):

```powershell
.\tool\firestore_backup.ps1 -Bucket "gs://acadegate-new-firestore-backups"
```

أو بدون gcloud (بعد `firebase login`):

```powershell
node tool\enable_firestore_backup.cjs
```

## 3) اختبار الاستعادة (مرة كل ربع سنة على الأقل)

السكربت أعلاه ينفّذ استعادة إلى قاعدة **جديدة** باسم `backup-drill-…` ثم يتحقق من القراءة.

يدوياً عبر gcloud:

```bash
gcloud firestore import gs://acadegate-new-firestore-backups/YYYYMMDD --project=acadegate-new --database=backup-drill-test
```

تحقق من:
- مستند مستخدم تجريبي
- طلب متجر / غرفة بحث
- قواعد الأمان ما زالت منشورة على الهدف الصحيح

### قائمة تحقق آخر اختبار

| التاريخ | المصدر | الهدف | النتيجة | ملاحظات |
|---------|--------|-------|---------|---------|
| 2026-09-19 | export يدوي + جدول يومي/أسبوعي | `backup-drill-20260919` | نجاح | `gs://acadegate-new-firestore-backups/manual-2026-09-19T18-28-47` — تحقق: users readable |

## 4) قبل الإطلاق العام

- [x] Backup schedule مفعّل (يومي + أسبوعي)
- [x] اختبار استعادة واحد موثّق (2026-09-19 → `backup-drill-20260919`)
- [ ] `allowBootstrap = false`
- [ ] بناء الويب/المتاجر **بدون** `--dart-define-from-file=dart_defines.json`
