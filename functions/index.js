const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { initializeApp } = require("firebase-admin/app");
const crypto = require("crypto");

initializeApp();

const geminiApiKey = defineSecret("GEMINI_API_KEY");

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

exports.geminiAdvisor = onCall(
  {
    secrets: [geminiApiKey],
    timeoutSeconds: 120,
    cors: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "يجب تسجيل الدخول لاستخدام المساعد الذكي");
    }

    const { systemPrompt, userMessage, history = [], maxOutputTokens = 8192 } =
      request.data || {};

    if (!userMessage || typeof userMessage !== "string") {
      throw new HttpsError("invalid-argument", "userMessage مطلوب");
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
    contents.push({ role: "user", parts: [{ text: userMessage }] });

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
          lastError = `${model}: ${response.status} ${errBody}`;
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

exports.joinResearchRoom = onCall(async (request) => {
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
  if (pass.length < 4) {
    throw new HttpsError("invalid-argument", "كلمة المرور قصيرة");
  }

  const secretSnap = await db.collection("research_room_secrets").doc(roomId).get();
  const legacyHash = room.passwordHash;
  const secretHash = secretSnap.exists ? secretSnap.data().passwordHash : null;
  const expected = secretHash || legacyHash;

  if (!expected || hashPassword(pass) !== expected) {
    throw new HttpsError("permission-denied", "كلمة المرور غير صحيحة");
  }

  await roomRef.collection("members").doc(uid).set({
    grantedAt: FieldValue.serverTimestamp(),
    method: "password",
  });

  return { ok: true };
});
