const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");

function isPaidEscrow(status) {
  return status === "paid_held" || status === "released";
}

async function grantKnowledgeLicenseIfNeeded(db, orderId, order) {
  const productId = String(order.productId || "").trim();
  const buyerId = String(order.buyerId || "").trim();
  const sellerId = String(order.sellerId || "").trim();
  if (!productId || !buyerId) return;

  const productSnap = await db.collection("product").doc(productId).get();
  if (!productSnap.exists) return;
  const product = productSnap.data() || {};
  if (String(product.productType || "") !== "knowledge_asset") return;
  if (!product.hasProtectedAsset) return;

  const secretSnap = await db
    .collection("knowledge_asset_secrets")
    .doc(productId)
    .get();
  if (!secretSnap.exists) {
    console.warn(
      `grantKnowledgeLicense: missing secret for product ${productId}`,
    );
    return;
  }
  const secret = secretSnap.data() || {};
  const licenseMode = String(product.licenseMode || "sale");
  const rentalDays = Number(product.rentalDays || 0);
  let expiresAt = null;
  if (licenseMode === "rental" && rentalDays > 0) {
    expiresAt = Timestamp.fromDate(
      new Date(Date.now() + rentalDays * 24 * 60 * 60 * 1000),
    );
  }

  const licenseId = `${buyerId}_${productId}`;
  const licenseRef = db.collection("product_licenses").doc(licenseId);
  const existing = await licenseRef.get();
  if (existing.exists) {
    // Extend rental on repurchase; keep sale perpetual.
    if (licenseMode === "rental" && expiresAt) {
      await licenseRef.set(
        {
          status: "active",
          expiresAt,
          orderId,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }
    return;
  }

  await licenseRef.set({
    buyerId,
    sellerId,
    productId,
    orderId,
    productName: String(product.name || order.productName || ""),
    licenseMode,
    status: "active",
    grantedAt: FieldValue.serverTimestamp(),
    expiresAt,
    decryptionKeyB64: String(secret.decryptionKeyB64 || ""),
    ivB64: String(secret.ivB64 || ""),
    assetStoragePath: String(product.assetStoragePath || ""),
    assetFileName: String(product.assetFileName || ""),
    assetContentType: String(product.assetContentType || ""),
    assetKind: String(product.assetKind || "other"),
    allowExport: licenseMode === "sale",
    accessCount: 0,
    createdAt: FieldValue.serverTimestamp(),
  });
}

/**
 * When a store order first becomes paid (escrow held or released),
 * increment product.orderCount and grant knowledge-asset licenses.
 */
function createStoreOrderStatsHandlers() {
  const onStoreOrderPaidHeld = onDocumentUpdated(
    {
      document: "store_orders/{orderId}",
      region: "us-central1",
    },
    async (event) => {
      const before = event.data?.before?.data() || {};
      const after = event.data?.after?.data() || {};
      if (isPaidEscrow(before.paymentStatus) || !isPaidEscrow(after.paymentStatus)) {
        return;
      }

      const productId = String(after.productId || "").trim();
      if (!productId) return;

      const db = getFirestore();
      const orderId = event.params.orderId;
      const productRef = db.collection("product").doc(productId);
      try {
        await productRef.update({
          orderCount: FieldValue.increment(1),
          orderCountUpdatedAt: FieldValue.serverTimestamp(),
        });
      } catch (err) {
        console.warn(
          `onStoreOrderPaidHeld: could not increment orderCount for ${productId}`,
          err?.message || err,
        );
      }

      try {
        await grantKnowledgeLicenseIfNeeded(db, orderId, after);
      } catch (err) {
        console.warn(
          `onStoreOrderPaidHeld: knowledge license grant failed for ${orderId}`,
          err?.message || err,
        );
      }
    },
  );

  return { onStoreOrderPaidHeld };
}

module.exports = { createStoreOrderStatsHandlers };
