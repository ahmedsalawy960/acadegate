const assert = require("node:assert");
const { test } = require("node:test");
const { appendPart, sanitizeContents, injectAttachments } = require("../academic_assistant")._test;

test("merges streamed text runs and keeps the trailing signature", () => {
  const out = [];
  appendPart(out, { text: "Hello " });
  appendPart(out, { text: "world" });
  appendPart(out, { text: "", thoughtSignature: "SIG" });
  assert.deepStrictEqual(out, [{ text: "Hello world", thoughtSignature: "SIG" }]);
});

test("keeps functionCall parts with their own signatures and skips thoughts", () => {
  const out = [];
  appendPart(out, { thought: true, text: "secret reasoning" });
  appendPart(out, { functionCall: { name: "a", args: {} }, thoughtSignature: "S1" });
  appendPart(out, { functionCall: { name: "b", args: { q: 1 } } });
  assert.deepStrictEqual(out, [
    { functionCall: { name: "a", args: {} }, thoughtSignature: "S1" },
    { functionCall: { name: "b", args: { q: 1 } } },
  ]);
});

test("does not merge text into a part that already carries a signature", () => {
  const out = [];
  appendPart(out, { text: "A", thoughtSignature: "S" });
  appendPart(out, { text: "B" });
  assert.deepStrictEqual(out, [{ text: "A", thoughtSignature: "S" }, { text: "B" }]);
});

test("sanitizeContents strips unknown part keys like inlineData", () => {
  const out = sanitizeContents([
    { role: "user", parts: [{ text: "hi", inlineData: { data: "x" } }] },
    { role: "bogus", parts: [{ functionResponse: { name: "a", response: {} } }] },
  ]);
  assert.deepStrictEqual(out, [
    { role: "user", parts: [{ text: "hi" }] },
    { role: "user", parts: [{ functionResponse: { name: "a", response: {} } }] },
  ]);
});

test("attachments go to the latest user text message, not functionResponse turns", () => {
  const contents = [
    { role: "user", parts: [{ text: "analyze" }] },
    { role: "model", parts: [{ functionCall: { name: "a" } }] },
    { role: "user", parts: [{ functionResponse: { name: "a", response: {} } }] },
  ];
  injectAttachments(contents, [{ inlineData: { mimeType: "image/png", data: "AA" } }]);
  assert.strictEqual(contents[0].parts.length, 2);
  assert.strictEqual(contents[2].parts.length, 1);
});

const {
  admitTurnOrFailOpen,
  shouldFailOpenOnAdmissionError,
} = require("../academic_assistant")._test;
const { HttpsError } = require("firebase-functions/v2/https");

test("quota and session decisions are enforced, not skipped", async () => {
  const quotaError = new HttpsError("resource-exhausted", "انتهى حد باقتك");
  await assert.rejects(
    admitTurnOrFailOpen("u1", "turn-123456", {
      admit: async () => {
        throw quotaError;
      },
    }),
    (e) => e === quotaError,
  );
  await assert.rejects(
    admitTurnOrFailOpen("u1", "turn-123456", {
      admit: async () => {
        throw new HttpsError("permission-denied", "جلسة غير صالحة");
      },
    }),
    /جلسة غير صالحة/,
  );
  await assert.rejects(
    admitTurnOrFailOpen("u1", "turn-123456", {
      admit: async () => {
        throw new HttpsError("deadline-exceeded", "انتهت مهلة هذا الطلب");
      },
    }),
    /انتهت مهلة/,
  );
});

test("infrastructure admission failures fail open as the free tier", async () => {
  const tier = await admitTurnOrFailOpen("u1", "turn-123456", {
    admit: async () => {
      throw new Error("firestore unavailable");
    },
  });
  assert.strictEqual(tier, "free");
});

test("slow admission races to a free-tier fail-open", async () => {
  const tier = await admitTurnOrFailOpen("u1", "turn-123456", {
    admit: () => new Promise(() => {}),
    timeoutMs: 20,
  });
  assert.strictEqual(tier, "free");
});

test("the admitted tier is returned to the caller", async () => {
  const tier = await admitTurnOrFailOpen("u1", "turn-123456", {
    admit: async () => ({ tier: "pro" }),
  });
  assert.strictEqual(tier, "pro");
});

test("classifier: HttpsError is a decision, anything else is transient", () => {
  assert.strictEqual(
    shouldFailOpenOnAdmissionError(new HttpsError("resource-exhausted", "x")),
    false,
  );
  assert.strictEqual(
    shouldFailOpenOnAdmissionError(new HttpsError("deadline-exceeded", "x")),
    false,
  );
  assert.strictEqual(
    shouldFailOpenOnAdmissionError(new Error("admit-timeout")),
    true,
  );
});

const { streamOnce, streamLimitsFor } = require("../academic_assistant")._test;

function sseResponse(chunks, { status = 200 } = {}) {
  const encoder = new TextEncoder();
  const events = chunks.map(
    (c) => `data: ${JSON.stringify(c)}\r\n\r\n`,
  );
  const bytes = events.map((e) => encoder.encode(e));
  return {
    ok: status >= 200 && status < 300,
    status,
    text: async () => "error body",
    body: (async function* () {
      for (const b of bytes) yield b;
    })(),
  };
}

async function withMockFetch(impl, fn) {
  const original = global.fetch;
  global.fetch = impl;
  try {
    return await fn();
  } finally {
    global.fetch = original;
  }
}

test("streams SSE deltas as they arrive and merges the parts", async () => {
  const chunks = [
    { candidates: [{ content: { parts: [{ text: "Hello " }] } }] },
    { candidates: [{ content: { parts: [{ text: "world" }] } }] },
    {
      candidates: [
        {
          content: { parts: [{ functionCall: { name: "search", args: {} }, thoughtSignature: "S1" }] },
          finishReason: "STOP",
        },
      ],
    },
  ];
  const deltas = [];
  const result = await withMockFetch(
    async () => sseResponse(chunks),
    () =>
      streamOnce({
        model: "m",
        apiKey: "k",
        body: {},
        onText: (t) => deltas.push(t),
        limits: { idleMs: 5000, totalMs: 10000 },
      }),
  );
  assert.strictEqual(result.ok, true);
  assert.deepStrictEqual(deltas, ["Hello ", "world"]);
  assert.deepStrictEqual(result.parts, [
    { text: "Hello world" },
    { functionCall: { name: "search", args: {} }, thoughtSignature: "S1" },
  ]);
  assert.strictEqual(result.finishReason, "STOP");
  assert.strictEqual(result.streamedChars, 11);
});

test("handles SSE events split across network chunks", async () => {
  const encoder = new TextEncoder();
  const payload = 'data: {"candidates":[{"content":{"parts":[{"text":"ab"}]}}]}\r\n\r\n';
  const all = encoder.encode(payload);
  const mid = Math.floor(all.length / 2);
  const deltas = [];
  const result = await withMockFetch(
    async () => ({
      ok: true,
      status: 200,
      body: (async function* () {
        yield all.subarray(0, mid);
        yield all.subarray(mid);
      })(),
    }),
    () =>
      streamOnce({
        model: "m",
        apiKey: "k",
        body: {},
        onText: (t) => deltas.push(t),
        limits: { idleMs: 5000, totalMs: 10000 },
      }),
  );
  assert.strictEqual(result.ok, true);
  assert.deepStrictEqual(deltas, ["ab"]);
});

test("ignores malformed SSE data lines and keeps parsing", async () => {
  const encoder = new TextEncoder();
  const deltas = [];
  const result = await withMockFetch(
    async () => ({
      ok: true,
      status: 200,
      body: (async function* () {
        yield encoder.encode("data: {broken json\r\n\r\n");
        yield encoder.encode('data: {"candidates":[{"content":{"parts":[{"text":"ok"}]}}]}\r\n\r\n');
      })(),
    }),
    () =>
      streamOnce({
        model: "m",
        apiKey: "k",
        body: {},
        onText: (t) => deltas.push(t),
        limits: { idleMs: 5000, totalMs: 10000 },
      }),
  );
  assert.strictEqual(result.ok, true);
  assert.deepStrictEqual(deltas, ["ok"]);
});

test("returns the HTTP error body for rejected calls", async () => {
  const result = await withMockFetch(
    async () => ({ ok: false, status: 429, text: async () => "quota exceeded" }),
    () =>
      streamOnce({
        model: "m",
        apiKey: "k",
        body: {},
        onText: () => {},
        limits: { idleMs: 5000, totalMs: 10000 },
      }),
  );
  assert.deepStrictEqual(result, { ok: false, status: 429, errBody: "quota exceeded" });
});

test("aborts a stream that goes idle", async () => {
  let capturedSignal = null;
  await assert.rejects(
    withMockFetch(
      async (url, opts) => {
        capturedSignal = opts.signal;
        return {
          ok: true,
          status: 200,
          body: (async function* () {
            yield new TextEncoder().encode('data: {"candidates":[{"content":{"parts":[{"text":"hi"}]}}]}\r\n\r\n');
            await new Promise((_, reject) => {
              capturedSignal.addEventListener("abort", () =>
                reject(capturedSignal.reason || new Error("aborted")),
              );
            });
          })(),
        };
      },
      () =>
        streamOnce({
          model: "m",
          apiKey: "k",
          body: {},
          onText: () => {},
          limits: { idleMs: 30, totalMs: 60000 },
        }),
    ),
    /stream-idle-timeout/,
  );
});

test("aborts a stream that exceeds the total cap", async () => {
  let capturedSignal = null;
  await assert.rejects(
    withMockFetch(
      async (url, opts) => {
        capturedSignal = opts.signal;
        return {
          ok: true,
          status: 200,
          body: (async function* () {
            const enc = new TextEncoder();
            while (true) {
              yield enc.encode('data: {"candidates":[{"content":{"parts":[{"text":"."}]}]}}]}\r\n\r\n');
              await new Promise((resolve, reject) => {
                const t = setTimeout(resolve, 10);
                capturedSignal.addEventListener("abort", () => {
                  clearTimeout(t);
                  reject(capturedSignal.reason || new Error("aborted"));
                });
              });
            }
          })(),
        };
      },
      () =>
        streamOnce({
          model: "m",
          apiKey: "k",
          body: {},
          onText: () => {},
          limits: { idleMs: 60000, totalMs: 50 },
        }),
    ),
    /stream-total-timeout/,
  );
});

test("deep mode gets a larger stream budget than fast mode", () => {
  const fast = streamLimitsFor(false);
  const deep = streamLimitsFor(true);
  assert.ok(deep.totalMs > fast.totalMs);
  assert.ok(deep.idleMs >= fast.idleMs);
});

const {
  primaryModelFor,
  DEEP_MODELS,
  FAST_MODELS,
  generationConfigFor,
} = require("../academic_assistant")._test;

test("model classes exclude deprecated ids that auto-route to weaker models", () => {
  const retired = ["gemini-2.5-flash", "gemini-2.5-pro"];
  for (const id of retired) {
    assert.ok(!DEEP_MODELS.includes(id), `${id} must leave DEEP_MODELS`);
    assert.ok(!FAST_MODELS.includes(id), `${id} must leave FAST_MODELS`);
  }
});

test("each class leads with its strongest supported model", () => {
  assert.strictEqual(DEEP_MODELS[0], "gemini-3.1-pro-preview");
  assert.strictEqual(FAST_MODELS[0], "gemini-3.6-flash");
  assert.strictEqual(primaryModelFor(true), DEEP_MODELS[0]);
  assert.strictEqual(primaryModelFor(false), FAST_MODELS[0]);
});

test("the lite model is only a last-resort fast fallback", () => {
  assert.strictEqual(FAST_MODELS[FAST_MODELS.length - 1], "gemini-3.1-flash-lite");
  assert.ok(!DEEP_MODELS.some((m) => m.includes("lite")), "deep never serves lite");
});

test("generation config uses thinking levels, never legacy thinking budgets", () => {
  for (const model of [...DEEP_MODELS, ...FAST_MODELS]) {
    for (const deep of [true, false]) {
      const config = generationConfigFor(model, { deep, hasMedia: false });
      assert.ok(
        !("thinkingBudget" in (config.thinkingConfig || {})),
        `${model} must not get a thinkingBudget`,
      );
      assert.strictEqual(config.thinkingConfig.thinkingLevel, deep ? "high" : "medium");
    }
  }
  const media = generationConfigFor(FAST_MODELS[0], { deep: false, hasMedia: true });
  assert.ok(!media.thinkingConfig, "media turns skip thinking config");
});
