"use strict";

const fs = require("fs");
const path = require("path");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const CSL = require("citeproc");

const STYLES_DIR = path.join(__dirname, "csl_styles");
const LOCALES_DIR = path.join(__dirname, "csl_locales");

const SUPPORTED_STYLES = new Set([
  "american-medical-association",
  "american-sociological-association",
  "apa",
  "chicago-author-date",
  "chicago-notes-bibliography",
  "elsevier-harvard",
  "elsevier-vancouver",
  "harvard-cite-them-right",
  "ieee",
  "modern-language-association",
  "nature",
  "springer-basic-author-date",
]);

const SUPPORTED_LOCALES = new Map([
  ["en", "locales-en-US.xml"],
  ["en-US", "locales-en-US.xml"],
  ["ar", "locales-ar.xml"],
]);

const MAX_ITEMS = 50;

const styleCache = new Map();
const localeCache = new Map();

function loadStyle(styleId) {
  if (!styleCache.has(styleId)) {
    const file = path.join(STYLES_DIR, `${styleId}.csl`);
    styleCache.set(styleId, fs.readFileSync(file, "utf8"));
  }
  return styleCache.get(styleId);
}

function loadLocale(localeKey) {
  const fileName = SUPPORTED_LOCALES.get(localeKey) ??
    SUPPORTED_LOCALES.get("en");
  if (!localeCache.has(fileName)) {
    localeCache.set(
      fileName,
      fs.readFileSync(path.join(LOCALES_DIR, fileName), "utf8"),
    );
  }
  return localeCache.get(fileName);
}

function stripMarkup(html) {
  return String(html)
    .replace(/<[^>]*>/g, "")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&#38;#60;/g, "<")
    .replace(/&#38;#62;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;|&apos;/g, "'")
    .replace(/\s+/g, " ")
    .trim();
}

/**
 * Core: format CSL-JSON items with a bundled style. Returns
 * [{ text, html }]. Throws Error with a code prefix on bad input.
 */
function formatBibliography({ items, style, locale }) {
  const styleId = typeof style === "string" ? style.trim() : "";
  if (!SUPPORTED_STYLES.has(styleId)) {
    throw new Error(`invalid-argument: Unsupported style: ${styleId || "(empty)"}`);
  }
  if (!Array.isArray(items) || items.length === 0 || items.length > MAX_ITEMS) {
    throw new Error(`invalid-argument: items must be 1..${MAX_ITEMS} CSL-JSON records`);
  }
  for (const item of items) {
    if (
      !item || typeof item !== "object" || typeof item.id !== "string" ||
      typeof item.title !== "string" || item.title.trim() === ""
    ) {
      throw new Error("invalid-argument: each item needs a string id and title");
    }
  }
  const localeXml = loadLocale(typeof locale === "string" ? locale : "en");
  const sys = {
    retrieveLocale: () => localeXml,
    retrieveItem: (id) => items.find((it) => it.id === id),
  };
  const engine = new CSL.Engine(sys, loadStyle(styleId));
  engine.updateItems(items.map((it) => it.id));
  const result = engine.makeBibliography();
  if (!result || !Array.isArray(result[1])) {
    throw new Error("internal: bibliography build failed");
  }
  return result[1].map((html) => ({
    html: String(html),
    text: stripMarkup(html),
  }));
}

/**
 * Formats CSL-JSON items into bibliography lines with a bundled journal
 * style. Callable: formatCitations({ items, style, locale }).
 * Returns { entries: [{ text, html }] }.
 */
function createFormatCitationsHandler() {
  return onCall({ timeoutSeconds: 30 }, (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }
    try {
      const data = request.data || {};
      const entries = formatBibliography({
        items: data.items,
        style: data.style,
        locale: data.locale,
      });
      return { entries };
    } catch (e) {
      const message = e instanceof Error ? e.message : String(e);
      if (message.startsWith("invalid-argument:")) {
        throw new HttpsError("invalid-argument", message.slice(17).trim());
      }
      throw new HttpsError("internal", message);
    }
  });
}

module.exports = {
  createFormatCitationsHandler,
  formatBibliography,
  SUPPORTED_STYLES,
  stripMarkup,
};
