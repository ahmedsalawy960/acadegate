import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import HTMLtoDOCX from 'html-to-docx';
import puppeteer from 'puppeteer';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const htmlPath = path.join(__dirname, 'AcadeGate_Dossier_AR.html');
const pdfPath = path.join(__dirname, 'AcadeGate_Dossier_AR.pdf');
const docxPath = path.join(__dirname, 'AcadeGate_Dossier_AR.docx');

const html = fs.readFileSync(htmlPath, 'utf8');

async function generatePdf() {
  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
  });
  try {
    const page = await browser.newPage();
    await page.setContent(html, { waitUntil: 'networkidle0' });
    await page.pdf({
      path: pdfPath,
      format: 'A4',
      printBackground: true,
      margin: { top: '18mm', right: '14mm', bottom: '18mm', left: '14mm' },
    });
    console.log('PDF:', pdfPath);
  } finally {
    await browser.close();
  }
}

async function generateDocx() {
  const buffer = await HTMLtoDOCX(html, null, {
    table: { row: { cantSplit: true } },
    footer: true,
    pageNumber: true,
    lang: 'ar',
    orientation: 'portrait',
    margins: {
      top: 1440,
      right: 1080,
      bottom: 1440,
      left: 1080,
      header: 720,
      footer: 720,
      gutter: 0,
    },
  });
  fs.writeFileSync(docxPath, buffer);
  console.log('DOCX:', docxPath);
}

await generatePdf();
await generateDocx();
