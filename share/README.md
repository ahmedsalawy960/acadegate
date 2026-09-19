# صفحة مشاركة واتساب (GitHub Pages)

واتساب أحياناً **يرفض إرسال** روابط `*.web.app` و`*.firebaseapp.com` (علامة تعجب حمراء).

## حل سريع الآن (بدون نشر)

1. أرسل العرض كـ **ملف PDF/HTML** عبر واتساب (مرفق)، وليس كرابط.
2. أو اكتب الرابط مقطّعاً في رسالتين:
   - الرسالة 1: `افتح في المتصفح:`
   - الرسالة 2: `acadegate-new.firebaseapp.com` (بدون https://)
3. أو اختبر مختصراً من bitly / tinyurl يشير لنفس الموقع.

## نشر رابط GitHub Pages (موصى به)

من جذر المشروع (مرة واحدة):

```powershell
git checkout --orphan gh-pages
git reset
git add share/index.html
git commit -m "Add WhatsApp-friendly AcadeGate redirect landing"
git push -u origin gh-pages --force
```

ثم في GitHub → Settings → Pages → Source: branch `gh-pages` / root.

الرابط المتوقع:
`https://ahmedsalawy960.github.io/acadegate/`

(يحوّل فوراً إلى المنصة الحيّة)
