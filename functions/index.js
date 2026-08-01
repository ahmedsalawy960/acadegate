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

/** Types that may only target the authenticated caller (no cross-user spoofing). */
const SELF_ONLY_NOTIFICATION_TYPES = new Set([
  "general",
  "sample_analysis_sla",
  "smart_match",
]);

/** Ops types that any signed-in user may send to accounts with role=admin. */
const ADMIN_FANOUT_TYPES = new Set([
  "sample_analysis",
  "lab_booking",
  "lab_claim",
]);

async function userHasAdminRole(db, uid) {
  const snap = await db.collection("users").doc(uid).get();
  return snap.exists && String(snap.data()?.role || "") === "admin";
}

function partiesInclude(parties, uid) {
  return parties.map(String).includes(String(uid));
}

/** contextId format: "serviceId:orderId" */
async function loadWritingOrder(db, contextId) {
  if (!contextId || !contextId.includes(":")) return null;
  const sep = contextId.indexOf(":");
  const serviceId = contextId.slice(0, sep);
  const orderId = contextId.slice(sep + 1);
  if (!serviceId || !orderId) return null;
  const order = await db
    .collection("writing_services")
    .doc(serviceId)
    .collection("writing_orders")
    .doc(orderId)
    .get();
  return order.exists ? order : null;
}

function assertWritingOrderParties(orderSnap, senderUid, targetUid) {
  const d = orderSnap.data() || {};
  const parties = [d.userId, d.serviceOwnerId];
  if (
    !partiesInclude(parties, senderUid) ||
    !partiesInclude(parties, targetUid)
  ) {
    throw new HttpsError(
      "permission-denied",
      "Not a party on this writing order",
    );
  }
}

/**
 * Cross-user notifications require a verified relationship.
 * Self-notify is always allowed. Arbitrary targeting is denied.
 */
async function assertCanNotify(
  db,
  senderUid,
  targetUid,
  type,
  contextId,
  contextType,
) {
  if (senderUid === targetUid) return;

  if (SELF_ONLY_NOTIFICATION_TYPES.has(type)) {
    throw new HttpsError(
      "permission-denied",
      "This notification type can only target the authenticated user",
    );
  }

  if (
    ADMIN_FANOUT_TYPES.has(type) &&
    (await userHasAdminRole(db, targetUid))
  ) {
    return;
  }

  switch (type) {
    case "message": {
      if (!contextId) {
        throw new HttpsError(
          "invalid-argument",
          "contextId (conversation) required for message notifications",
        );
      }
      const conv = await db.collection("conversations").doc(contextId).get();
      if (!conv.exists) {
        throw new HttpsError("permission-denied", "Conversation not found");
      }
      const ids = conv.data()?.participantIds || [];
      if (!partiesInclude(ids, senderUid) || !partiesInclude(ids, targetUid)) {
        throw new HttpsError(
          "permission-denied",
          "Not a participant in this conversation",
        );
      }
      return;
    }

    case "store_order":
    case "payment_held":
    case "payment_released":
    case "payment_refunded": {
      if (contextType === "store_order" && contextId) {
        const order = await db.collection("store_orders").doc(contextId).get();
        if (!order.exists) {
          throw new HttpsError("permission-denied", "Store order not found");
        }
        const d = order.data() || {};
        const parties = [d.buyerId, d.sellerId];
        if (
          !partiesInclude(parties, senderUid) ||
          !partiesInclude(parties, targetUid)
        ) {
          throw new HttpsError(
            "permission-denied",
            "Not a party on this store order",
          );
        }
        return;
      }
      if (contextType === "writing_order") {
        const order = await loadWritingOrder(db, contextId);
        if (!order) {
          throw new HttpsError("permission-denied", "Writing order not found");
        }
        assertWritingOrderParties(order, senderUid, targetUid);
        return;
      }
      throw new HttpsError(
        "invalid-argument",
        "contextType/contextId required for payment notifications",
      );
    }

    case "writing_order": {
      if (contextType !== "writing_order") {
        throw new HttpsError(
          "invalid-argument",
          "contextType must be writing_order",
        );
      }
      const order = await loadWritingOrder(db, contextId);
      if (!order) {
        throw new HttpsError("permission-denied", "Writing order not found");
      }
      assertWritingOrderParties(order, senderUid, targetUid);
      return;
    }

    case "supervision_request": {
      if (!contextId) {
        throw new HttpsError(
          "invalid-argument",
          "contextId required for supervision_request",
        );
      }
      const req = await db
        .collection("supervision_requests")
        .doc(contextId)
        .get();
      if (!req.exists) {
        throw new HttpsError("permission-denied", "Supervision request not found");
      }
      const d = req.data() || {};
      if (
        String(d.studentId) !== senderUid ||
        String(d.supervisorOwnerId) !== targetUid
      ) {
        throw new HttpsError(
          "permission-denied",
          "Not authorized for this supervision notification",
        );
      }
      return;
    }

    case "sample_analysis":
    case "lab_booking":
    case "lab_claim": {
      if (contextType !== "lab" || !contextId) {
        throw new HttpsError(
          "invalid-argument",
          "contextType=lab and contextId required",
        );
      }
      const lab = await db.collection("labs").doc(contextId).get();
      if (!lab.exists) {
        throw new HttpsError("permission-denied", "Lab not found");
      }
      const ownerId = String(lab.data()?.ownerId || "");
      if (ownerId && ownerId !== targetUid) {
        throw new HttpsError(
          "permission-denied",
          "Target is not the lab owner",
        );
      }
      if (!ownerId && !(await userHasAdminRole(db, targetUid))) {
        throw new HttpsError(
          "permission-denied",
          "Unowned lab notifications must target an admin",
        );
      }
      return;
    }

    case "research_room_reply":
    case "research_discussion_reply": {
      if (contextType !== "research_room" || !contextId) {
        throw new HttpsError(
          "invalid-argument",
          "contextType=research_room and contextId required",
        );
      }
      const member = await db
        .collection("research_rooms")
        .doc(contextId)
        .collection("members")
        .doc(senderUid)
        .get();
      const room = await db.collection("research_rooms").doc(contextId).get();
      if (!room.exists) {
        throw new HttpsError("permission-denied", "Research room not found");
      }
      const creatorId = String(room.data()?.creatorId || "");
      const isMember = member.exists || creatorId === senderUid;
      if (!isMember) {
        throw new HttpsError(
          "permission-denied",
          "Not a member of this research room",
        );
      }
      if (targetUid !== creatorId) {
        // Allow notifying discussion author only if they are also a member/creator
        const targetMember = await db
          .collection("research_rooms")
          .doc(contextId)
          .collection("members")
          .doc(targetUid)
          .get();
        if (!targetMember.exists && targetUid !== creatorId) {
          throw new HttpsError(
            "permission-denied",
            "Target is not in this research room",
          );
        }
      }
      return;
    }

    case "fund_award": {
      if (!(await userHasAdminRole(db, senderUid))) {
        throw new HttpsError(
          "permission-denied",
          "Only admins can send fund_award notifications",
        );
      }
      return;
    }

    case "proposal": {
      if (contextType !== "research_idea" || !contextId) {
        throw new HttpsError(
          "invalid-argument",
          "contextType=research_idea and contextId required",
        );
      }
      const idea = await db.collection("research_ideas").doc(contextId).get();
      if (!idea.exists) {
        throw new HttpsError("permission-denied", "Research idea not found");
      }
      const publisherId = String(idea.data()?.publisherId || "");
      if (publisherId !== targetUid && publisherId !== senderUid) {
        // Sender proposes to publisher, or publisher notifies proposer
        const ok =
          (senderUid !== targetUid && publisherId === targetUid) ||
          (publisherId === senderUid);
        if (!ok) {
          throw new HttpsError(
            "permission-denied",
            "Not authorized for this proposal notification",
          );
        }
      }
      return;
    }

    default:
      throw new HttpsError(
        "permission-denied",
        "Cross-user notification not allowed for this type",
      );
  }
}

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
  const senderUid = request.auth.uid;

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
  await assertCanNotify(db, senderUid, userId, type, contextId, contextType);

  await db.collection("notifications").add({
    userId,
    title,
    body,
    type,
    senderId: senderUid,
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
