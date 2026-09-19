import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const catalogPath = path.join(
  __dirname,
  '../lib/features/store/import/egypt_store_suppliers_catalog.dart',
);
const csvPath = path.join(
  __dirname,
  '../docs/AcadeGate_Suppliers_Contact_Directory.csv',
);
const htmlPath = path.join(
  __dirname,
  '../docs/AcadeGate_Suppliers_Contact_Directory_AR.html',
);

const text = fs.readFileSync(catalogPath, 'utf8');
const blocks = [...text.matchAll(/EgyptStoreSupplier\(\s*([\s\S]*?)\n  \),?/g)];

function field(block, name) {
  const m = block.match(new RegExp(`${name}:\\s*'([^']*)'`));
  return m ? m[1] : '';
}

function list(block, name) {
  const m = block.match(new RegExp(`${name}:\\s*\\[([^\\]]*)\\]`));
  if (!m) return [];
  return [...m[1].matchAll(/'([^']*)'/g)].map((x) => x[1]);
}

function csvEsc(v) {
  const s = v ?? '';
  if (/[",\n\r]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
  return s;
}

function htmlEsc(v) {
  return String(v ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

const suppliers = blocks.map((m, i) => {
  const b = m[1];
  return {
    n: i + 1,
    id: field(b, 'id'),
    nameAr: field(b, 'nameAr'),
    nameEn: field(b, 'nameEn'),
    phone: field(b, 'phone'),
    whatsapp: field(b, 'whatsapp'),
    email: field(b, 'email'),
    website: field(b, 'website'),
    city: field(b, 'city'),
    address: field(b, 'address'),
    focus: list(b, 'focusAreas').join(' | '),
    cats: list(b, 'categoryIds').join(' | '),
  };
});

const csv = [
  '#,id,الاسم_العربي,الاسم_الإنجليزي,الهاتف,واتساب,البريد,الموقع,المدينة,العنوان,التخصصات,أقسام_المتجر',
  ...suppliers.map(
    (s) =>
      [
        s.n,
        s.id,
        s.nameAr,
        s.nameEn,
        s.phone,
        s.whatsapp,
        s.email,
        s.website,
        s.city,
        s.address,
        s.focus,
        s.cats,
      ]
        .map(csvEsc)
        .join(','),
  ),
].join('\n');

fs.writeFileSync(csvPath, '\uFEFF' + csv + '\n', 'utf8');

const rows = suppliers
  .map((s) => {
    const phone = s.phone
      ? `<a href="tel:${encodeURIComponent(s.phone)}">${htmlEsc(s.phone)}</a>`
      : '<span class="empty">—</span>';
    const waDigits = s.whatsapp.replace(/\D/g, '');
    const wa = s.whatsapp
      ? `<a href="https://wa.me/${waDigits}">${htmlEsc(s.whatsapp)}</a>`
      : '<span class="empty">—</span>';
    const email = s.email
      ? `<a href="mailto:${htmlEsc(s.email)}">${htmlEsc(s.email)}</a>`
      : '<span class="empty">—</span>';
    const host = s.website
      .replace(/^https?:\/\/(www\.)?/, '')
      .replace(/\/$/, '');
    const web = s.website
      ? `<a href="${htmlEsc(s.website)}" target="_blank" rel="noopener">${htmlEsc(host)}</a>`
      : '<span class="empty">—</span>';
    const city = s.city ? htmlEsc(s.city) : '<span class="empty">—</span>';
    return `      <tr><td>${s.n}</td><td>${htmlEsc(s.nameAr)}</td><td>${phone}</td><td>${wa}</td><td>${email}</td><td>${web}</td><td>${city}</td></tr>`;
  })
  .join('\n');

const html = `<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>دليل اتصال موردي AcadeGate — مصر</title>
  <style>
    body { font-family: "Segoe UI", Tahoma, Arial, sans-serif; margin: 24px; color: #1a1a2e; }
    h1 { color: #1a237e; }
    .meta { color: #546e7a; margin-bottom: 16px; }
    table { width: 100%; border-collapse: collapse; font-size: 13px; }
    th { background: #1a237e; color: #fff; padding: 10px 8px; text-align: right; }
    td { border: 1px solid #cfd8dc; padding: 8px; vertical-align: top; }
    tr:nth-child(even) td { background: #f5f7fa; }
    a { color: #e65100; }
    .empty { color: #90a4ae; }
  </style>
</head>
<body>
  <h1>دليل اتصال موردي المتجر — AcadeGate</h1>
  <p class="meta">${suppliers.length} مورداً · مُولَّد من egypt_store_suppliers_catalog.dart · كل قسم ≥ 5 موردين</p>
  <table>
    <thead>
      <tr>
        <th>#</th><th>الاسم</th><th>الهاتف</th><th>واتساب</th><th>البريد</th><th>الموقع</th><th>المدينة</th>
      </tr>
    </thead>
    <tbody>
${rows}
    </tbody>
  </table>
</body>
</html>
`;

fs.writeFileSync(htmlPath, html, 'utf8');
console.log(`Wrote ${suppliers.length} suppliers to CSV + HTML`);
