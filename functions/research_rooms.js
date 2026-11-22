const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const crypto = require("crypto");

function hashRoomPassword(password) {
  const salt = crypto.randomBytes(16).toString("hex");
  const hash = crypto.scryptSync(String(password).trim(), salt, 32).toString("hex");
  return `s2:${salt}:${hash}`;
}

function verifyRoomPassword(password, stored) {
  const value = typeof stored === "string" ? stored : "";
  const pass = String(password).trim();
  if (!value) return false;

  if (value.startsWith("s2:")) {
    const parts = value.split(":");
    if (parts.length !== 3 || !parts[1] || !parts[2]) return false;
    const actual = crypto.scryptSync(pass, parts[1], 32);
    const expected = Buffer.from(parts[2], "hex");
    if (expected.length !== actual.length) return false;
    return crypto.timingSafeEqual(actual, expected);
  }

  const legacy = crypto.createHash("sha256").update(pass).digest("hex");
  const left = Buffer.from(legacy);
  const right = Buffer.from(value);
  if (left.length !== right.length) return false;
  return crypto.timingSafeEqual(left, right);
}

function createResearchRoomHandlers() {
  const createResearchRoom = onCall({ cors: true }, async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
    }

    const data = request.data || {};
    const title = typeof data.title === "string" ? data.title.trim() : "";
    const description =
      typeof data.description === "string" ? data.description.trim() : "";
    const categoryId =
      typeof data.categoryId === "string" ? data.categoryId.trim() : "";
    const isPasswordProtected = data.isPasswordProtected === true;
    const password = typeof data.password === "string" ? data.password.trim() : "";
    const creatorName =
      typeof data.creatorName === "string" && data.creatorName.trim()
        ? data.creatorName.trim().slice(0, 120)
        : "باحث";

    if (!title) {
      throw new HttpsError("invalid-argument", "اسم الغرفة مطلوب");
    }
    if (title.length > 200) {
      throw new HttpsError("invalid-argument", "اسم الغرفة طويل جداً");
    }
    if (isPasswordProtected && password.length < 8) {
      throw new HttpsError(
        "invalid-argument",
        "كلمة المرور يجب أن تكون 8 أحرف على الأقل",
      );
    }

    const uid = request.auth.uid;
    const db = getFirestore();

    const roomData = {
      title,
      description: description.slice(0, 2000),
      creatorId: uid,
      creatorName,
      isPasswordProtected,
      discussionsCount: 0,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (categoryId) {
      roomData.categoryId = categoryId;
    }

    const roomRef = db.collection("research_rooms").doc();
    const batch = db.batch();
    batch.set(roomRef, roomData);

    if (isPasswordProtected) {
      batch.set(db.collection("research_room_secrets").doc(roomRef.id), {
        passwordHash: hashRoomPassword(password),
        creatorId: uid,
        createdAt: FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    return { roomId: roomRef.id, ok: true };
  });

  const joinResearchRoom = onCall({ cors: true }, async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
    }

    const { roomId, password } = request.data || {};
    if (!roomId || typeof roomId !== "string") {
      throw new HttpsError("invalid-argument", "roomId مطلوب");
    }

    const db = getFirestore();
    const roomRef = db.collection("research_rooms").doc(roomId);
    const roomSnap = await roomRef.get();
    if (!roomSnap.exists) {
      throw new HttpsError("not-found", "الغرفة غير موجودة");
    }

    const room = roomSnap.data();
    const uid = request.auth.uid;

    if (!room.isPasswordProtected) {
      await roomRef.collection("members").doc(uid).set({
        grantedAt: FieldValue.serverTimestamp(),
        method: "open",
      });
      return { ok: true };
    }

    if (room.creatorId === uid) {
      return { ok: true };
    }

    const pass = typeof password === "string" ? password.trim() : "";

    const secretSnap = await db
      .collection("research_room_secrets")
      .doc(roomId)
      .get();
    const legacyHash = room.passwordHash;
    const secretHash = secretSnap.exists
      ? secretSnap.data().passwordHash
      : null;
    const expected = secretHash || legacyHash;

    if (!expected || !verifyRoomPassword(pass, expected)) {
      throw new HttpsError("permission-denied", "كلمة المرور غير صحيحة");
    }

    if (!String(expected).startsWith("s2:")) {
      await db.collection("research_room_secrets").doc(roomId).set(
        { passwordHash: hashRoomPassword(pass) },
        { merge: true },
      );
    }

    await roomRef.collection("members").doc(uid).set({
      grantedAt: FieldValue.serverTimestamp(),
      method: "password",
    });

    return { ok: true };
  });

  return { createResearchRoom, joinResearchRoom };
}

module.exports = { createResearchRoomHandlers };
