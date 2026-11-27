const crypto = require("crypto");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { fetchScienceNewsForIngest } = require("./science_news_rss");

/**
 * Continuous research-idea ingest:
 * OpenAlex works + science RSS → normalize (Gemini or heuristic) → research_ideas.
 */

const OPENALEX_MAILTO = "mailto:acadegate@acadegate.app";
const MAX_OPENALEX = 14;
const MAX_RSS = 12;
const MAX_OPENALEX_HUMANITIES = 28;
const MAX_RSS_HUMANITIES = 8;
const MAX_GEMINI_BATCH = 4;
const GEMINI_MODELS = ["gemini-3.6-flash", "gemini-3-flash-preview", "gemini-3.1-flash-lite"];

// ─── Grounded frontier pipeline («ابدأ من حيث انتهى البحث») ─────────
// Every generated idea starts from a real, recent, open-access paper and
// that paper's OWN limitations / future-work text. No full text, no idea.
// Cost cap: ideas written per daily run. Override with IDEAS_MAX_PER_RUN.
const MAX_IDEAS_PER_RUN = Math.max(
  1,
  Number(process.env.IDEAS_MAX_PER_RUN || 15) || 15,
);
// Papers fetched per run; dedup/extraction failures shrink this to the cap.
const GROUNDED_CANDIDATE_POOL = 40;
// Rolling freshness window for source papers, in months.
const OA_WINDOW_MONTHS = 12;
const MAX_FULLTEXT_BYTES = 1500000;
const FULLTEXT_TIMEOUT_MS = 12000;
const GEMINI_GUIDE_MAX_TOKENS = 6000;
const NATIONAL_PRIORITIES = [
  { id: "water", ar: "المياه والموارد المائية", en: "Water resources" },
  { id: "energy", ar: "الطاقة", en: "Energy" },
  { id: "agriculture", ar: "الزراعة والأمن الغذائي", en: "Agriculture & food security" },
  { id: "health", ar: "الصحة", en: "Health" },
  { id: "industry", ar: "الصناعة والتصنيع المحلي", en: "Industry & local manufacturing" },
  { id: "digital", ar: "التحول الرقمي", en: "Digital transformation" },
  { id: "education", ar: "التعليم وبناء الإنسان", en: "Education & human development" },
];
const NATIONAL_PRIORITY_IDS = new Set(NATIONAL_PRIORITIES.map((p) => p.id));

const FACULTY_QUERIES = [
  { category: "Engineering", query: "smart grid renewable energy materials engineering" },
  { category: "CS", query: "machine learning natural language processing Arabic" },
  { category: "Medicine", query: "precision medicine public health clinical AI" },
  { category: "Science", query: "nanomaterials climate chemistry catalysis" },
  { category: "Pharmacy", query: "drug delivery pharmaceutical nanotechnology" },
  { category: "Agriculture", query: "climate-smart agriculture crop stress Egypt" },
  { category: "Business", query: "digital transformation SME entrepreneurship" },
  { category: "Education", query: "educational technology learning assessment" },
  { category: "Law", query: "cyber law data protection comparative legislation" },
  { category: "Architecture", query: "sustainable architecture urban resilience" },
];

/** OpenAlex queries focused on humanities / social / legal / education gaps. */
const HUMANITIES_FACULTY_QUERIES = [
  { category: "Education", query: "inclusive education assistive technology Universal Design for Learning" },
  { category: "Education", query: "digital divide rural education learning outcomes Egypt" },
  { category: "Education", query: "artificial intelligence teacher education special education" },
  { category: "Education", query: "formative assessment digital exams secondary education" },
  { category: "Education", query: "climate education curriculum secondary schools" },
  { category: "Law", query: "artificial intelligence criminal justice due process data protection" },
  { category: "Law", query: "electronic litigation civil procedure digital courts" },
  { category: "Law", query: "personal data protection AI training regulation comparative law" },
  { category: "Law", query: "algorithmic administrative decisions accountability transparency" },
  { category: "Law", query: "digital evidence mobile forensics fair trial rights" },
  { category: "Arts", query: "digital humanities Arabic text mining intertextuality" },
  { category: "Arts", query: "digital literary studies interactive fiction hypertext" },
  { category: "Arts", query: "documentary heritage digitization archives preservation" },
  { category: "Arts", query: "oral history digital archive intangible cultural heritage" },
  { category: "Arts", query: "information literacy libraries deepfake media literacy" },
  { category: "Business", query: "digital transformation productivity medium enterprises" },
  { category: "Business", query: "startup governance founders investors agency costs" },
  { category: "Business", query: "green microfinance women entrepreneurship alternative credit data" },
  { category: "MassCommunication", query: "health misinformation social media crisis communication" },
  { category: "MassCommunication", query: "data journalism environmental justice local media" },
  { category: "MassCommunication", query: "influencer marketing sustainable consumption youth" },
  { category: "Tourism", query: "heritage tourism digital storytelling sustainable destinations" },
  { category: "FineArts", query: "digital art curation cultural heritage visualization" },
  { category: "PhysicalEducation", query: "physical education inclusion school sports pedagogy" },
];

const HUMANITIES_FACULTY_IDS = new Set([
  "Education",
  "Law",
  "Arts",
  "Business",
  "MassCommunication",
  "Tourism",
  "PhysicalEducation",
  "FineArts",
  "ProfessionalStudies",
]);

const RSS_CATEGORY_TO_FACULTY = {
  medicine: "Medicine",
  engineering: "Engineering",
  technology: "CS",
  physics: "Science",
  chemistry: "Science",
  biology: "Science",
  environment: "Science",
  agriculture: "Agriculture",
  psychology: "Education",
  mathematics: "CS",
  astronomy: "Science",
  general: "Science",
};

const FACULTY_IDS = new Set([
  "Engineering",
  "Science",
  "Medicine",
  "Dentistry",
  "Pharmacy",
  "Nursing",
  "Veterinary",
  "Law",
  "CS",
  "Agriculture",
  "Business",
  "Education",
  "Arts",
  "Architecture",
  "MassCommunication",
  "Tourism",
  "PhysicalEducation",
  "FineArts",
  "ProfessionalStudies",
]);

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

function stableId(externalId) {
  const hash = crypto.createHash("sha1").update(String(externalId)).digest("hex").slice(0, 24);
  return `sync_${hash}`;
}

function contentHash(title, details) {
  return crypto
    .createHash("sha1")
    .update(`${String(title).trim().toLowerCase()}|${String(details).trim().toLowerCase()}`)
    .digest("hex");
}

function normalizeDegreeLevel(raw) {
  const v = String(raw || "").toLowerCase().trim();
  if (v === "phd" || v === "doctorate" || v === "doctoral") return "phd";
  if (v === "masters" || v === "master" || v === "msc" || v === "ma") return "masters";
  if (v === "both" || v === "any") return "both";
  return "both";
}

function normalizeCategory(raw, fallback = "Science") {
  const v = String(raw || "").trim();
  if (FACULTY_IDS.has(v)) return v;
  return FACULTY_IDS.has(fallback) ? fallback : "Science";
}

function openAlexId(work) {
  const id = String(work?.id || "").replace("https://openalex.org/", "").trim();
  return id || "";
}

async function fetchOpenAlexWorks(query, perPage = 2) {
  const fromYear = new Date().getFullYear() - 3;
  const url =
    "https://api.openalex.org/works?" +
    new URLSearchParams({
      search: query,
      filter: `from_publication_date:${fromYear}-01-01,type:article|review`,
      sort: "cited_by_count:desc",
      per_page: String(perPage),
      mailto: "acadegate@acadegate.app",
    }).toString();

  const res = await fetch(url, {
    headers: {
      Accept: "application/json",
      "User-Agent": `AcadeGateResearchIdeasSync ${OPENALEX_MAILTO}`,
    },
  });
  if (!res.ok) return [];
  const data = await res.json();
  const results = Array.isArray(data?.results) ? data.results : [];
  return results.map((work) => {
    const id = openAlexId(work);
    const title = String(work?.display_name || work?.title || "").trim();
    const abstract = reconstructAbstract(work?.abstract_inverted_index);
    const concepts = (work?.concepts || [])
      .slice(0, 6)
      .map((c) => c?.display_name)
      .filter(Boolean);
    const doi = work?.doi ? String(work.doi) : "";
    const landing =
      work?.primary_location?.landing_page_url ||
      work?.primary_location?.source?.homepage_url ||
      (doi ? `https://doi.org/${doi.replace(/^https?:\/\/doi\.org\//i, "")}` : "") ||
      (id ? `https://openalex.org/${id}` : "");
    return {
      source: "openalex",
      externalId: id ? `openalex:${id}` : `openalex_title:${contentHash(title, abstract).slice(0, 16)}`,
      title,
      summary: abstract.slice(0, 900),
      url: landing,
      categoryHint: "",
      tags: concepts,
      citedByCount: Number(work?.cited_by_count || 0),
      publishedYear: work?.publication_year || null,
    };
  }).filter((x) => x.title);
}

function reconstructAbstract(inverted) {
  if (!inverted || typeof inverted !== "object") return "";
  const pairs = [];
  for (const [word, positions] of Object.entries(inverted)) {
    if (!Array.isArray(positions)) continue;
    for (const pos of positions) pairs.push([pos, word]);
  }
  pairs.sort((a, b) => a[0] - b[0]);
  return pairs.map((p) => p[1]).join(" ").trim();
}

// ─── Grounded frontier helpers ────────────────────────────────────────

function rollingFromDate(monthsBack) {
  const d = new Date();
  d.setMonth(d.getMonth() - monthsBack);
  return d.toISOString().slice(0, 10);
}

async function fetchTextWithTimeout(
  url,
  { maxBytes = MAX_FULLTEXT_BYTES, timeoutMs = FULLTEXT_TIMEOUT_MS, binary = false } = {},
) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      signal: controller.signal,
      redirect: "follow",
      headers: { "User-Agent": `AcadeGateResearchIdeasSync ${OPENALEX_MAILTO}` },
    });
    if (!res.ok || !res.body) return null;
    const reader = res.body.getReader();
    const chunks = [];
    let total = 0;
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      chunks.push(Buffer.from(value));
      total += value.length;
      if (total >= maxBytes) {
        try { await reader.cancel(); } catch (_) {}
        break;
      }
    }
    const buf = Buffer.concat(chunks);
    return binary ? buf : buf.toString("utf8");
  } catch (_) {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

function stripMarkupToText(markup) {
  return String(markup || "")
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    // Block-level boundaries become newlines so section headings stay
    // detectable as standalone lines before whitespace is collapsed.
    .replace(/<\/(p|div|section|article|li|tr|h[1-6])>/gi, "\n")
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/&#39;|&apos;/gi, "'")
    .replace(/&quot;/gi, '"')
    .replace(/[ \t]+/g, " ")
    .replace(/ *\n */g, "\n")
    .replace(/\n{2,}/g, "\n")
    .trim();
}

const GAP_SECTION_PATTERNS = [
  { key: "limitations", re: /\blimitations?\b/i },
  { key: "future_work", re: /future (work|research|directions?|studies|investigations?)/i },
  { key: "conclusion", re: /conclusions?\b/i },
];
const GAP_SECTION_MAX_CHARS = 1400;

// Plain-text sources (HTML pages, PDF text, ar5iv): prefer heading-like
// lines (short line containing the gap phrase), then fall back to the first
// body mention. Imperfect by nature; the generation step is constrained to
// quote from these windows only, and ungrounded quotes are dropped before
// anything is written.
function extractGapSectionsFromText(fullText) {
  const raw = String(fullText || "");
  // Bibliography titles often contain "limitations"/"future work", so only
  // search the body before the references heading. Pages often link
  // "References" in a nav menu near the top, so take the first standalone
  // references heading in the latter 70% of the document. When references
  // were cut and nothing is found, the paper is skipped: a junk bibliography
  // snippet is worse grounding than none.
  const refRe = /\n[ \t]*(?:\d+\.?\s+)?(references|bibliography)[ \t]*\n/gi;
  let refIdx = -1;
  let rm;
  while ((rm = refRe.exec(raw)) !== null) {
    if (rm.index > raw.length * 0.3) refIdx = rm.index;
  }
  const text = refIdx >= 0 ? raw.slice(0, refIdx) : raw;
  const lines = text.split("\n");
  const found = [];
  for (const { key, re } of GAP_SECTION_PATTERNS) {
    let start = -1;
    let offset = 0;
    for (const line of lines) {
      const trimmed = line.trim();
      // Heading-like: short line with the gap phrase, and not a reference
      // entry (citation titles often contain the word "limitations").
      if (
        trimmed.length > 0 &&
        trimmed.length < 90 &&
        re.test(trimmed) &&
        !/\[\d+\]|\bvol\.|\bpp\.|\bet al\.|\bdoi\b/i.test(trimmed)
      ) {
        start = offset + line.length;
        break;
      }
      offset += line.length + 1;
    }
    if (start < 0) {
      const m = re.exec(text);
      if (m && typeof m.index === "number") start = m.index + m[0].length;
    }
    if (start >= 0) found.push({ key, start });
  }

  found.sort((a, b) => a.start - b.start);
  const sections = [];
  for (const f of found) {
    const snippet = text
      .slice(f.start, f.start + GAP_SECTION_MAX_CHARS)
      .replace(/\n+/g, " ")
      .trim();
    if (
      snippet.length >= 120 &&
      !sections.some((s) => s.text.slice(0, 80) === snippet.slice(0, 80))
    ) {
      sections.push({ section: f.key, text: snippet });
    }
  }
  return sections.slice(0, 3);
}

// Europe PMC fullTextXML: <sec> blocks carry clean <title> headings, so the
// limitation / future-work / conclusion sections extract by tag.
function extractGapSectionsFromXml(xml) {
  const raw = String(xml || "");
  const out = [];
  for (const { key, re } of GAP_SECTION_PATTERNS) {
    const secRe = new RegExp(
      `<title>[^<]*${re.source}[^<]*<\\/title>([\\s\\S]{120,}?)(?=<title>|<\\/sec>)`,
      "i",
    );
    const m = secRe.exec(raw);
    if (m) {
      const snippet = stripMarkupToText(m[1]).slice(0, GAP_SECTION_MAX_CHARS).trim();
      if (snippet.length >= 120) out.push({ section: key, text: snippet });
    }
  }
  return out.slice(0, 3);
}

// Resolve the paper's gap sections from the best available full text:
// Europe PMC XML -> ar5iv HTML -> generic OA HTML -> OA PDF (pdf-parse is
// already a dependency). Returns null when nothing usable exists; the paper
// is then skipped (OA-only grounded rule).
async function resolvePaperSections(work) {
  const pmcid = String(work.pmcid || "").replace(/^PMC/i, "");
  if (pmcid) {
    const xml = await fetchTextWithTimeout(
      `https://www.ebi.ac.uk/europepmc/webservices/rest/PMC${pmcid}/fullTextXML`,
    );
    if (xml) {
      const sections = extractGapSectionsFromXml(xml);
      if (sections.length) return { sections, fullTextSource: "europepmc" };
    }
  }
  const arxivMatch =
    /arxiv\.org\/(?:abs|pdf)\/([0-9.]+)/i.exec(work.oaUrl || "") ||
    /arxiv\.org\/(?:abs|pdf)\/([0-9.]+)/i.exec(work.url || "");
  if (arxivMatch) {
    const html = await fetchTextWithTimeout(
      `https://ar5iv.labs.arxiv.org/html/${arxivMatch[1]}`,
    );
    if (html) {
      const sections = extractGapSectionsFromText(stripMarkupToText(html));
      if (sections.length) return { sections, fullTextSource: "ar5iv" };
    }
  }
  if (work.oaUrl && !/\.pdf(\?|$)/i.test(work.oaUrl)) {
    const html = await fetchTextWithTimeout(work.oaUrl);
    if (html && !html.startsWith("%PDF")) {
      const sections = extractGapSectionsFromText(stripMarkupToText(html));
      if (sections.length) return { sections, fullTextSource: "oa_html" };
    }
  }
  const pdfUrl =
    work.pdfUrl || (/\.pdf(\?|$)/i.test(work.oaUrl || "") ? work.oaUrl : "");
  if (pdfUrl) {
    const buf = await fetchTextWithTimeout(pdfUrl, {
      binary: true,
      maxBytes: 6 * 1024 * 1024,
      timeoutMs: 20000,
    });
    if (buf && buf.length > 1000) {
      try {
        const pdfParse = require("pdf-parse");
        const parsed = await pdfParse(buf);
        const sections = extractGapSectionsFromText(parsed.text || "");
        if (sections.length) return { sections, fullTextSource: "oa_pdf" };
      } catch (_) {}
    }
  }
  return null;
}

async function fetchOpenAlexGrounded(query, perPage = 20) {
  const url =
    "https://api.openalex.org/works?" +
    new URLSearchParams({
      search: query,
      filter: `from_publication_date:${rollingFromDate(OA_WINDOW_MONTHS)},type:article|review,is_oa:true`,
      sort: "publication_date:desc",
      per_page: String(perPage),
      mailto: "acadegate@acadegate.app",
    }).toString();
  const res = await fetch(url, {
    headers: {
      Accept: "application/json",
      "User-Agent": `AcadeGateResearchIdeasSync ${OPENALEX_MAILTO}`,
    },
  });
  if (!res.ok) return [];
  const data = await res.json();
  const results = Array.isArray(data?.results) ? data.results : [];
  return results
    .map((work) => {
      const id = openAlexId(work);
      const title = String(work?.display_name || "").trim();
      const abstract = reconstructAbstract(work?.abstract_inverted_index);
      const best = work?.best_oa_location || work?.primary_location || {};
      const ids = work?.ids || {};
      const doi = String(ids.doi || work?.doi || "").replace(
        /^https?:\/\/doi\.org\//i,
        "",
      );
      return {
        source: "openalex_grounded",
        externalId: id
          ? `openalex:${id}`
          : `openalex_title:${contentHash(title, abstract).slice(0, 16)}`,
        title,
        summary: abstract.slice(0, 900),
        url:
          best.landing_page_url ||
          (doi ? `https://doi.org/${doi}` : id ? `https://openalex.org/${id}` : ""),
        oaUrl: best.landing_page_url || "",
        pdfUrl: best.pdf_url || "",
        doi,
        pmcid: String(ids.pmcid || "")
          .replace(/^https?:\/\/www\.ncbi\.nlm\.nih\.gov\/pmc\/articles\//i, "")
          .replace(/\/$/, ""),
        venue: String(
          best?.source?.display_name ||
            work?.primary_location?.source?.display_name ||
            "",
        ),
        publishedYear: work?.publication_year || null,
        publishedDate: String(work?.publication_date || ""),
        citedByCount: Number(work?.cited_by_count || 0),
        authors: (work?.authorships || [])
          .slice(0, 6)
          .map((a) => a?.author?.display_name)
          .filter(Boolean),
        tags: (work?.concepts || [])
          .slice(0, 6)
          .map((c) => c?.display_name)
          .filter(Boolean),
        categoryHint: "",
      };
    })
    .filter((x) => x.title);
}

async function verifyDoiCrossref(doi) {
  if (!doi) return null;
  const res = await fetch(
    `https://api.crossref.org/works/${encodeURIComponent(doi)}?mailto=acadegate@acadegate.app`,
    {
      headers: { "User-Agent": `AcadeGateResearchIdeasSync ${OPENALEX_MAILTO}` },
      signal: AbortSignal.timeout(10000),
    },
  ).catch(() => null);
  if (!res || !res.ok) return null;
  const msg = (await res.json().catch(() => null))?.message;
  if (!msg) return null;
  return {
    title: String((msg.title || [])[0] || ""),
    authors: (msg.author || [])
      .slice(0, 6)
      .map((a) => [a?.given, a?.family].filter(Boolean).join(" "))
      .filter(Boolean),
    year: Number(msg?.issued?.["date-parts"]?.[0]?.[0]) || null,
    venue: String((msg["container-title"] || [])[0] || ""),
    doi: String(msg.DOI || doi),
  };
}

async function frontierCheckS2(title) {
  const query = String(title || "").split(/\s+/).slice(0, 12).join(" ");
  if (!query) return { nearestWorks: [] };
  const url =
    "https://api.semanticscholar.org/graph/v1/paper/search?" +
    new URLSearchParams({
      query,
      limit: "3",
      fields: "title,year,url,externalIds",
    }).toString();
  const res = await fetch(url, {
    headers: { "User-Agent": `AcadeGateResearchIdeasSync ${OPENALEX_MAILTO}` },
    signal: AbortSignal.timeout(10000),
  }).catch(() => null);
  if (!res || !res.ok) {
    return { nearestWorks: [], error: `http_${res ? res.status : "fetch_failed"}` };
  }
  const data = await res.json().catch(() => null);
  const nearestWorks = (Array.isArray(data?.data) ? data.data : [])
    .map((p) => ({
      title: String(p?.title || ""),
      year: p?.year || null,
      url: String(p?.url || ""),
      doi: String(p?.externalIds?.DOI || ""),
    }))
    .filter((w) => w.title);
  return { nearestWorks };
}

function pickDailyQueries(now = new Date()) {
  // Rotate the general faculty queries across the week: today's slice only.
  const day = now.getDay(); // 0=Sun ... 6=Sat
  const perDay = Math.ceil(FACULTY_QUERIES.length / 7);
  const start = (day * perDay) % FACULTY_QUERIES.length;
  const rotated = [
    ...FACULTY_QUERIES.slice(start),
    ...FACULTY_QUERIES.slice(0, start),
  ];
  return rotated.slice(0, perDay);
}

async function collectOpenAlexCandidates(scope = "all") {
  const queries =
    scope === "humanities" ? HUMANITIES_FACULTY_QUERIES : FACULTY_QUERIES;
  const max =
    scope === "humanities" ? MAX_OPENALEX_HUMANITIES : MAX_OPENALEX;
  const out = [];
  for (const item of queries) {
    if (out.length >= max) break;
    try {
      const works = await fetchOpenAlexWorks(item.query, scope === "humanities" ? 2 : 2);
      for (const work of works) {
        if (out.length >= max) break;
        out.push({ ...work, categoryHint: item.category });
      }
    } catch (_) {
      // continue other queries
    }
    await sleep(200);
  }
  return out;
}

async function collectRssCandidates(scope = "all") {
  const limit = scope === "humanities" ? MAX_RSS_HUMANITIES : MAX_RSS;
  try {
    const items = await fetchScienceNewsForIngest({ language: "en", limit });
    return items
      .map((item) => ({
        source: "science_rss",
        externalId: `rss:${contentHash(item.url || item.title, item.summary || "").slice(0, 20)}`,
        title: item.title,
        summary: item.summary || "",
        url: item.url || "",
        categoryHint: RSS_CATEGORY_TO_FACULTY[item.category] || "Science",
        tags: [item.source, item.category].filter(Boolean),
        citedByCount: 0,
        publishedYear: item.publishedAt ? new Date(item.publishedAt).getFullYear() : null,
      }))
      .filter((item) =>
        scope === "humanities"
          ? HUMANITIES_FACULTY_IDS.has(item.categoryHint) ||
            ["psychology", "general", "environment"].includes(
              String(item.tags?.[1] || "").toLowerCase(),
            )
          : true,
      );
  } catch (_) {
    return [];
  }
}

function heuristicIdea(raw, scope = "all") {
  const fallbackCat =
    scope === "humanities"
      ? normalizeCategory(raw.categoryHint, "Education")
      : normalizeCategory(raw.categoryHint, "Science");
  const category =
    scope === "humanities" && !HUMANITIES_FACULTY_IDS.has(fallbackCat)
      ? "Education"
      : fallbackCat;
  const degreeLevel =
    Number(raw.citedByCount || 0) >= 40 || /review|framework|theory/i.test(raw.title)
      ? "phd"
      : "masters";
  const tags = [...(raw.tags || [])].slice(0, 8);
  if (!tags.includes(degreeLevel)) tags.push(degreeLevel === "phd" ? "دكتوراه" : "ماجستير");
  if (scope === "humanities" && !tags.includes("إنسانيات")) tags.push("فجوة بحثية");

  const details = [
    "المشكلة: " + (raw.summary || raw.title).slice(0, 280),
    scope === "humanities"
      ? "الفجوة البحثية: الأدبيات الحديثة تشير إلى حاجة لدراسة تطبيقية في السياق المصري/العربي (تربية، قانون، آداب، علوم اجتماعية) تستغل ثغرة منهجية أو تشريعية أو تربوية واضحة."
      : "الفجوة البحثية: بناءً على اتجاهات حديثة في الأدبيات/الأخبار العلمية، ما زالت هناك حاجة لدراسة تطبيقية في السياق العربي/المصري.",
    "الأهداف: (1) تحليل الظاهرة (2) اقتراح نموذج أو تدخل (3) تقييم الأثر.",
    "المنهجية المقترحة: مراجعة أدبيات منهجية + دراسة تطبيقية (كمية/نوعية/مختلطة) مناسبة للتخصص.",
    "المخرجات المتوقعة: إطار نظري، نتائج قابلة للنشر، وتوصيات لصنّاع القرار أو الممارسين.",
  ].join("\n");

  return {
    title: String(raw.title).slice(0, 160),
    provider: raw.source === "openalex" ? "OpenAlex · AcadeGate Sync" : "Science News · AcadeGate Sync",
    details,
    tags,
    category,
    degreeLevel,
    feasibilityScore: 0.62,
    budget: "",
  };
}

function extractJsonObject(text) {
  const raw = String(text || "").trim();
  const fenced = raw.match(/```(?:json)?\s*([\s\S]*?)```/i);
  const body = (fenced ? fenced[1] : raw).trim();
  const start = body.indexOf("{");
  const end = body.lastIndexOf("}");
  if (start < 0 || end <= start) throw new Error("no_json");
  return JSON.parse(body.slice(start, end + 1));
}

async function callGemini(apiKey, prompt, maxOutputTokens = 2048) {
  let lastError = "gemini_failed";
  for (const model of GEMINI_MODELS) {
    try {
      const url =
        `https://generativelanguage.googleapis.com/v1beta/models/${model}` +
        `:generateContent?key=${encodeURIComponent(apiKey)}`;
      const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        signal: AbortSignal.timeout(60000),
        body: JSON.stringify({
          contents: [{ role: "user", parts: [{ text: prompt }] }],
          generationConfig: {
            temperature: 0.4,
            maxOutputTokens,
            responseMimeType: "application/json",
          },
        }),
      });
      if (!res.ok) {
        lastError = `http_${res.status}`;
        continue;
      }
      const data = await res.json();
      const parts = data?.candidates?.[0]?.content?.parts || [];
      const text = parts.map((p) => p?.text || "").join("\n").trim();
      if (!text) {
        lastError = "empty";
        continue;
      }
      return text;
    } catch (e) {
      lastError = e?.message || String(e);
    }
  }
  throw new Error(lastError);
}

async function geminiNormalize(apiKey, raw, scope = "all") {
  const humanitiesHint =
    scope === "humanities"
      ? `
Focus ONLY on humanities / education / law / arts / media / social-business thesis ideas.
Emphasize a clear RESEARCH GAP (what is missing in Egypt/Arab literature vs global 2023-2026 trends).
Prefer field methods (survey, interview, doctrinal analysis, archive, discourse) — not lab samples.
Allowed categories: ${[...HUMANITIES_FACULTY_IDS].join(", ")}.
`
      : "";

  const prompt = `You are an academic research coach for Egyptian/Arab postgraduate students.
Convert the source into ONE research idea suitable for a Master's or PhD thesis marketplace.
${humanitiesHint}
Return ONLY JSON with keys:
title (Arabic preferred, concise),
provider (short Arabic/English credit),
details (Arabic, multiline with: المشكلة / الفجوة البحثية / الأهداف / المنهجية المقترحة / المخرجات المتوقعة),
tags (array of 4-8 short Arabic/English keywords),
category (one of: ${[...(scope === "humanities" ? HUMANITIES_FACULTY_IDS : FACULTY_IDS)].join(", ")}),
degreeLevel ("masters" | "phd" | "both"),
feasibilityScore (0-1),
budget (optional short Arabic note or empty string).

Source type: ${raw.source}
Faculty hint: ${raw.categoryHint || ""}
Title: ${raw.title}
Summary: ${(raw.summary || "").slice(0, 700)}
URL: ${raw.url || ""}
Tags: ${(raw.tags || []).join(", ")}
Citations: ${raw.citedByCount || 0}
Year: ${raw.publishedYear || ""}

Rules:
- Do NOT invent fake data sources or universities.
- Keep the idea actionable for a thesis (not a news paraphrase).
- Prefer Egyptian/Arab application context when sensible.
- Explicitly state the gap in «الفجوة البحثية».
- If source is a review/highly cited paper, lean toward phd; applied news gaps may be masters.`;

  const text = await callGemini(apiKey, prompt);
  const parsed = extractJsonObject(text);
  let category = normalizeCategory(
    parsed.category,
    raw.categoryHint || (scope === "humanities" ? "Education" : "Science"),
  );
  if (scope === "humanities" && !HUMANITIES_FACULTY_IDS.has(category)) {
    category = normalizeCategory(raw.categoryHint, "Education");
    if (!HUMANITIES_FACULTY_IDS.has(category)) category = "Education";
  }
  return {
    title: String(parsed.title || raw.title).slice(0, 180),
    provider: String(parsed.provider || "AcadeGate Sync").slice(0, 120),
    details: String(parsed.details || "").trim() || heuristicIdea(raw, scope).details,
    tags: Array.isArray(parsed.tags)
      ? parsed.tags.map((t) => String(t).trim()).filter(Boolean).slice(0, 10)
      : heuristicIdea(raw, scope).tags,
    category,
    degreeLevel: normalizeDegreeLevel(parsed.degreeLevel),
    feasibilityScore: Math.max(
      0,
      Math.min(1, Number(parsed.feasibilityScore ?? 0.65) || 0.65),
    ),
    budget: String(parsed.budget || "").slice(0, 80),
  };
}

async function normalizeCandidate(apiKey, raw, scope = "all") {
  if (apiKey) {
    try {
      return await geminiNormalize(apiKey, raw, scope);
    } catch (_) {
      return heuristicIdea(raw, scope);
    }
  }
  return heuristicIdea(raw, scope);
}

async function writeRawIngest(db, batchId, candidates) {
  const writes = [];
  for (const raw of candidates) {
    const id = stableId(`raw:${raw.externalId}`);
    writes.push(
      db.collection("idea_ingest_raw").doc(id).set(
        {
          ...raw,
          batchId,
          fetchedAt: FieldValue.serverTimestamp(),
          status: "fetched",
        },
        { merge: true },
      ),
    );
  }
  // Firestore limits: commit in chunks of 40 sequential sets is fine for ~26 docs
  for (let i = 0; i < writes.length; i += 40) {
    await Promise.all(writes.slice(i, i + 40));
  }
}

async function upsertIdeas(db, { candidates, normalized, adminUid, autoApprove, batchId, scope = "all" }) {
  let imported = 0;
  let updated = 0;
  let skipped = 0;
  const seedSource =
    scope === "humanities" ? "research_ideas_sync_humanities" : "research_ideas_sync";

  for (let i = 0; i < candidates.length; i++) {
    const raw = candidates[i];
    const idea = normalized[i];
    if (!idea?.title || !idea?.details) {
      skipped += 1;
      continue;
    }

    if (scope === "humanities" && !HUMANITIES_FACULTY_IDS.has(idea.category)) {
      skipped += 1;
      continue;
    }

    const docId = stableId(`${scope}:${raw.externalId}`);
    const ref = db.collection("research_ideas").doc(docId);
    const snap = await ref.get();
    const hash = contentHash(idea.title, idea.details);

    const base = {
      title: idea.title,
      // العنوان والملخص الأصليان (إنجليزي غالباً) — يعرضهما التطبيق بجانب الصياغة العربية.
      titleEn: String(raw.title || "").slice(0, 300),
      summaryEn: String(raw.summary || "").slice(0, 900),
      provider: idea.provider,
      details: idea.details,
      tags: idea.tags,
      budget: idea.budget || "",
      category: idea.category,
      degreeLevel: idea.degreeLevel,
      feasibilityScore: idea.feasibilityScore,
      importSource: raw.source === "openalex" ? "openalex" : "science_rss",
      externalId: raw.externalId,
      sourceUrl: raw.url || "",
      seedSource,
      syncScope: scope,
      contentHash: hash,
      ingestBatchId: batchId,
      publisherId: adminUid || "system_ideas_sync",
      approvalStatus: autoApprove ? "approved" : "pending",
      syncedAt: FieldValue.serverTimestamp(),
    };

    if (!snap.exists) {
      await ref.set({
        ...base,
        status: "open",
        votesCount: 0,
        proposalsCount: 0,
        claimedBy: "",
        claimedByName: "",
        funded: false,
        createdAt: FieldValue.serverTimestamp(),
      });
      imported += 1;
    } else {
      const data = snap.data() || {};
      const patch = {
        ...base,
      };
      if (data.approvalStatus === "rejected") {
        delete patch.approvalStatus;
      }
      if (data.claimedBy) {
        delete patch.status;
      }
      await ref.set(patch, { merge: true });
      updated += 1;
    }

    await db.collection("idea_ingest_raw").doc(stableId(`raw:${scope}:${raw.externalId}`)).set(
      {
        status: "published",
        researchIdeaId: docId,
        syncScope: scope,
        normalizedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    if (apiKeyThrottleNeeded(i)) await sleep(350);
  }

  return { imported, updated, skipped };
}

function apiKeyThrottleNeeded(index) {
  return (index + 1) % MAX_GEMINI_BATCH === 0;
}

async function runResearchIdeasSync({
  adminUid = "system_ideas_sync",
  apiKey = "",
  autoApprove = true,
  scope = "all",
} = {}) {
  const db = getFirestore();
  const normalizedScope = scope === "humanities" ? "humanities" : "all";
  const batchId = `batch_${normalizedScope}_${Date.now()}`;

  const [openalex, rss] = await Promise.all([
    collectOpenAlexCandidates(normalizedScope),
    collectRssCandidates(normalizedScope),
  ]);

  const seen = new Set();
  const candidates = [];
  for (const item of [...openalex, ...rss]) {
    if (!item.externalId || seen.has(item.externalId)) continue;
    seen.add(item.externalId);
    candidates.push(item);
  }

  await writeRawIngest(db, batchId, candidates);

  const normalized = [];
  for (let i = 0; i < candidates.length; i++) {
    normalized.push(await normalizeCandidate(apiKey, candidates[i], normalizedScope));
    if (apiKey && apiKeyThrottleNeeded(i)) await sleep(400);
  }

  const stats = await upsertIdeas(db, {
    candidates,
    normalized,
    adminUid,
    autoApprove,
    batchId,
    scope: normalizedScope,
  });

  const summary = {
    syncedAt: FieldValue.serverTimestamp(),
    syncedBy: adminUid,
    batchId,
    scope: normalizedScope,
    candidates: candidates.length,
    openalex: openalex.length,
    rss: rss.length,
    imported: stats.imported,
    updated: stats.updated,
    skipped: stats.skipped,
    usedGemini: Boolean(apiKey),
    source: "cloud_function",
  };

  const metaPath =
    normalizedScope === "humanities"
      ? "app_meta/research_ideas_sync_humanities"
      : "app_meta/research_ideas_sync";
  await db.doc(metaPath).set(summary, { merge: true });
  // Keep a pointer on the general meta doc when humanities runs.
  if (normalizedScope === "humanities") {
    await db.doc("app_meta/research_ideas_sync").set(
      { lastHumanitiesSyncAt: FieldValue.serverTimestamp(), lastHumanitiesBatchId: batchId },
      { merge: true },
    );
  }

  return {
    batchId,
    scope: normalizedScope,
    candidates: candidates.length,
    openalex: openalex.length,
    rss: rss.length,
    imported: stats.imported,
    updated: stats.updated,
    skipped: stats.skipped,
    usedGemini: Boolean(apiKey),
  };
}

// ─── Grounded generation: ideas that start where the paper ended ─────

function normalizeWhitespace(s) {
  return String(s || "").toLowerCase().replace(/\s+/g, " ").trim();
}

// Anti-guesswork guard: the quoted limitation must actually appear in the
// extracted paper text. If the model paraphrases or invents it, the idea is
// dropped before anything is written.
function quoteIsGrounded(quote, sections) {
  const q = normalizeWhitespace(quote).slice(0, 60);
  if (q.length < 20) return false;
  return sections.some((s) => normalizeWhitespace(s.text).includes(q));
}

async function geminiGenerateGapIdeas(apiKey, { paper, sections, categoryHint }) {
  const extracts = sections
    .map((s) => `[${s.section}]\n${s.text}`)
    .join("\n\n")
    .slice(0, 4200);
  const priorityList = NATIONAL_PRIORITIES.map(
    (p) => `${p.id} (${p.ar} / ${p.en})`,
  ).join(", ");
  const prompt = `You generate research ideas for an Egyptian academic platform, in any field.
Given a recent published paper and VERBATIM extracts from its own Limitations / Future Work / Conclusion sections, propose 1 to 3 NEW research ideas that START WHERE THE PAPER ENDED. Use 1 idea when the gap is narrow, up to 3 only when the paper's stated gaps are broad or clearly distinct.
Rules:
- Ground every idea in the provided extracts. whereItEnded must COPY a sentence verbatim from the extracts below (never paraphrase, never invent).
- Never invent citations or references. The only source is this paper.
- National priorities: tag an idea ONLY when it directly serves that Egyptian priority, with a one-sentence Arabic justification. When none truly applies, return an empty list. Decorative tagging is forbidden.
- All guide content must be concrete enough for a graduate researcher to follow.
Return ONLY JSON with this shape:
{
 "ideas": [{
   "title": "Arabic concise title",
   "titleEn": "English title",
   "degreeLevel": "masters|phd|both",
   "budget": "short Arabic budget note or empty string",
   "feasibilityScore": 0.0,
   "whereItEnded": "verbatim English quote copied from the extracts",
   "whereItEndedSection": "limitations|future_work|conclusion",
   "proposedNextStepAr": "الخطوة البحثية المقترحة في جملتين",
   "guideAr": {"problem": "...", "objectives": ["..."], "methodology": ["..."], "milestones": [{"phase": "...", "duration": "..."}], "toolsAndSkills": ["..."], "expectedOutputs": ["..."]},
   "guideEn": {"problem": "...", "objectives": ["..."], "methodology": ["..."], "milestones": [{"phase": "...", "duration": "..."}], "toolsAndSkills": ["..."], "expectedOutputs": ["..."]},
   "guideSummaryEn": "3-4 sentence English summary",
   "nationalPriorities": [{"priority": "water|energy|agriculture|health|industry|digital|education", "justification": "جملة عربية واحدة"}]
 }]
}
National priorities allowed: ${priorityList}
Paper title: ${paper.title}
Paper abstract: ${(paper.summary || "").slice(0, 900)}
Faculty hint: ${categoryHint || ""}
Verbatim extracts from the paper:
${extracts}`;
  const text = await callGemini(apiKey, prompt, GEMINI_GUIDE_MAX_TOKENS);
  const parsed = extractJsonObject(text);
  const rawIdeas = Array.isArray(parsed?.ideas) ? parsed.ideas : [];
  const ideas = [];
  for (const raw of rawIdeas.slice(0, 3)) {
    const title = String(raw?.title || "").trim();
    const quote = String(raw?.whereItEnded || "").trim();
    if (!title || !quote) continue;
    if (!quoteIsGrounded(quote, sections)) continue; // ungrounded -> drop
    const priorities = (Array.isArray(raw?.nationalPriorities) ? raw.nationalPriorities : [])
      .map((p) => ({
        priority: String(p?.priority || "").trim(),
        justification: String(p?.justification || "").trim(),
      }))
      .filter((p) => NATIONAL_PRIORITY_IDS.has(p.priority) && p.justification.length >= 12)
      .slice(0, 3);
    ideas.push({
      title: title.slice(0, 180),
      titleEn: String(raw?.titleEn || "").slice(0, 300),
      degreeLevel: normalizeDegreeLevel(raw?.degreeLevel),
      budget: String(raw?.budget || "").slice(0, 120),
      feasibilityScore: Math.max(0, Math.min(1, Number(raw?.feasibilityScore ?? 0.65) || 0.65)),
      whereItEnded: quote.slice(0, 600),
      whereItEndedSection: ["limitations", "future_work", "conclusion"].includes(
        String(raw?.whereItEndedSection || ""),
      )
        ? String(raw.whereItEndedSection)
        : sections[0]?.section || "limitations",
      proposedNextStepAr: String(raw?.proposedNextStepAr || "").slice(0, 800),
      guideAr: raw?.guideAr && typeof raw.guideAr === "object" ? raw.guideAr : {},
      guideEn: raw?.guideEn && typeof raw.guideEn === "object" ? raw.guideEn : {},
      guideSummaryEn: String(raw?.guideSummaryEn || "").slice(0, 900),
      nationalPriorities: priorities,
    });
  }
  return { ideas };
}

function guideToDetailsText(idea) {
  const g = idea.guideAr || {};
  const lines = [];
  if (g.problem) lines.push(`المشكلة: ${g.problem}`);
  if (Array.isArray(g.objectives) && g.objectives.length) {
    lines.push(`الأهداف: ${g.objectives.join(" ؛ ")}`);
  }
  if (Array.isArray(g.methodology) && g.methodology.length) {
    lines.push(`المنهجية المقترحة: ${g.methodology.join(" ؛ ")}`);
  }
  if (Array.isArray(g.expectedOutputs) && g.expectedOutputs.length) {
    lines.push(`المخرجات المتوقعة: ${g.expectedOutputs.join(" ؛ ")}`);
  }
  return lines.join("\n").slice(0, 1800);
}

async function writeGroundedIdea(
  db,
  { idea, ideaIndex, paper, sections, crossref, frontier, fullTextSource, adminUid, autoApprove, batchId, stats },
) {
  const docId = stableId(`grounded:${paper.externalId}:${ideaIndex}`);
  const ref = db.collection("research_ideas").doc(docId);
  const snap = await ref.get();
  if (snap.exists) {
    stats.deduped += 1;
    return false;
  }
  const category = normalizeCategory(paper.categoryHint, "Science");
  const authors = crossref?.authors?.length
    ? crossref.authors
    : (paper.authors || []);
  const sourcePaper = {
    title: String(crossref?.title || paper.title || "").slice(0, 300),
    authors: authors.slice(0, 6),
    year: crossref?.year || paper.publishedYear || null,
    venue: String(crossref?.venue || paper.venue || "").slice(0, 200),
    doi: String(crossref?.doi || paper.doi || ""),
    doiVerified: Boolean(crossref),
    openAlexId: String(paper.externalId || "").replace(/^openalex:/, ""),
    url: String(paper.url || ""),
    publishedDate: String(paper.publishedDate || ""),
  };
  const starterReferences = [
    {
      title: sourcePaper.title,
      year: sourcePaper.year,
      url: sourcePaper.url,
      doi: sourcePaper.doi,
      role: "source",
    },
    ...(frontier.nearestWorks || []).map((w) => ({ ...w, role: "frontier" })),
  ].slice(0, 5);
  const tags = [...(paper.tags || [])].slice(0, 6);
  if (idea.degreeLevel && !tags.includes(idea.degreeLevel)) {
    tags.push(idea.degreeLevel === "phd" ? "دكتوراه" : "ماجستير");
  }
  await ref.set({
    // Legacy-compatible fields (UI reads these today).
    title: idea.title,
    titleEn: idea.titleEn,
    summaryEn: String(paper.summary || "").slice(0, 900),
    provider: "OpenAlex · AcadeGate Sync",
    details: guideToDetailsText(idea) || String(paper.summary || "").slice(0, 900),
    tags,
    budget: idea.budget,
    category,
    degreeLevel: idea.degreeLevel,
    feasibilityScore: idea.feasibilityScore,
    importSource: "openalex_grounded",
    externalId: paper.externalId,
    sourceUrl: paper.url || "",
    publisherId: adminUid || "system_grounded_ideas_sync",
    approvalStatus: autoApprove ? "approved" : "pending",
    status: "open",
    votesCount: 0,
    proposalsCount: 0,
    claimedBy: "",
    claimedByName: "",
    funded: false,
    createdAt: FieldValue.serverTimestamp(),
    syncedAt: FieldValue.serverTimestamp(),
    seedSource: "research_ideas_grounded",
    syncScope: "grounded",
    ingestBatchId: batchId,
    contentHash: contentHash(idea.title, idea.whereItEnded),
    // Citation contract + bilingual guide.
    generationMode: "oa_fulltext",
    fullTextSource,
    sourcePaper,
    sourceDoi: sourcePaper.doi,
    whereItEnded: { quote: idea.whereItEnded, section: idea.whereItEndedSection },
    proposedNextStepAr: idea.proposedNextStepAr,
    guideAr: idea.guideAr,
    guideEn: idea.guideEn,
    guideSummaryEn: idea.guideSummaryEn,
    nationalPriorities: idea.nationalPriorities,
    starterReferences,
    frontierCheck: {
      nearestWorks: frontier.nearestWorks || [],
      checkedAt: FieldValue.serverTimestamp(),
      error: frontier.error || "",
    },
    gapSectionsUsed: sections.map((s) => s.section),
  });
  return true;
}

async function runGroundedIdeasSync({
  adminUid = "system_grounded_ideas_sync",
  apiKey = "",
  maxIdeas = MAX_IDEAS_PER_RUN,
  autoApprove = true,
} = {}) {
  const db = getFirestore();
  const batchId = `batch_grounded_${Date.now()}`;
  const stats = {
    fetched: 0,
    deduped: 0,
    noFullText: 0,
    generated: 0,
    written: 0,
    failed: 0,
    droppedUngroundedQuotes: 0,
    timedOut: false,
  };
  const startedAt = Date.now();
  // Cloud Functions kills the instance at timeoutSeconds (540s) and the caller
  // then sees an opaque INTERNAL error. Stop starting new papers ~2 minutes
  // earlier so partial stats are always written and returned normally.
  const timeBudgetMs = 420000;
  if (!apiKey) {
    throw new Error("gemini_api_key_required");
  }
  const queries = pickDailyQueries();
  const pool = [];
  for (const q of queries) {
    try {
      const works = await fetchOpenAlexGrounded(q.query, 20);
      for (const w of works) pool.push({ ...w, categoryHint: q.category });
    } catch (_) {}
    await sleep(250);
    if (pool.length >= GROUNDED_CANDIDATE_POOL) break;
  }
  stats.fetched = pool.length;
  const seen = new Set();
  for (const paper of pool) {
    if (stats.written >= maxIdeas) break;
    if (Date.now() - startedAt > timeBudgetMs) {
      stats.timedOut = true;
      break;
    }
    if (seen.has(paper.externalId)) {
      stats.deduped += 1;
      continue;
    }
    seen.add(paper.externalId);
    try {
      if (paper.doi) {
        const dup = await db
          .collection("research_ideas")
          .where("sourceDoi", "==", paper.doi)
          .limit(1)
          .get();
        if (!dup.empty) {
          stats.deduped += 1;
          continue;
        }
      }
      const resolved = await resolvePaperSections(paper);
      if (!resolved) {
        stats.noFullText += 1;
        continue;
      }
      const crossref = await verifyDoiCrossref(paper.doi);
      const frontier = await frontierCheckS2(paper.title);
      const gen = await geminiGenerateGapIdeas(apiKey, {
        paper,
        sections: resolved.sections,
        categoryHint: paper.categoryHint,
      });
      stats.generated += gen.ideas.length;
      for (let i = 0; i < gen.ideas.length; i++) {
        if (stats.written >= maxIdeas) break;
        const ok = await writeGroundedIdea(db, {
          idea: gen.ideas[i],
          ideaIndex: i,
          paper,
          sections: resolved.sections,
          crossref,
          frontier,
          fullTextSource: resolved.fullTextSource,
          adminUid,
          autoApprove,
          batchId,
          stats,
        });
        if (ok) stats.written += 1;
      }
      await sleep(500); // Gemini + API politeness
    } catch (_) {
      stats.failed += 1;
    }
  }
  await db.doc("app_meta/research_ideas_sync").set(
    {
      groundedSyncedAt: FieldValue.serverTimestamp(),
      groundedBatchId: batchId,
      groundedStats: stats,
    },
    { merge: true },
  );
  return { batchId, ...stats };
}

function createResearchIdeasSyncHandlers(geminiApiKey) {
  // Daily grounded frontier sync (name kept for deployment compatibility):
  // recent OA papers -> their own limitations/future work -> new ideas.
  const researchIdeasSyncWeekly = onSchedule(
    {
      schedule: "every day 04:00",
      timeZone: "Africa/Cairo",
      timeoutSeconds: 540,
      memory: "1GiB",
      secrets: [geminiApiKey],
    },
    async () => {
      await runGroundedIdeasSync({
        adminUid: "system_daily_ideas_sync",
        apiKey: geminiApiKey.value(),
        autoApprove: true,
      });
    },
  );

  const researchIdeasSyncHumanitiesWeekly = onSchedule(
    {
      schedule: "every friday 05:00",
      timeZone: "Africa/Cairo",
      timeoutSeconds: 540,
      memory: "1GiB",
      secrets: [geminiApiKey],
    },
    async () => {
      await runResearchIdeasSync({
        adminUid: "system_weekly_humanities_ideas_sync",
        apiKey: geminiApiKey.value(),
        autoApprove: true,
        scope: "humanities",
      });
    },
  );

  const researchIdeasSyncNow = onCall(
    {
      timeoutSeconds: 540,
      memory: "1GiB",
      secrets: [geminiApiKey],
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Sign in required");
      }
      const db = getFirestore();
      const userSnap = await db.collection("users").doc(request.auth.uid).get();
      if (userSnap.get("role") !== "admin") {
        throw new HttpsError("permission-denied", "Admin only");
      }
      const autoApprove = request.data?.autoApprove !== false;
      const scope =
        String(request.data?.scope || "all").toLowerCase() === "humanities"
          ? "humanities"
          : "all";
      const mode = String(request.data?.mode || "grounded").toLowerCase();
      if (mode === "legacy") {
        return runResearchIdeasSync({
          adminUid: request.auth.uid,
          apiKey: geminiApiKey.value(),
          autoApprove,
          scope,
        });
      }
      return runGroundedIdeasSync({
        adminUid: request.auth.uid,
        apiKey: geminiApiKey.value(),
        autoApprove,
      });
    },
  );

  return {
    researchIdeasSyncWeekly,
    researchIdeasSyncHumanitiesWeekly,
    researchIdeasSyncNow,
  };
}

module.exports = {
  createResearchIdeasSyncHandlers,
  runResearchIdeasSync,
  runGroundedIdeasSync,
};
