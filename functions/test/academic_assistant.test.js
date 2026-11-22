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
