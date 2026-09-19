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

async function collectOpenAlexCandidates() {
  const out = [];
  for (const item of FACULTY_QUERIES) {
    if (out.length >= MAX_OPENALEX) break;
    try {
      const works = await fetchOpenAlexWorks(item.query, 2);
      for (const work of works) {
        if (out.length >= MAX_OPENALEX) break;
        out.push({ ...work, categoryHint: item.category });
      }
    } catch (_) {
      // continue other queries
    }
    await sleep(200);
  }
  return out;
}

async function collectRssCandidates() {
  try {
    const items = await fetchScienceNewsForIngest({ language: "en", limit: MAX_RSS });
    return items.map((item) => ({
      source: "science_rss",
      externalId: `rss:${contentHash(item.url || item.title, item.summary || "").slice(0, 20)}`,
      title: item.title,
      summary: item.summary || "",
      url: item.url || "",
      categoryHint: RSS_CATEGORY_TO_FACULTY[item.category] || "Science",
      tags: [item.source, item.category].filter(Boolean),
      citedByCount: 0,
      publishedYear: item.publishedAt ? new Date(item.publishedAt).getFullYear() : null,
    }));
  } catch (_) {
    return [];
  }
}

function heuristicIdea(raw) {
  const category = normalizeCategory(raw.categoryHint, "Science");
  const degreeLevel =
    Number(raw.citedByCount || 0) >= 40 || /review|framework|theory/i.test(raw.title)
      ? "phd"
      : "masters";
  const tags = [...(raw.tags || [])].slice(0, 8);
  if (!tags.includes(degreeLevel)) tags.push(degreeLevel === "phd" ? "دكتوراه" : "ماجستير");

  const details = [
    "المشكلة: " + (raw.summary || raw.title).slice(0, 280),
    "الفجوة البحثية: بناءً على اتجاهات حديثة في الأدبيات/الأخبار العلمية، ما زالت هناك حاجة لدراسة تطبيقية في السياق العربي/المصري.",
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

async function geminiNormalize(apiKey, raw) {
  const prompt = `You are an academic research coach for Egyptian/Arab postgraduate students.
Convert the source into ONE research idea suitable for a Master's or PhD thesis marketplace.

Return ONLY JSON with keys:
title (Arabic preferred, concise),
provider (short Arabic/English credit),
details (Arabic, multiline with: المشكلة / الفجوة البحثية / الأهداف / المنهجية المقترحة / المخرجات المتوقعة),
tags (array of 4-8 short Arabic/English keywords),
category (one of: ${[...FACULTY_IDS].join(", ")}),
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
- If source is a review/highly cited paper, lean toward phd; applied news gaps may be masters.`;

  const text = await callGemini(apiKey, prompt);
  const parsed = extractJsonObject(text);
  return {
    title: String(parsed.title || raw.title).slice(0, 180),
    provider: String(parsed.provider || "AcadeGate Sync").slice(0, 120),
    details: String(parsed.details || "").trim() || heuristicIdea(raw).details,
    tags: Array.isArray(parsed.tags)
      ? parsed.tags.map((t) => String(t).trim()).filter(Boolean).slice(0, 10)
      : heuristicIdea(raw).tags,
    category: normalizeCategory(parsed.category, raw.categoryHint || "Science"),
    degreeLevel: normalizeDegreeLevel(parsed.degreeLevel),
    feasibilityScore: Math.max(
      0,
      Math.min(1, Number(parsed.feasibilityScore ?? 0.65) || 0.65),
    ),
    budget: String(parsed.budget || "").slice(0, 80),
  };
}

async function normalizeCandidate(apiKey, raw) {
  if (apiKey) {
    try {
      return await geminiNormalize(apiKey, raw);
    } catch (_) {
      return heuristicIdea(raw);
    }
  }
  return heuristicIdea(raw);
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

async function upsertIdeas(db, { candidates, normalized, adminUid, autoApprove, batchId }) {
  let imported = 0;
  let updated = 0;
  let skipped = 0;

  for (let i = 0; i < candidates.length; i++) {
    const raw = candidates[i];
    const idea = normalized[i];
    if (!idea?.title || !idea?.details) {
      skipped += 1;
      continue;
    }

    const docId = stableId(raw.externalId);
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
      seedSource: "research_ideas_sync",
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
      // Never overwrite an active student claim / engagement counters blindly.
      const patch = {
        ...base,
      };
      // Keep human-edited approval if already reviewed and not sync-owned pending.
      if (data.approvalStatus === "rejected") {
        delete patch.approvalStatus;
      }
      if (data.claimedBy) {
        delete patch.status;
      }
      await ref.set(patch, { merge: true });
      updated += 1;
    }

    await db.collection("idea_ingest_raw").doc(stableId(`raw:${raw.externalId}`)).set(
      {
        status: "published",
        researchIdeaId: docId,
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
} = {}) {
  const db = getFirestore();
  const batchId = `batch_${Date.now()}`;

  const [openalex, rss] = await Promise.all([
    collectOpenAlexCandidates(),
    collectRssCandidates(),
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
    normalized.push(await normalizeCandidate(apiKey, candidates[i]));
    if (apiKey && apiKeyThrottleNeeded(i)) await sleep(400);
  }

  const stats = await upsertIdeas(db, {
    candidates,
    normalized,
    adminUid,
    autoApprove,
    batchId,
  });

  const summary = {
    syncedAt: FieldValue.serverTimestamp(),
    syncedBy: adminUid,
    batchId,
    candidates: candidates.length,
    openalex: openalex.length,
    rss: rss.length,
    imported: stats.imported,
    updated: stats.updated,
    skipped: stats.skipped,
    usedGemini: Boolean(apiKey),
    source: "cloud_function",
  };

  await db.doc("app_meta/research_ideas_sync").set(summary, { merge: true });

  return {
    batchId,
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
      return runResearchIdeasSync({
        adminUid: request.auth.uid,
        apiKey: geminiApiKey.value(),
        autoApprove,
      });
    },
  );

  return { researchIdeasSyncWeekly, researchIdeasSyncNow };
}

module.exports = {
  createResearchIdeasSyncHandlers,
  runResearchIdeasSync,
};
