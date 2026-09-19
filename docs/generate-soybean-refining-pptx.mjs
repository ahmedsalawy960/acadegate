/**
 * تكرير زيت الصويا — UCCMA · إعداد: أحمد سلاوي
 * تشغيل: node generate-soybean-refining-pptx.mjs
 */
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import PptxGenJS from 'pptxgenjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const out = path.join(__dirname, 'Soybean_Oil_Refining_UCCMA_AR.pptx');
const imgDir = path.join(__dirname, 'soybean_refinery_assets');
const img = (name) => path.join(imgDir, name);

const C = {
  ink: '14201A',
  muted: '4D5C54',
  navy: '16324F',
  green: '1F5C45',
  oil: 'C47A1A',
  oilDeep: '8A5410',
  cream: 'F3EFE4',
  soft: 'E6F1EB',
  warn: 'FFF7E8',
  line: 'D5DDD7',
  white: 'FFFFFF',
  sand: 'FAF8F2',
};

const pptx = new PptxGenJS();
pptx.defineLayout({ name: 'WIDE', width: 13.333, height: 7.5 });
pptx.layout = 'WIDE';
pptx.author = 'أحمد سلاوي';
pptx.title = 'تكرير زيت الصويا — UCCMA';
pptx.subject = 'عرض تشغيلي · 200 طن/يوم · إعداد أحمد سلاوي';
pptx.rtlMode = true;

const W = 13.333;
const H = 7.5;
const M = 0.42;
const TOTAL = 16;

function addFooter(slide, page) {
  slide.addShape(pptx.shapes.RECTANGLE, {
    x: 0, y: H - 0.36, w: W, h: 0.36,
    fill: { color: C.cream },
  });
  slide.addText('تكرير زيت الصويا · UCCMA · إعداد: أحمد سلاوي', {
    x: M, y: H - 0.32, w: 9.5, h: 0.26,
    fontSize: 10, color: C.muted, fontFace: 'Segoe UI', rtlMode: true, align: 'right',
  });
  slide.addText(`${page} / ${TOTAL}`, {
    x: W - M - 1.2, y: H - 0.32, w: 1.2, h: 0.26,
    fontSize: 10, color: C.muted, fontFace: 'Segoe UI', align: 'left',
  });
}

function slideTitle(slide, title) {
  slide.addShape(pptx.shapes.RECTANGLE, {
    x: M, y: 0.26, w: 0.11, h: 0.5,
    fill: { color: C.oil },
  });
  slide.addText(title, {
    x: M + 0.2, y: 0.2, w: W - M * 2 - 0.2, h: 0.56,
    fontSize: 24, bold: true, color: C.navy, fontFace: 'Segoe UI',
    rtlMode: true, align: 'right', valign: 'middle',
  });
  slide.addShape(pptx.shapes.RECTANGLE, {
    x: M, y: 0.86, w: W - M * 2, h: 0.03,
    fill: { color: C.green },
  });
}

function card(slide, { x, y, w, h, fill = C.white, border = C.line }) {
  slide.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
    x, y, w, h,
    fill: { color: fill },
    line: { color: border, width: 1 },
    rectRadius: 0.08,
  });
}

function bullets(slide, items, { x, y, w, h, size = 13, color = C.ink }) {
  slide.addText(
    items.map((t) => ({ text: t, options: { breakLine: true } })),
    {
      x, y, w, h,
      fontSize: size, color, fontFace: 'Segoe UI',
      rtlMode: true, align: 'right', valign: 'top',
      paraSpaceAfter: 6,
      bullet: { code: '25CF' },
    },
  );
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
      fontSize: 11,
      color: C.ink,
      fill: { color: C.white },
      ...opts,
    },
  };
}
function head(text) {
  return cell(text, { bold: true, color: C.white, fill: { color: C.navy }, fontSize: 11 });
}

// ─── 1 غلاف ───
{
  const s = pptx.addSlide();
  s.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: W, h: H, fill: { color: C.navy } });
  s.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: 0.28, h: H, fill: { color: C.oil } });
  s.addText('UCCMA · Refinery Operations', {
    x: M + 0.2, y: 1.5, w: W - M * 2, h: 0.4,
    fontSize: 14, color: 'F0D09A', fontFace: 'Segoe UI', rtlMode: true, align: 'right',
  });
  s.addText('تكرير زيت الصويا', {
    x: M + 0.2, y: 2.0, w: W - M * 2, h: 0.9,
    fontSize: 42, bold: true, color: C.white, fontFace: 'Segoe UI', rtlMode: true, align: 'right',
  });
  s.addText('عرض تشغيلي مفصّل لوحدة التكرير · القدرة الإنتاجية 200 طن / يوم', {
    x: M + 0.2, y: 3.0, w: 10, h: 0.45,
    fontSize: 16, color: 'D7E5DD', fontFace: 'Segoe UI', rtlMode: true, align: 'right',
  });
  s.addText('إعداد: أحمد سلاوي', {
    x: M + 0.2, y: 4.0, w: 5, h: 0.45,
    fontSize: 18, bold: true, color: 'FFDFA0', fontFace: 'Segoe UI', rtlMode: true, align: 'right',
  });
  s.addText('المصدر: ملف التشغيل + شاشات SCADA للمصنع', {
    x: M + 0.2, y: 5.8, w: 9, h: 0.35,
    fontSize: 12, color: 'A8BDB2', fontFace: 'Segoe UI', rtlMode: true, align: 'right',
  });
}

// ─── 2 فهرس ───
{
  const s = pptx.addSlide();
  s.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: W, h: H, fill: { color: C.sand } });
  slideTitle(s, 'محاور العرض');
  card(s, { x: M, y: 1.15, w: 7.4, h: 5.5 });
  bullets(s, [
    'القدرة الإنتاجية (200 طن/يوم)',
    'لماذا نكرّر الزيت ولا نستخدمه خاماً؟',
    'الخزانات والتنكات',
    'الوحدات المساعدة (فاكيوم · بخار · تبريد…)',
    'المراحل الأساسية بالتفصيل',
    'مؤشرات الجودة قبل/بعد كل مرحلة',
  ], { x: M + 0.35, y: 1.4, w: 6.8, h: 5.0, size: 18 });
  card(s, { x: 8.1, y: 1.15, w: 4.8, h: 5.5, fill: C.green, border: C.green });
  s.addText('فكرة العرض', {
    x: 8.35, y: 1.45, w: 4.3, h: 0.45,
    fontSize: 18, bold: true, color: C.white, fontFace: 'Segoe UI', rtlMode: true, align: 'right',
  });
  bullets(s, [
    'ملاحظات التشغيل من ملف الوحدة',
    'شاشات SCADA الفعلية',
    'خلفية تقنية لكل مرحلة',
    'هدف: تدريب تشغيلي عملي',
  ], { x: 8.35, y: 2.1, w: 4.3, h: 3.8, size: 14, color: C.white });
  addFooter(s, 2);
}

// ─── 3 قدرة ───
{
  const s = pptx.addSlide();
  s.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: W, h: H, fill: { color: C.sand } });
  slideTitle(s, 'القدرة الإنتاجية — 200 طن / يوم');
  const kpis = [
    ['200', 'طن زيت / يوم'],
    ['≈ 8.3', 'طن / ساعة (متوسط)'],
    ['600', 'طن سعة التنك'],
    ['3', 'مراحل تكرير أساسية'],
  ];
  kpis.forEach((k, i) => {
    const x = M + i * 3.15;
    card(s, { x, y: 1.15, w: 3.0, h: 1.7 });
    s.addText(k[0], {
      x, y: 1.3, w: 3.0, h: 0.8,
      fontSize: 32, bold: true, color: C.oilDeep, fontFace: 'Segoe UI', align: 'center',
    });
    s.addText(k[1], {
      x: x + 0.1, y: 2.15, w: 2.8, h: 0.45,
      fontSize: 13, color: C.muted, fontFace: 'Segoe UI', rtlMode: true, align: 'center',
    });
  });
  card(s, { x: M, y: 3.15, w: 6.1, h: 3.5 });
  s.addText('ماذا تعني 200 طن/يوم عملياً؟', {
    x: M + 0.25, y: 3.3, w: 5.6, h: 0.4,
    fontSize: 15, bold: true, color: C.green, fontFace: 'Segoe UI', rtlMode: true, align: 'right',
  });
  bullets(s, [
    'تشغيل شبه مستمر مع تخطيط تغذية من تنكات الخام',
    'توازن بين الاستقبال والمعادلة وفلاتر التبييض وعمود الإزالة',
    'أي عنق زجاجة يظهر فوراً على معدل الإنتاج اليومي',
  ], { x: M + 0.25, y: 3.8, w: 5.6, h: 2.5, size: 13 });
  card(s, { x: 6.85, y: 3.15, w: 6.05, h: 3.5, fill: C.warn, border: 'EFD3A0' });
  s.addText('ملاحظة تشغيلية', {
    x: 7.1, y: 3.3, w: 5.55, h: 0.4,
    fontSize: 15, bold: true, color: C.oilDeep, fontFace: 'Segoe UI', rtlMode: true, align: 'right',
  });
  bullets(s, [
    'خام بمواصفات مقبولة (FFA / رطوبة / فوسفوليبيدات)',
    'جاهزية الكيماويات والفاكيوم والبخار',
    'دورة فلاتر التبييض منتظمة دون توقف طويل',
  ], { x: 7.1, y: 3.8, w: 5.55, h: 2.5, size: 13 });
  addFooter(s, 3);
}

// ─── 4 لماذا التكرير ───
{
  const s = pptx.addSlide();
  s.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: W, h: H, fill: { color: C.sand } });
  slideTitle(s, 'لماذا لا يُستخدم زيت الصويا خاماً؟');
  s.addText('الزيت الخام بعد الاستخلاص يحتوي شوائب تجعل استخدامه مباشرة غير مناسب غذائياً ولا تجارياً.', {
    x: M, y: 1.05, w: W - M * 2, h: 0.4,
    fontSize: 14, color: C.muted, fontFace: 'Segoe UI', rtlMode: true, align: 'right',
  });
  const cols = [
    ['1) أحماض دهنية حرة FFA', 'ترفع الحموضة والطعم غير المرغوب، وتسرّع التزنخ، وتُضعف ثبات الزيت في القلي والتخزين.'],
    ['2) صموغ وفوسفوليبيدات', 'تسبب عكارة ورغاوي وصعوبة ترشيح/قلي. تُزال بالفوسفوريك ثم الفصل بالطرد المركزي.'],
    ['3) أصباغ وأكسدة', 'كاروتين وكلوروفيل تعطي لوناً داكناً. نواتج الأكسدة والروائح تُزال في التبييض والإزالة.'],
  ];
  cols.forEach((c, i) => {
    const x = M + i * 4.2;
    card(s, { x, y: 1.6, w: 4.0, h: 2.6 });
    s.addText(c[0], {
      x: x + 0.2, y: 1.8, w: 3.6, h: 0.55,
      fontSize: 15, bold: true, color: C.green, fontFace: 'Segoe UI', rtlMode: true, align: 'right',
    });
    s.addText(c[1], {
      x: x + 0.2, y: 2.45, w: 3.6, h: 1.5,
      fontSize: 13, color: C.ink, fontFace: 'Segoe UI', rtlMode: true, align: 'right',
    });
  });
  card(s, { x: M, y: 4.45, w: W - M * 2, h: 2.2 });
  s.addText('ما الذي يحققه التكرير؟', {
    x: M + 0.25, y: 4.6, w: W - M * 2 - 0.5, h: 0.35,
    fontSize: 15, bold: true, color: C.navy, fontFace: 'Segoe UI', rtlMode: true, align: 'right',
  });
  bullets(s, [
    'خفض FFA إلى أقل من 0.1%  ·  خفض الصابون إلى أقل من 100 ppm',
    'تحسين اللون والطعم والرائحة ورفع الثبات التخزيني',
    'مطابقة مواصفات السوق والتعبئة وتقليل الفاقد في خطوط القلي',
  ], { x: M + 0.25, y: 5.05, w: W - M * 2 - 0.5, h: 1.4, size: 13 });
  addFooter(s, 4);
}

// ─── 5 مسار ───
{
  const s = pptx.addSlide();
  s.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: W, h: H, fill: { color: C.sand } });
  slideTitle(s, 'خريطة المسار التشغيلي');
  const steps = ['استخلاص', 'خام', 'وسيط 102', 'معادلة', 'تبييض', 'Deaerator', 'إزالة', 'مكرر'];
  steps.forEach((t, i) => {
    const x = M + i * 1.58;
    card(s, { x, y: 1.2, w: 1.45, h: 0.75, fill: i % 2 ? C.soft : C.white });
    s.addText(t, {
      x, y: 1.35, w: 1.45, h: 0.45,
      fontSize: 12, bold: true, color: C.navy, fontFace: 'Segoe UI', rtlMode: true, align: 'center',
    });
  });
  const stages = [
    ['Neutralization', 'إزالة FFA والصموغ بفوسفوريك + صودا + separators ثم غسيل و citric.'],
    ['Bleaching', 'تراب مبيّض تحت فاكيوم لنزع الأصباغ وبقايا الصابون والرطوبة والفوسفور.'],
    ['Deodorization', 'تحت فاكيوم عالٍ وبخار شريطي لإزالة الروائح والـ FFA المتبقية ونواتج الأكسدة.'],
  ];
  stages.forEach((st, i) => {
    const x = M + i * 4.2;
    card(s, { x, y: 2.3, w: 4.0, h: 4.2, fill: C.green, border: C.green });
    s.addText(st[0], {
      x: x + 0.2, y: 2.55, w: 3.6, h: 0.5,
      fontSize: 18, bold: true, color: C.white, fontFace: 'Segoe UI', rtlMode: true, align: 'right',
    });
    s.addText(st[1], {
      x: x + 0.2, y: 3.25, w: 3.6, h: 2.8,
      fontSize: 14, color: C.white, fontFace: 'Segoe UI', rtlMode: true, align: 'right',
    });
  });
  addFooter(s, 5);
}

// ─── 6 تنكات ───
{
  const s = pptx.addSlide();
  s.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: W, h: H, fill: { color: C.sand } });
  slideTitle(s, 'الخزانات والتنكات');
  s.addTable(
    [
      [head('المجموعة'), head('الترقيم'), head('الوظيفة')],
      [cell('تنكات الاستخلاص'), cell('2001 – 2003'), cell('استقبال زيت الاستخلاص وسحبه لتنكات التكرير')],
      [cell('تنكات خام'), cell('1001 – 1002'), cell('تغذية وحدة التكرير بالخام')],
      [cell('تنكات مكرر'), cell('1003 – 1006'), cell('تخزين الزيت المكرر النهائي')],
      [cell('تنك وسيط خام'), cell('102'), cell('بداية المعادلة والغسيل')],
      [cell('سعة التنك'), cell('600 طن'), cell('ضمان استمرارية التغذية')],
    ],
    {
      x: M, y: 1.15, w: 7.2, h: 4.2,
      colW: [2.0, 1.7, 3.5],
      border: [{ pt: 0.5, color: C.line }],
      fontFace: 'Segoe UI',
      rtlMode: true,
    },
  );
  card(s, { x: 7.7, y: 1.15, w: 5.2, h: 5.5 });
  safeImage(s, img('scada_tanks_farm.png'), { x: 7.9, y: 1.35, w: 4.8, h: 3.4 });
  s.addText('شاشة مزرعة التنكات · SCADA', {
    x: 7.9, y: 4.9, w: 4.8, h: 0.35,
    fontSize: 12, color: C.muted, fontFace: 'Segoe UI', rtlMode: true, align: 'center',
  });
  bullets(s, [
    'تنكات مساعدة: صودا · أحماض · صابون · سولار',
  ], { x: 7.9, y: 5.4, w: 4.8, h: 0.8, size: 12 });
  addFooter(s, 6);
}

// ─── 7 تخزين SCADA ───
{
  const s = pptx.addSlide();
  s.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: W, h: H, fill: { color: C.sand } });
  slideTitle(s, 'التخزين التشغيلي والمنتجات الثانوية');
  safeImage(s, img('scada_storage.png'), { x: M, y: 1.15, w: 7.0, h: 5.4 });
  card(s, { x: 7.4, y: 1.15, w: 5.5, h: 5.4 });
  s.addText('ما يظهر على الشاشة', {
    x: 7.65, y: 1.35, w: 5.0, h: 0.4,
    fontSize: 16, bold: true, color: C.green, fontFace: 'Segoe UI', rtlMode: true, align: 'right',
  });
  bullets(s, [
    'FK201: تنك زيت خام / تغذية',
    'FK102-1/2: تنكات زيت مكرر',
    'FK103/104: Soapstock → شاحنة',
    'FK106: أحماض دهنية',
    'FK107: صودا كاوية سائلة',
    'FK105: ديزل / سولار',
  ], { x: 7.65, y: 1.9, w: 5.0, h: 4.2, size: 14 });
  addFooter(s, 7);
}

// ─── 8 مساعدات ───
{
  const s = pptx.addSlide();
  s.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: W, h: H, fill: { color: C.sand } });
  slideTitle(s, 'الوحدات المساعدة');
  const items = [
    ['فاكيوم', 'أساسي للتبييض والإزالة ومنع الأكسدة. الهدف في الإزالة غالباً 2–6 mbar.'],
    ['بخار Steam', 'تسخين الزيت، stripping في الديودورايزر، وتشغيل Steam Ejectors.'],
    ['مياه تبريد', 'Cooling tower + condensers + chiller لتقوية الفاكيوم وتبريد المنتج.'],
    ['هواء مضغوط', 'تشغيل صمامات وتحكم، ودعم دورات Blow/Empty في فلاتر التبييض.'],
    ['مياه ناعمة/ساخنة', 'غسيل separators وتنكات، وخطوط Hot/Soft water.'],
    ['كيماويات', 'فوسفوريك · صودا · ستريك · تراب مبيّض (~5 كجم/طن).'],
  ];
  items.forEach((it, i) => {
    const col = i % 3;
    const row = Math.floor(i / 3);
    const x = M + col * 4.2;
    const y = 1.2 + row * 2.7;
    card(s, { x, y, w: 4.0, h: 2.45 });
    s.addText(it[0], {
      x: x + 0.2, y: y + 0.25, w: 3.6, h: 0.45,
      fontSize: 16, bold: true, color: C.oilDeep, fontFace: 'Segoe UI', rtlMode: true, align: 'right',
    });
    s.addText(it[1], {
      x: x + 0.2, y: y + 0.85, w: 3.6, h: 1.3,
      fontSize: 13, color: C.ink, fontFace: 'Segoe UI', rtlMode: true, align: 'right',
    });
  });
  addFooter(s, 8);
}

// ─── 9 فاكيوم ───
{
  const s = pptx.addSlide();
  s.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: W, h: H, fill: { color: C.sand } });
  slideTitle(s, 'نظام الفاكيوم والتبريد');
  card(s, { x: M, y: 1.15, w: 6.5, h: 5.5 });
  bullets(s, [
    'Tower cold: يبرّد الشيلر والزيت الخارج ومكثفات الفاكيوم',
    'Acid tower: يدفع ماء إلى condensers / barometric',
    'Chiller: يبرّد المكثفات لتقوية الفاكيوم',
    'Steam Ejector: يسحب الغازات غير القابلة للتكثف (هدف 2–6 mbar)',
    'Vacuum Booster: يزيد قدرة السحب عند الأحمال العالية',
    'Condensers + Scrubber: تكثيف الأحماض وربط نواتج الإزالة',
  ], { x: M + 0.25, y: 1.4, w: 6.0, h: 5.0, size: 13 });
  safeImage(s, img('scada_vacuum_cooling.png'), { x: 7.3, y: 1.15, w: 5.6, h: 5.5 });
  addFooter(s, 9);
}

// ─── 10 قبل التشغيل ───
{
  const s = pptx.addSlide();
  s.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: W, h: H, fill: { color: C.sand } });
  slideTitle(s, 'قبل تشغيل المعادلة — Checklist');
  card(s, { x: M, y: 1.15, w: 6.1, h: 5.5, fill: C.warn, border: 'EFD3A0' });
  s.addText('مواصفات خام مثال', {
    x: M + 0.25, y: 1.4, w: 5.6, h: 0.4,
    fontSize: 16, bold: true, color: C.oilDeep, fontFace: 'Segoe UI', rtlMode: true, align: 'right',
  });
  s.addTable(
    [
      [head('البيان'), head('قيمة مثال')],
      [cell('FFA'), cell('0.4 %')],
      [cell('Moisture'), cell('0.1 %')],
      [cell('Phospholipids'), cell('0.2 %')],
      [cell('Colour'), cell('10 / 60')],
    ],
    {
      x: M + 0.3, y: 2.0, w: 5.5, h: 3.2,
      colW: [2.7, 2.8],
      border: [{ pt: 0.5, color: C.line }],
      fontFace: 'Segoe UI',
      rtlMode: true,
    },
  );
  card(s, { x: 6.85, y: 1.15, w: 6.05, h: 5.5 });
  s.addText('تحضير قبل التشغيل', {
    x: 7.1, y: 1.4, w: 5.55, h: 0.4,
    fontSize: 16, bold: true, color: C.green, fontFace: 'Segoe UI', rtlMode: true, align: 'right',
  });
  bullets(s, [
    'تحضير الكيماويات وعمل cycle على طلمبات الصودا والفوسفوريك وتنك الوسيط',
    'غسيل الـ separators',
    'التأكد أن الخطوط مفتوح عليها',
    'التأكد أن الفاكيوم شغال',
    'ثم التشغيل بعد الاستعداد الكامل',
  ], { x: 7.1, y: 2.0, w: 5.55, h: 4.2, size: 14 });
  addFooter(s, 10);
}

// ─── 11 معادلة ───
{
  const s = pptx.addSlide();
  s.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: W, h: H, fill: { color: C.sand } });
  slideTitle(s, 'مرحلة المعادلة والغسيل (Neutralization)');
  card(s, { x: M, y: 1.1, w: 6.4, h: 5.55 });
  bullets(s, [
    'تنك وسيط 102 → فلتر شوائب',
    'مبادل زيت/زيت ثم زيت/بخار → ≈ 65°م',
    'حقن فوسفوريك → Mixer → Retention',
    'حقن صودا → Mixer → Retention',
    'Separator 1: فصل Soapstock + gums',
    'ماء + ستريك → Separator 2 لبقايا الصابون',
    'Heater ثم Dryer للتخلص من الرطوبة',
    'الهدف: FFA < 0.1  |  Soap < 100 ppm',
  ], { x: M + 0.25, y: 1.3, w: 5.9, h: 5.1, size: 13 });
  safeImage(s, img('scada_neutralization.png'), { x: 7.1, y: 1.1, w: 5.8, h: 5.55 });
  addFooter(s, 11);
}

// ─── 12 تبييض ───
{
  const s = pptx.addSlide();
  s.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: W, h: H, fill: { color: C.sand } });
  slideTitle(s, 'مرحلة التبييض والترشيح (Bleaching)');
  card(s, { x: M, y: 1.1, w: 6.4, h: 5.55 });
  bullets(s, [
    'من Dryer → مبادلات زيت/زيت ثم زيت/بخار',
    'Slurry tank: تراب تبييض ≈ 5 كجم/طن',
    'Bleacher: contact time + تقليب + فاكيوم',
    'Vertical leaf filters لنزع التراب',
    'يزيل: أصباغ · Soap · Moisture · Phosphorus',
    'Polishing filters ثم Deaerator',
    'دورة الفلتر: Oil in → Blow → Empty → Discharge',
  ], { x: M + 0.25, y: 1.3, w: 5.9, h: 5.1, size: 13 });
  safeImage(s, img('scada_bleaching.png'), { x: 7.1, y: 1.1, w: 5.8, h: 5.55 });
  addFooter(s, 12);
}

// ─── 13 إزالة ───
{
  const s = pptx.addSlide();
  s.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: W, h: H, fill: { color: C.sand } });
  slideTitle(s, 'مرحلة إزالة الروائح (Deodorization)');
  card(s, { x: M, y: 1.1, w: 6.4, h: 5.55 });
  bullets(s, [
    'Deaerator → polishing → هيتر',
    'Economizer ثم Super heater',
    'Deodorizer يزيل: FFA · Pigments · Oxidation · Volatiles',
    'تبريد: Economizer → زيت/زيت → زيت/ماء',
    'Polishing filters → تنك Refined',
    'Scrubber cycle مرتبط بالفاكيوم',
    'حرارة عالية + فاكيوم عميق + بخار شريطي',
  ], { x: M + 0.25, y: 1.3, w: 5.9, h: 5.1, size: 13 });
  safeImage(s, img('scada_deodorization.png'), { x: 7.1, y: 1.1, w: 5.8, h: 5.55 });
  addFooter(s, 13);
}

// ─── 14 جودة ───
{
  const s = pptx.addSlide();
  s.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: W, h: H, fill: { color: C.sand } });
  slideTitle(s, 'الجودة عبر المراحل');
  s.addTable(
    [
      [head('المرحلة'), head('المدخل'), head('الهدف / المخرج')],
      [cell('خام (وسيط 102)'), cell('FFA≈0.4 · Moisture 0.1 · PL 0.2'), cell('خام معلوم المواصفات')],
      [cell('بعد المعادلة'), cell('خام + كيماويات + فصل'), cell('FFA < 0.1 · Soap < 100 ppm')],
      [cell('بعد التبييض'), cell('زيت معادل + clay'), cell('لون أفضل · فوسفور أقل · منزوع هواء')],
      [cell('بعد الإزالة'), cell('زيت مبيّض'), cell('طعم ورائحة محايدة · جاهز للتعبئة')],
    ],
    {
      x: M, y: 1.2, w: W - M * 2, h: 3.6,
      colW: [3.2, 4.5, 4.8],
      border: [{ pt: 0.5, color: C.line }],
      fontFace: 'Segoe UI',
      rtlMode: true,
    },
  );
  card(s, { x: M, y: 5.05, w: W - M * 2, h: 1.55 });
  bullets(s, [
    'مخرجات جانبية للمتابعة: Soapstock · Spent bleaching earth · Fatty acids / distillate',
  ], { x: M + 0.25, y: 5.25, w: W - M * 2 - 0.5, h: 1.1, size: 14 });
  addFooter(s, 14);
}

// ─── 15 نصائح ───
{
  const s = pptx.addSlide();
  s.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: W, h: H, fill: { color: C.sand } });
  slideTitle(s, 'نقاط حرجة للحفاظ على 200 طن/يوم');
  const tips = [
    ['معادلة', ['جرعة صودا زائدة → emulsion', 'حرارة أقل من ≈65°م → فصل ضعيف', 'S2 غير مستقر → صابون مرتفع']],
    ['تبييض', ['فاكيوم ضعيف → أكسدة ولون مرتد', 'زيادة clay بلا داعٍ → فاقد أعلى', 'سوء تفريغ الفلتر → انخفاض المعدل']],
    ['إزالة', ['فاكيوم أسوأ من 6 mbar → رائحة', 'نقص بخار شريطي → إزالة ناقصة', 'تبريد ضعيف → استهلاك طاقة أعلى']],
  ];
  tips.forEach((t, i) => {
    const x = M + i * 4.2;
    card(s, { x, y: 1.2, w: 4.0, h: 3.8 });
    s.addText(t[0], {
      x: x + 0.2, y: 1.4, w: 3.6, h: 0.45,
      fontSize: 18, bold: true, color: C.green, fontFace: 'Segoe UI', rtlMode: true, align: 'right',
    });
    bullets(s, t[1], { x: x + 0.2, y: 2.0, w: 3.6, h: 2.7, size: 13 });
  });
  card(s, { x: M, y: 5.2, w: W - M * 2, h: 1.4, fill: C.navy, border: C.navy });
  s.addText('قاعدة ذهبية: لا تشغيل قبل كيماويات جاهزة + separators مغسولة + خطوط مفتوحة + فاكيوم شغال.', {
    x: M + 0.3, y: 5.5, w: W - M * 2 - 0.6, h: 0.8,
    fontSize: 15, bold: true, color: C.white, fontFace: 'Segoe UI', rtlMode: true, align: 'right',
  });
  addFooter(s, 15);
}

// ─── 16 خاتمة ───
{
  const s = pptx.addSlide();
  s.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: W, h: H, fill: { color: C.navy } });
  s.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: 0.28, h: H, fill: { color: C.oil } });
  s.addText('خلاصة', {
    x: M + 0.2, y: 1.3, w: W - M * 2, h: 0.4,
    fontSize: 14, color: 'F0D09A', fontFace: 'Segoe UI', rtlMode: true, align: 'right',
  });
  s.addText('من الخام إلى المكرر… بخط واحد متماسك', {
    x: M + 0.2, y: 1.8, w: W - M * 2, h: 0.7,
    fontSize: 28, bold: true, color: C.white, fontFace: 'Segoe UI', rtlMode: true, align: 'right',
  });
  const end = [
    ['200 طن/يوم', 'طاقة تتطلب توازن التخزين والفصل والفلاتر والفاكيوم'],
    ['لماذا التكرير؟', 'إزالة FFA والصموغ والأصباغ والروائح'],
    ['ثلاث مراحل', 'معادلة → تبييض → إزالة روائح'],
  ];
  end.forEach((e, i) => {
    const x = M + 0.2 + i * 4.15;
    s.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
      x, y: 2.9, w: 3.95, h: 2.2,
      fill: { color: '1F4A3A' },
      rectRadius: 0.1,
    });
    s.addText(e[0], {
      x: x + 0.2, y: 3.15, w: 3.55, h: 0.45,
      fontSize: 16, bold: true, color: 'FFDFA0', fontFace: 'Segoe UI', rtlMode: true, align: 'right',
    });
    s.addText(e[1], {
      x: x + 0.2, y: 3.7, w: 3.55, h: 1.1,
      fontSize: 13, color: C.white, fontFace: 'Segoe UI', rtlMode: true, align: 'right',
    });
  });
  s.addText('إعداد: أحمد سلاوي  ·  UCCMA Soybean Oil Refining', {
    x: M + 0.2, y: 5.6, w: W - M * 2, h: 0.4,
    fontSize: 16, bold: true, color: 'FFDFA0', fontFace: 'Segoe UI', rtlMode: true, align: 'right',
  });
}

await pptx.writeFile({ fileName: out });
console.log('Wrote', out);
