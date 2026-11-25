"use strict";

const test = require("node:test");
const assert = require("node:assert");

const {
  splitIntoChunks,
  translateText,
  SYSTEM_INSTRUCTION,
  MAX_CHARS,
} = require("../academic_translate");

test("splitIntoChunks keeps short text in one chunk", () => {
  const chunks = splitIntoChunks("First paragraph.\n\nSecond paragraph.");
  assert.strictEqual(chunks.length, 1);
  assert.ok(chunks[0].includes("First paragraph."));
  assert.ok(chunks[0].includes("Second paragraph."));
});

test("splitIntoChunks splits on paragraph boundaries near the size limit", () => {
  const para = "x".repeat(4000);
  const text = `${para}\n\n${para}\n\n${para}`;
  const chunks = splitIntoChunks(text, 6000);
  assert.strictEqual(chunks.length, 3);
  for (const c of chunks) assert.ok(c.length <= 6000);
  // No paragraph content was cut: each chunk is a whole paragraph.
  for (const c of chunks) assert.ok(!c.includes("\n\n"));
});

test("splitIntoChunks hard-splits an over-long single paragraph", () => {
  const text = "y".repeat(13000);
  const chunks = splitIntoChunks(text, 6000);
  assert.strictEqual(chunks.length, 3);
  assert.strictEqual(chunks.join("").replace(/\s+/g, "").length, 13000);
});

test("system instruction carries the academic safeguards", () => {
  assert.ok(/DOIs/.test(SYSTEM_INSTRUCTION));
  assert.ok(/citations/.test(SYSTEM_INSTRUCTION));
  assert.ok(/Output ONLY the translation/.test(SYSTEM_INSTRUCTION));
});

test("translateText falls back across models and joins chunks", async () => {
  const calls = [];
  const fetchImpl = async (url, init) => {
    const body = JSON.parse(init.body);
    calls.push(url);
    const model = url.match(/models\/([^:]+)/)[1];
    if (model === "gemini-3.6-flash") {
      return { ok: false, status: 429, text: async () => "" };
    }
    return {
      ok: true,
      json: async () => ({
        candidates: [
          { content: { parts: [{ text: `ترجمة: ${body.contents[0].parts[0].text}` }] } },
        ],
      }),
    };
  };
  const result = await translateText({
    text: "Hello world.",
    targetLang: "ar",
    apiKey: "test-key",
    fetchImpl,
  });
  assert.strictEqual(result.translation, "ترجمة: Hello world.");
  assert.strictEqual(result.model, "gemini-3.1-flash-lite");
  assert.strictEqual(result.chunks, 1);
  assert.strictEqual(calls.length, 2);
  assert.ok(calls[0].includes("gemini-3.6-flash"));
  assert.ok(calls[1].includes("gemini-3.1-flash-lite"));
});

test("translateText throws when every model fails", async () => {
  const fetchImpl = async () => ({ ok: false, status: 503, text: async () => "" });
  await assert.rejects(
    translateText({ text: "Some text.", targetLang: "en", apiKey: "k", fetchImpl }),
    /translation failed/,
  );
});

test("MAX_CHARS is a sane manuscript cap", () => {
  assert.strictEqual(MAX_CHARS, 40000);
});
