/**
 * Academic Assistant: one Gemini round per call, streamed to the client.
 *
 * The app runs the tool loop (it owns the catalog / drafts / reference
 * services): each call returns either final text or functionCall parts, and
 * the app calls again with functionResponse parts under the same turnId.
 * Quota is charged once per turn; a turn allows MAX_ROUNDS calls.
 */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { consumeQuota, quotaExceededHttpsError } = require("./usage_quota");

const geminiApiKey = defineSecret("GEMINI_API_KEY");

const PRO_MODEL = "gemini-3.1-pro-preview";
const DEEP_MODELS = [PRO_MODEL, "gemini-3.6-flash", "gemini-3-flash-preview", "gemini-2.5-pro"];
const FAST_MODELS = [
  "gemini-2.5-flash",
  "gemini-3.1-flash-lite",
  "gemini-3-flash-preview",
  "gemini-3.6-flash",
];
const LEGACY_THINKING = new Set(["gemini-2.5-flash", "gemini-2.5-pro"]);

const MAX_ROUNDS = 6;
const TURN_TTL_MS = 15 * 60 * 1000;
const MAX_CONTENTS = 80;
const MAX_PAYLOAD_CHARS = 900000;
const MAX_TOOLS = 16;
const ALLOWED_PART_KEYS = ["text", "functionCall", "functionResponse", "thoughtSignature"];

function db() {
  return getFirestore();
}

function sanitizeContents(raw) {
  if (!Array.isArray(raw) || raw.length === 0) {
    throw new HttpsError("invalid-argument", "contents مطلوبة");
  }
  if (raw.length > MAX_CONTENTS) {
    throw new HttpsError("invalid-argument", "المحادثة أطول من المسموح");
  }
  const out = [];
  for (const item of raw) {
    if (!item || typeof item !== "object") continue;
    const role = item.role === "model" ? "model" : "user";
    const parts = [];
    for (const p of Array.isArray(item.parts) ? item.parts : []) {
      if (!p || typeof p !== "object") continue;
      const clean = {};
      for (const key of ALLOWED_PART_KEYS) {
        if (p[key] !== undefined && p[key] !== null) clean[key] = p[key];
      }
      if (Object.keys(clean).length > 0) parts.push(clean);
    }
    if (parts.length > 0) out.push({ role, parts });
  }
  if (out.length === 0) throw new HttpsError("invalid-argument", "contents فارغة");
  return out;
}

async function resolveAttachmentParts(attachments, uid) {
  if (!Array.isArray(attachments) || attachments.length === 0) return [];
  const mimeByExt = {
    png: "image/png",
    jpg: "image/jpeg",
    jpeg: "image/jpeg",
    webp: "image/webp",
    gif: "image/gif",
    heic: "image/heic",
    heif: "image/heif",
    pdf: "application/pdf",
    doc: "application/msword",
    docx: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    odt: "application/vnd.oasis.opendocument.text",
    xls: "application/vnd.ms-excel",
    xlsx: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    ods: "application/vnd.oasis.opendocument.spreadsheet",
    ppt: "application/vnd.ms-powerpoint",
    pptx: "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    odp: "application/vnd.oasis.opendocument.presentation",
    txt: "text/plain",
    md: "text/markdown",
    csv: "text/csv",
    tsv: "text/tab-separated-values",
    json: "application/json",
    rtf: "application/rtf",
    tex: "text/plain",
    bib: "text/plain",
    r: "text/plain",
    py: "text/plain",
    ipynb: "text/plain",
  };
  const officeExts = new Set(["pdf", "doc", "docx", "odt", "xls", "xlsx", "ods", "ppt", "pptx", "odp"]);
  const textExts = new Set(["txt", "md", "csv", "tsv", "json", "rtf", "tex", "bib", "r", "py", "ipynb"]);
  const maxImageText = 10 * 1024 * 1024;
  const maxOffice = 20 * 1024 * 1024;
  const maxMessage = 30 * 1024 * 1024;
  const maxBase64Text = 14 * 1024 * 1024;

  function extensionOf(name) {
    const base = String(name || "").split(/[/\\]/).pop() || "";
    const dot = base.lastIndexOf(".");
    if (dot < 0 || dot === base.length - 1) return "";
    return base.slice(dot + 1).toLowerCase();
  }

  function sizeLimit(ext) {
    return officeExts.has(ext) ? maxOffice : maxImageText;
  }

  function startsWithBytes(buf, hex) {
    const sig = Buffer.from(hex, "hex");
    return buf.length >= sig.length && buf.subarray(0, sig.length).equals(sig);
  }

  function assertFileBytes(ext, buf) {
    if (!Buffer.isBuffer(buf) || buf.length === 0 || buf.length > sizeLimit(ext)) {
      throw new HttpsError("invalid-argument", "حجم الملف يتجاوز الحد المسموح");
    }
    const zipOffice = new Set(["docx", "xlsx", "pptx", "odt", "ods", "odp"]);
    const oleOffice = new Set(["doc", "xls", "ppt"]);
    let ok = false;
    if (ext === "pdf") ok = buf.subarray(0, 4).toString("ascii") === "%PDF";
    else if (zipOffice.has(ext)) ok = buf.subarray(0, 2).toString("ascii") === "PK";
    else if (oleOffice.has(ext)) ok = startsWithBytes(buf, "d0cf11e0");
    else if (ext === "png") ok = startsWithBytes(buf, "89504e47");
    else if (ext === "jpg" || ext === "jpeg") ok = startsWithBytes(buf, "ffd8ff");
    else if (ext === "gif") {
      const head = buf.subarray(0, 6).toString("ascii");
      ok = head === "GIF87a" || head === "GIF89a";
    } else if (ext === "webp") {
      ok = buf.length >= 12
        && buf.subarray(0, 4).toString("ascii") === "RIFF"
        && buf.subarray(8, 12).toString("ascii") === "WEBP";
    } else if (ext === "heic" || ext === "heif") {
      const brand = buf.length >= 12 ? buf.subarray(8, 12).toString("ascii") : "";
      ok = buf.length >= 12
        && buf.subarray(4, 8).toString("ascii") === "ftyp"
        && ["heic", "heix", "hevc", "heif", "heim", "heis", "mif1", "msf1"].includes(brand);
    } else if (textExts.has(ext)) {
      const binary = startsWithBytes(buf, "4d5a")
        || startsWithBytes(buf, "504b")
        || startsWithBytes(buf, "7f454c46")
        || startsWithBytes(buf, "d0cf11e0")
        || buf.subarray(0, 512).includes(0);
      const head = buf.subarray(0, 512).toString("utf8").replace(/^\uFEFF/, "").trim().toLowerCase();
      const markup = /^<(?:!--|!doctype|html|svg|script|head|body|iframe|meta|link|style)\b/.test(head)
        || head.startsWith("<?xml");
      ok = !binary && !markup;
    }
    if (!ok) throw new HttpsError("invalid-argument", "محتوى الملف لا يطابق نوعه");
  }

  const { getStorage } = require("firebase-admin/storage");
  const bucket = getStorage().bucket();
  const parts = [];
  let total = 0;
  for (const a of attachments.slice(0, 8)) {
    if (!a || typeof a !== "object") continue;
    const storagePath = a.storagePath || a.storage_path;
    let buf = null;
    let ext = "";
    if (storagePath) {
      const path = String(storagePath).replace(/\\/g, "/").replace(/^\/+/, "");
      if (path.includes("..") || !path.startsWith(`uploads/${uid}/advisor/`)) {
        throw new HttpsError("permission-denied", "مسار الملف غير مسموح");
      }
      ext = extensionOf(path);
      if (!mimeByExt[ext]) throw new HttpsError("invalid-argument", "نوع الملف غير مسموح");
      const file = bucket.file(path);
      const [meta] = await file.getMetadata();
      const size = Number(meta && meta.size);
      if (!Number.isFinite(size) || size <= 0 || size > sizeLimit(ext)) {
        throw new HttpsError("invalid-argument", "حجم الملف يتجاوز الحد المسموح");
      }
      const [downloaded] = await file.download();
      buf = downloaded;
    } else {
      let clean = String(a.base64Data || a.base64_data || "").replace(/\s/g, "");
      const dataUrl = clean.match(/^data:[^;]*;base64,(.+)$/i);
      if (dataUrl) clean = dataUrl[1];
      if (!clean) continue;
      if (clean.length > maxBase64Text) {
        throw new HttpsError("invalid-argument", "المرفق أكبر من الحد المسموح");
      }
      ext = extensionOf(a.fileName || a.file_name || a.name || "");
      if (!mimeByExt[ext]) throw new HttpsError("invalid-argument", "نوع الملف غير مسموح");
      buf = Buffer.from(clean, "base64");
    }
    assertFileBytes(ext, buf);
    total += buf.length;
    if (total > maxMessage) {
      throw new HttpsError("invalid-argument", "إجمالي المرفقات يتجاوز 30 ميجابايت");
    }
    parts.push({ inlineData: { mimeType: mimeByExt[ext], data: buf.toString("base64") } });
  }
  return parts;
}

/** Attach files to the latest user message that has text (not a functionResponse turn). */
function injectAttachments(contents, attachmentParts) {
  if (attachmentParts.length === 0) return;
  for (let i = contents.length - 1; i >= 0; i--) {
    const c = contents[i];
    if (c.role === "user" && c.parts.some((p) => typeof p.text === "string")) {
      c.parts = [...c.parts, ...attachmentParts];
      return;
    }
  }
}

/**
 * Charges quota on the first call of a turn; later calls must reuse the same
 * turnId within TURN_TTL_MS and MAX_ROUNDS.
 */
async function admitRound(uid, turnId) {
  const ref = db().collection("assistant_turns").doc(`${uid}_${turnId}`);
  let snap = null;
  try {
    snap = await ref.get();
  } catch (e) {
    console.error("assistant turn read failed", e.message || e);
  }
  if (!snap || !snap.exists) {
    const quota = await consumeQuota({ uid, kind: "gemini" });
    if (!quota.ok) {
      if (quota.code === "resource-exhausted") throw quotaExceededHttpsError(quota, "gemini");
      throw new HttpsError("unavailable", quota.message || "تعذر التحقق من الحصة اليومية — أعد المحاولة");
    }
    const tier = quota.tier || "free";
    try {
      await ref.set({
        uid,
        tier,
        rounds: 1,
        createdAtMs: Date.now(),
        createdAt: FieldValue.serverTimestamp(),
        expireAt: Timestamp.fromMillis(Date.now() + 24 * 3600 * 1000),
      });
    } catch (e) {
      console.warn("assistant turn save failed", e.message || e);
    }
    return { tier };
  }

  return db().runTransaction(async (tx) => {
    const fresh = await tx.get(ref);
    const d = fresh.data() || {};
    if (d.uid !== uid) throw new HttpsError("permission-denied", "جلسة غير صالحة");
    if (Date.now() - Number(d.createdAtMs || 0) > TURN_TTL_MS) {
      throw new HttpsError("deadline-exceeded", "انتهت مهلة هذا الطلب — أرسل سؤالك مرة أخرى");
    }
    const rounds = Number(d.rounds || 0);
    if (rounds >= MAX_ROUNDS) {
      throw new HttpsError("resource-exhausted", "تجاوز الطلب الحد الأقصى لخطوات البحث");
    }
    tx.update(ref, { rounds: rounds + 1 });
    return { tier: d.tier || "free" };
  });
}

function generationConfigFor(model, { deep, hasMedia }) {
  const config = { maxOutputTokens: deep ? 16384 : 8192 };
  if (LEGACY_THINKING.has(model)) {
    config.temperature = 0.5;
    if (!hasMedia) config.thinkingConfig = { thinkingBudget: deep ? 4096 : 0 };
  } else if (String(model).startsWith("gemini-3")) {
    // Gemini 3: keep default temperature (Google advises against lowering it).
    if (!hasMedia) config.thinkingConfig = { thinkingLevel: deep ? "high" : "medium" };
  } else {
    config.temperature = 0.5;
  }
  return config;
}

function apiErrorText(status, body) {
  const lower = String(body || "").toLowerCase();
  if (status === 429 || lower.includes("resource_exhausted") || lower.includes("quota")) {
    return "انتهى رصيد Gemini API المرتبط بالمفتاح السحابي مؤقتاً — أعد المحاولة لاحقاً";
  }
  try {
    const msg = JSON.parse(body)?.error?.message;
    if (msg) return String(msg);
  } catch (_) {}
  const s = String(body || "");
  return s.length > 240 ? `${s.slice(0, 240)}…` : s;
}

/** Merge streamed parts: concatenate text runs, keep functionCalls and signatures intact. */
function appendPart(out, part) {
  if (!part || part.thought === true) return;
  const sig = part.thoughtSignature;
  if (part.functionCall) {
    out.push(sig ? { functionCall: part.functionCall, thoughtSignature: sig } : { functionCall: part.functionCall });
    return;
  }
  if (typeof part.text === "string") {
    const last = out[out.length - 1];
    if (last && typeof last.text === "string" && !last.thoughtSignature) {
      last.text += part.text;
      if (sig) last.thoughtSignature = sig;
    } else if (part.text.length > 0 || sig) {
      out.push(sig ? { text: part.text, thoughtSignature: sig } : { text: part.text });
    }
    return;
  }
  if (sig) {
    const last = out[out.length - 1];
    if (last && !last.thoughtSignature) last.thoughtSignature = sig;
    else out.push({ text: "", thoughtSignature: sig });
  }
}

async function streamOnce({ model, apiKey, body, onText }) {
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 25000);
  try {
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
      signal: controller.signal,
    });
    if (!res.ok) {
      const errBody = await res.text();
      return { ok: false, status: res.status, errBody };
    }
    const json = await res.json();
    const parts = [];
    let finishReason = null;
    const blockReason = json?.promptFeedback?.blockReason || null;
    const cand = Array.isArray(json?.candidates) ? json.candidates[0] : null;
    if (cand?.finishReason) finishReason = cand.finishReason;
    let streamedChars = 0;
    for (const p of cand?.content?.parts || []) {
      appendPart(parts, p);
      if (p && p.thought !== true && typeof p.text === "string" && p.text.length > 0) {
        streamedChars += p.text.length;
        onText(p.text);
      }
    }
    return { ok: true, parts, finishReason, blockReason, streamedChars };
  } finally {
    clearTimeout(timer);
  }
}

exports._test = {
  appendPart,
  sanitizeContents,
  injectAttachments,
  streamOnce,
  generationConfigFor,
  resolveAttachmentParts,
};

exports.academicAssistant = onCall(
  {
    secrets: [geminiApiKey],
    timeoutSeconds: 300,
    memory: "1GiB",
    cors: true,
    // Gen2 default compute account cannot read Firestore. Use the app account.
    serviceAccount: "acadegate-new@appspot.gserviceaccount.com",
  },
  async (request, response) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "يجب تسجيل الدخول لاستخدام المساعد الأكاديمي");
    }
    const uid = request.auth.uid;
    const data = request.data || {};

    const turnId = String(data.turnId || "");
    if (!/^[A-Za-z0-9_-]{8,64}$/.test(turnId)) {
      throw new HttpsError("invalid-argument", "turnId غير صالح");
    }
    if (JSON.stringify(data.contents || []).length > MAX_PAYLOAD_CHARS) {
      throw new HttpsError("invalid-argument", "حجم المحادثة كبير جداً — ابدأ محادثة جديدة");
    }
    const contents = sanitizeContents(data.contents);
    const systemPrompt = String(data.systemPrompt || "").slice(0, 40000);
    const tools = (Array.isArray(data.functionDeclarations)
      ? data.functionDeclarations.slice(0, MAX_TOOLS)
      : []
    ).map((tool) => {
      const props = tool?.parameters?.properties;
      if (props && Object.keys(props).length === 0) {
        const copy = { ...tool };
        delete copy.parameters;
        return copy;
      }
      return tool;
    });
    const streaming = request.acceptsStreaming === true;
    if (streaming && response && typeof response.sendChunk === "function") {
      response.sendChunk({ t: "" });
    }
    const toolMode = data.toolMode === "NONE" ? "NONE" : "AUTO";

    const apiKey = geminiApiKey.value();
    if (!apiKey) {
      throw new HttpsError("failed-precondition", "GEMINI_API_KEY غير مضبوط في Firebase Functions");
    }

    let tier = "free";
    try {
      const admitted = await Promise.race([
        admitRound(uid, turnId),
        new Promise((_, reject) => {
          setTimeout(() => reject(new Error("admit-timeout")), 8000);
        }),
      ]);
      tier = admitted.tier || "free";
    } catch (e) {
      console.error("academicAssistant admit skipped", e.message || e);
    }
    console.log("academicAssistant model loop", tier);
    const deep = data.mode === "deep" && (tier === "pro" || tier === "admin");

    const attachmentParts = await resolveAttachmentParts(data.attachments, uid);
    injectAttachments(contents, attachmentParts);
    const hasMedia = attachmentParts.length > 0;

    let sentChars = 0;
    const onText = (t) => {
      sentChars += t.length;
      if (streaming) response.sendChunk({ t });
    };

    const errors = [];
    for (const model of deep ? DEEP_MODELS : FAST_MODELS) {
      console.log("academicAssistant try", model);
      const body = {
        contents,
        generationConfig: generationConfigFor(model, { deep, hasMedia }),
      };
      if (systemPrompt) body.systemInstruction = { parts: [{ text: systemPrompt }] };
      if (tools.length > 0) {
        body.tools = [{ functionDeclarations: tools }];
        body.toolConfig = { functionCallingConfig: { mode: toolMode } };
      }

      let result;
      try {
        result = await streamOnce({ model, apiKey, body, onText });
        if (!result.ok && body.generationConfig.thinkingConfig && /thinking/i.test(result.errBody)) {
          delete body.generationConfig.thinkingConfig;
          result = await streamOnce({ model, apiKey, body, onText });
        }
      } catch (err) {
        const message = err.name === "TimeoutError" || err.name === "AbortError"
          ? "timed out"
          : (err.message || err);
        console.error("academicAssistant model error", model, message);
        errors.push(`${model}: ${message}`);
        if (sentChars > 0) {
          console.error("academicAssistant stream broke mid-answer", errors);
          return { error: "انقطع الاتصال أثناء كتابة الرد — أعد المحاولة", deep, tier };
        }
        continue;
      }

      if (!result.ok) {
        const why = apiErrorText(result.status, result.errBody);
        console.error("academicAssistant model rejected", model, result.status, why.slice(0, 180));
        errors.push(`${model}: ${why}`);
        if (/is not found|not supported/i.test(result.errBody)) continue;
        if (result.status === 429 && errors.filter((e) => e.includes("انتهى رصيد")).length >= 2) break;
        continue;
      }

      const functionCalls = result.parts
        .filter((p) => p.functionCall)
        .map((p) => ({
          id: p.functionCall.id || null,
          name: String(p.functionCall.name || ""),
          args: p.functionCall.args || {},
        }));
      const text = result.parts
        .filter((p) => typeof p.text === "string")
        .map((p) => p.text)
        .join("")
        .trim();

      if (!text && functionCalls.length === 0) {
        const why = result.blockReason || result.finishReason || "empty";
        errors.push(`${model}: رد فارغ (${why})`);
        // Text already streamed to the client cannot be retracted; only retry when nothing was sent.
        if (sentChars === 0) continue;
      }

      return {
        parts: result.parts,
        text,
        functionCalls,
        model,
        deep,
        tier,
        finishReason: result.finishReason || null,
      };
    }

    console.error("academicAssistant models failed", errors);
    const useful =
      errors.find((e) => !/is not found|not supported/i.test(e)) || errors[errors.length - 1] || "";
    if (String(useful).includes("انتهى رصيد")) return { error: useful, deep, tier };
    return {
      error: "تعذر إكمال الرد من خدمة الكتابة. أعد المحاولة بعد قليل.",
      deep,
      tier,
    };
  },
);
