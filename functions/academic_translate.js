"use strict";

const { onCall, HttpsError } = require("firebase-functions/v2/https");

// Fast, cheap chain — translation does not need the Pro model.
const MODELS = ["gemini-3.6-flash", "gemini-3.1-flash-lite", "gemini-2.5-flash"];

const MAX_CHARS = 40000;
const CHUNK_SIZE = 6000;
const TARGET_LANGS = new Set(["ar", "en"]);

const SYSTEM_INSTRUCTION = [
  "You are an academic translation engine inside AcadeGate.",
  "Translate the user's text into TARGET_LANGUAGE.",
  "Rules:",
  "1. Use formal academic register and the standard terminology of the field.",
  "2. Preserve EXACTLY, without translating or altering: DOIs, URLs,",
  "   citations and reference markers (e.g. (Smith, 2020), [12]), author",
  "   names, numbers, units, statistical notation (p < .05, t(28) = 2.2),",
  "   gene/protein/chemical names, and table or figure labels.",
  "3. Keep the original paragraph structure and markdown headings.",
  "4. When a technical term has a well-established form in the target",
  "   language's academic writing, use it consistently; otherwise keep the",
  "   English term with a brief translation in parentheses at first use.",
  "5. Output ONLY the translation. No notes, no commentary, no preamble.",
].join("\n");

/**
 * Split text on paragraph boundaries, packing paragraphs into chunks of at
 * most `size` characters; over-long paragraphs split on sentence ends,
 * then hard-split as a last resort.
 */
function splitIntoChunks(text, size = CHUNK_SIZE) {
  const normalized = String(text).replace(/\r\n/g, "\n");
  const paragraphs = normalized.split(/\n\n+/);
  const chunks = [];
  let current = "";

  const pushPiece = (piece) => {
    if (piece.length <= size) {
      if (current && current.length + piece.length + 2 > size) {
        chunks.push(current);
        current = piece;
      } else {
        current = current ? `${current}\n\n${piece}` : piece;
      }
      return;
    }
    // Over-long paragraph: split on sentence boundaries.
    if (current) {
      chunks.push(current);
      current = "";
    }
    const sentences = piece.split(/(?<=[.!؟?])\s+/);
    let buf = "";
    for (const sentence of sentences) {
      if (buf && buf.length + sentence.length + 1 > size) {
        chunks.push(buf);
        buf = sentence;
      } else {
        buf = buf ? `${buf} ${sentence}` : sentence;
      }
    }
    while (buf.length > size) {
      chunks.push(buf.slice(0, size));
      buf = buf.slice(size);
    }
    if (buf) current = buf;
  };

  for (const p of paragraphs) {
    const trimmed = p.trim();
    if (trimmed) pushPiece(trimmed);
  }
  if (current) chunks.push(current);
  return chunks;
}

async function callGemini({ apiKey, model, body, fetchImpl }) {
  const fetcher = fetchImpl || fetch;
  const endpoint =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}` +
    `:generateContent?key=${apiKey}`;
  const response = await fetcher(endpoint, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    return { ok: false, status: response.status, model };
  }
  const data = await response.json();
  const parts = data?.candidates?.[0]?.content?.parts;
  const text = Array.isArray(parts)
    ? parts.map((p) => p?.text || "").join("\n").trim()
    : "";
  if (!text) return { ok: false, status: 200, model };
  return { ok: true, text, model };
}

/**
 * Translate one text (already length-bounded) with model fallback.
 * Returns { translation, model, chunks } or throws Error.
 */
async function translateText({ text, targetLang, apiKey, fetchImpl }) {
  const chunks = splitIntoChunks(text);
  const out = [];
  let usedModel = "";
  for (const chunk of chunks) {
    let translated = null;
    let lastStatus = 0;
    for (const model of MODELS) {
      const result = await callGemini({
        apiKey,
        model,
        fetchImpl,
        body: {
          systemInstruction: {
            parts: [
              { text: SYSTEM_INSTRUCTION.replace("TARGET_LANGUAGE", targetLang === "ar" ? "Modern Standard Arabic" : "English") },
            ],
          },
          contents: [{ role: "user", parts: [{ text: chunk }] }],
          generationConfig: { temperature: 0.2 },
        },
      });
      if (result.ok) {
        translated = result.text;
        usedModel = result.model;
        break;
      }
      lastStatus = result.status;
    }
    if (translated == null) {
      throw new Error(`translation failed (last status ${lastStatus})`);
    }
    out.push(translated);
  }
  return { translation: out.join("\n\n"), model: usedModel, chunks: chunks.length };
}

function createAcademicTranslateHandlers(geminiApiKey) {
  const translateAcademicText = onCall(
    { secrets: [geminiApiKey], timeoutSeconds: 240, cors: true },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Sign in required");
      }
      const data = request.data || {};
      const text = typeof data.text === "string" ? data.text.trim() : "";
      const targetLang = typeof data.targetLang === "string"
        ? data.targetLang.trim()
        : "";
      if (text.length < 3 || text.length > MAX_CHARS) {
        throw new HttpsError(
          "invalid-argument",
          `text must be 3..${MAX_CHARS} characters`,
        );
      }
      if (!TARGET_LANGS.has(targetLang)) {
        throw new HttpsError(
          "invalid-argument",
          "targetLang must be 'ar' or 'en'",
        );
      }
      try {
        return await translateText({
          text,
          targetLang,
          apiKey: geminiApiKey.value(),
        });
      } catch (e) {
        throw new HttpsError(
          "unavailable",
          e instanceof Error ? e.message : String(e),
        );
      }
    },
  );
  return { translateAcademicText };
}

module.exports = {
  createAcademicTranslateHandlers,
  splitIntoChunks,
  translateText,
  SYSTEM_INSTRUCTION,
  MAX_CHARS,
};
