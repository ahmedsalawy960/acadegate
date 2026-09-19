# نسخ احتياطي واستعادة — AcadeGate (Firestore / Storage)

هذا الدليل يغطي **ما لا يوجد في الكود**: إعدادات Firebase/GCP اليدوية + سكربتات مساعدة.

## 1) تفعيل النسخ الاحتياطي الدوري (موصى به)

### Firestore (Scheduled export)

1. فعّل [Cloud Firestore managed export](https://firebase.google.com/docs/firestore/manage-data/export-data) أو **Backup schedules** من Google Cloud Console → Firestore → Backups.
2. أنشئ bucket خاصاً للنسخ، مثال: `gs://acadegate-new-firestore-backups` (غير عام).
3. امنح حساب الخدمة صلاحية الكتابة على الـ bucket فقط.
4. جدول يومي أو أسبوعي حسب الميزانية.

### Storage

- فعّل **Object Versioning** على bucket التخزين، أو انسخ دورياً إلى bucket ثانٍ عبر Transfer Service.

### Auth / Config

- صدّر قائمة المستخدمين عند الحاجة عبر Firebase Auth CLI / Admin SDK (ليس بديلاً عن Firestore).
- وثّق `config/app` يدوياً: يجب أن يبقى `allowBootstrap: false` في الإنتاج.

## 2) سكربت تصدير يدوي (اختبار)

من جذر المشروع (يتطلب `gcloud` مثبتاً ومصادقاً على مشروع `acadegate-new`):

```powershell
.\tool\firestore_backup.ps1 -Bucket "gs://YOUR_BACKUP_BUCKET"
```

أو يدوياً:

```bash
gcloud firestore export gs://YOUR_BACKUP_BUCKET/$(date +%Y%m%d) --project=acadegate-new
```

## 3) اختبار الاستعادة (مرة كل ربع سنة على الأقل)

1. أنشئ مشروع Firebase **تجريبي** أو قاعدة بيانات ثانوية.
2. نفّذ:

```bash
gcloud firestore import gs://YOUR_BACKUP_BUCKET/YYYYMMDD --project=TEST_PROJECT
```

3. تحقق من:
   - مستند مستخدم تجريبي
   - طلب متجر / غرفة بحث
   - قواعد الأمان ما زالت منشورة على الهدف الصحيح
4. سجّل التاريخ والنتيجة في هذا الملف أو تذكرة داخلية.

### قائمة تحقق آخر اختبار

| التاريخ | المصدر | الهدف | النتيجة | ملاحظات |
|---------|--------|-------|---------|---------|
| _(فارغ)_ | | | | لم يُنفَّذ بعد |

## 4) قبل الإطلاق العام

- [ ] Backup schedule مفعّل
- [ ] اختبار استعادة واحد موثّق
- [ ] `allowBootstrap = false`
- [ ] بناء الويب/المتاجر **بدون** `--dart-define-from-file=dart_defines.json`
