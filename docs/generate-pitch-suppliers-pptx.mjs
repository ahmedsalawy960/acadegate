/**
 * AcadeGate — عرض شراكة الموردين (PowerPoint)
 * تشغيل: npm run pitch:suppliers
 */
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import PptxGenJS from 'pptxgenjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const outPrimary = path.join(__dirname, 'AcadeGate_Pitch_Suppliers_AR.pptx');
const outFallback = path.join(__dirname, 'AcadeGate_Pitch_Suppliers_AR_v2.pptx');

const img = (...parts) => path.join(root, 'Assets', 'images', ...parts);

const C = {
  ink: '0F172A',
  muted: '475569',
  navy: '0B1F4D',
  navyDeep: '071433',
  teal: '0F766E',
  gold: 'B45309',
  goldSoft: 'FBBF24',
  sand: 'F8F5F0',
  soft: 'EEF6F5',
  line: 'D6D3D1',
  white: 'FFFFFF',
  softGold: 'FFFBEB',
  chipText: '115E59',
};

const pptx = new PptxGenJS();
pptx.defineLayout({ name: 'WIDE', width: 13.333, height: 7.5 });
pptx.layout = 'WIDE';
pptx.author = 'AcadeGate';
pptx.title = 'AcadeGate — عرض الشراكة للموردين والتجار';
pptx.subject = 'عرض شراكة المتجر الأكاديمي · محدّث ١٩ سبتمبر ٢٠٢٦ · acadegate-new.web.app';
pptx.rtlMode = true;

const W = 13.333;
const H = 7.5;
const M = 0.45;
const TOTAL = 16;

function addFooter(slide, page) {
  slide.addShape(pptx.shapes.RECTANGLE, {
    x: 0, y: H - 0.38, w: W, h: 0.38,
    fill: { color: C.sand },
  });
  slide.addText('AcadeGate · عرض شراكة الموردين · محدّث ١٩ سبتمبر ٢٠٢٦', {
    x: M, y: H - 0.34, w: 9, h: 0.28,
    fontSize: 10, color: C.muted, fontFace: 'Segoe UI', rtlMode: true, align: 'right',
  });
  slide.addText(`${page} / ${TOTAL}`, {
    x: W - M - 1.2, y: H - 0.34, w: 1.2, h: 0.28,
    fontSize: 10, color: C.muted, fontFace: 'Segoe UI', align: 'left',
  });
}

function slideTitle(slide, title) {
  slide.addShape(pptx.shapes.RECTANGLE, {
    x: M, y: 0.28, w: 0.12, h: 0.55,
    fill: { color: C.teal },
  });
  slide.addText(title, {
    x: M + 0.22, y: 0.22, w: W - M * 2 - 0.22, h: 0.62,
    fontSize: 24, bold: true, color: C.navy, fontFace: 'Segoe UI',
    rtlMode: true, align: 'right', valign: 'middle',
  });
  slide.addShape(pptx.shapes.RECTANGLE, {
    x: M, y: 0.9, w: W - M * 2, h: 0.035,
    fill: { color: C.teal },
  });
}

function bodyLead(slide, text, y = 1.05) {
  slide.addText(text, {
    x: M, y, w: W - M * 2, h: 0.5,
    fontSize: 13, color: C.muted, fontFace: 'Segoe UI',
    rtlMode: true, align: 'right',
  });
}

function card(slide, { x, y, w, h, fill = C.white, border = C.line }) {
  slide.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
    x, y, w, h,
    fill: { color: fill },
    line: { color: border, width: 1 },
    rectRadius: 0.1,
  });
}

function safeImage(slide, file, opts) {
  try {
    slide.addImage({ path: file, ...opts });
    return true;
  } catch {
    return false;
  }
}

function cell(text, opts = {}) {
  return {
    text,
    options: {
      align: 'right',
      valign: 'middle',
      fontFace: 'Segoe UI',
      fontSize: 12,
      color: C.ink,
      fill: { color: C.white },
      ...opts,
    },
  };
}
function head(text) {
  return cell(text, { bold: true, color: C.white, fill: { color: C.navy }, fontSize: 12 });
}

// ─── 1 غلاف ───
{
  const s = pptx.addSlide();
  s.addShape(pptx.shapes.RECTANGLE, {
    x: 0, y: 0, w: W, h: H,
    fill: { color: C.navyDeep },
  });
  s.addShape(pptx.shapes.OVAL, {
    x: -1.5, y: -1.2, w: 6, h: 6,
    fill: { color: C.teal, transparency: 70 },
  });
  s.addShape(pptx.shapes.OVAL, {
    x: 9, y: -0.8, w: 5, h: 4,
    fill: { color: C.gold, transparency: 78 },
  });
  s.addShape(pptx.shapes.RECTANGLE, {
    x: 0, y: 0, w: W, h: H,
    fill: { color: C.navy, transparency: 35 },
  });

  safeImage(s, img('acadegate_logo_2x.png'), {
    x: W - M - 1.35, y: 0.4, w: 1.2, h: 1.2,
  });

  s.addText('عرض شراكة مخصص · فئة الموردين والتجار · محدّث ١٩ سبتمبر ٢٠٢٦', {
    x: M, y: 1.5, w: W - M * 2 - 1.5, h: 0.35,
    fontSize: 13, color: 'CBD5E1', fontFace: 'Segoe UI',
    rtlMode: true, align: 'right',
  });
  s.addText('AcadeGate', {
    x: M, y: 1.95, w: W - M * 2 - 1.5, h: 0.85,
    fontSize: 52, bold: true, color: C.white, fontFace: 'Segoe UI',
    rtlMode: true, align: 'right',
  });
  s.addText('منصة أكاديمية متكاملة — والمتجر هو نقطة التنفيذ المادي لرحلة الباحث', {
    x: M, y: 2.85, w: 10, h: 0.5,
    fontSize: 17, color: 'E2E8F0', fontFace: 'Segoe UI',
    rtlMode: true, align: 'right',
  });

  s.addShape(pptx.shapes.RECTANGLE, {
    x: M + 9.55, y: 3.5, w: 0.08, h: 1.2,
    fill: { color: C.goldSoft },
  });
  s.addText(
    'فكرة التطبيق: نجمع رحلة الدراسات العليا في مكان واحد — من الفكرة والمشرف والمختبر إلى المعدات والكتابة والمجتمع والذكاء الاصطناعي — مع ضمان Escrow يحمي البائع والمشتري.',
    {
      x: M, y: 3.45, w: 9.4, h: 1.3,
      fontSize: 14, color: 'F1F5F9', fontFace: 'Segoe UI',
      rtlMode: true, align: 'right',
    },
  );

  const pills = [
    'فكرة المنصة أولاً · ثم عرض المورد',
    'مستجدات المتجر: Hub · عربة · RFQ',
    'نموذج إيرادات متعدد القنوات',
  ];
  pills.forEach((t, i) => {
    const pw = 3.7;
    const px = W - M - pw - i * (pw + 0.12);
    s.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
      x: px, y: 5.15, w: pw, h: 0.42,
      fill: { color: C.white, transparency: 88 },
      line: { color: C.white, width: 1, transparency: 50 },
      rectRadius: 0.2,
    });
    s.addText(t, {
      x: px, y: 5.17, w: pw, h: 0.38,
      fontSize: 11, color: C.white, fontFace: 'Segoe UI',
      rtlMode: true, align: 'center', valign: 'middle',
    });
  });

  safeImage(s, img('weekly', 'services', 'svc_store_w1.png'), {
    x: M, y: 5.8, w: 1.8, h: 1.05,
  });
  safeImage(s, img('weekly', 'features', 'feat_escrow_w1.png'), {
    x: M + 2, y: 5.8, w: 1.8, h: 1.05,
  });
  s.addText('وثيقة عرض شراكة · قابلة للمشاركة مع فريق المبيعات', {
    x: M + 4, y: 6.5, w: 8.5, h: 0.3,
    fontSize: 11, color: '94A3B8', fontFace: 'Segoe UI',
    rtlMode: true, align: 'right',
  });
}

// ─── 2 فهرس ───
{
  const s = pptx.addSlide();
  s.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: W, h: H, fill: { color: C.white } });
  slideTitle(s, 'ماذا ستجد في هذا العرض؟');
  bodyLead(s, 'نبدأ بفكرة التطبيق والجمهور — ثم المتجر والمستجدات — ثم الشراكة والإيرادات.');

  const items = [
    'فكرة AcadeGate ورحلة الباحث (لماذا يوجد متجر أصلاً؟)',
    'لماذا هذه فرصة للمورد؟',
    'ماذا تقدّم المنصة ككل (البوابتان والخدمات)',
    'مستجدات المتجر (Hub · عربة · RFQ · متاجر موردين…)',
    '١٥ قسماً + ماذا تنشر كمنتج؟',
    'دورة الطلب والضمان Escrow',
    'آلية الشراكة: ماذا نقدّم / ماذا تقدّم',
    'ماذا تفعل داخل التطبيق عملياً؟',
    'نموذج الإيرادات + بدائل ومقترحات',
    'أمور يجب معرفتها · لماذا الآن · ابدأ الشراكة',
  ];
  items.forEach((t, i) => {
    const col = i < 5 ? 0 : 1;
    const row = i < 5 ? i : i - 5;
    const x = M + col * 6.2;
    const y = 1.65 + row * 0.9;
    card(s, { x, y, w: 5.9, h: 0.78, fill: C.soft, border: 'CCFBF1' });
    s.addShape(pptx.shapes.OVAL, {
      x: x + 5.25, y: y + 0.17, w: 0.44, h: 0.44,
      fill: { color: C.navy },
    });
    s.addText(String(i + 1), {
      x: x + 5.25, y: y + 0.17, w: 0.44, h: 0.44,
      fontSize: 14, bold: true, color: C.white, align: 'center', valign: 'middle',
      fontFace: 'Segoe UI',
    });
    s.addText(t, {
      x: x + 0.2, y: y + 0.14, w: 4.9, h: 0.5,
      fontSize: 12.5, color: C.ink, fontFace: 'Segoe UI',
      rtlMode: true, align: 'right', valign: 'middle',
    });
  });
  addFooter(s, 2);
}

// ─── 3 فكرة التطبيق (في البداية) ───
{
  const s = pptx.addSlide();
  s.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: W, h: H, fill: { color: C.white } });
  slideTitle(s, '١ — فكرة التطبيق: لماذا AcadeGate؟');
  bodyLead(
    s,
    'قبل أن نتحدث عن عمولتك: هذه هي المشكلة التي نحلّها — ومنها يأتي عميلك إلى متجرك.',
  );

  card(s, { x: M, y: 1.65, w: W - M * 2, h: 1.35, fill: C.soft, border: C.teal });
  s.addText(
    'المشكلة: طالب الدراسات العليا والباحث العربي يحتاج مشرفاً، فكرة، مختبراً، معدات، كتابة، ومجتمعاً — لكنه يبحث عنها في قنوات متفرقة (واتساب، مجموعات، مواقع عامة) بلا ضمان ولا مسار واحد.',
    {
      x: M + 0.25, y: 1.8, w: W - M * 2 - 0.5, h: 1.05,
      fontSize: 14, color: C.ink, fontFace: 'Segoe UI',
      rtlMode: true, align: 'right',
    },
  );

  s.addText('الحل: رحلة واحدة مترابطة داخل المنصة', {
    x: M, y: 3.2, w: W - M * 2, h: 0.35,
    fontSize: 15, bold: true, color: C.navy, fontFace: 'Segoe UI',
    rtlMode: true, align: 'right',
  });

  const flow = [
    'فكرة بحثية',
    'مشرف',
    'مختبر',
    'معدات (متجرك)',
    'كتابة',
    'مجتمع + AI',
  ];
  flow.forEach((t, i) => {
    const x = M + i * 2.1;
    card(s, { x, y: 3.65, w: 1.95, h: 1.05, fill: i === 3 ? C.softGold : C.soft, border: i === 3 ? C.gold : 'CCFBF1' });
    s.addText(String(i + 1), {
      x, y: 3.72, w: 1.95, h: 0.3,
      fontSize: 11, bold: true, color: C.teal, fontFace: 'Segoe UI',
      align: 'center',
    });
    s.addText(t, {
      x: x + 0.05, y: 4.05, w: 1.85, h: 0.5,
      fontSize: 12, bold: true, color: C.navy, fontFace: 'Segoe UI',
      rtlMode: true, align: 'center',
    });
  });

  card(s, { x: M, y: 5.0, w: W - M * 2, h: 1.55, fill: C.softGold, border: C.gold });
  s.addText('ماذا يعني ذلك للمورد؟', {
    x: M + 0.25, y: 5.15, w: W - M * 2 - 0.5, h: 0.35,
    fontSize: 14, bold: true, color: C.gold, fontFace: 'Segoe UI',
    rtlMode: true, align: 'right',
  });
  s.addText(
    'المتجر ليس «إعلاناً منفصلاً». الباحث يعيش أسابيع داخل المنصة (ملف أكاديمي · مسار بحث · مختبرات · AI) — وعندما يحتاج كواشف أو أجهزة يصل إليك داخل نفس الرحلة، مع ثقة Escrow.',
    {
      x: M + 0.25, y: 5.55, w: W - M * 2 - 0.5, h: 0.85,
      fontSize: 13, color: C.ink, fontFace: 'Segoe UI',
      rtlMode: true, align: 'right',
    },
  );
  addFooter(s, 3);
}

// ─── 4 الفرصة للمورد ───
{
  const s = pptx.addSlide();
  s.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: W, h: H, fill: { color: C.white } });
  slideTitle(s, '٢ — لماذا AcadeGate فرصة للمورد؟');
  bodyLead(
    s,
    'المشتري الأكاديمي يشتري بشكل متكرر لكنه مشتت بين واتساب ومجموعات ومواقع لا تفهم احتياجاته.',
  );

  const stats = [
    { t: 'عميل مقصود', d: 'باحث يبحث عن منتج محدد، لا متصفح عشوائي' },
    { t: 'ثقة أعلى', d: 'ضمان حجز المبلغ حتى تأكيد الاستلام' },
    { t: 'ظهور متخصص', d: '١٥ قسماً أكاديمياً — لا منافسة سوبرماركت' },
  ];
  stats.forEach((st, i) => {
    const x = M + i * 4.15;
    card(s, { x, y: 1.7, w: 3.95, h: 1.5, fill: C.soft, border: 'CCFBF1' });
    s.addText(st.t, {
      x: x + 0.15, y: 1.85, w: 3.65, h: 0.45,
      fontSize: 18, bold: true, color: C.navy, fontFace: 'Segoe UI',
      rtlMode: true, align: 'center',
    });
    s.addText(st.d, {
      x: x + 0.15, y: 2.4, w: 3.65, h: 0.55,
      fontSize: 12, color: C.muted, fontFace: 'Segoe UI',
      rtlMode: true, align: 'center',
    });
  });

  s.addText('ما الذي نخسره اليوم بدون منصة؟', {
    x: M, y: 3.5, w: W - M * 2, h: 0.35,
    fontSize: 15, bold: true, color: C.teal, fontFace: 'Segoe UI',
    rtlMode: true, align: 'right',
  });

  const pains = [
    { t: 'قنوات غير منظمة', d: 'طلبات بلا سجل ولا متابعة' },
    { t: 'خلافات دفع', d: 'بدون وسيط محايد عند التحويل' },
    { t: 'وصول محدود', d: 'خارج شبكة علاقاتك الحالية' },
    { t: 'بلا سمعة رقمية', d: 'لا تقييم أكاديمي لمنتجاتك' },
  ];
  pains.forEach((p, i) => {
    const x = M + i * 3.15;
    card(s, { x, y: 4.0, w: 3.0, h: 2.35 });
    s.addText(p.t, {
      x: x + 0.15, y: 4.25, w: 2.7, h: 0.7,
      fontSize: 14, bold: true, color: C.navy, fontFace: 'Segoe UI',
      rtlMode: true, align: 'right',
    });
    s.addText(p.d, {
      x: x + 0.15, y: 5.1, w: 2.7, h: 0.9,
      fontSize: 13, color: C.muted, fontFace: 'Segoe UI',
      rtlMode: true, align: 'right',
    });
  });
  addFooter(s, 4);
}

// ─── 5 المنصة ككل ───
{
  const s = pptx.addSlide();
  s.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: W, h: H, fill: { color: C.white } });
  slideTitle(s, '٣ — ماذا تقدّم المنصة ككل؟');
  bodyLead(s, 'قوة المتجر = الباحث يعيش داخل المنصة أسابيع — لا زيارة واحدة ويختفي.');

  [
    {
      n: '١',
      t: 'بوابة الباحث / الطالب',
      d: 'مشرفون · أفكار · مختبرات · متجر · كتابة · مجتمع · AI · أخبار · تمويل · نشر',
    },
    {
      n: '٢',
      t: 'بوابة مقدم الخدمة',
      d: 'للمورد والمختبر والكاتب: طلبات واردة · نشر · متابعة · رسائل · لوحة مساهمة',
    },
  ].forEach((p, i) => {
    const x = M + i * 6.2;
    card(s, { x, y: 1.65, w: 5.95, h: 1.4 });
    s.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
      x: x + 5.25, y: 1.85, w: 0.5, h: 0.5,
      fill: { color: C.navy },
      rectRadius: 0.08,
    });
    s.addText(p.n, {
      x: x + 5.25, y: 1.85, w: 0.5, h: 0.5,
      fontSize: 16, bold: true, color: C.white, align: 'center', valign: 'middle',
    });
    s.addText(p.t, {
      x: x + 0.2, y: 1.8, w: 4.9, h: 0.4,
      fontSize: 15, bold: true, color: C.navy, fontFace: 'Segoe UI',
      rtlMode: true, align: 'right',
    });
    s.addText(p.d, {
      x: x + 0.2, y: 2.3, w: 4.9, h: 0.55,
      fontSize: 12, color: C.muted, fontFace: 'Segoe UI',
      rtlMode: true, align: 'right',
    });
  });

  const services = [
    { t: 'المشرفون', d: 'طلاب مشاريع تحتاج معدات' },
    { t: 'مسار البحث', d: 'يقترح منتجات ضمن الحزمة' },
    { t: 'المختبرات', d: 'مشترون متكررون للمستهلكات' },
    { t: 'الكتابة والمجتمع', d: 'يزيد وقت البقاء والشراء' },
    { t: 'المساعد AI', d: 'يوجّه لموارد التنفيذ' },
    { t: 'النزاهة والتمويل', d: 'تكمل دورة الباحث' },
  ];
  services.forEach((sv, i) => {
    const col = i % 3;
    const row = Math.floor(i / 3);
    const x = M + col * 4.15;
    const y = 3.3 + row * 1.55;
    card(s, { x, y, w: 3.95, h: 1.4 });
    s.addText(sv.t, {
      x: x + 0.2, y: y + 0.3, w: 3.55, h: 0.4,
      fontSize: 14, bold: true, color: C.navy, fontFace: 'Segoe UI',
      rtlMode: true, align: 'right',
    });
    s.addText(sv.d, {
      x: x + 0.2, y: y + 0.8, w: 3.55, h: 0.4,
      fontSize: 12, color: C.muted, fontFace: 'Segoe UI',
      rtlMode: true, align: 'right',
    });
  });
  addFooter(s, 5);
}

// ─── 6 مستجدات المتجر ───
{
  const s = pptx.addSlide();
  s.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: W, h: H, fill: { color: C.white } });
  slideTitle(s, '٤ — مستجدات المتجر (ما تغيّر للمورد والمشتري)');
  bodyLead(s, 'تطويرات حديثة تجعل تجربة السوق أقرب للمنصات التجارية — مع هوية أكاديمية.');

  const updates = [
    { t: 'واجهة سوق (Store Hub)', d: 'بحث · الأكثر طلباً · جديد هذا الأسبوع · أقسام · موردون موثّقون' },
    { t: 'صفحة منتج غنية', d: 'SKU · المنشأ · معرض صور · أسئلة وأجوبة · منتجات مشابهة' },
    { t: 'فلاتر متقدمة', d: 'توفر · شحن سريع · موثّق · نقاء · سعر · مدينة · ترتيب' },
    { t: 'متجر المورد العام', d: 'صفحة كتالوج لكل بائع + سياسة تسليم مبسّطة' },
    { t: 'عربة + طلبات متعددة', d: 'Escrow لكل صنف/مورد · دفع يدوي أو Paymob' },
    { t: 'توصيات بحثية', d: '«معدات تناسب رسالتك» من الملف الأكاديمي' },
    { t: 'شارات ثقة + RFQ', d: 'موثّق / مستورد رسمي · طلب عرض سعر للكميات' },
    { t: 'تصميم + أمان', d: 'جلد ماركت بليس · قواعد طلبات مشدّدة · خصوصية وشروط محدّثة' },
  ];
  updates.forEach((u, i) => {
    const col = i % 4;
    const row = Math.floor(i / 4);
    const x = M + col * 3.15;
    const y = 1.65 + row * 2.4;
    card(s, { x, y, w: 3.0, h: 2.2, fill: row === 0 ? C.soft : C.white, border: row === 0 ? 'CCFBF1' : C.line });
    s.addText(u.t, {
      x: x + 0.15, y: y + 0.25, w: 2.7, h: 0.65,
      fontSize: 13, bold: true, color: C.navy, fontFace: 'Segoe UI',
      rtlMode: true, align: 'right',
    });
    s.addText(u.d, {
      x: x + 0.15, y: y + 1.0, w: 2.7, h: 0.95,
      fontSize: 12, color: C.muted, fontFace: 'Segoe UI',
      rtlMode: true, align: 'right',
    });
  });
  addFooter(s, 6);
}

// ─── 7 الأقسام ───
{
  const s = pptx.addSlide();
  s.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: W, h: H, fill: { color: C.white } });
  slideTitle(s, '٥ — المتجر الأكاديمي: ١٥ قسماً متخصصاً');
  bodyLead(s, 'كل قسم موجّه لكليات وجمهور واضح — يظهر منتجك أمام من يحتاجه فعلاً.');

  const cats = [
    'مستلزمات ومواد كيميائية وكواشف', 'بيولوجيا وتقنية حيوية', 'طبي وصيدلي وسريري',
    'هندسة وإلكترونيات', 'فيزياء ومواد', 'زراعة وبيطري',
    'حوسبة وبرمجيات بحثية', 'مستهلكات وأدوات مختبر', 'أجهزة وأدوات قياس',
    'سلامة ومعدات وقاية', 'أدوات ميدانية ومسح', 'كتب ومراجع علمية',
    'إنسانيات وتربية', 'مستلزمات كتابة وتوثيق', 'مستلزمات عامة',
  ];
  cats.forEach((c, i) => {
    const col = i % 5;
    const row = Math.floor(i / 5);
    const x = M + col * 2.5;
    const y = 1.7 + row * 1.55;
    s.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
      x, y, w: 2.35, h: 1.35,
      fill: { color: C.soft },
      line: { color: '99F6E4', width: 1 },
      rectRadius: 0.08,
    });
    s.addText(c, {
      x: x + 0.08, y: y + 0.25, w: 2.2, h: 0.9,
      fontSize: 12, bold: true, color: C.chipText, fontFace: 'Segoe UI',
      rtlMode: true, align: 'center', valign: 'middle',
    });
  });
  addFooter(s, 7);
}

// ─── 8 بيانات المنتج ───
{
  const s = pptx.addSlide();
  s.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: W, h: H, fill: { color: C.white } });
  slideTitle(s, '٥ — ماذا تنشر كمنتج؟');

  const rows = [
    [head('الحقل'), head('إلزامي؟'), head('التفاصيل')],
    [cell('اسم المنتج'), cell('نعم'), cell('يظهر في القائمة والبحث')],
    [cell('السعر'), cell('نعم'), cell('بالجنيه · يُثبَّت من الخادم عند الطلب')],
    [cell('القسم'), cell('نعم'), cell('أحد الأقسام الخمسة عشر')],
    [cell('SKU / المنشأ / النقاء'), cell('مستحسن'), cell('يزيد ثقة الباحث والمختبر')],
    [cell('صور متعددة'), cell('مستحسن جداً'), cell('معرض في صفحة المنتج')],
    [cell('شارات الثقة'), cell('اختياري'), cell('موثّق · مستورد · ملاءمة مختبر')],
    [cell('وسائل التواصل'), cell('مستحسن'), cell('هاتف / واتساب / بريد')],
  ];
  s.addTable(rows, {
    x: M, y: 1.15, w: W - M * 2,
    colW: [3.4, 2.0, 7.083],
    border: [{ pt: 0.5, color: C.line }],
    rtlMode: true,
  });

  card(s, { x: M, y: 5.15, w: W - M * 2, h: 1.4, fill: C.soft, border: C.teal });
  s.addText(
    'المنتج يدخل قيد المراجعة ثم يظهر بعد الموافقة. المشتري: Hub → فلاتر → منتج → عربة/شراء أو RFQ → دفع → تأكيد استلام → إفراج الضمان.',
    {
      x: M + 0.25, y: 5.4, w: W - M * 2 - 0.5, h: 0.95,
      fontSize: 13, color: C.ink, fontFace: 'Segoe UI',
      rtlMode: true, align: 'right',
    },
  );
  addFooter(s, 8);
}

// ─── 9 Escrow ───
{
  const s = pptx.addSlide();
  s.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: W, h: H, fill: { color: C.white } });
  slideTitle(s, '٦ — آلية الضمان (Escrow)');
  bodyLead(s, 'أقوى حجة بيع أمام العميل المتردد — يقلل النزاعات ويسرّع إغلاق الصفقة.');

  const steps = [
    { n: '1', t: 'إنشاء طلب', d: 'السعر من قاعدة البيانات' },
    { n: '2', t: 'دفع / تحويل', d: 'يدوي أو Paymob' },
    { n: '3', t: 'حجز المبلغ', d: 'حالة paid_held' },
    { n: '4', t: 'التنفيذ', d: 'شحن وتواصل' },
    { n: '5', t: 'الإفراج', d: 'بعد تأكيد الاستلام' },
  ];
  steps.forEach((st, i) => {
    const x = M + i * 2.5;
    card(s, { x, y: 1.65, w: 2.35, h: 1.65, fill: C.soft, border: 'CCFBF1' });
    s.addShape(pptx.shapes.OVAL, {
      x: x + 0.9, y: 1.8, w: 0.5, h: 0.5,
      fill: { color: C.navy },
    });
    s.addText(st.n, {
      x: x + 0.9, y: 1.8, w: 0.5, h: 0.5,
      fontSize: 15, bold: true, color: C.white, align: 'center', valign: 'middle',
    });
    s.addText(st.t, {
      x: x + 0.1, y: 2.45, w: 2.15, h: 0.35,
      fontSize: 13, bold: true, color: C.navy, fontFace: 'Segoe UI',
      rtlMode: true, align: 'center',
    });
    s.addText(st.d, {
      x: x + 0.1, y: 2.85, w: 2.15, h: 0.3,
      fontSize: 11, color: C.muted, fontFace: 'Segoe UI',
      rtlMode: true, align: 'center',
    });
  });

  card(s, { x: M, y: 3.6, w: 6.0, h: 2.4 });
  s.addText('حالات الدفع', {
    x: M + 0.2, y: 3.75, w: 5.6, h: 0.35,
    fontSize: 14, bold: true, color: C.teal, fontFace: 'Segoe UI',
    rtlMode: true, align: 'right',
  });
  s.addText(
    'pending_payment → paid_held → released / refunded\nقواعد الخادم تربط البائع بمالك المنتج وتثبت السعر والحالة الابتدائية.',
    {
      x: M + 0.2, y: 4.25, w: 5.6, h: 1.5,
      fontSize: 13, color: C.ink, fontFace: 'Segoe UI',
      rtlMode: true, align: 'right',
    },
  );

  card(s, { x: M + 6.25, y: 3.6, w: 6.15, h: 2.4, fill: C.softGold, border: C.gold });
  s.addText('رسالة تطمئن المورد', {
    x: M + 6.45, y: 3.75, w: 5.75, h: 0.35,
    fontSize: 14, bold: true, color: C.gold, fontFace: 'Segoe UI',
    rtlMode: true, align: 'right',
  });
  s.addText(
    'لا تلاعب بالسعر من شاشة العميل. الإفراج مربوط بتأكيد الاستلام. العربة تدعم عدة موردين بطلبات منفصلة.',
    {
      x: M + 6.45, y: 4.25, w: 5.75, h: 1.5,
      fontSize: 13, color: C.ink, fontFace: 'Segoe UI',
      rtlMode: true, align: 'right',
    },
  );
  addFooter(s, 9);
}

// ─── 10 الشراكة ───
{
  const s = pptx.addSlide();
  s.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: W, h: H, fill: { color: C.white } });
  slideTitle(s, '٧ — آلية الشراكة: المورد ↔ AcadeGate');
  bodyLead(s, 'أنت تملك المنتج والسعر والتنفيذ — نحن نملك القناة والجمهور والثقة الرقمية.');

  card(s, { x: M, y: 1.65, w: 6.05, h: 4.6, fill: C.soft, border: 'CCFBF1' });
  s.addText('ماذا نقدّم نحن', {
    x: M + 0.25, y: 1.8, w: 5.55, h: 0.4,
    fontSize: 16, bold: true, color: C.navy, fontFace: 'Segoe UI',
    rtlMode: true, align: 'right',
  });
  s.addText(
    [
      'قناة وصول لطلاب الدراسات العليا والباحثين',
      '١٥ قسماً + Hub + بحث وفلاتر',
      'بوابة مورد: منتجات · طلبات · RFQ · رسائل',
      'Escrow + عربة متعددة الموردين',
      'متجر مورد عام + شارات ثقة',
      'مراجعة محتوى قبل النشر',
      'ظهور ضمن مسار البحث الذكي',
      'استيراد كتالوج (حسب الاتفاق)',
    ].map((t, i, a) => ({ text: t, options: { breakLine: i < a.length - 1 } })),
    {
      x: M + 0.25, y: 2.35, w: 5.55, h: 3.6,
      fontSize: 13, color: C.ink, fontFace: 'Segoe UI',
      rtlMode: true, align: 'right', paraSpacing: 8,
    },
  );

  card(s, { x: M + 6.3, y: 1.65, w: 6.1, h: 4.6 });
  s.addText('ماذا تقدّم أنت', {
    x: M + 6.55, y: 1.8, w: 5.6, h: 0.4,
    fontSize: 16, bold: true, color: C.teal, fontFace: 'Segoe UI',
    rtlMode: true, align: 'right',
  });
  s.addText(
    [
      'منتجات حقيقية بأسعار وصور صادقة',
      'تحديث التوفر والرد خلال وقت متفق عليه',
      'تنفيذ الشحن/التسليم كما تعرضه',
      'التعامل المهني مع التحويلات اليدوية',
      'الرد على RFQ والأسئلة على المنتج',
      'الالتزام بسياسات المحتوى',
      '',
      'التسعير: أنت تسعّر بالكامل',
      'الدور: تاجر (merchant)',
    ].map((t, i, a) => ({ text: t, options: { breakLine: i < a.length - 1 } })),
    {
      x: M + 6.55, y: 2.35, w: 5.6, h: 3.6,
      fontSize: 13, color: C.ink, fontFace: 'Segoe UI',
      rtlMode: true, align: 'right', paraSpacing: 8,
    },
  );
  addFooter(s, 10);
}

// ─── 11 داخل التطبيق ───
{
  const s = pptx.addSlide();
  s.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: W, h: H, fill: { color: C.white } });
  slideTitle(s, '٨ — ماذا تفعل داخل التطبيق عملياً؟');

  const steps2 = [
    'حساب بدور تاجر / مورد',
    'بوابة مقدم الخدمة',
    'متجري → إضافة منتج (حقول غنية + شارات)',
    'انتظار موافقة المراجعة',
    'ظهور في Hub ومتجر المورد',
    'استقبال طلبات العربة / الشراء المباشر',
    'الرد على RFQ وأسئلة المنتج',
    'تأكيد التحويل · الشحن · إغلاق الضمان',
  ];
  steps2.forEach((t, i) => {
    const y = 1.2 + i * 0.55;
    s.addShape(pptx.shapes.OVAL, {
      x: W - M - 0.45, y: y + 0.05, w: 0.38, h: 0.38,
      fill: { color: i % 2 === 0 ? C.navy : C.teal },
    });
    s.addText(String(i + 1), {
      x: W - M - 0.45, y: y + 0.05, w: 0.38, h: 0.38,
      fontSize: 12, bold: true, color: C.white, align: 'center', valign: 'middle',
    });
    s.addText(t, {
      x: M + 6.3, y, w: 5.9, h: 0.48,
      fontSize: 13.5, color: C.ink, fontFace: 'Segoe UI',
      rtlMode: true, align: 'right', valign: 'middle',
    });
  });

  card(s, { x: M, y: 1.2, w: 5.6, h: 2.4 });
  s.addText('تبويب منتجاتي', {
    x: M + 0.25, y: 1.35, w: 5.1, h: 0.4,
    fontSize: 15, bold: true, color: C.navy, fontFace: 'Segoe UI',
    rtlMode: true, align: 'right',
  });
  s.addText('عرض المنتجات وحالة الاعتماد\nإضافة منتج جديد بحقول غنية\nفتح التفاصيل / الحذف', {
    x: M + 0.25, y: 1.9, w: 5.1, h: 1.4,
    fontSize: 13, color: C.ink, fontFace: 'Segoe UI',
    rtlMode: true, align: 'right',
  });

  card(s, { x: M, y: 3.8, w: 5.6, h: 2.4, fill: C.soft, border: 'CCFBF1' });
  s.addText('تبويب الطلبات', {
    x: M + 0.25, y: 3.95, w: 5.1, h: 0.4,
    fontSize: 15, bold: true, color: C.teal, fontFace: 'Segoe UI',
    rtlMode: true, align: 'right',
  });
  s.addText('طلبات العربة والشراء المباشر\nتمييز دفع يدوي / إلكتروني\nتأكيد التحويل · مراسلة المشتري', {
    x: M + 0.25, y: 4.5, w: 5.1, h: 1.4,
    fontSize: 13, color: C.ink, fontFace: 'Segoe UI',
    rtlMode: true, align: 'right',
  });
  addFooter(s, 11);
}

// ─── 12 الإيرادات الحالي ───
{
  const s = pptx.addSlide();
  s.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: W, h: H, fill: { color: C.white } });
  slideTitle(s, '٩ — نموذج الإيرادات بشفافية (الوضع والمقترح الأساسي)');
  bodyLead(s, 'ما يعمل اليوم · وما يُقترح للشراكة — بلا مبالغة.');

  const rev = [
    [head('البند'), head('المقترح الأساسي'), head('ملاحظات')],
    [cell('عمولة على طلب Escrow ناجح'), cell('٥–١٥٪'), cell('تُناقش حسب حجم الكتالوج')],
    [cell('مثال'), cell('٨٠٠ ج.م × ٨٪ ≈ ٦٤ ج.م'), cell('للمنصة · صافيك بعد الاتفاق')],
    [cell('دليل Directory (تواصل فقط)'), cell('مجاني أو اشتراك خفيف'), cell('لا عمولة شراء إن لم يمر عبر Escrow')],
    [cell('استيراد كتالوج'), cell('رسوم لمرة واحدة'), cell('مزامنة WooCommerce / CSV')],
  ];
  s.addTable(rev, {
    x: M, y: 1.6, w: W - M * 2,
    colW: [4.2, 3.5, 4.783],
    border: [{ pt: 0.5, color: C.line }],
    rtlMode: true,
  });

  card(s, { x: M, y: 4.35, w: W - M * 2, h: 2.15, fill: C.softGold, border: C.gold });
  s.addText('شفافية مهمة', {
    x: M + 0.3, y: 4.5, w: W - M * 2 - 0.6, h: 0.35,
    fontSize: 15, bold: true, color: C.gold, fontFace: 'Segoe UI',
    rtlMode: true, align: 'right',
  });
  s.addText(
    'حالياً لا تُخصم عمولة تلقائياً من بوابة الدفع. التسوية (نسبة لكل طلب أو فاتورة شهرية) تُثبَّت في اتفاق الشراكة. تدفع على نجاح (طلب منفذ) لا على مجرد ظهور. الشريحة التالية تعرض بدائل أغنى لنمو الإيرادات.',
    {
      x: M + 0.3, y: 4.95, w: W - M * 2 - 0.6, h: 1.3,
      fontSize: 13, color: C.ink, fontFace: 'Segoe UI',
      rtlMode: true, align: 'right',
    },
  );
  addFooter(s, 12);
}

// ─── 13 مقترحات إيرادات إضافية ───
{
  const s = pptx.addSlide();
  s.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: W, h: H, fill: { color: C.white } });
  slideTitle(s, '٩ — مقترحات إضافية لنموذج الإيرادات');
  bodyLead(s, 'لا نعتمد على عمولة واحدة فقط — مزيج Marketplace + SaaS أنسب للنمو والاستدامة.');

  const ideas = [
    {
      t: 'عمولة متدرجة حسب القسم',
      d: 'كواشف/أجهزة هامش أعلى (١٠–١٥٪) · كتب/مستهلكات أقل (٥–٨٪) — أقرب لواقع السوق.',
    },
    {
      t: 'اشتراك مورد مميّز (SaaS)',
      d: 'باقة شهرية: ظهور أعلى في Hub · شارة · تحليلات طلبات · أولوية مراجعة — دخل متكرر للمنصة.',
    },
    {
      t: 'رسوم تحويل RFQ',
      d: 'مجاني لفتح الطلب · عمولة أعلى (١٢–١٨٪) عند تحويل عرض السعر لطلب مدفوع.',
    },
    {
      t: 'إعلانات داخل المتجر',
      d: 'راعي قسم / بنر في Hub / منتج مموّل — بدون إزعاج واجهة الباحث إن بقيت محدودة.',
    },
    {
      t: 'باقة مختبر / جامعة (B2B)',
      d: 'عقد سنوي لمشتريات متكررة + فاتورة مجمّعة — أعلى قيمة متوسط الطلب (AOV).',
    },
    {
      t: 'تجربة شراكة مبكرة',
      d: '٣ أشهر عمولة مخفّضة (مثلاً ٥٪) لأول ١٠ موردين — ثم العودة للشريحة المعيارية.',
    },
  ];
  ideas.forEach((idea, i) => {
    const col = i % 3;
    const row = Math.floor(i / 3);
    const x = M + col * 4.15;
    const y = 1.6 + row * 2.4;
    card(s, { x, y, w: 3.95, h: 2.2 });
    s.addShape(pptx.shapes.RECTANGLE, {
      x: x + 3.85, y, w: 0.1, h: 2.2,
      fill: { color: row === 0 ? C.navy : C.teal },
    });
    s.addText(idea.t, {
      x: x + 0.15, y: y + 0.2, w: 3.55, h: 0.55,
      fontSize: 13, bold: true, color: C.navy, fontFace: 'Segoe UI',
      rtlMode: true, align: 'right',
    });
    s.addText(idea.d, {
      x: x + 0.15, y: y + 0.85, w: 3.55, h: 1.15,
      fontSize: 12, color: C.muted, fontFace: 'Segoe UI',
      rtlMode: true, align: 'right',
    });
  });
  addFooter(s, 13);
}

// ─── 14 أشياء مهمة ───
{
  const s = pptx.addSlide();
  s.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: W, h: H, fill: { color: C.white } });
  slideTitle(s, '١٠ — أشياء يجب أن تكون على علم بها');

  const notes = [
    { t: 'جمهور عربي وأكاديمي', d: 'واجهة RTL · أسعار بالجنيه · تواصل سريع' },
    { t: 'الجودة قبل الكمية', d: 'المراجعة فلتر يحمي سمعة الجميع' },
    { t: 'الدفع الإلكتروني', d: 'يدوي الآن · Paymob جاهز للتفعيل' },
    { t: 'دليل أو شراء Escrow', d: 'أو الاثنان حسب استراتيجيتك' },
    { t: 'خصوصية وشروط', d: 'موافقة عند التسجيل · صفحات قانونية محدّثة' },
    { t: 'ملكية البيانات', d: 'كتالوجك يبقى لك — نحن قناة توزيع' },
  ];
  notes.forEach((n, i) => {
    const col = i % 3;
    const row = Math.floor(i / 3);
    const x = M + col * 4.15;
    const y = 1.3 + row * 2.55;
    card(s, { x, y, w: 3.95, h: 2.3 });
    s.addShape(pptx.shapes.RECTANGLE, {
      x: x + 3.85, y, w: 0.1, h: 2.3,
      fill: { color: row === 0 ? C.navy : C.teal },
    });
    s.addText(n.t, {
      x: x + 0.2, y: y + 0.35, w: 3.5, h: 0.7,
      fontSize: 15, bold: true, color: C.navy, fontFace: 'Segoe UI',
      rtlMode: true, align: 'right',
    });
    s.addText(n.d, {
      x: x + 0.2, y: y + 1.15, w: 3.5, h: 0.8,
      fontSize: 13, color: C.muted, fontFace: 'Segoe UI',
      rtlMode: true, align: 'right',
    });
  });
  addFooter(s, 14);
}

// ─── 15 لماذا الآن + CTA مختصر ───
{
  const s = pptx.addSlide();
  s.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: W, h: H, fill: { color: C.white } });
  slideTitle(s, '١١ — لماذا الآن؟ وخطوات البدء');

  const why = [
    { t: 'ميزة الرائد', d: 'أول الموردين يبنون سمعة وكتالوجاً يظهر أولاً' },
    { t: 'المتجر صار جاهزاً أكثر', d: 'Hub · عربة · RFQ · متاجر موردين — أقل احتكاكاً للمشتري' },
    { t: 'تأثير الشبكة', d: 'كل باحث جديد يرى متجرك ضمن رحلته' },
    { t: 'مرونة التجربة', d: 'ابدأ بـ ٣–١٠ منتجات عالية الدوران ثم وسّع' },
  ];
  why.forEach((w, i) => {
    const y = 1.25 + i * 0.85;
    card(s, { x: M, y, w: W - M * 2, h: 0.75, fill: i % 2 ? C.soft : C.white, border: i % 2 ? 'CCFBF1' : C.line });
    s.addText(`${i + 1}. ${w.t} — ${w.d}`, {
      x: M + 0.25, y: y + 0.15, w: W - M * 2 - 0.5, h: 0.45,
      fontSize: 14, color: C.ink, fontFace: 'Segoe UI',
      rtlMode: true, align: 'right', valign: 'middle',
    });
  });

  card(s, { x: M, y: 4.8, w: W - M * 2, h: 1.7, fill: C.navy, border: C.navy });
  s.addText('الخطوات: تواصل كشريك → حساب تاجر → ٣–١٠ منتجات → اتفاق قسم وعمولة', {
    x: M + 0.3, y: 5.0, w: W - M * 2 - 0.6, h: 0.4,
    fontSize: 14, bold: true, color: C.white, fontFace: 'Segoe UI',
    rtlMode: true, align: 'right',
  });
  s.addText(
    'المنصة: https://acadegate-new--v20261002-tp9dbk1c.web.app   ·   التسجيل: https://acadegate-new--v20261002-tp9dbk1c.web.app/register',
    {
      x: M + 0.3, y: 5.45, w: W - M * 2 - 0.6, h: 0.35,
      fontSize: 13, bold: true, color: C.goldSoft, fontFace: 'Segoe UI',
      rtlMode: true, align: 'right',
    },
  );
  s.addText(
    'بريد: acadegate@gmail.com   ·   بديل واتساب: https://acadegate-new.firebaseapp.com',
    {
      x: M + 0.3, y: 5.85, w: W - M * 2 - 0.6, h: 0.35,
      fontSize: 12, color: 'E2E8F0', fontFace: 'Segoe UI',
      rtlMode: true, align: 'right',
    },
  );
  addFooter(s, 15);
}

// ─── 16 ملحق ───
{
  const s = pptx.addSlide();
  s.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: W, h: H, fill: { color: C.white } });
  slideTitle(s, 'ملحق — ملخص تنفيذي لصفحة واحدة');

  const summary = [
    [head('البند'), head('المحتوى')],
    [cell('فكرة المنصة'), cell('رحلة دراسات عليا متكاملة — المتجر نقطة التنفيذ المادي')],
    [cell('عرض المورد'), cell('قناة بيع أكاديمية + Escrow + Hub + عربة + RFQ')],
    [cell('الأقسام'), cell('١٥ قسماً متخصصاً')],
    [cell('الدور'), cell('merchant (تاجر)')],
    [cell('الظهور'), cell('بعد موافقة الإدارة')],
    [cell('الدفع'), cell('تحويل يدوي الآن · Paymob جاهز')],
    [cell('إيراد أساسي'), cell('عمولة ٥–١٥٪ على طلب ناجح (بالاتفاق)')],
    [cell('إيرادات مقترحة'), cell('اشتراك مميّز · RFQ · إعلان · B2B · عمولة متدرجة')],
    [cell('الخطوة التالية'), cell('حساب تجريبي + كتالوج صغير + اجتماع تشغيل')],
    [cell('المنصة'), cell('https://acadegate-new--v20261002-tp9dbk1c.web.app')],
    [cell('التسجيل'), cell('https://acadegate-new--v20261002-tp9dbk1c.web.app/register')],
  ];
  s.addTable(summary, {
    x: M, y: 1.15, w: W - M * 2,
    colW: [3.5, 8.983],
    border: [{ pt: 0.5, color: C.line }],
    rtlMode: true,
  });

  s.addText(
    'مبني على وظائف التطبيق الفعلية. الأرقام قابلة للتفاوض. أعِد التوليد: npm run pitch:suppliers',
    {
      x: M, y: 6.55, w: W - M * 2, h: 0.4,
      fontSize: 11, color: C.muted, fontFace: 'Segoe UI',
      rtlMode: true, align: 'right',
    },
  );
  addFooter(s, 16);
}

try {
  await pptx.writeFile({ fileName: outPrimary });
  console.log('PPTX:', outPrimary);
} catch (err) {
  if (err && (err.code === 'EBUSY' || err.code === 'EPERM')) {
    await pptx.writeFile({ fileName: outFallback });
    console.log('PPTX locked — wrote:', outFallback);
    console.log('Close the open PowerPoint file then re-run to overwrite the main name.');
  } else {
    throw err;
  }
}
