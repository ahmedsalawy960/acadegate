import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import HTMLtoDOCX from 'html-to-docx';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const htmlPath = path.join(__dirname, 'AcadeGate_Pitch_Suppliers_AR.html');
const docxPath = path.join(__dirname, 'AcadeGate_Pitch_Suppliers_AR.docx');

const html = fs.readFileSync(htmlPath, 'utf8');

const buffer = await HTMLtoDOCX(html, null, {
  table: { row: { cantSplit: true } },
  footer: true,
  pageNumber: true,
  lang: 'ar',
  orientation: 'portrait',
  margins: {
    top: 1080,
    right: 1008,
    bottom: 1080,
    left: 1008,
    header: 720,
    footer: 720,
    gutter: 0,
  },
});

fs.writeFileSync(docxPath, buffer);
console.log('DOCX:', docxPath);
