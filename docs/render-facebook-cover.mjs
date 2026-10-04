import puppeteer from 'puppeteer';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const htmlPath = path.join(__dirname, 'acadegate-facebook-cover.html');
const outPath = path.join(__dirname, '..', 'Assets', 'images', 'acadegate_facebook_cover.png');

const browser = await puppeteer.launch({
  executablePath: 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  headless: true,
  args: ['--no-sandbox'],
});
const page = await browser.newPage();
await page.setViewport({ width: 1640, height: 624, deviceScaleFactor: 2 });
await page.goto('file:///' + htmlPath.replace(/\\/g, '/'), { waitUntil: 'networkidle0' });
await page.screenshot({ path: outPath, type: 'png' });
await browser.close();
console.log(outPath);
