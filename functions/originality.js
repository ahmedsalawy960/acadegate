const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const crypto = require("crypto");
const mammoth = require("mammoth");
const pdfParse = require("pdf-parse");

const copyleaksEmail = defineSecret("COPYLEAKS_EMAIL");
const copyleaksApiKey = defineSecret("COPYLEAKS_API_KEY");
const plagiarismCheckToken = defineSecret("PLAGIARISMCHECK_API_TOKEN");
const copyleaksWebhookSecret = defineSecret("COPYLEAKS_WEBHOOK_SECRET");

const COPYLEAKS_LOGIN_URL = "https://id.copyleaks.com/v3/account/login/api";
const COPYLEAKS_API_BASE = "https://api.copyleaks.com/v3";
const PLAGIARISMCHECK_BASE = "https://plagiarismcheck.org/api/v1";
const PROJECT_ID = process.env.GCLOUD_PROJECT || "acadegate-new";
const FUNCTIONS_REGION = process.env.FUNCTION_REGION || "us-central1";
const FUNCTIONS_SERVICE_ACCOUNT = `${PROJECT_ID}@appspot.gserviceaccount.com`;

function normalizePlagiarismCheckToken(raw) {
  const trimmed = String(raw || "").trim();
  if (!trimmed || trimmed.toLowerCase() === "none") {
    return null;
  }
  const ascii = trimmed.replace(/[^\x21-\x7E]/g, "");
  if (ascii.length < 10) {
    return null;
  }
  return ascii;
}

function requirePlagiarismCheckToken(raw) {
  const token = normalizePlagiarismCheckToken(raw);
  if (!token) {
    throw new HttpsError(
      "failed-precondition",
      "PLAGIARISMCHECK_API_TOKEN invalid — set ASCII token from plagiarismcheck.org",
    );
  }
  return token;
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function randomSuffix() {
  return crypto.randomBytes(4).toString("hex");
}

/** Copyleaks scanId: 3–36 chars, [a-z0-9] and limited punctuation only. */
function createCopyleaksScanId() {
  return crypto.randomBytes(16).toString("hex");
}

async function copyleaksLogin(email, apiKey) {
  const response = await fetch(COPYLEAKS_LOGIN_URL, {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ email, key: apiKey }),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new HttpsError(
      "failed-precondition",
      `Copyleaks login failed: ${response.status} ${body}`,
    );
  }

  const data = await response.json();
  if (!data.access_token) {
    throw new HttpsError("failed-precondition", "Copyleaks login: no access token");
  }
  return data.access_token;
}

function copyleaksWebhookUrl(scanId, webhookSecret) {
  const token = String(webhookSecret || "").trim();
  let url =
    `https://${FUNCTIONS_REGION}-${PROJECT_ID}.cloudfunctions.net/copyleaksWebhook` +
    `?scanId=${encodeURIComponent(scanId)}&event={STATUS}`;
  if (token) {
    url += `&token=${encodeURIComponent(token)}`;
  }
  return url;
}

function parseCopyleaksCompleted(payload) {
  const score = payload?.results?.score?.aggregatedScore
    ?? payload?.score?.aggregatedScore
    ?? 0;

  const buckets = [
    ...(payload?.results?.internet || []),
    ...(payload?.results?.database || []),
    ...(payload?.results?.batch || []),
    ...(payload?.results?.repositories || []),
  ];

  const sources = buckets.slice(0, 30).map((item) => ({
    title: item.title || item.metadata?.filename || "Source",
    url: item.metadata?.finalUrl || item.metadata?.canonicalUrl || "",
    matchedWords: item.matchedWords || 0,
    percent: item.matchedWords && payload?.scannedDocument?.totalWords
      ? Math.round((item.matchedWords / payload.scannedDocument.totalWords) * 100)
      : null,
  }));

  return {
    similarityPercent: Math.round(Number(score) * 100) / 100,
    totalWords: payload?.scannedDocument?.totalWords || null,
    sourceCount: buckets.length,
    sources,
    provider: "copyleaks",
  };
}

async function waitForCopyleaksScan(db, scanId, timeoutMs = 180000) {
  const ref = db.collection("originality_scans").doc(scanId);
  const started = Date.now();

  while (Date.now() - started < timeoutMs) {
    const snap = await ref.get();
    if (!snap.exists) {
      await sleep(2500);
      continue;
    }

    const data = snap.data();
    const event = data?.event || data?.status;

    if (event === "error") {
      const message = data?.payload?.error?.message
        || data?.payload?.message
        || "Copyleaks scan failed";
      throw new HttpsError("internal", message);
    }

    if (event === "completed" && data?.payload) {
      return parseCopyleaksCompleted(data.payload);
    }

    await sleep(2500);
  }

  throw new HttpsError(
    "deadline-exceeded",
    "Copyleaks scan timed out — try a shorter document or retry later",
  );
}

async function runCopyleaksScan({
  db,
  uid,
  text,
  base64,
  filename,
  email,
  apiKey,
  webhookSecret,
}) {
  const scanId = createCopyleaksScanId();
  const token = await copyleaksLogin(email, apiKey);
  const secret = String(webhookSecret || "").trim();
  if (!secret) {
    throw new HttpsError(
      "failed-precondition",
      "COPYLEAKS_WEBHOOK_SECRET not configured in Firebase Functions",
    );
  }

  await db.collection("originality_scans").doc(scanId).set({
    uid,
    provider: "copyleaks",
    status: "pending",
    createdAt: FieldValue.serverTimestamp(),
  });

  const body = {
    properties: {
      webhooks: {
        status: copyleaksWebhookUrl(scanId, secret),
      },
      sandbox: false,
    },
  };

  if (base64 && filename) {
    body.base64 = base64;
    body.filename = filename;
  } else if (text) {
    body.base64 = Buffer.from(text, "utf8").toString("base64");
    body.filename = "document.txt";
  } else {
    throw new HttpsError("invalid-argument", "text or base64 file required");
  }

  const submitUrl = `${COPYLEAKS_API_BASE}/scans/submit/file/${scanId}`;
  const submitResponse = await fetch(submitUrl, {
    method: "PUT",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  if (!submitResponse.ok) {
    const errBody = await submitResponse.text();
    throw new HttpsError(
      "failed-precondition",
      `Copyleaks submit failed: ${submitResponse.status} ${errBody}`,
    );
  }

  const result = await waitForCopyleaksScan(db, scanId);
  return { scanId, ...result };
}

function fileExtension(filename) {
  const parts = String(filename || "").trim().toLowerCase().split(".");
  return parts.length > 1 ? parts.pop() : "";
}

async function extractDocumentText(buffer, filename) {
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
    case "rtf":
      return buffer
        .toString("utf8")
        .replace(/\\[a-z]+\d* ?/gi, " ")
        .replace(/[{}]/g, " ")
        .replace(/\s+/g, " ")
        .trim();
    default:
      throw new HttpsError(
        "invalid-argument",
        `Unsupported file type for text extraction: .${ext || "unknown"}`,
      );
  }
}

function parsePlagiarismCheckReport(reportJson, statusJson) {
  const percent = Number(
    reportJson?.data?.report?.percent
      ?? statusJson?.data?.report?.percent
      ?? 0,
  );

  const rawSources = reportJson?.data?.report_data?.sources || [];
  const sources = rawSources.slice(0, 30).map((src) => ({
    title: src.title || src.url || "Source",
    url: src.url || "",
    matchedWords: null,
    percent: src.percent != null ? Number(src.percent) : null,
  }));

  return {
    similarityPercent: Math.round(percent * 100) / 100,
    totalWords: reportJson?.data?.report_data?.length || statusJson?.data?.words || null,
    sourceCount: reportJson?.data?.report?.source_count
      ?? statusJson?.data?.report?.source_count
      ?? sources.length,
    sources,
    provider: "plagiarismcheck",
  };
}

async function runPlagiarismCheckScan({ text, base64, filename, token, language }) {
  const apiToken = requirePlagiarismCheckToken(token);

  let content = String(text || "").trim();

  if (base64 && filename) {
    const buffer = Buffer.from(base64, "base64");
    content = await extractDocumentText(buffer, filename.trim());
    if (!content) {
      throw new HttpsError(
        "invalid-argument",
        "Could not extract text from file — try DOCX, PDF, or TXT",
      );
    }
  }

  if (content.length < 80) {
    throw new HttpsError(
      "invalid-argument",
      "PlagiarismCheck requires at least 80 characters of extractable text",
    );
  }

  if (content.length > 500000) {
    content = content.slice(0, 500000);
  }

  const form = new URLSearchParams();
  form.append("language", language || "en");
  form.append("text", content);

  const submitResponse = await fetch(`${PLAGIARISMCHECK_BASE}/text`, {
    method: "POST",
    headers: {
      "X-API-TOKEN": apiToken,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: form,
  });

  const submitJson = await submitResponse.json();
  if (!submitResponse.ok || !submitJson?.success) {
    const message = submitJson?.message || `PlagiarismCheck submit failed: ${submitResponse.status}`;
    throw new HttpsError("failed-precondition", message);
  }

  const textId = submitJson.data?.text?.id;

  if (!textId) {
    throw new HttpsError("internal", "PlagiarismCheck: missing text id");
  }

  let statusJson = null;
  for (let attempt = 0; attempt < 60; attempt++) {
    const statusResponse = await fetch(`${PLAGIARISMCHECK_BASE}/text/${textId}`, {
      method: "GET",
      headers: { "X-API-TOKEN": apiToken },
    });
    statusJson = await statusResponse.json();

    const state = statusJson?.data?.state;
    if (state === 5) break;
    if (state === 4) {
      throw new HttpsError("internal", "PlagiarismCheck scan failed");
    }
    await sleep(3000);
  }

  if (statusJson?.data?.state !== 5) {
    throw new HttpsError(
      "deadline-exceeded",
      "PlagiarismCheck scan timed out — try again later",
    );
  }

  const reportResponse = await fetch(`${PLAGIARISMCHECK_BASE}/text/report/${textId}`, {
    method: "GET",
    headers: { "X-API-TOKEN": apiToken },
  });
  const reportJson = await reportResponse.json();

  if (!reportResponse.ok) {
    throw new HttpsError(
      "internal",
      reportJson?.message || "PlagiarismCheck report fetch failed",
    );
  }

  const result = parsePlagiarismCheckReport(reportJson, statusJson);
  return { scanId: String(textId), ...result };
}

function resolveProvider(requested, hasCopyleaks, hasPlagiarismCheck) {
  const normalized = String(requested || "auto").toLowerCase();
  if (normalized === "copyleaks") return hasCopyleaks ? "copyleaks" : null;
  if (normalized === "plagiarismcheck" || normalized === "plagiarism_check") {
    return hasPlagiarismCheck ? "plagiarismcheck" : null;
  }

  if (hasCopyleaks) return "copyleaks";
  if (hasPlagiarismCheck) return "plagiarismcheck";
  return null;
}

const { createOriginalityHandlers: buildHandlers } = require("./originality_handlers");

function createOriginalityHandlers() {
  return buildHandlers({
    onCall,
    onRequest,
    HttpsError,
    getAuth,
    getFirestore,
    FieldValue,
    copyleaksEmail,
    copyleaksApiKey,
    plagiarismCheckToken,
    copyleaksWebhookSecret,
    resolveProvider,
    runCopyleaksScan,
    runPlagiarismCheckScan,
    functionsServiceAccount: FUNCTIONS_SERVICE_ACCOUNT,
    normalizePlagiarismCheckToken,
    requirePlagiarismCheckToken,
  });
}

module.exports = { createOriginalityHandlers };
