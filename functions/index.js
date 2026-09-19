const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const { initializeApp } = require("firebase-admin/app");
const crypto = require("crypto");
const { createOriginalityHandlers } = require("./originality");
const { createPublishExtractHandler } = require("./publish_extract");
const { createScienceNewsRssHandler } = require("./science_news_rss");
const { createCitationProxyHandler } = require("./citation_proxy");
const { createResearchRoomHandlers } = require("./research_rooms");
const { createJournalGuidelinesHandlers } = require("./journal_guidelines");
const { createStoreSuppliersSyncHandlers } = require("./store_suppliers_sync");
const { createStoreOrderStatsHandlers } = require("./store_order_stats");

initializeApp();

const { originalityCheck, originalityCheckHttp, copyleaksWebhook } = createOriginalityHandlers();
exports.originalityCheck = originalityCheck;
exports.originalityCheckHttp = originalityCheckHttp;
exports.copyleaksWebhook = copyleaksWebhook;
exports.publishExtractReferencesHttp = createPublishExtractHandler();
exports.scienceNewsRssHttp = createScienceNewsRssHandler();
exports.citationLookupHttp = createCitationProxyHandler();

// Google Scholar via SerpAPI (secret: SERPAPI_API_KEY).
const serpapiKey = defineSecret("SERPAPI_API_KEY");
const { createGoogleScholarSearchHandler } = require("./scholar_search");
exports.googleScholarSearchHttp = createGoogleScholarSearchHandler(serpapiKey);

const { createResearchRoom, joinResearchRoom } = createResearchRoomHandlers();
exports.createResearchRoom = createResearchRoom;
exports.joinResearchRoom = joinResearchRoom;

const geminiApiKey = defineSecret("GEMINI_API_KEY");
const {
  consumeQuota,
  quotaExceededHttpsError,
} = require("./usage_quota");

const {
  createGenerateProductFilmHandler,
} = require("./generate_product_film");
const { generateProductFilm } = createGenerateProductFilmHandler(geminiApiKey);
exports.generateProductFilm = generateProductFilm;

// CAD secrets: لا تُحمَّل إلا عند التفعيل — وإلا يفشل أي deploy إن لم تُنشأ الأسرار
const ENABLE_CAD = process.env.ENABLE_CAD === "true";
if (ENABLE_CAD) {
  const partworkApiKey = defineSecret("PARTWORK_API_KEY");
  const tyeApiKey = defineSecret("TYE_API_KEY");
  const { createCadGenerateHandlers } = require("./cad_generate");
  const { generateCadPart } = createCadGenerateHandlers({
    partworkApiKey,
    tyeApiKey,
    geminiApiKey,
  });
  exports.generateCadPart = generateCadPart;
}

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

const {
  createStoreProductDiscoverHandlers,
} = require("./store_product_discover");
const { storeProductDiscover } = createStoreProductDiscoverHandlers();
exports.storeProductDiscover = storeProductDiscover;

const { createResearchIdeasSyncHandlers } = require("./research_ideas_sync");
const {
  researchIdeasSyncWeekly,
  researchIdeasSyncNow,
} = createResearchIdeasSyncHandlers(geminiApiKey);
exports.researchIdeasSyncWeekly = researchIdeasSyncWeekly;
exports.researchIdeasSyncNow = researchIdeasSyncNow;

const { onStoreOrderPaidHeld } = createStoreOrderStatsHandlers();
exports.onStoreOrderPaidHeld = onStoreOrderPaidHeld;

const { createKpiWeeklyHandlers } = require("./kpi_weekly");
const {
  adminComputeWeeklyKpis,
  adminSetWeeklyAdSpend,
  kpiWeeklyScheduled,
} = createKpiWeeklyHandlers();
exports.adminComputeWeeklyKpis = adminComputeWeeklyKpis;
exports.adminSetWeeklyAdSpend = adminSetWeeklyAdSpend;
exports.kpiWeeklyScheduled = kpiWeeklyScheduled;

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
  "privacy_request",
  "catalog_report",
  "supplier_claim",
  "profile_claim",
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
  "privacy_request",
  "catalog_report",
  "supplier_claim",
  "profile_claim",
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

    case "profile_claim": {
      // Admin → claimant after approve/reject.
      if (!(await userHasAdminRole(db, senderUid))) {
        throw new HttpsError(
          "permission-denied",
          "Only admins can send profile_claim result notifications",
        );
      }
      if (contextType !== "profile_claim" || !contextId) {
        throw new HttpsError(
          "invalid-argument",
          "contextType=profile_claim and contextId required",
        );
      }
      const claim = await db.collection("profile_claims").doc(contextId).get();
      if (!claim.exists) {
        throw new HttpsError("permission-denied", "Profile claim not found");
      }
      if (String(claim.data()?.claimantUid || "") !== targetUid) {
        throw new HttpsError(
          "permission-denied",
          "Target is not the claim claimant",
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

/**
 * When an admin deletes a provider, release directory ownership so the same
 * email can re-register and submit/claim again for review.
 */
async function releaseDeletedUserOwnership(db, uid) {
  const writes = [];

  const queueUpdate = (ref, data) => writes.push({ op: "update", ref, data });
  const queueDelete = (ref) => writes.push({ op: "delete", ref });

  const claimsSnap = await db
    .collection("profile_claims")
    .where("claimantUid", "==", uid)
    .get();
  for (const doc of claimsSnap.docs) {
    const status = String(doc.data().status || "");
    if (status === "pending_review") {
      queueUpdate(doc.ref, {
        status: "cancelled",
        cancelledReason: "user_deleted",
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
  }

  const suppliersSnap = await db
    .collection("store_suppliers")
    .where("claimedByUid", "==", uid)
    .get();
  for (const doc of suppliersSnap.docs) {
    queueUpdate(doc.ref, {
      claimedByUid: FieldValue.delete(),
      claimedByName: FieldValue.delete(),
      claimedAt: FieldValue.delete(),
      managedClaimId: FieldValue.delete(),
      directoryStatus: "unverified",
      isPartner: false,
      isVerifiedSeller: false,
      updatedAt: FieldValue.serverTimestamp(),
    });
  }

  const releaseOwnedListing = (doc) => {
    const data = doc.data() || {};
    const approval = String(data.approvalStatus || "");
    if (approval === "pending" || approval === "rejected") {
      queueDelete(doc.ref);
      return;
    }
    queueUpdate(doc.ref, {
      ownerId: "",
      claimedByName: FieldValue.delete(),
      claimedAt: FieldValue.delete(),
      managedClaimId: FieldValue.delete(),
      directoryStatus: "unverified",
      updatedAt: FieldValue.serverTimestamp(),
    });
  };

  const labsSnap = await db
    .collection("labs")
    .where("ownerId", "==", uid)
    .get();
  labsSnap.docs.forEach(releaseOwnedListing);

  const supervisorsSnap = await db
    .collection("supervisors")
    .where("ownerId", "==", uid)
    .get();
  supervisorsSnap.docs.forEach(releaseOwnedListing);

  const writingSnap = await db
    .collection("writing_services")
    .where("ownerId", "==", uid)
    .get();
  for (const doc of writingSnap.docs) {
    const approval = String((doc.data() || {}).approvalStatus || "");
    if (approval === "pending" || approval === "rejected") {
      queueDelete(doc.ref);
    } else {
      queueUpdate(doc.ref, {
        ownerId: "",
        approvalStatus: "pending",
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
  }

  queueDelete(db.collection("provider_applications").doc(uid));

  const productsSnap = await db
    .collection("product")
    .where("createdBy", "==", uid)
    .where("approvalStatus", "==", "pending")
    .get()
    .catch(() => null);
  if (productsSnap) {
    productsSnap.docs.forEach((doc) => queueDelete(doc.ref));
  }

  for (let i = 0; i < writes.length; i += 400) {
    const batch = db.batch();
    for (const w of writes.slice(i, i + 400)) {
      if (w.op === "delete") batch.delete(w.ref);
      else batch.update(w.ref, w.data);
    }
    await batch.commit();
  }
}

/**
 * Delete all users/{id} docs whose email matches (case-insensitive).
 * Used after Auth delete so re-register does not leave ghost profiles.
 */
async function deleteUserDocsByEmail(db, email, { exceptUid = "" } = {}) {
  const target = String(email || "").trim().toLowerCase();
  if (!target) return 0;
  const snap = await db.collection("users").get();
  let n = 0;
  let batch = db.batch();
  let batchCount = 0;
  const commitBatch = async () => {
    if (batchCount === 0) return;
    await batch.commit();
    batch = db.batch();
    batchCount = 0;
  };
  for (const doc of snap.docs) {
    if (exceptUid && doc.id === exceptUid) continue;
    const docEmail = String(doc.data().email || "").trim().toLowerCase();
    if (docEmail !== target) continue;
    batch.delete(doc.ref);
    n += 1;
    batchCount += 1;
    if (batchCount >= 400) await commitBatch();
  }
  await commitBatch();
  return n;
}

/**
 * Admin: delete Firestore users/{uid} AND Firebase Auth account so re-register
 * with the same email is a true first-time signup. Also releases directory
 * ownership so claims/submissions can enter review again.
 */
exports.adminDeleteUser = onCall(
  {
    cors: true,
    serviceAccount: "acadegate-new@appspot.gserviceaccount.com",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }
    const db = getFirestore();
    const callerUid = request.auth.uid;
    if (!(await userHasAdminRole(db, callerUid))) {
      throw new HttpsError("permission-denied", "Admin only");
    }
    const uid = String((request.data || {}).uid || "").trim();
    if (!uid) {
      throw new HttpsError("invalid-argument", "uid required");
    }
    if (uid === callerUid) {
      throw new HttpsError(
        "failed-precondition",
        "Cannot delete your own account here",
      );
    }

    const userSnap = await db.collection("users").doc(uid).get();
    const email = String((userSnap.data() || {}).email || "").trim();

    await releaseDeletedUserOwnership(db, uid);

    await db.collection("users").doc(uid).delete().catch(() => {});

    // Purge any leftover profiles with the same email (orphans from older deletes).
    if (email) {
      await deleteUserDocsByEmail(db, email);
    }

    try {
      await getAuth().deleteUser(uid);
    } catch (e) {
      if (e && e.code !== "auth/user-not-found") {
        throw new HttpsError("internal", e.message || "Auth delete failed");
      }
    }

    return { ok: true };
  },
);

/**
 * Admin: remove Firestore user profiles whose Auth account no longer exists
 * (typical after delete + re-register with the same email → ghost row).
 */
exports.adminCleanupOrphanUsers = onCall(
  {
    cors: true,
    serviceAccount: "acadegate-new@appspot.gserviceaccount.com",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }
    const db = getFirestore();
    const callerUid = request.auth.uid;
    if (!(await userHasAdminRole(db, callerUid))) {
      throw new HttpsError("permission-denied", "Admin only");
    }

    const auth = getAuth();
    const snap = await db.collection("users").get();
    let orphansRemoved = 0;

    for (const doc of snap.docs) {
      if (doc.id === callerUid) continue;
      let missing = false;
      try {
        await auth.getUser(doc.id);
      } catch (e) {
        if (e && e.code === "auth/user-not-found") {
          missing = true;
        } else {
          continue;
        }
      }
      if (!missing) continue;
      await releaseDeletedUserOwnership(db, doc.id).catch(() => {});
      await doc.ref.delete().catch(() => {});
      orphansRemoved += 1;
    }

    return { ok: true, orphansRemoved };
  },
);

/** نماذج حالية — 1.5 و 2.0 أُوقفت من Google */
const MODELS_VISION = [
  "gemini-2.5-flash",
  "gemini-2.5-pro",
  "gemini-2.5-flash-lite",
  "gemini-flash-latest",
];
const MODELS_TEXT = [
  "gemini-2.5-flash",
  "gemini-2.5-pro",
  "gemini-2.5-flash-lite",
  "gemini-flash-latest",
];

const MODELS_IMAGE = [
  "gemini-2.5-flash-image",
  "gemini-2.5-flash-preview-image-generation",
  "gemini-2.0-flash-preview-image-generation",
  "gemini-2.0-flash-exp-image-generation",
];

/** نماذج تدعم thinkingConfig — إرساله لباقي النماذج يسبب INVALID_ARGUMENT */
const THINKING_MODELS = new Set(["gemini-2.5-flash", "gemini-2.5-pro"]);

function extractResponseText(data) {
  const candidates = data?.candidates;
  if (!Array.isArray(candidates) || candidates.length === 0) return null;

  const parts = candidates[0]?.content?.parts;
  if (!Array.isArray(parts) || parts.length === 0) return null;

  const chunks = [];
  for (const part of parts) {
    // Gemini 2.5 may return thought parts — never treat them as user-visible text.
    if (part?.thought === true) continue;
    const text = part?.text?.trim();
    if (text) chunks.push(text);
  }
  return chunks.length > 0 ? chunks.join("\n") : null;
}

function emptyResponseDetail(data) {
  const c0 = Array.isArray(data?.candidates) ? data.candidates[0] : null;
  const finish = c0?.finishReason || data?.promptFeedback?.blockReason || "unknown";
  const partCount = Array.isArray(c0?.content?.parts) ? c0.content.parts.length : 0;
  const thoughtOnly =
    partCount > 0 &&
    Array.isArray(c0?.content?.parts) &&
    c0.content.parts.every((p) => p?.thought === true || !String(p?.text || "").trim());
  if (thoughtOnly) return `empty (thought-only, finish=${finish})`;
  return `empty response (finish=${finish}, parts=${partCount})`;
}

function extractResponseImage(data) {
  const parts = data?.candidates?.[0]?.content?.parts;
  if (!Array.isArray(parts)) return null;
  for (const part of parts) {
    const inline = part?.inlineData || part?.inline_data;
    const b64 = inline?.data;
    if (b64) {
      return {
        data: String(b64),
        mimeType: inline.mimeType || inline.mime_type || "image/png",
      };
    }
  }
  return null;
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

    const quota = await consumeQuota({
      uid: request.auth.uid,
      kind: "gemini",
    });
    if (!quota.ok) {
      if (quota.code === "resource-exhausted") {
        throw quotaExceededHttpsError(quota, "gemini");
      }
      // Do not surface opaque INTERNAL for quota bookkeeping failures.
      console.error("quota check failed", quota);
      throw new HttpsError(
        "unavailable",
        quota.message || "تعذر التحقق من الحصة اليومية — أعد المحاولة",
      );
    }

    const {
      systemPrompt,
      userMessage,
      history = [],
      attachments = [],
      maxOutputTokens = 8192,
      generateImage = false,
      preferPro = false,
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
        // نظّف base64 (قد يصل مع بادئة data: أو مسافات)
        let cleanB64 = String(base64Data).replace(/\s/g, "");
        const dataUrl = cleanB64.match(/^data:([^;]+);base64,(.+)$/i);
        let cleanMime = String(mimeType);
        if (dataUrl) {
          cleanMime = dataUrl[1] || cleanMime;
          cleanB64 = dataUrl[2];
        }
        if (!cleanB64) continue;
        // REST API يقبل camelCase؛ snake_case يفشل على بعض النماذج مع الصور
        userParts.push({
          inlineData: {
            mimeType: cleanMime,
            data: cleanB64,
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

    if (generateImage === true) {
      const imageErrors = [];
      for (const model of MODELS_IMAGE) {
        try {
          const url =
            `https://generativelanguage.googleapis.com/v1beta/models/${model}` +
            `:generateContent?key=${apiKey}`;
          const response = await fetch(url, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              contents,
              generationConfig: {
                temperature: 0.7,
                responseModalities: ["TEXT", "IMAGE"],
              },
            }),
          });
          if (!response.ok) {
            const errBody = await response.text();
            imageErrors.push(
              `${model}: ${formatGeminiApiError(response.status, errBody)}`,
            );
            if (response.status === 429) break;
            continue;
          }
          const data = await response.json();
          const image = extractResponseImage(data);
          if (image) {
            return {
              imageBase64: image.data,
              mimeType: image.mimeType || "image/png",
              model,
            };
          }
          imageErrors.push(`${model}: no image in response`);
        } catch (err) {
          imageErrors.push(`${model}: ${err.message}`);
        }
      }
      return {
        error:
          imageErrors.find(
            (e) => !/is not found|not supported for generateContent/i.test(e),
          ) ||
          imageErrors[imageErrors.length - 1] ||
          "تعذر توليد صورة الأنيميشن",
      };
    }

    const hasInlineImage = userParts.some(
      (p) => p && typeof p === "object" && (p.inlineData || p.inline_data),
    );

    let modelsToTry = hasInlineImage ? MODELS_VISION : MODELS_TEXT;
    if (preferPro === true) {
      modelsToTry = [
        "gemini-2.5-pro",
        ...modelsToTry.filter((m) => m !== "gemini-2.5-pro"),
      ];
    }
    const errors = [];
    for (const model of modelsToTry) {
      try {
        const url =
          `https://generativelanguage.googleapis.com/v1beta/models/${model}` +
          `:generateContent?key=${apiKey}`;

        const generationConfig = {
          temperature: hasInlineImage ? 0.4 : 0.85,
          maxOutputTokens: cappedTokens,
        };
        // لا ترسل thinkingConfig مع الصور — يسبب INVALID_ARGUMENT على أغلب النماذج
        if (!hasInlineImage && THINKING_MODELS.has(model)) {
          generationConfig.thinkingConfig = { thinkingBudget: 0 };
        }

        const response = await fetch(url, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            systemInstruction: {
              parts: [{ text: systemPrompt || "أنت مساعد أكاديمي." }],
            },
            contents,
            generationConfig,
          }),
        });

        if (!response.ok) {
          const errBody = await response.text();
          const msg = `${model}: ${formatGeminiApiError(response.status, errBody)}`;
          errors.push(msg);
          if (response.status === 429) break;
          continue;
        }

        const data = await response.json();
        const text = extractResponseText(data);
        if (text) {
          return { text, model };
        }
        errors.push(`${model}: ${emptyResponseDetail(data)}`);
      } catch (err) {
        errors.push(`${model}: ${err.message}`);
      }
    }

    // فضّل خطأ غير "not found" إن وُجد (أوضح للمستخدم)
    const useful =
      errors.find((e) => !/is not found|not supported for generateContent/i.test(e)) ||
      errors[errors.length - 1] ||
      "unknown";
    return { error: useful };
  },
);
