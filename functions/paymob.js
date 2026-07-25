const crypto = require("crypto");
const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

const paymobSecretKey = defineSecret("PAYMOB_SECRET_KEY");
const paymobPublicKey = defineSecret("PAYMOB_PUBLIC_KEY");
const paymobHmacSecret = defineSecret("PAYMOB_HMAC_SECRET");
const paymobIntegrationId = defineSecret("PAYMOB_INTEGRATION_ID");

const PAYMOB_BASE = "https://accept.paymob.com";
const PROJECT_ID = process.env.GCLOUD_PROJECT || "acadegate-new";
const REGION = process.env.FUNCTION_REGION || "us-central1";

function webhookUrl() {
  return `https://${REGION}-${PROJECT_ID}.cloudfunctions.net/paymobWebhook`;
}

function verifyTransactionHmac(obj, receivedHmac, hmacSecret) {
  if (!obj || !receivedHmac || !hmacSecret) return false;
  const fields = [
    obj.amount_cents,
    obj.created_at,
    obj.currency,
    obj.error_occured,
    obj.has_parent_transaction,
    obj.id,
    obj.integration_id,
    obj.is_3d_secure,
    obj.is_auth,
    obj.is_capture,
    obj.is_refunded,
    obj.is_standalone_payment,
    obj.is_voided,
    obj.order?.id,
    obj.owner,
    obj.pending,
    obj.source_data?.pan,
    obj.source_data?.sub_type,
    obj.source_data?.type,
    obj.success,
  ];
  const computed = crypto
    .createHmac("sha512", hmacSecret)
    .update(fields.map((v) => String(v)).join(""))
    .digest("hex");
  try {
    const a = Buffer.from(computed, "utf8");
    const b = Buffer.from(String(receivedHmac), "utf8");
    return a.length === b.length && crypto.timingSafeEqual(a, b);
  } catch (_) {
    return false;
  }
}

function parseSpecialReference(ref) {
  const raw = String(ref || "").trim();
  // store:{orderId}
  // writing:{serviceId}:{orderId}
  if (raw.startsWith("store:")) {
    return { kind: "store", orderId: raw.slice("store:".length) };
  }
  if (raw.startsWith("writing:")) {
    const rest = raw.slice("writing:".length);
    const idx = rest.indexOf(":");
    if (idx <= 0) return null;
    return {
      kind: "writing",
      serviceId: rest.slice(0, idx),
      orderId: rest.slice(idx + 1),
    };
  }
  return null;
}

async function createIntention({
  amountCents,
  currency,
  specialReference,
  billing,
  integrationId,
  secretKey,
  notificationUrl,
  redirectionUrl,
}) {
  const body = {
    amount: amountCents,
    currency,
    payment_methods: [Number(integrationId)],
    special_reference: specialReference,
    notification_url: notificationUrl,
    redirection_url: redirectionUrl,
    billing_data: {
      apartment: "NA",
      first_name: billing.firstName || "Customer",
      last_name: billing.lastName || "AcadeGate",
      street: "NA",
      building: "NA",
      phone_number: billing.phone || "+201000000000",
      city: "Cairo",
      country: "EG",
      email: billing.email || "customer@acadegate.app",
      floor: "NA",
      state: "NA",
    },
  };

  const res = await fetch(`${PAYMOB_BASE}/v1/intention/`, {
    method: "POST",
    headers: {
      Authorization: `Token ${secretKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  const text = await res.text();
  let data;
  try {
    data = JSON.parse(text);
  } catch (_) {
    throw new HttpsError(
      "internal",
      `Paymob intention invalid JSON (${res.status})`,
    );
  }

  if (!res.ok) {
    const msg =
      data?.detail ||
      data?.message ||
      data?.error ||
      text.slice(0, 200) ||
      `HTTP ${res.status}`;
    throw new HttpsError("failed-precondition", `Paymob: ${msg}`);
  }

  const clientSecret = data.client_secret;
  if (!clientSecret) {
    throw new HttpsError("internal", "Paymob: missing client_secret");
  }
  return data;
}

async function markStorePaidHeld(db, orderId, tx) {
  const ref = db.collection("store_orders").doc(orderId);
  const snap = await ref.get();
  if (!snap.exists) return { ok: false, reason: "order_not_found" };
  const data = snap.data() || {};
  if (data.paymentStatus === "paid_held" || data.paymentStatus === "released") {
    return { ok: true, reason: "already_paid", sellerId: data.sellerId };
  }

  await ref.set(
    {
      paymentStatus: "paid_held",
      paidAt: FieldValue.serverTimestamp(),
      paymobTransactionId: tx?.id ?? null,
      paymobOrderId: tx?.order?.id ?? null,
      status: data.status === "pending" ? "paid" : data.status,
    },
    { merge: true },
  );
  return {
    ok: true,
    sellerId: data.sellerId,
    productName: data.productName,
    amount: data.amount ?? data.price,
    buyerId: data.buyerId,
  };
}

async function markWritingPaidHeld(db, serviceId, orderId, tx) {
  const ref = db
    .collection("writing_services")
    .doc(serviceId)
    .collection("writing_orders")
    .doc(orderId);
  const snap = await ref.get();
  if (!snap.exists) return { ok: false, reason: "order_not_found" };
  const data = snap.data() || {};
  if (data.paymentStatus === "paid_held" || data.paymentStatus === "released") {
    return { ok: true, reason: "already_paid", ownerId: data.serviceOwnerId };
  }

  await ref.set(
    {
      paymentStatus: "paid_held",
      paidAt: FieldValue.serverTimestamp(),
      paymobTransactionId: tx?.id ?? null,
      paymobOrderId: tx?.order?.id ?? null,
      status: "in_progress",
    },
    { merge: true },
  );
  return {
    ok: true,
    ownerId: data.serviceOwnerId,
    topic: data.topic,
    amount: data.amount,
    userId: data.userId,
  };
}

async function addNotification(db, { userId, title, body, type, senderId }) {
  if (!userId) return;
  await db.collection("notifications").add({
    userId,
    title,
    body,
    type,
    senderId: senderId || "system",
    read: false,
    createdAt: FieldValue.serverTimestamp(),
  });
}

function createPaymobHandlers() {
  const secrets = [
    paymobSecretKey,
    paymobPublicKey,
    paymobHmacSecret,
    paymobIntegrationId,
  ];

  const createPaymobCheckout = onCall(
    {
      secrets,
      cors: true,
      timeoutSeconds: 60,
    },
    async (request) => {
      if (!request.auth?.uid) {
        throw new HttpsError("unauthenticated", "يجب تسجيل الدخول للدفع");
      }

      const secretKey = String(paymobSecretKey.value() || "").trim();
      const publicKey = String(paymobPublicKey.value() || "").trim();
      const integrationId = String(paymobIntegrationId.value() || "").trim();
      if (!secretKey || !publicKey || !integrationId) {
        throw new HttpsError(
          "failed-precondition",
          "Paymob غير مضبوط — عيّن PAYMOB_SECRET_KEY و PAYMOB_PUBLIC_KEY و PAYMOB_INTEGRATION_ID",
        );
      }

      const data = request.data || {};
      const kind = String(data.kind || "store").trim();
      const orderId = String(data.orderId || "").trim();
      const serviceId = String(data.serviceId || "").trim();
      if (!orderId) {
        throw new HttpsError("invalid-argument", "orderId مطلوب");
      }

      const db = getFirestore();
      let amount = 0;
      let specialReference = "";
      let title = "AcadeGate order";

      if (kind === "store") {
        const snap = await db.collection("store_orders").doc(orderId).get();
        if (!snap.exists) {
          throw new HttpsError("not-found", "الطلب غير موجود");
        }
        const order = snap.data() || {};
        if (order.buyerId !== request.auth.uid) {
          throw new HttpsError("permission-denied", "غير مصرح");
        }
        if (
          order.paymentStatus === "paid_held" ||
          order.paymentStatus === "released"
        ) {
          throw new HttpsError("failed-precondition", "الطلب مدفوع مسبقاً");
        }
        amount = Number(order.amount ?? order.price ?? 0);
        title = String(order.productName || "Store order");
        specialReference = `store:${orderId}`;
      } else if (kind === "writing") {
        if (!serviceId) {
          throw new HttpsError("invalid-argument", "serviceId مطلوب");
        }
        const snap = await db
          .collection("writing_services")
          .doc(serviceId)
          .collection("writing_orders")
          .doc(orderId)
          .get();
        if (!snap.exists) {
          throw new HttpsError("not-found", "طلب الكتابة غير موجود");
        }
        const order = snap.data() || {};
        if (order.userId !== request.auth.uid) {
          throw new HttpsError("permission-denied", "غير مصرح");
        }
        if (
          order.paymentStatus === "paid_held" ||
          order.paymentStatus === "released"
        ) {
          throw new HttpsError("failed-precondition", "الطلب مدفوع مسبقاً");
        }
        amount = Number(order.amount ?? 0);
        title = String(order.topic || "Writing order");
        specialReference = `writing:${serviceId}:${orderId}`;
      } else {
        throw new HttpsError("invalid-argument", "kind غير مدعوم");
      }

      if (!(amount > 0)) {
        throw new HttpsError("failed-precondition", "مبلغ غير صالح");
      }

      const amountCents = Math.round(amount * 100);
      const email = request.auth.token?.email || "customer@acadegate.app";
      const name = String(request.auth.token?.name || "Customer").trim();
      const parts = name.split(/\s+/);
      const firstName = parts[0] || "Customer";
      const lastName = parts.slice(1).join(" ") || "AcadeGate";

      const intention = await createIntention({
        amountCents,
        currency: "EGP",
        specialReference,
        billing: {
          firstName,
          lastName,
          email,
          phone: String(data.phone || "").trim() || "+201000000000",
        },
        integrationId,
        secretKey,
        notificationUrl: webhookUrl(),
        redirectionUrl: String(data.redirectionUrl || "").trim() ||
          "https://acadegate-new.web.app/payment-return",
      });

      const clientSecret = intention.client_secret;
      const checkoutUrl =
        `${PAYMOB_BASE}/unifiedcheckout/?publicKey=${encodeURIComponent(publicKey)}` +
        `&clientSecret=${encodeURIComponent(clientSecret)}`;

      // Persist checkout attempt metadata (no paymentStatus forge by client).
      if (kind === "store") {
        await db.collection("store_orders").doc(orderId).set(
          {
            paymobSpecialReference: specialReference,
            paymobCheckoutAt: FieldValue.serverTimestamp(),
            paymobIntentionId: intention.id || null,
          },
          { merge: true },
        );
      } else {
        await db
          .collection("writing_services")
          .doc(serviceId)
          .collection("writing_orders")
          .doc(orderId)
          .set(
            {
              paymobSpecialReference: specialReference,
              paymobCheckoutAt: FieldValue.serverTimestamp(),
              paymobIntentionId: intention.id || null,
            },
            { merge: true },
          );
      }

      return {
        checkoutUrl,
        clientSecret,
        publicKey,
        amount,
        currency: "EGP",
        title,
        specialReference,
      };
    },
  );

  const paymobWebhook = onRequest(
    {
      cors: true,
      invoker: "public",
      secrets: [paymobHmacSecret],
      timeoutSeconds: 60,
    },
    async (req, res) => {
      if (req.method !== "POST") {
        res.status(405).send("Method not allowed");
        return;
      }

      const hmacSecret = String(paymobHmacSecret.value() || "").trim();
      const receivedHmac = String(req.query.hmac || "");
      const obj = req.body?.obj || req.body?.transaction || null;

      if (!verifyTransactionHmac(obj, receivedHmac, hmacSecret)) {
        res.status(401).json({ error: "Invalid HMAC" });
        return;
      }

      // Always 200 after HMAC ok to stop retries; ignore non-success.
      if (!(obj.success === true || obj.success === "true") || obj.pending) {
        res.status(200).json({ received: true, ignored: true });
        return;
      }

      const special =
        obj.order?.merchant_order_id ||
        obj.order?.special_reference ||
        obj.special_reference ||
        "";
      const parsed = parseSpecialReference(special);
      if (!parsed) {
        res.status(200).json({ received: true, ignored: "bad_reference" });
        return;
      }

      const db = getFirestore();
      try {
        if (parsed.kind === "store") {
          const result = await markStorePaidHeld(db, parsed.orderId, obj);
          if (result.ok && result.reason !== "already_paid" && result.sellerId) {
            await addNotification(db, {
              userId: result.sellerId,
              title: "تم استلام الدفع",
              body: `${result.productName || "طلب متجر"} — المبلغ محجوز حتى تأكيد الاستلام`,
              type: "payment_held",
              senderId: "paymob",
            });
          }
        } else if (parsed.kind === "writing") {
          const result = await markWritingPaidHeld(
            db,
            parsed.serviceId,
            parsed.orderId,
            obj,
          );
          if (result.ok && result.reason !== "already_paid" && result.ownerId) {
            await addNotification(db, {
              userId: result.ownerId,
              title: "تم استلام دفع طلب كتابة",
              body: `${result.topic || "طلب كتابة"} — المبلغ محجوز حتى التسليم`,
              type: "payment_held",
              senderId: "paymob",
            });
          }
        }
        res.status(200).json({ received: true });
      } catch (err) {
        console.error("paymobWebhook error", err);
        res.status(500).json({ error: "internal" });
      }
    },
  );

  const confirmEscrowRelease = onCall(
    { cors: true, timeoutSeconds: 30 },
    async (request) => {
      if (!request.auth?.uid) {
        throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
      }
      const data = request.data || {};
      const kind = String(data.kind || "store").trim();
      const orderId = String(data.orderId || "").trim();
      const serviceId = String(data.serviceId || "").trim();
      if (!orderId) {
        throw new HttpsError("invalid-argument", "orderId مطلوب");
      }

      const db = getFirestore();

      if (kind === "store") {
        const ref = db.collection("store_orders").doc(orderId);
        const snap = await ref.get();
        if (!snap.exists) throw new HttpsError("not-found", "الطلب غير موجود");
        const order = snap.data() || {};
        if (order.buyerId !== request.auth.uid) {
          throw new HttpsError("permission-denied", "غير مصرح");
        }
        const updates = {
          status: "delivered",
          deliveredAt: FieldValue.serverTimestamp(),
        };
        if (order.paymentStatus === "paid_held") {
          updates.paymentStatus = "released";
          updates.releasedAt = FieldValue.serverTimestamp();
        }
        await ref.set(updates, { merge: true });
        if (order.sellerId) {
          await addNotification(db, {
            userId: order.sellerId,
            title: "تم تأكيد الاستلام",
            body: `${order.productName || "طلب"} — تم تحرير المبلغ للبائع`,
            type: "payment_released",
            senderId: request.auth.uid,
          });
        }
        return { ok: true, paymentStatus: updates.paymentStatus || order.paymentStatus };
      }

      if (kind === "writing") {
        if (!serviceId) {
          throw new HttpsError("invalid-argument", "serviceId مطلوب");
        }
        const ref = db
          .collection("writing_services")
          .doc(serviceId)
          .collection("writing_orders")
          .doc(orderId);
        const snap = await ref.get();
        if (!snap.exists) throw new HttpsError("not-found", "الطلب غير موجود");
        const order = snap.data() || {};
        if (order.userId !== request.auth.uid) {
          throw new HttpsError("permission-denied", "غير مصرح");
        }
        const updates = {
          status: "completed",
          completedAt: FieldValue.serverTimestamp(),
        };
        if (data.rating != null) updates.studentRating = Number(data.rating);
        if (order.paymentStatus === "paid_held") {
          updates.paymentStatus = "released";
          updates.releasedAt = FieldValue.serverTimestamp();
        }
        await ref.set(updates, { merge: true });
        if (order.serviceOwnerId) {
          await addNotification(db, {
            userId: order.serviceOwnerId,
            title: "تم إكمال طلب الكتابة",
            body: `${order.topic || "طلب كتابة"} — تم تحرير المبلغ`,
            type: "payment_released",
            senderId: request.auth.uid,
          });
        }
        return { ok: true };
      }

      throw new HttpsError("invalid-argument", "kind غير مدعوم");
    },
  );

  return { createPaymobCheckout, paymobWebhook, confirmEscrowRelease };
}

module.exports = { createPaymobHandlers };
