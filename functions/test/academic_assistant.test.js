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
