/**
 * Refresh partner pitch decks + contact sheets with the live share URL
 * and September 2026 product updates.
 *
 * Usage: node docs/refresh-partner-pitches.mjs
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const APP = 'https://acadegate-new--v20261002-tp9dbk1c.web.app';
const REG = 'https://acadegate-new--v20261002-tp9dbk1c.web.app/register';
const LOGIN = 'https://acadegate-new--v20261002-tp9dbk1c.web.app/login';
const ALT = 'https://acadegate-new.firebaseapp.com/register';
const PHONE = '01044339033';
const TEL = 'tel:+201044339033';
const DATE_AR = '٢ أكتوبر ٢٠٢٦';
const DATE_ISO = '2026-10-02';

const bannerCss = `
    .link-banner {
      position: sticky; top: 8px; z-index: 30;
      background: linear-gradient(105deg, #071433 0%, #0b1f4d 45%, #0f766e 100%);
      color: #fff; padding: 14px 18px; border-radius: 16px;
      margin: 0 0 18px; display: flex; flex-wrap: wrap; gap: 10px 18px;
      align-items: center; justify-content: space-between;
      box-shadow: 0 12px 32px rgba(11, 31, 77, 0.28);
      border: 1px solid rgba(255,255,255,0.12);
    }
    .link-banner .lb-title { font-weight: 800; font-size: 13pt; }
    .link-banner .lb-meta { opacity: 0.9; font-size: 10.5pt; }
    .link-banner a {
      color: #fde68a; font-weight: 800; text-decoration: none;
      border-bottom: 1px solid rgba(253,230,138,0.55);
    }
    .link-banner .lb-actions { display: flex; flex-wrap: wrap; gap: 10px; }
    .link-banner .lb-btn {
      display: inline-block; background: #fbbf24; color: #071433 !important;
      border: none; border-radius: 999px; padding: 8px 14px; font-weight: 800;
      border-bottom: none !important; font-size: 11pt;
    }
    .link-banner .lb-btn.secondary {
      background: rgba(255,255,255,0.12); color: #fff !important;
      border: 1px solid rgba(255,255,255,0.28);
    }
    @media print { .link-banner { position: static; box-shadow: none; } }
`;

function bannerHtml(audience) {
  return `
  <div class="link-banner" role="banner">
    <div>
      <div class="lb-title">منصة AcadeGate الحيّة — جاهزة للتجربة الآن</div>
      <div class="lb-meta">عرض ${audience} · محدّث ${DATE_AR} · الدعم ${PHONE}</div>
    </div>
    <div class="lb-actions">
      <a class="lb-btn" href="${APP}" target="_blank" rel="noopener">فتح المنصة</a>
      <a class="lb-btn secondary" href="${REG}" target="_blank" rel="noopener">التسجيل</a>
      <a class="lb-btn secondary" href="${LOGIN}" target="_blank" rel="noopener">الدخول</a>
      <a class="lb-btn secondary" href="${TEL}">${PHONE}</a>
      <a class="lb-btn secondary" href="${ALT}" target="_blank" rel="noopener">بديل واتساب</a>
    </div>
  </div>`;
}

function whatsNewSlide(kind) {
  const common = `
        <div class="card"><strong>رابط حيّ</strong>المنصة على ${APP} · التسجيل ${REG} · الدخول ${LOGIN} · الدعم ${PHONE}.</div>
        <div class="card"><strong>بوابتان واضحتان</strong>بوابة باحث + بوابة مقدم خدمة (تاجر / مختبر / كاتب) مع مراجعة انضمام.</div>
        <div class="card"><strong>مطالبة ملف موثّق</strong>Claim للملفات المستوردة → حالة Managed Verified بعد موافقة الإدارة.</div>
        <div class="card"><strong>رسائل داخل المنصة</strong>تواصل الباحث معكم دون الاعتماد على واتساب فقط.</div>`;

  const byKind = {
    store: `
        <div class="card"><strong>Store Hub + عربة</strong>بحث، أقسام، الأكثر طلباً، عربة متعددة الموردين وطلبات واردة.</div>
        <div class="card"><strong>RFQ + شارات ثقة</strong>طلب عرض سعر للكميات · شارات موثّق / شريك.</div>
        <div class="card"><strong>صفحة متجر المورد</strong>كتالوج عام لكل بائع + إضافة منتجات غنية (صور · SKU · منشأ).</div>
        <div class="card"><strong>Escrow</strong>دفع محجوز حتى تأكيد الاستلام — حماية للطرفين.</div>`,
    lab: `
        <div class="card"><strong>حجز أجهزة + رزنامة</strong>جلسات مع بوابة تدريب عند الحاجة · إشعارات للمالك.</div>
        <div class="card"><strong>تحليل عينات</strong>تبويب منفصل لطلبات التحليل ومتابعتها.</div>
        <div class="card"><strong>ملف مختبر مُدار</strong>ترتيب الوصف والخدمات بعد التحقق · دليل NBSLE قابل للمطالبة.</div>
        <div class="card"><strong>ربط بمسار البحث</strong>ظهور ضمن اقتراحات المطابقة و«لك اليوم».</div>`,
    writer: `
        <div class="card"><strong>Writing Hub</strong>أقسام خدمات، بحث، مطابقة كاتب حسب التخصص واللغة.</div>
        <div class="card"><strong>طلبات بمواصفات غنية</strong>مستوى أكاديمي · توثيق · استعجال · إحصاء · مراحل رسالة.</div>
        <div class="card"><strong>أدوات مساعدة للباحث</strong>مسودة · مناقشة · نزاهة/اقتباس — تزيد الحاجة لخدماتكم البشرية.</div>
        <div class="card"><strong>دور الكاتب + وارد</strong>تفعيل الدور عند النشر · طلبات في بوابة مقدم الخدمة مع Escrow.</div>`,
  };

  return `
  <section class="slide">
    <div class="slide-inner">
      <h2>مستجدات المنصة الحيّة — ${DATE_AR}</h2>
      <p class="lead">ما يعمل الآن في التطبيق ويمكن للشريك تجربته عبر الرابط أدناه — ليست وعوداً ورقية.</p>
      <div class="grid-2">
        ${common}
        ${byKind[kind]}
      </div>
      <div class="callout callout-teal">
        <strong>جرّبوا الآن:</strong>
        <a href="${APP}" target="_blank" rel="noopener">${APP}</a>
        · تسجيل:
        <a href="${REG}" target="_blank" rel="noopener">${REG}</a>
        · إن حجب واتساب النطاق .web.app استخدموا
        <a href="${ALT}" target="_blank" rel="noopener">${ALT}</a>
      </div>
    </div>
  </section>`;
}

function injectCss(html) {
  if (html.includes('.link-banner {')) return html;
  return html.replace('</style>', `${bannerCss}\n  </style>`);
}

function injectBanner(html, audience) {
  if (html.includes('class="link-banner"')) {
    return html.replace(
      /<div class="link-banner"[\s\S]*?<\/div>\s*(?=<section|<div class="slide)/,
      `${bannerHtml(audience)}\n`,
    );
  }
  return html.replace('<div class="deck">', `<div class="deck">\n${bannerHtml(audience)}`);
}

function injectWhatsNew(html, kind) {
  if (html.includes('مستجدات المنصة الحيّة')) {
    return html.replace(
      /<section class="slide">\s*<div class="slide-inner">\s*<h2>مستجدات المنصة الحيّة[\s\S]*?<\/section>/,
      whatsNewSlide(kind).trim(),
    );
  }
  // After first TOC / فهرس slide if present, else after cover
  const tocEnd = html.search(/<\/section>\s*<!-- |<\/section>\s*<section class="slide">/);
  if (tocEnd > 0) {
    const insertAt = html.indexOf('</section>', html.indexOf('محتوى العرض') > 0 ? html.indexOf('محتوى العرض') : 0);
    if (insertAt > 0) {
      const end = html.indexOf('</section>', insertAt) + '</section>'.length;
      return html.slice(0, end) + '\n' + whatsNewSlide(kind) + html.slice(end);
    }
  }
  // Fallback: after cover section
  const coverClose = html.indexOf('</section>', html.indexOf('class="slide cover"'));
  if (coverClose > 0) {
    const end = coverClose + '</section>'.length;
    return html.slice(0, end) + '\n' + whatsNewSlide(kind) + html.slice(end);
  }
  return html;
}

function bumpPills(html) {
  return html
    .replace(/محدّث سبتمبر 2026 · https:\/\/acadegate-new\.web\.app/g, `محدّث ${DATE_AR} · ${APP}`)
    .replace(/محدّث آب 2026/g, `محدّث ${DATE_AR}`)
    .replace(/· آب 2026/g, `· ${DATE_AR}`);
}

function patchPitch(file, audience, kind) {
  const p = path.join(__dirname, file);
  let html = fs.readFileSync(p, 'utf8');
  html = injectCss(html);
  html = injectBanner(html, audience);
  html = injectWhatsNew(html, kind);
  html = bumpPills(html);
  // Ensure CTA has alt whatsapp link
  if (!html.includes('firebaseapp.com') && html.includes('الخطوة التالية')) {
    html = html.replace(
      /(التسجيل:<\/strong>\s*<a[^>]+><\/a><\/p>)/,
      `$1\n        <p><strong>بديل واتساب:</strong> <a href="${ALT}" target="_blank" rel="noopener">${ALT}</a></p>`,
    );
  }
  fs.writeFileSync(p, html, 'utf8');
  console.log('updated pitch:', file);
}

function patchContactMeta(file, titleLine) {
  const p = path.join(__dirname, file);
  let html = fs.readFileSync(p, 'utf8');
  const banner = `
<div style="background:linear-gradient(105deg,#071433,#0f766e);color:#fff;padding:16px 18px;border-radius:14px;margin:0 0 18px;display:flex;flex-wrap:wrap;gap:12px;align-items:center;justify-content:space-between">
  <div>
    <div style="font-weight:800;font-size:16px">${titleLine}</div>
    <div style="opacity:.92;font-size:13px;margin-top:4px">محدّث ${DATE_ISO} · الدعم ${PHONE} · للمراسلة والشراكة مع AcadeGate</div>
  </div>
  <div style="display:flex;flex-wrap:wrap;gap:8px">
    <a href="${APP}" style="background:#fbbf24;color:#071433;padding:8px 12px;border-radius:999px;font-weight:800;text-decoration:none">المنصة</a>
    <a href="${REG}" style="background:rgba(255,255,255,.14);color:#fff;padding:8px 12px;border-radius:999px;font-weight:700;text-decoration:none;border:1px solid rgba(255,255,255,.3)">التسجيل</a>
    <a href="${LOGIN}" style="background:rgba(255,255,255,.14);color:#fff;padding:8px 12px;border-radius:999px;font-weight:700;text-decoration:none;border:1px solid rgba(255,255,255,.3)">الدخول</a>
    <a href="${TEL}" style="background:rgba(255,255,255,.14);color:#fff;padding:8px 12px;border-radius:999px;font-weight:700;text-decoration:none;border:1px solid rgba(255,255,255,.3)">${PHONE}</a>
    <a href="${ALT}" style="background:rgba(255,255,255,.14);color:#fff;padding:8px 12px;border-radius:999px;font-weight:700;text-decoration:none;border:1px solid rgba(255,255,255,.3)">بديل واتساب</a>
  </div>
</div>`;

  if (html.includes('محدّث ') || html.includes(DATE_ISO)) {
    // refresh existing banner block roughly
    html = html.replace(
      /<div style="background:linear-gradient[\s\S]*?<\/div>\s*(?=<h1|<p class="meta"|<div class="stats")/,
      banner + '\n',
    );
  } else if (html.includes('<div class="wrap">')) {
    html = html.replace('<div class="wrap">', `<div class="wrap">\n${banner}`);
  } else if (html.includes('<body>')) {
    html = html.replace('<body>', `<body>\n${banner}`);
  }

  // Refresh meta dates/links
  html = html.replace(/2026-09-13/g, DATE_ISO);
  html = html.replace(
    /المنصة:\s*<a href="https:\/\/acadegate-new\.web\.app\/?">https:\/\/acadegate-new\.web\.app\/?<\/a>/g,
    `المنصة: <a href="${APP}">${APP}</a>`,
  );
  if (!html.includes(REG)) {
    html = html.replace(
      APP,
      `${APP}</a> · التسجيل: <a href="${REG}">${REG}`,
    );
  }
  fs.writeFileSync(p, html, 'utf8');
  console.log('updated contact:', file);
}

patchPitch('Stores.html', 'الموردين والمتاجر', 'store');
patchPitch('Labs.html', 'المختبرات', 'lab');
patchPitch('خدمات الكتابة.html', 'خبراء الكتابة', 'writer');
patchPitch('AcadeGate_Pitch_Suppliers_AR.html', 'الموردين والتجار', 'store');

// Keep Arabic lab alias in sync with Labs.html
fs.copyFileSync(path.join(__dirname, 'Labs.html'), path.join(__dirname, 'المختبرات.html'));
console.log('synced: المختبرات.html <- Labs.html');

patchContactMeta('كشف تواصل الموردين.html', 'كشف تواصل الموردين — AcadeGate');
patchContactMeta('AcadeGate — كشف تواصل المختبرات.html', 'كشف تواصل المختبرات — AcadeGate');
patchContactMeta('كشف تواصل المراكز البحثية.html', 'كشف تواصل المراكز البحثية — AcadeGate');

console.log('\nDone. Share links:');
console.log(' ', APP);
console.log(' ', REG);
console.log(' ', ALT);
