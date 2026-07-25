const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { initializeApp } = require("firebase-admin/app");
const crypto = require("crypto");
const { createOriginalityHandlers } = require("./originality");
const { createPublishExtractHandler } = require("./publish_extract");
const { createScienceNewsRssHandler } = require("./science_news_rss");
const { createCitationProxyHandler } = require("./citation_proxy");
const { createResearchRoomHandlers } = require("./research_rooms");
const { createJournalGuidelinesHandlers } = require("./journal_guidelines");
const { createStoreSuppliersSyncHandlers } = require("./store_suppliers_sync");

initializeApp();

const { originalityCheck, originalityCheckHttp, copyleaksWebhook } = createOriginalityHandlers();
exports.originalityCheck = originalityCheck;
exports.originalityCheckHttp = originalityCheckHttp;
exports.copyleaksWebhook = copyleaksWebhook;
exports.publishExtractReferencesHttp = createPublishExtractHandler();
exports.scienceNewsRssHttp = createScienceNewsRssHandler();
exports.citationLookupHttp = createCitationProxyHandler();

const { createResearchRoom, joinResearchRoom } = createResearchRoomHandlers();
exports.createResearchRoom = createResearchRoom;
exports.joinResearchRoom = joinResearchRoom;

const geminiApiKey = defineSecret("GEMINI_API_KEY");

const {
  journalGuidelinesExtract,
  journalGuidelinesExtractHttp,
} = createJournalGuidelinesHandlers(geminiApiKey);
exports.journalGuidelinesExtract = journalGuidelinesExtract;
exports.journalGuidelinesExtractHttp = journalGuidelinesExtractHttp;

const {
  storeSuppliersSyncWeekly,
  storeSuppliersSyncNow,
} = createStoreSuppliersSyncHandlers();
exports.storeSuppliersSyncWeekly = storeSuppliersSyncWeekly;
exports.storeSuppliersSyncNow = storeSuppliersSyncNow;

// Paymob loads defineSecret() — if secrets are unset, ANY functions deploy fails.
// Keep false until: firebase functions:secrets:set PAYMOB_* then set true and redeploy.
const ENABLE_PAYMOB = process.env.ENABLE_PAYMOB === "true";
if (ENABLE_PAYMOB) {
  const { createPaymobHandlers } = require("./paymob");
  const {
    createPaymobCheckout,
    paymobWebhook,
    confirmEscrowRelease,
  } = createPaymobHandlers();
  exports.createPaymobCheckout = createPaymobCheckout;
  exports.paymobWebhook = paymobWebhook;
  exports.confirmEscrowRelease = confirmEscrowRelease;
}

const NOTIFICATION_TYPES = new Set([
  "general",
  "store_order",
  "payment_held",
  "payment_released",
  "payment_refunded",
  "research_room_reply",
  "research_discussion_reply",
  "writing_order",
  "supervision_request",
  "sample_analysis",
  "sample_analysis_sla",
  "lab_booking",
  "lab_claim",
  "message",
  "smart_match",
  "fund_award",
  "proposal",
]);

/** Create in-app notifications (client cannot write notifications collection). */
exports.sendAppNotification = onCall(
  {
    cors: true,
    // Gen2 default compute SA often lacks Firestore write; App Engine SA has it.
    serviceAccount: "acadegate-new@appspot.gserviceaccount.com",
  },
  async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required");
  }

  const data = request.data || {};
  const userId = String(data.userId || "").trim();
  const title = String(data.title || "").trim();
  const body = String(data.body || "").trim();
  const type = String(data.type || "general").trim();
  const contextId = String(data.contextId || "").trim();
  const contextType = String(data.contextType || "").trim();

  if (!userId || title.length < 1 || body.length < 1) {
    throw new HttpsError("invalid-argument", "userId, title, and body required");
  }
  if (title.length > 200 || body.length > 500) {
    throw new HttpsError("invalid-argument", "title/body too long");
  }
  if (!NOTIFICATION_TYPES.has(type)) {
    throw new HttpsError("invalid-argument", "Invalid notification type");
  }

  const db = getFirestore();
  await db.collection("notifications").add({
    userId,
    title,
    body,
    type,
    senderId: request.auth.uid,
    read: false,
    ...(contextId ? { contextId } : {}),
    ...(contextType ? { contextType } : {}),
    createdAt: FieldValue.serverTimestamp(),
  });

  return { ok: true };
});

const MODELS = [
  "gemini-2.5-flash",
  "gemini-2.0-flash",
  "gemini-2.5-pro",
  "gemini-2.0-flash-lite",
  "gemini-1.5-flash",
  "gemini-flash-latest",
];

function extractResponseText(data) {
  const candidates = data?.candidates;
  if (!Array.isArray(candidates) || candidates.length === 0) return null;

  const parts = candidates[0]?.content?.parts;
  if (!Array.isArray(parts) || parts.length === 0) return null;

  const chunks = [];
  for (const part of parts) {
    const text = part?.text?.trim();
    if (text) chunks.push(text);
  }
  return chunks.length > 0 ? chunks.join("\n") : null;
}

function hashPassword(password) {
  return crypto.createHash("sha256").update(String(password).trim()).digest("hex");
}

function formatGeminiApiError(status, errBody) {
  const body = String(errBody || "");
  const lower = body.toLowerCase();
  if (
    status === 429 ||
    lower.includes("resource_exhausted") ||
    lower.includes("prepayment credits") ||
    lower.includes("quota")
  ) {
    return (
      "انتهى رصيد Gemini API المرتبط بالمفتاح السحابي. " +
      "أضف رصيداً من Google AI Studio ثم أعد المحاولة: https://aistudio.google.com/apikey"
    );
  }
  if (status === 403 || lower.includes("api key not valid")) {
    return "مفتاح Gemini API غير صالح أو محظور. راجع المفتاح في Firebase Secrets.";
  }
  try {
    const parsed = JSON.parse(body);
    const message = parsed?.error?.message;
    if (message) return String(message);
  } catch (_) {}
  return body.length > 240 ? `${body.slice(0, 240)}...` : body;
}

exports.geminiAdvisor = onCall(
  {
    secrets: [geminiApiKey],
    timeoutSeconds: 180,
    memory: "1GiB",
    cors: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "يجب تسجيل الدخول لاستخدام المساعد الذكي");
    }

    const {
      systemPrompt,
      userMessage,
      history = [],
      attachments = [],
      maxOutputTokens = 8192,
    } = request.data || {};

    if (
      (typeof userMessage !== "string" || !userMessage.trim()) &&
      (!Array.isArray(attachments) || attachments.length === 0)
    ) {
      throw new HttpsError("invalid-argument", "userMessage أو مرفقات مطلوبة");
    }

    const cappedTokens = Math.min(Math.max(Number(maxOutputTokens) || 4096, 256), 8192);

    const apiKey = geminiApiKey.value();
    if (!apiKey) {
      throw new HttpsError(
        "failed-precondition",
        "GEMINI_API_KEY غير مضبوط في Firebase Functions",
      );
    }

    const contents = [];
    for (const item of history) {
      if (!item || !item.text) continue;
      contents.push({
        role: item.role === "assistant" ? "model" : "user",
        parts: [{ text: item.text }],
      });
    }
    const userParts = [];
    const trimmedMessage = typeof userMessage === "string" ? userMessage.trim() : "";
    if (trimmedMessage.length > 0) {
      userParts.push({ text: trimmedMessage });
    }

    if (Array.isArray(attachments)) {
      const { getStorage } = require("firebase-admin/storage");
      const bucket = getStorage().bucket();
      const uid = request.auth.uid;

      for (const attachment of attachments) {
        if (!attachment || typeof attachment !== "object") continue;
        const mimeType = attachment.mimeType || attachment.mime_type;
        let base64Data = attachment.base64Data || attachment.base64_data;
        const storagePath = attachment.storagePath || attachment.storage_path;

        if ((!base64Data || !String(base64Data).trim()) && storagePath) {
          const path = String(storagePath).replace(/^\/+/, "");
          if (!path.startsWith(`uploads/${uid}/`)) {
            throw new HttpsError(
              "permission-denied",
              "مسار الملف غير مسموح",
            );
          }
          try {
            const [buf] = await bucket.file(path).download();
            base64Data = buf.toString("base64");
          } catch (err) {
            throw new HttpsError(
              "not-found",
              `تعذر قراءة الملف من Storage: ${err.message || err}`,
            );
          }
        }

        if (!mimeType || !base64Data) continue;
        userParts.push({
          inline_data: {
            mime_type: String(mimeType),
            data: String(base64Data),
          },
        });
      }
    }

    if (userParts.length === 0) {
      userParts.push({
        text: attachments.length > 0
          ? "حلّل الملفات المرفقة وأجب بالعربية."
          : userMessage,
      });
    } else if (attachments.length > 0 && trimmedMessage.length === 0) {
      userParts.unshift({
        text: "حلّل الملفات المرفقة وأجب بالعربية.",
      });
    }

    contents.push({ role: "user", parts: userParts });

    let lastError = "unknown";
    for (const model of MODELS) {
      try {
        const url =
          `https://generativelanguage.googleapis.com/v1beta/models/${model}` +
          `:generateContent?key=${apiKey}`;

        const response = await fetch(url, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            system_instruction: {
              parts: [{ text: systemPrompt || "أنت مساعد أكاديمي." }],
            },
            contents,
            generationConfig: {
              temperature: 0.85,
              maxOutputTokens: cappedTokens,
              thinkingConfig: { thinkingBudget: 0 },
            },
          }),
        });

        if (!response.ok) {
          const errBody = await response.text();
          lastError = `${model}: ${formatGeminiApiError(response.status, errBody)}`;
          if (response.status === 429) break;
          continue;
        }

        const data = await response.json();
        const text = extractResponseText(data);
        if (text) {
          return { text, model };
        }
        lastError = `${model}: empty response`;
      } catch (err) {
        lastError = `${model}: ${err.message}`;
      }
    }

    return { error: lastError };
  },
);
