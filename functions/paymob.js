const crypto = require("crypto");
const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret, defineString } = require("firebase-functions/params");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");

const paymobSecretKey = defineSecret("PAYMOB_SECRET_KEY");
const paymobPublicKey = defineSecret("PAYMOB_PUBLIC_KEY");
const paymobHmacSecret = defineSecret("PAYMOB_HMAC_SECRET");
const paymobIntegrationId = defineSecret("PAYMOB_INTEGRATION_ID");
// Mobile Wallets integration (Vodafone Cash, Etisalat Cash, Orange Cash,
// WE Pay). Not a secret — set in functions/.env; empty = wallets disabled.
const paymobWalletIntegrationId = defineString("PAYMOB_WALLET_INTEGRATION_ID", {
  default: "",
});

const PLAN_PRICES_EGP = { plus: 550, pro: 3350 };
const PAYMOB_BASE = "https://accept.paymob.com";
const FUNCTIONS_SERVICE_ACCOUNT = "acadegate-new@appspot.gserviceaccount.com";
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
  // store:{orderId} or store:{orderId}:{attempt}
  // writing:{serviceId}:{orderId} or writing:{serviceId}:{orderId}:{attempt}
  if (raw.startsWith("store:")) {
    const orderId = raw.slice("store:".length).split(":")[0];
    if (!orderId) return null;
    return { kind: "store", orderId };
  }
  if (raw.startsWith("writing:")) {
    const parts = raw.slice("writing:".length).split(":");
    if (!parts[0] || !parts[1]) return null;
    return {
      kind: "writing",
      serviceId: parts[0],
      orderId: parts[1],
    };
  }
  if (raw.startsWith("plan:")) {
    const paymentId = raw.slice("plan:".length).split(":")[0];
    if (!paymentId) return null;
    return { kind: "plan", paymentId };
  }
  return null;
}

function checkoutReference(base) {
  return `${base}:${Date.now().toString(36)}`;
}

function addOneMonthUtc(date) {
  return new Date(Date.UTC(
    date.getUTCFullYear(),
    date.getUTCMonth() + 1,
    date.getUTCDate(),
    date.getUTCHours(),
    date.getUTCMinutes(),
    date.getUTCSeconds(),
    date.getUTCMilliseconds(),
  ));
}

function paymobErrorText(data, text, status) {
  const raw = data?.detail ?? data?.message ?? data?.error ?? "";
  if (raw && typeof raw === "object") {
    const bits = Object.values(raw).map((value) => {
      if (Array.isArray(value)) return value.join(" ");
      if (value && typeof value === "object") return JSON.stringify(value);
      return String(value ?? "");
    });
    const joined = bits.filter(Boolean).join(" ");
    if (joined) return joined;
  }
  const plain = String(raw || text || "").trim();
  return plain.slice(0, 240) || `HTTP ${status}`;
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
    throw new HttpsError(
      "failed-precondition",
      `Paymob: ${paymobErrorText(data, text, res.status)}`,
    );
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

async function markPlanPaid(db, paymentId, tx) {
  const ref = db.collection("subscription_payments").doc(paymentId);
  const paidCents = Number(tx?.amount_cents);
  let outcome = { ok: false, reason: "missing" };
  await db.runTransaction(async (t) => {
    const snap = await t.get(ref);
    if (!snap.exists) {
      outcome = { ok: false, reason: "payment_not_found" };
      return;
    }
    const payment = snap.data() || {};
    if (payment.paymentStatus === "paid") {
      outcome = { ok: true, reason: "already_paid", userId: payment.userId };
      return;
    }
    const expected = Math.round(Number(payment.amount) * 100);
    if (!Number.isFinite(paidCents) || paidCents !== expected) {
      outcome = { ok: false, reason: "amount_mismatch" };
      return;
    }
    const uid = String(payment.userId || "");
    const tier = payment.tier === "pro" ? "pro" : "plus";
    if (!uid) {
      outcome = { ok: false, reason: "missing_user" };
      return;
    }
    const userRef = db.collection("users").doc(uid);
    const userSnap = await t.get(userRef);
    const user = userSnap.data() || {};
    const now = new Date();
    let start = now;
    const currentTier = String(user.subscription || "free");
    const exp = user.subscriptionExpiresAt?.toDate?.() || null;
    if (currentTier === tier && exp && exp > now) start = exp;
    const expires = addOneMonthUtc(start);
    t.set(
      ref,
      {
        paymentStatus: "paid",
        paidAt: FieldValue.serverTimestamp(),
        paymobTransactionId: tx?.id ?? null,
        paymobOrderId: tx?.order?.id ?? null,
        expiresAt: Timestamp.fromDate(expires),
      },
      { merge: true },
    );
    t.set(
      userRef,
      {
        subscription: tier,
        subscriptionExpiresAt: Timestamp.fromDate(expires),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    outcome = {
      ok: true,
      userId: uid,
      tier,
      amount: payment.amount,
    };
  });
  return outcome;
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
      serviceAccount: FUNCTIONS_SERVICE_ACCOUNT,
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
      const channel = data.channel === "wallet" ? "wallet" : "card";
      if (kind !== "subscription" && !orderId) {
        throw new HttpsError("invalid-argument", "orderId مطلوب");
      }

      let checkoutIntegrationId = integrationId;
      if (channel === "wallet") {
        checkoutIntegrationId = String(paymobWalletIntegrationId.value() || "").trim();
        if (!checkoutIntegrationId || checkoutIntegrationId === String(integrationId).trim()) {
          throw new HttpsError(
            "failed-precondition",
            "الدفع بالمحفظة الإلكترونية غير مفعّل بعد — استخدم البطاقة أو التحويل اليدوي",
          );
        }
      }

      const db = getFirestore();
      let amount = 0;
      let specialReference = "";
      let title = "AcadeGate order";
      let planPaymentId = "";
      let billingPhone = String(data.phone || "").trim();

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
        specialReference = checkoutReference(`store:${orderId}`);
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
        specialReference = checkoutReference(`writing:${serviceId}:${orderId}`);
      } else if (kind === "subscription") {
        const tier = String(data.tier || "").trim();
        amount = PLAN_PRICES_EGP[tier];
        if (!(amount > 0)) {
          throw new HttpsError("invalid-argument", "الباقة غير متاحة للدفع");
        }
        const userSnap = await db.collection("users").doc(request.auth.uid).get();
        const user = userSnap.data() || {};
        billingPhone = String(user.phone || billingPhone || "").trim();
        title = tier === "pro" ? "الباقة الشاملة" : "الباقة الأساسية";
        const payRef = db.collection("subscription_payments").doc();
        planPaymentId = payRef.id;
        specialReference = checkoutReference(`plan:${planPaymentId}`);
        await payRef.set({
          userId: request.auth.uid,
          email: request.auth.token?.email || "",
          tier,
          amount,
          currency: "EGP",
          paymentStatus: "pending",
          paymobChannel: channel,
          paymobSpecialReference: specialReference,
          createdAt: FieldValue.serverTimestamp(),
        });
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
          phone: billingPhone || "+201000000000",
        },
        integrationId: checkoutIntegrationId,
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
      if (kind === "subscription") {
        await db.collection("subscription_payments").doc(planPaymentId).set(
          {
            paymobCheckoutAt: FieldValue.serverTimestamp(),
            paymobIntentionId: intention.id || null,
          },
          { merge: true },
        );
      } else if (kind === "store") {
        await db.collection("store_orders").doc(orderId).set(
          {
            paymobSpecialReference: specialReference,
            paymobCheckoutAt: FieldValue.serverTimestamp(),
            paymobIntentionId: intention.id || null,
            paymobChannel: channel,
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
              paymobChannel: channel,
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
        channel,
        paymentId: planPaymentId,
      };
    },
  );

  const paymobWebhook = onRequest(
    {
      cors: true,
      invoker: "public",
      secrets: [paymobHmacSecret],
      timeoutSeconds: 60,
      serviceAccount: FUNCTIONS_SERVICE_ACCOUNT,
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
        } else if (parsed.kind === "plan") {
          const result = await markPlanPaid(db, parsed.paymentId, obj);
          if (result.ok && result.reason !== "already_paid" && result.userId) {
            const planName = result.tier === "pro" ? "الشاملة" : "الأساسية";
            await addNotification(db, {
              userId: result.userId,
              title: "تم تفعيل الاشتراك",
              body: `تم استلام ${result.amount} ج.م وبدأت باقة ${planName}`,
              type: "subscription_paid",
              senderId: "paymob",
            });
          } else if (!result.ok) {
            console.error("plan payment not applied", parsed.paymentId, result.reason);
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
    {
      cors: true,
      timeoutSeconds: 30,
      serviceAccount: FUNCTIONS_SERVICE_ACCOUNT,
    },
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
