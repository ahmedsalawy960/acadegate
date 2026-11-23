"use strict";

// Advisor-only validation. This is not antivirus or a guarantee of model support.
const { TextDecoder } = require("node:util");
const { crc32 } = require("node:zlib");
const { Worker, isMainThread, parentPort, workerData } = require("node:worker_threads");
const { SaxesParser } = require("saxes");
const yauzl = require("yauzl");
const MAX_BYTES = 10 * 1024 * 1024;
const MAX_EXPANDED = 32 * 1024 * 1024;
const MAX_ENTRIES = 2000;
const MIME = Object.freeze({
  png: "image/png", jpg: "image/jpeg", jpeg: "image/jpeg", webp: "image/webp",
  pdf: "application/pdf", doc: "application/msword", xls: "application/vnd.ms-excel",
  ppt: "application/vnd.ms-powerpoint",
  docx: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  xlsx: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  pptx: "application/vnd.openxmlformats-officedocument.presentationml.presentation",
  txt: "text/plain", md: "text/markdown", csv: "text/csv", tsv: "text/tab-separated-values",
});
const TEXT = new Set(["txt", "md", "csv", "tsv"]);
const OFFICE = {
  docx: ["word/document.xml", "document", "wordprocessingml", "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"],
  xlsx: ["xl/workbook.xml", "workbook", "spreadsheetml", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"],
  pptx: ["ppt/presentation.xml", "presentation", "presentationml", "application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"],
};
class AdvisorFileError extends Error {
  constructor(message = "الملف تالف أو مشفر أو غير مدعوم. احفظ نسخة جديدة غير مشفرة ثم أعد المحاولة.") {
    super(message); this.name = "AdvisorFileError";
  }
}
const fail = () => { throw new AdvisorFileError(); };
const starts = (buf, hex) => buf.subarray(0, hex.length / 2).equals(Buffer.from(hex, "hex"));

function decodeText(buf) {
  let encoding = "utf-8";
  let offset = 0;
  if (starts(buf, "fffe")) { encoding = "utf-16le"; offset = 2; }
  else if (starts(buf, "feff")) { encoding = "utf-16be"; offset = 2; }
  else if (starts(buf, "efbbbf")) offset = 3;
  if (encoding !== "utf-8" && (buf.length - offset) % 2 !== 0) fail();
  let text;
  try { text = new TextDecoder(encoding, { fatal: true }).decode(buf.subarray(offset)); }
  catch (_) { throw new AdvisorFileError("ترميز النص غير مدعوم. احفظ الملف بترميز UTF-8 أو UTF-16 مع BOM."); }
  // Tags are ordinary text here. Never render or execute them.
  if (/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/u.test(text)) fail();
  const out = Buffer.from(text, "utf8");
  if (out.length > MAX_BYTES) throw new AdvisorFileError("النص بعد تحويل الترميز يتجاوز 10 ميجابايت.");
  return out;
}

function parseXml(buf) {
  const text = decodeText(buf);
  let root;
  const overrides = [];
  const relationships = [];
  const parser = new SaxesParser({ xmlns: true });
  parser.on("error", fail);
  parser.on("doctype", fail); // No DTD or entity expansion, local or remote.
  let depth = 0;
  parser.on("opentag", (tag) => {
    depth += 1;
    if (!root) root = { local: tag.local, uri: tag.uri };
    const attr = (key) => Object.values(tag.attributes).find((a) => a.local === key && !a.uri)?.value;
    if (depth === 2 && tag.local === "Override" && tag.uri === "http://schemas.openxmlformats.org/package/2006/content-types") overrides.push([attr("PartName"), attr("ContentType")]);
    if (depth === 2 && tag.local === "Relationship" && tag.uri === "http://schemas.openxmlformats.org/package/2006/relationships") relationships.push({ target: attr("Target"), type: attr("Type"), mode: attr("TargetMode") });
  });
  parser.on("closetag", () => { depth -= 1; });
  try { parser.write(text.toString("utf8")).close(); } catch (_) { fail(); }
  if (!root) fail();
  return { root, overrides, relationships };
}

function validateOpenXml(ext, buf) {
  return new Promise((resolve, reject) => {
    let zip;
    let settled = false;
    let count = 0;
    let expanded = 0;
    let declared = 0;
    const seen = new Set();
    const xmlParts = new Map();
    const finish = (error) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      if (zip) zip.close();
      if (error) reject(error instanceof AdvisorFileError ? error : new AdvisorFileError());
      else resolve();
    };
    const timer = setTimeout(() => finish(new AdvisorFileError()), 10000);
    yauzl.fromBuffer(buf, { lazyEntries: true, validateEntrySizes: true, strictFileNames: true }, (err, opened) => {
      if (settled) { if (opened) opened.close(); return; }
      if (err) return finish(err);
      zip = opened;
      zip.on("error", finish);
      zip.on("entry", (entry) => {
        if (settled) return;
        const name = entry.fileName;
        const key = name.toLowerCase();
        if (++count > MAX_ENTRIES || seen.has(key) || name.startsWith("/") || name.includes("\\") || name.split("/").includes("..") || name.includes("\u0000") || (entry.generalPurposeBitFlag & 1) || /encryptedpackage|encryptioninfo|vbaproject\.bin/i.test(name)) return finish(new AdvisorFileError());
        seen.add(key);
        declared += entry.uncompressedSize;
        if (!Number.isSafeInteger(entry.uncompressedSize) || declared > MAX_EXPANDED || (entry.compressionMethod !== 0 && entry.compressionMethod !== 8)) return finish(new AdvisorFileError());
        if (name.endsWith("/")) { zip.readEntry(); return; }
        zip.openReadStream(entry, (streamError, stream) => {
          if (settled) { if (stream) stream.destroy(); return; }
          if (streamError) return finish(streamError);
          const chunks = [];
          const isXml = /\.(xml|rels)$/i.test(name);
          let size = 0;
          let crc = 0;
          stream.on("error", finish);
          stream.on("data", (chunk) => {
            size += chunk.length; expanded += chunk.length;
            if (expanded > MAX_EXPANDED || size > entry.uncompressedSize) {
              stream.destroy(); finish(new AdvisorFileError()); return;
            }
            crc = crc32(chunk, crc);
            if (isXml) chunks.push(chunk);
          });
          stream.on("end", () => {
            if (settled) return;
            if (size !== entry.uncompressedSize || crc !== entry.crc32) return finish(new AdvisorFileError());
            try { if (isXml) xmlParts.set(name, parseXml(Buffer.concat(chunks))); }
            catch (error) { return finish(error); }
            zip.readEntry();
          });
        });
      });
      zip.on("end", () => {
        try {
          const [part, root, ns, contentType] = OFFICE[ext];
          const main = xmlParts.get(part);
          const types = xmlParts.get("[Content_Types].xml");
          const rels = xmlParts.get("_rels/.rels");
          const transitional = `http://schemas.openxmlformats.org/${ns}/2006/main`;
          const strict = `http://purl.oclc.org/ooxml/${ns}/main`;
          if (!main || main.root.local !== root || ![transitional, strict].includes(main.root.uri)) fail();
          if (!types || types.root.local !== "Types" || types.root.uri !== "http://schemas.openxmlformats.org/package/2006/content-types" || !types.overrides.some(([p, t]) => p === `/${part}` && t === contentType)) fail();
          if (!rels || rels.root.local !== "Relationships" || rels.root.uri !== "http://schemas.openxmlformats.org/package/2006/relationships" || !rels.relationships.some((r) => r.mode !== "External" && [part, `/${part}`].includes(r.target) && ["http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument", "http://purl.oclc.org/ooxml/officeDocument/relationships/officeDocument"].includes(r.type))) fail();
          finish();
        } catch (error) { finish(error); }
      });
      zip.readEntry();
    });
  });
}

// Legacy Office parsing is isolated: malformed sector chains cannot stall the
// request's main thread. No macros, external links or embedded programs run.
function parseOle(ext, buf) {
  const CFB = require("cfb");
  if (!starts(buf, "d0cf11e0a1b11ae1") || buf.length < 512 || buf.readUInt16LE(28) !== 0xfffe) fail();
  const major = buf.readUInt16LE(26);
  const shift = buf.readUInt16LE(30);
  if (!((major === 3 && shift === 9) || (major === 4 && shift === 12)) || buf.readUInt16LE(32) !== 6) fail();
  const sectorSize = 2 ** shift;
  if (buf.length % sectorSize || buf.length < sectorSize * 2) fail();
  const sectors = buf.length / sectorSize - 1;
  for (const off of [44, 64, 72]) if (buf.readUInt32LE(off) > sectors) fail();
  let file;
  try { file = CFB.read(buf, { type: "buffer" }); } catch (_) { fail(); }
  if (!file.FileIndex || file.FileIndex[0]?.type !== 5 || file.FileIndex.length > 10000) fail();
  let total = 0;
  for (const entry of file.FileIndex) {
    if (/^(EncryptionInfo|EncryptedPackage)$/i.test(entry.name)) fail();
    if (entry.type !== 2) continue;
    if (!Number.isSafeInteger(entry.size) || entry.size < 0 || entry.size > MAX_EXPANDED || (entry.size > 0 && (!entry.content || entry.content.length !== entry.size))) fail();
    total += entry.size;
    if (total > MAX_EXPANDED) fail();
  }
  const get = (name) => {
    const index = file.FullPaths.findIndex((path) => path === `${file.FullPaths[0]}${name}`);
    const entry = file.FileIndex[index];
    return entry?.type === 2 ? Buffer.from(entry.content || []) : null;
  };
  if (ext === "doc") {
    const word = get("WordDocument");
    if (!word || word.length < 154 || word.readUInt16LE(0) !== 0xa5ec || word.readUInt16LE(2) < 0x00c1) fail();
    const fcMin = word.readUInt32LE(24), fcMac = word.readUInt32LE(28);
    if (fcMin > fcMac || fcMac > word.length) fail();
    let fib = 34 + word.readUInt16LE(32) * 2;
    if (fib + 2 > word.length) fail();
    fib += 2 + word.readUInt16LE(fib) * 4;
    if (fib + 2 > word.length) fail();
    const pairCount = word.readUInt16LE(fib);
    if (pairCount < 93 || fib + 2 + pairCount * 8 > word.length) fail();
    const flags = word.readUInt16LE(10);
    if (flags & 0x8100) fail(); // encrypted or obfuscated
    if (!get(flags & 0x0200 ? "1Table" : "0Table")) fail();
  } else if (ext === "xls") {
    const sheet = get("Workbook") || get("Book");
    if (!sheet || sheet.length < 12 || ![0x0209, 0x0409, 0x0809].includes(sheet.readUInt16LE(0)) || sheet.readUInt16LE(2) < 4 || ![0x0005, 0x0010].includes(sheet.readUInt16LE(6))) fail();
    let pos = 0;
    let eof = false;
    while (pos < sheet.length) {
      if (pos + 4 > sheet.length) fail();
      const id = sheet.readUInt16LE(pos);
      const length = sheet.readUInt16LE(pos + 2);
      if (id === 0x002f || pos + 4 + length > sheet.length) fail(); // FILEPASS
      if (id === 0x000a) { if (length !== 0) fail(); eof = true; }
      pos += 4 + length;
    }
    if (!eof) fail();
  } else {
    const presentation = get("PowerPoint Document");
    const current = get("Current User");
    if (!presentation || presentation.length < 8 || !current || current.length < 20 || current.readUInt16LE(2) !== 0x0ff6 || current.readUInt32LE(12) !== 0xe391c05f) fail();
    const editOffset = current.readUInt32LE(16);
    if (editOffset + 8 > presentation.length || presentation.readUInt16LE(editOffset + 2) !== 0x0ff5 || presentation.readUInt32LE(editOffset + 4) < 28) fail();
    let pos = 0;
    let documentFound = false;
    while (pos < presentation.length) {
      if (pos + 8 > presentation.length) fail();
      const length = presentation.readUInt32LE(pos + 4);
      if (presentation.readUInt16LE(pos + 2) === 1000 && (presentation.readUInt16LE(pos) & 15) === 15) documentFound = true;
      if (pos + 8 + length > presentation.length) fail();
      pos += 8 + length;
    }
    if (!documentFound) fail();
  }
}
function validateOle(ext, buf) {
  return new Promise((resolve, reject) => {
    const worker = new Worker(__filename, { workerData: { advisorOle: true, ext, bytes: buf }, resourceLimits: { maxOldGenerationSizeMb: 64, stackSizeMb: 4 } });
    let settled = false;
    const finish = (ok) => {
      if (settled) return;
      settled = true; clearTimeout(timer); void worker.terminate();
      if (ok) resolve(); else reject(new AdvisorFileError());
    };
    const timer = setTimeout(() => finish(false), 5000);
    worker.once("message", (msg) => finish(msg === true));
    worker.once("error", () => finish(false));
    worker.once("exit", () => finish(false));
  });
}

async function validateAdvisorFile(ext, buf) {
  if (!MIME[ext] || !Buffer.isBuffer(buf) || !buf.length || buf.length > MAX_BYTES) throw new AdvisorFileError("نوع الملف غير مدعوم أو حجمه يتجاوز 10 ميجابايت.");
  if (TEXT.has(ext)) {
    if (["504b0304", "7f454c46", "d0cf11e0a1b11ae1"].some((sig) => starts(buf, sig))) fail();
    // Pass decoded content as a text part, not unsupported binary text MIME.
    return { text: decodeText(buf).toString("utf8") };
  }
  if (OFFICE[ext]) await validateOpenXml(ext, buf);
  else if (["doc", "xls", "ppt"].includes(ext)) await validateOle(ext, buf);
  else if (ext === "pdf" && !starts(buf, "255044462d")) fail();
  else if (ext === "png" && !starts(buf, "89504e470d0a1a0a")) fail();
  else if (["jpg", "jpeg"].includes(ext) && !starts(buf, "ffd8ff")) fail();
  else if (ext === "webp" && (buf.length < 12 || buf.toString("ascii", 0, 4) !== "RIFF" || buf.toString("ascii", 8, 12) !== "WEBP")) fail();
  return { inlineData: { mimeType: MIME[ext], data: buf.toString("base64") } };
}
if (!isMainThread && workerData?.advisorOle) {
  try { parseOle(workerData.ext, Buffer.from(workerData.bytes)); parentPort.postMessage(true); }
  catch (_) { parentPort.postMessage(false); }
}
module.exports = { validateAdvisorFile, AdvisorFileError };
