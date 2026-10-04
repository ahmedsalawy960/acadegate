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
const GEMINI_MODELS = ["gemini-2.5-flash", "gemini-2.5-flash-lite", "gemini-flash-latest"];

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

async function callGemini(apiKey, prompt) {
  let lastError = "gemini_failed";
  for (const model of GEMINI_MODELS) {
    try {
      const url =
        `https://generativelanguage.googleapis.com/v1beta/models/${model}` +
        `:generateContent?key=${encodeURIComponent(apiKey)}`;
      const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ role: "user", parts: [{ text: prompt }] }],
          generationConfig: {
            temperature: 0.4,
            maxOutputTokens: 2048,
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

function createResearchIdeasSyncHandlers(geminiApiKey) {
  const researchIdeasSyncWeekly = onSchedule(
    {
      schedule: "every tuesday 04:00",
      timeZone: "Africa/Cairo",
      timeoutSeconds: 540,
      memory: "1GiB",
      secrets: [geminiApiKey],
    },
    async () => {
      await runResearchIdeasSync({
        adminUid: "system_weekly_ideas_sync",
        apiKey: geminiApiKey.value(),
        autoApprove: true,
        scope: "all",
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
      return runResearchIdeasSync({
        adminUid: request.auth.uid,
        apiKey: geminiApiKey.value(),
        autoApprove,
        scope,
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
};
