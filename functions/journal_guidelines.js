const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { getAuth } = require("firebase-admin/auth");
const pdfParse = require("pdf-parse");

const MAX_PAGE_BYTES = 900000;
const MAX_TEXT_FOR_AI = 70000;

function stripHtml(html) {
  return String(html || "")
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<noscript[\s\S]*?<\/noscript>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/\s+/g, " ")
    .trim();
}

function extractLinks(html, baseUrl) {
  const links = new Set();
  const re = /href\s*=\s*["']([^"']+)["']/gi;
  let match;
  while ((match = re.exec(html)) !== null) {
    try {
      const url = new URL(match[1], baseUrl).href;
      if (url.startsWith("http")) links.add(url);
    } catch (_) {}
  }
  return [...links];
}

function scoreGuideLink(url) {
  const lower = url.toLowerCase();
  let score = 0;
  if (lower.includes("about/submissions")) score += 7;
  if (lower.includes("information/authors")) score += 7;
  if (lower.includes("author-instructions")) score += 6;
  if (lower.includes("for-authors")) score += 6;
  if (lower.includes("author-guideline")) score += 6;
  if (lower.includes("author-guidelines")) score += 6;
  if (lower.includes("instructions-for-authors")) score += 6;
  if (lower.includes("guide-for-authors")) score += 6;
  if (lower.includes("author")) score += 3;
  if (lower.includes("guide")) score += 2;
  if (lower.includes("instruction")) score += 2;
  if (lower.includes("manuscript")) score += 2;
  if (lower.includes("submission")) score += 2;
  if (lower.includes("ejol.info") || lower.includes("ajol.info")) score += 4;
  if (lower.includes("ethiopian")) score += 2;
  return score;
}

const { assertSafePublicHttpsUrl } = require("./url_safety");

async function fetchPage(url) {
  try {
    assertSafePublicHttpsUrl(url);
  } catch (err) {
    return { html: null, text: null, status: 0, error: err?.message };
  }
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 25000);
  try {
    const response = await fetch(url, {
      signal: controller.signal,
      headers: {
        "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
          "(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36 AcadeGate/1.0",
        Accept:
          "text/html,application/xhtml+xml,text/plain,application/pdf;q=0.9,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9,ar;q=0.8",
      },
      redirect: "follow",
    });
    if (!response.ok) {
      return { html: null, text: null, status: response.status };
    }
    const contentType = (response.headers.get("content-type") || "").toLowerCase();
    const buffer = Buffer.from(await response.arrayBuffer());
    if (buffer.length > MAX_PAGE_BYTES) {
      return { html: null, text: null, status: 413 };
    }

    if (contentType.includes("pdf") || String(url).toLowerCase().includes(".pdf")) {
      try {
        const parsed = await pdfParse(buffer);
        const text = String(parsed.text || "").trim();
        return { html: null, text, status: 200, contentType: "pdf" };
      } catch (_) {
        return { html: null, text: null, status: 0 };
      }
    }

    if (
      contentType.includes("text/html") ||
      contentType.includes("text/plain") ||
      contentType.includes("application/xhtml")
    ) {
      return {
        html: buffer.toString("utf8"),
        text: null,
        status: 200,
        contentType: "html",
      };
    }
    return { html: null, text: null, status: 0, contentType };
  } catch (err) {
    return { html: null, text: null, status: 0, error: String(err?.message || err) };
  } finally {
    clearTimeout(timer);
  }
}

function pageTextFromFetch(result) {
  if (!result) return "";
  if (result.text && result.text.trim().length > 0) return result.text.trim();
  if (result.html) return stripHtml(result.html);
  return "";
}

async function crossrefJournalUrl(issn) {
  const raw = String(issn || "").trim();
  if (!raw) return null;
  const parts = raw.split(/[,;\s]+/).map((s) => s.trim()).filter(Boolean);
  for (const part of parts) {
    const clean = part.replace(/[^0-9Xx\-]/gi, "");
    if (clean.length < 8) continue;
    try {
      const response = await fetch(
        `https://api.crossref.org/journals/${encodeURIComponent(clean)}`,
        {
          headers: {
            Accept: "application/json",
            "User-Agent": "AcadeGate/1.0 (mailto:support@acadegate.app)",
          },
        },
      );
      if (!response.ok) continue;
      const data = await response.json();
      const url = data?.message?.URL;
      if (url && String(url).startsWith("http")) return String(url);
    } catch (_) {}
  }
  return null;
}

function journalSlugGuess(journalName) {
  const lower = String(journalName || "").toLowerCase();
  if (lower.includes("chemical society of ethiopia") || lower.includes("bcse")) {
    return "bcse";
  }
  const paren = String(journalName || "").match(/\(([A-Za-z]{2,8})\)/);
  if (paren) return paren[1].toLowerCase();
  const words = lower
    .replace(/[^a-z0-9\s]/g, " ")
    .split(/\s+/)
    .filter((w) => w.length > 3 && !["journal", "bulletin", "review", "international", "the", "and", "of"].includes(w));
  if (words.length >= 2 && words.length <= 6) {
    return words.map((w) => w[0]).join("");
  }
  return words[0] || "";
}

function discoverGenericOjsCandidates(journalName) {
  const candidates = [];
  const slug = journalSlugGuess(journalName);
  const slugs = new Set([slug].filter(Boolean));
  const paren = String(journalName || "").match(/\(([A-Za-z]{2,8})\)/);
  if (paren) slugs.add(paren[1].toLowerCase());

  const hosts = [
    "https://www.ajol.info/index.php",
    "https://ejol.aau.edu.et/index.php",
  ];
  const paths = ["/about/submissions", "/information/authors", "/about"];

  for (const s of slugs) {
    for (const host of hosts) {
      for (const path of paths) {
        candidates.push({ url: `${host}/${s}${path}`, source: "ojs_pattern" });
      }
    }
    candidates.push({
      url: `https://bulletin.csechem.org/index.php/${s}/about/submissions`,
      source: "ojs_pattern",
    });
  }
  return candidates;
}

async function discoverAjolEjolCandidates(journalName) {
  const candidates = [];
  const slug = journalSlugGuess(journalName);
  const encoded = encodeURIComponent(journalName);

  const knownPatterns = [];
  if (slug === "bcse") {
    knownPatterns.push(
      "https://bulletin.csechem.org/index.php/bcse/about/submissions",
      "https://www.ajol.info/index.php/bcse/about/submissions",
      "https://www.ajol.info/index.php/bcse/information/authors",
      "https://ejol.aau.edu.et/index.php/BCSE/information/authors",
    );
  }
  if (slug) {
    knownPatterns.push(
      `https://www.ajol.info/index.php/${slug}/about/submissions`,
      `https://www.ajol.info/index.php/${slug}/information/authors`,
    );
  }

  for (const url of knownPatterns) {
    candidates.push({ url, source: "ajol_ejol_pattern" });
  }

  for (const base of ["https://www.ajol.info", "https://ejol.aau.edu.et"]) {
    try {
      const searchUrl = `${base}/index.php/index/search/results?query=${encoded}`;
      const fetched = await fetchPage(searchUrl);
      if (fetched.status !== 200 || !fetched.html) continue;
      const links = extractLinks(fetched.html, base)
        .filter((u) => scoreGuideLink(u) >= 5)
        .slice(0, 4);
      for (const url of links) {
        candidates.push({ url, source: "ajol_search" });
      }
    } catch (_) {}
  }

  return candidates;
}

function isQuotaError(status) {
  return status === 429 || status === 503;
}

function quotaMessage() {
  return (
    "انتهى رصيد/حد طلبات Gemini API. أضف رصيداً من Google AI Studio: " +
    "https://aistudio.google.com/apikey — أو انتظر دقائق ثم أعد المحاولة."
  );
}

function scoreGuideText(text) {
  const lower = String(text || "").toLowerCase();
  let score = 0;
  if (lower.includes("instructions for authors")) score += 8;
  if (lower.includes("author guidelines")) score += 8;
  if (lower.includes("submission preparation")) score += 6;
  if (lower.includes("manuscript")) score += 4;
  if (lower.includes("abstract")) score += 2;
  if (/single[\s-]?spaced/i.test(text)) score += 5;
  if (/\d+\s*point/i.test(text)) score += 4;
  if (lower.includes("microsoft word")) score += 3;
  score += Math.min(10, Math.floor(text.length / 2000));
  return score;
}

function extractRulesHeuristic(pageText, sourceUrl) {
  const text = String(pageText || "");
  const lower = text.toLowerCase();
  if (scoreGuideText(text) < 6) return null;

  const rules = {
    found: false,
    confidence: "medium",
    keyRequirements: [],
    sectionOrder: [],
    acceptedFileFormats: [],
    excerpt: text.replace(/\s+/g, " ").slice(0, 350),
    guidelinesUrl: sourceUrl,
  };

  if (/single[\s-]?spaced/i.test(text)) {
    rules.lineSpacing = 1;
    rules.lineSpacingLabel = "single";
    rules.keyRequirements.push("Single-spaced text");
    rules.found = true;
  } else if (/double[\s-]?spaced/i.test(text)) {
    rules.lineSpacing = 2;
    rules.lineSpacingLabel = "double";
    rules.keyRequirements.push("Double-spaced text");
    rules.found = true;
  } else if (/1\.5[\s-]?spaced|one and a half/i.test(text)) {
    rules.lineSpacing = 1.5;
    rules.lineSpacingLabel = "1.5";
    rules.found = true;
  }

  const fontPt = text.match(/(\d{1,2})[\s-]?point/i);
  if (fontPt) {
    rules.bodyFontSizePt = Number(fontPt[1]);
    rules.keyRequirements.push(`${fontPt[1]}-point font`);
    rules.found = true;
  }

  if (/times new roman/i.test(text)) {
    rules.fontFamily = "Times New Roman";
    rules.found = true;
  } else if (/arial/i.test(text)) {
    rules.fontFamily = "Arial";
    rules.found = true;
  }

  const abstractMax =
    text.match(/abstract[^.]{0,120}?(\d{2,4})\s*words?/i) ||
    text.match(/contain\s+(\d{2,4})\s*words/i);
  if (abstractMax) {
    const n = Number(abstractMax[1]);
    if (n >= 50 && n <= 5000) {
      rules.abstractMaxWords = n;
      rules.keyRequirements.push(`Abstract max ${n} words`);
      rules.found = true;
    }
  }

  const apc = text.match(/(?:processing charge|apc|fee).{0,40}(\$\s*[\d,]+)/i) ||
    text.match(/(\$\s*300)/);
  if (apc) {
    rules.articleProcessingCharge = apc[1].replace(/\s+/g, "");
    rules.found = true;
  }

  if (/microsoft word|\.docx?|openoffice|rtf/i.test(text)) {
    const formats = [];
    if (/microsoft word|\.docx?/i.test(text)) formats.push("Microsoft Word");
    if (/rtf/i.test(text)) formats.push("RTF");
    if (/openoffice/i.test(text)) formats.push("OpenOffice");
    rules.acceptedFileFormats = formats;
    rules.found = true;
  }

  const sections = [];
  for (const name of [
    "Title", "Abstract", "Introduction", "Experimental",
    "Methods", "Results", "Discussion", "Conclusion", "References",
  ]) {
    if (lower.includes(name.toLowerCase())) sections.push(name);
  }
  if (sections.length >= 3) {
    rules.sectionOrder = sections;
    rules.found = true;
  }

  if (/without\s+\[\s*\]|without\s+square\s+brackets|listed\s+as\s+1\./i.test(text)) {
    rules.citationStyle = "vancouver";
    rules.referenceListPlainNumber = true;
    rules.keyRequirements.push("References as 1., 2., 3. without brackets");
    rules.found = true;
  } else if (lower.includes("reference") && /\[\s*\d+\s*\]/.test(text)) {
    rules.citationStyle = "vancouver";
    rules.found = true;
  } else if (/\bieee\b/i.test(text)) {
    rules.citationStyle = "ieee";
    rules.found = true;
  } else if (/\bapa\b/i.test(text)) {
    rules.citationStyle = "apa";
    rules.found = true;
  }

  return rules.found ? rules : null;
}

async function callGemini({ apiKey, model, body }) {
  const endpoint =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}` +
    `:generateContent?key=${apiKey}`;
  const response = await fetch(endpoint, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    const errText = await response.text().catch(() => "");
    return {
      ok: false,
      status: response.status,
      error: `${model}: HTTP ${response.status}${errText ? ` — ${errText.slice(0, 120)}` : ""}`,
      quota: isQuotaError(response.status),
    };
  }
  const data = await response.json();
  const parts = data?.candidates?.[0]?.content?.parts;
  const text = Array.isArray(parts)
    ? parts.map((p) => p?.text || "").join("\n").trim()
    : "";
  return { ok: true, data, text, model };
}

async function searchDoajHomepages(journalName) {
  const name = String(journalName || "").trim();
  if (!name) return [];
  try {
    const response = await fetch(
      `https://doaj.org/api/search/journals/${encodeURIComponent(`"${name}"`)}?pageSize=5`,
      {
        headers: {
          Accept: "application/json",
          "User-Agent": "AcadeGate/1.0 (mailto:support@acadegate.app)",
        },
      },
    );
    if (!response.ok) return [];
    const data = await response.json();
    const urls = [];
    for (const hit of data?.results || []) {
      for (const link of hit?.bibjson?.link || []) {
        const href = link?.url;
        if (href && String(href).startsWith("http")) urls.push(String(href));
      }
    }
    return [...new Set(urls)];
  } catch (_) {
    return [];
  }
}

async function searchOpenAlexHomepages(journalName, issn) {
  try {
    const cleanIssn = String(issn || "").replace(/[^0-9Xx]/gi, "");
    const url =
      cleanIssn.length >= 8
        ? `https://api.openalex.org/sources?filter=issn:${encodeURIComponent(cleanIssn)}&per_page=3`
        : `https://api.openalex.org/sources?search=${encodeURIComponent(journalName)}&per_page=5`;
    const response = await fetch(url, {
      headers: {
        "User-Agent": "AcadeGate/1.0 (mailto:support@acadegate.app)",
        Accept: "application/json",
      },
    });
    if (!response.ok) return [];
    const data = await response.json();
    return [...new Set(
      (data?.results || [])
        .map((r) => r?.homepage_url)
        .filter((u) => u && String(u).startsWith("http")),
    )];
  } catch (_) {
    return [];
  }
}

async function addHomepageCandidates({ homepage, source, candidates, attempted }) {
  if (!homepage) return;
  attempted.push(homepage);
  const fetched = await fetchPage(homepage);
  if (fetched.status !== 200) return;

  const html = fetched.html;
  if (html) {
    const links = extractLinks(html, homepage)
      .map((url) => ({ url, score: scoreGuideLink(url) }))
      .filter((item) => item.score >= 4)
      .sort((a, b) => b.score - a.score);
    for (const link of links.slice(0, 5)) {
      candidates.push({ url: link.url, source });
    }
    if (stripHtml(html).length > 400 && scoreGuideLink(homepage) >= 4) {
      candidates.push({ url: homepage, source });
    }
  } else {
    const text = pageTextFromFetch(fetched);
    if (text.length > 400 && scoreGuideLink(homepage) >= 4) {
      candidates.push({ url: homepage, source });
    }
  }
}

async function resolveGuidePages({
  journalName,
  publisher,
  issn,
  candidateUrls,
  submissionUrl,
}) {
  const attempted = [];
  const candidates = [];

  const addCandidate = (url, source, crawl = false) => {
    const trimmed = String(url || "").trim();
    if (!trimmed.startsWith("http")) return;
    attempted.push(trimmed);
    candidates.push({ url: trimmed, source, crawl });
  };

  if (Array.isArray(candidateUrls)) {
    for (const url of candidateUrls) {
      addCandidate(url, "client_seed", true);
    }
  }

  const submission = String(submissionUrl || "").trim();
  if (submission) {
    addCandidate(submission, "submission_portal", true);
  }

  const crossrefHome = await crossrefJournalUrl(issn);
  await addHomepageCandidates({
    homepage: crossrefHome,
    source: "crossref_homepage",
    candidates,
    attempted,
  });

  const doajHomes = await searchDoajHomepages(journalName);
  for (const home of doajHomes.slice(0, 3)) {
    await addHomepageCandidates({
      homepage: home,
      source: "doaj_homepage",
      candidates,
      attempted,
    });
  }

  const openAlexHomes = await searchOpenAlexHomepages(journalName, issn);
  for (const home of openAlexHomes.slice(0, 3)) {
    await addHomepageCandidates({
      homepage: home,
      source: "openalex_homepage",
      candidates,
      attempted,
    });
  }

  const ajolCandidates = await discoverAjolEjolCandidates(journalName);
  for (const item of ajolCandidates) {
    addCandidate(item.url, item.source);
  }

  for (const item of discoverGenericOjsCandidates(journalName)) {
    addCandidate(item.url, item.source);
  }

  const publisherHub = publisherAuthorHub(publisher);
  if (publisherHub) {
    addCandidate(publisherHub, "publisher_hub");
  }

  const unique = [];
  const seen = new Set();
  for (const item of candidates) {
    if (seen.has(item.url)) continue;
    seen.add(item.url);
    unique.push(item);
  }
  return { candidates: unique.slice(0, 20), attempted };
}

function publisherAuthorHub(publisher) {
  const p = String(publisher || "").toLowerCase();
  if (p.includes("elsevier")) {
    return "https://www.elsevier.com/researcher/author/policies-and-guidelines";
  }
  if (p.includes("springer")) {
    return "https://www.springernature.com/gp/authors/campaigns/how-to-publish";
  }
  if (p.includes("ieee")) {
    return "https://journals.ieeeauthorcenter.ieee.org/create-your-ieee-journal-article/";
  }
  if (p.includes("wiley")) {
    return "https://authorservices.wiley.com/author-resources/Journal-Authors/index.html";
  }
  if (p.includes("taylor") || p.includes("francis")) {
    return "https://authorservices.taylorandfrancis.com/publishing-your-research/writing-your-paper/journal-manuscript-layout-guide/";
  }
  if (p.includes("mdpi")) return "https://www.mdpi.com/authors";
  if (p.includes("acs") || p.includes("american chemical society")) {
    return "https://publish.acs.org/publish/author_guidelines";
  }
  if (p.includes("royal society of chemistry") || p === "rsc") {
    return "https://www.rsc.org/journals-books-databases/journal-authors/";
  }
  if (p.includes("oxford university press") || p.includes("oup")) {
    return "https://academic.oup.com/pages/author-guidelines";
  }
  if (p.includes("cambridge university press")) {
    return "https://www.cambridge.org/core/services/authors/journals";
  }
  if (p.includes("sage")) return "https://journals.sagepub.com/author-instructions";
  if (p.includes("frontiers")) {
    return "https://www.frontiersin.org/guidelines/author-guidelines";
  }
  if (p.includes("plos")) {
    return "https://journals.plos.org/plosone/s/submission-guidelines";
  }
  if (p.includes("hindawi")) return "https://www.hindawi.com/authors/";
  return null;
}

function parseJsonFromModel(text) {
  const raw = String(text || "").trim();
  const fenced = raw.match(/```(?:json)?\s*([\s\S]*?)```/i);
  const candidate = fenced ? fenced[1].trim() : raw;
  try {
    return JSON.parse(candidate);
  } catch (_) {
    const start = candidate.indexOf("{");
    const end = candidate.lastIndexOf("}");
    if (start >= 0 && end > start) {
      try {
        return JSON.parse(candidate.slice(start, end + 1));
      } catch (_) {}
    }
  }
  return null;
}

async function extractRulesWithGemini({
  apiKey,
  journalName,
  publisher,
  sourceUrl,
  pageText,
}) {
  const prompt = `You are an academic publishing expert. Read the author guidelines text and extract ONLY formatting rules explicitly stated.

Journal: ${journalName}
Publisher: ${publisher || "unknown"}
Source URL: ${sourceUrl}

Return ONLY valid JSON (no markdown):
{
  "found": boolean,
  "confidence": "high" | "medium" | "low",
  "citationStyle": "ieee" | "apa" | "vancouver" | "acs" | "chicago" | "harvard" | "other",
  "fontFamily": string or null,
  "bodyFontSizePt": number or null,
  "lineSpacing": number or null,
  "lineSpacingLabel": "single" | "double" | "1.5" | null,
  "marginCm": number or null,
  "justifyText": boolean or null,
  "referencesHeading": string or null,
  "referenceListPlainNumber": boolean or null,
  "abstractMaxWords": number or null,
  "sectionOrder": string[],
  "acceptedFileFormats": string[],
  "articleProcessingCharge": string or null,
  "keyRequirements": string[],
  "excerpt": string,
  "notes": string
}

Rules:
- Set found=false if the text does not contain manuscript formatting instructions.
- If text says "single-spaced" set lineSpacing=1 and lineSpacingLabel="single".
- If text says "double-spaced" set lineSpacing=2 and lineSpacingLabel="double".
- Capture section order (Title, Abstract, Introduction, etc.) in sectionOrder.
- Capture fees (APC) in articleProcessingCharge if mentioned.
- excerpt must be a short quote from the source (max 350 chars).
- Do not invent rules not present in the text.

TEXT:
${pageText.slice(0, MAX_TEXT_FOR_AI)}`;

  const models = ["gemini-2.0-flash-lite", "gemini-2.0-flash"];
  let lastError = "gemini_failed";
  let quotaHit = false;

  for (const model of models) {
    const result = await callGemini({
      apiKey,
      model,
      body: {
        contents: [{ role: "user", parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.1,
          maxOutputTokens: 4096,
        },
      },
    });
    if (!result.ok) {
      lastError = result.error;
      if (result.quota) {
        quotaHit = true;
        break;
      }
      continue;
    }
    const parsed = parseJsonFromModel(result.text);
    if (parsed && typeof parsed === "object") {
      return { rules: parsed, model: result.model, quotaHit: false };
    }
    lastError = `${model}: invalid_json`;
  }
  return { error: quotaHit ? quotaMessage() : lastError, quotaHit };
}

const RULES_JSON_FIELDS = `{
  "found": boolean,
  "guidelinesUrl": string or null,
  "confidence": "high" | "medium" | "low",
  "citationStyle": "ieee" | "apa" | "vancouver" | "acs" | "chicago" | "harvard" | "other",
  "fontFamily": string or null,
  "bodyFontSizePt": number or null,
  "lineSpacing": number or null,
  "lineSpacingLabel": "single" | "double" | "1.5" | null,
  "marginCm": number or null,
  "justifyText": boolean or null,
  "referencesHeading": string or null,
  "referenceListPlainNumber": boolean or null,
  "abstractMaxWords": number or null,
  "sectionOrder": string[],
  "acceptedFileFormats": string[],
  "articleProcessingCharge": string or null,
  "keyRequirements": string[],
  "excerpt": string,
  "notes": string
}`;

function urlsFromGrounding(data) {
  const chunks = data?.candidates?.[0]?.groundingMetadata?.groundingChunks || [];
  const urls = [];
  for (const chunk of chunks) {
    const uri = chunk?.web?.uri || chunk?.retrievedContext?.uri;
    if (uri && String(uri).startsWith("http")) urls.push(String(uri));
  }
  return [...new Set(urls)];
}

async function extractWithGoogleSearchGrounding({
  apiKey,
  journalName,
  publisher,
  issn,
}) {
  const prompt = `Find the official author guidelines / instructions for authors for this academic journal using Google Search.

Journal: ${journalName}
Publisher: ${publisher || "unknown"}
ISSN: ${issn || "unknown"}

Steps:
1. Search the web for this journal's author guidelines (try: "${journalName}" instructions for authors, "${journalName}" guide for authors, "${journalName}" manuscript formatting).
2. Open and read the actual guidelines page (EJO, AJOL, publisher site, etc.).
3. Extract ONLY formatting rules explicitly stated on that page.

Return ONLY valid JSON (no markdown):
${RULES_JSON_FIELDS}

Rules:
- guidelinesUrl = the URL of the guidelines page you read.
- Set found=false only if no author guidelines exist online for this journal.
- If text says "single-spaced" set lineSpacing=1 and lineSpacingLabel="single".
- If text says "double-spaced" set lineSpacing=2 and lineSpacingLabel="double".
- excerpt must quote the source (max 350 chars).
- Do not invent rules not present in the guidelines.`;

  const models = ["gemini-2.0-flash"];
  let lastError = "google_search_grounding_failed";

  for (const model of models) {
    const result = await callGemini({
      apiKey,
      model,
      body: {
        contents: [{ role: "user", parts: [{ text: prompt }] }],
        tools: [{ google_search: {} }],
        generationConfig: {
          temperature: 0.1,
          maxOutputTokens: 4096,
        },
      },
    });
    if (!result.ok) {
      lastError = result.quota ? quotaMessage() : result.error;
      if (result.quota) break;
      continue;
    }
    const parsed = parseJsonFromModel(result.text);
    if (!parsed || typeof parsed !== "object") {
      lastError = `${model}: invalid_json`;
      continue;
    }
    const groundingUrls = urlsFromGrounding(result.data);
    const guidelinesUrl =
      parsed.guidelinesUrl ||
      groundingUrls.find((u) => scoreGuideLink(u) >= 3) ||
      groundingUrls[0] ||
      null;
    return {
      rules: parsed,
      model: result.model,
      guidelinesUrl,
      groundingUrls,
      searchQueries:
        result.data?.candidates?.[0]?.groundingMetadata?.webSearchQueries || [],
    };
  }
  return { error: lastError };
}

async function runExtraction(data, apiKey) {
  const journalName = String(data?.journalName || "").trim();
  const publisher = String(data?.publisher || "").trim();
  const issn = String(data?.issn || "").trim();
  const manualUrl = String(data?.guidelinesUrl || "").trim();
  const pastedText = String(data?.guidelinesText || "").trim();
  const submissionUrl = String(data?.submissionUrl || "").trim();
  const candidateUrls = Array.isArray(data?.candidateUrls) ? data.candidateUrls : [];

  if (!journalName) {
    throw new HttpsError("invalid-argument", "journalName required");
  }
  if (!apiKey) {
    throw new HttpsError(
      "failed-precondition",
      "GEMINI_API_KEY غير مضبوط — لا يمكن قراءة دليل المؤلفين تلقائياً",
    );
  }

  if (pastedText.length >= 80) {
    const heuristic = extractRulesHeuristic(
      pastedText,
      manualUrl || "pasted_by_user",
    );
    if (heuristic) {
      return {
        success: true,
        sourceUrl: manualUrl || "pasted_by_user",
        sourceType: "pasted_text_heuristic",
        model: "heuristic",
        rules: heuristic,
        attemptedUrls: manualUrl ? [manualUrl] : [],
        fetchLog: [],
      };
    }
    const ai = await extractRulesWithGemini({
      apiKey,
      journalName,
      publisher,
      sourceUrl: manualUrl || "pasted_by_user",
      pageText: pastedText,
    });
    if (ai.error) {
      return {
        success: false,
        reason: "ai_parse_failed",
        message: ai.error,
        attemptedUrls: manualUrl ? [manualUrl] : [],
        fetchLog: [],
      };
    }
    const rules = ai.rules || {};
    if (rules.found === true) {
      return {
        success: true,
        sourceUrl: manualUrl || "pasted_by_user",
        sourceType: "pasted_text",
        model: ai.model,
        rules,
        attemptedUrls: manualUrl ? [manualUrl] : [],
        fetchLog: [],
      };
    }
  }

  const { candidates, attempted } = await resolveGuidePages({
    journalName,
    publisher,
    issn,
    candidateUrls,
    submissionUrl,
  });

  if (manualUrl) {
    candidates.unshift({ url: manualUrl, source: "manual" });
    attempted.unshift(manualUrl);
  }

  const fetchLog = [];
  const fetchedPages = [];
  let quotaHit = false;

  for (const candidate of candidates) {
    const fetched = await fetchPage(candidate.url);
    const text = pageTextFromFetch(fetched);
    fetchLog.push({
      url: candidate.url,
      source: candidate.source,
      fetched: fetched.status === 200,
      status: fetched.status || 0,
      textLength: text.length,
      contentType: fetched.contentType || "",
      error: fetched.error || "",
    });
    if (fetched.status === 200 && text.length >= 120) {
      fetchedPages.push({
        url: candidate.url,
        source: candidate.source,
        text,
        score: scoreGuideText(text) + scoreGuideLink(candidate.url),
      });
    }
  }

  fetchedPages.sort((a, b) => b.score - a.score);

  for (const page of fetchedPages) {
    const heuristic = extractRulesHeuristic(page.text, page.url);
    if (heuristic) {
      return {
        success: true,
        sourceUrl: page.url,
        sourceType: `${page.source}_heuristic`,
        model: "heuristic",
        rules: heuristic,
        attemptedUrls: attempted,
        fetchLog,
      };
    }
  }

  if (fetchedPages.length > 0 && !quotaHit) {
    const best = fetchedPages[0];
    const ai = await extractRulesWithGemini({
      apiKey,
      journalName,
      publisher,
      sourceUrl: best.url,
      pageText: best.text,
    });
    if (ai.quotaHit) quotaHit = true;
    if (ai.error && !ai.quotaHit) {
      return {
        success: false,
        reason: "ai_parse_failed",
        message: ai.error,
        attemptedUrls: attempted,
        fetchLog,
      };
    }
    if (!ai.error) {
      const rules = ai.rules || {};
      if (rules.found === true) {
        return {
          success: true,
          sourceUrl: best.url,
          sourceType: best.source,
          model: ai.model,
          rules,
          attemptedUrls: attempted,
          fetchLog,
        };
      }
    }
  }

  const manualFailed = manualUrl && fetchLog.some((f) => f.source === "manual" && !f.fetched);

  // Last resort: Gemini + Google Search — only if quota not exhausted
  if (!pastedText && !quotaHit) {
    fetchLog.push({
      url: "gemini:google_search",
      source: "google_search_grounding",
      fetched: true,
      status: 0,
      textLength: 0,
      contentType: "ai_search",
      error: "",
    });

    const grounded = await extractWithGoogleSearchGrounding({
      apiKey,
      journalName,
      publisher,
      issn,
    });

    if (grounded.error) {
      fetchLog[fetchLog.length - 1].error = grounded.error;
      if (String(grounded.error).includes("رصيد") || String(grounded.error).includes("429")) {
        quotaHit = true;
      }
    } else {
      const rules = grounded.rules || {};
      if (rules.found === true) {
        const sourceUrl =
          grounded.guidelinesUrl ||
          rules.guidelinesUrl ||
          (grounded.groundingUrls && grounded.groundingUrls[0]) ||
          "google_search";
        return {
          success: true,
          sourceUrl: String(sourceUrl),
          sourceType: "google_search_grounding",
          model: grounded.model,
          rules,
          attemptedUrls: [
            ...attempted,
            ...(grounded.groundingUrls || []),
          ],
          fetchLog,
          searchQueries: grounded.searchQueries || [],
        };
      }
      fetchLog[fetchLog.length - 1].error = "no_rules_in_search_result";
    }
  }

  return {
    success: false,
    reason: quotaHit ? "quota_exceeded" : manualFailed ? "url_fetch_failed" : "no_guidelines_found",
    message: quotaHit
      ? quotaMessage()
      : manualFailed
        ? "تعذّر تحميل الرابط من الخادم. جرّب لصق نص الدليل في الخيارات المتقدمة."
        : "لم يُعثر على دليل مؤلفين تلقائياً. جرّب لصق رابط أو نص الدليل في الخيارات المتقدمة.",
    attemptedUrls: attempted,
    fetchLog,
  };
}

function createJournalGuidelinesHandlers(geminiApiKey) {
  const callHandler = async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
    }
    return runExtraction(request.data || {}, geminiApiKey.value());
  };

  const journalGuidelinesExtract = onCall(
    {
      secrets: [geminiApiKey],
      timeoutSeconds: 180,
      cors: true,
    },
    callHandler,
  );

  const journalGuidelinesExtractHttp = onRequest(
    {
      secrets: [geminiApiKey],
      cors: true,
      timeoutSeconds: 180,
      memory: "512MiB",
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

      try {
        await getAuth().verifyIdToken(token);
      } catch (_) {
        res.status(401).json({
          error: { status: "UNAUTHENTICATED", message: "Invalid auth token" },
        });
        return;
      }

      try {
        const body = req.body?.data || req.body || {};
        const result = await runExtraction(body, geminiApiKey.value());
        res.status(200).json({ result });
      } catch (err) {
        const message = err.message || "Extract guidelines failed";
        const status = err.code === "invalid-argument" ? 400 : 500;
        res.status(status).json({
          error: { status: "INTERNAL", message },
        });
      }
    },
  );

  return { journalGuidelinesExtract, journalGuidelinesExtractHttp };
}

module.exports = { createJournalGuidelinesHandlers };
