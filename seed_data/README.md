# حزمة استيراد AcadeGate — جاهزة للتعبئة

هذه المجلد يحتوي ملفات جاهزة لتعبئة المنصة **قبل الإطلاق** بدون برمجة إضافية.

## محتويات الحزمة

| الملف | الاستخدام |
|-------|-----------|
| `csv/labs_template.csv` | قالب فارغ لإضافة مختبراتك |
| `csv/labs_egypt_starter.csv` | **18 مختبر/مركز** نموذجي لجامعات مصرية |
| `csv/supervisors_template.csv` | قالب مشرفين (يدوي أو تكميلي) |
| `universities/openalex_egypt.md` | قائمة جامعات للبحث في OpenAlex |

---

## 1) المشرفون — عبر OpenAlex (الأسرع)

**من التطبيق:** بوابة مقدم الخدمة → استيراد مشرفين → تبويب **OpenAlex**

1. افتح `universities/openalex_egypt.md` واختر جامعة.
2. ابحث بالاسم **الإنجليزي** (مثل `Cairo University`).
3. حمّل قائمة الباحثين واختر التخصص (Engineering, Science...).
4. استورد — يُرسل للمراجعة أو يُنشر مباشرة إن كنت مديراً.

**هدف أول أسبوع:** 150–300 مشرف من 3 جامعات على الأقل.

---

## 2) المختبرات — عبر CSV

**من التطبيق:** مختبرات ومراكز التحليل → (مدير) استيراد CSV  
أو: زر **«حزمة مصر الجاهزة»** داخل شاشة الاستيراد.

### خطوات

1. عدّل `labs_egypt_starter.csv` أو انسخ `labs_template.csv`.
2. افتح الملف في Excel أو Google Sheets (ترميز UTF-8).
3. املأ الأعمدة:
   - `name` — اسم المختبر
   - `university` — الجامعة
   - `city` — المدينة
   - `labType` — `research_center` | `core_facility` | `university_lab`
   - `faculty` — `Science` | `Engineering` | `Medicine` | `CS` | `Agriculture` ...
   - `sampleServices` — مفصولة بـ `;` مثل `SEM;XRD;FTIR`
   - `equipment` — نفس الصيغة
   - `contactEmail` — بريد التواصل (اختياري)

4. احفظ كـ **CSV UTF-8** وارفعه من التطبيق.

**هدف:** 20+ مختبر قبل التجربة المغلقة.

---

## 3) المشرفون — CSV يدوي (تكميلي)

استخدم `supervisors_template.csv` للمشرفين غير الموجودين في OpenAlex.

الأعمدة: `name`, `university`, `speciality`, `bio`, `faculty`, `category`, `tags`

---

## 4) ترتيب التعبئة المقترح

| اليوم | المهمة | الهدف |
|-------|--------|-------|
| 1–2 | OpenAlex لـ 3 جامعات | 150+ مشرف |
| 3 | استيراد `labs_egypt_starter.csv` + تعديل | 18+ مختبر |
| 4 | 10 أفكار بحثية يدوياً من التطبيق | 10 أفكار |
| 5 | 5 منتجات تجريبية في المتجر | 5 منتجات |

---

## 5) ملاحظات

- البيانات النموذجية في `labs_egypt_starter.csv` **للتجربة** — حدّثها ببيانات حقيقية قبل العرض للعملاء.
- الاستيراد يحتاج **حساب مدير** للموافقة التلقائية، أو يُرسل للمراجعة.
- قواعد Firestore منشورة — المحتوى المستورد يظهر بعد `approvalStatus: approved`.

---

## المسار في المشروع

```
seed_data/
├── README.md
├── csv/
│   ├── labs_template.csv
│   ├── labs_egypt_starter.csv
│   └── supervisors_template.csv
└── universities/
    └── openalex_egypt.md
```
