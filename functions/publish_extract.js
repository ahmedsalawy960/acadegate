const { randomUUID } = require("crypto");
const { onRequest, HttpsError } = require("firebase-functions/v2/https");
const { getAuth } = require("firebase-admin/auth");
const { getStorage } = require("firebase-admin/storage");
const mammoth = require("mammoth");
const pdfParse = require("pdf-parse");
const { assertFirebaseStorageHttpsUrl } = require("./url_safety");

const MAX_IMPORT_IMAGES = 120;

const MAX_BODY_BLOCKS = 500;
const MAX_BODY_TEXT = 120000;
const MAX_REFERENCES = 200;
const MAX_BLOCK_TEXT = 80000;

async function downloadFileBuffer(fileUrl) {
  try {
    assertFirebaseStorageHttpsUrl(fileUrl);
  } catch (err) {
    throw new HttpsError(
      "invalid-argument",
      err?.message || "Unsafe or disallowed fileUrl",
    );
  }
  const res = await fetch(fileUrl);
  if (!res.ok) {
    throw new HttpsError(
      "invalid-argument",
      `Could not download file: HTTP ${res.status}`,
    );
  }
  return Buffer.from(await res.arrayBuffer());
}

function capBodyBlocks(blocks) {
  const limited = blocks.slice(0, MAX_BODY_BLOCKS).map((b) => {
    if (b.text && b.text.length > MAX_BLOCK_TEXT) {
      return { ...b, text: b.text.slice(0, MAX_BLOCK_TEXT) };
    }
    return b;
  });
  if (blocks.length <= MAX_BODY_BLOCKS) return limited;
  limited.push({
    id: `truncated_${Date.now()}`,
    type: "paragraph",
    text: `[${blocks.length - MAX_BODY_BLOCKS + 1} more sections omitted]`,
  });
  return limited;
}

function capReferences(refs) {
  return refs.slice(0, MAX_REFERENCES).map((r) => ({
    ...r,
    rawText: r.rawText ? r.rawText.slice(0, 450) : "",
    title: r.title ? r.title.slice(0, 300) : "",
  }));
}

function fileExtension(filename) {
  const parts = String(filename || "").trim().toLowerCase().split(".");
  return parts.length > 1 ? parts.pop() : "";
}

async function extractDocxStructured(buffer) {
  const images = [];
  const options = {
    convertImage: mammoth.images.imgElement((image) =>
      image.read("base64").then((imageBuffer) => {
        const index = images.length;
        if (index >= MAX_IMPORT_IMAGES) {
          return { src: `{{img:skipped}}` };
        }
        images.push({
          index,
          contentType: image.contentType || "image/png",
          base64: imageBuffer.toString("base64"),
        });
        return { src: `{{img:${index}}}` };
      }),
    ),
  };

  const [htmlResult, textResult] = await Promise.all([
    mammoth.convertToHtml({ buffer }, options),
    mammoth.extractRawText({ buffer }),
  ]);

  const html = String(htmlResult.value || "").trim();
  const text = String(textResult.value || "").trim();
  const bodyBlocks = htmlToBodyBlocks(html);

  return { html, text, images, bodyBlocks };
}

async function uploadExtractImages(images, uid, fileHint) {
  if (!images.length) return {};
  const bucket = getStorage().bucket();
  const urls = {};
  const safeHint = String(fileHint || "doc")
    .replace(/[^\w.\-]+/g, "_")
    .slice(0, 40);
  const batchId = Date.now();

  for (const img of images.slice(0, MAX_IMPORT_IMAGES)) {
    try {
      const ext = (img.contentType || "image/png").split("/").pop() || "png";
      const path = `publish/${uid}/import/${batchId}_${safeHint}/img_${img.index}.${ext}`;
      const token = randomUUID();
      const file = bucket.file(path);
      await file.save(Buffer.from(img.base64, "base64"), {
        metadata: {
          contentType: img.contentType || "image/png",
          metadata: { firebaseStorageDownloadTokens: token },
        },
      });
      const encoded = encodeURIComponent(path);
      urls[img.index] =
        `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encoded}?alt=media&token=${token}`;
    } catch (err) {
      console.warn("Image upload failed", img.index, err.message);
    }
  }
  return urls;
}

function resolveImagePlaceholders(bodyBlocks, imageUrls) {
  return bodyBlocks.map((block) => {
    if (block.type !== "image") return block;
    const url = block.imageUrl || "";
    const match = /^\{\{img:(\d+)\}\}$/.exec(url);
    if (!match) return block;
    const idx = match[1];
    if (imageUrls[idx]) {
      return { ...block, imageUrl: imageUrls[idx] };
    }
    return {
      id: block.id,
      type: "paragraph",
      text: "[Figure]",
    };
  });
}

async function extractTextOnly(buffer, filename) {
  const ext = fileExtension(filename);
  switch (ext) {
    case "txt":
      return buffer.toString("utf8").replace(/^\uFEFF/, "").trim();
    case "docx":
    case "doc": {
      const result = await mammoth.extractRawText({ buffer });
      return String(result.value || "").trim();
    }
    case "pdf": {
      const pdf = await pdfParse(buffer);
      return String(pdf.text || "").trim();
    }
    default:
      throw new HttpsError(
        "invalid-argument",
        `Unsupported file type: .${ext || "unknown"}`,
      );
  }
}

async function extractDocumentText(buffer, filename) {
  const ext = fileExtension(filename);
  switch (ext) {
    case "txt":
      return {
        text: buffer.toString("utf8").replace(/^\uFEFF/, "").trim(),
        html: "",
        images: [],
        bodyBlocks: [],
      };
    case "docx":
    case "doc":
      return extractDocxStructured(buffer);
    case "pdf": {
      const pdf = await pdfParse(buffer);
      const text = String(pdf.text || "").trim();
      return { text, html: "", images: [], bodyBlocks: textToBodyBlocks(text) };
    }
    default:
      throw new HttpsError(
        "invalid-argument",
        `Unsupported file type: .${ext || "unknown"}`,
      );
  }
}

function isBibliographyHeading(text) {
  const t = String(text || "").trim().toLowerCase();
  return (
    t === "references" ||
    t === "bibliography" ||
    t === "works cited" ||
    t.includes("المراجع") ||
    t.includes("قائمة المراجع")
  );
}

function normalizeTableRows(rows) {
  if (!rows.length) return rows;
  const maxCols = Math.max(...rows.map((r) => r.length));
  return rows.map((row) => {
    const padded = [...row];
    while (padded.length < maxCols) padded.push("");
    return padded;
  });
}

function isTableCaption(text) {
  const t = String(text || "").trim();
  return /^Table\s+\d+/i.test(t) || /^جدول\s*\d+/.test(t);
}

function mergeConsecutiveParagraphs(blocks) {
  const out = [];
  const buffer = [];
  let idCounter = 0;
  const nextId = () => `merged_${Date.now()}_${idCounter++}`;

  const flush = () => {
    if (!buffer.length) return;
    const merged = buffer.join("\n\n").trim();
    if (merged) out.push({ id: nextId(), type: "paragraph", text: merged });
    buffer.length = 0;
  };

  for (const block of blocks) {
    if (block.type === "paragraph") {
      const t = String(block.text || "").trim();
      if (t) buffer.push(t);
    } else {
      flush();
      out.push(block);
    }
  }
  flush();
  return out;
}

function attachTableCaptions(blocks) {
  const out = [];
  for (let i = 0; i < blocks.length; i++) {
    const block = blocks[i];
    const next = blocks[i + 1];
    if (
      block.type === "paragraph" &&
      next?.type === "table" &&
      isTableCaption(block.text)
    ) {
      out.push({
        ...next,
        caption: String(block.text || "").trim(),
        rowCells: normalizeTableRows(
          (next.rowCells || []).map((r) => r.cells || []),
        ).map((cells) => ({ cells })),
      });
      i++;
      continue;
    }
    if (block.type === "table") {
      const rows = (block.rowCells || []).map((r) => r.cells || []);
      out.push({
        ...block,
        rowCells: normalizeTableRows(rows).map((cells) => ({ cells })),
      });
    } else {
      out.push(block);
    }
  }
  return out;
}

function structureBodyBlocks(blocks) {
  return attachTableCaptions(mergeConsecutiveParagraphs(blocks));
}

function isSectionHeading(line) {
  const t = String(line || "").trim();
  if (!t || t.length > 120) return false;
  if (
    /^(Abstract|Introduction|Background|Methods|Materials|Results|Discussion|Conclusion|References|Acknowledgment|الملخص|المقدمة|الخلفية|المنهج|المواد|النتائج|المناقشة|الخاتمة|المراجع)/i.test(
      t,
    )
  ) {
    return true;
  }
  if (/^\d+\.?\s+[A-Za-z\u0600-\u06FF]/.test(t) && t.length < 100) return true;
  if (t.length < 80 && t === t.toUpperCase() && /[A-Z\u0600-\u06FF]/.test(t)) {
    return true;
  }
  return false;
}

function htmlToBodyBlocks(html) {
  if (!html) return [];
  const blocks = [];
  let idCounter = 0;
  const nextId = () => `srv_${Date.now()}_${idCounter++}`;

  const tagRegex = /<(h[1-6]|p|table|img)[^>]*>[\s\S]*?<\/\1>|<img[^>]*\/?>/gi;
  let match;
  while ((match = tagRegex.exec(html)) !== null) {
    const chunk = match[0];
    const tagMatch = chunk.match(/^<(h[1-6]|p|table|img)/i);
    if (!tagMatch) continue;
    const tag = tagMatch[1].toLowerCase();

    if (tag.startsWith("h")) {
      const text = stripTags(chunk).trim();
      if (!text || isBibliographyHeading(text)) break;
      blocks.push({ id: nextId(), type: "heading", text });
    } else if (tag === "p") {
      const text = stripTags(chunk).trim();
      if (!text) continue;
      if (isBibliographyHeading(text)) break;
      blocks.push({ id: nextId(), type: "paragraph", text });
    } else if (tag === "table") {
      const parsed = parseHtmlTable(chunk);
      if (parsed.rows.length > 0) {
        blocks.push({
          id: nextId(),
          type: "table",
          rowCells: parsed.rows.map((cells) => ({ cells })),
          colSpans: parsed.colSpans.map((cells) => ({ cells })),
          rowSpans: parsed.rowSpans.map((cells) => ({ cells })),
        });
      }
    } else if (tag === "img") {
      const srcMatch = chunk.match(/src="([^"]+)"/i);
      const altMatch = chunk.match(/alt="([^"]*)"/i);
      const src = srcMatch ? srcMatch[1] : "";
      if (src) {
        blocks.push({
          id: nextId(),
          type: "image",
          imageUrl: src,
          caption: altMatch ? altMatch[1] : "",
        });
      }
    }
  }

  return attachTableCaptions(blocks);
}

function parseHtmlTable(tableHtml) {
  const rawRows = [];
  const rowRegex = /<tr[^>]*>([\s\S]*?)<\/tr>/gi;
  let rowMatch;
  while ((rowMatch = rowRegex.exec(tableHtml)) !== null) {
    const cells = [];
    const cellRegex = /<(td|th)([^>]*)>([\s\S]*?)<\/\1>/gi;
    let cellMatch;
    while ((cellMatch = cellRegex.exec(rowMatch[1])) !== null) {
      const attrs = cellMatch[2] || "";
      const colspan = parseInt((attrs.match(/colspan="(\d+)"/i) || [])[1] || "1", 10);
      const rowspan = parseInt((attrs.match(/rowspan="(\d+)"/i) || [])[1] || "1", 10);
      cells.push({
        text: stripTags(cellMatch[3]).trim(),
        colspan: Math.max(1, colspan || 1),
        rowspan: Math.max(1, rowspan || 1),
      });
    }
    if (cells.length > 0) rawRows.push(cells);
  }

  const grid = [];
  const colSpans = [];
  const rowSpans = [];

  function ensure(r, c) {
    while (grid.length <= r) {
      grid.push([]);
      colSpans.push([]);
      rowSpans.push([]);
    }
    while (grid[r].length <= c) {
      grid[r].push("");
      colSpans[r].push(1);
      rowSpans[r].push(1);
    }
  }

  function covered(r, c) {
    if (r >= colSpans.length || c >= colSpans[r].length) return false;
    if (colSpans[r][c] === 0) return true;
    return colSpans[r][c] > 0 && rowSpans[r][c] === 0;
  }

  for (let r = 0; r < rawRows.length; r++) {
    let col = 0;
    for (const cell of rawRows[r]) {
      while (covered(r, col)) col++;
      const cs = cell.colspan;
      const rs = cell.rowspan;
      for (let dr = 0; dr < rs; dr++) {
        for (let dc = 0; dc < cs; dc++) {
          ensure(r + dr, col + dc);
          if (dr === 0 && dc === 0) {
            grid[r][col] = cell.text;
            colSpans[r][col] = cs;
            rowSpans[r][col] = rs;
          } else if (dr === 0) {
            colSpans[r][col + dc] = 0;
            rowSpans[r][col + dc] = 0;
          } else if (dc === 0) {
            colSpans[r + dr][col] = cs;
            rowSpans[r + dr][col] = 0;
          } else {
            colSpans[r + dr][col + dc] = 0;
            rowSpans[r + dr][col + dc] = 0;
          }
        }
      }
      col += cs;
    }
  }

  let maxCols = 0;
  for (const row of grid) maxCols = Math.max(maxCols, row.length);
  for (let r = 0; r < grid.length; r++) {
    while (grid[r].length < maxCols) {
      grid[r].push("");
      colSpans[r].push(1);
      rowSpans[r].push(1);
    }
  }

  return { rows: grid, colSpans, rowSpans };
}

function toSubUnicode(text) {
  const map = {
    "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄",
    "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
    "+": "₊", "-": "₋", "=": "₌", "(": "₍", ")": "₎",
  };
  return String(text).split("").map((c) => map[c] || c).join("");
}

function toSupUnicode(text) {
  const map = {
    "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
    "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹",
    "+": "⁺", "-": "⁻",
  };
  return String(text).split("").map((c) => map[c] || c).join("");
}

function stripTags(html) {
  return String(html)
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<sub[^>]*>([\s\S]*?)<\/sub>/gi, (_, t) => toSubUnicode(t.replace(/<[^>]+>/g, "")))
    .replace(/<sup[^>]*>([\s\S]*?)<\/sup>/gi, (_, t) => toSupUnicode(t.replace(/<[^>]+>/g, "")))
    .replace(/<[^>]+>/g, "")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"');
}

function textToBodyBlocks(text) {
  const idx = bibliographyStartIndex(text);
  const mainText = idx != null ? text.slice(0, idx).trim() : text.trim();
  if (!mainText) return [];

  let idCounter = 0;
  const nextId = () => `txt_${Date.now()}_${idCounter++}`;
  const abstractMatch = /(?:^|\n)\s*Abstract\s*:?\s*/i.exec(mainText);
  if (!abstractMatch) {
    return [{ id: nextId(), type: "paragraph", text: mainText }];
  }

  const titleAuthors = mainText.slice(0, abstractMatch.index).trim();
  const abstractEnd = abstractZoneEnd(mainText, abstractMatch.index);
  const abstractKeywords = mainText.slice(abstractMatch.index, abstractEnd).trim();
  const bodyText = mainText.slice(abstractEnd).trim();

  const blocks = [];
  if (titleAuthors) blocks.push({ id: nextId(), type: "paragraph", text: titleAuthors });
  if (abstractKeywords) blocks.push({ id: nextId(), type: "paragraph", text: abstractKeywords });
  if (bodyText) blocks.push({ id: nextId(), type: "paragraph", text: bodyText });
  return blocks;
}

function abstractZoneEnd(text, abstractStart) {
  const afterAbstract = text.slice(abstractStart);
  const introMatch = /(?:^|\n)\s*(?:\d+\.?\s*)?(Introduction|Background|INTRODUCTION)\b/i.exec(
    afterAbstract,
  );
  if (introMatch) return abstractStart + introMatch.index;

  const kwMatch = /(?:^|\n)\s*Keywords?\s*:?/i.exec(afterAbstract);
  if (kwMatch) {
    const tail = afterAbstract.slice(kwMatch.index + kwMatch[0].length);
    const nextSection = /(?:^|\n)\s*(?:\d+\.?\s+\w|Introduction|INTRODUCTION|Background|Materials|Methods|Results|Discussion)/i.exec(
      tail,
    );
    if (nextSection) return abstractStart + kwMatch.index + kwMatch[0].length + nextSection.index;
    const paraEnd = /\n\s*\n/.exec(tail);
    if (paraEnd) return abstractStart + kwMatch.index + kwMatch[0].length + paraEnd.index + paraEnd[0].length;
    return abstractStart + kwMatch.index + kwMatch[0].length + tail.length;
  }

  const numberedStart = /(?:^|\n)\s*(?:1[\.\)]\s+\w|\d+\.?\s+(?:Materials|Methods|Results))/i.exec(
    afterAbstract,
  );
  if (numberedStart) return abstractStart + numberedStart.index;
  return abstractStart + afterAbstract.length;
}

function bibliographyStartIndex(text) {
  if (!text || !text.trim()) return null;
  const minPos = text.length > 4000 ? Math.floor(text.length * 0.42) : 0;
  let charPos = 0;
  const lines = text.split("\n");
  for (const rawLine of lines) {
    const line = rawLine.trim();
    const lineStart = charPos;
    charPos += rawLine.length + 1;
    if (lineStart < minPos) continue;
    if (isBibliographyHeadingLine(line)) return lineStart;
  }
  return null;
}

function isBibliographyHeadingLine(line) {
  const t = String(line || "").trim();
  if (!t || t.length > 70) return false;
  if (/[.!?]/.test(t) && t.split(/[.!?]/).length > 2) return false;
  return /^(References|Bibliography|Works Cited|Reference List|Literature Cited|REFERENCES)\s*\.?\s*$/i.test(
    t,
  ) || /^(المراجع|قائمة المراجع|المصادر)( والمصادر)?\s*\.?\s*$/.test(t);
}

function bibliographySection(text) {
  const idx = bibliographyStartIndex(text);
  if (idx == null) return "";
  let section = text.slice(idx);
  const nl = section.indexOf("\n");
  if (nl > 0 && nl < 80) section = section.slice(nl + 1);
  return section.trim();
}

function isRunningMatterLine(line) {
  const t = String(line || "").replace(/\s+/g, " ").trim();
  if (!t || t.length > 220) return false;
  if (/©|ISSN\s*:|Open Access|Cite this:|Creative Commons|All rights reserved/i.test(t)) {
    return true;
  }
  if (/\|\s*\d{1,3}\s*$/.test(t) && /\b(?:19|20)\d{2}\b/.test(t)) return true;
  return (
    t.length < 64 &&
    /^[A-Za-z]{2,14}\s+[A-Z]\.\s+\S+(?:\s+\S+)?\s+et\s+al\.?\s*$/i.test(t)
  );
}

function bibliographyLineContinues(current, line) {
  const t = String(line || "").trim();
  const cur = String(current || "").trim();
  if (!t || !cur || isRunningMatterLine(t)) return false;
  if (/^\((?:19|20)\d{2}[a-z]?\)/.test(t)) return true;
  if (/^(?:19|20)\d{2}[a-z]?\. /.test(t)) return true;
  if (/^https?:\/\/|^doi\b/i.test(t)) return true;
  if (/^[&,]/.test(t) || /^and\s+/i.test(t)) return true;
  if (/[,&]\s*$/.test(cur) || /\b(?:and|&)\s*$/i.test(cur)) return true;
  if (/^(?:[A-Z]\.\s*)+\(?\s*(?:19|20)\d{2}/.test(t)) return true;
  if (/^[a-z]/.test(t)) return true;
  if (!/\b(?:19|20)\d{2}\b/.test(cur) && looksLikeAuthorListFragment(cur)) {
    return true;
  }
  return false;
}

function looksLikeAuthorListFragment(raw) {
  const t = String(raw || "").trim();
  if (t.length < 8 || t.length > 400 || isRunningMatterLine(t)) return false;
  if (/\((?:19|20)\d{2}/.test(t) && /\.\s+\S/.test(t)) return false;
  return /[A-Z][\p{L}\p{M}'’.\-]*(?:\s+[\p{L}\p{M}'’.\-]+)*,\s*[A-Z]/u.test(t);
}

function looksLikeReference(block) {
  const t = String(block || "").trim();
  if (t.length < 20 || t.length > 2500) return false;
  if (isRunningMatterLine(t)) return false;
  if (/^\((?:19|20)\d{2}[a-z]?\)/.test(t) || /^[&,]/.test(t)) return false;
  if (
    /^(The|This|These|Those|It |We |Our |In |For |Using |According|However|Therefore|Moreover|Furthermore|Additionally|Thus|Hence|Figure|Table|Many |It is)/i.test(
      t,
    )
  ) {
    return false;
  }
  if (!/\(\d{4}[a-z]?\)|,\s*(19|20)\d{2}\b|\b(19|20)\d{2}\b/.test(t)) return false;
  if (/doi\.org|DOI:|vol\.|pp\.|Journal|Proceedings|\bet al\./i.test(t)) {
    return true;
  }
  return /[A-Z][\p{L}\p{M}'’.\-\s]{1,80},\s*[A-Z.]/u.test(t);
}

function parseReferences(fullText) {
  const section = bibliographySection(fullText);
  if (!section) {
    const tailStart = Math.floor(fullText.length * 0.78);
    const tail = fullText.slice(tailStart);
    const ieeePattern = /(?:^|\n)\[(\d+)\]\s*([\s\S]*?)(?=(?:^|\n)\[\d+\]|$)/g;
    const refs = [];
    let m;
    while ((m = ieeePattern.exec(tail)) !== null) {
      const block = (m[2] || "").trim();
      if (block.length >= 8 && looksLikeReference(block)) {
        refs.push(blockToReference(block, `ref_${m[1]}`));
      }
    }
    return refs.length >= 3 ? refs : [];
  }

  const ieeePattern = /(?:^|\n)\[(\d+)\]\s*([\s\S]*?)(?=(?:^|\n)\[\d+\]|$)/g;
  const ieee = [];
  let m;
  while ((m = ieeePattern.exec(section)) !== null) {
    const block = (m[2] || "").trim();
    if (block.length >= 8 && looksLikeReference(block)) {
      ieee.push(blockToReference(block, `ref_${m[1]}`));
    }
  }
  if (ieee.length >= 2) return ieee;

  const apa = parseApa(section).filter((r) =>
    looksLikeReference(r.rawText || r.title || ""),
  );
  if (apa.length > 0) return apa;

  const blocks = section
    .split(/\n\s*\n/)
    .map((b) => b.trim())
    .filter((b) => b.length > 25 && looksLikeReference(b));

  if (blocks.length > 0) {
    return blocks.slice(0, 80).map((b, i) => blockToReference(b, `ref_${i + 1}`));
  }
  return [];
}

function parseApa(section) {
  const lines = section.split("\n");
  const merged = [];
  let current = "";

  function looksLikeStart(line) {
    const t = line.trim();
    if (t.length < 8 || isRunningMatterLine(t)) return false;
    if (/^\[\d+\]/.test(t) || /^\d+[.)]\s/.test(t)) return true;
    if (/^\((?:19|20)\d{2}[a-z]?\)/.test(t)) return false;
    if (looksLikeAuthorListFragment(t)) return true;
    return /\(\d{4}[a-z]?\)/.test(t) || (/\b(19|20)\d{2}\b/.test(t) && t.length > 35);
  }

  function hasYear(text) {
    return /\b(?:19|20)\d{2}\b/.test(text);
  }

  for (const raw of lines) {
    const line = raw.trim();
    if (!line) {
      if (current && hasYear(current)) {
        merged.push(current.trim());
        current = "";
      }
      continue;
    }
    if (isRunningMatterLine(line)) continue;
    if (!current) {
      if (looksLikeStart(line) || looksLikeAuthorListFragment(line)) {
        current = line;
      }
      continue;
    }
    if (bibliographyLineContinues(current, line)) {
      current += " " + line;
      continue;
    }
    if (looksLikeStart(line) && hasYear(current)) {
      merged.push(current.trim());
      current = line;
      continue;
    }
    current += " " + line;
  }
  if (current) merged.push(current.trim());

  const refs = [];
  let i = 0;
  for (const block of merged) {
    if (block.length < 25) continue;
    if (/\(\d{4}[a-z]?\)/.test(block) || /\b(19|20)\d{2}\b/.test(block)) {
      refs.push(blockToReference(block, `ref_${++i}`));
    }
  }
  return refs.slice(0, 80);
}

function blockToReference(block, id) {
  const yearMatch = block.match(/\b(19|20)\d{2}\b/);
  const year = yearMatch ? yearMatch[0] : "";
  const doiMatch = block.match(/(?:doi[:\s]*|https?:\/\/doi\.org\/)([^\s,]+)/i);
  const doi = doiMatch ? doiMatch[1].replace(/[.)]$/, "") : "";

  let title = block;
  const quoted = block.match(/"([^"]+)"/);
  if (quoted) {
    title = quoted[1];
  } else {
    title = block.split(".")[0].trim();
  }

  const authorsPart = yearMatch
    ? block.slice(0, yearMatch.index).trim()
    : block.split(".")[0].trim();
  const authors = authorsPart
    .split(/,|\band\b/i)
    .map((a) => a.trim())
    .filter((a) => a.length > 0 && a.length < 80)
    .slice(0, 4);

  return {
    id,
    type: "journal",
    authors,
    title: title.length > 300 ? title.slice(0, 300) : title,
    year,
    doi,
    container: "",
    volume: "",
    issue: "",
    pages: "",
    url: "",
    publisher: "",
    conference: "",
    rawText: block.trim(),
  };
}

function createPublishExtractHandler() {
  return onRequest(
    {
      cors: true,
      timeoutSeconds: 120,
      memory: "1GiB",
    },
    async (req, res) => {
      if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
      }
      if (req.method !== "POST") {
        res.status(405).json({ error: { message: "POST only" } });
        return;
      }

      const authHeader = req.headers.authorization || "";
      const token = authHeader.startsWith("Bearer ")
        ? authHeader.slice(7)
        : null;
      if (!token) {
        res.status(401).json({
          error: { status: "UNAUTHENTICATED", message: "Missing auth token" },
        });
        return;
      }

      let uid;
      try {
        const decoded = await getAuth().verifyIdToken(token);
        uid = decoded.uid;
      } catch (_) {
        res.status(401).json({
          error: { status: "UNAUTHENTICATED", message: "Invalid auth token" },
        });
        return;
      }

      try {
        const body = req.body?.data || req.body || {};
        const base64 = body.base64;
        const fileUrl = body.fileUrl;
        const filename = body.filename;
        if (!filename) {
          throw new HttpsError("invalid-argument", "filename required");
        }
        if (!base64 && !fileUrl) {
          throw new HttpsError(
            "invalid-argument",
            "base64 or fileUrl required",
          );
        }

        const referencesOnly = body.referencesOnly === true;
        const buffer = fileUrl
          ? await downloadFileBuffer(fileUrl)
          : Buffer.from(base64, "base64");

        if (referencesOnly) {
          const text = await extractTextOnly(buffer, filename);
          if (!text || text.length < 40) {
            throw new HttpsError(
              "invalid-argument",
              "Could not extract enough text from file",
            );
          }
          const references = capReferences(parseReferences(text));
          const idx = bibliographyStartIndex(text);
          const bodyText = idx != null ? text.slice(0, idx).trim() : text;
          res.status(200).json({
            result: {
              fullText: text.slice(0, MAX_BODY_TEXT),
              bodyText: bodyText.slice(0, MAX_BODY_TEXT),
              references,
              referenceCount: references.length,
              bodyBlocks: [],
              referencesOnly: true,
            },
          });
          return;
        }

        const extracted = await extractDocumentText(buffer, filename);
        const text = extracted.text;
        if (!text || text.length < 40) {
          throw new HttpsError(
            "invalid-argument",
            "Could not extract enough text from file",
          );
        }

        const references = capReferences(parseReferences(text));
        const idx = bibliographyStartIndex(text);
        const bodyText = idx != null ? text.slice(0, idx).trim() : text;
        let bodyBlocks =
          extracted.bodyBlocks.length > 0
            ? extracted.bodyBlocks
            : textToBodyBlocks(bodyText);

        const imageUrls = await uploadExtractImages(
          extracted.images || [],
          uid,
          filename,
        );
        bodyBlocks = resolveImagePlaceholders(bodyBlocks, imageUrls);
        bodyBlocks = capBodyBlocks(attachTableCaptions(bodyBlocks));

        res.status(200).json({
          result: {
            fullText: text.slice(0, MAX_BODY_TEXT),
            bodyText: bodyText.slice(0, MAX_BODY_TEXT),
            references,
            referenceCount: references.length,
            bodyBlocks,
            imagesUploaded: Object.keys(imageUrls).length,
            imagesSkipped: Math.max(
              0,
              (extracted.images || []).length - Object.keys(imageUrls).length,
            ),
            blocksTruncated: bodyBlocks.length >= MAX_BODY_BLOCKS,
          },
        });
      } catch (err) {
        const message = err.message || "Extract failed";
        const status = err.code === "invalid-argument" ? 400 : 500;
        res.status(status).json({
          error: { status: "INTERNAL", message },
        });
      }
    },
  );
}

module.exports = { createPublishExtractHandler };
